part of twitch_watch_page;

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
        _viewerScopes = validation.scopes;
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
      _playerError = null;
      _engagementError = null;
      _relationshipError = null;
      _chatBootstrapping = false;
      _engagementBootstrapping = false;
      _emoteBootstrapping = false;
      _relationshipBootstrapping = false;
    });

    try {
      await _stopCurrentSession(clearStatus: false, cancelDeferredTasks: false);
      if (!_isCurrentWatchTask(generation, channel)) return;

      setState(() => _loadingWatch = false);
      unawaited(_runWatchStartupPipeline(channel: channel, generation: generation));
    } catch (error) {
      if (mounted) _showSnack('載入 Watch Page 失敗：$error');
    } finally {
      if (mounted && generation == _watchLoadGeneration && _loadingWatch) {
        setState(() => _loadingWatch = false);
      }
    }
  }

  Future<void> _loadPlayer(String channel) async {
    if (!_enableWatchPlayer) {
      if (mounted) {
        setState(() {
          _loadingPlayer = false;
          _playerError = null;
        });
      }
      return;
    }

    setState(() {
      _loadingPlayer = true;
      _playerError = null;
    });

    try {
      await _watchPorts.player.openLive(channelLogin: channel);
      await _applyPlayerVolume();
      await _waitForInitialPlaybackSettle();
    } catch (error) {
      _playerError = error.toString();
      rethrow;
    } finally {
      if (mounted) setState(() => _loadingPlayer = false);
    }
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
    await _yieldToUi();
    if (!_isCurrentWatchTask(generation, channel)) return;

    setState(() => _relationshipBootstrapping = true);
    await _prepareWatchBackgroundSnapshot(generation, channel);
    if (!_isCurrentWatchTask(generation, channel)) return;
    await _runDeferredRelationshipStartup(generation, channel);
    await _yieldToUi();
    if (!_isCurrentWatchTask(generation, channel)) return;

    setState(() => _engagementBootstrapping = true);
    await _runDeferredEngagementStartup(generation, channel);
    await _yieldToUi();
    if (!_isCurrentWatchTask(generation, channel)) return;

    setState(() => _emoteBootstrapping = true);
    await _runDeferredEmoteStartup(generation, channel);
    await _yieldToUi();
    if (!_isCurrentWatchTask(generation, channel)) return;

    setState(() => _chatBootstrapping = true);
    await _runDeferredChatStartup(channel, generation);
    await _yieldToUi();
    if (!_isCurrentWatchTask(generation, channel)) return;

    if (_enableWatchPlayer) {
      await _yieldToUi();
      await _loadPlayer(channel);
    }
  }

  Future<void> _yieldToUi() async {
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _prepareWatchBackgroundSnapshot(
    int generation,
    String channel,
  ) async {
    try {
      final startup = await _watchPorts.chat.fetchStartupSnapshot(channelLogin: channel);
      if (!_isCurrentWatchTask(generation, channel)) return;
      final nextChannelId = startup.channelId.trim();
      if (nextChannelId.isNotEmpty && nextChannelId != _channelId) {
        setState(() => _channelId = nextChannelId);
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

    await _chatRuntime?.disconnect();
    _watchPorts.emotes.clear();

    if (!mounted) return;
    setState(() {
      _channelId = null;
      _channelPointsSnapshot = null;
      _prediction = null;
      _pinnedMessages = const <dynamic>[];
      _engagementError = null;
      _playerError = null;
      _relationshipError = null;
      _isFollowing = false;
      _chatBootstrapping = false;
      _engagementBootstrapping = false;
      _emoteBootstrapping = false;
      _relationshipBootstrapping = false;
    });
  }
}
