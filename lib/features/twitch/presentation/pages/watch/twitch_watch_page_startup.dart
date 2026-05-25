part of '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _TwitchWatchPageStartupMethods on _TwitchWatchPageState {
  Future<void> _loadAuth() async {
    setState(() => _loadingAuth = true);
    try {
      await _authService.loadStoredSession();
      await _webGqlAuthService.loadStoredSession();
      await _dropsAuthService.loadStoredSession();

      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => _loadingAuth = false);
        return;
      }

      final validation = await _authApi.validateToken(token);
      if (!mounted) return;
      setState(() {
        _viewerLogin = validation.login;
        _viewerId = validation.userId;
        _loadingAuth = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingAuth = false);
      _showSnack('OAuth 載入失敗：$error');
    }
  }

  Future<void> _loadWatch() async {
    if (_loadingWatch) return;
    final channel = _channelLogin;
    _cancelDeferredWatchTasks();
    final generation = ++_watchLoadGeneration;

    setState(() {
      _loadingWatch = true;
      _chatBootstrapping = false;
      _engagementBootstrapping = false;
      _emoteBootstrapping = false;
      _relationshipBootstrapping = false;
    });
    _playbackController.resetError();
    _engagementController.engagementError = null;
    _relationshipController.relationshipError = null;
    _chatController.loadingSpecialMessages = false;

    try {
      await _stopCurrentSession(clearStatus: false, cancelDeferredTasks: false);
      if (!_isCurrentWatchTask(generation, channel)) return;

      setState(() => _loadingWatch = false);
      unawaited(
        _runWatchStartupPipeline(channel: channel, generation: generation),
      );
    } catch (error) {
      if (mounted) _showSnack('載入 Watch Page 失敗：$error');
    } finally {
      if (mounted && generation == _watchLoadGeneration && _loadingWatch) {
        setState(() => _loadingWatch = false);
      }
    }
  }

  Future<void> _loadPlayer(String channel) async {
    return _playbackController.loadPlayer(
      channelLogin: channel,
      enabled: _enableWatchPlayer,
    );
  }

  Future<void> _waitForInitialPlaybackSettle() async {
    final player = _playerSession.playerOrNull;
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

  Future<void> _runWatchStartupPipeline({
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
    await _yieldToUi();
    if (!_isCurrentWatchTask(generation, channel)) return;

    if (_enableWatchPlayer) {
      try {
        await _loadPlayer(channel);
      } catch (error) {
        if (!_isCurrentWatchTask(generation, channel)) return;
        _showSnack('播放器載入失敗：$error');
      }
    }

    await _yieldToUi();
    if (!_isCurrentWatchTask(generation, channel)) return;

    setState(() {
      _chatBootstrapping = true;
      _relationshipBootstrapping = true;
      _engagementBootstrapping = true;
      _emoteBootstrapping = true;
    });

    unawaited(
      _runWatchBackgroundStartup(channel: channel, generation: generation),
    );
    await _runDeferredChatStartup(channel, generation);
  }

  Future<void> _runWatchBackgroundStartup({
    required String channel,
    required int generation,
  }) async {
    if (!_isCurrentWatchTask(generation, channel)) return;

    await _prepareWatchBackgroundSnapshot(generation, channel);
    if (!_isCurrentWatchTask(generation, channel)) return;

    await Future.wait<void>([
      _runDeferredRelationshipStartup(generation, channel),
      _runDeferredEngagementStartup(generation, channel),
      _runDeferredEmoteStartup(generation, channel),
      _runDeferredSpecialMessagesStartup(generation, channel),
    ]);
  }

  Future<void> _yieldToUi() async {
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _prepareWatchBackgroundSnapshot(
    int generation,
    String channel,
  ) async {
    try {
      final startup = await _watchPorts.chat.fetchStartupSnapshot(
        channelLogin: channel,
      );
      if (!_isCurrentWatchTask(generation, channel)) return;
      final nextChannelId = startup.channelId.trim();
      if (nextChannelId.isNotEmpty && nextChannelId != _channelId) {
        _setResolvedChannelId(nextChannelId);
      }
    } catch (error) {
      debugPrint('prepare watch background snapshot failed: $error');
    }
  }

  bool _isCurrentWatchTask(int generation, String channel) {
    return mounted &&
        generation == _watchLoadGeneration &&
        channel.trim().toLowerCase() == _channelLogin;
  }

  void _cancelDeferredWatchTasks() {
    if (!mounted) return;
    setState(() {
      _chatBootstrapping = false;
      _engagementBootstrapping = false;
      _emoteBootstrapping = false;
      _relationshipBootstrapping = false;
    });
  }

  Future<void> _stopCurrentSession({
    bool clearStatus = true,
    bool cancelDeferredTasks = true,
  }) async {
    if (cancelDeferredTasks) {
      _watchLoadGeneration++;
      _cancelDeferredWatchTasks();
    }

    await _chatController.disconnect();
    _watchPorts.emotes.clear();
    _engagementController.reset();
    _chatController.resetSpecialMessages();
    _playbackController.resetError();
    _relationshipController.reset();

    if (!mounted) return;
    setState(() {
      _channelId = null;
      _chatBootstrapping = false;
      _engagementBootstrapping = false;
      _emoteBootstrapping = false;
      _relationshipBootstrapping = false;
    });
  }
}
