part of '../twitch_watch_page.dart';

extension _TwitchWatchPageChatPart on _TwitchWatchPageState {
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
      final startup = await _watchPorts.chat.fetchStartupSnapshot(
        channelLogin: channel,
      );
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
