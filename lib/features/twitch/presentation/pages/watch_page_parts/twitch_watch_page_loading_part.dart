part of '../twitch_watch_page.dart';

extension _TwitchWatchPageLoadingPart on _TwitchWatchPageState {
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
      await _stopCurrentSession(
        clearStatus: false,
        cancelDeferredTasks: false,
      );
      if (!_isCurrentWatchTask(generation, channel)) return;

      await _loadPlayer(channel);
      if (!_isCurrentWatchTask(generation, channel)) return;

      setState(() => _loadingWatch = false);
      unawaited(_runWatchStartupPipeline(
        channel: channel,
        generation: generation,
      ));
    } catch (error) {
      if (mounted) _showSnack('載入 Watch Page 失敗：$error');
    } finally {
      if (mounted && generation == _watchLoadGeneration && _loadingWatch) {
        setState(() => _loadingWatch = false);
      }
    }
  }

  Future<void> _runWatchStartupPipeline({
    required String channel,
    required int generation,
  }) async {
    await _yieldToUi();
    if (!_isCurrentWatchTask(generation, channel)) return;

    setState(() => _chatBootstrapping = true);
    await _runDeferredChatStartup(channel, generation);
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

    setState(() => _relationshipBootstrapping = true);
    await _runDeferredRelationshipStartup(generation, channel);
  }

  Future<void> _yieldToUi() async {
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _runDeferredChatStartup(
    String channel,
    int generation,
  ) async {
    try {
      await _connectChat(channel);
    } catch (error) {
      if (_isCurrentWatchTask(generation, channel)) {
        _showSnack('聊天室連線失敗：$error');
      }
    } finally {
      if (_isCurrentWatchTask(generation, channel)) {
        setState(() => _chatBootstrapping = false);
      }
    }
  }

  Future<void> _runDeferredEngagementStartup(
    int generation,
    String channel,
  ) async {
    try {
      await _refreshEngagement(showSnackOnError: false);
    } finally {
      if (_isCurrentWatchTask(generation, channel)) {
        setState(() => _engagementBootstrapping = false);
      }
    }
  }

  Future<void> _runDeferredEmoteStartup(
    int generation,
    String channel,
  ) async {
    try {
      await _loadThirdPartyEmotes();
    } finally {
      if (_isCurrentWatchTask(generation, channel)) {
        setState(() => _emoteBootstrapping = false);
      }
    }
  }

  Future<void> _runDeferredRelationshipStartup(
    int generation,
    String channel,
  ) async {
    try {
      await _refreshRelationshipStatus(channelLogin: channel);
    } finally {
      if (_isCurrentWatchTask(generation, channel)) {
        setState(() => _relationshipBootstrapping = false);
      }
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
}
