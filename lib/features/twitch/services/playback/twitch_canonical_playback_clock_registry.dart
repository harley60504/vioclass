/// Shared canonical clock anchors for the single warm Twitch player pipeline.
///
/// The near-live replay proxy resolves the exact Twitch segment that is emitted
/// first, while the UI owns the native media player position. Keeping only the
/// immutable canonical start here lets the presentation layer map
/// `segmentCanonicalStart + player.position` without using a wall-clock timer.
class TwitchCanonicalPlaybackClockRegistry {
  TwitchCanonicalPlaybackClockRegistry._();

  static Duration? _localReplayCanonicalStart;
  static int? _localReplaySequence;

  static Duration? get localReplayCanonicalStart =>
      _localReplayCanonicalStart;
  static int? get localReplaySequence => _localReplaySequence;

  static void setLocalReplayAnchor({
    required Duration canonicalStart,
    required int sequence,
  }) {
    _localReplayCanonicalStart = canonicalStart;
    _localReplaySequence = sequence;
  }

  static void clearLocalReplayAnchor() {
    _localReplayCanonicalStart = null;
    _localReplaySequence = null;
  }
}
