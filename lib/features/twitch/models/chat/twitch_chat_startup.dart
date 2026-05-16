import './twitch_chat_badge.dart';

class TwitchChatStartupSnapshot {
  final String channelLogin;
  final String channelId;
  final TwitchBadgeCatalog badgeCatalog;
  final Map<String, dynamic>? chatRestrictions;
  final Map<String, dynamic>? chatRoomState;
  final Map<String, dynamic>? chatChannelData;
  final Map<String, dynamic>? chatInput;
  final List<Map<String, dynamic>> recentMessages;
  final List<TwitchStartupOperationSummary> operations;

  const TwitchChatStartupSnapshot({
    required this.channelLogin,
    required this.badgeCatalog,
    required this.operations,
    this.channelId = '',
    this.chatRestrictions,
    this.chatRoomState,
    this.chatChannelData,
    this.chatInput,
    this.recentMessages = const <Map<String, dynamic>>[],
  });

  bool get hasChannelId => channelId.isNotEmpty;
  bool get hasBadges => badgeCatalog.totalCount > 0;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelLogin': channelLogin,
      'channelId': channelId,
      'hasChannelId': hasChannelId,
      'hasBadges': hasBadges,
      'badgeCatalog': badgeCatalog.toJson(),
      'chatRestrictionsKeys': chatRestrictions?.keys.toList(),
      'chatRoomStateKeys': chatRoomState?.keys.toList(),
      'chatChannelDataKeys': chatChannelData?.keys.toList(),
      'chatInputKeys': chatInput?.keys.toList(),
      'recentMessageCount': recentMessages.length,
      'recentMessagesPreview': recentMessages.take(5).toList(),
      'operations': operations.map((operation) => operation.toJson()).toList(),
    };
  }
}

class TwitchStartupOperationSummary {
  final String operationName;
  final bool hasErrors;
  final List<String> topLevelDataKeys;
  final List<String> firstNestedKeys;

  const TwitchStartupOperationSummary({
    required this.operationName,
    required this.hasErrors,
    required this.topLevelDataKeys,
    required this.firstNestedKeys,
  });

  factory TwitchStartupOperationSummary.fromResponse({
    required String operationName,
    required bool hasErrors,
    required Object? response,
  }) {
    final data = _extractDataMap(response);
    final firstNested = _firstNestedMap(data);

    return TwitchStartupOperationSummary(
      operationName: operationName,
      hasErrors: hasErrors,
      topLevelDataKeys: data.keys.toList(),
      firstNestedKeys: firstNested?.keys.toList() ?? const <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'operationName': operationName,
      'hasErrors': hasErrors,
      'topLevelDataKeys': topLevelDataKeys,
      'firstNestedKeys': firstNestedKeys,
    };
  }
}

Map<String, dynamic> _extractDataMap(Object? response) {
  if (response is! Map<String, dynamic>) return <String, dynamic>{};
  final data = response['data'];
  return data is Map<String, dynamic> ? data : <String, dynamic>{};
}

Map<String, dynamic>? _firstNestedMap(Map<String, dynamic> map) {
  for (final value in map.values) {
    if (value is Map<String, dynamic>) return value;
  }
  return null;
}
