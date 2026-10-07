// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_history_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_threads_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/models/chat/twitch_whisper_conversation.dart';
import '../lib/features/twitch/models/chat/twitch_whisper_remote_history.dart';
import '../lib/features/twitch/services/chat/twitch_whisper_archive_store.dart';
import '../lib/features/twitch/services/chat/twitch_whisper_recovery_service.dart';

class _History extends TwitchWhisperHistoryApiService {
  final calls = <String>[];
  bool fail = false;
  Completer<void>? gate;
  _History(TwitchApiClient superClient)
    : super(client: superClient, webTokenProviders: const []);
  @override
  Future<TwitchWhisperRemotePage> page({
    required String ownerId,
    required String peerId,
    String? cursor,
  }) async {
    calls.add('$peerId/${cursor ?? "recent"}');
    await gate?.future;
    if (fail && cursor != null) throw StateError('fake page failure');
    return TwitchWhisperRemotePage(
      ownerId: ownerId,
      peerId: peerId,
      requestedCursor: cursor,
      nextCursor: cursor == null ? 'older' : null,
      messages: [
        TwitchWhisperMessage(
          id: '$peerId-${cursor ?? "recent"}',
          fromUserId: peerId,
          toUserId: ownerId,
          text: 'history',
          timestamp: DateTime.utc(2026, 10, 3),
          state: TwitchWhisperMessageState.received,
        ),
      ],
    );
  }
}

class _Threads extends TwitchWhisperThreadsApiService {
  final calls = <String?>[];
  Completer<void>? gate;
  _Threads(TwitchWhisperHistoryApiService superHistory)
    : super(history: superHistory);
  @override
  Future<TwitchWhisperThreadsPage> page({
    required String ownerId,
    String? cursor,
  }) async {
    calls.add(cursor);
    await gate?.future;
    return TwitchWhisperThreadsPage(
      ownerId: ownerId,
      requestedCursor: cursor,
      nextCursor: cursor == null ? 'more' : null,
      conversations: [
        TwitchWhisperConversation(
          userId: cursor == null ? '3' : '4',
          login: 'remote',
          displayName: 'Remote',
          remoteUnreadCount: 4,
        ),
      ],
    );
  }
}

void main() {
  late Map<String, String> disk;
  late TwitchWhisperArchiveStore store;
  late TwitchApiClient client;
  late _History history;
  late _Threads threads;
  bool failWrite = false;
  TwitchWhisperArchiveStore newStore() => TwitchWhisperArchiveStore(
    read: (key) async => disk[key],
    write: (key, value) async {
      if (failWrite) throw StateError('fake checkpoint write failure');
      disk[key] = value;
    },
  );
  TwitchWhisperRecoveryService runner() => TwitchWhisperRecoveryService(
    archive: store,
    history: history,
    threads: threads,
    timeout: const Duration(milliseconds: 200),
  );
  setUp(() async {
    disk = {};
    failWrite = false;
    store = newStore();
    client = TwitchApiClient();
    history = _History(client);
    threads = _Threads(history);
    final peer = TwitchWhisperConversation(
      userId: '2',
      login: 'local',
      displayName: 'Local',
    );
    await store.saveDraft('1', peer, 'keep draft');
    await store.recordReceiveGap('1', DateTime.utc(2026, 10, 1));
    await store.mergeThreadsPage(
      '1',
      TwitchWhisperThreadsPage(
        ownerId: '1',
        conversations: const [],
        nextCursor: 'ui-list',
      ),
    );
    await store.mergeRemotePage(
      '1',
      peer,
      TwitchWhisperRemotePage(
        ownerId: '1',
        peerId: '2',
        messages: const [],
        nextCursor: 'ui-history',
      ),
    );
  });
  tearDown(() => client.close());

  for (final complete in [false, true]) {
    test('Imported new peer resets remote progress (complete=$complete)', () async {
      final current = (await store.load('1')).single;
      final imported = TwitchWhisperConversation(
        userId: '3',
        login: 'imported',
        displayName: 'Imported',
        avatarUrl: 'https://example.com/avatar.png',
        draft: 'restored draft',
        unreadCount: 8,
        remoteUnreadCount: 11,
        hasReceivedWhisper: true,
        remoteHistoryCursor: complete ? null : 'other-device-cursor',
        remoteHistoryComplete: complete,
        messages: [
          TwitchWhisperMessage(
            id: 'imported-message',
            fromUserId: '3',
            toUserId: '1',
            text: 'backup history',
            timestamp: DateTime.utc(2026, 10, 4),
            state: TwitchWhisperMessageState.received,
          ),
        ],
      );
      final raw = jsonEncode({
        'version': 1,
        'ownerId': '1',
        'conversations': [
          current.copyWith(
            draft: 'not the current draft',
            remoteUnreadCount: 99,
            remoteHistoryCursor: 'not the current cursor',
            replaceRemoteHistoryCursor: true,
          ).toJson(),
          imported.toJson(),
        ],
      });
      final before = Map<String, String>.of(disk);
      failWrite = true;
      await expectLater(store.importBackup('1', raw), throwsStateError);
      expect(disk, before);
      failWrite = false;
      expect(await store.importBackup('1', raw), 1);
      store = newStore();
      final saved = await store.load('1');
      final newPeer = saved.singleWhere((peer) => peer.userId == '3');
      expect(newPeer.remoteHistoryCursor, isNull);
      expect(newPeer.remoteHistoryComplete, false);
      expect(newPeer.remoteUnreadCount, 0);
      expect(newPeer.unreadCount, 0);
      expect(newPeer.hasReceivedWhisper, false);
      expect(newPeer.draft, 'restored draft');
      expect(newPeer.avatarUrl, imported.avatarUrl);
      expect(newPeer.messages.single.historicalOnly, true);
      final existing = saved.singleWhere((peer) => peer.userId == '2');
      expect(existing.draft, 'keep draft');
      expect(existing.remoteHistoryCursor, 'ui-history');
      expect(existing.remoteHistoryComplete, false);
      expect(existing.remoteUnreadCount, 0);
      expect((await store.threadsCheckpoint('1')).cursor, 'ui-list');
      expect(await store.receiveGapSince('1'), DateTime.utc(2026, 10, 1));
      // First remote page is not blocked by another device's completion/cursor.
      await store.mergeRemotePage(
        '1',
        newPeer,
        TwitchWhisperRemotePage(
          ownerId: '1',
          peerId: '3',
          messages: const [],
          nextCursor: 'fresh-cursor',
        ),
      );
      expect(await store.importBackup('1', raw), 0);
      store = newStore();
      final refreshed = (await store.load('1')).singleWhere(
        (peer) => peer.userId == '3',
      );
      expect(refreshed.remoteHistoryCursor, 'fresh-cursor');
      expect(refreshed.draft, 'restored draft');
    });
  }

  test(
    'Import preserves existing live provenance and distinct outgoing identities across restart',
    () async {
      final peer = (await store.load('1')).first;
      final at = DateTime.utc(2026, 10, 4);
      final live = TwitchWhisperMessage(
        id: 'existing-live',
        fromUserId: '2',
        toUserId: '1',
        text: 'same text',
        timestamp: at,
        state: TwitchWhisperMessageState.received,
      );
      await store.append('1', peer, live);
      final messages = [
        live,
        TwitchWhisperMessage(
          id: 'import-incoming',
          fromUserId: '2',
          toUserId: '1',
          text: 'same text',
          timestamp: at,
          state: TwitchWhisperMessageState.received,
        ),
        TwitchWhisperMessage(
          id: 'local-attempt',
          fromUserId: '1',
          toUserId: '2',
          text: 'same text',
          timestamp: at,
          state: TwitchWhisperMessageState.sending,
        ),
        TwitchWhisperMessage(
          id: 'official-outgoing',
          fromUserId: '1',
          toUserId: '2',
          text: 'same text',
          timestamp: at,
          state: TwitchWhisperMessageState.submitted,
        ),
      ];
      final raw = jsonEncode({
        'version': 1,
        'ownerId': '1',
        'conversations': [peer.copyWith(messages: messages).toJson()],
      });
      expect(await store.importBackup('1', raw), 3);
      store = newStore();
      final saved = (await store.load('1')).single;
      final byId = {for (final message in saved.messages) message.id: message};
      expect(byId, hasLength(4));
      expect(byId['existing-live']!.historicalOnly, false);
      expect(byId['import-incoming']!.historicalOnly, true);
      expect(byId['local-attempt']!.historicalOnly, true);
      expect(
        byId['local-attempt']!.state,
        TwitchWhisperMessageState.unconfirmed,
      );
      expect(
        byId['official-outgoing']!.state,
        TwitchWhisperMessageState.submitted,
      );
      expect(saved.unreadCount, 1);
      expect(saved.draft, 'keep draft');
      expect(await store.importBackup('1', raw), 0);
      expect((await store.load('1')).single.messages, hasLength(4));
    },
  );

  test(
    'Unchanged snapshots reuse immutable data but external changes and corruption never use stale cache',
    () async {
      final first = await store.load('1');
      final repeated = await store.load('1');
      expect(identical(first, repeated), true);
      expect(() => repeated.clear(), throwsUnsupportedError);
      expect(() => repeated.first.messages.clear(), throwsUnsupportedError);
      final other = newStore();
      await other.saveDraft('1', first.first, 'externally changed');
      final updated = await store.load('1');
      expect(identical(first, updated), false);
      expect(updated.first.draft, 'externally changed');
      disk['vioclass_twitch_whispers_v1_1'] = '{corrupt';
      await expectLater(
        store.load('1'),
        throwsA(isA<TwitchWhisperArchiveException>()),
      );
      await expectLater(
        store.markRead('1', '2'),
        throwsA(isA<TwitchWhisperArchiveException>()),
      );
      expect(disk['vioclass_twitch_whispers_v1_1'], '{corrupt');
    },
  );

  test(
    'Cache holds one owner and does not hide source read failures or deletion',
    () async {
      var readFails = false;
      store = TwitchWhisperArchiveStore(
        read: (key) async {
          if (readFails) throw StateError('fake source read failure');
          return disk[key];
        },
        write: (key, value) async => disk[key] = value,
      );
      final first = await store.load('1');
      readFails = true;
      await expectLater(store.load('1'), throwsStateError);
      readFails = false;
      await store.saveDraft(
        '9',
        TwitchWhisperConversation(
          userId: '2',
          login: 'peer',
          displayName: 'Peer',
        ),
        'other owner',
      );
      final other = await store.load('9');
      expect(other.single.draft, 'other owner');
      final returned = await store.load('1');
      expect(identical(first, returned), false);
      expect(returned.single.userId, '2');
      disk.remove('vioclass_twitch_whispers_v1_1');
      expect(await store.load('1'), isEmpty);
    },
  );

  test(
    'Large-history unchanged draft and read operations perform no writes but genuine changes persist',
    () async {
      final peer = (await store.load('1')).first;
      await store.append(
        '1',
        peer,
        TwitchWhisperMessage(
          id: 'large-noop',
          fromUserId: '2',
          toUserId: '1',
          text: 'x' * (3 * 1024 * 1024),
          timestamp: DateTime.utc(2026, 10, 4),
          state: TwitchWhisperMessageState.received,
        ),
        reading: true,
      );
      var writes = 0;
      final counted = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async {
          writes++;
          disk[key] = value;
        },
      );
      final current = (await counted.load('1')).single;
      final before = disk['vioclass_twitch_whispers_v1_1'];
      for (var i = 0; i < 10; i++) {
        await counted.saveDraft('1', current, current.draft);
        await counted.markRead('1', '2');
      }
      expect(writes, 0);
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      await counted.saveDraft('1', current, 'changed');
      expect(writes, 1);
      expect((await counted.load('1')).single.draft, 'changed');
      expect(
        (await counted.load('1')).single.messages.single.text,
        current.messages.single.text,
      );
    },
  );

  test(
    'Backup larger than two MiB roundtrips without importing runtime metadata',
    () async {
      final peer = (await store.load('1')).first;
      final message = TwitchWhisperMessage(
        id: 'large-backup',
        fromUserId: '2',
        toUserId: '1',
        text: 'x' * (3 * 1024 * 1024),
        timestamp: DateTime.utc(2026, 10, 4),
        state: TwitchWhisperMessageState.received,
      );
      await store.append('1', peer, message);
      final raw = await store.exportBackup('1');
      expect(utf8.encode(raw).length, greaterThan(2 * 1024 * 1024));
      final restoredDisk = <String, String>{};
      final restored = TwitchWhisperArchiveStore(
        read: (key) async => restoredDisk[key],
        write: (key, value) async => restoredDisk[key] = value,
      );
      expect(await restored.importBackup('1', raw), 1);
      expect(
        (await restored.load('1')).single.messages.single.text,
        message.text,
      );
      expect((await restored.load('1')).single.draft, 'keep draft');
      expect(await restored.receiveGapSince('1'), isNull);
      expect((await restored.threadsCheckpoint('1')).cursor, isNull);
      expect(await restored.recoveryCheckpoint('1'), isNull);
      expect(await restored.importBackup('1', raw), 0);
    },
  );

  test(
    'Export and import use the same exact UTF-8 boundary and never overwrite on overflow',
    () async {
      final peer = (await store.load('1')).first;
      await store.saveDraft('1', peer, '中文字😀' * 50);
      final raw = await store.exportBackup('1');
      final bytes = utf8.encode(raw).length;
      expect(bytes, greaterThan(raw.length));
      TwitchWhisperArchiveStore limited(int limit) => TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async => disk[key] = value,
        maxBackupBytes: limit,
      );
      final atLimit = limited(bytes);
      expect(await atLimit.exportBackup('1'), raw);
      expect(await atLimit.importBackup('1', raw), 0);
      final before = disk['vioclass_twitch_whispers_v1_1'];
      for (final limit in [bytes - 1, raw.length]) {
        final under = limited(limit);
        await expectLater(
          under.exportBackup('1'),
          throwsA(isA<TwitchWhisperArchiveException>()),
        );
        await expectLater(
          under.importBackup('1', raw),
          throwsA(isA<TwitchWhisperArchiveException>()),
        );
        expect(disk['vioclass_twitch_whispers_v1_1'], before);
      }
    },
  );

  test(
    'Gap save reports cancellation separately from persisted or unchanged observations',
    () async {
      const id = '11111111111111111111111111111111';
      final before = disk['vioclass_twitch_whispers_v1_1'];
      expect(
        await store.recordReceiveGap(
          '1',
          DateTime.utc(2026, 10, 4),
          observationId: id,
          canApply: () => false,
        ),
        false,
      );
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      expect(
        await store.recordReceiveGap(
          '1',
          DateTime.utc(2026, 10, 4),
          observationId: id,
        ),
        true,
      );
      final saved = disk['vioclass_twitch_whispers_v1_1'];
      expect(
        await store.recordReceiveGap(
          '1',
          DateTime.utc(2026, 10, 4),
          observationId: id,
        ),
        true,
      );
      expect(disk['vioclass_twitch_whispers_v1_1'], saved);
    },
  );

  test(
    'Distinct observation identities invalidate work with backwards or equal clocks',
    () async {
      final at = DateTime.utc(2026, 10, 4);
      const firstId = '11111111111111111111111111111111';
      const secondId = '22222222222222222222222222222222';
      const thirdId = '33333333333333333333333333333333';
      await store.recordReceiveGap(
        '1',
        at,
        observedAt: at,
        observationId: firstId,
      );
      final first = await store.beginRecovery('1');
      expect(first.gapObservationId, firstId);
      final earlier = at.subtract(const Duration(days: 1));
      await store.recordReceiveGap(
        '1',
        earlier,
        observedAt: earlier,
        observationId: secondId,
      );
      expect(await store.recoveryNeedsRestart('1', first), true);
      final second = await store.beginRecovery('1');
      expect(second.gapObservationId, secondId);
      expect(second.gapObservedAt, earlier);
      await store.recordReceiveGap(
        '1',
        earlier,
        observedAt: earlier,
        observationId: thirdId,
      );
      expect(await store.recoveryNeedsRestart('1', second), true);
      final third = await store.beginRecovery('1');
      expect(third.gapObservationId, thirdId);
      expect(third.gapObservedAt, earlier);
      final saved = disk['vioclass_twitch_whispers_v1_1'];
      await store.recordReceiveGap(
        '1',
        earlier,
        observedAt: earlier,
        observationId: thirdId,
      );
      expect(disk['vioclass_twitch_whispers_v1_1'], saved);
      expect(await store.recoveryNeedsRestart('1', third), false);
      expect((await store.load('1')).first.draft, 'keep draft');
    },
  );

  test(
    'Same-time new receiving lifetimes have separate persisted identities',
    () async {
      final at = DateTime.utc(2026, 10, 4);
      await store.beginReceiveSession('1', at);
      await store.beginReceiveSession('1', at);
      final first = await store.beginRecovery('1');
      expect(first.gapObservationId, matches(RegExp(r'^[0-9a-f]{32}$')));
      store = newStore();
      await store.beginReceiveSession('1', at);
      expect(await store.recoveryNeedsRestart('1', first), true);
      final second = await store.beginRecovery('1');
      expect(second.gapObservationId, isNot(first.gapObservationId));
      expect(second.gapObservedAt, first.gapObservedAt);
      expect((await store.load('1')).first.draft, 'keep draft');
    },
  );

  test(
    'Identity save failure retries the same event and rejects corrupt identities without overwrite',
    () async {
      const id = '11111111111111111111111111111111';
      final before = disk['vioclass_twitch_whispers_v1_1'];
      failWrite = true;
      await expectLater(
        store.recordReceiveGap(
          '1',
          DateTime.utc(2026, 10, 4),
          observationId: id,
        ),
        throwsStateError,
      );
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      failWrite = false;
      await store.recordReceiveGap(
        '1',
        DateTime.utc(2026, 10, 4),
        observationId: id,
      );
      final work = await store.beginRecovery('1');
      final saved = disk['vioclass_twitch_whispers_v1_1'];
      await store.recordReceiveGap(
        '1',
        DateTime.utc(2026, 10, 4),
        observationId: id,
      );
      expect(disk['vioclass_twitch_whispers_v1_1'], saved);
      expect(await store.recoveryNeedsRestart('1', work), false);
      for (final field in ['receiveGapObservationId', 'gapObservationId']) {
        for (final invalid in [123, '', 'x' * 32, '1' * 33]) {
          final metadata = jsonDecode(saved!) as Map;
          if (field == 'receiveGapObservationId') {
            metadata[field] = invalid;
          } else {
            (metadata['receiveRecovery'] as Map)[field] = invalid;
          }
          final corrupt = jsonEncode(metadata);
          disk['vioclass_twitch_whispers_v1_1'] = corrupt;
          await expectLater(
            store.beginRecovery('1'),
            throwsA(isA<TwitchWhisperArchiveException>()),
          );
          expect(disk['vioclass_twitch_whispers_v1_1'], corrupt);
        }
      }
    },
  );

  test(
    'Recovery enumerates every thread and pages every local/unknown peer without changing browsing cursors',
    () async {
      final work = await runner().run('1', canApply: () => true);
      expect(work.complete, true);
      expect(threads.calls, [null, 'more']);
      expect(history.calls, [
        '2/recent',
        '2/older',
        '3/recent',
        '3/older',
        '4/recent',
        '4/older',
      ]);
      final peers = await store.load('1');
      expect(peers.map((p) => p.userId), ['2', '3', '4']);
      expect(peers.every((p) => p.messages.length == 2), true);
      expect(peers.every((p) => p.unreadCount == 0), true);
      expect(
        peers.expand((p) => p.messages).every((m) => m.historicalOnly),
        true,
      );
      expect(peers.first.draft, 'keep draft');
      expect(peers.first.remoteHistoryCursor, 'ui-history');
      expect((await store.threadsCheckpoint('1')).cursor, 'ui-list');
      expect(await store.receiveGapSince('1'), DateTime.utc(2026, 10, 1));
      expect(await store.recoveryCheckpoint('9'), isNull);
    },
  );

  test(
    'Restart after page failure resumes exact saved peer/cursor instead of re-enumerating',
    () async {
      history.fail = true;
      await expectLater(
        runner().run('1', canApply: () => true),
        throwsStateError,
      );
      final before = (await store.recoveryCheckpoint('1'))!;
      expect(before.activePeerId, '2');
      expect(before.cursor, 'older');
      history.fail = false;
      history.calls.clear();
      threads.calls.clear();
      store = newStore();
      expect((await runner().run('1', canApply: () => true)).complete, true);
      expect(threads.calls, isEmpty);
      expect(history.calls.first, '2/older');
      expect((await store.load('1')).first.messages, hasLength(2));
    },
  );

  test(
    'Page write failure saves neither discoveries nor progress and stale work is rejected',
    () async {
      final work = await store.beginRecovery('1');
      final before = disk['vioclass_twitch_whispers_v1_1'];
      final page = await threads.page(ownerId: '1');
      failWrite = true;
      await expectLater(
        store.mergeThreadsPage('1', page, recovery: work),
        throwsStateError,
      );
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      failWrite = false;
      await store.mergeThreadsPage('1', page, recovery: work);
      final saved = disk['vioclass_twitch_whispers_v1_1'];
      await expectLater(
        store.mergeThreadsPage('1', page, recovery: work),
        throwsFormatException,
      );
      expect(disk['vioclass_twitch_whispers_v1_1'], saved);
    },
  );

  test(
    'New gap during a page keeps saved data but requires a fresh pass',
    () async {
      history.fail = true;
      await expectLater(
        runner().run('1', canApply: () => true),
        throwsStateError,
      );
      history.fail = false;
      history.calls.clear();
      threads.calls.clear();
      history.gate = Completer<void>();
      final job = runner();
      final pending = job.run('1', canApply: () => true);
      final rejected = expectLater(pending, throwsException);
      while (history.calls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(history.calls.first, '2/older');
      final newer = DateTime.utc(2026, 10, 4);
      await store.recordReceiveGap(
        '1',
        DateTime.utc(2026, 10, 1),
        observedAt: newer,
      );
      history.gate!.complete();
      await rejected;
      expect(job.running, false);
      expect((await store.load('1')).first.messages, hasLength(2));
      expect(await store.receiveGapSince('1'), DateTime.utc(2026, 10, 1));
      history.gate = null;
      store = newStore();
      history.calls.clear();
      final finished = await runner().run('1', canApply: () => true);
      expect(finished.gapObservedAt, newer);
      expect(threads.calls, [null, 'more']);
      expect(history.calls.first, '2/recent');
      expect((await store.load('1')).first.draft, 'keep draft');
      expect((await store.threadsCheckpoint('1')).cursor, 'ui-list');
    },
  );

  test(
    'Failed new-gap save is atomic and repeated observation does not invalidate progress',
    () async {
      history.fail = true;
      await expectLater(
        runner().run('1', canApply: () => true),
        throwsStateError,
      );
      final work = (await store.recoveryCheckpoint('1'))!;
      final before = disk['vioclass_twitch_whispers_v1_1'];
      failWrite = true;
      await expectLater(
        store.recordReceiveGap(
          '1',
          DateTime.utc(2026, 10, 1),
          observedAt: DateTime.utc(2026, 10, 4),
        ),
        throwsStateError,
      );
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      failWrite = false;
      await store.recordReceiveGap('1', DateTime.utc(2026, 10, 1));
      expect(await store.recoveryNeedsRestart('1', work), false);
      expect((await store.beginRecovery('1')).toJson(), work.toJson());
      await store.recordReceiveGap(
        '1',
        DateTime.utc(2026, 10, 1),
        observedAt: DateTime.utc(2026, 10, 4),
      );
      final saved = disk['vioclass_twitch_whispers_v1_1'];
      failWrite = true;
      await expectLater(store.beginRecovery('1'), throwsStateError);
      expect(disk['vioclass_twitch_whispers_v1_1'], saved);
      expect((await store.recoveryCheckpoint('1'))!.toJson(), work.toJson());
      failWrite = false;
      final fresh = await store.beginRecovery('1');
      expect(fresh.phase, 'threads');
      expect(fresh.cursor, isNull);
      expect(fresh.gapObservedAt, DateTime.utc(2026, 10, 4));
    },
  );

  test(
    'New receiving lifetime invalidates unfinished work and invalid observations preserve disk',
    () async {
      await store.beginReceiveSession('1', DateTime.utc(2026, 10, 2));
      history.fail = true;
      await expectLater(
        runner().run('1', canApply: () => true),
        throwsStateError,
      );
      final old = (await store.recoveryCheckpoint('1'))!;
      await store.beginReceiveSession('1', DateTime.utc(2026, 10, 4));
      expect(await store.recoveryNeedsRestart('1', old), true);
      final fresh = await store.beginRecovery('1');
      expect(fresh.phase, 'threads');
      expect(fresh.gapObservedAt, DateTime.utc(2026, 10, 4));
      final metadata =
          jsonDecode(disk['vioclass_twitch_whispers_v1_1']!) as Map;
      for (final invalid in [123, 'invalid', '2026-02-30T00:00:00.000Z']) {
        metadata['receiveGapObservedAt'] = invalid;
        final corrupt = jsonEncode(metadata);
        disk['vioclass_twitch_whispers_v1_1'] = corrupt;
        await expectLater(
          store.beginRecovery('1'),
          throwsA(isA<TwitchWhisperArchiveException>()),
        );
        expect(disk['vioclass_twitch_whispers_v1_1'], corrupt);
      }
    },
  );

  test(
    'Cancellation releases waiting page and ignores its late response; retry starts at original cursor',
    () async {
      threads.gate = Completer<void>();
      final job = runner();
      final running = job.run('1', canApply: () => true);
      final cancelled = expectLater(running, throwsException);
      while (threads.calls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      job.cancel();
      await cancelled;
      final before = disk['vioclass_twitch_whispers_v1_1'];
      threads.gate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      threads.gate = null;
      expect((await job.run('1', canApply: () => true)).complete, true);
      expect(threads.calls.take(2), [null, null]);
    },
  );

  test(
    'Gap during the final history page cannot be reported as a successful pass',
    () async {
      final gate = Completer<void>();
      final pending = runner().run(
        '1',
        canApply: () => true,
        onProgress: (work) {
          if (work.activePeerId == '4' && work.cursor == 'older') {
            history.gate = gate;
          }
        },
      );
      final rejected = expectLater(pending, throwsException);
      while (!history.calls.contains('4/older')) {
        await Future<void>.delayed(Duration.zero);
      }
      await store.recordReceiveGap('1', DateTime.utc(2026, 10, 4));
      gate.complete();
      await rejected;
      final saved = (await store.recoveryCheckpoint('1'))!;
      expect(saved.complete, true);
      expect(await store.recoveryNeedsRestart('1', saved), true);
      expect(
        (await store.load('1')).every((p) => p.messages.length == 2),
        true,
      );
      history.gate = null;
      final fresh = await store.beginRecovery('1');
      expect(fresh.complete, false);
      expect(fresh.phase, 'threads');
    },
  );

  for (final recovering in [false, true]) {
    test(
      'Remote history enforces total twenty MiB atomically, recovery=$recovering',
      () async {
        final metadata =
            jsonDecode(disk['vioclass_twitch_whispers_v1_1']!) as Map;
        final largeText = 'x' * (33 * 1024 * 1024 ~/ 10);
        final peers = List.generate(
          6,
          (i) => TwitchWhisperConversation(
            userId: '${i + 2}',
            login: 'peer',
            displayName: 'Peer',
            draft: i == 0 ? 'keep draft' : '',
            unreadCount: i == 0 ? 2 : 0,
            messages: [
              TwitchWhisperMessage(
                id: 'base-$i',
                fromUserId: '${i + 2}',
                toUserId: '1',
                text: largeText,
                timestamp: DateTime.utc(2026, 10, 1),
                state: TwitchWhisperMessageState.received,
              ),
            ],
          ),
        );
        metadata['conversations'] = peers.map((p) => p.toJson()).toList();
        disk['vioclass_twitch_whispers_v1_1'] = jsonEncode(metadata);
        final bytesBefore = utf8
            .encode(jsonEncode(metadata['conversations']))
            .length;
        expect(bytesBefore, lessThan(20 * 1024 * 1024));
        var work = recovering ? await store.beginRecovery('1') : null;
        if (work != null) {
          await store.mergeThreadsPage(
            '1',
            TwitchWhisperThreadsPage(ownerId: '1', conversations: const []),
            recovery: work,
          );
          work = await store.recoveryCheckpoint('1');
        }
        final before = disk['vioclass_twitch_whispers_v1_1'];
        final peer = (await store.load('1')).first;
        final page = TwitchWhisperRemotePage(
          ownerId: '1',
          peerId: '2',
          nextCursor: 'quota-page',
          messages: [
            TwitchWhisperMessage(
              id: 'over-total',
              fromUserId: '2',
              toUserId: '1',
              text: 'y' * (3 * 1024 * 1024 ~/ 10),
              timestamp: DateTime.utc(2026, 10, 3),
              state: TwitchWhisperMessageState.received,
            ),
          ],
        );
        expect(
          utf8
              .encode(
                jsonEncode(
                  peer
                      .copyWith(messages: [...peer.messages, ...page.messages])
                      .toJson(),
                ),
              )
              .length,
          lessThan(4 * 1024 * 1024),
        );
        await expectLater(
          store.mergeRemotePage('1', peer, page, recovery: work),
          throwsA(isA<TwitchWhisperArchiveException>()),
        );
        expect(disk['vioclass_twitch_whispers_v1_1'], before);
        expect((await store.load('1')).first.draft, 'keep draft');
        expect((await store.load('1')).first.unreadCount, 2);
        expect(await store.receiveGapSince('1'), DateTime.utc(2026, 10, 1));
        if (work != null) {
          expect(
            (await store.recoveryCheckpoint('1'))!.toJson(),
            work.toJson(),
          );
        }
      },
    );
  }

  test(
    'Remote history cannot add the five hundred first peer or move a browsing cursor',
    () async {
      final metadata =
          jsonDecode(disk['vioclass_twitch_whispers_v1_1']!) as Map;
      metadata['conversations'] = List.generate(
        500,
        (i) => TwitchWhisperConversation(
          userId: '${i + 2}',
          login: 'peer',
          displayName: 'Peer',
          draft: 'keep',
        ).toJson(),
      );
      disk['vioclass_twitch_whispers_v1_1'] = jsonEncode(metadata);
      final before = disk['vioclass_twitch_whispers_v1_1'];
      final peer = TwitchWhisperConversation(
        userId: '999',
        login: 'extra',
        displayName: 'Extra',
      );
      await expectLater(
        store.mergeRemotePage(
          '1',
          peer,
          TwitchWhisperRemotePage(
            ownerId: '1',
            peerId: '999',
            nextCursor: 'next',
            messages: const [],
          ),
        ),
        throwsA(isA<TwitchWhisperArchiveException>()),
      );
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      expect((await store.threadsCheckpoint('1')).cursor, 'ui-list');
    },
  );

  test(
    'Receiving lifetime marker preserves earliest gap and all other archive metadata across stores',
    () async {
      final first = DateTime.utc(2026, 9, 1);
      expect(await store.beginReceiveSession('9', first), isNull);
      final restarted = newStore();
      expect(
        await restarted.beginReceiveSession(
          '9',
          first.add(const Duration(days: 1)),
        ),
        first,
      );
      expect(await store.receiveGapSince('9'), first);
      await store.beginReceiveSession('9', first.add(const Duration(days: 2)));
      expect(await store.receiveGapSince('9'), first);
      expect(await store.receiveGapSince('1'), DateTime.utc(2026, 10, 1));
      await store.beginReceiveSession('1', first);
      final work = await store.beginRecovery('1');
      await store.saveDraft(
        '1',
        (await store.load('1')).first,
        'preserved marker',
      );
      final metadata =
          jsonDecode(disk['vioclass_twitch_whispers_v1_1']!) as Map;
      expect(metadata['receiveSessionStartedAt'], first.toIso8601String());
      expect((await store.threadsCheckpoint('1')).cursor, 'ui-list');
      expect((await store.recoveryCheckpoint('1'))!.toJson(), work.toJson());
    },
  );

  test(
    'Invalid receive session marker and cancelled owner save do not overwrite archive',
    () async {
      final before = disk['vioclass_twitch_whispers_v1_1'];
      await store.beginReceiveSession(
        '1',
        DateTime.utc(2026, 10, 3),
        canApply: () => false,
      );
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      final metadata = jsonDecode(before!) as Map;
      for (final bad in [123, 'not-a-date', '2026-02-30T00:00:00.000Z']) {
        metadata['receiveSessionStartedAt'] = bad;
        final corrupt = jsonEncode(metadata);
        disk['vioclass_twitch_whispers_v1_1'] = corrupt;
        await expectLater(
          store.beginReceiveSession('1', DateTime.utc(2026, 10, 3)),
          throwsA(isA<TwitchWhisperArchiveException>()),
        );
        expect(disk['vioclass_twitch_whispers_v1_1'], corrupt);
      }
    },
  );

  test('Malformed persisted recovery is rejected without overwrite', () async {
    final work = await store.beginRecovery('1');
    final json = jsonDecode(disk['vioclass_twitch_whispers_v1_1']!) as Map;
    json['receiveRecovery'] = {...work.toJson(), 'peerIndex': 999};
    final corrupt = jsonEncode(json);
    disk['vioclass_twitch_whispers_v1_1'] = corrupt;
    await expectLater(store.beginRecovery('1'), throwsException);
    expect(disk['vioclass_twitch_whispers_v1_1'], corrupt);
  });

  test(
    'Owner change while reading rejects late discoveries without advancing checkpoint',
    () async {
      threads.gate = Completer<void>();
      var sameOwner = true;
      final running = runner().run('1', canApply: () => sameOwner);
      final rejected = expectLater(running, throwsException);
      while (threads.calls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final before = disk['vioclass_twitch_whispers_v1_1'];
      sameOwner = false;
      threads.gate!.complete();
      await rejected;
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      expect(disk.containsKey('vioclass_twitch_whispers_v1_9'), false);
    },
  );

  test(
    'Recovery history write failure preserves both message page and work cursor',
    () async {
      var work = await store.beginRecovery('1');
      await store.mergeThreadsPage(
        '1',
        await threads.page(ownerId: '1'),
        recovery: work,
      );
      work = (await store.recoveryCheckpoint('1'))!;
      await store.mergeThreadsPage(
        '1',
        await threads.page(ownerId: '1', cursor: work.cursor),
        recovery: work,
      );
      work = (await store.recoveryCheckpoint('1'))!;
      final peer = (await store.load('1')).first;
      final page = await history.page(ownerId: '1', peerId: '2');
      final before = disk['vioclass_twitch_whispers_v1_1'];
      failWrite = true;
      await expectLater(
        store.mergeRemotePage('1', peer, page, recovery: work),
        throwsStateError,
      );
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      failWrite = false;
      await store.mergeRemotePage('1', peer, page, recovery: work);
      expect((await store.recoveryCheckpoint('1'))!.cursor, 'older');
      expect((await store.load('1')).first.messages.single.id, '2-recent');
    },
  );

  test('Repeated cursor is rejected without modifying saved work', () async {
    var work = await store.beginRecovery('1');
    await store.mergeThreadsPage(
      '1',
      await threads.page(ownerId: '1'),
      recovery: work,
    );
    work = (await store.recoveryCheckpoint('1'))!;
    final before = disk['vioclass_twitch_whispers_v1_1'];
    await expectLater(
      store.mergeThreadsPage(
        '1',
        TwitchWhisperThreadsPage(
          ownerId: '1',
          requestedCursor: 'more',
          nextCursor: 'more',
          conversations: const [],
        ),
        recovery: work,
      ),
      throwsFormatException,
    );
    expect(disk['vioclass_twitch_whispers_v1_1'], before);
  });
}
