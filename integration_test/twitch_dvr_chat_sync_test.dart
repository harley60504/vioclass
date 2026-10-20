// No OS mouse/keyboard injection. Read-only navigation through Flutter events.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vioclass/main.dart' as app;
import 'package:vioclass/features/twitch/models/discovery/twitch_live_stream.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_stream_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/watch/twitch_live_watch_state.dart';
import 'package:vioclass/features/twitch/presentation/pages/watch/twitch_live_watch_playback.dart';
import 'package:vioclass/features/twitch/presentation/pages/watch/twitch_watch_page_navigation.dart';
import 'package:vioclass/features/twitch/presentation/widgets/discovery/twitch_stream_card.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/player/twitch_vod_playback_strip.dart';
import 'package:vioclass/features/twitch/presentation/mini_player/twitch_mini_player_overlay.dart';
import 'package:vioclass/features/twitch/presentation/mini_player/twitch_mini_player_controller.dart';

Future<void> waitFor(
  WidgetTester tester,
  bool Function() ready,
  String stage, {
  int seconds = 30,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(ready(), isTrue, reason: stage);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('DVR chat shares displayed clock across seek and mini return', (
    tester,
  ) async {
    final previousPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message?.startsWith('[DvrChatTest]') == true) {
        previousPrint(message, wrapWidth: wrapWidth);
      }
    };
    addTearDown(() => debugPrint = previousPrint);
    await app.main([]);
    await waitFor(
      tester,
      () => find.byType(TwitchStreamCard).evaluate().isNotEmpty,
      'A live card must be available',
      seconds: 40,
    );
    final dynamic home = tester.state(find.byType(TwitchStreamPage));
    final candidates = tester
        .widgetList<TwitchStreamCard>(find.byType(TwitchStreamCard))
        .map((card) => card.stream)
        .take(4)
        .toList();
    TwitchLiveStream? selected;
    for (final candidate in candidates) {
      final page = await home.discoveryService
          .fetchChannelVideos(userId: candidate.userId, first: 1)
          .timeout(const Duration(seconds: 12));
      if (page.videos.isNotEmpty && page.videos.first.isLikelyGrowingArchive) {
        selected = candidate;
        break;
      }
    }
    expect(
      selected,
      isNotNull,
      reason: 'No growing archive in four live samples; not verified.',
    );
    final card = find.byWidgetPredicate(
      (w) => w is TwitchStreamCard && w.stream.id == selected!.id,
    );
    await tester.ensureVisible(card.first);
    await tester.tap(card.first);
    await waitFor(
      tester,
      () => find.byType(TwitchWatchPage).evaluate().isNotEmpty,
      'Watch route',
    );
    var watch = tester.state<TwitchWatchPageState>(
      find.byType(TwitchWatchPage),
    );
    await waitFor(
      tester,
      () => watch.hasUsableLiveDvrArchive,
      'DVR archive warmed',
      seconds: 35,
    );
    final duration = watch.currentLiveTimelineDuration()!;
    final target = Duration(milliseconds: duration.inMilliseconds ~/ 2);
    await watch
        .seekLiveDvrBridgePlaybackAt(target)
        .timeout(const Duration(seconds: 25));
    await waitFor(
      tester,
      () =>
          watch.vodReplayController.active &&
          watch.playerSession.player.state.playing,
      'Replay started',
    );
    Future<void> checkClock(String phase) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
        final clock = watch.playbackTimelineController;
        final shown = clock.positionFor(
          clock.displayDurationFor(clock.snapshot.duration!),
        );
        final chat = watch.vodReplayController.playbackTimeSeconds;
        final difference = (shown.inMilliseconds / 1000 - chat).abs();
        debugPrint(
          '[DvrChatTest] phase=$phase deltaSeconds=${difference.toStringAsFixed(3)}',
        );
        expect(difference, lessThan(1.0));
      }
    }

    await checkClock('initial-dvr');
    final slider = find.descendant(
      of: find.byType(TwitchVodPlaybackStrip),
      matching: find.byWidgetPredicate((w) => w is Slider && w.max == 1),
    );
    final rect = tester.getRect(slider.first);
    await tester.tapAt(Offset(rect.left + rect.width * .65, rect.center.dy));
    await waitFor(
      tester,
      () => !watch.loadingPlayer && watch.vodReplayController.active,
      'DVR seek completes',
    );
    await tester.pump(const Duration(seconds: 3));
    await checkClock('after-seek');
    await watch.leaveToMiniPlayer();
    await waitFor(
      tester,
      () =>
          TwitchMiniPlayerController.instance.isActive &&
          find.byType(TwitchWatchPage).evaluate().isEmpty,
      'Mini handoff',
    );
    final mini = find.descendant(
      of: find.byType(TwitchMiniPlayerOverlay),
      matching: find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onTap != null,
      ),
    );
    await tester.tap(mini.first);
    await waitFor(
      tester,
      () => find.byType(TwitchWatchPage).evaluate().isNotEmpty,
      'Mini expand',
    );
    watch = tester.state<TwitchWatchPageState>(find.byType(TwitchWatchPage));
    await waitFor(
      tester,
      () => watch.vodReplayController.active,
      'Mini replay chat restored',
    );
    await checkClock('after-mini');
    debugPrint('[DvrChatTest] PASS internal Flutter events only');
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 4)));
}
