part of '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

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

  Future<void> _connectChat(String channel) {
    return _chatController.connectChat(channel);
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      await _chatController.sendMessage(message);
      _messageController.clear();
    } catch (_) {}
  }

  Future<void> _runDeferredSpecialMessagesStartup(
    int generation,
    String channel,
  ) async {
    await _refreshSpecialMessages(
      generation: generation,
      channel: channel,
      autoSelectPending: true,
      showSnackOnError: false,
    );
  }

  Future<TwitchViewerSpecialMessagesSnapshotStage251?> _refreshSpecialMessages({
    int? generation,
    String? channel,
    bool autoSelectPending = true,
    bool showSnackOnError = true,
  }) async {
    final targetChannel = channel ?? _channelLogin;
    if (generation != null && !_isCurrentWatchTask(generation, targetChannel)) {
      return null;
    }

    try {
      final snapshot = await _chatController.loadSpecialMessages(
        targetChannel: targetChannel,
        autoSelectPending: autoSelectPending,
      );
      if (generation != null &&
          !_isCurrentWatchTask(generation, targetChannel)) {
        return null;
      }
      return snapshot;
    } catch (error) {
      if (showSnackOnError) _showSnack('特殊訊息載入失敗：$error');
      return null;
    }
  }

  TwitchPendingSpecialMessage _pendingFromWatchStreak(
    TwitchWatchStreakStatusStage251 status,
  ) {
    return _chatController.pendingFromWatchStreak(status);
  }

  TwitchPendingSpecialMessage _pendingFromResub(
    TwitchResubNotificationStage251 resub,
  ) {
    return _chatController.pendingFromResub(resub);
  }

  Future<void> _openSpecialMessagesSheet() async {
    final snapshot =
        _specialMessagesSnapshot ??
        await _refreshSpecialMessages(
          autoSelectPending: false,
          showSnackOnError: false,
        );
    if (!mounted) return;

    await showTwitchSpecialMessageSheetStage251(
      context: context,
      initialSnapshot: snapshot,
      loading: _loadingSpecialMessages,
      onRefresh: () => _refreshSpecialMessages(
        autoSelectPending: false,
        showSnackOnError: true,
      ),
      onShareWatchStreak: (status) {
        _chatController.setPendingSpecialMessage(
          _pendingFromWatchStreak(status),
        );
      },
      onShareResub: (resub) {
        _chatController.setPendingSpecialMessage(_pendingFromResub(resub));
        final defaultMessage = resub.defaultMessage?.trim();
        if (_messageController.text.trim().isEmpty &&
            defaultMessage != null &&
            defaultMessage.isNotEmpty) {
          _messageController.text = defaultMessage;
        }
      },
      onSelectBadge: (badge) async {
        final result = await _watchServices.specialMessagesStage251.runtime
            .updateChatIdentity(
              channelLogin: _channelLogin,
              channelId: _channelId,
              viewerId: _viewerId,
              badge: badge,
            );
        if (!result.ok) {
          _showSnack('更新聊天身分失敗：${result.error}');
          return false;
        }
        _showSnack('已套用徽章 ${badge.title}');
        await _refreshSpecialMessages(
          autoSelectPending: false,
          showSnackOnError: false,
        );
        return true;
      },
      onOpenDebugProbe: _openSpecialMessageDebugProbeSheet,
    );
  }

  Future<void> _openSpecialMessageDebugProbeSheet() async {
    await showTwitchSpecialMessageDebugProbeSheetStage251(
      context: context,
      onRunProbe: () => _watchServices.specialMessagesStage251.debugProbe.run(
        channelLogin: _channelLogin,
        channelId: _channelId,
        viewerId: _viewerId,
      ),
      onRunCustomPersistedOperation:
          ({
            required operationName,
            required sha256Hash,
            required variables,
            useAndroidClient = false,
          }) => _watchServices.specialMessagesStage251.debugProbe
              .runCustomPersistedOperation(
                operationName: operationName,
                sha256Hash: sha256Hash,
                variables: variables,
                useAndroidClient: useAndroidClient,
              ),
    );
  }

  void _setPendingSpecialMessage(TwitchPendingSpecialMessage pending) {
    _chatController.setPendingSpecialMessage(pending);
  }

  void _clearPendingSpecialMessage() {
    _chatController.clearPendingSpecialMessage();
  }

  void _toggleChatVisibility() {
    _preferencesController.toggleChatVisibility();
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
