// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import '../lib/features/twitch/presentation/watch/controllers/twitch_playback_timeline_controller.dart';
import '../lib/features/twitch/services/playback/twitch_canonical_playback_clock_registry.dart';

class _State implements PlayerState {
  @override
  Duration position = Duration.zero;
  @override
  bool get playing => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player implements Player {
  final playbackState = _State();
  final seeks = <Duration>[];
  @override
  PlayerState get state => playbackState;
  @override
  Future<void> seek(Duration position, {bool synchronized = true}) async {
    seeks.add(position);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'buffering transition does not rebase to stale hidden-control position',
    () {
      var now = DateTime.utc(2026, 10, 11);
      final player = _Player();
      final clock = TwitchPlaybackTimelineController(
        now: () => now,
        player: () => player,
        mediaUri: () => 'http://127.0.0.1:1234/stream.ts',
      );
      addTearDown(clock.dispose);
      addTearDown(TwitchCanonicalPlaybackClockRegistry.clearLocalReplayAnchor);
      TwitchCanonicalPlaybackClockRegistry.setLocalReplayAnchor(
        canonicalStart: const Duration(seconds: 600),
        sequence: 1,
      );
      void configure(bool advancing, int edge) => clock.configure(
        mode: TwitchPlaybackTimelineMode.liveDvr,
        timelineEnabled: true,
        advancing: advancing,
        position: const Duration(seconds: 600),
        duration: Duration(seconds: edge),
      );
      configure(true, 610);
      // No control rebuild updates _duration or _position during this interval.
      now = now.add(const Duration(minutes: 2));
      player.playbackState.position = const Duration(minutes: 2);
      configure(false, 730);
      expect(
        clock.positionFor(const Duration(seconds: 730)),
        const Duration(seconds: 720),
      );
      now = now.add(const Duration(seconds: 5));
      configure(true, 735);
      now = now.add(const Duration(seconds: 30));
      final edge = clock.displayDurationFor(const Duration(seconds: 765));
      expect(edge - clock.positionFor(edge), const Duration(seconds: 15));
      expect(player.seeks, isEmpty);
    },
  );
  for (final foreground in [false, true]) {
    test(
      'same replay keeps its clock after two minutes: foreground=$foreground',
      () {
        var now = DateTime.utc(2026, 10, 11);
        final player = _Player();
        final clock = TwitchPlaybackTimelineController(
          now: () => now,
          player: () => player,
          mediaUri: () => 'http://127.0.0.1:1234/stream.ts',
        );
        addTearDown(clock.dispose);
        addTearDown(
          TwitchCanonicalPlaybackClockRegistry.clearLocalReplayAnchor,
        );
        TwitchCanonicalPlaybackClockRegistry.setLocalReplayAnchor(
          canonicalStart: const Duration(seconds: 600),
          sequence: 1,
        );
        void configure(Duration edge) => clock.configure(
          mode: TwitchPlaybackTimelineMode.liveDvr,
          timelineEnabled: true,
          advancing: true,
          position: const Duration(seconds: 600),
          duration: edge,
        );
        configure(const Duration(seconds: 610));
        now = now.add(const Duration(minutes: 2));
        player.playbackState.position = const Duration(minutes: 2);
        configure(const Duration(seconds: 730));
        expect(
          clock.positionFor(const Duration(seconds: 730)),
          const Duration(seconds: 720),
        );
        if (foreground) {
          clock.resumeClock();
        } else {
          player.playbackState.position = const Duration(seconds: 1);
        }
        configure(const Duration(seconds: 730));
        expect(
          clock.positionFor(const Duration(seconds: 730)),
          const Duration(seconds: 720),
        );
        expect(player.seeks, isEmpty);
        now = now.add(const Duration(seconds: 30));
        final edge = clock.displayDurationFor(const Duration(seconds: 760));
        expect(edge - clock.positionFor(edge), const Duration(seconds: 10));

        // A genuinely new replay revision must still honor the new target.
        TwitchCanonicalPlaybackClockRegistry.setLocalReplayAnchor(
          canonicalStart: const Duration(seconds: 745),
          sequence: 2,
        );
        configure(const Duration(seconds: 760));
        expect(
          clock.positionFor(const Duration(seconds: 760)),
          const Duration(seconds: 745),
        );
      },
    );
  }
}
