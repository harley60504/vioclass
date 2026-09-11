import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Keeps stale/preroll decoder frames hidden while playback is transitioning.
///
/// The video surface itself stays mounted. Only a black overlay is toggled, so
/// Android MediaCodec/SurfaceTexture ownership is not disturbed by the mask.
/// The same mask is used both for DVR seeks and live-source switches.
class TwitchDvrTransitionMaskController extends ChangeNotifier {
  TwitchDvrTransitionMaskController._();

  static final TwitchDvrTransitionMaskController instance =
      TwitchDvrTransitionMaskController._();

  // A decoded frame that is already playing, non-buffering and on target does
  // not need a full 100 ms confirmation window. 40 ms still spans multiple
  // display frames while reducing the visible delay after timeline seeks.
  static const Duration _readyStabilityWindow = Duration(milliseconds: 40);
  static const Duration _revealTimeout = Duration(milliseconds: 1200);
  static const Duration _liveSwitchRevealTimeout = Duration(seconds: 2);
  static const Duration _liveSwitchProgressThreshold =
      Duration(milliseconds: 40);
  static const int _targetToleranceMs = 650;

  bool _visible = false;
  int _generation = 0;

  bool get visible => _visible;

  int begin() {
    final generation = ++_generation;
    if (!_visible) {
      _visible = true;
      notifyListeners();
    }
    debugPrint('[PlaybackTransitionMask] begin generation=$generation');
    return generation;
  }

  void cancel(int generation, {String reason = 'cancelled'}) {
    if (generation != _generation) return;
    _hide(generation, reason: reason, elapsed: Duration.zero);
  }

  Future<void> revealWhenReady({
    required Player player,
    required Duration target,
    required int generation,
  }) async {
    if (generation != _generation || !_visible) return;

    final stopwatch = Stopwatch()..start();
    final completer = Completer<String>();
    StreamSubscription<Duration>? positionSubscription;
    StreamSubscription<bool>? bufferingSubscription;
    StreamSubscription<bool>? playingSubscription;
    Timer? stabilityTimer;
    Timer? timeoutTimer;

    bool isTargetReady() {
      final distanceMs =
          (player.state.position - target).inMilliseconds.abs();
      return player.state.playing &&
          !player.state.buffering &&
          distanceMs <= _targetToleranceMs;
    }

    void complete(String reason) {
      if (completer.isCompleted) return;
      stabilityTimer?.cancel();
      stabilityTimer = null;
      completer.complete(reason);
    }

    void evaluate() {
      if (generation != _generation) {
        complete('superseded');
        return;
      }
      if (!isTargetReady()) {
        stabilityTimer?.cancel();
        stabilityTimer = null;
        return;
      }
      stabilityTimer ??= Timer(_readyStabilityWindow, () {
        stabilityTimer = null;
        if (generation != _generation) {
          complete('superseded');
          return;
        }
        if (isTargetReady()) {
          complete('ready');
        } else {
          evaluate();
        }
      });
    }

    positionSubscription = player.stream.position.listen((_) => evaluate());
    bufferingSubscription = player.stream.buffering.listen((_) => evaluate());
    playingSubscription = player.stream.playing.listen((_) => evaluate());
    timeoutTimer = Timer(_revealTimeout, () => complete('timeout'));

    evaluate();
    final reason = await completer.future;
    stopwatch.stop();

    timeoutTimer?.cancel();
    stabilityTimer?.cancel();
    await positionSubscription?.cancel();
    await bufferingSubscription?.cancel();
    await playingSubscription?.cancel();

    if (generation != _generation) return;
    _hide(
      generation,
      reason: reason,
      elapsed: stopwatch.elapsed,
      player: player,
      target: target,
    );
  }

  /// Reveals a newly opened LIVE source only after its own media clock starts
  /// moving. `playing && !buffering` alone is not sufficient because media_kit
  /// can briefly retain those states while the video surface still contains the
  /// previous channel's final decoded frame.
  Future<void> revealWhenLivePlaybackAdvances({
    required Player player,
    required int generation,
  }) async {
    if (generation != _generation || !_visible) return;

    final stopwatch = Stopwatch()..start();
    final baseline = player.state.position;
    final completer = Completer<String>();
    StreamSubscription<Duration>? positionSubscription;
    StreamSubscription<bool>? bufferingSubscription;
    StreamSubscription<bool>? playingSubscription;
    Timer? stabilityTimer;
    Timer? timeoutTimer;

    bool hasAdvanced() {
      final delta = player.state.position - baseline;
      return delta.abs() >= _liveSwitchProgressThreshold;
    }

    bool isLiveFrameReady() {
      return player.state.playing && !player.state.buffering && hasAdvanced();
    }

    void complete(String reason) {
      if (completer.isCompleted) return;
      stabilityTimer?.cancel();
      stabilityTimer = null;
      completer.complete(reason);
    }

    void evaluate() {
      if (generation != _generation) {
        complete('superseded');
        return;
      }
      if (!isLiveFrameReady()) {
        stabilityTimer?.cancel();
        stabilityTimer = null;
        return;
      }
      stabilityTimer ??= Timer(_readyStabilityWindow, () {
        stabilityTimer = null;
        if (generation != _generation) {
          complete('superseded');
          return;
        }
        if (isLiveFrameReady()) {
          complete('live-ready');
        } else {
          evaluate();
        }
      });
    }

    positionSubscription = player.stream.position.listen((_) => evaluate());
    bufferingSubscription = player.stream.buffering.listen((_) => evaluate());
    playingSubscription = player.stream.playing.listen((_) => evaluate());
    timeoutTimer = Timer(
      _liveSwitchRevealTimeout,
      () => complete('live-timeout'),
    );

    evaluate();
    final reason = await completer.future;
    stopwatch.stop();

    timeoutTimer?.cancel();
    stabilityTimer?.cancel();
    await positionSubscription?.cancel();
    await bufferingSubscription?.cancel();
    await playingSubscription?.cancel();

    if (generation != _generation) return;
    _hide(
      generation,
      reason: reason,
      elapsed: stopwatch.elapsed,
      player: player,
    );
  }

  void _hide(
    int generation, {
    required String reason,
    required Duration elapsed,
    Player? player,
    Duration? target,
  }) {
    if (generation != _generation || !_visible) return;
    _visible = false;
    notifyListeners();

    final position = player?.state.position;
    debugPrint(
      '[PlaybackLatency] transitionMask=${elapsed.inMilliseconds}ms '
      'reason=$reason generation=$generation '
      'target=${target == null ? '-' : _seconds(target)}s '
      'position=${position == null ? '-' : _seconds(position)}s '
      'buffering=${player?.state.buffering ?? false}',
    );
  }

  String _seconds(Duration value) =>
      (value.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(3);
}