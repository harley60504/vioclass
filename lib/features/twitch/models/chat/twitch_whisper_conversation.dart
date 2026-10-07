enum TwitchWhisperMessageState {
  received,
  sending,
  submitted,
  failed,
  unconfirmed,
}

/// Submitted means accepted by Twitch, not delivered or read by the recipient.
class TwitchWhisperMessage {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String text;
  final DateTime timestamp;
  final TwitchWhisperMessageState state;

  /// Loaded history exists, but this App has not observed a live receipt.
  final bool historicalOnly;

  const TwitchWhisperMessage({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.text,
    required this.timestamp,
    required this.state,
    this.historicalOnly = false,
  });

  TwitchWhisperMessage copyWith({
    TwitchWhisperMessageState? state,
    bool? historicalOnly,
  }) => TwitchWhisperMessage(
    id: id,
    fromUserId: fromUserId,
    toUserId: toUserId,
    text: text,
    timestamp: timestamp,
    state: state ?? this.state,
    historicalOnly: historicalOnly ?? this.historicalOnly,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromUserId': fromUserId,
    'toUserId': toUserId,
    'text': text,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'state': state.name,
    'historicalOnly': historicalOnly,
  };

  factory TwitchWhisperMessage.fromJson(Map<String, dynamic> json) {
    final state = TwitchWhisperMessageState.values.byName(
      json['state'] as String,
    );
    return TwitchWhisperMessage(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      toUserId: json['toUserId'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
      state: state,
      historicalOnly: json['historicalOnly'] as bool? ?? false,
    );
  }
}

class TwitchWhisperConversation {
  static int sendLimit(bool receivedFromPeer) => receivedFromPeer ? 10000 : 500;
  final String userId;
  final String login;
  final String displayName;
  final String? avatarUrl;
  final DateTime? profileObservedAt;
  final List<TwitchWhisperMessage> messages;
  final int unreadCount;
  final int remoteUnreadCount;
  final String draft;
  final bool hasReceivedWhisper;
  final String? remoteHistoryCursor;
  final bool remoteHistoryComplete;
  int get messageLimit => sendLimit(hasReceivedWhisper);

  TwitchWhisperConversation({
    required this.userId,
    required this.login,
    required this.displayName,
    this.avatarUrl,
    this.profileObservedAt,
    Iterable<TwitchWhisperMessage> messages = const [],
    this.unreadCount = 0,
    this.remoteUnreadCount = 0,
    this.draft = '',
    this.hasReceivedWhisper = false,
    this.remoteHistoryCursor,
    this.remoteHistoryComplete = false,
  }) : messages = List.unmodifiable(_deduplicate(messages)) {
    if (remoteUnreadCount < 0 ||
        userId.isEmpty ||
        unreadCount < 0 ||
        (remoteHistoryCursor != null &&
            (remoteHistoryCursor!.isEmpty ||
                remoteHistoryCursor!.length > 4096 ||
                remoteHistoryComplete))) {
      throw const FormatException('Invalid whisper conversation');
    }
  }

  DateTime? get lastMessageAt =>
      messages.isEmpty ? null : messages.last.timestamp;

  /// Helix accepts a send without returning its Twitch message ID. Keep both
  /// records on disk, but suppress an accepted local echo when one official
  /// history row uniquely matches it. Ambiguous repeated sends stay visible.
  List<TwitchWhisperMessage> get displayMessages {
    final local = messages
        .where(
          (m) =>
              m.id.startsWith('local-') &&
              !m.historicalOnly &&
              m.state == TwitchWhisperMessageState.submitted,
        )
        .toList();
    final remote = messages
        .where(
          (m) =>
              m.historicalOnly &&
              !m.id.startsWith('local-') &&
              m.state == TwitchWhisperMessageState.submitted,
        )
        .toList();
    bool matches(TwitchWhisperMessage a, TwitchWhisperMessage b) =>
        a.fromUserId == b.fromUserId &&
        a.toUserId == b.toUserId &&
        a.text == b.text &&
        a.timestamp.difference(b.timestamp).inMilliseconds.abs() <= 30000;
    final hidden = <String>{};
    for (final echo in local) {
      final candidates = remote.where((m) => matches(echo, m)).toList();
      if (candidates.length == 1 &&
          local.where((m) => matches(m, candidates.single)).length == 1) {
        hidden.add(echo.id);
      }
    }
    return List.unmodifiable(messages.where((m) => !hidden.contains(m.id)));
  }

  TwitchWhisperConversation copyWith({
    String? login,
    String? displayName,
    String? avatarUrl,
    bool replaceAvatar = false,
    DateTime? profileObservedAt,
    bool resetProfileObservedAt = false,
    Iterable<TwitchWhisperMessage>? messages,
    int? unreadCount,
    int? remoteUnreadCount,
    String? draft,
    bool? hasReceivedWhisper,
    String? remoteHistoryCursor,
    bool replaceRemoteHistoryCursor = false,
    bool? remoteHistoryComplete,
  }) => TwitchWhisperConversation(
    userId: userId,
    login: login ?? this.login,
    displayName: displayName ?? this.displayName,
    avatarUrl: replaceAvatar ? avatarUrl : this.avatarUrl,
    profileObservedAt: resetProfileObservedAt
        ? null
        : profileObservedAt ?? this.profileObservedAt,
    messages: messages ?? this.messages,
    unreadCount: unreadCount ?? this.unreadCount,
    remoteUnreadCount: remoteUnreadCount ?? this.remoteUnreadCount,
    draft: draft ?? this.draft,
    hasReceivedWhisper: hasReceivedWhisper ?? this.hasReceivedWhisper,
    remoteHistoryCursor: replaceRemoteHistoryCursor
        ? remoteHistoryCursor
        : this.remoteHistoryCursor,
    remoteHistoryComplete: remoteHistoryComplete ?? this.remoteHistoryComplete,
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'login': login,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'profileObservedAt': profileObservedAt?.toUtc().toIso8601String(),
    'unreadCount': unreadCount,
    'remoteUnreadCount': remoteUnreadCount,
    'draft': draft,
    'hasReceivedWhisper': hasReceivedWhisper,
    'remoteHistoryCursor': remoteHistoryCursor,
    'remoteHistoryComplete': remoteHistoryComplete,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory TwitchWhisperConversation.fromJson(Map<String, dynamic> json) =>
      TwitchWhisperConversation(
        userId: json['userId'] as String,
        login: json['login'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        profileObservedAt: json['profileObservedAt'] == null
            ? null
            : DateTime.parse(json['profileObservedAt'] as String).toUtc(),
        unreadCount: json['unreadCount'] as int,
        remoteUnreadCount: json['remoteUnreadCount'] as int? ?? 0,
        draft: json['draft'] as String,
        hasReceivedWhisper: json['hasReceivedWhisper'] == true,
        remoteHistoryCursor: json['remoteHistoryCursor'] as String?,
        remoteHistoryComplete: json['remoteHistoryComplete'] as bool? ?? false,
        messages: (json['messages'] as List).map(
          (item) => TwitchWhisperMessage.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      );

  static List<TwitchWhisperMessage> _deduplicate(
    Iterable<TwitchWhisperMessage> messages,
  ) {
    final byId = <String, TwitchWhisperMessage>{};
    for (final message in messages) {
      if (message.id.isEmpty ||
          message.fromUserId.isEmpty ||
          message.toUserId.isEmpty) {
        throw const FormatException('Invalid whisper message');
      }
      final prior = byId[message.id];
      if (prior != null &&
          (prior.fromUserId != message.fromUserId ||
              prior.toUserId != message.toUserId ||
              prior.text != message.text)) {
        throw const FormatException('Conflicting whisper identity');
      }
      byId[message.id] = message;
    }
    return byId.values.toList()..sort((a, b) {
      final order = a.timestamp.compareTo(b.timestamp);
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
  }
}
