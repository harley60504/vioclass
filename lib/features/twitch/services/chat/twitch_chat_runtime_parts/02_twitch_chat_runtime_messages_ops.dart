part of '../twitch_chat_runtime.dart';

extension _TwitchChatRuntimeMessagesOps on TwitchChatRuntime {
  void _handleReadConnectionMessage(TwitchChatMessage message) {
    switch (message.command) {
      case 'GLOBALUSERSTATE':
      case 'USERSTATE':
        _ownUserStateTags.addAll(message.tags);
        this._markOldestPendingAcknowledged();
        return;

      case 'NOTICE':
        this._handleNotice(message);
        return;

      case 'CLEARMSG':
        this._handleClearMessage(message);
        return;

      case 'CLEARCHAT':
        this._handleClearChat(message);
        return;

      case 'ROOMSTATE':
        this._handleRoomState(message);
        return;

      case 'PRIVMSG':
        this._handleVisiblePrivMsg(message);
        return;

      case 'USERNOTICE':
        this._appendRuntimeMessage(
          normalizer.normalize(message, receivedAt: DateTime.now()),
        );
        return;
    }
  }

  void _handleWriteConnectionMessage(TwitchChatMessage message) {
    switch (message.command) {
      case 'GLOBALUSERSTATE':
      case 'USERSTATE':
        _ownUserStateTags.addAll(message.tags);
        this._markOldestPendingAcknowledged();
        return;

      case 'NOTICE':
        this._handleNotice(message);
        return;

      case 'PRIVMSG':
        this._handleVisiblePrivMsg(message);
        return;
    }
  }

  void _handleRoomState(TwitchChatMessage message) {
    final previous = Map<String, String>.of(_roomStateTags);
    for (final key in TwitchChatRoomState.tagNames) {
      final value = message.tags[key];
      if (value != null) _roomStateTags[key] = value;
    }
    if (!mapEquals(previous, _roomStateTags)) {
      _notifyPartListeners();
    }
  }

  void _handleVisiblePrivMsg(TwitchChatMessage message) {
    final pending = this._findMatchingPending(message);
    if (pending != null) {
      this._removePending(pending);
      _serverEchoMatchCount += 1;
    }

    this._appendRuntimeMessage(
      normalizer.normalize(message, receivedAt: DateTime.now()),
    );
  }

  void _handleNotice(TwitchChatMessage message) {
    if (this._isSendRejectionNotice(message)) {
      this._rejectNewestPending(message);
      return;
    }

    final text = message.message.trim();
    if (text.isNotEmpty) {
      this._appendSystemMessage(text);
    }
  }

  void _handleClearMessage(TwitchChatMessage message) {
    final targetId =
        message.tags['target-msg-id'] ??
        message.tags['target_msg_id'] ??
        message.tags['id'];

    if (targetId == null || targetId.isEmpty) return;

    _deletedMessageIds.add(targetId);
    this._trimHistory(_deletedMessageIds);
    _messages.removeWhere((item) => item.id == targetId);
    _notifyPartListeners();
  }

  void _handleClearChat(TwitchChatMessage message) {
    final targetUserId =
        message.tags['target-user-id'] ?? message.tags['target_user_id'];

    if (targetUserId == null || targetUserId.trim().isEmpty) {
      _messages.clear();
      this._appendSystemMessage('Chat was cleared.');
      _notifyPartListeners();
      return;
    }

    _messages.removeWhere((item) {
      final userId = item.source.tags['user-id'] ?? '';
      return userId == targetUserId;
    });

    final targetUser = message.message.trim().isNotEmpty
        ? message.message.trim()
        : (message.tags['login'] ?? targetUserId);

    final duration =
        message.tags['ban-duration'] ?? message.tags['ban_duration'];
    if (duration != null && duration.isNotEmpty) {
      this._appendSystemMessage('$targetUser was timed out for ${duration}s.');
    } else {
      this._appendSystemMessage('$targetUser was banned or removed from chat.');
    }

    _notifyPartListeners();
  }

  bool _isOwnVisibleMessage(TwitchChatMessage message) {
    final incomingUserId = message.tags['user-id']?.trim() ?? '';
    if (incomingUserId.isNotEmpty && _viewerUserId.trim().isNotEmpty) {
      return incomingUserId == _viewerUserId.trim();
    }

    final incomingLogin = message.userLogin.trim().toLowerCase();
    if (incomingLogin.isEmpty) return false;

    return incomingLogin == _viewerLogin.trim().toLowerCase();
  }

  void _appendRuntimeMessage(
    TwitchChatRuntimeMessage message, {
    bool notify = true,
  }) {
    if (this._isDeletedMessage(message.id)) return;

    final id = message.id;
    if (id.isNotEmpty) {
      if (_seenMessageIds.contains(id)) {
        return;
      }

      final existingIndex = _messages.indexWhere((item) => item.id == id);
      if (existingIndex >= 0) {
        return;
      }
    }

    final fingerprint = this._messageFingerprint(message);
    if (fingerprint.isNotEmpty &&
        _seenMessageFingerprints.contains(fingerprint)) {
      return;
    }

    this._insertRuntimeMessageInTimeOrder(message);
    this._markSeen(message);

    if (_messages.length > maxMessages) {
      _messages.removeRange(0, _messages.length - maxMessages);
    }

    if (notify) {
      _requestUiNotify();
    }
  }

  void _requestUiNotify() {
    _notifyBatcher.request(() {
      if (_partHasListeners) _notifyPartListeners();
    });
  }

  void _insertRuntimeMessageInTimeOrder(TwitchChatRuntimeMessage message) {
    if (_messages.isEmpty ||
        !message.receivedAt.isBefore(_messages.last.receivedAt)) {
      _messages.add(message);
      return;
    }

    var insertAt = _messages.length;
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (!message.receivedAt.isBefore(_messages[i].receivedAt)) {
        insertAt = i + 1;
        break;
      }
      insertAt = i;
    }
    _messages.insert(insertAt, message);
  }

  String _messageFingerprint(TwitchChatRuntimeMessage message) {
    final source = message.source;
    final sentAt =
        source.tags['tmi-sent-ts'] ??
        source.tags['sent-ts'] ??
        source.tags['timestamp'] ??
        message.receivedAt.millisecondsSinceEpoch.toString();
    final userKey = (source.tags['user-id']?.trim().isNotEmpty ?? false)
        ? source.tags['user-id']!.trim()
        : source.userLogin.trim().toLowerCase();
    final text = source.message.trim();
    if (userKey.isEmpty && text.isEmpty) return '';
    return '${source.source.name}|${source.channel.trim().toLowerCase()}|$userKey|$sentAt|$text';
  }

  bool _isDeletedMessage(String id) {
    if (id.isEmpty) return false;
    return _deletedMessageIds.contains(id);
  }

  void _appendSystemMessage(String message) {
    final text = message.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final id = 'system-${now.microsecondsSinceEpoch}';

    final source = TwitchChatMessage.synthetic(
      channelLogin: _channelLogin,
      userLogin: 'system',
      displayName: 'Twitch',
      message: text,
      source: TwitchChatMessageSource.synthetic,
      tags: <String, String>{
        'id': id,
        'display-name': 'Twitch',
        'color': '#9146FF',
        'tmi-sent-ts': now.millisecondsSinceEpoch.toString(),
        'badges': 'staff/1',
        'user-id': 'twitch-system',
      },
    );

    this._appendRuntimeMessage(normalizer.normalize(source, receivedAt: now));
  }
}

extension _TwitchChatRuntimeOutgoingOps on TwitchChatRuntime {
  void _markOldestPendingAcknowledged() {
    for (final pending in _pendingOutgoingMessages) {
      if (!pending.writeAcknowledged) {
        pending.writeAcknowledged = true;
        _notifyPartListeners();
        return;
      }
    }
  }

  _PendingOutgoingChatMessage? _findMatchingPending(TwitchChatMessage message) {
    if (!this._isOwnVisibleMessage(message)) return null;

    final text = message.message.trim();
    if (text.isEmpty) return null;

    for (final pending in _pendingOutgoingMessages) {
      if (pending.text.trim() != text) continue;

      final delta = DateTime.now().difference(pending.createdAt).abs();
      if (delta <= TwitchChatRuntime.pendingOutgoingTtl) {
        return pending;
      }
    }

    return null;
  }

  void _rejectNewestPending(TwitchChatMessage noticeMessage) {
    final pending = _pendingOutgoingMessages.isEmpty
        ? null
        : _pendingOutgoingMessages.last;

    final reason = noticeMessage.message.trim().isNotEmpty
        ? noticeMessage.message.trim()
        : (noticeMessage.tags['msg-id'] ?? 'Message rejected by Twitch');

    _error = reason;
    _rejectedOutgoingCount += 1;
    if (!_sendRejectionsController.isClosed) {
      _sendRejectionsController.add(
        TwitchChatSendRejection(
          messageId: noticeMessage.tags['msg-id'] ?? '',
          reason: reason,
        ),
      );
    }

    if (pending != null) {
      this._removePending(pending);
    }

    this._appendSystemMessage(reason);
    _notifyPartListeners();
  }

  bool _isSendRejectionNotice(TwitchChatMessage message) {
    final msgId = message.tags['msg-id'];
    if (msgId == null || msgId.isEmpty) return false;

    return const <String>{
      'msg_slowmode',
      'msg_ratelimit',
      'msg_duplicate',
      'msg_banned',
      'msg_timedout',
      'msg_channel_blocked',
      'msg_suspended',
      'msg_emoteonly',
      'msg_subsonly',
      'msg_followersonly',
      'msg_followersonly_followed',
      'msg_followersonly_zero',
      'msg_r9k',
      'msg_verified_email',
      'msg_requires_verified_phone_number',
      'msg_rejected',
      'msg_rejected_mandatory',
      'msg_bad_characters',
    }.contains(msgId);
  }

  void _schedulePendingCleanup(_PendingOutgoingChatMessage pending) {
    pending.cleanupTimer = Timer(TwitchChatRuntime.pendingOutgoingTtl, () {
      if (!_pendingOutgoingMessages.contains(pending)) return;
      this._removePending(pending);
      _notifyPartListeners();
    });
  }

  void _removePending(_PendingOutgoingChatMessage pending) {
    pending.cleanupTimer?.cancel();
    _pendingOutgoingMessages.remove(pending);
  }

  void _clearPendingOutgoingMessages() {
    for (final pending in _pendingOutgoingMessages) {
      pending.cleanupTimer?.cancel();
    }
    _pendingOutgoingMessages.clear();
  }
}

extension _TwitchChatRuntimeConnectionOps on TwitchChatRuntime {
  void _markSeen(TwitchChatRuntimeMessage message) {
    final id = message.id;
    if (id.isNotEmpty) {
      _seenMessageIds.add(id);
      this._trimHistory(_seenMessageIds);
    }
    final fingerprint = this._messageFingerprint(message);
    if (fingerprint.isNotEmpty) {
      _seenMessageFingerprints.add(fingerprint);
      this._trimHistory(_seenMessageFingerprints);
    }
  }
}

extension _TwitchChatRuntimeHistoryOps on TwitchChatRuntime {
  void _trimHistory(Set<String> history) {
    final limit = maxMessages > 0 ? maxMessages * 2 : 1;
    while (history.length > limit) {
      history.remove(history.first);
    }
  }
}

class TwitchChatSendRejection {
  final String messageId;
  final String reason;

  const TwitchChatSendRejection({
    required this.messageId,
    required this.reason,
  });
}

class TwitchChatRoomState {
  static const Set<String> tagNames = <String>{
    'emote-only',
    'followers-only',
    'r9k',
    'slow',
    'subs-only',
  };

  final bool known;
  final bool emoteOnly;
  final int followersOnlyMinutes;
  final bool uniqueChat;
  final int slowModeSeconds;
  final bool subscribersOnly;

  const TwitchChatRoomState({
    this.known = false,
    this.emoteOnly = false,
    this.followersOnlyMinutes = -1,
    this.uniqueChat = false,
    this.slowModeSeconds = 0,
    this.subscribersOnly = false,
  });

  factory TwitchChatRoomState.fromTags(Map<String, String> tags) {
    if (tags.isEmpty) return const TwitchChatRoomState();
    return TwitchChatRoomState(
      known: true,
      emoteOnly: tags['emote-only'] == '1',
      followersOnlyMinutes: int.tryParse(tags['followers-only'] ?? '') ?? -1,
      uniqueChat: tags['r9k'] == '1',
      slowModeSeconds: int.tryParse(tags['slow'] ?? '') ?? 0,
      subscribersOnly: tags['subs-only'] == '1',
    );
  }

  bool get hasRestrictions =>
      emoteOnly ||
      followersOnlyMinutes >= 0 ||
      uniqueChat ||
      slowModeSeconds > 0 ||
      subscribersOnly;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'known': known,
      'emoteOnly': emoteOnly,
      'followersOnlyMinutes': followersOnlyMinutes,
      'uniqueChat': uniqueChat,
      'slowModeSeconds': slowModeSeconds,
      'subscribersOnly': subscribersOnly,
    };
  }
}

class _PendingOutgoingChatMessage {
  final String text;
  final DateTime createdAt;
  final String userLogin;
  final String userId;

  bool writeAcknowledged = false;
  Timer? cleanupTimer;

  _PendingOutgoingChatMessage({
    required this.text,
    required this.createdAt,
    required this.userLogin,
    required this.userId,
  });
}
