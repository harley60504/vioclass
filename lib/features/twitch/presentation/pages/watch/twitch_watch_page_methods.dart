part of twitch_watch_page;

extension _TwitchWatchPageMethods on _TwitchWatchPageState {
  Future<void> _loadWatchPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedChatPanelWidth =
          (prefs.getDouble(_chatPanelWidthPreferenceKey) ??
                  prefs.getDouble(_legacyChatPanelWidthPreferenceKey) ??
                  _chatPanelWidth)
              .clamp(_minChatPanelWidth, _maxChatPanelWidth)
              .toDouble();
      final savedChatPanelRatio =
          (prefs.getDouble(_chatPanelRatioPreferenceKey) ?? _chatPanelRatio)
              .clamp(_minStoredChatPanelRatio, _maxChatPanelRatio)
              .toDouble();
      final savedVolume =
          (prefs.getDouble(_playerVolumePreferenceKey) ??
                  prefs.getDouble(_legacyPlayerVolumePreferenceKey) ??
                  _volume)
              .clamp(0.0, 100.0)
              .toDouble();
      final savedMuted = prefs.getBool(_playerMutedPreferenceKey) ??
          prefs.getBool(_legacyPlayerMutedPreferenceKey) ??
          false;
      final savedChatVisible =
          prefs.getBool(_chatVisiblePreferenceKey) ?? _chatVisible;

      if (!mounted) return;
      setState(() {
        _chatPanelWidth = savedChatPanelWidth;
        _chatPanelRatio = savedChatPanelRatio;
        _volume = savedVolume;
        _lastNonZeroVolume = savedVolume > 0 ? savedVolume : 100.0;
        _isMuted = savedMuted;
        _chatVisible = savedChatVisible;
      });

      unawaited(_saveChatPanelWidthPreference());
      unawaited(_saveVolumePreference());
    } catch (error) {
      debugPrint('load watch preferences failed: $error');
    }

    await _applyPlayerVolume();
    _bindPlayerVolumeStream();
  }

  void _bindPlayerVolumeStream() {
    final previousCancel = _playerVolumeSubscription?.cancel();
    if (previousCancel != null) unawaited(previousCancel);
    // PiliPlus media_kit PlayerStream does not expose stream.volume.
    // WatchPage owns volume state through _setPlayerVolume / _togglePlayerMute.
    _playerVolumeSubscription = null;
  }

  Future<void> _setPlayerVolume(double value) async {
    final nextVolume = value.clamp(0.0, 100.0).toDouble();
    setState(() {
      _volume = nextVolume;
      _isMuted = nextVolume <= 0.0;
      if (nextVolume > 0.0) _lastNonZeroVolume = nextVolume;
    });
    final player = _playerSession.playerOrNull;
    if (player != null) {
      await player.setVolume(_isMuted ? 0.0 : nextVolume);
    }
    _scheduleVolumePreferenceSave();
  }

  Future<void> _togglePlayerMute() async {
    final nextMuted = !_isMuted;
    final nextVolume = nextMuted
        ? 0.0
        : (_volume > 0.0 ? _volume : _lastNonZeroVolume)
            .clamp(1.0, 100.0)
            .toDouble();
    setState(() {
      _isMuted = nextMuted;
      if (!nextMuted) {
        _volume = nextVolume;
        _lastNonZeroVolume = nextVolume;
      }
    });
    final player = _playerSession.playerOrNull;
    if (player != null) {
      await player.setVolume(nextMuted ? 0.0 : nextVolume);
    }
    _scheduleVolumePreferenceSave();
  }

  Future<void> _applyPlayerVolume() async {
    if (!_isMuted && _volume <= 0) {
      _volume = _lastNonZeroVolume.clamp(1.0, 100.0).toDouble();
    }
    final player = _playerSession.playerOrNull;
    if (player == null) return;
    await player.setVolume(
      _isMuted ? 0.0 : _volume.clamp(0.0, 100.0).toDouble(),
    );
  }

  void _scheduleVolumePreferenceSave() {
    _volumePreferenceSaveDebounce?.cancel();
    _volumePreferenceSaveDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_saveVolumePreference());
    });
  }

  Future<void> _saveVolumePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
        _playerVolumePreferenceKey,
        _volume.clamp(0.0, 100.0).toDouble(),
      );
      await prefs.setBool(_playerMutedPreferenceKey, _isMuted);
    } catch (error) {
      debugPrint('save watch volume preference failed: $error');
    }
  }

  Future<void> _saveChatVisiblePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chatVisiblePreferenceKey, _chatVisible);
    } catch (error) {
      debugPrint('save watch chat visibility preference failed: $error');
    }
  }

  Future<void> _saveChatPanelWidthPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
        _chatPanelWidthPreferenceKey,
        _chatPanelWidth.clamp(_minChatPanelWidth, _maxChatPanelWidth).toDouble(),
      );
      await prefs.setDouble(
        _chatPanelRatioPreferenceKey,
        _chatPanelRatio.clamp(_minStoredChatPanelRatio, _maxChatPanelRatio).toDouble(),
      );
    } catch (error) {
      debugPrint('save watch chat width preference failed: $error');
    }
  }

  void _setChatPanelWidthForViewport({
    required double viewportWidth,
    required double value,
  }) {
    if (viewportWidth <= 0) return;
    final ratioLimitedMin = viewportWidth * _minChatPanelRatio;
    final effectiveMinWidth = ratioLimitedMin
        .clamp(_minChatPanelWidth, _maxEffectiveMinChatPanelWidth)
        .toDouble();
    final effectiveMaxWidth = _maxChatPanelWidth
        .clamp(effectiveMinWidth, viewportWidth - 120.0)
        .toDouble();
    final nextWidth = value.clamp(effectiveMinWidth, effectiveMaxWidth).toDouble();
    final effectiveMinRatio = (effectiveMinWidth / viewportWidth)
        .clamp(_minStoredChatPanelRatio, _maxChatPanelRatio)
        .toDouble();
    final nextRatio = (nextWidth / viewportWidth)
        .clamp(effectiveMinRatio, _maxChatPanelRatio)
        .toDouble();

    if ((_chatPanelWidth - nextWidth).abs() < 0.5 &&
        (_chatPanelRatio - nextRatio).abs() < 0.002) {
      return;
    }

    setState(() {
      _chatPanelWidth = nextWidth;
      _chatPanelRatio = nextRatio;
    });
  }

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

  Future<void> _prepareWatchBackgroundSnapshot(int generation, String channel) async {
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

  Future<void> _runDeferredChatStartup(String channel, int generation) async {
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

  Future<void> _runDeferredEngagementStartup(int generation, String channel) async {
    try {
      await _refreshEngagement(showSnackOnError: false);
    } finally {
      if (_isCurrentWatchTask(generation, channel)) {
        setState(() => _engagementBootstrapping = false);
      }
    }
  }

  Future<void> _runDeferredEmoteStartup(int generation, String channel) async {
    try {
      await _loadThirdPartyEmotes();
    } finally {
      if (_isCurrentWatchTask(generation, channel)) {
        setState(() => _emoteBootstrapping = false);
      }
    }
  }

  Future<void> _runDeferredRelationshipStartup(int generation, String channel) async {
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

  Future<void> _connectChat(String channel) async {
    setState(() => _connectingChat = true);
    try {
      await _chatRuntime?.disposeRuntime();

      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw StateError('沒有可用 OAuth，不能連線可發言聊天室。');
      }

      await _dropsAuthService.loadStoredSession();
      final validation = await _authApi.validateToken(token);
      final startup = await _watchPorts.chat.fetchStartupSnapshot(channelLogin: channel);
      final runtime = TwitchChatRuntime(
        ircApi: TwitchIrcApiService(),
        writeIrcApi: TwitchIrcApiService(),
        badgeCache: TwitchBadgeCacheService(),
        recentMessagesApi: _recentMessagesApi,
      );

      if (!mounted) return;
      setState(() {
        _chatRuntime = runtime;
        _viewerLogin = validation.login;
        _viewerId = validation.userId;
        _viewerScopes = validation.scopes;
        _channelId = startup.channelId;
      });

      await runtime.connect(
        channelLogin: channel,
        accessToken: token,
        ircNick: validation.login,
        viewerLogin: validation.login,
        viewerDisplayName: validation.login,
        viewerUserId: validation.userId,
        badgeCatalog: startup.badgeCatalog,
        preloadRecentMessages: true,
        recentMessageLimit: 100,
      );
    } finally {
      if (mounted) setState(() => _connectingChat = false);
    }
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

  Future<void> _loadThirdPartyEmotes({bool forceRefresh = false}) async {
    final channelId = _channelId;
    if (channelId == null || channelId.isEmpty) return;

    setState(() => _loadingEmotes = true);
    try {
      await _watchPorts.emotes.loadForChannel(
        channelId: channelId,
        channelLogin: _channelLogin,
        viewerId: _viewerId ?? '',
        forceRefresh: forceRefresh,
      );
    } finally {
      if (mounted) setState(() => _loadingEmotes = false);
    }
  }

  Future<void> _refreshEngagement({bool showSnackOnError = true}) async {
    final channelLogin = _channelLogin;
    final channelId = _channelId;
    if (!mounted) return;

    setState(() {
      _loadingEngagement = true;
      _engagementError = null;
    });

    final snapshot = await _watchPorts.engagement.refresh(
      channelLogin: channelLogin,
      channelId: channelId,
    );

    if (!mounted || channelLogin != _channelLogin) return;
    final lastError = snapshot.error;
    setState(() {
      if (snapshot.channelPoints != null) _channelPointsSnapshot = snapshot.channelPoints;
      if (snapshot.prediction != null) _prediction = snapshot.prediction;
      _pinnedMessages = snapshot.pinnedMessages;
      _engagementError = lastError?.toString();
      _loadingEngagement = false;
    });

    if (lastError != null && showSnackOnError) {
      _showSnack('互動資料更新失敗：$lastError');
    }
  }

  Future<void> _refreshRelationshipStatus({String? channelLogin}) async {
    final login = (channelLogin ?? _channelLogin).trim().toLowerCase();
    if (login.isEmpty || _checkingRelationship) return;

    setState(() {
      _checkingRelationship = true;
      _relationshipError = null;
    });

    try {
      final snapshot = await _watchPorts.relationship.fetchRelationship(
        channelLogin: login,
        targetUserId: _channelId,
        viewerUserId: _viewerId,
      );
      if (!mounted) return;
      setState(() {
        _isFollowing = snapshot.isFollowing;
        if (snapshot.userId.trim().isNotEmpty) _channelId = snapshot.userId.trim();
        _relationshipError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _relationshipError = error.toString());
    } finally {
      if (mounted) setState(() => _checkingRelationship = false);
    }
  }

  Future<void> _toggleFollowChannel() async {
    if (_followBusy) return;
    final login = _channelLogin.trim().toLowerCase();
    if (login.isEmpty) return;

    setState(() {
      _followBusy = true;
      _relationshipError = null;
    });

    try {
      final snapshot = _isFollowing
          ? await _watchPorts.relationship.unfollowChannel(
              channelLogin: login,
              targetUserId: _channelId,
              viewerUserId: _viewerId,
            )
          : await _watchPorts.relationship.followChannel(
              channelLogin: login,
              targetUserId: _channelId,
              viewerUserId: _viewerId,
            );
      if (!mounted) return;
      setState(() {
        _isFollowing = snapshot.isFollowing;
        if (snapshot.userId.trim().isNotEmpty) _channelId = snapshot.userId.trim();
        _relationshipError = null;
      });
      _showSnack(_isFollowing ? '已追隨 $login' : '已取消追隨 $login');
    } catch (error) {
      if (mounted) {
        setState(() => _relationshipError = error.toString());
        _showSnack('追隨狀態更新失敗：$error');
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _openSubscribePage() async {
    try {
      final uri = _watchPorts.relationship.buildSubscribeUri(_channelLogin);
      await showTwitchSubscribeWebViewDialogV1(
        context: context,
        initialUri: uri,
        channelLogin: _channelLogin,
      );
    } catch (error) {
      _showSnack('開啟訂閱彈窗失敗：$error');
    }
  }

  Future<void> _enterMobileImmersiveByDefault() async {
    if (!TwitchFullscreenController.isMobilePlatform) return;
    try {
      await TwitchFullscreenController.setFullscreen(true);
      _mobileImmersiveEntered = true;
    } catch (_) {}
  }

  void _toggleChatVisibility() {
    setState(() => _chatVisible = !_chatVisible);
    unawaited(_saveChatVisiblePreference());
  }

  Future<void> _toggleFullscreenMode() async {
    final next = !_fullscreenMode;
    try {
      await TwitchFullscreenController.setFullscreen(next);
      if (!mounted) return;
      setState(() => _fullscreenMode = next);
    } catch (error) {
      _showSnack('切換全螢幕失敗：$error');
    }
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final runtime = _chatRuntime;
    if (runtime == null || !runtime.connected) {
      _showSnack('聊天室尚未連線。');
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _sending = true);
    try {
      await runtime.sendMessage(message);
      _messageController.clear();
    } catch (error) {
      _showSnack('發送失敗：$error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openEmotePicker() {
    return _sheetLauncher.openEmotePicker(context);
  }

  Future<void> _openChannelPointsSheet() {
    return _sheetLauncher.openChannelPointsSheet(context);
  }

  Future<void> _openPredictionBetSheet() {
    return _sheetLauncher.openPredictionBetSheet(context);
  }

  void _insertMessageText(String text) {
    final current = _messageController.text;
    final selection = _messageController.selection;
    final start = selection.start < 0 ? current.length : selection.start;
    final end = selection.end < 0 ? current.length : selection.end;
    final next = current.replaceRange(start, end, text);
    _messageController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
