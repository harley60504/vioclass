enum TwitchWatchPlaybackKind { none, live, liveDvr, vod, clip }

enum TwitchWatchMode { liveWatch, recordedWatch }

extension TwitchWatchPlaybackKindMode on TwitchWatchPlaybackKind {
  TwitchWatchMode get watchMode {
    switch (this) {
      case TwitchWatchPlaybackKind.live:
      case TwitchWatchPlaybackKind.liveDvr:
        return TwitchWatchMode.liveWatch;
      case TwitchWatchPlaybackKind.vod:
      case TwitchWatchPlaybackKind.clip:
      case TwitchWatchPlaybackKind.none:
        return TwitchWatchMode.recordedWatch;
    }
  }
}
