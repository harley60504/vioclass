import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/playback/twitch_media_kit_player_host.dart';
import '../../watch/twitch_playback_session_controller.dart';
import '../../watch/twitch_watch_playback_kind.dart';
import '../twitch_watch_page.dart';
import 'twitch_live_watch_playback.dart';
import 'twitch_recorded_watch_playback.dart';
import 'twitch_watch_page_chat.dart';
import 'twitch_watch_page_engagement.dart';
import 'twitch_watch_playback_state.dart';
import 'twitch_watch_page_relationship.dart';

export 'twitch_live_watch_playback.dart';
export 'twitch_recorded_watch_playback.dart';

// ignore_for_file: invalid_use_of_protected_member

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

    if (watchMode == TwitchWatchMode.liveWatch) {
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
          if (watchMode == TwitchWatchMode.recordedWatch) {
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
        if (watchMode == TwitchWatchMode.recordedWatch) {
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
    vodQualityVariants = const [];
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
}
