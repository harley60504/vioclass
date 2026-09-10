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
///
/// 官方 MessageBuffer 與第三方 recent-messages 都屬於「歷史訊息」。這裡統一標成
/// recentObject，讓 runtime 的既有 fingerprint 可以跨來源去重；controller 會先加入
/// 官方歷史，因此相同訊息同時存在官方與第三方時，官方版本會保留下來。
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
        message: parsed,
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
            message: parsed,
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
      return parsed.copyWith(source: TwitchChatMessageSource.recentObject);
    }

    final relaxedMessage = extractRelaxedPrivmsgTrailing(raw);
    if (relaxedMessage == null || relaxedMessage.trim().isEmpty) {
      return parsed.copyWith(source: TwitchChatMessageSource.recentObject);
    }

    return parsed.copyWith(
      message: relaxedMessage,
      source: TwitchChatMessageSource.recentObject,
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
      ...readStringMap(readNestedValue(item, const <String>['message', 'tags'])),
    };

    final nestedMessage = item['message'];
    final text =
        readTextValue(item['text']) ??
        readTextValue(item['body']) ??
        readTextValue(item['content']) ??
        readTextValue(item['messageText']) ??
        readTextValue(readNestedValue(item, const <String>['fragments'])) ??
        readTextValue(nestedMessage) ??
        readTextValue(
          readNestedValue(item, const <String>['message', 'text']),
        ) ??
        readTextValue(
          readNestedValue(item, const <String>['message', 'body']),
        ) ??
        readTextValue(
          readNestedValue(item, const <String>['message', 'content']),
        ) ??
        readTextValue(
          readNestedValue(
            item,
            const <String>['message', 'content', 'fragments'],
          ),
        ) ??
        parsed?.message ??
        '';

    final extractedDisplayName = _readFirstPathText(
      item,
      const <List<String>>[
        <String>['displayName'],
        <String>['display_name'],
        <String>['display-name'],
        <String>['sender', 'displayName'],
        <String>['sender', 'display_name'],
        <String>['sender', 'name'],
        <String>['user', 'displayName'],
        <String>['user', 'display_name'],
        <String>['user', 'name'],
        <String>['author', 'displayName'],
        <String>['author', 'name'],
        <String>['chatter', 'displayName'],
        <String>['chatter', 'name'],
        <String>['message', 'sender', 'displayName'],
        <String>['message', 'sender', 'display_name'],
        <String>['message', 'sender', 'name'],
        <String>['message', 'user', 'displayName'],
        <String>['message', 'user', 'name'],
        <String>['message', 'author', 'displayName'],
        <String>['message', 'chatter', 'displayName'],
      ],
    );

    final userLogin =
        _readFirstPathText(
          item,
          const <List<String>>[
            <String>['userLogin'],
            <String>['login'],
            <String>['username'],
            <String>['sender', 'login'],
            <String>['sender', 'username'],
            <String>['user', 'login'],
            <String>['user', 'username'],
            <String>['author', 'login'],
            <String>['author', 'username'],
            <String>['chatter', 'login'],
            <String>['chatter', 'username'],
            <String>['message', 'sender', 'login'],
            <String>['message', 'sender', 'username'],
            <String>['message', 'user', 'login'],
            <String>['message', 'author', 'login'],
            <String>['message', 'chatter', 'login'],
          ],
        ) ??
        parsed?.userLogin ??
        extractedDisplayName?.trim().toLowerCase() ??
        '';

    final displayName =
        extractedDisplayName ?? parsed?.displayName ?? userLogin;

    final badgesTag = _readBadgesTag(item);
    final emotesTag = _buildEmotesTagFromObject(item);

    final mergedTags = <String, String>{
      ...tags,
      if (!tags.containsKey('display-name') && displayName.trim().isNotEmpty)
        'display-name': displayName.trim(),
      if (!tags.containsKey('login') && userLogin.trim().isNotEmpty)
        'login': userLogin.trim(),
      if (!tags.containsKey('id'))
        'id':
            _readFirstPathText(
              item,
              const <List<String>>[
                <String>['id'],
                <String>['message', 'id'],
                <String>['content', 'id'],
              ],
            ) ??
            parsed?.tags['id'] ??
            '',
      if (!tags.containsKey('user-id'))
        'user-id':
            _readFirstPathText(
              item,
              const <List<String>>[
                <String>['userId'],
                <String>['userID'],
                <String>['sender', 'id'],
                <String>['user', 'id'],
                <String>['author', 'id'],
                <String>['chatter', 'id'],
                <String>['message', 'sender', 'id'],
                <String>['message', 'user', 'id'],
                <String>['message', 'author', 'id'],
                <String>['message', 'chatter', 'id'],
              ],
            ) ??
            parsed?.tags['user-id'] ??
            '',
      if (!tags.containsKey('color'))
        'color':
            _readFirstPathText(
              item,
              const <List<String>>[
                <String>['senderChatColor'],
                <String>['color'],
                <String>['userColor'],
                <String>['chatColor'],
                <String>['sender', 'color'],
                <String>['sender', 'chatColor'],
                <String>['user', 'color'],
                <String>['message', 'senderChatColor'],
                <String>['message', 'sender', 'color'],
                <String>['message', 'sender', 'chatColor'],
              ],
            ) ??
            parsed?.tags['color'] ??
            '',
      if (!tags.containsKey('badges') && badgesTag != null)
        'badges': badgesTag,
      if (!tags.containsKey('emotes') && emotesTag != null)
        'emotes': emotesTag,
      if (!tags.containsKey('tmi-sent-ts'))
        'tmi-sent-ts':
            _readFirstTimestampMillis(
              item,
              const <List<String>>[
                <String>['timestamp'],
                <String>['sentAt'],
                <String>['createdAt'],
                <String>['message', 'timestamp'],
                <String>['message', 'sentAt'],
                <String>['message', 'createdAt'],
                <String>['content', 'timestamp'],
                <String>['content', 'sentAt'],
              ],
            ) ??
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

  String? _readFirstPathText(
    Map<String, dynamic> item,
    List<List<String>> paths,
  ) {
    for (final path in paths) {
      final value = readNestedValue(item, path);
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num) {
        return value.toString();
      }
    }
    return null;
  }

  String? _readFirstTimestampMillis(
    Map<String, dynamic> item,
    List<List<String>> paths,
  ) {
    for (final path in paths) {
      final timestamp = readTimestampMillis(readNestedValue(item, path));
      if (timestamp != null && timestamp.isNotEmpty) return timestamp;
    }
    return null;
  }

  String? _readBadgesTag(Map<String, dynamic> item) {
    for (final path in const <List<String>>[
      <String>['senderBadges'],
      <String>['sourceSenderBadges'],
      <String>['badges'],
      <String>['sender', 'badges'],
      <String>['user', 'badges'],
      <String>['author', 'badges'],
      <String>['chatter', 'badges'],
      <String>['message', 'senderBadges'],
      <String>['message', 'sourceSenderBadges'],
      <String>['message', 'badges'],
      <String>['message', 'sender', 'badges'],
      <String>['message', 'user', 'badges'],
    ]) {
      final tag = _badgeTagFromUnknown(readNestedValue(item, path));
      if (tag != null && tag.isNotEmpty) return tag;
    }
    return null;
  }

  String? _badgeTagFromUnknown(Object? value) {
    if (value == null) return null;

    if (value is String) {
      final clean = value.trim();
      return clean.isEmpty ? null : clean;
    }

    if (value is List) {
      final tokens = value
          .map(_badgeTokenFromUnknown)
          .whereType<String>()
          .where((token) => token.isNotEmpty)
          .toList(growable: false);
      return tokens.isEmpty ? null : tokens.join(',');
    }

    if (value is Map) {
      final direct = _badgeTokenFromUnknown(value);
      if (direct != null && direct.isNotEmpty) return direct;

      final tokens = <String>[];
      for (final entry in value.entries) {
        final version = entry.value?.toString().trim() ?? '';
        final setId = entry.key.toString().trim();
        if (setId.isNotEmpty && version.isNotEmpty && version != 'null') {
          tokens.add('$setId/$version');
        }
      }
      return tokens.isEmpty ? null : tokens.join(',');
    }

    return null;
  }

  String? _badgeTokenFromUnknown(Object? value) {
    if (value is String) {
      final clean = value.trim();
      return clean.contains('/') ? clean : null;
    }
    if (value is! Map) return null;

    String? firstNonEmpty(Iterable<Object?> values) {
      for (final candidate in values) {
        final text = candidate?.toString().trim() ?? '';
        if (text.isNotEmpty && text != 'null') return text;
      }
      return null;
    }

    final setId = firstNonEmpty(<Object?>[
      value['setID'],
      value['setId'],
      value['set_id'],
      value['set-id'],
      value['set'],
      value['name'],
    ]);
    final version = firstNonEmpty(<Object?>[
      value['version'],
      value['versionID'],
      value['versionId'],
      value['version_id'],
      value['value'],
    ]);

    if (setId == null || version == null) return null;
    return '$setId/$version';
  }

  String? _buildEmotesTagFromObject(Map<String, dynamic> item) {
    List<dynamic>? fragments;
    for (final path in const <List<String>>[
      <String>['fragments'],
      <String>['content', 'fragments'],
      <String>['message', 'fragments'],
      <String>['message', 'content', 'fragments'],
    ]) {
      final value = readNestedValue(item, path);
      if (value is List && value.isNotEmpty) {
        fragments = value;
        break;
      }
    }
    if (fragments == null) return null;

    final rangesById = <String, List<String>>{};
    var cursor = 0;

    for (final fragment in fragments) {
      if (fragment is! Map) continue;
      final text =
          readTextValue(fragment['text']) ??
          readTextValue(fragment['content']) ??
          '';
      if (text.isEmpty) continue;

      final emote = fragment['emote'];
      String? emoteId;
      if (emote is Map) {
        emoteId =
            emote['id']?.toString().trim() ??
            emote['emoteID']?.toString().trim() ??
            emote['emoteId']?.toString().trim();
      }
      emoteId ??=
          fragment['emoteID']?.toString().trim() ??
          fragment['emoteId']?.toString().trim();

      final start = cursor;
      final end = cursor + text.length - 1;
      if (emoteId != null && emoteId.isNotEmpty) {
        rangesById.putIfAbsent(emoteId, () => <String>[]).add('$start-$end');
      }
      cursor = end + 1;
    }

    if (rangesById.isEmpty) return null;
    return rangesById.entries
        .map((entry) => '${entry.key}:${entry.value.join(',')}')
        .join('/');
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
        'fragments',
        'message',
        'value',
      ]) {
        final nested = readTextValue(value[key]);
        if (nested != null && nested.trim().isNotEmpty) {
          return nested;
        }
      }
    }

    if (value is List) {
      final text = value
          .map(readTextValue)
          .whereType<String>()
          .where((item) => item.trim().isNotEmpty)
          .join();
      return text.trim().isEmpty ? null : text;
    }

    return null;
  }

  String? readTimestampMillis(Object? value) {
    if (value is num) {
      final numeric = value.toDouble();
      if (!numeric.isFinite) return null;
      final millis = numeric.abs() < 100000000000
          ? (numeric * 1000).round()
          : numeric.round();
      return millis.toString();
    }

    final text = readTextValue(value);
    if (text == null || text.trim().isEmpty) return null;

    final integer = int.tryParse(text.trim());
    if (integer != null) {
      return integer.abs() < 100000000000
          ? (integer * 1000).toString()
          : integer.toString();
    }

    final parsed = DateTime.tryParse(text.trim());
    if (parsed == null) return null;

    return parsed.millisecondsSinceEpoch.toString();
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