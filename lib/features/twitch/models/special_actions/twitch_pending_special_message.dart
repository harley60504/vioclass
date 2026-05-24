enum TwitchPendingSpecialMessageKind {
  preview,
  highlightedMessage,
  watchStreak,
  resub,
  channelPointRewardMessage,
  officialSpecialMessage,
}

class TwitchPendingSpecialMessage {
  final TwitchPendingSpecialMessageKind kind;
  final String channelLogin;
  final String? channelId;
  final String title;
  final String subtitle;
  final String sendLabel;
  final String? costLabel;
  final bool requiresTextInput;
  final bool previewOnly;
  final Map<String, dynamic> payload;

  const TwitchPendingSpecialMessage({
    required this.kind,
    required this.channelLogin,
    this.channelId,
    required this.title,
    required this.subtitle,
    this.sendLabel = '發送',
    this.costLabel,
    this.requiresTextInput = true,
    this.previewOnly = false,
    this.payload = const <String, dynamic>{},
  });

  bool get hasCostLabel {
    final text = costLabel?.trim();
    return text != null && text.isNotEmpty;
  }

  String get normalizedChannelLogin => channelLogin.trim().toLowerCase();

  String get kindLabel {
    switch (kind) {
      case TwitchPendingSpecialMessageKind.preview:
        return '測試';
      case TwitchPendingSpecialMessageKind.highlightedMessage:
        return '高亮訊息';
      case TwitchPendingSpecialMessageKind.watchStreak:
        return '連續觀看';
      case TwitchPendingSpecialMessageKind.resub:
        return '訂閱分享';
      case TwitchPendingSpecialMessageKind.channelPointRewardMessage:
        return '忠誠點數訊息';
      case TwitchPendingSpecialMessageKind.officialSpecialMessage:
        return '官方特殊訊息';
    }
  }

  String describeForLog({String? message}) {
    final trimmedMessage = message?.trim();
    return <String>[
      'kind=$kindLabel',
      'channel=$normalizedChannelLogin',
      'title=$title',
      if (hasCostLabel) 'cost=$costLabel',
      if (trimmedMessage != null && trimmedMessage.isNotEmpty)
        'message=$trimmedMessage',
    ].join(' | ');
  }

  TwitchPendingSpecialMessage copyWith({
    TwitchPendingSpecialMessageKind? kind,
    String? channelLogin,
    String? channelId,
    String? title,
    String? subtitle,
    String? sendLabel,
    String? costLabel,
    bool? requiresTextInput,
    bool? previewOnly,
    Map<String, dynamic>? payload,
  }) {
    return TwitchPendingSpecialMessage(
      kind: kind ?? this.kind,
      channelLogin: channelLogin ?? this.channelLogin,
      channelId: channelId ?? this.channelId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      sendLabel: sendLabel ?? this.sendLabel,
      costLabel: costLabel ?? this.costLabel,
      requiresTextInput: requiresTextInput ?? this.requiresTextInput,
      previewOnly: previewOnly ?? this.previewOnly,
      payload: payload ?? this.payload,
    );
  }
}
