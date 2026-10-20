// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/models/discovery/twitch_stream_header_metadata.dart';
import '../lib/features/twitch/models/playback/twitch_m3u8_variant.dart';
import '../lib/features/twitch/presentation/watch/controllers/twitch_playback_timeline_controller.dart';
import '../lib/features/twitch/presentation/watch/twitch_watch_playback_kind.dart';
import '../lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart';
import '../lib/features/twitch/services/playback/twitch_playlist_player_runtime.dart';

class _Runtime extends ChangeNotifier implements TwitchPlaylistPlayerRuntime {
  int durationReads = 0;
  Duration duration = const Duration(minutes: 5);
  void emitChange() => notifyListeners();
  @override
  Duration? get canonicalLiveTimelineDuration {
    durationReads++;
    return duration;
  }

  @override
  bool get loading => false;
  @override
  bool get switchingQuality => false;
  @override
  List<TwitchM3u8Variant> get variants => const [];
  @override
  TwitchM3u8Variant? get currentVariant => null;
  @override
  String? get error => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final kind in [
    TwitchWatchPlaybackKind.live,
    TwitchWatchPlaybackKind.liveDvr,
  ]) {
    testWidgets('Timeline refresh stays inside player area: $kind', (
      tester,
    ) async {
      final runtime = _Runtime();
      final timeline = TwitchPlaybackTimelineController();
      final replacement = TwitchPlaybackTimelineController();
      addTearDown(runtime.dispose);
      addTearDown(timeline.dispose);
      addTearDown(replacement.dispose);
      var parentBuilds = 0;
      Widget host(TwitchPlaybackTimelineController controller) => MaterialApp(
        home: Builder(
          builder: (context) {
            parentBuilds++;
            return TwitchWatchPlayerArea(
              playerRuntime: runtime,
              player: null,
              videoController: null,
              metadata: const TwitchStreamHeaderMetadata.empty(),
              loading: false,
              error: null,
              playbackKind: kind,
              playbackTimelineController: controller,
              onBack: () {},
            );
          },
        ),
      );
      await tester.pumpWidget(host(timeline));
      final video = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_WatchPlayerVideoStage',
      );
      expect(video, findsOneWidget);
      final stableVideo = tester.widget(video);
      final initialParentBuilds = parentBuilds;
      final initialReads = runtime.durationReads;
      runtime.duration += const Duration(seconds: 1);
      timeline.returnToLive();
      await tester.pump();
      expect(runtime.durationReads, greaterThan(initialReads));
      expect(parentBuilds, initialParentBuilds);
      expect(identical(tester.widget(video), stableVideo), isTrue);

      // Replacing the controller must detach the old listener.
      await tester.pumpWidget(host(replacement));
      final readsAfterReplacement = runtime.durationReads;
      timeline.returnToLive();
      await tester.pump();
      expect(runtime.durationReads, readsAfterReplacement);
      replacement.returnToLive();
      await tester.pump();
      expect(runtime.durationReads, greaterThan(readsAfterReplacement));

      await tester.pumpWidget(const SizedBox());
      final readsAfterUnmount = runtime.durationReads;
      replacement.returnToLive();
      runtime.emitChange();
      await tester.pump();
      expect(runtime.durationReads, readsAfterUnmount);
      expect(tester.takeException(), isNull);
    });
  }
}
