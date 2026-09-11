import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Keeps preroll/zero-position decoder frames hidden while a frozen DVR
/// snapshot is opening and seeking to its requested target.
///
/// The video surface itself stays mounted. Only a black overlay is toggled, so
/// Android MediaCodec/SurfaceTexture ownership is not disturbed by the mask.
class TwitchDvrTransitionMaskController extends ChangeNotifier {
  TwitchDvrTransitionMaskController._();

  static final TwitchDvrTransitionMaskController instance =
      TwitchDvrTransitionMaskController._();

  static const Duration _readyStabilityWindow = Duration(milliseconds: 100);
  static const Duration _revealTimeout = Duration(milliseconds: 1200);
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
    debugPrint('[DvrTransitionMask] begin generation=$generation');
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

    timeoutTimer.cancel();
    stabilityTimer?.cancel();
    await positionSubscription.cancel();
    await bufferingSubscription.cancel();
    await playingSubscription.cancel();

    if (generation != _generation) return;
    _hide(generation, reason: reason, elapsed: stopwatch.elapsed, player: player, target: target);
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
      '[PlaybackLatency] dvrTransitionMask=${elapsed.inMilliseconds}ms '
      'reason=$reason generation=$generation '
      'target=${target == null ? '-' : _seconds(target)}s '
      'position=${position == null ? '-' : _seconds(position)}s '
      'buffering=${player?.state.buffering ?? false}',
    );
  }

  String _seconds(Duration value) =>
      (value.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(3);
}
