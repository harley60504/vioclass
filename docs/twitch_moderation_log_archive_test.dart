// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/models/chat/twitch_moderation_log_entry.dart';
import '../lib/features/twitch/services/chat/twitch_moderation_log_archive_store.dart';

TwitchModerationLogEntry entry(
  String id, {
  String channel = '20',
  String action = 'clear',
  Map<String, dynamic>? details,
  int second = 0,
}) => TwitchModerationLogEntry.parse(
  id: id,
  time: DateTime.utc(2026, 10, 3, 12, 0, second),
  expectedBroadcasterId: channel,
  event: {
    'broadcaster_user_id': channel,
    'source_broadcaster_user_id': '30',
    'moderator_user_id': '40',
    'action': action,
    action: ?details,
  },
)!;

void main() {
  late Map<String, String> disk;
  late TwitchModerationLogArchiveStore store;
  var writes = 0;
  TwitchModerationLogArchiveStore create({
    int limit = 500,
    int bytes = 2097152,
  }) => TwitchModerationLogArchiveStore(
    read: (key) async => disk[key],
    write: (key, value) async {
      writes++;
      disk[key] = value;
    },
    maxEntries: limit,
    maxBytes: bytes,
  );
  setUp(() {
    disk = {};
    writes = 0;
    store = create();
  });

  test(
    'Restart restores received identity, shared source and immutable details',
    () async {
      await store.append(
        '10',
        '20',
        entry(
          'a',
          action: 'warn',
          details: {
            'user_id': '50',
            'reason': 'spam',
            'chat_rules_cited': ['be kind'],
          },
        ),
      );
      final loaded = await create().load('10', '20');
      expect(loaded.single.sourceBroadcasterId, '30');
      expect(loaded.single.moderatorId, '40');
      expect(loaded.single.targetUserId, '50');
      expect(loaded.single.details['chat_rules_cited'], ['be kind']);
      expect(() => loaded.clear(), throwsUnsupportedError);
    },
  );
  test('Account and channel partitions cannot collide', () async {
    await store.append('10', '20', entry('same'));
    await store.append('11', '20', entry('same'));
    await store.append('10', '21', entry('same', channel: '21'));
    expect(disk, hasLength(3));
    expect(await store.load('12', '20'), isEmpty);
    expect(await store.load('10', '22'), isEmpty);
    await expectLater(
      store.append('10', '21', entry('wrong')),
      throwsArgumentError,
    );
    await expectLater(store.load('10_20', '21'), throwsArgumentError);
  });
  test(
    'Concurrent append serializes and restart delivery is deduplicated',
    () async {
      await Future.wait(
        List.generate(
          20,
          (i) => store.append('10', '20', entry('$i', second: i)),
        ),
      );
      final before = writes;
      await create().append('10', '20', entry('3', second: 50));
      final loaded = await store.load('10', '20');
      expect(loaded, hasLength(20));
      expect(writes, before);
      expect(loaded.first.id, '0');
      expect(loaded.last.id, '19');
    },
  );
  test('Retention keeps newest by event time, not receipt order', () async {
    store = create(limit: 2);
    await store.append('10', '20', entry('new', second: 3));
    await store.append('10', '20', entry('middle', second: 2));
    await store.append('10', '20', entry('old', second: 1));
    expect((await store.load('10', '20')).map((v) => v.id), ['middle', 'new']);
  });
  test(
    'Unknown and unavailable detail survive serialization honestly',
    () async {
      await store.append('10', '20', entry('a', action: 'future_action'));
      await store.append('10', '20', entry('b', action: 'ban'));
      final loaded = await store.load('10', '20');
      expect(loaded.first.category, TwitchModerationLogCategory.unknown);
      expect(loaded.first.detailsAvailable, false);
      expect(loaded.last.detailsAvailable, false);
    },
  );
  test(
    'Corrupt or mismatched archive is preserved and blocks append',
    () async {
      await store.append('10', '20', entry('original'));
      final key = disk.keys.single;
      final original = disk[key]!;
      for (final raw in [
        'not json',
        jsonEncode({'version': 9}),
        original.replaceFirst('"ownerId":"10"', '"ownerId":"11"'),
        original.replaceFirst(
          '"broadcaster_user_id":"20"',
          '"broadcaster_user_id":"21"',
        ),
      ]) {
        disk[key] = raw;
        await expectLater(
          store.append('10', '20', entry('next')),
          throwsA(isA<TwitchModerationLogArchiveException>()),
        );
        expect(disk[key], raw);
      }
    },
  );
  test(
    'UTF8 byte limit trims oldest but oversized single entry cannot erase log',
    () async {
      store = create(bytes: 900);
      for (var i = 0; i < 5; i++) {
        await store.append(
          '10',
          '20',
          entry(
            '$i',
            action: 'ban',
            second: i,
            details: {'reason': '測試' * 30, 'user_id': '50'},
          ),
        );
      }
      expect(utf8.encode(disk.values.single).length, lessThanOrEqualTo(900));
      final saved = disk.values.single;
      await expectLater(
        store.append(
          '10',
          '20',
          entry('huge', action: 'ban', details: {'reason': '測試' * 1000}),
        ),
        throwsA(isA<TwitchModerationLogArchiveException>()),
      );
      expect(disk.values.single, saved);
    },
  );
  test(
    'Failed persistence does not poison queue or overwrite saved data',
    () async {
      await store.append('10', '20', entry('saved'));
      var fail = true;
      store = TwitchModerationLogArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async {
          if (fail) throw StateError('fixture failure');
          disk[key] = value;
        },
      );
      await expectLater(
        store.append('10', '20', entry('failed')),
        throwsStateError,
      );
      expect((await store.load('10', '20')).single.id, 'saved');
      fail = false;
      await store.append('10', '20', entry('retry'));
      expect(await store.load('10', '20'), hasLength(2));
    },
  );
}
