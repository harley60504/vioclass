enum TwitchChatMessageSource {
  liveIrc,
  recentRawIrc,
  recentObject,
  synthetic,
  localEcho,
}

class TwitchChatMessage {
  final String raw;
  final String command;
  final String channel;
  final String userLogin;
  final String displayName;
  final String message;
  final Map<String, String> tags;
  final TwitchChatMessageSource source;

  const TwitchChatMessage({
    required this.raw,
    required this.command,
    required this.channel,
    required this.userLogin,
    required this.displayName,
    required this.message,
    this.tags = const <String, String>{},
    this.source = TwitchChatMessageSource.liveIrc,
  });

  bool get isPrivMsg => command == 'PRIVMSG';
  bool get hasMessageText => message.trim().isNotEmpty;

  TwitchChatMessage copyWith({
    String? raw,
    String? command,
    String? channel,
    String? userLogin,
    String? displayName,
    String? message,
    Map<String, String>? tags,
    TwitchChatMessageSource? source,
  }) {
    return TwitchChatMessage(
      raw: raw ?? this.raw,
      command: command ?? this.command,
      channel: channel ?? this.channel,
      userLogin: userLogin ?? this.userLogin,
      displayName: displayName ?? this.displayName,
      message: message ?? this.message,
      tags: tags ?? this.tags,
      source: source ?? this.source,
    );
  }

  factory TwitchChatMessage.synthetic({
    required String channelLogin,
    required String userLogin,
    required String displayName,
    required String message,
    Map<String, String> tags = const <String, String>{},
    String raw = '',
    TwitchChatMessageSource source = TwitchChatMessageSource.synthetic,
  }) {
    final safeLogin = userLogin.trim().isEmpty ? 'unknown' : userLogin.trim();
    final safeDisplayName =
        displayName.trim().isEmpty ? safeLogin : displayName.trim();
    final safeChannel = channelLogin.trim().replaceFirst('#', '').toLowerCase();

    final mergedTags = <String, String>{
      ...tags,
      if (!tags.containsKey('display-name')) 'display-name': safeDisplayName,
    };

    return TwitchChatMessage(
      raw: raw.isEmpty
          ? ':$safeLogin!$safeLogin@$safeLogin.tmi.twitch.tv PRIVMSG #$safeChannel :$message'
          : raw,
      command: 'PRIVMSG',
      channel: safeChannel,
      userLogin: safeLogin,
      displayName: safeDisplayName,
      message: message,
      tags: mergedTags,
      source: source,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'source': source.name,
      'command': command,
      'channel': channel,
      'userLogin': userLogin,
      'displayName': displayName,
      'message': message,
      'messageLength': message.length,
      'hasMessageText': hasMessageText,
      'tags': tags,
      'raw': raw,
    };
  }
}
