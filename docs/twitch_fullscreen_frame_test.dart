import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';
import 'package:vioclass/features/twitch/presentation/navigation/twitch_route_observer.dart';
import 'package:vioclass/features/twitch/presentation/widgets/notifications/twitch_app_notification_overlay.dart';
import 'package:vioclass/features/twitch/services/window/twitch_fullscreen_controller.dart';

void main() {
  testWidgets(
    'Frame returns after repeated fullscreen exits without a native leave event',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('window_manager');
      var fullscreen = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'isMaximized':
            return false;
          case 'isFullScreen':
            return fullscreen;
          case 'setFullScreen':
            fullscreen = call.arguments['isFullScreen'] as bool;
            return null;
          case 'ensureInitialized':
          case 'focus':
            return null;
          default:
            throw StateError('Unexpected window call: ${call.method}');
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      var backs = 0;
      twitchRouteObserver.watchNavigation.value = TwitchWatchFrameNavigation(
        onBack: () => backs++,
        onHome: () {},
      );
      addTearDown(() => twitchRouteObserver.watchNavigation.value = null);
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: Text('player')),
          builder: (context, child) =>
              TwitchAppNotificationOverlay(child: child!),
        ),
      );
      await tester.pumpAndSettle();
      for (var cycle = 0; cycle < 3; cycle++) {
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        await TwitchFullscreenController.setFullscreen(true);
        for (final listener in windowManager.listeners) {
          listener.onWindowEnterFullScreen();
        }
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.close_rounded), findsNothing);
        await TwitchFullscreenController.setFullscreen(false);
        await tester.pumpAndSettle();
        expect(
          find.byIcon(Icons.close_rounded),
          findsOneWidget,
          reason: 'Exit cycle $cycle must restore the frame',
        );
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        expect(backs, cycle + 1);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'Late window queries and stale enter events cannot hide the restored frame',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('window_manager');
      final initialQuery = Completer<bool>();
      var queries = 0;
      var fullscreen = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'isMaximized':
            return false;
          case 'isFullScreen':
            return ++queries == 1 ? initialQuery.future : fullscreen;
          case 'setFullScreen':
            fullscreen = call.arguments['isFullScreen'] as bool;
            return null;
          case 'ensureInitialized':
          case 'focus':
            return null;
          default:
            throw StateError('Unexpected window call: ${call.method}');
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: Text('player')),
          builder: (context, child) =>
              TwitchAppNotificationOverlay(child: child!),
        ),
      );
      await tester.pump();
      await TwitchFullscreenController.setFullscreen(true);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      initialQuery.complete(false);
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.close_rounded),
        findsNothing,
        reason: 'An old query cannot undo the latest request',
      );
      await TwitchFullscreenController.setFullscreen(false);
      for (final listener in windowManager.listeners) {
        listener.onWindowEnterFullScreen();
      }
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.close_rounded),
        findsOneWidget,
        reason: 'A late enter event must read current native state',
      );
      fullscreen = true;
      for (final listener in windowManager.listeners) {
        listener.onWindowEnterFullScreen();
      }
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      fullscreen = false;
      await TwitchFullscreenController.exitFullscreen();
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.close_rounded),
        findsOneWidget,
        reason: 'An already-windowed request must also synchronize the frame',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
