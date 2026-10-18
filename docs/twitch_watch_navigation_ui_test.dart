// ignore_for_file: avoid_relative_lib_imports
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/models/discovery/twitch_live_stream.dart';
import '../lib/features/twitch/models/discovery/twitch_stream_header_metadata.dart';
import '../lib/features/twitch/presentation/navigation/twitch_route_observer.dart';
import '../lib/features/twitch/presentation/widgets/discovery/twitch_stream_card.dart';
import '../lib/features/twitch/presentation/widgets/notifications/twitch_app_notification_overlay.dart';
import '../lib/features/twitch/presentation/widgets/watch/player/twitch_watch_top_action_bar.dart';
import '../lib/features/twitch/presentation/widgets/watch/twitch_watch_responsive_body.dart';

void main() {
  testWidgets('streamer info and surrounding space open About', (tester) async {
    var about = 0;
    var stream = 0;
    final live = TwitchLiveStream.fromHelixJson({
      'id': 'live',
      'user_id': '7',
      'user_login': 'fixture',
      'user_name': 'Fixture',
      'title': 'live',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 380,
            height: 360,
            child: TwitchStreamCard(
              stream: live,
              onTap: () => stream++,
              onOpenChannel: () => about++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('channel-avatar-fixture')));
    expect(about, 1);
    expect(stream, 0);
    await tester.tap(find.text('Fixture'));
    await tester.tap(find.text('fixture'));
    final footer = tester.getRect(
      find.byKey(const ValueKey('channel-about-fixture')),
    );
    await tester.tapAt(footer.centerRight - const Offset(2, 0));
    expect(about, 4);
    expect(stream, 0);
    await tester.tap(find.byType(AspectRatio));
    expect(stream, 1);
    expect(about, 4);
  });

  testWidgets('window navigation works outside Navigator Overlay', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const channel = MethodChannel('window_manager');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => false,
    );
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });
    var backs = 0;
    var homes = 0;
    twitchRouteObserver.watchNavigation.value = TwitchWatchFrameNavigation(
      onBack: () => backs++,
      onHome: () => homes++,
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => TwitchAppNotificationOverlay(child: child!),
        home: const SizedBox(),
      ),
    );
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    for (final icon in [Icons.arrow_back_rounded, Icons.home_rounded]) {
      await mouse.moveTo(tester.getCenter(find.byIcon(icon)));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(icon));
    }
    expect(backs, 1);
    expect(homes, 1);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    twitchRouteObserver.watchNavigation.value = null;
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('frame navigation follows watch routes, not modal sheets', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final observer = TwitchRouteObserver();
    final home = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    final watch = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    final dialog = DialogRoute<void>(
      context: tester.element(find.byType(SizedBox).first),
      builder: (_) => const SizedBox(),
    );
    var backs = 0;
    final actions = TwitchWatchFrameNavigation(
      onBack: () => backs++,
      onHome: () {},
    );
    observer.didPush(home, null);
    observer.didPush(watch, home);
    observer.registerWatch(watch, actions);
    await tester.pump();
    expect(observer.watchNavigation.value, same(actions));
    observer.watchNavigation.value!.onBack();
    expect(backs, 1);
    observer.didPush(dialog, watch);
    await tester.pump();
    expect(observer.watchNavigation.value, isNull);
    observer.didPop(dialog, watch);
    await tester.pump();
    expect(observer.watchNavigation.value, same(actions));
    observer.didPop(watch, home);
    observer.unregisterWatch(watch);
    await tester.pump();
    expect(observer.watchNavigation.value, isNull);
  });

  testWidgets('watch header can leave navigation to the window frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WatchTopActionBar(
            metadata: const TwitchStreamHeaderMetadata(channelLogin: 'fixture'),
            isFollowing: false,
            followBusy: false,
            showNavigation: false,
            onBack: () {},
            onHome: () {},
            onToggleFollow: null,
            onSubscribe: null,
          ),
        ),
      ),
    );
    expect(find.byTooltip('返回'), findsNothing);
    expect(find.byTooltip('回主畫面'), findsNothing);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('phone long content swipes and returns on $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: TwitchWatchResponsiveBody(
              chatVisible: true,
              chatPanelWidth: 300,
              chatPanelRatio: .25,
              minChatPanelWidth: 200,
              maxEffectiveMinChatPanelWidth: 300,
              maxChatPanelWidth: 500,
              minChatPanelRatio: .2,
              minStoredChatPanelRatio: .15,
              maxChatPanelRatio: .5,
              player: const ColoredBox(
                key: ValueKey('video'),
                color: Colors.black,
              ),
              chat: const Text('chat'),
              belowPlayer: const SizedBox(
                height: 1000,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text('about-content'),
                ),
              ),
              onSetChatPanelWidthForViewport:
                  ({required viewportWidth, required value}) {},
              onPersistChatPanelWidth: () {},
            ),
          ),
        ),
      );
      expect(find.text('about-content').hitTestable(), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('video')),
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      expect(find.text('about-content').hitTestable(), findsOneWidget);
      await tester.drag(find.text('about-content'), const Offset(0, 180));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('video')).hitTestable(), findsOneWidget);
      expect(find.text('chat'), findsOneWidget);
    });
  }
}
