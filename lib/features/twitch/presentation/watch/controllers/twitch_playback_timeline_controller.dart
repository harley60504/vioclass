import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/connectivity/vioclass_connectivity_service.dart';

enum TwitchPlaybackTimelineMode { live, liveDvr, vod, clip }

class TwitchPlaybackTimelineSnapshot {
  final TwitchPlaybackTimelineMode mode;
  final Duration position;
  final Duration? duration;
  final bool isAtLiveEdge;
  final bool canSeek;
  final bool seeking;

  const TwitchPlaybackTimelineSnapshot({
    required this.mode,
    required this.position,
    required this.duration,
    required this.isAtLiveEdge,
    required this.canSeek,
    required this.seeking,
  });
}

class TwitchPlaybackTimelineController extends ChangeNotifier {
  static const Duration _seekCommitDelay = Duration(milliseconds: 420);
  static const Duration _playbackTickInterval = Duration(milliseconds: 250);

  Timer? _pendingSeekTimer;
  Timer? _playbackTimer;
  TwitchPlaybackTimelineMode? _mode;
  Duration? _position;
  Duration? _duration;
  Duration? _pendingSeekTarget;
  DateTime? _lastPlaybackTickAt;
  bool _dragging = false;
  bool _timelineEnabled = true;
  bool _advancing = false;

  TwitchPlaybackTimelineSnapshot get snapshot {
    final mode = _mode ?? TwitchPlaybackTimelineMode.live;
    final duration = _duration;
    final position = _clampPosition(_position ?? Duration.zero, duration);
    final liveTailMs = duration == null ? 0 : duration.inMilliseconds - 1000;
    return TwitchPlaybackTimelineSnapshot(
      mode: mode,
      position: position,
      duration: duration,
      isAtLiveEdge:
          mode == TwitchPlaybackTimelineMode.live ||
          (duration != null && position.inMilliseconds >= liveTailMs),
      canSeek: _timelineEnabled && duration != null && duration > Duration.zero,
      seeking: _dragging,
    );
  }

  void configure({
    required TwitchPlaybackTimelineMode mode,
    required bool timelineEnabled,
    required bool advancing,
    Duration? position,
    Duration? duration,
  }) {
    final previousMode = _mode;
    final modeChanged = previousMode != mode;

    _mode = mode;
    _timelineEnabled = timelineEnabled;
    _advancing = advancing;

    if (mode == TwitchPlaybackTimelineMode.liveDvr) {
      if (modeChanged) {
        _duration = duration;
        _position = _clampPosition(
          position ?? _fallbackPosition(mode),
          _duration,
        );
      } else if (duration != null &&
          (_duration == null || duration > _duration!)) {
        _duration = duration;
      }
    } else {
      _duration = duration;
      if (!_dragging && _pendingSeekTarget == null) {
        _position = _clampPosition(
          position ?? _fallbackPosition(mode),
          _duration,
        );
      }
    }

    _syncPlaybackTimer();
  }

  Duration positionFor(Duration displayDuration) {
    return _clampPosition(_position ?? Duration.zero, displayDuration);
  }

  void beginDrag(Duration position) {
    _dragging = true;
    _position = _clampPosition(position, _duration);
    _syncPlaybackTimer();
    notifyListeners();
  }

  void updateDrag(Duration position) {
    _position = _clampPosition(position, _duration);
    notifyListeners();
  }

  void commitPosition(Duration position) {
    _pendingSeekTimer?.cancel();
    _pendingSeekTarget = null;
    _dragging = false;
    _position = _clampPosition(position, _duration);
    _syncPlaybackTimer();
    notifyListeners();
  }

  Duration queueJumpBy({
    required Duration delta,
    required Duration current,
    required Duration duration,
    required bool fromLiveEdge,
    required ValueChanged<Duration> onCommit,
  }) {
    final base =
        _pendingSeekTarget ??
        _position ??
        (fromLiveEdge && delta.isNegative ? duration : current);
    final target = _clampPosition(base + delta, duration);
    _pendingSeekTarget = target;
    _position = target;
    _syncPlaybackTimer();
    notifyListeners();

    _pendingSeekTimer?.cancel();
    _pendingSeekTimer = Timer(_seekCommitDelay, () {
      final committedTarget = _pendingSeekTarget;
      _pendingSeekTarget = null;
      if (committedTarget == null) return;
      onCommit(committedTarget);
      _syncPlaybackTimer();
    });
    return target;
  }

  void seekTo(Duration target, ValueChanged<Duration> onCommit) {
    _pendingSeekTimer?.cancel();
    _pendingSeekTarget = null;
    commitPosition(target);
    onCommit(_position ?? target);
  }

  void returnToLive() {
    _pendingSeekTimer?.cancel();
    _pendingSeekTarget = null;
    _dragging = false;
    _position = _duration;
    _syncPlaybackTimer();
    notifyListeners();
  }

  void _syncPlaybackTimer() {
    final shouldTick =
        _mode == TwitchPlaybackTimelineMode.liveDvr &&
        !_dragging &&
        _pendingSeekTarget == null;
    if (!shouldTick) {
      _playbackTimer?.cancel();
      _playbackTimer = null;
      _lastPlaybackTickAt = null;
      return;
    }
    if (_playbackTimer != null) return;

    _lastPlaybackTickAt = DateTime.now();
    _playbackTimer = Timer.periodic(_playbackTickInterval, (_) {
      final now = DateTime.now();
      final previous = _lastPlaybackTickAt ?? now;
      _lastPlaybackTickAt = now;
      final elapsed = now.difference(previous);
      _duration = (_duration ?? Duration.zero) + elapsed;
      final connectivity = VioClassConnectivityService.instance;
      final hasNetwork =
          !connectivity.initialized || connectivity.hasInternetAccess;
      if (_advancing && hasNetwork) {
        _position = _clampPosition(
          (_position ?? Duration.zero) + elapsed,
          _duration,
        );
      }
      notifyListeners();
    });
  }

  Duration _fallbackPosition(TwitchPlaybackTimelineMode mode) {
    if (mode == TwitchPlaybackTimelineMode.live) {
      return _duration ?? Duration.zero;
    }
    return Duration.zero;
  }

  Duration _clampPosition(Duration position, Duration? duration) {
    final maxMs = duration?.inMilliseconds;
    if (maxMs == null || maxMs <= 0) {
      return position < Duration.zero ? Duration.zero : position;
    }
    return Duration(
      milliseconds: position.inMilliseconds.clamp(0, maxMs).toInt(),
    );
  }

  @override
  void dispose() {
    _pendingSeekTimer?.cancel();
    _playbackTimer?.cancel();
    super.dispose();
  }
}
