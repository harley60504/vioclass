// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';

import '../lib/features/twitch/presentation/watch/twitch_watch_playback_kind.dart';
import '../lib/features/twitch/presentation/widgets/watch/player/twitch_vod_playback_strip.dart';
import '../lib/features/twitch/presentation/widgets/watch/player/twitch_watch_bottom_control_bar.dart';
import '../lib/features/twitch/services/playback/twitch_playlist_player_runtime.dart';
import '../lib/features/twitch/presentation/widgets/shared/twitch_glass.dart';
import '../lib/features/twitch/presentation/watch/controllers/twitch_playback_timeline_controller.dart';
import '../lib/features/twitch/presentation/widgets/watch/player/twitch_player_chrome_button.dart';

class _State implements PlayerState {
  @override
  Duration get position => const Duration(minutes: 30);
  @override
  Duration get duration => const Duration(hours: 1);
  @override
  bool get playing => false;
  @override
  bool get buffering => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Streams implements PlayerStream {
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Stream<Duration> get duration => const Stream.empty();
  @override
  Stream<bool> get playing => const Stream.empty();
  @override
  Stream<bool> get buffering => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player implements Player {
  final seeks = <Duration>[];
  int plays = 0;
  @override
  Future<void> play({bool synchronized = true}) async {
    plays++;
  }

  @override
  PlayerState get state => _State();
  @override
  PlayerStream get stream => _Streams();
  @override
  Future<void> seek(Duration position, {bool synchronized = true}) async =>
      seeks.add(position);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Runtime implements TwitchPlaylistPlayerRuntime {
  @override
  bool get busy => false;
  @override
  bool get usingExternalVodPlayback => true;
  @override
  bool get usingLiveTimelineReplay => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LiveClock extends TwitchPlaybackTimelineController {
  Duration edge = const Duration(seconds: 610);
  @override
  Duration displayDurationFor(Duration sourceDuration) => edge;
  @override
  Duration positionFor(Duration displayDuration) =>
      const Duration(seconds: 600);
}

void main() {
  for (final kind in [
    TwitchWatchPlaybackKind.live,
    TwitchWatchPlaybackKind.liveDvr,
    TwitchWatchPlaybackKind.vod,
    TwitchWatchPlaybackKind.clip,
  ]) {
    testWidgets('Resume uses LIVE edge only for plain live: $kind', (
      tester,
    ) async {
      final player = _Player();
      var liveResumes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 80,
                child: WatchBottomControlBar(
                  player: player,
                  playerRuntime: _Runtime(),
                  muted: false,
                  volume: 50,
                  fullscreen: false,
                  chatVisible: true,
                  showFullscreenButton: false,
                  onToggleMute: null,
                  onVolumeChanged: null,
                  qualityVariants: const [],
                  currentVariant: null,
                  onQualityChanged: null,
                  onToggleChat: null,
                  onToggleFullscreen: null,
                  playbackKind: kind,
                  onReturnToLive: () => liveResumes++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('播放'));
      await tester.pump();
      expect(liveResumes, kind == TwitchWatchPlaybackKind.live ? 1 : 0);
      expect(player.plays, kind == TwitchWatchPlaybackKind.live ? 0 : 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'limited window shares clock and freezes its target during drag',
    (tester) async {
      final clock = _LiveClock();
      addTearDown(clock.dispose);
      final targets = <Duration>[];
      Future<void> build() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: TwitchVodPlaybackStrip(
                player: _Player(),
                compact: true,
                fullWidthTimeline: true,
                showLiveEdgeLabel: true,
                liveTimelineDuration: const Duration(seconds: 600),
                liveSeekWindowDuration: const Duration(seconds: 20),
                timelineController: clock,
                onOpenDvrReplayAtPosition: targets.add,
              ),
            ),
          ),
        ),
      );
      await build();
      await tester.pump();
      final limitedBadge = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_LimitedReplayBadge',
      );
      final liveBadge = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_LiveStatusButton',
      );
      final limitedRect = tester.getRect(limitedBadge);
      final liveRect = tester.getRect(liveBadge);
      expect(tester.getSize(limitedBadge), tester.getSize(liveBadge));
      expect(limitedRect.width, closeTo(limitedRect.height, 0.01));
      expect(liveRect.width, closeTo(liveRect.height, 0.01));
      final finder = find.byType(Slider);
      final slider = tester.widget<Slider>(finder);
      expect(slider.value, closeTo(0.5, 0.001));
      slider.onChangeStart!(0.25);
      await tester.pump();
      clock.edge = const Duration(seconds: 620);
      await build();
      await tester.pump();
      tester.widget<Slider>(finder).onChangeEnd!(0.25);
      await tester.pump();
      expect(targets.single, const Duration(seconds: 595));
      expect(tester.takeException(), isNull);
    },
  );
  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    testWidgets('player chrome real frost on $platform', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PlayerChromeButton(
                tooltip: 'test',
                icon: Icons.home,
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(TwitchPlayerGlassSurface), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      await tester.tap(find.byIcon(Icons.home));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }
  testWidgets('frost samples purple track according to painted length', (
    tester,
  ) async {
    final key = GlobalKey();
    Future<int> sample(double progressWidth) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 240,
                  height: 60,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: Colors.black),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        width: progressWidth,
                        height: 2,
                        child: const ColoredBox(color: Color(0xFF8D7BFF)),
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        top: 2,
                        child: TwitchPlayerGlassSurface(
                          borderRadius: BorderRadius.zero,
                          child: SizedBox(height: 48),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final blue = data!.getUint8((4 * 240 + 150) * 4 + 2);
        image.dispose();
        return blue;
      }))!;
    }

    final shortBlue = await sample(60);
    final longBlue = await sample(200);
    expect(
      longBlue,
      greaterThan(shortBlue),
      reason: 'Only the painted purple part should tint nearby frost.',
    );
  });
  for (final width in [
    240.0,
    390.0,
    620.0,
    699.0,
    700.0,
    701.0,
    720.0,
    760.0,
    860.0,
    1024.0,
  ]) {
    testWidgets('live time controls centered width=$width', (tester) async {
      final player = _Player();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: TwitchVodPlaybackStrip(
                  player: player,
                  compact: width < 720,
                  fullWidthTimeline: true,
                  showLiveEdgeLabel: true,
                  liveTimelineDuration: const Duration(hours: 1),
                  onReturnToLive: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controls = find.byWidgetPredicate(
        (widget) =>
            widget.runtimeType.toString() == '_LiveTimelineTimeControls' ||
            widget.runtimeType.toString() == '_InlineTimelineTimeControls',
      );
      expect(controls, findsOneWidget);
      expect(
        tester.getRect(controls).center.dx,
        closeTo(
          tester.getRect(find.byType(TwitchVodPlaybackStrip)).center.dx,
          0.1,
        ),
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('full width timeline above controls width=$width', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final player = _Player();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: WatchBottomControlBar(
                  player: player,
                  playerRuntime: _Runtime(),
                  muted: false,
                  volume: 50,
                  fullscreen: false,
                  chatVisible: true,
                  showFullscreenButton: true,
                  onToggleMute: () {},
                  onVolumeChanged: (_) {},
                  qualityVariants: const [],
                  currentVariant: null,
                  onQualityChanged: null,
                  onToggleChat: () {},
                  onToggleFullscreen: () {},
                  playbackKind: TwitchWatchPlaybackKind.vod,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final strip = find.byType(TwitchVodPlaybackStrip);
      expect(strip, findsOneWidget);
      final slider = find.descendant(
        of: strip,
        matching: find.byWidgetPredicate(
          (widget) => widget is Slider && widget.max == 1,
        ),
      );
      expect(slider, findsOneWidget);
      expect(find.byTooltip('打開播放進度'), findsNothing);
      expect(find.byIcon(Icons.timeline_rounded), findsNothing);
      final theme = tester.widget<SliderTheme>(
        find.ancestor(of: slider, matching: find.byType(SliderTheme)).first,
      );
      expect(theme.data.thumbShape, same(SliderComponentShape.noThumb));
      expect(theme.data.overlayShape, same(SliderComponentShape.noOverlay));
      expect(theme.data.trackHeight, 2);
      final rect = tester.getRect(slider);
      expect(rect.width, greaterThan(width * 0.8));
      final timeLabel = find.descendant(
        of: strip,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget.runtimeType.toString() == '_VodTimelineTimeControls' ||
              widget.runtimeType.toString() == '_InlineTimelineTimeControls',
        ),
      );
      expect(timeLabel, findsOneWidget);
      expect(tester.getRect(find.byTooltip('音量')).width, 36);
      if (width >= 620) {
        expect(
          tester.getRect(timeLabel).center.dx,
          closeTo(tester.getRect(strip).center.dx, 0.1),
        );
      } else {
        expect(
          tester.getRect(timeLabel).center.dx,
          lessThan(tester.getRect(strip).center.dx),
        );
      }
      final leftZone = find.byKey(const ValueKey('player-control-left'));
      final rightZone = find.byKey(const ValueKey('player-control-right'));
      if (width == 240) {
        expect(
          tester.getRect(timeLabel).left - tester.getRect(leftZone).right,
          closeTo(6, 0.1),
          reason: 'Crowded controls should reuse the empty space after play.',
        );
      }
      if (width == 390) {
        expect(
          tester.getRect(find.byTooltip('音量')).left,
          greaterThanOrEqualTo(tester.getRect(rightZone).left),
          reason: 'Shifting time frees room for the volume button.',
        );
      }
      expect(
        tester.getRect(leftZone).right,
        lessThanOrEqualTo(tester.getRect(timeLabel).left),
      );
      expect(
        tester.getRect(rightZone).left,
        greaterThanOrEqualTo(tester.getRect(timeLabel).right),
      );
      expect(
        tester.getRect(find.byTooltip('播放')).left,
        closeTo(tester.getRect(leftZone).left, 0.1),
      );
      expect(
        tester.getRect(find.byTooltip('全螢幕')).right,
        closeTo(tester.getRect(rightZone).right, 0.1),
      );
      if (width >= 720) {
        expect(
          tester.getRect(timeLabel).center.dx,
          closeTo(tester.getRect(strip).center.dx, 0.1),
        );
        final volume = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == 'PlayerVolumeButton',
        );
        final volumeViewport = find
            .ancestor(of: volume, matching: find.byType(SingleChildScrollView))
            .first;
        expect(tester.getRect(volume).width, 36);
        expect(find.byIcon(Icons.replay_10_rounded), findsNothing);
        expect(find.byIcon(Icons.forward_10_rounded), findsNothing);
        final viewportRect = tester.getRect(volumeViewport);
        expect(
          viewportRect.left - tester.getRect(timeLabel).right,
          greaterThanOrEqualTo(11.9),
        );
        expect(
          tester.widget<SingleChildScrollView>(volumeViewport).clipBehavior,
          Clip.hardEdge,
        );
        await tester.drag(volumeViewport, const Offset(180, 0));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(volumeViewport).left - tester.getRect(timeLabel).right,
          greaterThanOrEqualTo(11.9),
        );
      }
      final play = find.byIcon(Icons.play_arrow);
      expect(tester.getTopLeft(play).dy, greaterThanOrEqualTo(rect.center.dy));
      final surface = find.byWidgetPredicate(
        (widget) =>
            widget.runtimeType.toString() == '_WatchBottomControlSurface',
      );
      expect(surface, findsOneWidget);
      final panel = tester.getRect(surface);
      expect(panel.height, 48);
      expect(tester.getRect(timeLabel).top, greaterThan(rect.center.dy));
      expect(
        tester.getRect(timeLabel).center.dy,
        closeTo(tester.getRect(play).center.dy, 0.1),
      );
      expect(tester.getRect(timeLabel).overlaps(tester.getRect(play)), isFalse);
      expect(
        find.descendant(of: surface, matching: find.byType(BackdropFilter)),
        findsOneWidget,
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: surface,
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.gradient, isNull);
      expect(decoration.color, const Color(0x59171420));
      final backdrop = find.descendant(
        of: surface,
        matching: find.byType(BackdropFilter),
      );
      expect(
        tester.getRect(backdrop),
        tester.getRect(
          find.descendant(of: surface, matching: find.byType(ClipRRect)),
        ),
      );
      final border = decoration.border! as Border;
      expect(border.top.style, BorderStyle.none);
      final radius = decoration.borderRadius! as BorderRadius;
      expect(radius.topLeft, Radius.zero);
      expect(radius.topRight, Radius.zero);
      expect(radius.bottomLeft.x, greaterThan(0));
      expect(panel.top - rect.center.dy, closeTo(1, 0.1));
      expect(find.ancestor(of: strip, matching: surface), findsNothing);
      expect(
        find
            .descendant(
              of: find.byType(WatchBottomControlBar),
              matching: find.byType(FittedBox),
            )
            .evaluate()
            .where((e) => (e.widget as FittedBox).child is SizedBox),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.tapAt(Offset(rect.left + rect.width * 0.7, rect.center.dy));
      await tester.pumpAndSettle();
      expect(player.seeks, isNotEmpty);
      expect(player.seeks.last, greaterThan(const Duration(minutes: 30)));
      await tester.dragFrom(rect.center, Offset(-rect.width * 0.2, 0));
      await tester.pumpAndSettle();
      expect(player.seeks.last, lessThan(const Duration(minutes: 30)));
      expect(tester.takeException(), isNull);
    });
  }
}
