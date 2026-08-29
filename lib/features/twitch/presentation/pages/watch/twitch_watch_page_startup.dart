import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/discovery/twitch_live_stream.dart';
import '../../../models/playback/twitch_m3u8_variant.dart';
import '../../../services/playback/twitch_media_kit_player_host.dart';
import '../../watch/twitch_playback_session_controller.dart';
import '../../watch/twitch_watch_playback_kind.dart';
import '../twitch_watch_page.dart';
import 'twitch_watch_page_chat.dart';
import 'twitch_watch_page_engagement.dart';
import 'twitch_watch_playback_state.dart';
import 'twitch_watch_page_relationship.dart';

// ignore_for_file: invalid_use_of_protected_member

const double _liveDvrLiveEdgeRatio = 0.98;

extension TwitchWatchPageStartupMethods on TwitchWatchPageState {
  Future<void> loadAuth() async {
    setState(() => loadingAuth = true);
    try {
      await authService.loadStoredSession();
      await webGqlAuthService.loadStoredSession();
      await dropsAuthService.loadStoredSession();

      final token = await authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => loadingAuth = false);
        return;
      }

      final validation = await authApi.validateToken(token);
      if (!mounted) return;
      setState(() {
        viewerLogin = validation.login;
        viewerId = validation.userId;
        loadingAuth = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loadingAuth = false);
      showSnack('OAuth 暫時載入失敗，請稍後再試。');
    }
  }

  Future<void> loadWatch() async {
    if (loadingWatch) return;
    final channel = channelLogin;
    cancelDeferredWatchTasks();
    final generation = ++watchLoadGeneration;
    final reuseCurrentPlayback = reuseCurrentPlaybackOnNextLiveLoad;
    reuseCurrentPlaybackOnNextLiveLoad = false;

    setState(() {
      loadingWatch = true;
      chatBootstrapping = false;
      engagementBootstrapping = false;
      emoteBootstrapping = false;
      relationshipBootstrapping = false;
    });
    playbackController.resetError();
    engagementController.engagementError = null;
    relationshipController.relationshipError = null;
    chatController.loadingSpecialMessages = false;

    try {
      final restoredPlayback = reuseCurrentPlayback
          ? await restoreCurrentPlaybackBundle(channel, generation)
          : false;
      if (!restoredPlayback) {
        await stopCurrentSession(
          clearStatus: false,
          cancelDeferredTasks: false,
        );
        if (!isCurrentWatchTask(generation, channel)) return;
        primeInitialActiveDvrAvailability(channel, generation);
      }

      setState(() => loadingWatch = false);
      unawaited(
        runWatchStartupPipeline(
          channel: channel,
          generation: generation,
          reuseCurrentLivePlayback: reuseCurrentPlayback,
          skipPlaybackStartup: restoredPlayback,
        ),
      );
    } catch (error) {
      if (mounted) showSnack('觀看頁暫時載入失敗，請稍後再試。');
    } finally {
      if (mounted && generation == watchLoadGeneration && loadingWatch) {
        setState(() => loadingWatch = false);
      }
    }
  }

  Future<bool> restoreCurrentPlaybackBundle(
    String channel,
    int generation,
  ) async {
    final state = TwitchPlaybackSessionController.instance.playableState;
    if (state == null) return false;
    final currentUri = TwitchMediaKitPlayerHost.currentMediaUri?.trim();
    if (currentUri == null ||
        currentUri.isEmpty ||
        currentUri != state.mediaUri.trim()) {
      return false;
    }

    await playerSession.ensureReady();
    if (!isCurrentWatchTask(generation, channel)) return false;
    await preferencesController.applyPlayerVolume();
    playbackController.setError(null);

    activeGrowingVodVideo = state.activeDvrVideo;
    currentVodQualityVideo = state.kind == TwitchWatchPlaybackKind.clip
        ? null
        : state.vodVideo ?? state.activeDvrVideo;
    currentClipQualityClip = state.clip;
    offlineVodFallbackVideo = state.kind == TwitchWatchPlaybackKind.vod
        ? state.vodVideo
        : null;
    preferVodReplayChat =
        state.preferVodReplayChat ||
        state.kind == TwitchWatchPlaybackKind.vod ||
        state.kind == TwitchWatchPlaybackKind.clip;

    if (state.kind == TwitchWatchPlaybackKind.vod ||
        state.kind == TwitchWatchPlaybackKind.clip) {
      watchPorts.player.runtime.markExternalVodPlayback(channelLogin: channel);
    }

    final replayVideo = state.kind == TwitchWatchPlaybackKind.clip
        ? state.clip?.videoId.trim()
        : state.vodVideo?.id.trim() ?? state.activeDvrVideo?.id.trim();
    if (state.usesReplayChat && replayVideo != null && replayVideo.isNotEmpty) {
      final timelineOffsetSeconds = state.kind == TwitchWatchPlaybackKind.clip
          ? state.clip?.vodOffset.toDouble()
          : null;
      unawaited(
        vodReplayController.start(
          videoId: replayVideo,
          channelLogin: channel,
          player: playerSession.player,
          timelineOffsetSeconds: timelineOffsetSeconds,
        ),
      );
    }

    if (mounted) setState(() {});
    return true;
  }

  Future<void> loadPlayer(String channel, {bool forceOpen = true}) async {
    await playbackController.loadPlayer(
      channelLogin: channel,
      enabled: enableWatchPlayer,
      forceOpen: forceOpen,
    );
    markOwnedPlayback(
      kind: TwitchWatchPlaybackKind.live,
      mediaUri: TwitchMediaKitPlayerHost.currentMediaUri,
    );
  }

  void primeInitialActiveDvrAvailability(String channel, int generation) {
    final video = widget.initialActiveDvrVideo;
    if (video == null || !video.isLikelyGrowingArchive) return;

    activeGrowingVodVideo = video;
    currentVodQualityVideo ??= video;
    preferVodReplayChat = widget.initialPreferVodReplayChat;
    unawaited(
      warmLiveDvrBridgeSource(
        video: video,
        channel: channel,
        generation: generation,
      ),
    );
  }

  Future<void> waitForInitialPlaybackSettle() async {
    final player = playerSession.playerOrNull;
    if (player == null) return;

    if (player.state.playing) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      return;
    }

    final completer = Completer<void>();
    StreamSubscription<bool>? playingSubscription;
    Timer? timeout;

    void complete() {
      if (completer.isCompleted) return;
      completer.complete();
      final playingCancel = playingSubscription?.cancel();
      if (playingCancel != null) unawaited(playingCancel);
      timeout?.cancel();
    }

    playingSubscription = player.stream.playing.listen((playing) {
      if (playing) Timer(const Duration(milliseconds: 180), complete);
    });
    timeout = Timer(const Duration(milliseconds: 850), complete);
    return completer.future;
  }

  Future<void> runWatchStartupPipeline({
    required String channel,
    required int generation,
    bool reuseCurrentLivePlayback = false,
    bool skipPlaybackStartup = false,
  }) async {
    await yieldToUi();
    if (!isCurrentWatchTask(generation, channel)) return;

    var chatStartedEarly = false;
    if (reuseCurrentLivePlayback) {
      setState(() => chatBootstrapping = true);
      chatStartedEarly = true;
      unawaited(runDeferredChatStartup(channel, generation));
    }

    if (enableWatchPlayer && !skipPlaybackStartup) {
      try {
        final loadedInitialClip = await loadInitialClipPlayback(
          channel: channel,
          generation: generation,
        );
        if (!isCurrentWatchTask(generation, channel)) return;
        if (loadedInitialClip) {
          setState(() {
            relationshipBootstrapping = true;
            emoteBootstrapping = true;
          });
          unawaited(runDeferredRelationshipStartup(generation, channel));
          unawaited(runDeferredEmoteStartup(generation, channel));
          return;
        }

        final loadedInitialVod = await loadInitialVodPlayback(
          channel: channel,
          generation: generation,
        );
        if (!loadedInitialVod) {
          if (widget.initialVodPlaybackOnly) {
            showSnack('VOD 載入失敗，沒有切回直播。');
          } else if (reuseCurrentLivePlayback) {
            playbackController.setError(null);
            await preferencesController.applyPlayerVolume();
            markOwnedPlayback(
              kind:
                  widget.initialActiveDvrVideo != null &&
                      widget.initialPreferVodReplayChat
                  ? TwitchWatchPlaybackKind.liveDvr
                  : TwitchWatchPlaybackKind.live,
              mediaUri: TwitchMediaKitPlayerHost.currentMediaUri,
            );
            if (activeGrowingVodVideo == null) {
              unawaited(
                prepareActiveGrowingVod(
                  channel: channel,
                  generation: generation,
                ),
              );
            }
          } else {
            await loadPlayer(channel, forceOpen: !reuseCurrentLivePlayback);
            if (!isCurrentWatchTask(generation, channel)) return;
            unawaited(
              prepareActiveGrowingVod(channel: channel, generation: generation),
            );
          }
        }
      } catch (error) {
        if (!isCurrentWatchTask(generation, channel)) return;
        if (widget.initialVodPlaybackOnly) {
          showSnack('VOD 暫時載入失敗，請稍後再試。');
          return;
        }
        final loadedVod = await loadOfflineVodFallback(
          channel: channel,
          generation: generation,
        );
        if (!loadedVod) {
          showSnack('播放器暫時載入失敗，請稍後再試。');
        }
      }
    }

    await yieldToUi();
    if (!isCurrentWatchTask(generation, channel)) return;

    setState(() {
      if (!chatStartedEarly) chatBootstrapping = true;
      relationshipBootstrapping = true;
      engagementBootstrapping = true;
      emoteBootstrapping = true;
    });

    unawaited(
      runWatchBackgroundStartup(channel: channel, generation: generation),
    );
    if (!chatStartedEarly) {
      await runDeferredChatStartup(channel, generation);
    }
  }

  Future<void> runWatchBackgroundStartup({
    required String channel,
    required int generation,
  }) async {
    if (!isCurrentWatchTask(generation, channel)) return;

    await prepareWatchBackgroundSnapshot(generation, channel);
    if (!isCurrentWatchTask(generation, channel)) return;

    await Future.wait<void>([
      runDeferredRelationshipStartup(generation, channel),
      runDeferredEngagementStartup(generation, channel),
      runDeferredEmoteStartup(generation, channel),
      runDeferredSpecialMessagesStartup(generation, channel),
    ]);
  }

  Future<void> yieldToUi() async {
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> prepareWatchBackgroundSnapshot(
    int generation,
    String channel,
  ) async {
    try {
      final startup = await watchPorts.chat.fetchStartupSnapshot(
        channelLogin: channel,
      );
      if (!isCurrentWatchTask(generation, channel)) return;
      final nextChannelId = startup.channelId.trim();
      if (nextChannelId.isNotEmpty && nextChannelId != channelId) {
        setResolvedChannelId(nextChannelId);
      }
    } catch (error) {
      debugPrint('prepare watch background snapshot failed: $error');
    }
  }

  bool isCurrentWatchTask(int generation, String channel) {
    return mounted &&
        generation == watchLoadGeneration &&
        channel.trim().toLowerCase() == channelLogin;
  }

  void cancelDeferredWatchTasks({bool rebuild = true}) {
    if (!mounted) return;
    if (!rebuild) {
      chatBootstrapping = false;
      engagementBootstrapping = false;
      emoteBootstrapping = false;
      relationshipBootstrapping = false;
      return;
    }
    setState(() {
      chatBootstrapping = false;
      engagementBootstrapping = false;
      emoteBootstrapping = false;
      relationshipBootstrapping = false;
    });
  }

  Future<void> stopCurrentSession({
    bool clearStatus = true,
    bool cancelDeferredTasks = true,
  }) async {
    if (cancelDeferredTasks) {
      watchLoadGeneration++;
      cancelDeferredWatchTasks();
    }

    await chatController.disconnect();
    watchPorts.emotes.clear();
    engagementController.reset();
    chatController.resetSpecialMessages();
    vodReplayController.stop();
    playbackController.resetError();
    relationshipController.reset();
    offlineVodFallbackVideo = null;
    activeGrowingVodVideo = null;
    currentVodQualityVideo = null;
    currentClipQualityClip = null;
    vodQualityVariants = const <TwitchM3u8Variant>[];
    currentVodQualityVariant = null;
    warmedLiveDvrVideoId = null;
    warmedLiveDvrQualityKey = null;
    preferVodReplayChat = false;
    watchPorts.player.runtime.setLiveDvrPlaylistOverride(null);
    clearOwnedPlayback();

    if (!mounted) return;
    setState(() {
      channelId = null;
      chatBootstrapping = false;
      engagementBootstrapping = false;
      emoteBootstrapping = false;
      relationshipBootstrapping = false;
    });
  }

  Future<bool> loadOfflineVodFallback({
    required String channel,
    required int generation,
  }) async {
    final fallbackChannel = widget.initialOfflineChannel;
    final discoveryService = widget.initialDiscoveryService;
    if (fallbackChannel == null || discoveryService == null) return false;

    try {
      final page = await discoveryService.fetchChannelVideos(
        userId: fallbackChannel.broadcasterId,
        first: 1,
      );
      if (!isCurrentWatchTask(generation, channel)) return false;
      if (page.videos.isEmpty) return false;

      final video = page.videos.first;
      if (video.isLikelyGrowingArchive) return false;
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
      if (video.isLikelyGrowingArchive) {
        activeGrowingVodVideo = video;
        await switchToLiveDvrReplay(
          video: video,
          ratio: widget.initialVodReplayRatio ?? 0.92,
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
    final current = TwitchPlaybackSessionController.instance.playableState;
    if (current == null) return;
    restorePlaybackOnDispose = current;
  }

  Future<void> prepareActiveGrowingVod({
    required String channel,
    required int generation,
  }) async {
    final fallbackChannel = widget.initialOfflineChannel;
    final discoveryService = widget.initialDiscoveryService;
    if (fallbackChannel == null || discoveryService == null) return;

    try {
      final page = await discoveryService.fetchChannelVideos(
        userId: fallbackChannel.broadcasterId,
        first: 1,
      );
      if (!isCurrentWatchTask(generation, channel)) return;
      final video = page.videos.isEmpty ? null : page.videos.first;
      activeGrowingVodVideo = video != null && video.isLikelyGrowingArchive
          ? video
          : null;
      if (activeGrowingVodVideo == null) warmedLiveDvrVideoId = null;
      watchPorts.player.runtime.setLiveDvrPlaylistOverride(null);
      if (activeGrowingVodVideo != null) {
        markOwnedPlayback(
          kind: currentPlaybackKind,
          mediaUri: TwitchMediaKitPlayerHost.currentMediaUri,
        );
        unawaited(
          warmLiveDvrBridgeSource(
            video: activeGrowingVodVideo!,
            channel: channel,
            generation: generation,
          ),
        );
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (isCurrentWatchTask(generation, channel)) {
        debugPrint('prepare active growing VOD failed: $error');
      }
    }
  }

  Future<void> warmLiveDvrBridgeSource({
    required TwitchChannelVideo video,
    required String channel,
    required int generation,
  }) async {
    if (!video.isLikelyGrowingArchive) return;

    try {
      final playlist = await watchServices.playbackApi.resolveVodPlaylist(
        videoId: video.id,
        preferredQuality: _preferredLiveDvrQuality(),
      );
      if (!isCurrentWatchTask(generation, channel)) return;
      final warmed = await watchPorts.player.runtime.warmLiveDvrBridge(
        dvrPlaylistUri: playlist.playlistUri,
      );
      vodQualityVariants = playlist.variants;
      currentVodQualityVariant = playlist.selectedVariant;
      currentVodQualityVideo = video;
      currentClipQualityClip = null;
      if (warmed) {
        warmedLiveDvrVideoId = video.id;
        warmedLiveDvrQualityKey = playlist.selectedVariant?.adAwareQualityKey;
        markOwnedPlayback(
          kind: currentPlaybackKind,
          mediaUri: TwitchMediaKitPlayerHost.currentMediaUri,
        );
      }
    } catch (error) {
      warmedLiveDvrVideoId = null;
      if (isCurrentWatchTask(generation, channel)) {
        debugPrint('warm live DVR bridge failed: $error');
      }
    }
  }

  Future<bool> prepareLiveDvrBridgeSource(TwitchChannelVideo? video) async {
    if (video == null || !video.isLikelyGrowingArchive) {
      watchPorts.player.runtime.setLiveDvrPlaylistOverride(null);
      return false;
    }

    final preferredQuality = _preferredLiveDvrQuality();
    final preferredQualityKey = _normalizeWatchQualityKey(preferredQuality);
    if (warmedLiveDvrVideoId == video.id &&
        (preferredQualityKey == null ||
            warmedLiveDvrQualityKey == preferredQualityKey) &&
        watchPorts.player.runtime.hasWarmLiveDvrBridge) {
      debugPrint(
        '[LiveDvrBridge] reuse warmed active archive video=${video.id}',
      );
      return true;
    }

    try {
      final playlist = await watchServices.playbackApi.resolveVodPlaylist(
        videoId: video.id,
        preferredQuality: preferredQuality,
      );
      watchPorts.player.runtime.setLiveDvrPlaylistOverride(null);
      final warmed = await watchPorts.player.runtime.warmLiveDvrBridge(
        dvrPlaylistUri: playlist.playlistUri,
      );
      vodQualityVariants = playlist.variants;
      currentVodQualityVariant = playlist.selectedVariant;
      currentVodQualityVideo = video;
      currentClipQualityClip = null;
      debugPrint(
        '[LiveDvrBridge] active archive warmed video=${video.id} '
        'dvr=${playlist.playlistUri} warmed=$warmed',
      );
      if (warmed) warmedLiveDvrVideoId = video.id;
      if (warmed) {
        warmedLiveDvrQualityKey = playlist.selectedVariant?.adAwareQualityKey;
      }
      return warmed;
    } catch (error) {
      watchPorts.player.runtime.setLiveDvrPlaylistOverride(null);
      warmedLiveDvrVideoId = null;
      warmedLiveDvrQualityKey = null;
      debugPrint('prepare live DVR bridge failed: $error');
      return false;
    }
  }

  Future<void> openActiveDvrReplay({double initialRatio = 0.92}) async {
    final generation = watchLoadGeneration;
    final channel = channelLogin;
    if (watchPorts.player.runtime.usingLiveDvrBridge) {
      await seekLiveDvrBridgePlayback(initialRatio);
      return;
    }

    var video = activeGrowingVodVideo;

    if (video == null) {
      await prepareActiveGrowingVod(channel: channel, generation: generation);
      video = activeGrowingVodVideo;
    }
    if (video == null) {
      showSnack('目前找不到可回看的直播 VOD。');
      return;
    }

    if (video.isLikelyGrowingArchive) {
      await switchToLiveDvrReplay(video: video, ratio: initialRatio);
      return;
    }

    final loaded = await openVodPlayback(
      channel: channel,
      generation: generation,
      video: video,
      initialRatio: initialRatio,
    );
    if (!loaded) showSnack('DVR 回放載入失敗。');
  }

  Future<void> returnToLivePlayback() async {
    debugPrint('[LiveDvrBridge] return to low-latency live requested');
    if (watchPorts.player.runtime.usingLiveDvrBridge) {
      await switchToLowLatencyLivePlayback();
      return;
    }
    if (!watchPorts.player.runtime.usingExternalVodPlayback) return;

    offlineVodFallbackVideo = null;
    await switchToLowLatencyLivePlayback();
  }

  Future<void> switchToLiveDvrReplay({
    required TwitchChannelVideo video,
    required double ratio,
  }) async {
    final prepared = await prepareLiveDvrBridgeSource(video);
    if (!prepared) {
      showSnack('目前找不到可用的 DVR 播放來源。');
      return;
    }
    await seekLiveDvrBridgePlayback(ratio);
  }

  Future<void> seekLiveDvrBridgePlayback(double ratio) async {
    final atLiveEdge = ratio >= _liveDvrLiveEdgeRatio;
    if (atLiveEdge) {
      await switchToLowLatencyLivePlayback();
      return;
    }
    final video = activeGrowingVodVideo;
    final timelineDuration =
        watchPorts.player.runtime.liveDvrBridgeDuration ??
        video?.parsedDuration;
    final timelineOffsetSeconds =
        timelineDuration == null || timelineDuration.inMilliseconds <= 0
        ? null
        : timelineDuration.inMilliseconds *
              ratio.clamp(0.0, _liveDvrLiveEdgeRatio) /
              1000;
    final playbackUrl = await watchPorts.player.runtime.seekLiveDvrBridgeRatio(
      ratio,
    );
    if (playbackUrl == null) return;
    await playbackController.openMedia(
      uri: playbackUrl,
      play: true,
      forceOpen: true,
    );
    if (video != null) {
      preferVodReplayChat = true;
      markOwnedPlayback(
        kind: TwitchWatchPlaybackKind.liveDvr,
        mediaUri: playbackUrl,
      );
      await vodReplayController.start(
        videoId: video.id,
        channelLogin: channelLogin,
        player: playerSession.player,
        timelineOffsetSeconds: timelineOffsetSeconds,
      );
    } else {
      markOwnedPlayback(
        kind: TwitchWatchPlaybackKind.liveDvr,
        mediaUri: playbackUrl,
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> switchToLowLatencyLivePlayback() async {
    debugPrint('[LiveDvrBridge] switch to low-latency live');
    watchPorts.player.runtime.setLiveDvrPlaylistOverride(null);
    vodReplayController.stop();
    preferVodReplayChat = false;
    playbackController.setError(null);
    if (mounted) setState(() {});
    final preparedUri = await watchPorts.player.runtime
        .prepareLowLatencyLiveFromWarmUpstream();
    if (preparedUri != null) {
      await playbackController.openMedia(
        uri: preparedUri.toString(),
        play: true,
        forceOpen: true,
      );
      markOwnedPlayback(
        kind: TwitchWatchPlaybackKind.live,
        mediaUri: preparedUri.toString(),
      );
    } else {
      await loadPlayer(channelLogin, forceOpen: true);
    }
    await preferencesController.applyPlayerVolume();
  }

  Future<bool> openVodPlayback({
    required String channel,
    required int generation,
    required TwitchChannelVideo video,
    double? initialRatio,
    Duration? initialLiveBackoff,
    bool reuseCurrentPlayback = false,
  }) async {
    if (video.isLikelyGrowingArchive) {
      activeGrowingVodVideo = video;
      debugPrint(
        '[WatchVodOnly] growing archive redirected to live DVR bridge',
      );
      await switchToLiveDvrReplay(video: video, ratio: initialRatio ?? 0.92);
      return true;
    }

    final playlist = await watchServices.playbackApi.resolveVodPlaylist(
      videoId: video.id,
    );
    vodQualityVariants = playlist.variants;
    currentVodQualityVariant = playlist.selectedVariant;
    currentVodQualityVideo = video;
    currentClipQualityClip = null;
    debugPrint(
      '[WatchVodOnly] video=${video.id} '
      'growing=${video.isLikelyGrowingArchive} '
      'duration=${video.duration} playlist=${playlist.playlistUri} '
      'variant=${playlist.selectedVariant?.name} '
      'variants=${playlist.variants.length}',
    );
    if (!isCurrentWatchTask(generation, channel)) return false;

    final playbackUri = playlist.playlistUri;
    debugPrint(
      '[WatchVodOnly] playbackUri=$playbackUri '
      'viaGrowingDvrProxy=${video.isLikelyGrowingArchive}',
    );
    if (!isCurrentWatchTask(generation, channel)) return false;
    final expectedDuration = video.parsedDuration;
    final initialStartPosition = _initialVodStartPosition(
      duration: expectedDuration,
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
        } else {
          final ratio = initialRatio;
          if (ratio != null) {
            final target = Duration(
              milliseconds: (duration.inMilliseconds * ratio.clamp(0.0, 0.98))
                  .round(),
            );
            await playerSession.player.seek(target);
          }
        }
      }
    }

    if (!isCurrentWatchTask(generation, channel)) return false;
    offlineVodFallbackVideo = video;
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
      if (video.isLikelyGrowingArchive) {
        final selectedUri = Uri.tryParse(variant.url);
        if (selectedUri == null) {
          throw StateError('VOD 畫質 URL 無效。');
        }
        final warmed = await watchPorts.player.runtime.warmLiveDvrBridge(
          dvrPlaylistUri: selectedUri,
        );
        if (!warmed) throw StateError('DVR 畫質切換失敗。');
        currentVodQualityVariant = variant;
        currentVodQualityVideo = video;
        warmedLiveDvrVideoId = video.id;
        warmedLiveDvrQualityKey = variant.adAwareQualityKey;
        final ratio =
            watchPorts.player.runtime.liveDvrBridgeTimelineRatio ?? 0.92;
        await seekLiveDvrBridgePlayback(ratio);
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

  String _preferredLiveDvrQuality() {
    final current = watchPorts.player.runtime.currentVariant;
    if (current == null) return 'source';
    final key = current.adAwareQualityKey.trim();
    return key.isEmpty || key == 'unknown' ? current.name : key;
  }

  String? _normalizeWatchQualityKey(String value) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty || text == 'source' || text == 'best') return null;
    return text
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('_', '')
        .replaceAll('-', '');
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
