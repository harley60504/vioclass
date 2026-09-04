import 'package:flutter/foundation.dart';

import '../../../services/playback/twitch_media_kit_player_host.dart';
import '../../watch/twitch_playback_session_controller.dart';
import '../../watch/twitch_watch_playback_kind.dart';
import '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension TwitchWatchPlaybackStateMethods on TwitchWatchPageState {
  void markOwnedPlayback({
    required TwitchWatchPlaybackKind kind,
    required String? mediaUri,
  }) {
    final safeUri = mediaUri?.trim();
    final title = currentClipQualityClip?.title.trim().isNotEmpty == true
        ? currentClipQualityClip!.title
        : (currentVodQualityVideo ??
                  activeGrowingVodVideo ??
                  offlineVodFallbackVideo)
              ?.title;
    final resumeVodVideo = switch (kind) {
      TwitchWatchPlaybackKind.liveDvr || TwitchWatchPlaybackKind.vod =>
        currentVodQualityVideo ??
            activeGrowingVodVideo ??
            offlineVodFallbackVideo,
      TwitchWatchPlaybackKind.live => activeGrowingVodVideo,
      _ => null,
    };
    TwitchPlaybackSessionController.instance.setPlayback(
      kind: safeUri == null || safeUri.isEmpty
          ? TwitchWatchPlaybackKind.none
          : kind,
      mediaUri: safeUri,
      metadata: widget.resolvedInitialMetadata.copyWith(
        channelLogin: channelLogin,
        streamTitle: title,
      ),
      activeDvrVideo: activeGrowingVodVideo,
      vodVideo: resumeVodVideo,
      clip: kind == TwitchWatchPlaybackKind.clip
          ? currentClipQualityClip
          : null,
      vodRatio: kind == TwitchWatchPlaybackKind.liveDvr
          ? watchPorts.player.runtime.liveDvrBridgeTimelineRatio
          : activeGrowingVodVideo != null
          ? 1.0
          : null,
      preferVodReplayChat: preferVodReplayChat,
    );
    ownedPlaybackForVisibleRoute =
        TwitchPlaybackSessionController.instance.playableState;
    TwitchPlaybackSessionController.instance.setRoutePlayback(
      playbackRouteOwner,
      ownedPlaybackForVisibleRoute,
    );
  }

  void clearOwnedPlayback() {
    TwitchPlaybackSessionController.instance.clear();
    ownedPlaybackForVisibleRoute = null;
    TwitchPlaybackSessionController.instance.clearRoutePlayback(
      playbackRouteOwner,
    );
  }

  TwitchPlaybackSessionState? buildPlaybackSnapshot() {
    final currentUri = TwitchMediaKitPlayerHost.currentMediaUri?.trim();
    final state = TwitchPlaybackSessionController.instance
        .playableStateForMediaUri(currentUri);
    if (state == null) {
      final ownedUri =
          TwitchPlaybackSessionController.instance.playableState?.mediaUri
              .trim() ??
          '';
      debugPrint(
        '[WatchPlaybackState] skip mini snapshot because owner uri is stale: '
        'owned=$ownedUri current=$currentUri',
      );
      return null;
    }

    return state;
  }

  Future<void> reconcileVisibleRoutePlayback() async {
    final owned = ownedPlaybackForVisibleRoute;
    if (owned == null || !owned.playable) return;

    var ownedUri = owned.mediaUri.trim();
    final currentUri = TwitchMediaKitPlayerHost.currentMediaUri?.trim();

    TwitchPlaybackSessionController.instance.restorePlayback(owned);

    if (owned.kind == TwitchWatchPlaybackKind.live) {
      final preparedUri = await watchPorts.player.runtime
          .prepareLowLatencyLiveFromWarmUpstream();
      if (preparedUri != null) {
        ownedUri = preparedUri.toString();
        markOwnedPlayback(
          kind: TwitchWatchPlaybackKind.live,
          mediaUri: ownedUri,
        );
      }
    }

    debugPrint(
      '[WatchPlaybackState] restore visible route playback '
      'kind=${owned.kind} uri=$ownedUri current=$currentUri',
    );
    await TwitchMediaKitPlayerHost.restoreSharedMedia(
      uri: ownedUri,
      play: true,
      forceOpen: true,
    );

    await preferencesController.applyPlayerVolume();
    if (mounted) setState(() {});
  }

  TwitchWatchPlaybackKind get currentPlaybackKind {
    if (currentClipQualityClip != null) return TwitchWatchPlaybackKind.clip;
    if (watchPorts.player.runtime.usingLiveDvrBridge) {
      return TwitchWatchPlaybackKind.liveDvr;
    }
    if (watchPorts.player.runtime.usingExternalVodPlayback ||
        offlineVodFallbackVideo != null ||
        preferVodReplayChat) {
      return TwitchWatchPlaybackKind.vod;
    }
    return TwitchWatchPlaybackKind.live;
  }

  bool get usesVodQualityControls {
    return watchPorts.player.runtime.usingLiveDvrBridge ||
        watchPorts.player.runtime.usingExternalVodPlayback;
  }

  bool get shouldShowVodReplayChat {
    return offlineVodFallbackVideo != null || vodReplayController.active;
  }

  bool get hasDvrReplayPlayback {
    return watchPorts.player.runtime.usingLiveDvrBridge ||
        watchPorts.player.runtime.usingExternalVodPlayback ||
        activeGrowingVodVideo != null;
  }

  bool get showsLiveDvrEdgeLabel {
    return watchPorts.player.runtime.usingLiveDvrBridge ||
        activeGrowingVodVideo != null;
  }
}
