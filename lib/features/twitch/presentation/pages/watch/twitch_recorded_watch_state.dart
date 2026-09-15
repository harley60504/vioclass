import '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension TwitchRecordedWatchStateMethods on TwitchWatchPageState {
  bool get usesVodQualityControls {
    return watchPorts.player.runtime.usingLiveDvrBridge ||
        watchPorts.player.runtime.usingExternalVodPlayback;
  }

  bool get shouldShowVodReplayChat {
    return offlineVodFallbackVideo != null || vodReplayController.active;
  }
}
