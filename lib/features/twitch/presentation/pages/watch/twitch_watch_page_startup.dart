import 'dart:async';

import 'package:flutter/foundation.dart';

import '../twitch_watch_page.dart';
import 'twitch_watch_page_chat.dart';
import 'twitch_watch_page_engagement.dart';
import 'twitch_watch_page_relationship.dart';

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
      showSnack('OAuth 載入失敗：$error');
    }
  }

  Future<void> loadWatch() async {
    if (loadingWatch) return;
    final channel = channelLogin;
    cancelDeferredWatchTasks();
    final generation = ++watchLoadGeneration;

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
      await stopCurrentSession(clearStatus: false, cancelDeferredTasks: false);
      if (!isCurrentWatchTask(generation, channel)) return;

      setState(() => loadingWatch = false);
      unawaited(
        runWatchStartupPipeline(channel: channel, generation: generation),
      );
    } catch (error) {
      if (mounted) showSnack('載入 Watch Page 失敗：$error');
    } finally {
      if (mounted && generation == watchLoadGeneration && loadingWatch) {
        setState(() => loadingWatch = false);
      }
    }
  }

  Future<void> loadPlayer(String channel) async {
    return playbackController.loadPlayer(
      channelLogin: channel,
      enabled: enableWatchPlayer,
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
  }) async {
    // Stage 245A startup order:
    // 1. Open player first for fastest first paint.
    // 2. Start chat and engagement bootstrap at the same time.
    //    Engagement covers channel points, prediction, and pinned chat. It is
    //    background work, so the blocking mask still only waits on player/chat.
    // 3. Relationship / emotes continue as background tasks after the startup
    //    snapshot gives us channelId.
    await yieldToUi();
    if (!isCurrentWatchTask(generation, channel)) return;

    if (enableWatchPlayer) {
      try {
        await loadPlayer(channel);
      } catch (error) {
        if (!isCurrentWatchTask(generation, channel)) return;
        showSnack('播放器載入失敗：$error');
      }
    }

    await yieldToUi();
    if (!isCurrentWatchTask(generation, channel)) return;

    setState(() {
      chatBootstrapping = true;
      relationshipBootstrapping = true;
      engagementBootstrapping = true;
      emoteBootstrapping = true;
    });

    unawaited(
      runWatchBackgroundStartup(channel: channel, generation: generation),
    );
    await runDeferredChatStartup(channel, generation);
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

  void cancelDeferredWatchTasks() {
    if (!mounted) return;
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
    playbackController.resetError();
    relationshipController.reset();

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
