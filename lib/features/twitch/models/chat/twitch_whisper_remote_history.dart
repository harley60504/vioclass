import 'twitch_whisper_conversation.dart';

class TwitchWhisperRemotePage {
  final String ownerId;
  final String peerId;
  final List<TwitchWhisperMessage> messages;
  final String? requestedCursor;
  final String? nextCursor;

  /// False when messages are valid but the server supplied no page boundary.
  final bool paginationKnown;
  bool get exhausted => paginationKnown && nextCursor == null;
  TwitchWhisperRemotePage({
    required this.ownerId,
    required this.peerId,
    required Iterable<TwitchWhisperMessage> messages,
    this.requestedCursor,
    this.nextCursor,
    this.paginationKnown = true,
  }) : messages = List.unmodifiable(messages);
}

class TwitchWhisperThreadsPage {
  final String ownerId;
  final List<TwitchWhisperConversation> conversations;
  final String? requestedCursor;
  final String? nextCursor;
  TwitchWhisperThreadsPage({
    required this.ownerId,
    required Iterable<TwitchWhisperConversation> conversations,
    this.requestedCursor,
    this.nextCursor,
  }) : conversations = List.unmodifiable(conversations);
}
