import '../../../../services/chat/twitch_chat_runtime.dart';
import '../../../localization/vioclass_localizations.dart';

String? twitchChatRoomModeHint({
  required VioClassLocalizations l10n,
  required TwitchChatRoomState roomState,
  required bool viewerIsFollowing,
  required DateTime? viewerFollowedAt,
  required bool viewerIsModerator,
  required bool viewerIsVip,
  required bool viewerIsSubscriber,
}) {
  if (!roomState.hasRestrictions) return null;

  final bypassFollowerAndSlow = viewerIsModerator || viewerIsVip;
  final labels = <String>[
    if (roomState.subscribersOnly &&
        !viewerIsModerator &&
        !viewerIsVip &&
        !viewerIsSubscriber)
      l10n.isEnglish ? 'Subscribers-only' : '訂閱者限定',
    if (roomState.followersOnlyMinutes >= 0 &&
        !bypassFollowerAndSlow &&
        !_meetsFollowerRequirement(
          requiredMinutes: roomState.followersOnlyMinutes,
          viewerIsFollowing: viewerIsFollowing,
          viewerFollowedAt: viewerFollowedAt,
        ))
      _followersOnlyLabel(l10n, roomState.followersOnlyMinutes),
    if (roomState.slowModeSeconds > 0 && !bypassFollowerAndSlow)
      _slowModeLabel(l10n, roomState.slowModeSeconds),
    if (roomState.emoteOnly && !viewerIsModerator)
      l10n.isEnglish ? 'Emote-only' : '僅限表情',
    if (roomState.uniqueChat && !viewerIsModerator)
      l10n.isEnglish ? 'Unique chat' : '唯一訊息模式',
  ];
  if (labels.isEmpty) return null;

  final prefix = l10n.isEnglish ? 'Chat restrictions' : '聊天室限制';
  return '$prefix · ${labels.join(' · ')}';
}

bool _meetsFollowerRequirement({
  required int requiredMinutes,
  required bool viewerIsFollowing,
  required DateTime? viewerFollowedAt,
}) {
  if (!viewerIsFollowing) return false;
  if (requiredMinutes <= 0) return true;
  if (viewerFollowedAt == null) return false;
  return DateTime.now().difference(viewerFollowedAt).inMinutes >=
      requiredMinutes;
}

String _followersOnlyLabel(VioClassLocalizations l10n, int minutes) {
  if (minutes <= 0) {
    return l10n.isEnglish ? 'Followers-only' : '追隨者限定';
  }
  final duration = _formatMinutes(l10n, minutes);
  return l10n.isEnglish ? 'Follow for $duration' : '需追隨滿 $duration';
}

String _slowModeLabel(VioClassLocalizations l10n, int seconds) {
  final duration = seconds >= 60 && seconds % 60 == 0
      ? (l10n.isEnglish ? '${seconds ~/ 60} min' : '${seconds ~/ 60} 分鐘')
      : (l10n.isEnglish ? '$seconds sec' : '$seconds 秒');
  return l10n.isEnglish ? 'Slow mode · $duration' : '慢速模式 · $duration';
}

String _formatMinutes(VioClassLocalizations l10n, int minutes) {
  if (minutes % (24 * 60) == 0) {
    final days = minutes ~/ (24 * 60);
    return l10n.isEnglish ? '$days ${days == 1 ? 'day' : 'days'}' : '$days 天';
  }
  if (minutes % 60 == 0) {
    final hours = minutes ~/ 60;
    return l10n.isEnglish
        ? '$hours ${hours == 1 ? 'hour' : 'hours'}'
        : '$hours 小時';
  }
  return l10n.isEnglish ? '$minutes min' : '$minutes 分鐘';
}
