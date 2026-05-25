import '../../models/chat/twitch_chat_message.dart';
import './twitch_irc_message_parser.dart';

class TwitchRecentMessageParseResult {
  final List<TwitchChatMessage> messages;
  final List<String> rawMessages;
  final List<Map<String, dynamic>> rawObjects;
  final List<TwitchRecentMessageParseIssue> issues;

  const TwitchRecentMessageParseResult({
    required this.messages,
    required this.rawMessages,
    required this.rawObjects,
    required this.issues,
  });

  int get emptyMessageCount {
    return messages.where((message) => message.message.trim().isEmpty).length;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'count': messages.length,
      'emptyMessageCount': emptyMessageCount,
      'issueCount': issues.length,
      'issues': issues.take(20).map((issue) => issue.toJson()).toList(),
      'emptyMessagesPreview': messages
          .where((message) => message.message.trim().isEmpty)
          .take(12)
          .map((message) => message.toJson())
          .toList(),
      'rawMessagesPreview': rawMessages.take(8).toList(),
      'rawObjectsPreview': rawObjects.take(5).toList(),
    };
  }
}

class TwitchRecentMessageParseIssue {
  final String reason;
  final Object? itemPreview;

  const TwitchRecentMessageParseIssue({required this.reason, this.itemPreview});

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'reason': reason,
      'itemPreview': itemPreview?.toString(),
    };
  }
}

/// recent-messages / historical message parser.
///
/// recent-messages.robotty.de 會回傳兩種常見 raw 格式：
///
/// 1. 標準 IRC trailing：
///    PRIVMSG #channel :message
///
/// 2. historical relaxed trailing：
///    PRIVMSG #channel message
///
/// 第二種不是標準 IRC trailing，但 recent-messages 會出現，所以只在 recent parser
/// 補 fallback，不改 live IRC parser。
class TwitchRecentMessageParser {
  final TwitchIrcMessageParser ircParser;

  const TwitchRecentMessageParser({
    this.ircParser = const TwitchIrcMessageParser(),
  });

  TwitchRecentMessageParseResult parseMessagesField({
    required Object? messagesField,
    required String channelLogin,
  }) {
    if (messagesField is! List) {
      return TwitchRecentMessageParseResult(
        messages: const <TwitchChatMessage>[],
        rawMessages: const <String>[],
        rawObjects: const <Map<String, dynamic>>[],
        issues: <TwitchRecentMessageParseIssue>[
          TwitchRecentMessageParseIssue(
            reason: 'messages field is not List',
            itemPreview: messagesField,
          ),
        ],
      );
    }

    final messages = <TwitchChatMessage>[];
    final rawMessages = <String>[];
    final rawObjects = <Map<String, dynamic>>[];
    final issues = <TwitchRecentMessageParseIssue>[];

    for (final item in messagesField) {
      final parsed = _parseSingleItem(item, channelLogin: channelLogin);

      if (parsed.rawLine != null) {
        rawMessages.add(parsed.rawLine!);
      }

      if (parsed.rawObject != null) {
        rawObjects.add(parsed.rawObject!);
      }

      if (parsed.issue != null) {
        issues.add(parsed.issue!);
      }

      final message = parsed.message;
      if (message != null && message.isPrivMsg) {
        messages.add(message);
      }
    }

    return TwitchRecentMessageParseResult(
      messages: messages,
      rawMessages: rawMessages,
      rawObjects: rawObjects,
      issues: issues,
    );
  }

  _RecentSingleParseResult _parseSingleItem(
    Object? item, {
    required String channelLogin,
  }) {
    if (item is String) {
      final raw = item.trimRight();

      if (raw.isEmpty) {
        return const _RecentSingleParseResult(
          issue: TwitchRecentMessageParseIssue(reason: 'empty string item'),
        );
      }

      final parsed = parseRecentRawLine(raw);

      return _RecentSingleParseResult(
        message: parsed.copyWith(source: TwitchChatMessageSource.recentRawIrc),
        rawLine: raw,
        issue: parsed.message.trim().isEmpty
            ? TwitchRecentMessageParseIssue(
                reason: 'recent raw line parsed but message body is empty',
                itemPreview: raw,
              )
            : null,
      );
    }

    if (item is Map<String, dynamic>) {
      final rawObject = item;
      final rawLine = readRawLine(rawObject);

      if (rawLine != null && rawLine.trim().isNotEmpty) {
        final parsed = parseRecentRawLine(rawLine);

        if (parsed.message.trim().isNotEmpty) {
          return _RecentSingleParseResult(
            message: parsed.copyWith(
              source: TwitchChatMessageSource.recentRawIrc,
            ),
            rawLine: rawLine,
            rawObject: rawObject,
          );
        }

        final fallback = messageFromObjectFallback(
          rawObject,
          channelLogin: channelLogin,
          raw: rawLine,
          parsed: parsed,
        );

        return _RecentSingleParseResult(
          message: fallback,
          rawLine: rawLine,
          rawObject: rawObject,
          issue: fallback.message.trim().isEmpty
              ? TwitchRecentMessageParseIssue(
                  reason:
                      'object raw line parsed but message body is still empty after fallback',
                  itemPreview: rawObject,
                )
              : null,
        );
      }

      final fallback = messageFromObjectFallback(
        rawObject,
        channelLogin: channelLogin,
        raw: '',
        parsed: null,
      );

      return _RecentSingleParseResult(
        message: fallback.message.trim().isEmpty ? null : fallback,
        rawObject: rawObject,
        issue: fallback.message.trim().isEmpty
            ? TwitchRecentMessageParseIssue(
                reason: 'object has no raw line and no readable message text',
                itemPreview: rawObject,
              )
            : null,
      );
    }

    return _RecentSingleParseResult(
      issue: TwitchRecentMessageParseIssue(
        reason: 'unsupported recent message item type: ${item.runtimeType}',
        itemPreview: item,
      ),
    );
  }

  TwitchChatMessage parseRecentRawLine(String raw) {
    final parsed = ircParser.parseLine(raw);

    if (parsed.message.trim().isNotEmpty) {
      return parsed.copyWith(source: TwitchChatMessageSource.recentRawIrc);
    }

    final relaxedMessage = extractRelaxedPrivmsgTrailing(raw);
    if (relaxedMessage == null || relaxedMessage.trim().isEmpty) {
      return parsed.copyWith(source: TwitchChatMessageSource.recentRawIrc);
    }

    return parsed.copyWith(
      message: relaxedMessage,
      source: TwitchChatMessageSource.recentRawIrc,
    );
  }

  /// Handles recent-messages relaxed format:
  ///   :user!user@user.tmi.twitch.tv PRIVMSG #channel message without colon
  ///
  /// Standard IRC requires " :message", but recent history can omit that colon.
  String? extractRelaxedPrivmsgTrailing(String raw) {
    final privmsgIndex = raw.indexOf(' PRIVMSG ');
    if (privmsgIndex < 0) return null;

    final afterPrivmsg = raw.substring(privmsgIndex + ' PRIVMSG '.length);

    // If standard trailing exists, let the normal IRC parser handle it.
    if (afterPrivmsg.contains(' :')) return null;

    final firstSpace = afterPrivmsg.indexOf(' ');
    if (firstSpace < 0 || firstSpace >= afterPrivmsg.length - 1) {
      return null;
    }

    final channelToken = afterPrivmsg.substring(0, firstSpace).trim();
    if (!channelToken.startsWith('#')) return null;

    return afterPrivmsg.substring(firstSpace + 1);
  }

  String? readRawLine(Map<String, dynamic> item) {
    for (final key in const <String>[
      'raw',
      'line',
      'irc',
      'ircLine',
      'rawLine',
      'data',
    ]) {
      final value = item[key];
      if (value is String && value.contains(' PRIVMSG ')) {
        return value;
      }
    }

    final message = item['message'];
    if (message is String && message.contains(' PRIVMSG ')) {
      return message;
    }

    return null;
  }

  TwitchChatMessage messageFromObjectFallback(
    Map<String, dynamic> item, {
    required String channelLogin,
    required String raw,
    required TwitchChatMessage? parsed,
  }) {
    final tags = <String, String>{
      if (parsed != null) ...parsed.tags,
      ...readStringMap(item['tags']),
    };

    final nestedMessage = item['message'];
    final text =
        readTextValue(item['text']) ??
        readTextValue(item['body']) ??
        readTextValue(item['content']) ??
        readTextValue(item['messageText']) ??
        readTextValue(nestedMessage) ??
        readTextValue(
          readNestedValue(item, const <String>['message', 'text']),
        ) ??
        readTextValue(
          readNestedValue(item, const <String>['message', 'body']),
        ) ??
        parsed?.message ??
        '';

    final userLogin =
        readTextValue(item['userLogin']) ??
        readTextValue(item['login']) ??
        readTextValue(item['username']) ??
        readTextValue(item['user']) ??
        readTextValue(readNestedValue(item, const <String>['user', 'login'])) ??
        parsed?.userLogin ??
        '';

    final displayName =
        readTextValue(item['displayName']) ??
        readTextValue(item['display-name']) ??
        readTextValue(
          readNestedValue(item, const <String>['user', 'displayName']),
        ) ??
        parsed?.displayName ??
        userLogin;

    final mergedTags = <String, String>{
      ...tags,
      if (!tags.containsKey('display-name') && displayName.trim().isNotEmpty)
        'display-name': displayName.trim(),
      if (!tags.containsKey('id'))
        'id': readTextValue(item['id']) ?? parsed?.tags['id'] ?? '',
      if (!tags.containsKey('tmi-sent-ts'))
        'tmi-sent-ts':
            readTextValue(item['timestamp']) ??
            readTextValue(item['sentAt']) ??
            parsed?.tags['tmi-sent-ts'] ??
            '',
    }..removeWhere((key, value) => value.trim().isEmpty);

    return TwitchChatMessage.synthetic(
      channelLogin: parsed?.channel.isNotEmpty == true
          ? parsed!.channel
          : channelLogin,
      userLogin: userLogin,
      displayName: displayName,
      message: text,
      tags: mergedTags,
      raw: raw,
      source: TwitchChatMessageSource.recentObject,
    );
  }

  Object? readNestedValue(Map<String, dynamic> item, List<String> path) {
    Object? current = item;

    for (final key in path) {
      if (current is! Map<String, dynamic>) return null;
      current = current[key];
    }

    return current;
  }

  String? readTextValue(Object? value) {
    if (value == null) return null;

    if (value is String) {
      final text = value.trim();
      return text.isEmpty ? null : value;
    }

    if (value is Map<String, dynamic>) {
      for (final key in const <String>[
        'text',
        'body',
        'content',
        'message',
        'value',
      ]) {
        final nested = readTextValue(value[key]);
        if (nested != null && nested.trim().isNotEmpty) {
          return nested;
        }
      }
    }

    return null;
  }

  Map<String, String> readStringMap(Object? value) {
    if (value is! Map) return const <String, String>{};

    return value.map(
      (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
    );
  }
}

class _RecentSingleParseResult {
  final TwitchChatMessage? message;
  final String? rawLine;
  final Map<String, dynamic>? rawObject;
  final TwitchRecentMessageParseIssue? issue;

  const _RecentSingleParseResult({
    this.message,
    this.rawLine,
    this.rawObject,
    this.issue,
  });
}
