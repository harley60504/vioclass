// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/twitch/models/discovery/twitch_live_stream.dart';
import '../lib/features/twitch/services/notifications/twitch_app_notification_service.dart';
import '../lib/features/twitch/services/notifications/twitch_live_notification_policy.dart';
import '../lib/features/twitch/services/notifications/twitch_notification_history_store.dart';
import '../lib/features/twitch/services/notifications/twitch_system_notification_service.dart';
import '../lib/features/twitch/presentation/settings/vioclass_update_controller.dart';
import '../lib/features/twitch/services/update/vioclass_update_service.dart';
import '../lib/features/twitch/presentation/widgets/notifications/twitch_notification_card.dart';

TwitchLiveStream live(String login, {String id = 'stream'}) => TwitchLiveStream(
  id: id,
  userId: login,
  userLogin: login,
  userName: login,
  gameId: '',
  gameName: '',
  title: '',
  viewerCount: 1,
  startedAt: null,
  language: '',
  thumbnailUrl: '',
  tags: const [],
  isMature: false,
);

class MemoryHistory extends TwitchNotificationHistoryStore {
  List<Map<String, dynamic>> entries = [];
  Completer<List<Map<String, dynamic>>>? pendingRead;
  @override
  Future<List<Map<String, dynamic>>> read() async =>
      pendingRead == null ? entries : await pendingRead!.future;
  @override
  Future<void> write(List<Map<String, dynamic>> value) async => entries = value;
}

class UpdateSource extends VioClassUpdateService {
  String version = 'v2.0.0';
  int checks = 0;
  @override
  Future<VioClassUpdateInfo> checkLatest() async {
    checks++;
    return VioClassUpdateInfo(
      currentVersion: '1.0.0',
      updateAvailable: true,
      release: VioClassRelease(
        tagName: version,
        version: version.substring(1),
        name: version,
        body: '',
        htmlUrl: '',
        publishedAt: null,
        assets: const [],
      ),
    );
  }
}

void main() {
  test(
    'switching known accounts removes only the previous owner whisper records',
    () async {
      final store = MemoryHistory();
      final center = TwitchAppNotificationCenter(historyStore: store);
      await center.loadHistory();
      center.show(
        title: 'old owner',
        message: '',
        whisperTarget: const TwitchWhisperNotificationTarget(
          ownerId: '123',
          peerId: '456',
        ),
      );
      center.show(
        title: 'new owner',
        message: '',
        whisperTarget: const TwitchWhisperNotificationTarget(
          ownerId: '789',
          peerId: '456',
        ),
      );
      center.showInfo(title: 'general', message: '');
      center.retainWhisperOwner('789');
      await center.flushHistory();
      expect(center.items.map((item) => item.title), ['general', 'new owner']);
      expect(store.entries, hasLength(2));
      center.dispose();
    },
  );
  test('startup and restart seed live channels silently', () {
    final policy = TwitchLiveNotificationPolicy();
    expect(policy.observe([live('a'), live('b')]), isEmpty);
    expect(policy.observe([live('a'), live('b')]), isEmpty);
    expect(
      policy.observe([live('a'), live('b'), live('c')]).single.channelLogin,
      'c',
    );
    policy.reset();
    expect(policy.observe([live('a'), live('b'), live('c')]), isEmpty);
  });
  test('changing stream ID while live does not announce again', () {
    final policy = TwitchLiveNotificationPolicy();
    policy.observe([live('a', id: 'old')]);
    expect(policy.observe([live('a', id: 'new')]), isEmpty);
  });
  test('brief reconnect is deduplicated for five minutes', () {
    var clock = DateTime(2026, 10, 9);
    final policy = TwitchLiveNotificationPolicy(clock: () => clock);
    policy.observe([]);
    expect(policy.observe([live('a')]), hasLength(1));
    policy.observe([]);
    clock = clock.add(const Duration(minutes: 1));
    expect(policy.observe([live('A')]), isEmpty);
    policy.observe([]);
    clock = clock.add(const Duration(minutes: 4));
    expect(policy.observe([live('a')]), hasLength(1));
  });
  test('duplicate rows in one snapshot produce one event', () {
    final policy = TwitchLiveNotificationPolicy();
    policy.observe([]);
    expect(policy.observe([live('a'), live('A')]), hasLength(1));
  });
  test('blank channel identity is not an event', () {
    final policy = TwitchLiveNotificationPolicy();
    policy.observe([]);
    expect(policy.observe([live('')]), isEmpty);
  });
  test(
    'restored history never replays toasts and retains read status',
    () async {
      final store = MemoryHistory();
      final first = TwitchAppNotificationCenter(historyStore: store);
      await first.loadHistory();
      first.showInfo(title: 'record', message: 'body');
      first.markAllRead();
      await first.flushHistory();
      first.dispose();
      final second = TwitchAppNotificationCenter(historyStore: store);
      await second.loadHistory();
      expect(second.items.single.title, 'record');
      expect(second.visibleItems, isEmpty);
      expect(second.unreadCount, 0);
      second.dispose();
    },
  );
  test(
    'seven-day expiry, future timestamps and malformed entries are ignored',
    () async {
      final store = MemoryHistory();
      final center = TwitchAppNotificationCenter(historyStore: store);
      await center.loadHistory();
      center.showInfo(title: 'valid', message: 'ok');
      await center.flushHistory();
      final valid = store.entries.single;
      store.entries = [
        {
          ...valid,
          'title': 'expired',
          'createdAt': DateTime.now()
              .subtract(const Duration(days: 7, seconds: 1))
              .toIso8601String(),
        },
        {
          ...valid,
          'title': 'future',
          'createdAt': DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
        },
        {'bad': true},
        valid,
      ];
      center.dispose();
      final restored = TwitchAppNotificationCenter(historyStore: store);
      await restored.loadHistory();
      expect(restored.items.map((item) => item.title), ['valid']);
      restored.dispose();
    },
  );
  test('history is bounded to twenty and clearing persists', () async {
    final store = MemoryHistory();
    final center = TwitchAppNotificationCenter(historyStore: store);
    await center.loadHistory();
    for (var i = 0; i < 25; i++) {
      center.showInfo(title: '$i', message: '');
    }
    await center.flushHistory();
    expect(store.entries, hasLength(20));
    center.clear();
    await center.flushHistory();
    expect(store.entries, isEmpty);
    center.dispose();
  });
  test('clear while loading cannot resurrect old history', () async {
    final store = MemoryHistory()..pendingRead = Completer();
    final center = TwitchAppNotificationCenter(historyStore: store);
    final loading = center.loadHistory();
    center.clear();
    store.pendingRead!.complete([
      {
        'title': 'old',
        'message': '',
        'category': 'general',
        'type': 'info',
        'createdAt': DateTime.now().toIso8601String(),
      },
    ]);
    await loading;
    await center.flushHistory();
    expect(center.items, isEmpty);
    expect(store.entries, isEmpty);
    center.dispose();
  });
  test('restored live card retains its metadata and action', () async {
    final store = MemoryHistory();
    final center = TwitchAppNotificationCenter(historyStore: store);
    await center.loadHistory();
    center.show(
      title: 'live',
      message: '',
      category: TwitchAppNotificationCategory.live,
      liveStream: live('a'),
    );
    await center.flushHistory();
    center.dispose();
    var opened = '';
    final restored = TwitchAppNotificationCenter(historyStore: store);
    await restored.loadHistory(
      onLiveOpen: (stream) async => opened = stream.channelLogin,
    );
    await restored.items.single.onOpen!();
    expect(opened, 'a');
    expect(restored.visibleItems, isEmpty);
    restored.dispose();
  });
  test('SharedPreferences round trip is notification metadata only', () async {
    SharedPreferences.setMockInitialValues({});
    final store = TwitchNotificationHistoryStore();
    await store.write([
      {'title': 'safe'},
    ]);
    expect(await store.read(), [
      {'title': 'safe'},
    ]);
  });
  testWidgets('point bursts wait three quiet seconds and sum channels', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    twitchAppNotificationCenter.clear();
    final service = twitchSystemNotificationService;
    service.clearPendingPointNotifications();
    service.recordChannelPointsEarned(channel: 'a', points: 10);
    await tester.pump(const Duration(seconds: 2));
    service.recordChannelPointsEarned(channel: 'a', points: 50);
    service.recordChannelPointsEarned(channel: 'b', points: 20);
    await tester.pump(const Duration(seconds: 2));
    expect(twitchAppNotificationCenter.items, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(twitchAppNotificationCenter.items.single.title, '忠誠點數 +80');
    expect(twitchAppNotificationCenter.items.single.message, 'a +60、b +20');
    service.clearPendingPointNotifications();
    twitchAppNotificationCenter.clear();
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets(
    'clearing a pending burst on logout prevents a delayed notification',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      twitchAppNotificationCenter.clear();
      twitchSystemNotificationService.recordChannelPointsEarned(
        channel: 'a',
        points: 50,
      );
      twitchSystemNotificationService.clearPendingPointNotifications();
      await tester.pump(const Duration(seconds: 4));
      expect(twitchAppNotificationCenter.items, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  test(
    'automatic updates announce each version once across restarts',
    () async {
      SharedPreferences.setMockInitialValues({
        'vioclass_auto_check_updates_v1': true,
      });
      var announced = 0;
      final source = UpdateSource();
      final controller = VioClassUpdateController(
        service: source,
        onNewVersion: (_) async => announced++,
      );
      await controller.load();
      await controller.checkNow(announce: true);
      await controller.checkNow(announce: true);
      expect(announced, 1);
      controller.dispose();
      final nextSource = UpdateSource();
      final restarted = VioClassUpdateController(
        service: nextSource,
        onNewVersion: (_) async => announced++,
      );
      await restarted.load();
      await restarted.checkNow(announce: true);
      expect(announced, 1);
      nextSource.version = 'v2.0.1';
      await restarted.checkNow(announce: true);
      expect(announced, 2);
      restarted.dispose();
    },
  );
  test(
    'manual update check and disabled automatic checks do not announce',
    () async {
      SharedPreferences.setMockInitialValues({
        'vioclass_auto_check_updates_v1': false,
      });
      var announced = 0;
      final controller = VioClassUpdateController(
        service: UpdateSource(),
        onNewVersion: (_) async => announced++,
      );
      await controller.load();
      await controller.checkNow();
      await controller.checkNow(announce: true);
      expect(announced, 0);
      controller.dispose();
    },
  );
  testWidgets(
    'notification card works above the Navigator without an Overlay ancestor',
    (tester) async {
      final item = TwitchAppNotification(
        id: 1,
        title: 'live',
        message: 'body',
        type: TwitchAppNotificationType.info,
        createdAt: DateTime.now(),
        duration: TwitchAppNotificationCenter.liveDuration,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: const SizedBox(),
          builder: (context, child) => Stack(
            children: [
              child!,
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 380,
                  child: TwitchNotificationCard(item: item, onDismiss: () {}),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
