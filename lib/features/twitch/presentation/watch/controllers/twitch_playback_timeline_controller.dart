import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/playback/twitch_canonical_playback_clock_registry.dart';
import '../../../services/playback/twitch_media_kit_player_host.dart';

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
  static const Duration _mediaRestartTolerance = Duration(milliseconds: 500);
  static const Duration _initialSeekJumpThreshold = Duration(seconds: 3);
  static const Duration _initialSeekReanchorWindow = Duration(seconds: 2);
  static const Duration _canonicalAnchorTolerance = Duration(seconds: 1);
  static const Duration _liveEdgeTolerance = Duration(milliseconds: 750);

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
  bool _foregroundReanchorPending = false;

  // Live/DVR uses the player's media clock as the authoritative moving clock.
  // The canonical position supplied by the playback runtime is only an anchor.
  // This avoids drifting when Flutter timers are throttled in the background,
  // while still keeping all UI positions in the canonical Twitch timeline.
  String? _mediaAnchorUri;
  Duration? _mediaAnchorPosition;
  Duration? _canonicalAnchorPosition;
  Duration? _lastObservedMediaPosition;
  DateTime? _mediaAnchorObservedAt;

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
      _duration = duration ?? _duration;
      _syncLiveDvrPosition(
        modeChanged: modeChanged,
        canonicalPosition: position,
      );
    } else {
      _foregroundReanchorPending = false;
      _clearMediaClockAnchor();
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

  void _syncLiveDvrPosition({
    required bool modeChanged,
    required Duration? canonicalPosition,
  }) {
    final player = TwitchMediaKitPlayerHost.playerOrNull;
    final mediaPosition = player?.state.position;
    final mediaUri = TwitchMediaKitPlayerHost.currentMediaUri;
    final previousMediaPosition = _lastObservedMediaPosition;
    final now = DateTime.now();

    final duration = _duration;
    final followsLiveEdge =
        canonicalPosition != null &&
        duration != null &&
        _durationDistance(canonicalPosition, duration) <= _liveEdgeTolerance;

    // Plain LIVE is not a pauseable media position. Android may pause the
    // native player while the app is backgrounded, but when the live source is
    // visible again it is expected to represent the newest live edge. Always
    // bind the UI timeline to the canonical Twitch live edge instead of the
    // pre-background media position.
    if (followsLiveEdge &&
        !_dragging &&
        _pendingSeekTarget == null) {
      _foregroundReanchorPending = false;
      _clearMediaClockAnchor();
      _position = _clampPosition(duration, duration);
      return;
    }

    // Local near-live replay outputs the complete resolved TS segment. Its
    // canonical segment start is known exactly by SegmentTimelineIndex, while
    // media_kit reports elapsed playback from that local TS stream.
    final localReplayStart =
        TwitchCanonicalPlaybackClockRegistry.localReplayCanonicalStart;
    final localReplaySequence =
        TwitchCanonicalPlaybackClockRegistry.localReplaySequence;
    final looksLikeTsSource =
        mediaUri != null && mediaUri.contains('/stream.ts');
    final behindLive =
        canonicalPosition != null &&
        duration != null &&
        canonicalPosition + const Duration(milliseconds: 500) < duration;
    if (localReplayStart != null &&
        looksLikeTsSource &&
        behindLive &&
        mediaPosition != null &&
        !_dragging &&
        _pendingSeekTarget == null) {
      // A 20-second Local TS source is ephemeral. After foreground resume the
      // old segment/media anchor may no longer describe the bytes media_kit is
      // receiving. The runtime's canonicalPosition preserves the requested
      // from-live delay, so re-anchor the *current* media position to it once.
      // This does not fabricate elapsed playback time and avoids carrying the
      // stale pre-background anchor forward.
      if (_foregroundReanchorPending && canonicalPosition != null) {
        _mediaAnchorUri = mediaUri;
        _mediaAnchorPosition = mediaPosition;
        _canonicalAnchorPosition = canonicalPosition;
        _mediaAnchorObservedAt = now;
        _lastObservedMediaPosition = mediaPosition;
        _position = _clampPosition(canonicalPosition, duration);
        _foregroundReanchorPending = false;
        if (kDebugMode) {
          debugPrint(
            '[CanonicalPlaybackClock][LOCAL-FOREGROUND] '
            'sequence=${localReplaySequence ?? -1} '
            'media=${_seconds(mediaPosition)}s '
            'canonical=${_seconds(canonicalPosition)}s',
          );
        }
        return;
      }

      _mediaAnchorUri = mediaUri;
      _mediaAnchorPosition = Duration.zero;
      _canonicalAnchorPosition = localReplayStart;
      _mediaAnchorObservedAt = now;
      _lastObservedMediaPosition = mediaPosition;
      _position = _clampPosition(localReplayStart + mediaPosition, duration);
      if (kDebugMode && localReplaySequence != null) {
        debugPrint(
          '[CanonicalPlaybackClock][LOCAL-UI] '
          'sequence=$localReplaySequence '
          'segmentStart=${_seconds(localReplayStart)}s '
          'media=${_seconds(mediaPosition)}s '
          'canonical=${_seconds(_position ?? Duration.zero)}s',
        );
      }
      return;
    }

    // DVR is genuinely pauseable. Do not snap it to a newer canonical target
    // merely because the app returned from the background; preserve its media
    // clock mapping and continue from the actual player position.
    _foregroundReanchorPending = false;

    final mediaRestarted =
        mediaPosition != null &&
        previousMediaPosition != null &&
        mediaPosition + _mediaRestartTolerance < previousMediaPosition;
    final sourceChanged = mediaUri != _mediaAnchorUri;
    final initialSeekJumped = _shouldReanchorInitialSeek(
      now: now,
      mediaPosition: mediaPosition,
      canonicalPosition: canonicalPosition,
    );
    final needsAnchor =
        modeChanged ||
        sourceChanged ||
        mediaRestarted ||
        initialSeekJumped ||
        _mediaAnchorPosition == null ||
        _canonicalAnchorPosition == null;

    // A repaint-only timer can observe a source restart before the widget has
    // supplied the new canonical target. Never continue with the old source's
    // anchor in that gap.
    if ((sourceChanged || mediaRestarted) && canonicalPosition == null) {
      _clearMediaClockAnchor();
      return;
    }

    if (needsAnchor && canonicalPosition != null && mediaPosition != null) {
      _mediaAnchorUri = mediaUri;
      _mediaAnchorPosition = mediaPosition;
      _canonicalAnchorPosition = canonicalPosition;
      _mediaAnchorObservedAt = now;
    }

    _lastObservedMediaPosition = mediaPosition;

    if (_dragging || _pendingSeekTarget != null) return;

    final mediaAnchor = _mediaAnchorPosition;
    final canonicalAnchor = _canonicalAnchorPosition;
    if (mediaPosition != null &&
        mediaAnchor != null &&
        canonicalAnchor != null) {
      final mapped = canonicalAnchor + (mediaPosition - mediaAnchor);
      _position = _clampPosition(mapped, _duration);
      return;
    }

    if (canonicalPosition != null) {
      _position = _clampPosition(canonicalPosition, _duration);
    } else if (modeChanged) {
      _position = _clampPosition(_fallbackPosition(_mode!), _duration);
    }
  }

  bool _shouldReanchorInitialSeek({
    required DateTime now,
    required Duration? mediaPosition,
    required Duration? canonicalPosition,
  }) {
    final mediaAnchor = _mediaAnchorPosition;
    final canonicalAnchor = _canonicalAnchorPosition;
    final anchoredAt = _mediaAnchorObservedAt;
    if (mediaPosition == null ||
        canonicalPosition == null ||
        mediaAnchor == null ||
        canonicalAnchor == null ||
        anchoredAt == null) {
      return false;
    }

    final anchorAge = now.difference(anchoredAt);
    if (anchorAge.isNegative || anchorAge > _initialSeekReanchorWindow) {
      return false;
    }

    final mediaAdvance = mediaPosition - mediaAnchor;
    if (mediaAdvance <= _initialSeekJumpThreshold) return false;

    final canonicalDistance = _durationDistance(
      canonicalPosition,
      canonicalAnchor,
    );
    return canonicalDistance <= _canonicalAnchorTolerance;
  }

  Duration _durationDistance(Duration a, Duration b) {
    final delta = a.inMicroseconds - b.inMicroseconds;
    return Duration(microseconds: delta < 0 ? -delta : delta);
  }

  String _seconds(Duration value) =>
      (value.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(3);

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
    _clearMediaClockAnchor();
    _syncPlaybackTimer();
    notifyListeners();
  }

  Duration queueJumpBy({
    required Duration delta,
    required Duration current,
    required Duration duration,
    required bool fromLiveEdge,
    required ValueChanged<Duration> onCommit,
    Duration minimum = Duration.zero,
  }) {
    final base =
        _pendingSeekTarget ??
        _position ??
        (fromLiveEdge && delta.isNegative ? duration : current);
    final minimumMs = minimum.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toInt();
    final targetMs = (base + delta).inMilliseconds
        .clamp(minimumMs, duration.inMilliseconds)
        .toInt();
    final target = Duration(milliseconds: targetMs);
    _pendingSeekTarget = target;
    _position = target;
    _clearMediaClockAnchor();
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
    _foregroundReanchorPending = false;
    _clearMediaClockAnchor();
    _syncPlaybackTimer();
    notifyListeners();
  }

  void suspendClock() {
    _lastPlaybackTickAt = null;
  }

  void resumeClock() {
    // Lifecycle resume changes the semantics for non-pauseable live sources.
    // Consume this flag on the next authoritative configure() sample.
    _foregroundReanchorPending = true;
    if (_playbackTimer != null) {
      _lastPlaybackTickAt = DateTime.now();
    }
  }

  void reset() {
    _pendingSeekTimer?.cancel();
    _pendingSeekTimer = null;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _mode = null;
    _position = null;
    _duration = null;
    _pendingSeekTarget = null;
    _lastPlaybackTickAt = null;
    _dragging = false;
    _advancing = false;
    _foregroundReanchorPending = false;
    _clearMediaClockAnchor();
    notifyListeners();
  }

  void _clearMediaClockAnchor() {
    _mediaAnchorUri = null;
    _mediaAnchorPosition = null;
    _canonicalAnchorPosition = null;
    _lastObservedMediaPosition = null;
    _mediaAnchorObservedAt = null;
  }

  void _syncPlaybackTimer() {
    // The timer is repaint-only for a growing live timeline. It must never
    // advance playback position; the native media player's clock is authoritative.
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
      _lastPlaybackTickAt = DateTime.now();
      if (_advancing) {
        _syncLiveDvrPosition(
          modeChanged: false,
          canonicalPosition: null,
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
