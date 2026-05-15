class TwitchPinnedChatMessage {
  final String pinId;
  final String type;
  final String messageId;
  final String text;
  final DateTime? sentAt;
  final DateTime? startsAt;
  final DateTime? updatedAt;
  final DateTime? endsAt;
  final TwitchPinnedChatUser? sender;
  final TwitchPinnedChatUser? pinnedBy;

  const TwitchPinnedChatMessage({
    required this.pinId,
    required this.type,
    required this.messageId,
    required this.text,
    this.sentAt,
    this.startsAt,
    this.updatedAt,
    this.endsAt,
    this.sender,
    this.pinnedBy,
  });

  bool get isActive {
    final now = DateTime.now().toUtc();
    final end = endsAt;
    return end == null || end.isAfter(now);
  }

  factory TwitchPinnedChatMessage.fromGqlNode(Map<String, dynamic> node) {
    final pinnedMessage = node['pinnedMessage'];
    final pinnedMessageMap =
        pinnedMessage is Map<String, dynamic> ? pinnedMessage : <String, dynamic>{};

    final content = pinnedMessageMap['content'];
    final contentMap = content is Map<String, dynamic> ? content : <String, dynamic>{};

    return TwitchPinnedChatMessage(
      pinId: node['id']?.toString() ?? '',
      type: node['type']?.toString() ?? '',
      messageId: pinnedMessageMap['id']?.toString() ?? '',
      text: contentMap['text']?.toString() ?? '',
      sentAt: DateTime.tryParse(pinnedMessageMap['sentAt']?.toString() ?? ''),
      startsAt: DateTime.tryParse(node['startsAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(node['updatedAt']?.toString() ?? ''),
      endsAt: DateTime.tryParse(node['endsAt']?.toString() ?? ''),
      sender: TwitchPinnedChatUser.fromNullableJson(pinnedMessageMap['sender']),
      pinnedBy: TwitchPinnedChatUser.fromNullableJson(node['pinnedBy']),
    );
  }

  static List<TwitchPinnedChatMessage> listFromGqlResponse(Object? response) {
    if (response is! Map<String, dynamic>) return const <TwitchPinnedChatMessage>[];

    final data = response['data'];
    if (data is! Map<String, dynamic>) return const <TwitchPinnedChatMessage>[];

    final channel = data['channel'];
    if (channel is! Map<String, dynamic>) return const <TwitchPinnedChatMessage>[];

    final pinnedChatMessages = channel['pinnedChatMessages'];
    if (pinnedChatMessages is! Map<String, dynamic>) {
      return const <TwitchPinnedChatMessage>[];
    }

    final edges = pinnedChatMessages['edges'];
    if (edges is! List) return const <TwitchPinnedChatMessage>[];

    return edges
        .whereType<Map<String, dynamic>>()
        .map((edge) => edge['node'])
        .whereType<Map<String, dynamic>>()
        .map(TwitchPinnedChatMessage.fromGqlNode)
        .where((message) => message.pinId.isNotEmpty || message.messageId.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pinId': pinId,
      'type': type,
      'messageId': messageId,
      'text': text,
      'sentAt': sentAt?.toIso8601String(),
      'startsAt': startsAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'endsAt': endsAt?.toIso8601String(),
      'sender': sender?.toJson(),
      'pinnedBy': pinnedBy?.toJson(),
      'isActive': isActive,
    };
  }
}

class TwitchPinnedChatUser {
  final String id;
  final String displayName;
  final String chatColor;
  final List<TwitchPinnedChatBadge> displayBadges;

  const TwitchPinnedChatUser({
    required this.id,
    required this.displayName,
    this.chatColor = '',
    this.displayBadges = const <TwitchPinnedChatBadge>[],
  });

  static TwitchPinnedChatUser? fromNullableJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;

    return TwitchPinnedChatUser(
      id: value['id']?.toString() ?? '',
      displayName: value['displayName']?.toString() ?? '',
      chatColor: value['chatColor']?.toString() ?? '',
      displayBadges: TwitchPinnedChatBadge.listFromJson(value['displayBadges']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'displayName': displayName,
      'chatColor': chatColor,
      'displayBadges': displayBadges.map((badge) => badge.toJson()).toList(),
    };
  }
}

class TwitchPinnedChatBadge {
  final String id;
  final String setId;
  final String version;

  const TwitchPinnedChatBadge({
    required this.id,
    required this.setId,
    required this.version,
  });

  factory TwitchPinnedChatBadge.fromJson(Map<String, dynamic> json) {
    return TwitchPinnedChatBadge(
      id: json['id']?.toString() ?? '',
      setId: json['setID']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
    );
  }

  static List<TwitchPinnedChatBadge> listFromJson(Object? value) {
    if (value is! List) return const <TwitchPinnedChatBadge>[];

    return value
        .whereType<Map<String, dynamic>>()
        .map(TwitchPinnedChatBadge.fromJson)
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'setId': setId,
      'version': version,
    };
  }
}
