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
      await _sendPendingSpecialMessage(pending, message);
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

  Future<void> _sendPendingSpecialMessage(
    TwitchPendingSpecialMessageStage250 pending,
    String message,
  ) async {
    setState(() => _sending = true);
    try {
      switch (pending.kind) {
        case TwitchPendingSpecialMessageKind.highlightedMessage:
        case TwitchPendingSpecialMessageKind.channelPointRewardMessage:
          await _sendPendingChannelPointTextReward(pending, message);
          break;
        case TwitchPendingSpecialMessageKind.watchStreak:
          await _sendPendingWatchStreak(pending, message);
          break;
        case TwitchPendingSpecialMessageKind.resub:
          await _sendPendingResub(pending, message);
          break;
        case TwitchPendingSpecialMessageKind.preview:
        case TwitchPendingSpecialMessageKind.officialSpecialMessage:
          _showSnack('特殊訊息預覽：${pending.describeForLog(message: message)}');
          break;
      }

      _messageController.clear();
      _clearPendingSpecialMessage();
    } catch (error) {
      _showSnack('特殊訊息處理失敗：$error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPendingChannelPointTextReward(
    TwitchPendingSpecialMessageStage250 pending,
    String message,
  ) async {
    final reward = pending.payload['reward'];
    if (reward is! Map<String, dynamic>) {
      throw StateError('缺少忠誠點 reward payload。');
    }

    final resolvedChannelId = pending.channelId?.trim().isNotEmpty == true
        ? pending.channelId!.trim()
        : _channelPointsSnapshot?.channelId ?? _channelId;
    if (resolvedChannelId == null || resolvedChannelId.isEmpty) {
      throw StateError('沒有 channelId，不能兌換忠誠點數獎勵。');
    }

    final result = await _watchPorts.engagement.redeemReward(
      channelId: resolvedChannelId,
      reward: reward,
      textInput: message,
    );

    _showSnack('已兌換：${result.title}');
    await _refreshEngagement(showSnackOnError: false);
  }

  Future<void> _sendPendingWatchStreak(
    TwitchPendingSpecialMessageStage250 pending,
    String message,
  ) async {
    final status = pending.payload['watchStreak'];
    if (status is! TwitchWatchStreakStatusStage251) {
      throw StateError('Missing watch streak payload.');
    }

    final result = await _watchServices.specialMessagesStage251.runtime
        .shareWatchStreak(
          channelLogin: pending.channelLogin,
          channelId: pending.channelId ?? _channelId,
          viewerId: _viewerId,
          status: status,
          message: message,
        );
    if (!result.ok) {
      throw StateError(
        result.error?.toString() ?? 'Watch streak share failed.',
      );
    }
    _showSnack('已分享連續觀看 ${status.streakCount ?? ''}${status.unitLabel}');
    await _refreshSpecialMessages(autoSelectPending: false);
  }

  Future<void> _sendPendingResub(
    TwitchPendingSpecialMessageStage250 pending,
    String message,
  ) async {
    final resub = pending.payload['resub'];
    if (resub is! TwitchResubNotificationStage251) {
      throw StateError('Missing resub payload.');
    }

    final result = await _watchServices.specialMessagesStage251.runtime
        .useResubToken(
          channelLogin: pending.channelLogin,
          channelId: pending.channelId ?? _channelId,
          viewerId: _viewerId,
          resub: resub,
          message: message,
        );
    if (!result.ok) {
      throw StateError(result.error?.toString() ?? 'Resub share failed.');
    }
    _showSnack('已分享訂閱 ${resub.cumulativeMonths ?? ''} 個月');
    await _refreshSpecialMessages(autoSelectPending: false);
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

    setState(() => _loadingSpecialMessages = true);
    try {
      final snapshot = await _watchServices.specialMessagesStage251.runtime
          .load(
            channelLogin: targetChannel,
            channelId: _channelId,
            viewerId: _viewerId,
          );
      if (generation != null &&
          !_isCurrentWatchTask(generation, targetChannel)) {
        return null;
      }
      if (!mounted) return null;
      setState(() {
        _specialMessagesSnapshot = snapshot;
        if (autoSelectPending &&
            (_pendingSpecialMessage == null ||
                _pendingSpecialMessage!.kind ==
                    TwitchPendingSpecialMessageKind.watchStreak ||
                _pendingSpecialMessage!.kind ==
                    TwitchPendingSpecialMessageKind.resub)) {
          _pendingSpecialMessage = _pendingFromSpecialMessages(snapshot);
        }
      });
      return snapshot;
    } catch (error) {
      if (showSnackOnError) _showSnack('特殊訊息載入失敗：$error');
      return null;
    } finally {
      if (mounted) setState(() => _loadingSpecialMessages = false);
    }
  }

  TwitchPendingSpecialMessageStage250? _pendingFromSpecialMessages(
    TwitchViewerSpecialMessagesSnapshotStage251 snapshot,
  ) {
    final resub = snapshot.resub;
    if (resub != null && resub.canShare) return _pendingFromResub(resub);

    final watchStreak = snapshot.watchStreak;
    if (watchStreak != null && watchStreak.canShare) {
      return _pendingFromWatchStreak(watchStreak);
    }

    return null;
  }

  TwitchPendingSpecialMessageStage250 _pendingFromWatchStreak(
    TwitchWatchStreakStatusStage251 status,
  ) {
    final count = status.streakCount;
    return TwitchPendingSpecialMessageStage250(
      kind: TwitchPendingSpecialMessageKind.watchStreak,
      channelLogin: _channelLogin,
      channelId: _channelId ?? status.channelId,
      title: count == null ? '分享連續觀看' : '連續觀看 $count${status.unitLabel}',
      subtitle: '輸入訊息後送出，就會分享你的 Watch Streak。',
      sendLabel: '分享',
      costLabel: count == null ? null : '$count${status.unitLabel}',
      payload: <String, dynamic>{'watchStreak': status},
    );
  }

  TwitchPendingSpecialMessageStage250 _pendingFromResub(
    TwitchResubNotificationStage251 resub,
  ) {
    final months = resub.cumulativeMonths;
    return TwitchPendingSpecialMessageStage250(
      kind: TwitchPendingSpecialMessageKind.resub,
      channelLogin: _channelLogin,
      channelId: _channelId ?? resub.channelId,
      title: months == null ? '分享訂閱訊息' : '訂閱 $months 個月',
      subtitle: '輸入訊息後送出，就會分享你的 Resub 訊息。',
      sendLabel: '分享',
      costLabel: months == null ? null : '$months 個月',
      payload: <String, dynamic>{'resub': resub},
    );
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
        setState(
          () => _pendingSpecialMessage = _pendingFromWatchStreak(status),
        );
      },
      onShareResub: (resub) {
        setState(() {
          _pendingSpecialMessage = _pendingFromResub(resub);
          final defaultMessage = resub.defaultMessage?.trim();
          if (_messageController.text.trim().isEmpty &&
              defaultMessage != null &&
              defaultMessage.isNotEmpty) {
            _messageController.text = defaultMessage;
          }
        });
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
          _showSnack('徽章切換失敗：${result.error}');
          return false;
        }
        _showSnack('已切換徽章：${badge.title}');
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

  void _setPendingSpecialMessage(TwitchPendingSpecialMessageStage250 pending) {
    if (!mounted) return;
    setState(() => _pendingSpecialMessage = pending);
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
