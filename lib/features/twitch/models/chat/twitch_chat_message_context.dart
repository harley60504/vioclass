import 'twitch_chat_runtime_message.dart';

class TwitchChatMessageContextEntry {
  final TwitchChatRuntimeMessage message;
  final List<String> mentionedLogins;
  final String? replyTargetLogin;

  const TwitchChatMessageContextEntry({
    required this.message,
    required this.mentionedLogins,
    required this.replyTargetLogin,
  });

  bool get hasRelation => mentionedLogins.isNotEmpty || replyTargetLogin != null;
}

class TwitchChatMessageContextGroup {
  final TwitchChatRuntimeMessage selectedMessage;
  final List<TwitchChatMessageContextEntry> entries;
  final bool groupedByMention;

  const TwitchChatMessageContextGroup({
    required this.selectedMessage,
    required this.entries,
    required this.groupedByMention,
  });

  bool get hasMultipleMessages => entries.length > 1;
  int get count => entries.length;
}
