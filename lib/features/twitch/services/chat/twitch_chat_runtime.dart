import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../api/chat/twitch_irc_api_service.dart';
import '../../api/chat/twitch_recent_messages_api_service.dart';
import '../../models/chat/twitch_chat_badge.dart';
import '../../models/chat/twitch_chat_message.dart';
import '../../models/chat/twitch_chat_runtime_message.dart';
import '../engagement/twitch_prediction_hermes_runtime_service.dart';
import '../../parsers/chat/twitch_chat_message_normalizer.dart';
import './twitch_badge_cache_service.dart';
import './twitch_chat_runtime_notify_batcher.dart';

class TwitchChatRuntime extends ChangeNotifier {
  /// Main IRC connection.
  ///
  /// This connection is responsible for reading visible chat messages.
  final TwitchIrcApiService ircApi;

  /// Optional second IRC connection used only for sending messages.
  ///
  /// If present, both read/write IRC messages are still listened to, but visible
  /// chat is always server-authored. No local echo is inserted.
  final TwitchIrcApiService? writeIrcApi;

  final TwitchBadgeCacheService badgeCache;
  final TwitchRecentMessagesApiService? recentMessagesApi;

  TwitchChatRuntime({
    required this.ircApi,
    required this.badgeCache,
    this.recentMessagesApi,
    this.writeIrcApi,
    this.maxMessages = 350,
    this.notifyDebounce = const Duration(milliseconds: 200),
  }) : _notifyBatcher = TwitchChatRuntimeNotifyBatcher(
         interval: notifyDebounce,
       );

  /// 手機上聊天室最怕無限制累積 + 每則訊息都重建。
  ///
  /// 預設 350 則足夠保留上下文，也能避免熱門台長時間觀看後記憶體與 layout 成本暴增。
  final int maxMessages;

  /// 熱門聊天室一秒可能多則訊息；用 runtime 層 batch 合併 notify，避免每則訊息都重建 UI。
  final Duration notifyDebounce;

  static const Duration initialUserStateWait = Duration(milliseconds: 1500);
  static const Duration sendUserStateWait = Duration(milliseconds: 900);
  static const Duration pendingOutgoingTtl = Duration(seconds: 20);

  TwitchIrcApiService get _sendIrcApi => writeIrcApi ?? ircApi;
  bool get usingDualIrcMode => writeIrcApi != null;

  final List<TwitchChatRuntimeMessage> _messages = <TwitchChatRuntimeMessage>[];
  final List<_PendingOutgoingChatMessage> _pendingOutgoingMessages =
      <_PendingOutgoingChatMessage>[];
  final Set<String> _seenMessageIds = <String>{};
  final Set<String> _deletedMessageIds = <String>{};
  final Map<String, String> _ownUserStateTags = <String, String>{};
  final TwitchChatRuntimeNotifyBatcher _notifyBatcher;

  StreamSubscription<TwitchChatMessage>? _messageSubscription;
  StreamSubscription<TwitchChatMessage>? _writeMessageSubscription;
  StreamSubscription<String>? _rawSubscription;

  String _channelLogin = '';
  String _viewerLogin = '';
  String _viewerDisplayName = '';
  String _viewerUserId = '';
  bool _connecting = false;
  bool _connected = false;
  Object? _error;
  int _rawEventCount = 0;
  int _recentMessageCount = 0;
  int _recentParseIssueCount = 0;
  int _serverEchoMatchCount = 0;
  int _rejectedOutgoingCount = 0;

  List<TwitchChatRuntimeMessage> get messages {
    return List<TwitchChatRuntimeMessage>.unmodifiable(_messages);
  }

  String get channelLogin => _channelLogin;
  String get viewerLogin => _viewerLogin;
  String get viewerDisplayName => _viewerDisplayName;
  String get viewerUserId => _viewerUserId;
  bool get connecting => _connecting;
  bool get connected => _connected;
  Object? get error => _error;
  int get rawEventCount => _rawEventCount;
  int get recentMessageCount => _recentMessageCount;
  int get recentParseIssueCount => _recentParseIssueCount;
  int get pendingOutgoingCount => _pendingOutgoingMessages.length;
  int get serverEchoMatchCount => _serverEchoMatchCount;
  int get rejectedOutgoingCount => _rejectedOutgoingCount;

  TwitchChatMessageNormalizer get normalizer {
    return TwitchChatMessageNormalizer(badgeCache: badgeCache);
  }

  Future<void> connect({
    required String channelLogin,
    String? accessToken,
    TwitchBadgeCatalog? badgeCatalog,
    bool preloadRecentMessages = true,
    int recentMessageLimit = 100,
    Iterable<TwitchChatMessage> startupRecentMessages =
        const <TwitchChatMessage>[],
    String? ircNick,
    String? viewerLogin,
    String? viewerDisplayName,
    String? viewerUserId,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      throw ArgumentError.value(
        channelLogin,
        'channelLogin',
        'channelLogin cannot be empty',
      );
    }

    if (badgeCatalog != null) {
      badgeCache.updateCatalog(badgeCatalog);
    }

    await disconnect();

    _channelLogin = login;
    _viewerLogin = (viewerLogin ?? ircNick ?? '').trim().toLowerCase();
    _viewerDisplayName = (viewerDisplayName ?? viewerLogin ?? ircNick ?? '')
        .trim();
    _viewerUserId = (viewerUserId ?? '').trim();

    _connecting = true;
    _connected = false;
    _error = null;
    _rawEventCount = 0;
    _recentMessageCount = 0;
    _recentParseIssueCount = 0;
    _serverEchoMatchCount = 0;
    _rejectedOutgoingCount = 0;

    _notifyBatcher.cancel();
    _messages.clear();
    _clearPendingOutgoingMessages();
    _seenMessageIds.clear();
    _deletedMessageIds.clear();
    _ownUserStateTags.clear();

    notifyListeners();

    _loadStartupRecentMessages(startupRecentMessages);

    if (preloadRecentMessages && recentMessagesApi != null) {
      await _loadRecentMessages(channelLogin: login, limit: recentMessageLimit);
    }

    _messageSubscription = ircApi.messages.listen(
      _handleReadConnectionMessage,
      onError: (Object error, StackTrace stackTrace) {
        _error = error;
        _connected = false;
        notifyListeners();
      },
    );

    if (writeIrcApi != null) {
      _writeMessageSubscription = writeIrcApi!.messages.listen(
        _handleWriteConnectionMessage,
        onError: (Object error, StackTrace stackTrace) {
          _error = error;
          _connected = false;
          notifyListeners();
        },
      );
    }

    _rawSubscription = ircApi.rawLines.listen((line) {
      _rawEventCount += 1;
      if (line == 'DISCONNECTED' || line.startsWith('ERROR ')) {
        _connected = false;
        _error ??= line;
        notifyListeners();
      }
    });

    try {
      await ircApi.connect(
        channelLogin: login,
        accessToken: accessToken,
        nick: _resolveIrcNick(ircNick),
      );

      final readUserState = await ircApi.waitForCurrentUserState(
        timeout: initialUserStateWait,
      );
      _ownUserStateTags.addAll(readUserState);

      if (writeIrcApi != null) {
        await writeIrcApi!.connect(
          channelLogin: login,
          accessToken: accessToken,
          nick: _resolveIrcNick(ircNick),
        );

        final writeUserState = await writeIrcApi!.waitForCurrentUserState(
          timeout: initialUserStateWait,
        );
        _ownUserStateTags.addAll(writeUserState);
      }

      _connected = true;
    } catch (e) {
      _error = e;
      _connected = false;
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  String _resolveIrcNick(String? ircNick) {
    final clean = ircNick?.trim().toLowerCase();
    if (clean != null && clean.isNotEmpty) return clean;

    if (_viewerLogin.trim().isNotEmpty) {
      return _viewerLogin.trim().toLowerCase();
    }

    return 'justinfan12345';
  }

  Future<List<TwitchChatRuntimeMessage>> collectRuntimeMessages({
    required String channelLogin,
    String? accessToken,
    TwitchBadgeCatalog? badgeCatalog,
    Duration duration = const Duration(seconds: 8),
    int maxMessages = 30,
    bool preloadRecentMessages = true,
    int recentMessageLimit = 100,
    Iterable<TwitchChatMessage> startupRecentMessages =
        const <TwitchChatMessage>[],
    String? ircNick,
    String? viewerLogin,
    String? viewerDisplayName,
    String? viewerUserId,
  }) async {
    await connect(
      channelLogin: channelLogin,
      accessToken: accessToken,
      badgeCatalog: badgeCatalog,
      preloadRecentMessages: preloadRecentMessages,
      recentMessageLimit: recentMessageLimit,
      ircNick: ircNick,
      viewerLogin: viewerLogin,
      viewerDisplayName: viewerDisplayName,
      viewerUserId: viewerUserId,
      startupRecentMessages: startupRecentMessages,
    );

    final completer = Completer<List<TwitchChatRuntimeMessage>>();
    Timer? timer;
    late final VoidCallback listener;

    listener = () {
      if (_messages.length >= maxMessages && !completer.isCompleted) {
        completer.complete(messages.take(maxMessages).toList(growable: false));
      }
    };

    addListener(listener);

    timer = Timer(duration, () {
      if (!completer.isCompleted) {
        completer.complete(messages.take(maxMessages).toList(growable: false));
      }
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      removeListener(listener);
      await disconnect();
    }
  }

  void _loadStartupRecentMessages(Iterable<TwitchChatMessage> messages) {
    final parsedMessages = messages
        .where((message) => message.isPrivMsg && message.hasMessageText)
        .toList(growable: false);
    if (parsedMessages.isEmpty) return;

    final normalize = normalizer;

    for (final message in parsedMessages) {
      final runtimeMessage = normalize.normalize(
        message,
        receivedAt: normalize.readMessageTimeOrNow(message),
      );

      _appendRuntimeMessage(runtimeMessage, notify: false);
    }

    _recentMessageCount += parsedMessages.length;
    notifyListeners();
  }

  Future<void> _loadRecentMessages({
    required String channelLogin,
    required int limit,
  }) async {
    final api = recentMessagesApi;
    if (api == null) return;

    try {
      final result = await api.getRecentMessages(
        channelLogin: channelLogin,
        limit: limit,
      );

      final normalize = normalizer;

      for (final message in result.messages) {
        final runtimeMessage = normalize.normalize(
          message,
          receivedAt: normalize.readMessageTimeOrNow(message),
        );

        _appendRuntimeMessage(runtimeMessage, notify: false);
      }

      _recentMessageCount += result.messages.length;
      _recentParseIssueCount += result.issues.length;

      if (result.emptyMessageCount > 0 || result.issues.isNotEmpty) {
        _error ??=
            'Recent messages parsed with '
            '${result.emptyMessageCount} empty messages and '
            '${result.issues.length} parse issues. '
            'Open Recent Messages API debug to inspect raw items.';
      }

      notifyListeners();
    } catch (e) {
      // Recent messages 是輔助資料，失敗不應該阻止 IRC 連線。
      _error ??= e;
      notifyListeners();
    }
  }

  void _handleReadConnectionMessage(TwitchChatMessage message) {
    switch (message.command) {
      case 'GLOBALUSERSTATE':
      case 'USERSTATE':
        _ownUserStateTags.addAll(message.tags);
        _markOldestPendingAcknowledged();
        return;

      case 'NOTICE':
        _handleNotice(message);
        return;

      case 'CLEARMSG':
        _handleClearMessage(message);
        return;

      case 'CLEARCHAT':
        _handleClearChat(message);
        return;

      case 'ROOMSTATE':
        return;

      case 'PRIVMSG':
        _handleVisiblePrivMsg(message);
        return;

      case 'USERNOTICE':
        _appendRuntimeMessage(
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
        _markOldestPendingAcknowledged();
        return;

      case 'NOTICE':
        _handleNotice(message);
        return;

      case 'PRIVMSG':
        _handleVisiblePrivMsg(message);
        return;
    }
  }

  void _handleVisiblePrivMsg(TwitchChatMessage message) {
    final pending = _findMatchingPending(message);
    if (pending != null) {
      _removePending(pending);
      _serverEchoMatchCount += 1;
    }

    _appendRuntimeMessage(
      normalizer.normalize(message, receivedAt: DateTime.now()),
    );
  }

  void _handleNotice(TwitchChatMessage message) {
    if (_isSendRejectionNotice(message)) {
      _rejectNewestPending(message);
      return;
    }

    final text = message.message.trim();
    if (text.isNotEmpty) {
      _appendSystemMessage(text);
    }
  }

  void _handleClearMessage(TwitchChatMessage message) {
    final targetId =
        message.tags['target-msg-id'] ??
        message.tags['target_msg_id'] ??
        message.tags['id'];

    if (targetId == null || targetId.isEmpty) return;

    _deletedMessageIds.add(targetId);
    _messages.removeWhere((item) => item.id == targetId);
    notifyListeners();
  }

  void _handleClearChat(TwitchChatMessage message) {
    final targetUserId =
        message.tags['target-user-id'] ?? message.tags['target_user_id'];

    if (targetUserId == null || targetUserId.trim().isEmpty) {
      _messages.clear();
      _appendSystemMessage('Chat was cleared.');
      notifyListeners();
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
      _appendSystemMessage('$targetUser was timed out for ${duration}s.');
    } else {
      _appendSystemMessage('$targetUser was banned or removed from chat.');
    }

    notifyListeners();
  }

  void _markOldestPendingAcknowledged() {
    for (final pending in _pendingOutgoingMessages) {
      if (!pending.writeAcknowledged) {
        pending.writeAcknowledged = true;
        notifyListeners();
        return;
      }
    }
  }

  _PendingOutgoingChatMessage? _findMatchingPending(TwitchChatMessage message) {
    if (!_isOwnVisibleMessage(message)) return null;

    final text = message.message.trim();
    if (text.isEmpty) return null;

    for (final pending in _pendingOutgoingMessages) {
      if (pending.text.trim() != text) continue;

      final delta = DateTime.now().difference(pending.createdAt).abs();
      if (delta <= pendingOutgoingTtl) {
        return pending;
      }
    }

    return null;
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

  void _rejectNewestPending(TwitchChatMessage noticeMessage) {
    final pending = _pendingOutgoingMessages.isEmpty
        ? null
        : _pendingOutgoingMessages.last;

    final reason = noticeMessage.message.trim().isNotEmpty
        ? noticeMessage.message.trim()
        : (noticeMessage.tags['msg-id'] ?? 'Message rejected by Twitch');

    _error = reason;
    _rejectedOutgoingCount += 1;

    if (pending != null) {
      _removePending(pending);
    }

    _appendSystemMessage(reason);
    notifyListeners();
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

  void _appendRuntimeMessage(
    TwitchChatRuntimeMessage message, {
    bool notify = true,
  }) {
    if (_isDeletedMessage(message.id)) return;

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

    _messages.add(message);
    _markSeen(message);

    if (_messages.length > maxMessages) {
      _messages.removeRange(0, _messages.length - maxMessages);
    }

    if (notify) {
      _requestUiNotify();
    }
  }

  void _requestUiNotify() {
    _notifyBatcher.request(() {
      if (hasListeners) notifyListeners();
    });
  }

  void _markSeen(TwitchChatRuntimeMessage message) {
    final id = message.id;
    if (id.isNotEmpty) {
      _seenMessageIds.add(id);
    }
  }

  bool _isDeletedMessage(String id) {
    if (id.isEmpty) return false;
    return _deletedMessageIds.contains(id);
  }

  Future<void> sendMessage(String message) async {
    if (!_connected) {
      throw StateError('聊天室尚未連線，不能送出訊息。');
    }

    final text = message.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

    if (text.isEmpty) {
      throw ArgumentError.value(message, 'message', 'message cannot be empty');
    }

    await _sendIrcApi.waitForCurrentUserState(timeout: sendUserStateWait);

    final pending = _PendingOutgoingChatMessage(
      text: text,
      createdAt: DateTime.now(),
      userLogin: _viewerLogin.trim().toLowerCase(),
      userId: _viewerUserId.trim(),
    );

    _pendingOutgoingMessages.add(pending);
    _schedulePendingCleanup(pending);

    try {
      await _sendIrcApi.sendChatMessage(
        channelLogin: _channelLogin,
        message: text,
      );
      notifyListeners();
    } catch (e) {
      _removePending(pending);
      _error = e;
      notifyListeners();
      rethrow;
    }
  }

  void injectRedemptionMessage(TwitchCommunityRedemptionEvent redemption) {
    final title = redemption.rewardTitle.trim();
    if (title.isEmpty) return;

    final userLogin = redemption.userLogin.trim().isNotEmpty
        ? redemption.userLogin.trim().toLowerCase()
        : redemption.userName.trim().toLowerCase();
    final displayName = redemption.userName.trim().isNotEmpty
        ? redemption.userName.trim()
        : userLogin;
    if (userLogin.isEmpty && displayName.isEmpty) return;

    final id = redemption.redemptionId.trim().isNotEmpty
        ? 'redeem-${redemption.redemptionId.trim()}'
        : 'redeem-${redemption.rewardId.trim()}-${DateTime.now().microsecondsSinceEpoch}';
    final rewardId = redemption.rewardId.trim().isNotEmpty
        ? redemption.rewardId.trim()
        : 'community-redemption';
    final now = DateTime.now();

    final source = TwitchChatMessage.synthetic(
      channelLogin: _channelLogin,
      userLogin: userLogin.isEmpty ? 'viewer' : userLogin,
      displayName: displayName.isEmpty ? userLogin : displayName,
      message: title,
      source: TwitchChatMessageSource.synthetic,
      tags: <String, String>{
        'id': id,
        'user-id': redemption.userId,
        'display-name': displayName.isEmpty ? userLogin : displayName,
        'color': redemption.backgroundColor.trim().isNotEmpty
            ? redemption.backgroundColor.trim()
            : '#9146FF',
        'custom-reward-id': rewardId,
        'tmi-sent-ts': now.millisecondsSinceEpoch.toString(),
        if (redemption.rewardCost > 0)
          'sn-reward-cost': redemption.rewardCost.toString(),
        if (redemption.imageUrl.trim().isNotEmpty)
          'sn-reward-image': redemption.imageUrl.trim(),
      },
    );

    _appendRuntimeMessage(normalizer.normalize(source, receivedAt: now));
  }

  void _schedulePendingCleanup(_PendingOutgoingChatMessage pending) {
    pending.cleanupTimer = Timer(pendingOutgoingTtl, () {
      if (!_pendingOutgoingMessages.contains(pending)) return;
      _removePending(pending);
      notifyListeners();
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

    _appendRuntimeMessage(normalizer.normalize(source, receivedAt: now));
  }

  Future<void> disconnect() async {
    _notifyBatcher.cancel();
    await _messageSubscription?.cancel();
    await _writeMessageSubscription?.cancel();
    await _rawSubscription?.cancel();

    _messageSubscription = null;
    _writeMessageSubscription = null;
    _rawSubscription = null;

    _clearPendingOutgoingMessages();

    await ircApi.disconnect();
    await writeIrcApi?.disconnect();

    _ownUserStateTags.clear();

    _connecting = false;
    _connected = false;

    notifyListeners();
  }

  Future<void> disposeRuntime() async {
    _notifyBatcher.dispose();
    await disconnect();
    await ircApi.dispose();
    await writeIrcApi?.dispose();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelLogin': channelLogin,
      'viewerLogin': viewerLogin,
      'viewerDisplayName': viewerDisplayName,
      'viewerUserId': viewerUserId,
      'connecting': connecting,
      'connected': connected,
      'error': error?.toString(),
      'rawEventCount': rawEventCount,
      'recentMessageCount': recentMessageCount,
      'recentParseIssueCount': recentParseIssueCount,
      'pendingOutgoingCount': pendingOutgoingCount,
      'serverEchoMatchCount': serverEchoMatchCount,
      'rejectedOutgoingCount': rejectedOutgoingCount,
      'usingDualIrcMode': usingDualIrcMode,
      'serverOnlyOutgoing': true,
      'pendingOutgoingTtlMs': pendingOutgoingTtl.inMilliseconds,
      'seenMessageIdCount': _seenMessageIds.length,
      'deletedMessageIdCount': _deletedMessageIds.length,
      'ownUserStateTags': _ownUserStateTags,
      'readCurrentUserStateTags': ircApi.currentUserStateTags,
      'writeCurrentUserStateTags': writeIrcApi?.currentUserStateTags,
      'messageCount': messages.length,
      'maxMessages': maxMessages,
      'notifyDebounceMs': notifyDebounce.inMilliseconds,
      'messages': messages.map((message) => message.toJson()).toList(),
      'badgeCache': badgeCache.toJson(),
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
