import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/models/playback/twitch_hls_proxy_models.dart';
import 'package:vioclass/features/twitch/presentation/watch/controllers/twitch_live_foreground_checkpoint.dart';

void main() {
  final start = DateTime.utc(2026, 10, 27);
  TwitchHlsLiveStatus upstream({
    required DateTime updatedAt,
    bool running = true,
  }) => TwitchHlsLiveStatus.fromJson({
    'running': running,
    'hasWriter': true,
    'outputDurationMs': 30000,
    'latestPlayableSequence': 50,
    'lastWrittenSequence': 50,
    'updatedAtMs': updatedAt.millisecondsSinceEpoch,
  });

  test(
    'A recovering upstream becomes reusable inside the grace window',
    () async {
      var now = start;
      var reads = 0;
      final stale = upstream(
        updatedAt: start.subtract(const Duration(seconds: 20)),
      );
      final result = await TwitchLiveForegroundCheckpoint.confirmUpstream(
        initial: stale,
        refresh: () async {
          reads++;
          return reads == 2 ? upstream(updatedAt: now) : stale;
        },
        isCurrent: () => true,
        now: () => now,
        wait: (duration) async {
          now = now.add(duration);
        },
      );
      expect(
        TwitchLiveForegroundCheckpoint.upstreamIsCurrent(result, now),
        isTrue,
      );
      expect(now.difference(start), const Duration(milliseconds: 500));
    },
  );
  test('A stale upstream stops waiting at two seconds', () async {
    var now = start;
    final stale = upstream(
      updatedAt: start.subtract(const Duration(seconds: 20)),
    );
    final result = await TwitchLiveForegroundCheckpoint.confirmUpstream(
      initial: stale,
      refresh: () async => stale,
      isCurrent: () => true,
      now: () => now,
      wait: (duration) async {
        now = now.add(duration);
      },
    );
    expect(result, same(stale));
    expect(now.difference(start), const Duration(seconds: 2));
    expect(
      TwitchLiveForegroundCheckpoint.upstreamIsCurrent(result, now),
      isFalse,
    );
  });
  test('Current, stopped and unavailable upstreams do not wait', () async {
    for (final status in [
      upstream(updatedAt: start),
      upstream(updatedAt: start, running: false),
      null,
    ]) {
      final result = await TwitchLiveForegroundCheckpoint.confirmUpstream(
        initial: status,
        refresh: () => throw StateError('Unexpected status read'),
        isCurrent: () => true,
        now: () => start,
        wait: (_) => throw StateError('Unexpected wait'),
      );
      expect(result, same(status));
    }
  });
  test(
    'A route or source change cancels confirmation before another read',
    () async {
      var current = true;
      final result = await TwitchLiveForegroundCheckpoint.confirmUpstream(
        initial: upstream(
          updatedAt: start.subtract(const Duration(seconds: 20)),
        ),
        refresh: () => throw StateError('Cancelled owner must not read'),
        isCurrent: () => current,
        now: () => start,
        wait: (_) async {
          current = false;
        },
      );
      expect(result, isNull);
    },
  );
  test('Cancellation during a read rejects a late healthy result', () async {
    var now = start;
    var current = true;
    final result = await TwitchLiveForegroundCheckpoint.confirmUpstream(
      initial: upstream(updatedAt: start.subtract(const Duration(seconds: 20))),
      refresh: () async {
        current = false;
        return upstream(updatedAt: now);
      },
      isCurrent: () => current,
      now: () => now,
      wait: (duration) async {
        now = now.add(duration);
      },
    );
    expect(result, isNull);
  });
  test(
    'A hanging status read is bounded by the confirmation deadline',
    () async {
      final watch = Stopwatch()..start();
      final stale = upstream(
        updatedAt: DateTime.now().subtract(const Duration(seconds: 20)),
      );
      final result = await TwitchLiveForegroundCheckpoint.confirmUpstream(
        initial: stale,
        refresh: () => Completer<TwitchHlsLiveStatus?>().future,
        isCurrent: () => true,
        confirmationWindow: const Duration(milliseconds: 300),
      );
      expect(result, same(stale));
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    },
  );
  final snapshot = TwitchLiveForegroundCheckpoint(
    capturedAt: start,
    position: const Duration(seconds: 20),
    mediaUri: 'fixture-live',
    wasPlaying: true,
  );
  bool reuse(
    int elapsed,
    int advanced, {
    String uri = 'fixture-live',
    bool buffering = false,
    bool playing = true,
    bool error = false,
  }) => snapshot.keptUp(
    now: start.add(Duration(seconds: elapsed)),
    currentPosition: Duration(seconds: 20 + advanced),
    currentUri: uri,
    playing: playing,
    buffering: buffering,
    hasError: error,
  );
  test(
    'Continuous live playback is reused without accumulating background drift',
    () {
      expect(reuse(30, 30), isTrue);
      expect(reuse(3600, 3600), isTrue);
      expect(reuse(30, 29), isTrue);
      expect(reuse(30, 5), isFalse);
      expect(reuse(3600, 3590), isFalse);
    },
  );
  test('Stopped, replaced, buffering and failed readers are not reused', () {
    expect(reuse(30, 30, uri: 'another'), isFalse);
    expect(reuse(30, 30, buffering: true), isFalse);
    expect(reuse(30, 30, playing: false), isFalse);
    expect(reuse(30, 30, error: true), isFalse);
    expect(reuse(30, 0), isFalse);
    expect(reuse(30, -10), isFalse);
  });
  test('Only a current advancing upstream avoids upstream reconnection', () {
    TwitchHlsLiveStatus status({
      int age = 2,
      bool running = true,
      int lag = 0,
    }) => TwitchHlsLiveStatus.fromJson({
      'running': running,
      'hasWriter': true,
      'outputDurationMs': 30000,
      'latestPlayableSequence': 50,
      'lastWrittenSequence': 50 - lag,
      'updatedAtMs': start
          .subtract(Duration(seconds: age))
          .millisecondsSinceEpoch,
    });
    expect(
      TwitchLiveForegroundCheckpoint.upstreamIsCurrent(status(), start),
      isTrue,
    );
    expect(
      TwitchLiveForegroundCheckpoint.upstreamIsCurrent(status(age: 20), start),
      isFalse,
    );
    expect(
      TwitchLiveForegroundCheckpoint.upstreamIsCurrent(
        status(running: false),
        start,
      ),
      isFalse,
    );
    expect(
      TwitchLiveForegroundCheckpoint.upstreamIsCurrent(status(lag: 5), start),
      isFalse,
    );
    expect(
      TwitchLiveForegroundCheckpoint.upstreamIsCurrent(null, start),
      isFalse,
    );
  });
}
