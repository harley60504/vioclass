import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vioclass/app.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_browse_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_stream_home_models.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_stream_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/watch/twitch_watch_page_navigation.dart';
import 'package:vioclass/features/twitch/presentation/mini_player/twitch_mini_player_controller.dart';
import 'package:vioclass/features/twitch/presentation/widgets/discovery/twitch_stream_card.dart';
import 'package:vioclass/features/twitch/presentation/widgets/home/twitch_stream_home_toolbar.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/player/twitch_watch_controls_overlay.dart';
import 'package:vioclass/features/twitch/services/notifications/twitch_app_notification_service.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_media_kit_player_host.dart';
import 'package:window_manager/window_manager.dart';

Future<void> _wait(
  WidgetTester tester,
  bool Function() ready,
  String phase, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  expect(ready(), isTrue, reason: phase);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Capture real product pages for the bilingual README', (
    tester,
  ) async {
    const destination = String.fromEnvironment('VIOCLASS_SCREENSHOTS_DIR');
    expect(destination, isNotEmpty);
    final output = Directory(destination);
    await output.create(recursive: true);
    final previousPrint = debugPrint;
    // Public documentation capture: never print saved session data or chat.
    debugPrint = (message, {wrapWidth}) {
      if (message?.startsWith('[ReadmeCapture]') == true) {
        previousPrint(message, wrapWidth: wrapWidth);
      }
    };
    addTearDown(() => debugPrint = previousPrint);
    await windowManager.ensureInitialized();
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setMinimumSize(const Size(380, 600));
    await windowManager.setSize(const Size(1440, 920));
    final boundaryKey = GlobalKey();
    Future<void> capture(String name) async {
      // Hide only transient toast presentation, preserving notification history.
      for (final item in twitchAppNotificationCenter.visibleItems) {
        twitchAppNotificationCenter.hideToast(item.id);
      }
      await tester.pump(const Duration(milliseconds: 450));
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final picture = await boundary.toImage(pixelRatio: 1.5);
      final png = await picture.toByteData(format: ui.ImageByteFormat.png);
      await File('${output.path}/$name.png').writeAsBytes(
        png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      );
      debugPrint(
        '[ReadmeCapture] saved $name ${picture.width}x${picture.height}',
      );
      picture.dispose();
    }

    try {
      await tester.pumpWidget(
        RepaintBoundary(key: boundaryKey, child: const VioClassApp()),
      );
      await _wait(
        tester,
        () => find.byType(TwitchStreamPage).evaluate().isNotEmpty,
        'home mounted',
      );
      final dynamic home = tester.state(find.byType(TwitchStreamPage));
      await _wait(
        tester,
        () => home.loadingLoginState == false,
        'session resolved without changing login',
      );
      tester
          .widget<TwitchStreamHomeToolbar>(find.byType(TwitchStreamHomeToolbar))
          .onSelectSection(TwitchHomeSection.browse);
      await _wait(
        tester,
        () => find.byType(TwitchBrowsePage).evaluate().isNotEmpty,
        'public browse mounted',
      );
      final browse = tester.state<TwitchBrowsePageState>(
        find.byType(TwitchBrowsePage),
      );
      await _wait(
        tester,
        () => !browse.loadingFirstPage && browse.loadedStreams.isNotEmpty,
        'public live content',
      );
      await tester.pump(const Duration(seconds: 4));
      await capture('desktop-browse');
      final cards = tester.widgetList<TwitchStreamCard>(
        find.byType(TwitchStreamCard),
      );
      final selected = cards.firstWhere((card) => !card.stream.isMature);
      selected.onTap();
      await _wait(
        tester,
        () => find.byType(TwitchWatchPage).evaluate().isNotEmpty,
        'live watch mounted',
      );
      final watch = tester.state<TwitchWatchPageState>(
        find.byType(TwitchWatchPage),
      );
      await _wait(
        tester,
        () {
          final player = watch.playerSession.playerOrNull;
          return !watch.loadingPlayer &&
              !watch.showOfflineChannelPlaceholder &&
              player?.state.playing == true &&
              (int.tryParse(player!.getProperty('video-params/h')) ?? 0) > 0;
        },
        'real live video decoded',
        timeout: const Duration(seconds: 50),
      );
      await tester.pump(const Duration(seconds: 4));
      // Synthetic Flutter pointer event, never the operating-system mouse.
      final pointer = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await pointer.addPointer(
        location: tester.getCenter(find.byType(WatchControlsOverlay)),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await capture('desktop-watch');
      await pointer.removePointer();
      await watch.leaveToMiniPlayer();
      await tester.pump(const Duration(seconds: 2));
      expect(TwitchMiniPlayerController.instance.isActive, isTrue);
      await capture('desktop-mini-player');
      TwitchMiniPlayerController.instance.close(pausePlayback: true);
      await windowManager.setSize(const Size(440, 920));
      await tester.pump(const Duration(seconds: 2));
      await capture('compact-browse');
    } finally {
      await tester.pumpWidget(const SizedBox());
      await TwitchMediaKitPlayerHost.disposeNow();
    }
  });
}
