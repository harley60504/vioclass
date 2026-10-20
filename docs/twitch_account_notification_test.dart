// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/twitch/api/notifications/twitch_account_notification_api.dart';
import '../lib/features/twitch/services/notifications/twitch_account_notification_monitor.dart';
import '../lib/features/twitch/services/notifications/twitch_app_notification_service.dart';
import '../lib/features/twitch/services/notifications/twitch_notification_history_store.dart';

Map<String, dynamic> node(
  String id, {
  String type = 'gift',
  String category = 'gift_subscriptions',
}) => {
  'node': {
    'id': id,
    'type': type,
    'category': category,
    'body': '**Alice** gifted a subscription.',
    'createdAt': '2026-10-09T00:00:00Z',
    'thumbnailURL': 'https://example.com/avatar.png',
  },
};
Map<String, dynamic> response(List<dynamic> edges, {String owner = '123'}) => {
  'data': {
    'currentUser': {
      'id': owner,
      'notifications': {'edges': edges},
    },
  },
};
List<TwitchAccountNotification> items(List<String> ids) =>
    TwitchAccountNotificationApi.parse(
      response(ids.map(node).toList()),
      ownerId: '123',
    );

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'only own gifts and earned badges; no Drops, promotions or lifecycle',
    () {
      final result = TwitchAccountNotificationApi.parse(
        response([
          node('gift'),
          node('badge', type: 'user_earned_badge', category: 'rewards'),
          node('drop', type: 'user_drop_reward', category: 'rewards'),
          node('ad', type: 'earned_badge', category: 'promotions'),
          node('old', type: 'earned_badge_lifecycle', category: 'rewards'),
          node('streak', type: 'watch_streak', category: 'rewards'),
        ]),
        ownerId: '123',
      );
      expect(result.map((e) => e.id), ['gift', 'badge']);
      expect(result.first.body, 'Alice gifted a subscription.');
      expect(result.last.kind, TwitchAccountNotificationKind.earnedBadge);
    },
  );

  test(
    'valid empty distinct from missing feed, GQL errors and wrong owner',
    () {
      expect(
        TwitchAccountNotificationApi.parse(response([]), ownerId: '123'),
        isEmpty,
      );
      for (final invalid in [
        {
          'errors': [
            {'message': 'denied'},
          ],
          ...response([]),
        },
        {
          'data': {
            'currentUser': {'id': '123'},
          },
        },
        response([], owner: '456'),
        response([
          {'node': null},
        ]),
        response([
          {
            'node': {...node('bad')['node'], 'createdAt': 'invalid'},
          },
        ]),
      ]) {
        expect(
          () => TwitchAccountNotificationApi.parse(invalid, ownerId: '123'),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'first snapshot silent, next only new IDs, persisted across restart',
    () async {
      var snapshot = items(['old']);
      final sent = <String>[];
      TwitchAccountNotificationMonitor make() =>
          TwitchAccountNotificationMonitor(
            fetch: (_) async => snapshot,
            notify: (item) async => sent.add(item.id),
          );
      final monitor = make()..start('123');
      addTearDown(monitor.stop);
      await settle();
      expect(sent, isEmpty);
      snapshot = items(['new', 'new', 'old']);
      await monitor.checkNow();
      expect(sent, ['new']);
      monitor.stop();
      final restarted = make()..start('123');
      addTearDown(restarted.stop);
      await settle();
      expect(sent, ['new']);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(
          prefs.getString(TwitchAccountNotificationMonitor.storageKey('123'))!,
        ),
        ['new', 'old'],
      );
    },
  );

  test(
    'failed first fetch does not seed; failed later fetch preserves baseline',
    () async {
      var fail = true;
      var snapshot = items(['old']);
      final sent = <String>[];
      final monitor = TwitchAccountNotificationMonitor(
        fetch: (_) async {
          if (fail) throw StateError('offline');
          return snapshot;
        },
        notify: (item) async => sent.add(item.id),
      )..start('123');
      addTearDown(monitor.stop);
      await settle();
      final prefs = await SharedPreferences.getInstance();
      final key = TwitchAccountNotificationMonitor.storageKey('123');
      expect(prefs.getString(key), isNull);
      fail = false;
      await monitor.checkNow();
      expect(sent, isEmpty);
      final baseline = prefs.getString(key);
      fail = true;
      await monitor.checkNow();
      expect(prefs.getString(key), baseline);
      fail = false;
      snapshot = items(['new']);
      await monitor.checkNow();
      expect(sent, ['new']);
    },
  );

  test(
    'account switch drops in-flight response and seeds new account silently',
    () async {
      final oldRequest = Completer<List<TwitchAccountNotification>>();
      final sent = <String>[];
      final monitor = TwitchAccountNotificationMonitor(
        fetch: (owner) =>
            owner == '123' ? oldRequest.future : Future.value(items(['other'])),
        notify: (item) async => sent.add(item.id),
      )..start('123');
      addTearDown(monitor.stop);
      monitor.start('456');
      await settle();
      oldRequest.complete(items(['stale']));
      await settle();
      final prefs = await SharedPreferences.getInstance();
      expect(sent, isEmpty);
      expect(
        prefs.getString(TwitchAccountNotificationMonitor.storageKey('123')),
        isNull,
      );
      expect(
        prefs.getString(TwitchAccountNotificationMonitor.storageKey('456')),
        isNotNull,
      );
    },
  );

  test('cap IDs at 200, malformed baseline silently reseeds', () async {
    SharedPreferences.setMockInitialValues({
      TwitchAccountNotificationMonitor.storageKey('123'): 'broken json',
    });
    final sent = <String>[];
    final monitor = TwitchAccountNotificationMonitor(
      fetch: (_) async => items(List.generate(210, (i) => '$i')),
      notify: (item) async => sent.add(item.id),
    )..start('123');
    addTearDown(monitor.stop);
    await settle();
    final prefs = await SharedPreferences.getInstance();
    expect(sent, isEmpty);
    expect(
      (jsonDecode(
                prefs.getString(
                  TwitchAccountNotificationMonitor.storageKey('123'),
                )!,
              )
              as List)
          .length,
      200,
    );
  });

  test(
    'account reward history restores owner and prunes on account switch',
    () async {
      final center = TwitchAppNotificationCenter(
        historyStore: TwitchNotificationHistoryStore(),
      );
      await center.loadHistory();
      center.show(
        title: 'gift',
        message: 'gift',
        category: TwitchAppNotificationCategory.giftSubscription,
        accountOwnerId: '123',
      );
      await center.flushHistory();
      final restored = TwitchAppNotificationCenter(
        historyStore: TwitchNotificationHistoryStore(),
      );
      await restored.loadHistory();
      expect(restored.items.single.accountOwnerId, '123');
      expect(restored.visibleItems, isEmpty);
      restored.retainAccountOwner('456');
      expect(restored.items, isEmpty);
      await restored.flushHistory();
      center.dispose();
      restored.dispose();
    },
  );
}
