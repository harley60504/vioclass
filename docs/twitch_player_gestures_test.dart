// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/twitch/presentation/watch/controllers/twitch_playback_timeline_controller.dart';
import '../lib/features/twitch/presentation/settings/twitch_player_settings_controller.dart';
import '../lib/features/twitch/presentation/widgets/watch/player/twitch_player_seek_gestures.dart';
import '../lib/features/twitch/presentation/widgets/watch/player/twitch_player_volume_control.dart';

class _Clock extends TwitchPlaybackTimelineController {
  bool canSeek = true;
  TwitchPlaybackTimelineMode mode = TwitchPlaybackTimelineMode.vod;
  @override
  TwitchPlaybackTimelineSnapshot get snapshot => TwitchPlaybackTimelineSnapshot(
    mode: mode,
    position: const Duration(seconds: 50),
    duration: const Duration(seconds: 100),
    isAtLiveEdge: false,
    canSeek: canSeek,
    seeking: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('double-tap feedback accumulates and resets after a pause', (
    tester,
  ) async {
    final clock = _Clock();
    addTearDown(clock.dispose);
    final jumps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: PlayerSeekGestures(
              controller: clock,
              doubleTapEnabled: true,
              dragEnabled: false,
              limitToLiveBuffer: false,
              enabled: true,
              onJump: (seconds) {
                jumps.add(seconds);
                return true;
              },
              onSeek: (_) {},
            ),
          ),
        ),
      ),
    );
    Future<void> twice(Offset point) async {
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 70));
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 80));
    }

    await twice(const Offset(300, 100));
    expect(find.text('+10s'), findsOneWidget);
    await twice(const Offset(300, 100));
    expect(find.text('+20s'), findsOneWidget);
    await twice(const Offset(300, 100));
    expect(find.text('+30s'), findsOneWidget);
    await twice(const Offset(100, 100));
    expect(find.text('-10s'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await twice(const Offset(300, 100));
    expect(find.text('+10s'), findsOneWidget);
    expect(jumps, [10, 10, 10, -10, 10]);
    await tester.pump(const Duration(seconds: 1));
  });
  test(
    'all seeking preferences default on and persist independently',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = TwitchPlayerSettingsController();
      addTearDown(settings.dispose);
      await settings.reloadGestures();
      expect(
        settings.keyboardSeekEnabled &&
            settings.doubleTapSeekEnabled &&
            settings.dragSeekEnabled,
        true,
      );
      await settings.setDoubleTapSeekEnabled(false);
      await settings.setDragSeekEnabled(false);
      final restored = TwitchPlayerSettingsController();
      addTearDown(restored.dispose);
      await restored.reloadGestures();
      expect(restored.keyboardSeekEnabled, true);
      expect(restored.doubleTapSeekEnabled, false);
      expect(restored.dragSeekEnabled, false);
      await restored.setKeyboardSeekEnabled(false);
      expect(restored.keyboardSeekEnabled, false);
    },
  );
  for (final enabled in [true, false]) {
    testWidgets('video double tap left/right enabled=$enabled', (tester) async {
      final clock = _Clock();
      addTearDown(clock.dispose);
      final jumps = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: PlayerSeekGestures(
                controller: clock,
                enabled: true,
                doubleTapEnabled: enabled,
                dragEnabled: enabled,
                limitToLiveBuffer: false,
                onJump: (s) {
                  jumps.add(s);
                  return true;
                },
                onSeek: (_) {},
              ),
            ),
          ),
        ),
      );
      for (final x in [50.0, 250.0]) {
        await tester.tapAt(Offset(x, 150));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tapAt(Offset(x, 150));
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(jumps, enabled ? [-10, 10] : []);
      await tester.pump(const Duration(seconds: 1));
    });
    testWidgets('drag previews and only seeks on release enabled=$enabled', (
      tester,
    ) async {
      final clock = _Clock();
      addTearDown(clock.dispose);
      final targets = <Duration>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: PlayerSeekGestures(
                controller: clock,
                enabled: true,
                doubleTapEnabled: enabled,
                dragEnabled: enabled,
                limitToLiveBuffer: false,
                onJump: (_) => true,
                onSeek: targets.add,
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(const Offset(100, 150));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(targets, isEmpty);
      await gesture.up();
      await tester.pump();
      expect(targets.length, enabled ? 1 : 0);
      if (enabled) {
        expect(targets.single, greaterThan(const Duration(seconds: 50)));
      }
      await tester.pump(const Duration(seconds: 1));
    });
  }
  testWidgets('limited DVR clamps dragging and cancelling never seeks', (
    tester,
  ) async {
    final clock = _Clock()..mode = TwitchPlaybackTimelineMode.liveDvr;
    addTearDown(clock.dispose);
    final targets = <Duration>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: PlayerSeekGestures(
              controller: clock,
              enabled: true,
              doubleTapEnabled: true,
              dragEnabled: true,
              limitToLiveBuffer: true,
              onJump: (_) => true,
              onSeek: targets.add,
            ),
          ),
        ),
      ),
    );
    var gesture = await tester.startGesture(const Offset(250, 150));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-150, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(targets.single, const Duration(seconds: 80));
    gesture = await tester.startGesture(const Offset(100, 150));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pump();
    expect(targets.length, 1);
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets(
    'volume hover bridges to popup, stays in bounds and closes on exit',
    (tester) async {
      tester.view.physicalSize = const Size(320, 280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: PlayerVolumeButton(
                muted: false,
                volume: 50,
                onVolumeChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      await mouse.moveTo(tester.getCenter(find.byTooltip('音量')));
      await tester.pumpAndSettle();
      final popup = find.byKey(const ValueKey('player-volume-popover'));
      expect(popup, findsOneWidget);
      final popupRect = tester.getRect(popup);
      expect(popupRect.left, greaterThanOrEqualTo(0));
      expect(popupRect.right, lessThanOrEqualTo(320));
      expect(popupRect.top, greaterThanOrEqualTo(0));
      expect(
        popupRect.bottom,
        lessThan(tester.getRect(find.byTooltip('音量')).top),
      );
      await mouse.moveTo(popupRect.center);
      await tester.pump(const Duration(milliseconds: 300));
      expect(popup, findsOneWidget);
      // Hover the popup's mute button long enough for a tooltip to activate.
      // Unlike the anchor, this button lives under a composited follower.
      await mouse.moveTo(
        tester.getCenter(
          find.descendant(of: popup, matching: find.byType(IconButton)),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(popup, findsOneWidget);
      await mouse.moveTo(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 300));
      expect(popup, findsNothing);
      await mouse.removePointer();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('volume is a single button and slider opens on demand', (
    tester,
  ) async {
    final values = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerVolumeButton(
            muted: false,
            volume: 50,
            onVolumeChanged: values.add,
            onToggleMute: () {},
          ),
        ),
      ),
    );
    expect(find.byType(Slider), findsNothing);
    await tester.tap(find.byTooltip('音量'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    final popup = find.byKey(const ValueKey('player-volume-popover'));
    expect(tester.getRect(popup).width, 52);
    expect(tester.getRect(popup).height, lessThanOrEqualTo(180));
    await tester.drag(find.byType(Slider), const Offset(0, -35));
    await tester.pumpAndSettle();
    expect(values, isNotEmpty);
    expect(values.last, greaterThan(50));
    await tester.tapAt(const Offset(250, 300));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
