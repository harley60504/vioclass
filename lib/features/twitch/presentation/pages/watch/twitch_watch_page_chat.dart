part of twitch_watch_page;

extension _TwitchWatchPageChatMethods on _TwitchWatchPageState {
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

  Future<void> _sendMessage() async {
    if (_sending) return;
    final runtime = _chatRuntime;
    if (runtime == null || !runtime.connected) {
      _showSnack('聊天室尚未連線。');
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final pending = _pendingSpecialMessage;
    if (pending != null) {
      await _sendPendingSpecialMessagePreview(pending, message);
      return;
    }

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

  Future<void> _sendPendingSpecialMessagePreview(
    TwitchPendingSpecialMessageStage250 pending,
    String message,
  ) async {
    setState(() => _sending = true);
    try {
      // Stage 250A only verifies the unified composer flow. Do not call Twitch
      // special-message APIs yet; later stages will dispatch by pending.kind.
      _showSnack('特殊訊息預覽：${pending.describeForLog(message: message)}');
      _messageController.clear();
      _clearPendingSpecialMessage();
    } catch (error) {
      _showSnack('特殊訊息處理失敗：$error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _setPreviewPendingSpecialMessage() {
    setState(() {
      _pendingSpecialMessage = TwitchPendingSpecialMessageStage250(
        kind: TwitchPendingSpecialMessageKind.preview,
        channelLogin: _channelLogin,
        channelId: _channelId,
        title: '特殊訊息流程測試',
        subtitle: '這只會測試輸入欄上方提示與送出流程，不會真的發 Twitch 特殊訊息。',
        costLabel: '測試',
        previewOnly: true,
      );
    });
  }

  void _clearPendingSpecialMessage() {
    if (_pendingSpecialMessage == null) return;
    setState(() => _pendingSpecialMessage = null);
  }

  void _toggleChatVisibility() {
    setState(() => _chatVisible = !_chatVisible);
    unawaited(_saveChatVisiblePreference());
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
}
