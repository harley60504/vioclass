import 'package:flutter/foundation.dart';

import '../../../models/discovery/twitch_live_stream.dart';
import '../../../models/playback/twitch_m3u8_variant.dart';
import '../../watch/twitch_playback_session_controller.dart';
import '../../watch/twitch_watch_playback_kind.dart';
import '../twitch_watch_page.dart';
import 'twitch_watch_page_startup.dart';
import 'twitch_watch_playback_state.dart';

// ignore_for_file: invalid_use_of_protected_member

extension TwitchRecordedWatchPlaybackMethods on TwitchWatchPageState {
  Future<bool> loadOfflineVodFallback({
    required String channel,
    required int generation,
  }) async {
    final fallbackChannel = widget.resolvedInitialOfflineChannel;
    final discoveryService = widget.initialDiscoveryService;
    if (!widget.initialOfflineFallbackAllowed) return false;
    if (fallbackChannel == null || discoveryService == null) return false;

    try {
      final page = await discoveryService.fetchChannelVideos(
        userId: fallbackChannel.broadcasterId,
        first: 1,
      );
      if (!isCurrentWatchTask(generation, channel)) return false;
      if (page.videos.isEmpty) {
        showOfflineChannelPlaceholder = true;
        playbackController.setError(null);
        if (mounted) setState(() {});
        return true;
      }

      final video = page.videos.first;
      if (video.isLikelyGrowingArchive) return false;
      showOfflineChannelPlaceholder = false;
      return openVodPlayback(
        channel: channel,
        generation: generation,
        video: video,
      );
    } catch (error) {
      if (isCurrentWatchTask(generation, channel)) {
        debugPrint('offline VOD fallback failed: $error');
      }
      return false;
    }
  }

  Future<bool> loadInitialVodPlayback({
    required String channel,
    required int generation,
  }) async {
    final video = widget.initialVodVideo;
    if (video == null) return false;

    try {
      rememberMediaUriForRouteRestore();
      if (usesLiveDvrArchive(video)) {
        activeGrowingVodVideo = video;
        await switchToLiveDvrReplay(
          video: video,
          position:
              positionForVodRatio(
                widget.initialVodReplayRatio,
                video.parsedDuration ?? currentLiveTimelineDuration(),
              ) ??
              defaultLiveDvrReplayPosition(),
        );
        if (mounted) setState(() {});
        return true;
      }
      return openVodPlayback(
        channel: channel,
        generation: generation,
        video: video,
        initialRatio: widget.initialVodReplayRatio,
        reuseCurrentPlayback: widget.initialReuseCurrentPlayback,
      );
    } catch (error) {
      if (isCurrentWatchTask(generation, channel)) {
        debugPrint('initial VOD playback failed: $error');
      }
      return false;
    }
  }

  Future<bool> loadInitialClipPlayback({
    required String channel,
    required int generation,
  }) async {
    final clip = widget.initialClip;
    if (clip == null) return false;

    try {
      rememberMediaUriForRouteRestore();
      final playback = await watchServices.playbackApi.resolveClipPlayback(
        clipSlug: clip.id,
        preferredQuality: 'source',
      );
      if (!isCurrentWatchTask(generation, channel)) return false;

      vodQualityVariants = playback.variants;
      currentVodQualityVariant = playback.selectedVariant;
      currentVodQualityVideo = null;
      currentClipQualityClip = clip;

      if (widget.initialReuseCurrentPlayback) {
        await playerSession.ensureReady();
        await preferencesController.applyPlayerVolume();
      } else {
        final playbackUri = playback.playbackUri.toString();
        await playbackController.openMedia(
          uri: playbackUri,
          play: true,
          forceOpen: true,
          waitForSettle: true,
        );
      }
      watchPorts.player.runtime.markExternalVodPlayback(channelLogin: channel);
      preferVodReplayChat = true;
      playbackController.setError(null);
      markOwnedPlayback(
        kind: TwitchWatchPlaybackKind.clip,
        mediaUri: playback.playbackUri.toString(),
      );

      final replayVideoId = (playback.sourceVideoId?.trim().isNotEmpty ?? false)
          ? playback.sourceVideoId!.trim()
          : clip.videoId.trim();
      final replayOffset = playback.sourceVodOffsetSeconds ?? clip.vodOffset;
      final replayChannel =
          (playback.broadcasterLogin?.trim().isNotEmpty ?? false)
          ? playback.broadcasterLogin!.trim()
          : channel;
      if (replayVideoId.isNotEmpty && replayOffset >= 0) {
        await vodReplayController.start(
          videoId: replayVideoId,
          channelLogin: replayChannel,
          player: playerSession.player,
          timelineOffsetSeconds: replayOffset.toDouble(),
        );
      }
      if (mounted) setState(() {});
      return true;
    } catch (error) {
      if (isCurrentWatchTask(generation, channel)) {
        debugPrint('initial clip playback failed: $error');
        showSnack('片段暫時載入失敗，請稍後再試。');
      }
      return false;
    }
  }

  void rememberMediaUriForRouteRestore() {
    if (restorePlaybackOnDispose != null) return;
    final session = TwitchPlaybackSessionController.instance;
    final current =
        session.playableStateBeforeRouteOwner(playbackRouteOwner) ??
        session.playableState;
    if (current == null) return;
    restorePlaybackOnDispose = current;
  }

  Future<bool> openVodPlayback({
    required String channel,
    required int generation,
    required TwitchChannelVideo video,
    double? initialRatio,
    Duration? initialLiveBackoff,
    bool reuseCurrentPlayback = false,
  }) async {
    if (usesLiveDvrArchive(video)) {
      activeGrowingVodVideo = video;
      debugPrint('[WatchVodOnly] growing archive redirected to live DVR bridge');
      await switchToLiveDvrReplay(
        video: video,
        position:
            positionForVodRatio(
              initialRatio,
              video.parsedDuration ?? currentLiveTimelineDuration(),
            ) ??
            defaultLiveDvrReplayPosition(),
      );
      return true;
    }

    final playlist = await watchServices.playbackApi.resolveVodPlaylist(
      videoId: video.id,
    );
    activeGrowingVodVideo = null;
    warmedLiveDvrVideoId = null;
    warmedLiveDvrQualityKey = null;
    warmedLiveDvrResolvedAt = null;
    watchPorts.player.runtime.setLiveDvrPlaylistOverride(null);
    vodQualityVariants = playlist.variants;
    currentVodQualityVariant = playlist.selectedVariant;
    currentVodQualityVideo = video;
    currentClipQualityClip = null;
    debugPrint(
      '[WatchVodOnly] video=${video.id} '
      'growing=${usesLiveDvrArchive(video)} '
      'duration=${video.duration} playlist=${playlist.playlistUri} '
      'variant=${playlist.selectedVariant?.name} '
      'variants=${playlist.variants.length}',
    );
    if (!isCurrentWatchTask(generation, channel)) return false;

    final playbackUri = playlist.playlistUri;
    debugPrint(
      '[WatchVodOnly] playbackUri=$playbackUri '
      'viaGrowingDvrProxy=${usesLiveDvrArchive(video)}',
    );
    if (!isCurrentWatchTask(generation, channel)) return false;
    final initialStartPosition = _initialVodStartPosition(
      duration: video.parsedDuration,
      initialRatio: initialRatio,
      initialLiveBackoff: initialLiveBackoff,
    );
    if (reuseCurrentPlayback) {
      await playerSession.ensureReady();
      await preferencesController.applyPlayerVolume();
    } else {
      await playbackController.openMedia(
        uri: playbackUri.toString(),
        play: true,
        forceOpen: true,
        startPosition: initialStartPosition,
        waitForSettle: true,
      );
      final duration = playerSession.player.state.duration;
      if (duration.inMilliseconds > 500) {
        final liveBackoff = initialLiveBackoff;
        if (liveBackoff != null) {
          final target = duration > liveBackoff
              ? duration - liveBackoff
              : Duration.zero;
          await playerSession.player.seek(target);
        } else if (initialRatio != null) {
          final target = Duration(
            milliseconds:
                (duration.inMilliseconds * initialRatio.clamp(0.0, 0.98)).round(),
          );
          await playerSession.player.seek(target);
        }
      }
    }

    if (!isCurrentWatchTask(generation, channel)) return false;
    offlineVodFallbackVideo = video;
    showOfflineChannelPlaceholder = false;
    preferVodReplayChat = true;
    watchPorts.player.runtime.markExternalVodPlayback(channelLogin: channel);
    playbackController.setError(null);
    markOwnedPlayback(
      kind: TwitchWatchPlaybackKind.vod,
      mediaUri: playbackUri.toString(),
    );
    await vodReplayController.start(
      videoId: video.id,
      channelLogin: channel,
      player: playerSession.player,
    );
    if (mounted) setState(() {});
    return true;
  }

  Future<void> switchVodQuality(TwitchM3u8Variant variant) async {
    final video = currentVodQualityVideo ?? activeGrowingVodVideo;
    final clip = currentClipQualityClip;
    if (video == null && clip == null) return;

    try {
      playbackController.setError(null);
      if (clip != null && video == null) {
        final position = playerSession.player.state.position;
        await playbackController.openMedia(
          uri: variant.url,
          play: true,
          forceOpen: true,
          startPosition: position,
        );
        currentVodQualityVariant = variant;
        markOwnedPlayback(
          kind: TwitchWatchPlaybackKind.clip,
          mediaUri: variant.url,
        );
        if (mounted) setState(() {});
        return;
      }

      if (video == null) return;
      if (usesLiveDvrArchive(video)) {
        final selectedUri = Uri.tryParse(variant.url);
        if (selectedUri == null) throw StateError('VOD 畫質 URL 無效。');
        final timelinePosition =
            currentLiveTimelinePosition() ?? defaultLiveDvrReplayPosition();
        final warmed = await watchPorts.player.runtime.warmLiveDvrBridge(
          dvrPlaylistUri: selectedUri,
        );
        if (!warmed) throw StateError('DVR 畫質切換失敗。');
        currentVodQualityVariant = variant;
        currentVodQualityVideo = video;
        warmedLiveDvrVideoId = video.id;
        warmedLiveDvrQualityKey = variant.adAwareQualityKey;
        warmedLiveDvrResolvedAt = DateTime.now();
        await seekLiveDvrBridgePlaybackAt(timelinePosition);
        return;
      }

      final duration = playerSession.player.state.duration;
      final position = playerSession.player.state.position;
      final startPosition = duration.inMilliseconds > 500
          ? Duration(
              milliseconds: position.inMilliseconds.clamp(
                0,
                duration.inMilliseconds,
              ),
            )
          : Duration.zero;
      await playbackController.openMedia(
        uri: variant.url,
        play: true,
        forceOpen: true,
        startPosition: startPosition,
      );
      currentVodQualityVariant = variant;
      currentVodQualityVideo = video;
      markOwnedPlayback(
        kind: TwitchWatchPlaybackKind.vod,
        mediaUri: variant.url,
      );
    } catch (error) {
      playbackController.setError(error.toString());
      showSnack('VOD 畫質切換失敗，請稍後再試。');
    }
    if (mounted) setState(() {});
  }

  Duration? _initialVodStartPosition({
    required Duration? duration,
    required double? initialRatio,
    required Duration? initialLiveBackoff,
  }) {
    if (duration == null || duration.inMilliseconds <= 500) return null;
    if (initialLiveBackoff != null) {
      return duration > initialLiveBackoff
          ? duration - initialLiveBackoff
          : Duration.zero;
    }
    if (initialRatio == null) return null;
    return Duration(
      milliseconds: (duration.inMilliseconds * initialRatio.clamp(0.0, 0.98))
          .round(),
    );
  }
}
