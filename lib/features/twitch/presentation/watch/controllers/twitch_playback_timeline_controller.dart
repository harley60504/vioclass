import 'dart:async';

import 'package:flutter/foundation.dart';

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
  static const Duration _tickInterval = Duration(milliseconds: 500);
  static const Duration _seekCommitDelay = Duration(milliseconds: 420);

  Timer? _timer;
  Timer? _pendingSeekTimer;
  TwitchPlaybackTimelineMode? _mode;
  Duration? _position;
  Duration? _duration;
  Duration? _pendingSeekTarget;
  bool _advancesWithPlayback = false;
  bool _playing = false;
  bool _dragging = false;
  bool _timelineEnabled = true;
  DateTime? _lastTickAt;
  DateTime? _liveStartedAt;

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
    required bool playing,
    required bool advancesWithPlayback,
    required bool timelineEnabled,
    Duration? position,
    Duration? duration,
    DateTime? liveStartedAt,
  }) {
    final effectiveDuration = _effectiveLiveDuration(duration, liveStartedAt);
    final previousMode = _mode;
    final modeChanged = previousMode != mode;

    _mode = mode;
    _playing = playing;
    _advancesWithPlayback = advancesWithPlayback;
    _timelineEnabled = timelineEnabled;
    _liveStartedAt = liveStartedAt;
    _duration = effectiveDuration;

    if (!_dragging) {
      if (modeChanged || !advancesWithPlayback || _position == null) {
        _position = _clampPosition(
          position ?? _fallbackPosition(mode),
          _duration,
        );
      } else if (position != null && _shouldAcceptExternalPosition(position)) {
        _position = _clampPosition(position, _duration);
      }
    }

    _syncTimer();
  }

  Duration positionFor(Duration displayDuration) {
    return _clampPosition(_position ?? Duration.zero, displayDuration);
  }

  void beginDrag(Duration position) {
    _dragging = true;
    _position = _clampPosition(position, _duration);
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
    _lastTickAt = DateTime.now();
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
    _lastTickAt = DateTime.now();
    notifyListeners();

    _pendingSeekTimer?.cancel();
    _pendingSeekTimer = Timer(_seekCommitDelay, () {
      final committedTarget = _pendingSeekTarget;
      _pendingSeekTarget = null;
      if (committedTarget == null) return;
      onCommit(committedTarget);
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
    _refreshLiveDuration();
    _position = _duration;
    _lastTickAt = DateTime.now();
    notifyListeners();
  }

  Duration _fallbackPosition(TwitchPlaybackTimelineMode mode) {
    if (mode == TwitchPlaybackTimelineMode.live) {
      return _duration ?? Duration.zero;
    }
    return Duration.zero;
  }

  bool _shouldAcceptExternalPosition(Duration position) {
    final current = _position;
    if (current == null) return true;
    final delta = (position - current).abs();
    return delta > const Duration(seconds: 3);
  }

  Duration? _effectiveLiveDuration(Duration? base, DateTime? startedAt) {
    final elapsed = startedAt == null
        ? null
        : DateTime.now().toUtc().difference(startedAt.toUtc());
    final positiveElapsed = elapsed == null || elapsed.isNegative
        ? null
        : elapsed;

    if (base == null) return positiveElapsed;
    if (positiveElapsed == null) return base;
    return positiveElapsed > base ? positiveElapsed : base;
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

  void _syncTimer() {
    final shouldTick =
        _timelineEnabled &&
        (_advancesWithPlayback || _liveStartedAt != null) &&
        _position != null;
    if (!shouldTick) {
      _timer?.cancel();
      _timer = null;
      _lastTickAt = null;
      return;
    }

    _lastTickAt ??= DateTime.now();
    _timer ??= Timer.periodic(_tickInterval, (_) => _tick());
  }

  void _tick() {
    final wasAtLiveEdge = snapshot.isAtLiveEdge;
    _refreshLiveDuration();
    if (!_advancesWithPlayback || _dragging) {
      if (!_dragging && wasAtLiveEdge) {
        _position = _duration;
      }
      _lastTickAt = DateTime.now();
      notifyListeners();
      return;
    }
    final now = DateTime.now();
    final last = _lastTickAt ?? now;
    _lastTickAt = now;
    if (!_playing) return;

    final delta = now.difference(last);
    if (delta.isNegative || delta == Duration.zero) return;
    _position = _clampPosition((_position ?? Duration.zero) + delta, _duration);
    notifyListeners();
  }

  void _refreshLiveDuration() {
    final startedAt = _liveStartedAt;
    if (startedAt == null) return;
    final elapsed = DateTime.now().toUtc().difference(startedAt.toUtc());
    if (elapsed.isNegative) return;
    final current = _duration;
    if (current == null || elapsed > current) {
      _duration = elapsed;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pendingSeekTimer?.cancel();
    super.dispose();
  }
}
