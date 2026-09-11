/// Shared canonical clock anchors for the single warm Twitch player pipeline.
///
/// The near-live replay proxy resolves the exact Twitch segment that is emitted
/// first, while the UI owns the native media player position. The canonical
/// start identifies the resolved segment; [localReplayIntraSegment] identifies
/// the exact target inside that segment; [localReplayRevision] identifies each
/// replay request even when two seeks resolve to the same segment.
class TwitchCanonicalPlaybackClockRegistry {
  TwitchCanonicalPlaybackClockRegistry._();

  static Duration? _localReplayCanonicalStart;
  static Duration? _localReplayIntraSegment;
  static int? _localReplaySequence;
  static int _localReplayRevision = 0;

  static Duration? get localReplayCanonicalStart =>
      _localReplayCanonicalStart;
  static Duration? get localReplayIntraSegment => _localReplayIntraSegment;
  static int? get localReplaySequence => _localReplaySequence;
  static int get localReplayRevision => _localReplayRevision;

  static void setLocalReplayAnchor({
    required Duration canonicalStart,
    Duration intraSegment = Duration.zero,
    required int sequence,
  }) {
    _localReplayCanonicalStart = canonicalStart;
    _localReplayIntraSegment = intraSegment;
    _localReplaySequence = sequence;
    _localReplayRevision++;
  }

  static void clearLocalReplayAnchor() {
    _localReplayCanonicalStart = null;
    _localReplayIntraSegment = null;
    _localReplaySequence = null;
  }
}