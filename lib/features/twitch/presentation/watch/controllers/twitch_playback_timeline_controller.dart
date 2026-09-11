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
  static const Duration _dvrInitialSeekJumpThreshold = Duration(milliseconds: 80);
  static const Duration _initialSeekReanchorWindow = Duration(seconds: 2);
  static const Duration _canonicalAnchorTolerance = Duration(seconds: 1);
  static const Duration _liveEdgeTolerance = Duration(milliseconds: 750);

  Timer? _pendingSeekTimer;
  Timer? _playbackTimer;
  TwitchPlaybackTimelineMode? _mode;
  Duration? _position;
  Duration? _duration;
  Duration? _pendingSeekTarget;
  Duration? _explicitSeekAnchorPosition;
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

  // The stable /stream.ts URL deliberately survives Local TS route changes,
  // so neither media URI nor native player.position can identify a new seek.
  // The replay proxy increments this revision for every resolved replay request.
  // Keep it separate from _clearMediaClockAnchor(): while a new seek is being
  // committed we must not re-bind the old replay revision to its old target.
  int? _localReplayAnchorRevision;

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
      _explicitSeekAnchorPosition = null;
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

    if (followsLiveEdge && !_dragging && _pendingSeekTarget == null) {
      _foregroundReanchorPending = false;
      _explicitSeekAnchorPosition = null;
      _clearMediaClockAnchor();
      _position = _clampPosition(duration, duration);
      return;
    }

    final localReplayStart =
        TwitchCanonicalPlaybackClockRegistry.localReplayCanonicalStart;
    final localReplaySequence =
        TwitchCanonicalPlaybackClockRegistry.localReplaySequence;
    final localReplayRevision =
        TwitchCanonicalPlaybackClockRegistry.localReplayRevision;
    final looksLikeTsSource = mediaUri != null && mediaUri.contains('/stream.ts');
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
      final localMediaRestarted =
          previousMediaPosition != null &&
          mediaPosition + _mediaRestartTolerance < previousMediaPosition;
      final localSourceChanged = mediaUri != _mediaAnchorUri;
      final replayChanged =
          _localReplayAnchorRevision != localReplayRevision;
      final firstLocalAnchor = _localReplayAnchorRevision == null;
      final shouldReanchor =
          replayChanged ||
          firstLocalAnchor ||
          _foregroundReanchorPending ||
          localSourceChanged ||
          localMediaRestarted;

      if (shouldReanchor && canonicalPosition != null) {
        final explicitAnchor = _explicitSeekAnchorPosition;
        final canonicalAnchor = explicitAnchor ?? canonicalPosition;
        _mediaAnchorUri = mediaUri;
        _mediaAnchorPosition = mediaPosition;
        _canonicalAnchorPosition = canonicalAnchor;
        _mediaAnchorObservedAt = now;
        _lastObservedMediaPosition = mediaPosition;
        _localReplayAnchorRevision = localReplayRevision;
        _position = _clampPosition(canonicalAnchor, duration);
        _explicitSeekAnchorPosition = null;
        _foregroundReanchorPending = false;
        if (kDebugMode) {
          debugPrint(
            '[CanonicalPlaybackClock][LOCAL-ANCHOR] '
            'revision=$localReplayRevision '
            'sequence=${localReplaySequence ?? -1} '
            'segmentStart=${_seconds(localReplayStart)}s '
            'media=${_seconds(mediaPosition)}s '
            'canonical=${_seconds(canonicalAnchor)}s '
            'runtimeCanonical=${_seconds(canonicalPosition)}s',
          );
        }
        return;
      }

      _lastObservedMediaPosition = mediaPosition;
      final mediaAnchor = _mediaAnchorPosition;
      final canonicalAnchor = _canonicalAnchorPosition;
      if (mediaAnchor != null && canonicalAnchor != null) {
        final mapped = canonicalAnchor + (mediaPosition - mediaAnchor);
        _position = _clampPosition(mapped, duration);
        if (kDebugMode && localReplaySequence != null) {
          debugPrint(
            '[CanonicalPlaybackClock][LOCAL-UI] '
            'revision=$_localReplayAnchorRevision '
            'sequence=$localReplaySequence '
            'segmentStart=${_seconds(localReplayStart)}s '
            'mediaAnchor=${_seconds(mediaAnchor)}s '
            'media=${_seconds(mediaPosition)}s '
            'canonicalAnchor=${_seconds(canonicalAnchor)}s '
            'canonical=${_seconds(_position ?? Duration.zero)}s',
          );
        }
      }
      return;
    }

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

    if ((sourceChanged || mediaRestarted) && canonicalPosition == null) {
      _clearMediaClockAnchor();
      return;
    }

    if (needsAnchor && canonicalPosition != null && mediaPosition != null) {
      final explicitAnchor = _explicitSeekAnchorPosition;
      _mediaAnchorUri = mediaUri;
      _mediaAnchorPosition = mediaPosition;
      _canonicalAnchorPosition = explicitAnchor ?? canonicalPosition;
      _mediaAnchorObservedAt = now;
      _explicitSeekAnchorPosition = null;
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
    final isSequentialDvr =
        _mediaAnchorUri?.contains('/stream.ts?v=') ?? false;
    final jumpThreshold = isSequentialDvr
        ? _dvrInitialSeekJumpThreshold
        : _initialSeekJumpThreshold;
    if (mediaAdvance <= jumpThreshold) return false;

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
    _explicitSeekAnchorPosition = null;
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
    _explicitSeekAnchorPosition = _position;
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
        (fromLiveEdge && delta.isNegative ? duration : current);

    // Step buttons first resolve one absolute UI/canonical target, then reuse
    // the exact same seek path as timeline dragging. Native playback latency is
    // transport state and must not become part of the next +/-10 second base.
    final minimumMs = _mode == TwitchPlaybackTimelineMode.liveDvr
        ? 0
        : minimum.inMilliseconds.clamp(0, duration.inMilliseconds).toInt();
    final targetMs = (base + delta).inMilliseconds
        .clamp(minimumMs, duration.inMilliseconds)
        .toInt();
    final target = Duration(milliseconds: targetMs);
    _pendingSeekTarget = target;
    _position = target;
    _explicitSeekAnchorPosition = target;
    _clearMediaClockAnchor();
    _syncPlaybackTimer();
    notifyListeners();

    _pendingSeekTimer?.cancel();
    _pendingSeekTimer = Timer(_seekCommitDelay, () {
      final committedTarget = _pendingSeekTarget;
      if (committedTarget == null) return;
      commitPosition(committedTarget);
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
    _explicitSeekAnchorPosition = null;
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
    _explicitSeekAnchorPosition = null;
    _lastPlaybackTickAt = null;
    _dragging = false;
    _advancing = false;
    _foregroundReanchorPending = false;
    _localReplayAnchorRevision = null;
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
