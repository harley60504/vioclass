// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/models/discovery/twitch_live_stream.dart';
import '../lib/features/twitch/services/notifications/twitch_app_notification_service.dart';
import '../lib/features/twitch/services/notifications/twitch_system_notification_service.dart';
import '../lib/features/twitch/presentation/widgets/notifications/twitch_notification_card.dart';
import '../lib/features/twitch/presentation/widgets/shared/twitch_cached_image_layer.dart';

const stream = TwitchLiveStream(
  id: 'live-test',
  userId: '123',
  userLogin: 'tester',
  userName: '測試實況主',
  gameId: '456',
  gameName: '測試遊戲',
  title: '今天一起玩遊戲！',
  viewerCount: 1200,
  startedAt: null,
  language: 'zh',
  thumbnailUrl: '',
  tags: [],
  isMature: false,
  profileImageUrl: '',
);

TwitchAppNotification notification({
  TwitchAppNotificationCategory category = TwitchAppNotificationCategory.live,
  bool clickable = false,
}) => TwitchAppNotification(
  id: 1,
  title: '測試實況主 開台了',
  message: '舊的合併內文',
  type: TwitchAppNotificationType.info,
  createdAt: DateTime(2026, 10, 9, 20),
  duration: const Duration(seconds: 8),
  category: category,
  liveStream: category == TwitchAppNotificationCategory.live ? stream : null,
  avatarUrls: category == TwitchAppNotificationCategory.live
      ? const ['']
      : const [],
  onOpen: clickable ? () async {} : null,
);

Widget host(Widget child, {double width = 380, double scale = 1}) =>
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 700),
                textScaler: TextScaler.linear(scale),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );

void main() {
  for (final width in [220.0, 280.0, 380.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('live notification $width px at ${scale}x text', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            TwitchNotificationCard(
              item: notification(clickable: true),
              onDismiss: () {},
              onOpen: () {},
            ),
            width: width,
            scale: scale,
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('測試遊戲'), findsOneWidget);
        expect(find.text('今天一起玩遊戲！'), findsOneWidget);
        expect(find.text('舊的合併內文'), findsNothing);
        expect(find.byType(TwitchCachedImageLayer), findsOneWidget);
        expect(find.text('觀看直播'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  for (final category in TwitchAppNotificationCategory.values) {
    testWidgets('shared appearance for $category', (tester) async {
      await tester.pumpWidget(
        host(
          TwitchNotificationCard(
            item: notification(category: category),
            onDismiss: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('watch and dismiss remain independent', (tester) async {
    var opens = 0;
    var dismisses = 0;
    await tester.pumpWidget(
      host(
        TwitchNotificationCard(
          item: notification(clickable: true),
          onOpen: () => opens++,
          onDismiss: () => dismisses++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('觀看直播'));
    expect(opens, 1);
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(opens, 1);
    expect(dismisses, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('multi-live avatars have fallback and are bounded', (
    tester,
  ) async {
    final center = TwitchAppNotificationCenter();
    center.show(
      title: '4 個頻道開台了',
      message: '甲、乙、丙、丁',
      category: TwitchAppNotificationCategory.live,
      avatarUrls: ['', '', '', ''],
    );
    expect(center.items.single.avatarUrls.length, 3);
    await tester.pumpWidget(
      host(
        TwitchNotificationCard(item: center.items.single, onDismiss: () {}),
        width: 220,
        scale: 2,
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(TwitchCachedImageLayer), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    center.dispose();
  });
  testWidgets('Windows service propagates live metadata and expires normally', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    twitchAppNotificationCenter.clear();
    await twitchSystemNotificationService.showStreamLive(
      stream,
      onOpen: () async {},
    );
    final item = twitchAppNotificationCenter.items.single;
    expect(item.liveStream, same(stream));
    expect(item.category, TwitchAppNotificationCategory.live);
    expect(item.onOpen, isNotNull);
    expect(item.avatarUrls, ['']);
    await tester.pump(TwitchAppNotificationCenter.liveDuration);
    expect(twitchAppNotificationCenter.visibleItems, isEmpty);
    expect(twitchAppNotificationCenter.items, hasLength(1));
    twitchAppNotificationCenter.clear();
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets(
    'Windows points and whispers get proper category without changing target',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      twitchAppNotificationCenter.clear();
      await twitchSystemNotificationService.showChannelPoints(
        title: '點數增加',
        message: '+50',
      );
      expect(
        twitchAppNotificationCenter.items.single.category,
        TwitchAppNotificationCategory.channelPoints,
      );
      await twitchSystemNotificationService.showWhisper(
        sender: 'Tester',
        userId: '456',
        ownerId: '123',
      );
      final item = twitchAppNotificationCenter.items.first;
      expect(item.category, TwitchAppNotificationCategory.whisper);
      expect(item.whisperTarget!.payload, 'whisper:123:456');
      twitchAppNotificationCenter.clear();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
