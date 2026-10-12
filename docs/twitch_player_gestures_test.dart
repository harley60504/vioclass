// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member
import 'package:flutter/material.dart';
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
    await tester.drag(find.byType(Slider), const Offset(50, 0));
    await tester.pumpAndSettle();
    expect(values, isNotEmpty);
    expect(tester.takeException(), isNull);
  });
}
