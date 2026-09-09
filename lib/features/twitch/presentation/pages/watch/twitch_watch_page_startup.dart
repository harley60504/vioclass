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

const Duration _liveDvrWarmTtl = Duration(minutes: 8);
const Duration _liveReplaySeekWindowDuration = Duration(seconds: 20);
const Duration _liveReplayCacheDuration = Duration(seconds: 22);
const Duration _liveTimelineEdgeTolerance = Duration(milliseconds: 500);

enum _LiveTimelineSeekRoute { liveEdge, liveBuffer, dvrArchive }

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
        showOfflineChannelPlaceholder = false;
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
    ownedPlaybackForVisibleRoute = state;
    TwitchPlaybackSessionController.instance.setRoutePlayback(
      playbackRouteOwner,
      state,
    );

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
    if (video == null) return;
    final reusingBoundLiveDvr =
        widget.initialReuseCurrentPlayback &&
        liveTimelineStreamId?.trim().isNotEmpty == true &&
        liveTimelineStartedAt != null;
    if (!video.isLikelyGrowingArchive && !reusingBoundLiveDvr) return;

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

    final shouldRefreshLiveIdentity =
        widget.initialClip == null &&
        widget.initialVodVideo == null &&
        !widget.initialVodPlaybackOnly;
    if (shouldRefreshLiveIdentity) {
      await refreshLiveTimelineStartedAt(allowWithoutLivePlayback: true);
      if (!isCurrentWatchTask(generation, channel)) return;
    }

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
    showOfflineChannelPlaceholder = false;
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
      return await openVodPlayback(
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
      if (_usesLiveDvrArchive(video)) {
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
      return await openVodPlayback(
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

  bool _usesLiveDvrArchive(TwitchChannelVideo video) {
    final activeVideoId = activeGrowingVodVideo?.id.trim() ?? '';
    final videoId = video.id.trim();
    final isBoundToCurrentLive =
        videoId.isNotEmpty &&
        activeVideoId == videoId &&
        liveTimelineStreamId?.trim().isNotEmpty == true &&
        liveTimelineStartedAt != null;
    return isBoundToCurrentLive || video.isLikelyGrowingArchive;
  }

  Future<void> prepareActiveGrowingVod({
    required String channel,
    required int generation,
  }) async {
    final fallbackChannel = widget.resolvedInitialOfflineChannel;
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
      if (activeGrowingVodVideo == null) {
        warmedLiveDvrVideoId = null;
        warmedLiveDvrResolvedAt = null;
      }
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
    if (!_usesLiveDvrArchive(video)) return;
    final wasUsable = hasUsableLiveDvrArchive;

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
        warmedLiveDvrResolvedAt = DateTime.now();
        markOwnedPlayback(
          kind: currentPlaybackKind,
          mediaUri: TwitchMediaKitPlayerHost.currentMediaUri,
        );
      }
      if (wasUsable != hasUsableLiveDvrArchive) {
        playbackTimelineController.reset();
      }
      if (mounted) setState(() {});
    } catch (error) {
      warmedLiveDvrVideoId = null;
      warmedLiveDvrQualityKey = null;
      warmedLiveDvrResolvedAt = null;
      if (isCurrentWatchTask(generation, channel)) {
        debugPrint('warm live DVR bridge failed: $error');
        if (wasUsable != hasUsableLiveDvrArchive) {
          playbackTimelineController.reset();
        }
        if (mounted) setState(() {});
      }
    }
  }

  Future<bool> prepareLiveDvrBridgeSource(TwitchChannelVideo? video) async {
    if (video == null || !_usesLiveDvrArchive(video)) {
      watchPorts.player.runtime.setLiveDvrPlaylistOverride(null);
      return false;
    }

    final preferredQuality = _preferredLiveDvrQuality();
    final preferredQualityKey = _normalizeWatchQualityKey(preferredQuality);
    final warmedAt = warmedLiveDvrResolvedAt;
    final hasFreshWarmBridge =
        warmedAt != null &&
        DateTime.now().difference(warmedAt) < _liveDvrWarmTtl;
    if (warmedLiveDvrVideoId == video.id &&
        (preferredQualityKey == null ||
            warmedLiveDvrQualityKey == preferredQualityKey) &&
        watchPorts.player.runtime.hasWarmLiveDvrBridge &&
        hasFreshWarmBridge) {
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
        warmedLiveDvrResolvedAt = DateTime.now();
      }
      return warmed;
    } catch (error) {
      watchPorts.player.runtime.setLiveDvrPlaylistOverride(null);
      warmedLiveDvrVideoId = null;
      warmedLiveDvrQualityKey = null;
      warmedLiveDvrResolvedAt = null;
      debugPrint('prepare live DVR bridge failed: $error');
      return false;
    }
  }

  Future<void> openActiveDvrReplay({Duration? initialPosition}) async {
    final duration = currentLiveTimelineDuration();
    if (duration != null && duration.inMilliseconds > 0) {
      await openActiveDvrReplayAt(
        initialPosition ?? defaultLiveDvrReplayPosition(),
      );
      return;
    }

    final generation = watchLoadGeneration;
    final channel = channelLogin;
    final target = initialPosition ?? defaultLiveDvrReplayPosition();
    if (await tryOpenLiveBufferReplayAt(target)) {
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

    if (_usesLiveDvrArchive(video)) {
      await switchToLiveDvrReplay(video: video, position: target);
      return;
    }

    final loaded = await openVodPlayback(
      channel: channel,
      generation: generation,
      video: video,
      initialRatio: ratioForVodPosition(target, video.parsedDuration),
    );
    if (!loaded) showSnack('DVR 回放載入失敗。');
  }

  Future<void> openActiveDvrReplayAt(Duration target) async {
    final duration = currentLiveTimelineDuration();
    final targetMs = duration == null || duration.inMilliseconds <= 0
        ? target.inMilliseconds
        : target.inMilliseconds.clamp(0, duration.inMilliseconds).toInt();
    pendingLiveTimelineSeekTarget = Duration(milliseconds: targetMs);
    pendingLiveTimelineReturnToLive = false;
    await drainLiveTimelineActions();
  }

  Future<void> openActiveDvrReplayAtOnce(Duration target) async {
    final duration = currentLiveTimelineDuration();
    if (duration == null || duration.inMilliseconds <= 0) {
      await openActiveDvrReplay();
      return;
    }

    final safeTarget = clampLiveTimelinePosition(target, duration);
    final route = _liveTimelineSeekRoute(safeTarget, duration);

    final generation = watchLoadGeneration;
    final channel = channelLogin;
    switch (route) {
      case _LiveTimelineSeekRoute.liveEdge:
        await returnToLivePlaybackOnce();
        return;
      case _LiveTimelineSeekRoute.liveBuffer:
        if (await openLiveBufferReplayIfAvailable(safeTarget, duration)) {
          return;
        }
        if (!hasUsableLiveDvrArchive) return;
        break;
      case _LiveTimelineSeekRoute.dvrArchive:
        if (!hasUsableLiveDvrArchive) {
          final bufferStart = duration > _liveReplaySeekWindowDuration
              ? duration - _liveReplaySeekWindowDuration
              : Duration.zero;
          await openLiveBufferReplayIfAvailable(bufferStart, duration);
          return;
        }
        break;
    }

    if (watchPorts.player.runtime.usingLiveDvrBridge) {
      await seekLiveDvrBridgePlaybackAt(safeTarget);
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

    if (_usesLiveDvrArchive(video)) {
      final prepared = await prepareLiveDvrBridgeSource(video);
      if (!prepared) {
        showSnack('目前找不到可用的 DVR 播放來源。');
        return;
      }
      await seekLiveDvrBridgePlaybackAt(safeTarget);
      return;
    }

    final loaded = await openVodPlayback(
      channel: channel,
      generation: generation,
      video: video,
      initialRatio: ratioForVodPosition(safeTarget, video.parsedDuration),
    );
    if (!loaded) showSnack('DVR 回放載入失敗。');
  }

  Future<void> returnToLivePlayback() async {
    pendingLiveTimelineSeekTarget = null;
    pendingLiveTimelineReturnToLive = true;
    await drainLiveTimelineActions();
  }

  Future<void> drainLiveTimelineActions() async {
    if (liveTimelineActionInFlight) return;

    liveTimelineActionInFlight = true;
    try {
      while (mounted) {
        final shouldReturnToLive = pendingLiveTimelineReturnToLive;
        final nextTarget = pendingLiveTimelineSeekTarget;
        if (!shouldReturnToLive && nextTarget == null) break;

        pendingLiveTimelineReturnToLive = false;
        pendingLiveTimelineSeekTarget = null;
        final generation = watchLoadGeneration;
        final channel = channelLogin;

        if (shouldReturnToLive) {
          await returnToLivePlaybackOnce();
        } else if (nextTarget != null) {
          await openActiveDvrReplayAtOnce(nextTarget);
        }

        if (!isCurrentWatchTask(generation, channel)) {
          pendingLiveTimelineReturnToLive = false;
          pendingLiveTimelineSeekTarget = null;
          break;
        }
      }
    } finally {
      liveTimelineActionInFlight = false;
    }
  }

  Future<void> returnToLivePlaybackOnce() async {
    if (watchPorts.player.runtime.usingLiveTimelineReplay) {
      debugPrint('[LiveDvrBridge] return to low-latency live requested');
      await switchToLowLatencyLivePlayback();
      return;
    }
    if (!watchPorts.player.runtime.usingExternalVodPlayback) {
      debugPrint('[LiveDvrBridge] return to low-latency live ignored');
      return;
    }

    debugPrint('[LiveDvrBridge] return external replay to low-latency live');
    _clearExternalReplaySelection();
    await switchToLowLatencyLivePlayback();
  }

  Future<void> switchToLiveDvrReplay({
    required TwitchChannelVideo video,
    required Duration position,
  }) async {
    final prepared = await prepareLiveDvrBridgeSource(video);
    if (!prepared) {
      showSnack('目前找不到可用的 DVR 播放來源。');
      return;
    }
    await seekLiveDvrBridgePlaybackAt(position);
  }

  Future<void> seekLiveDvrBridgePlaybackAt(Duration target) async {
    final video = activeGrowingVodVideo;
    final timelineDuration = currentLiveTimelineDuration();
    final safeTarget = timelineDuration == null
        ? target
        : clampLiveTimelinePosition(target, timelineDuration);
    final timelineOffsetSeconds =
        timelineDuration == null || timelineDuration.inMilliseconds <= 0
        ? null
        : safeTarget.inMilliseconds / 1000;
    final playbackUrl = await watchPorts.player.runtime
        .seekLiveDvrBridgePosition(safeTarget);
    if (playbackUrl == null) return;
    await openLiveDvrBridgeMedia(playbackUrl);
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

  Future<void> openLiveDvrBridgeMedia(String playbackUrl) async {
    await playbackController.openMedia(
      uri: playbackUrl,
      play: true,
      forceOpen: true,
    );
  }

  Future<bool> tryOpenLiveBufferReplayAt(Duration target) async {
    final timelineDuration = currentLiveTimelineDuration();
    if (timelineDuration == null || timelineDuration.inMilliseconds <= 0) {
      return false;
    }

    return openLiveBufferReplayIfAvailable(target, timelineDuration);
  }

  Future<bool> openLiveBufferReplayIfAvailable(
    Duration target,
    Duration timelineDuration,
  ) async {
    final safeTarget = clampLiveTimelinePosition(target, timelineDuration);
    final fromLiveMs =
        timelineDuration.inMilliseconds - safeTarget.inMilliseconds;
    if (fromLiveMs <= 0 ||
        fromLiveMs > _liveReplayCacheDuration.inMilliseconds) {
      return false;
    }

    final playbackUrl = await watchPorts.player.runtime.seekLiveBufferReplay(
      fromLive: Duration(milliseconds: fromLiveMs),
      timelineDuration: timelineDuration,
    );
    if (playbackUrl == null) return false;

    vodReplayController.stop();
    preferVodReplayChat = false;
    playbackController.setError(null);
    await playbackController.openMedia(
      uri: playbackUrl,
      play: true,
      forceOpen: true,
    );
    markOwnedPlayback(
      kind: TwitchWatchPlaybackKind.liveDvr,
      mediaUri: playbackUrl,
    );
    if (mounted) setState(() {});
    return true;
  }

  _LiveTimelineSeekRoute _liveTimelineSeekRoute(
    Duration target,
    Duration timelineDuration,
  ) {
    final safeTarget = clampLiveTimelinePosition(target, timelineDuration);
    final fromLiveMs =
        timelineDuration.inMilliseconds - safeTarget.inMilliseconds;
    if (fromLiveMs <= _liveTimelineEdgeTolerance.inMilliseconds) {
      return _LiveTimelineSeekRoute.liveEdge;
    }
    if (fromLiveMs <= _liveReplaySeekWindowDuration.inMilliseconds) {
      return _LiveTimelineSeekRoute.liveBuffer;
    }
    return _LiveTimelineSeekRoute.dvrArchive;
  }

  Duration clampLiveTimelinePosition(
    Duration target,
    Duration timelineDuration,
  ) {
    if (timelineDuration.inMilliseconds <= 0) return Duration.zero;
    return Duration(
      milliseconds: target.inMilliseconds
          .clamp(0, timelineDuration.inMilliseconds)
          .toInt(),
    );
  }

  Duration? currentLiveTimelineDuration() {
    final startedAt = liveTimelineStartedAt;
    if (startedAt == null) return null;
    final elapsed = DateTime.now().toUtc().difference(startedAt.toUtc());
    return elapsed.isNegative ? null : elapsed;
  }

  Duration? currentLiveTimelinePosition() {
    final runtimePosition =
        watchPorts.player.runtime.liveDvrBridgeTimelinePosition;
    if (runtimePosition != null && runtimePosition >= Duration.zero) {
      return runtimePosition;
    }

    final timelineDuration = currentLiveTimelineDuration();
    final playerPosition = playerSession.playerOrNull?.state.position;
    if (playerPosition != null && playerPosition >= Duration.zero) {
      if (timelineDuration == null || timelineDuration.inMilliseconds <= 0) {
        return playerPosition;
      }
      return Duration(
        milliseconds: playerPosition.inMilliseconds
            .clamp(0, timelineDuration.inMilliseconds)
            .toInt(),
      );
    }

    return null;
  }

  Duration defaultLiveDvrReplayPosition() {
    final timelineDuration = currentLiveTimelineDuration();
    if (timelineDuration == null || timelineDuration.inMilliseconds <= 0) {
      return Duration.zero;
    }
    final backoff = _liveReplaySeekWindowDuration ~/ 2;
    if (timelineDuration <= backoff) return Duration.zero;
    return timelineDuration - backoff;
  }

  double? ratioForVodPosition(Duration position, Duration? duration) {
    if (duration == null || duration.inMilliseconds <= 0) return null;
    return (position.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  Duration? positionForVodRatio(double? ratio, Duration? duration) {
    if (ratio == null || duration == null || duration.inMilliseconds <= 0) {
      return null;
    }
    return Duration(
      milliseconds: (duration.inMilliseconds * ratio.clamp(0.0, 1.0)).round(),
    );
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

  void _clearExternalReplaySelection() {
    offlineVodFallbackVideo = null;
    currentVodQualityVideo = null;
    currentClipQualityClip = null;
    vodQualityVariants = const <TwitchM3u8Variant>[];
    currentVodQualityVariant = null;
    preferVodReplayChat = false;
  }

  Future<bool> openVodPlayback({
    required String channel,
    required int generation,
    required TwitchChannelVideo video,
    double? initialRatio,
    Duration? initialLiveBackoff,
    bool reuseCurrentPlayback = false,
  }) async {
    if (_usesLiveDvrArchive(video)) {
      activeGrowingVodVideo = video;
      debugPrint(
        '[WatchVodOnly] growing archive redirected to live DVR bridge',
      );
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
      'growing=${_usesLiveDvrArchive(video)} '
      'duration=${video.duration} playlist=${playlist.playlistUri} '
      'variant=${playlist.selectedVariant?.name} '
      'variants=${playlist.variants.length}',
    );
    if (!isCurrentWatchTask(generation, channel)) return false;

    final playbackUri = playlist.playlistUri;
    debugPrint(
      '[WatchVodOnly] playbackUri=$playbackUri '
      'viaGrowingDvrProxy=${_usesLiveDvrArchive(video)}',
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
      if (_usesLiveDvrArchive(video)) {
        final selectedUri = Uri.tryParse(variant.url);
        if (selectedUri == null) {
          throw StateError('VOD 畫質 URL 無效。');
        }
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
