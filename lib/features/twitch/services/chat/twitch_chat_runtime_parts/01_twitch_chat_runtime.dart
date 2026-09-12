part of '../twitch_chat_runtime.dart';

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
  final Set<String> _seenMessageFingerprints = <String>{};
  final Set<String> _deletedMessageIds = <String>{};
  final Map<String, String> _ownUserStateTags = <String, String>{};
  final Map<String, String> _roomStateTags = <String, String>{};
  final TwitchChatRuntimeNotifyBatcher _notifyBatcher;
  final StreamController<TwitchChatSendRejection> _sendRejectionsController =
      StreamController<TwitchChatSendRejection>.broadcast();

  StreamSubscription<TwitchChatMessage>? _messageSubscription;
  StreamSubscription<TwitchChatMessage>? _writeMessageSubscription;
  StreamSubscription<String>? _rawSubscription;

  String _channelLogin = '';
  String _viewerLogin = '';
  String _viewerDisplayName = '';
  String _viewerUserId = '';
  String? _accessToken;
  String? _ircNick;
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
  Stream<TwitchChatSendRejection> get sendRejections =>
      _sendRejectionsController.stream;
  Set<String> get ownBadgeNames => (_ownUserStateTags['badges'] ?? '')
      .split(',')
      .map((badge) => badge.split('/').first.trim().toLowerCase())
      .where((badge) => badge.isNotEmpty)
      .toSet();
  bool get viewerIsModerator =>
      _ownUserStateTags['mod'] == '1' ||
      ownBadgeNames.contains('broadcaster') ||
      ownBadgeNames.contains('moderator');
  bool get viewerIsVip => ownBadgeNames.contains('vip');
  bool get viewerIsSubscriber =>
      _ownUserStateTags['subscriber'] == '1' ||
      ownBadgeNames.contains('subscriber') ||
      ownBadgeNames.contains('founder');
  TwitchChatRoomState get roomState =>
      TwitchChatRoomState.fromTags(_roomStateTags);

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
    bool preserveMessages = false,
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
    _accessToken = accessToken;
    _ircNick = ircNick;

    _connecting = true;
    _connected = false;
    _error = null;
    _rawEventCount = 0;
    _recentMessageCount = 0;
    _recentParseIssueCount = 0;
    _serverEchoMatchCount = 0;
    _rejectedOutgoingCount = 0;

    _notifyBatcher.cancel();
    if (!preserveMessages) {
      _messages.clear();
      _seenMessageIds.clear();
      _seenMessageFingerprints.clear();
      _deletedMessageIds.clear();
    }
    this._clearPendingOutgoingMessages();
    _ownUserStateTags.clear();
    _roomStateTags.clear();

    notifyListeners();

    final recentMessagesFuture =
        preloadRecentMessages && recentMessagesApi != null
        ? _fetchRecentMessages(channelLogin: login, limit: recentMessageLimit)
        : Future<TwitchRecentMessagesResult?>.value();

    _messageSubscription = ircApi.messages.listen(
      this._handleReadConnectionMessage,
      onError: (Object error, StackTrace stackTrace) {
        _error = error;
        _connected = false;
        notifyListeners();
      },
    );

    if (writeIrcApi != null) {
      _writeMessageSubscription = writeIrcApi!.messages.listen(
        this._handleWriteConnectionMessage,
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

      final recentMessages = await recentMessagesFuture;
      _loadInitialRecentMessages(
        startupMessages: startupRecentMessages,
        recentMessages: recentMessages,
      );
      _connected = true;
    } catch (e) {
      final recentMessages = await recentMessagesFuture;
      _loadInitialRecentMessages(
        startupMessages: startupRecentMessages,
        recentMessages: recentMessages,
      );
      _error = e;
      _connected = false;
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  Future<void> reconnect() async {
    if (_connecting || _channelLogin.isEmpty) return;

    await connect(
      channelLogin: _channelLogin,
      accessToken: _accessToken,
      preloadRecentMessages: false,
      ircNick: _ircNick,
      viewerLogin: _viewerLogin,
      viewerDisplayName: _viewerDisplayName,
      viewerUserId: _viewerUserId,
      preserveMessages: true,
    );
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

  void _loadInitialRecentMessages({
    required Iterable<TwitchChatMessage> startupMessages,
    required TwitchRecentMessagesResult? recentMessages,
  }) {
    final mergedMessages = <TwitchChatMessage>[
      ...startupMessages,
      ...?recentMessages?.messages,
    ];
    final parsedMessages = mergedMessages
        .where((message) => message.isPrivMsg && message.hasMessageText)
        .toList(growable: false);
    if (parsedMessages.isEmpty) return;

    final normalize = normalizer;

    for (final message in parsedMessages) {
      final runtimeMessage = normalize.normalize(
        message,
        receivedAt: normalize.readMessageTimeOrNow(message),
      );

      this._appendRuntimeMessage(runtimeMessage, notify: false);
    }

    _recentMessageCount +=
        recentMessages?.messages.length ?? parsedMessages.length;
    _recentParseIssueCount += recentMessages?.issues.length ?? 0;

    if (recentMessages != null &&
        (recentMessages.emptyMessageCount > 0 ||
            recentMessages.issues.isNotEmpty)) {
      _error ??=
          'Recent messages parsed with '
          '${recentMessages.emptyMessageCount} empty messages and '
          '${recentMessages.issues.length} parse issues. '
          'Open Recent Messages API debug to inspect raw items.';
    }

    notifyListeners();
  }

  Future<TwitchRecentMessagesResult?> _fetchRecentMessages({
    required String channelLogin,
    required int limit,
  }) async {
    final api = recentMessagesApi;
    if (api == null) return null;

    try {
      return await api.getRecentMessages(
        channelLogin: channelLogin,
        limit: limit,
      );
    } catch (e) {
      // Recent messages 是輔助資料，失敗不應該阻止 IRC 連線。
      _error ??= e;
      return null;
    }
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
    this._schedulePendingCleanup(pending);

    try {
      await _sendIrcApi.sendChatMessage(
        channelLogin: _channelLogin,
        message: text,
      );
      notifyListeners();
    } catch (e) {
      this._removePending(pending);
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

    this._appendRuntimeMessage(normalizer.normalize(source, receivedAt: now));
  }

  Future<void> disconnect() async {
    _notifyBatcher.cancel();
    await _messageSubscription?.cancel();
    await _writeMessageSubscription?.cancel();
    await _rawSubscription?.cancel();

    _messageSubscription = null;
    _writeMessageSubscription = null;
    _rawSubscription = null;

    this._clearPendingOutgoingMessages();

    await ircApi.disconnect();
    await writeIrcApi?.disconnect();

    _ownUserStateTags.clear();
    _roomStateTags.clear();

    _connecting = false;
    _connected = false;

    notifyListeners();
  }

  Future<void> disposeRuntime() async {
    _notifyBatcher.dispose();
    await disconnect();
    await ircApi.dispose();
    await writeIrcApi?.dispose();
    await _sendRejectionsController.close();
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
      'roomState': roomState.toJson(),
      'readCurrentUserStateTags': ircApi.currentUserStateTags,
      'writeCurrentUserStateTags': writeIrcApi?.currentUserStateTags,
      'messageCount': messages.length,
      'maxMessages': maxMessages,
      'notifyDebounceMs': notifyDebounce.inMilliseconds,
      'messages': messages.map((message) => message.toJson()).toList(),
      'badgeCache': badgeCache.toJson(),
    };
  }

  void _notifyPartListeners() => notifyListeners();
  bool get _partHasListeners => hasListeners;
}
