import 'package:flutter/material.dart';

import '../../../../services/chat/twitch_chat_runtime.dart';
import '../../../localization/vioclass_localizations.dart';
import '../../chat/twitch_chat_text_style.dart';

class TwitchChatRoomModeBanner extends StatelessWidget {
  final TwitchChatRoomState roomState;
  final bool compact;
  final bool viewerIsFollowing;
  final DateTime? viewerFollowedAt;
  final bool viewerIsModerator;
  final bool viewerIsVip;
  final bool viewerIsSubscriber;

  const TwitchChatRoomModeBanner({
    super.key,
    required this.roomState,
    required this.compact,
    required this.viewerIsFollowing,
    required this.viewerFollowedAt,
    required this.viewerIsModerator,
    required this.viewerIsVip,
    required this.viewerIsSubscriber,
  });

  @override
  Widget build(BuildContext context) {
    if (!roomState.hasRestrictions) return const SizedBox.shrink();

    final l10n = context.vio;
    final bypassFollowerAndSlow = viewerIsModerator || viewerIsVip;
    final labels = <String>[
      if (roomState.subscribersOnly &&
          !viewerIsModerator &&
          !viewerIsVip &&
          !viewerIsSubscriber)
        l10n.isEnglish ? 'Subscribers-only' : '訂閱者限定',
      if (roomState.followersOnlyMinutes >= 0 &&
          !bypassFollowerAndSlow &&
          !_meetsFollowerRequirement(roomState.followersOnlyMinutes))
        _followersOnlyLabel(l10n, roomState.followersOnlyMinutes),
      if (roomState.slowModeSeconds > 0 && !bypassFollowerAndSlow)
        _slowModeLabel(l10n, roomState.slowModeSeconds),
      if (roomState.emoteOnly && !viewerIsModerator)
        l10n.isEnglish ? 'Emote-only' : '僅限表情',
      if (roomState.uniqueChat && !viewerIsModerator)
        l10n.isEnglish ? 'Unique chat' : '唯一訊息模式',
    ];
    if (labels.isEmpty) return const SizedBox.shrink();

    return Semantics(
      container: true,
      label: l10n.isEnglish ? 'Chat restrictions' : '聊天室限制',
      value: labels.join(', '),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(10, compact ? 6 : 7, 10, 2),
        child: Wrap(
          spacing: 6,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Icon(
              Icons.lock_outline_rounded,
              size: compact ? 13 : 14,
              color: Colors.amber.shade200.withValues(alpha: 0.88),
            ),
            ...labels.map(
              (label) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  label,
                  style: twitchChatTextStyle(
                    TextStyle(
                      color: Colors.amber.shade100.withValues(alpha: 0.92),
                      fontSize: compact ? 10.5 : 11,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _meetsFollowerRequirement(int requiredMinutes) {
    if (!viewerIsFollowing) return false;
    if (requiredMinutes <= 0) return true;
    final followedAt = viewerFollowedAt;
    if (followedAt == null) return false;
    return DateTime.now().difference(followedAt).inMinutes >= requiredMinutes;
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
}
