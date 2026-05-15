import '../../models/chat/twitch_chat_message.dart';

/// Live IRC raw line parser.
///
/// 只處理 Twitch IRC / IRC WebSocket 這種標準格式：
///   @tags :user!user@user.tmi.twitch.tv PRIVMSG #channel :message
///
/// recent-messages / historical object 不應該直接丟進這裡。
class TwitchIrcMessageParser {
  const TwitchIrcMessageParser();

  TwitchChatMessage parseLine(String line) {
    final original = line.trimRight();
    final tags = <String, String>{};

    var rest = original.trim();

    if (rest.startsWith('@')) {
      final spaceIndex = rest.indexOf(' ');
      if (spaceIndex > 0) {
        final rawTags = rest.substring(1, spaceIndex);
        rest = rest.substring(spaceIndex + 1);

        for (final pair in rawTags.split(';')) {
          if (pair.isEmpty) continue;

          final equalsIndex = pair.indexOf('=');
          if (equalsIndex <= 0) {
            tags[pair] = '';
          } else {
            tags[pair.substring(0, equalsIndex)] =
                decodeTagValue(pair.substring(equalsIndex + 1));
          }
        }
      }
    }

    var prefix = '';
    if (rest.startsWith(':')) {
      final spaceIndex = rest.indexOf(' ');
      if (spaceIndex > 0) {
        prefix = rest.substring(1, spaceIndex);
        rest = rest.substring(spaceIndex + 1);
      }
    }

    final trailingIndex = rest.indexOf(' :');
    final middle = trailingIndex < 0 ? rest : rest.substring(0, trailingIndex);
    var trailing = trailingIndex < 0 ? '' : rest.substring(trailingIndex + 2);

    if (trailing.isEmpty) {
      trailing = extractPrivmsgTrailingFromRaw(original);
    }

    final parts = middle.split(' ').where((item) => item.isNotEmpty).toList();
    final command = parts.isEmpty ? extractCommandFromRaw(original) : parts.first;
    final channel = extractChannel(parts, original);

    final userLogin = extractLogin(
      prefix: prefix,
      tags: tags,
      raw: original,
    );

    final displayName = tags['display-name']?.trim().isNotEmpty == true
        ? tags['display-name']!.trim()
        : userLogin;

    return TwitchChatMessage(
      raw: original,
      command: command,
      channel: channel,
      userLogin: userLogin,
      displayName: displayName,
      message: trailing,
      tags: tags,
      source: TwitchChatMessageSource.liveIrc,
    );
  }

  static String extractPrivmsgTrailingFromRaw(String raw) {
    final privmsgIndex = raw.indexOf(' PRIVMSG ');
    if (privmsgIndex < 0) return '';

    final afterPrivmsg = raw.substring(privmsgIndex + ' PRIVMSG '.length);
    final separatorIndex = afterPrivmsg.indexOf(' :');

    if (separatorIndex < 0) return '';

    return afterPrivmsg.substring(separatorIndex + 2);
  }

  static String extractCommandFromRaw(String raw) {
    if (raw.contains(' PRIVMSG ')) return 'PRIVMSG';
    if (raw.contains(' USERNOTICE ')) return 'USERNOTICE';
    if (raw.contains(' NOTICE ')) return 'NOTICE';
    if (raw.contains(' CLEARCHAT ')) return 'CLEARCHAT';
    if (raw.contains(' CLEARMSG ')) return 'CLEARMSG';
    if (raw.contains(' ROOMSTATE ')) return 'ROOMSTATE';
    if (raw.contains(' USERSTATE ')) return 'USERSTATE';
    return '';
  }

  static String extractChannel(List<String> parts, String raw) {
    if (parts.length >= 2) {
      return parts[1].replaceFirst('#', '');
    }

    final match = RegExp(r' PRIVMSG #([^\s]+) ').firstMatch(raw);
    if (match != null) return match.group(1) ?? '';

    return '';
  }

  static String extractLogin({
    required String prefix,
    required Map<String, String> tags,
    required String raw,
  }) {
    if (prefix.contains('!')) {
      return prefix.substring(0, prefix.indexOf('!'));
    }

    final loginTag = tags['login'];
    if (loginTag != null && loginTag.trim().isNotEmpty) {
      return loginTag.trim();
    }

    final userIdLogin = tags['user-login'];
    if (userIdLogin != null && userIdLogin.trim().isNotEmpty) {
      return userIdLogin.trim();
    }

    final match = RegExp(r':([^!\s]+)!').firstMatch(raw);
    if (match != null) return match.group(1) ?? '';

    return '';
  }

  static String decodeTagValue(String value) {
    return value
        .replaceAll(r'\s', ' ')
        .replaceAll(r'\:', ';')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\n', '\n');
  }
}
