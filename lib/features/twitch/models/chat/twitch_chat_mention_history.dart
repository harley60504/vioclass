import './twitch_chat_runtime_message.dart';

class TwitchChatMentionHistoryItem {
  final TwitchChatRuntimeMessage message;
  final String fromLogin;
  final String fromDisplayName;
  final String targetLogin;
  final String targetDisplayName;
  final bool fromReply;

  const TwitchChatMentionHistoryItem({
    required this.message,
    required this.fromLogin,
    required this.fromDisplayName,
    required this.targetLogin,
    required this.targetDisplayName,
    required this.fromReply,
  });

  String get fromLabel =>
      fromDisplayName.trim().isNotEmpty ? fromDisplayName : fromLogin;
  String get targetLabel =>
      targetDisplayName.trim().isNotEmpty ? targetDisplayName : targetLogin;

  String get relationLabel =>
      '$targetLabel 被 $fromLabel ${fromReply ? '回覆' : 'tag'}';

  String get plainText {
    final body = message.message.trim();
    if (body.isEmpty) return relationLabel;
    return '$relationLabel：$body';
  }
}

class TwitchChatMentionHistoryGroup {
  final List<String> participants;
  final List<TwitchChatMentionHistoryItem> items;

  const TwitchChatMentionHistoryGroup({
    required this.participants,
    required this.items,
  });

  DateTime get latestAt {
    if (items.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    return items
        .map((item) => item.message.receivedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  String get title {
    if (participants.isEmpty) return 'Tag 記錄';
    if (participants.length <= 4) return participants.join(' ↔ ');
    return '${participants.take(4).join(' ↔ ')} +${participants.length - 4}';
  }

  String get copyText {
    return items.map((item) => item.plainText).join('\n');
  }
}
