import 'package:flutter/foundation.dart';

import '../../../services/playback/twitch_media_kit_player_host.dart';
import '../../watch/twitch_playback_session_controller.dart';
import '../../watch/twitch_watch_playback_kind.dart';
import '../twitch_watch_page.dart';
import 'twitch_live_watch_state.dart';

export 'twitch_live_watch_state.dart';
export 'twitch_recorded_watch_state.dart';

// ignore_for_file: invalid_use_of_protected_member

extension TwitchWatchPlaybackStateMethods on TwitchWatchPageState {
  void markOwnedPlayback({
    required TwitchWatchPlaybackKind kind,
    required String? mediaUri,
  }) {
    final session = TwitchPlaybackSessionController.instance;
    final existingOwned =
        session.playableStateForRouteOwner(playbackRouteOwner) ??
        ownedPlaybackForVisibleRoute;
    final isTopOwner = session.isTopRouteOwner(playbackRouteOwner);
    final safeUri = isTopOwner
        ? mediaUri?.trim()
        : existingOwned?.mediaUri.trim() ?? mediaUri?.trim();
    final effectiveKind = isTopOwner ? kind : existingOwned?.kind ?? kind;
    final isLive = effectiveKind == TwitchWatchPlaybackKind.live;
    final usesLiveTimeline =
        isLive || effectiveKind == TwitchWatchPlaybackKind.liveDvr;
    final replayTitle = currentClipQualityClip?.title.trim().isNotEmpty == true
        ? currentClipQualityClip!.title
        : (currentVodQualityVideo ??
                  activeGrowingVodVideo ??
                  offlineVodFallbackVideo)
              ?.title;
    final streamTitle = isLive
        ? widget.resolvedInitialMetadata.streamTitle
        : replayTitle;
    final resumeVodVideo = switch (effectiveKind) {
      TwitchWatchPlaybackKind.liveDvr => activeGrowingVodVideo,
      TwitchWatchPlaybackKind.vod =>
        currentVodQualityVideo ?? offlineVodFallbackVideo,
      TwitchWatchPlaybackKind.live => activeGrowingVodVideo,
      _ => null,
    };
    final effectivePreferVodReplayChat = switch (effectiveKind) {
      TwitchWatchPlaybackKind.live => false,
      TwitchWatchPlaybackKind.liveDvr =>
        activeGrowingVodVideo != null && preferVodReplayChat,
      TwitchWatchPlaybackKind.vod || TwitchWatchPlaybackKind.clip => true,
      TwitchWatchPlaybackKind.none => false,
    };
    session.setRouteOwnedPlayback(
      owner: playbackRouteOwner,
      kind: safeUri == null || safeUri.isEmpty
          ? TwitchWatchPlaybackKind.none
          : effectiveKind,
      mediaUri: safeUri,
      metadata: widget.resolvedInitialMetadata.copyWith(
        streamId: usesLiveTimeline ? liveTimelineStreamId ?? '' : null,
        channelLogin: channelLogin,
        streamTitle: streamTitle,
        startedAt: usesLiveTimeline ? liveTimelineStartedAt : null,
        clearStartedAt: usesLiveTimeline && liveTimelineStartedAt == null,
      ),
      activeDvrVideo: activeGrowingVodVideo,
      vodVideo: resumeVodVideo,
      clip: effectiveKind == TwitchWatchPlaybackKind.clip
          ? currentClipQualityClip
          : null,
      vodRatio: effectiveKind == TwitchWatchPlaybackKind.liveDvr
          ? null
          : activeGrowingVodVideo != null
          ? 1.0
          : null,
      preferVodReplayChat: effectivePreferVodReplayChat,
    );
    ownedPlaybackForVisibleRoute = session.playableStateForRouteOwner(
      playbackRouteOwner,
    );
  }

  void applyPlaybackSessionStateToPage(TwitchPlaybackSessionState state) {
    if (state.kind == TwitchWatchPlaybackKind.live ||
        state.kind == TwitchWatchPlaybackKind.liveDvr) {
      final streamId = state.metadata.streamId.trim();
      liveTimelineStreamId = streamId.isEmpty ? null : streamId;
      liveTimelineStartedAt = state.metadata.startedAt;
    }
    activeGrowingVodVideo = state.activeDvrVideo;
    currentClipQualityClip = state.kind == TwitchWatchPlaybackKind.clip
        ? state.clip
        : null;
    currentVodQualityVideo = switch (state.kind) {
      TwitchWatchPlaybackKind.live => null,
      TwitchWatchPlaybackKind.clip => null,
      TwitchWatchPlaybackKind.liveDvr => state.activeDvrVideo ?? state.vodVideo,
      TwitchWatchPlaybackKind.vod => state.vodVideo,
      TwitchWatchPlaybackKind.none => null,
    };
    offlineVodFallbackVideo = state.kind == TwitchWatchPlaybackKind.vod
        ? state.vodVideo
        : null;
    preferVodReplayChat = switch (state.kind) {
      TwitchWatchPlaybackKind.live => false,
      TwitchWatchPlaybackKind.liveDvr => state.preferVodReplayChat,
      TwitchWatchPlaybackKind.vod || TwitchWatchPlaybackKind.clip => true,
      TwitchWatchPlaybackKind.none => false,
    };
  }

  void clearOwnedPlayback() {
    ownedPlaybackForVisibleRoute = null;
    TwitchPlaybackSessionController.instance.clearRoutePlayback(
      playbackRouteOwner,
    );
    if (TwitchPlaybackSessionController.instance.isTopRouteOwner(
      playbackRouteOwner,
    )) {
      TwitchPlaybackSessionController.instance.clear();
    }
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

  Future<void> reconcileVisibleRoutePlayback({
    bool forceOpen = false,
    bool forceProxyReconnect = false,
  }) async {
    final session = TwitchPlaybackSessionController.instance;
    if (!session.isTopRouteOwner(playbackRouteOwner)) return;

    final owned =
        session.playableStateForRouteOwner(playbackRouteOwner) ??
        ownedPlaybackForVisibleRoute;
    if (owned == null || !owned.playable) return;

    var ownedUri = owned.mediaUri.trim();
    final currentUri = TwitchMediaKitPlayerHost.currentMediaUri?.trim();
    final previousPosition = playerSession.playerOrNull?.state.position;

    ownedPlaybackForVisibleRoute = owned;
    applyPlaybackSessionStateToPage(owned);
    session.restorePlayback(owned);

    if (owned.kind == TwitchWatchPlaybackKind.live) {
      var shouldForceProxyReconnect = forceProxyReconnect;
      if (shouldForceProxyReconnect &&
          currentUri != null &&
          currentUri.isNotEmpty &&
          currentUri == ownedUri &&
          playerSession.playerOrNull != null) {
        final liveStatus = await watchPorts.player.runtime.refreshProxyLiveStatus(
          notify: false,
        );
        final existingConnectionIsHealthy =
            liveStatus != null && liveStatus.running && liveStatus.hasWriter;
        if (existingConnectionIsHealthy) {
          shouldForceProxyReconnect = false;
          debugPrint(
            '[WatchPlaybackState] keep foreground live connection '
            'clients=${liveStatus.activeClientCount} '
            'sequence=${liveStatus.lastWrittenSequence}',
          );
        }
      }

      final preparedUri = await watchPorts.player.runtime
          .prepareLowLatencyLiveFromWarmUpstream(
            forceProxyReconnect: shouldForceProxyReconnect,
          );
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
      forceOpen: forceOpen || currentUri != ownedUri,
    );
    if (forceOpen &&
        owned.kind != TwitchWatchPlaybackKind.live &&
        previousPosition != null &&
        previousPosition > Duration.zero) {
      await playerSession.player.seek(previousPosition);
    }

    await preferencesController.applyPlayerVolume();
    if (mounted) setState(() {});
  }

  TwitchWatchPlaybackKind get currentPlaybackKind {
    ensureWatchModeRuntime(this);
    if (currentClipQualityClip != null) return TwitchWatchPlaybackKind.clip;
    if (watchPorts.player.runtime.usingLiveTimelineReplay) {
      return TwitchWatchPlaybackKind.liveDvr;
    }
    if (watchPorts.player.runtime.usingExternalVodPlayback ||
        offlineVodFallbackVideo != null ||
        preferVodReplayChat) {
      return TwitchWatchPlaybackKind.vod;
    }
    return TwitchWatchPlaybackKind.live;
  }
}
