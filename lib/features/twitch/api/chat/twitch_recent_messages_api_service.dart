import '../../models/chat/twitch_chat_message.dart';
import '../../parsers/chat/twitch_recent_message_parser.dart';
import '../core/twitch_api_client.dart';

class TwitchRecentMessagesResult {
  final String channelLogin;
  final List<TwitchChatMessage> messages;
  final List<String> rawMessages;
  final List<Map<String, dynamic>> rawObjects;
  final List<TwitchRecentMessageParseIssue> issues;

  const TwitchRecentMessagesResult({
    required this.channelLogin,
    required this.messages,
    required this.rawMessages,
    this.rawObjects = const <Map<String, dynamic>>[],
    this.issues = const <TwitchRecentMessageParseIssue>[],
  });

  int get emptyMessageCount {
    return messages.where((message) => message.message.trim().isEmpty).length;
  }

  Map<String, dynamic> toJson() {
    final emptyMessages = messages
        .where((message) => message.message.trim().isEmpty)
        .take(12)
        .map((message) => message.toJson())
        .toList(growable: false);

    return <String, dynamic>{
      'channelLogin': channelLogin,
      'count': messages.length,
      'emptyMessageCount': emptyMessageCount,
      'issueCount': issues.length,
      'messages': messages.map((message) => message.toJson()).toList(),
      'emptyMessagesPreview': emptyMessages,
      'issues': issues.take(20).map((issue) => issue.toJson()).toList(),
      'rawMessagesPreview': rawMessages.take(8).toList(),
      'rawObjectsPreview': rawObjects.take(5).toList(),
    };
  }
}

/// recent-messages.robotty.de wrapper.
///
/// 這個 service 只負責打 API，不直接寫 parsing 細節。
/// Parsing 交給 TwitchRecentMessageParser。
class TwitchRecentMessagesApiService {
  final TwitchApiClient client;
  final TwitchRecentMessageParser parser;

  const TwitchRecentMessagesApiService({
    required this.client,
    this.parser = const TwitchRecentMessageParser(),
  });

  Future<TwitchRecentMessagesResult> getRecentMessages({
    required String channelLogin,
    int limit = 100,
    bool includeClearchat = false,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      throw ArgumentError.value(
        channelLogin,
        'channelLogin',
        'channelLogin cannot be empty',
      );
    }

    final uri = Uri.https(
      'recent-messages.robotty.de',
      '/api/v2/recent-messages/$login',
      <String, String>{
        'limit': limit.clamp(1, 700).toString(),
        'clearchat': includeClearchat.toString(),
      },
    );

    final response = await client.getJson<Map<String, dynamic>>(
      uri.toString(),
      headers: const <String, String>{
        'Accept': 'application/json',
      },
    );

    final parsed = parser.parseMessagesField(
      messagesField: response['messages'],
      channelLogin: login,
    );

    return TwitchRecentMessagesResult(
      channelLogin: login,
      messages: parsed.messages,
      rawMessages: parsed.rawMessages,
      rawObjects: parsed.rawObjects,
      issues: parsed.issues,
    );
  }
}
