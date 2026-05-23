import 'package:flutter/material.dart';

import '../../../../models/special_actions/twitch_pending_special_message_stage250.dart';

class TwitchPendingChatActionBannerStage250 extends StatelessWidget {
  final TwitchPendingSpecialMessageStage250 pending;
  final bool compact;
  final VoidCallback onCancel;

  const TwitchPendingChatActionBannerStage250({
    super.key,
    required this.pending,
    required this.compact,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentForKind(pending.kind);

    return Padding(
      padding: EdgeInsets.fromLTRB(10, compact ? 7 : 9, 10, 0),
      child: Container(
        padding: EdgeInsets.fromLTRB(10, compact ? 8 : 10, 7, compact ? 8 : 10),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.34)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: compact ? 30 : 34,
              height: compact ? 30 : 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.20),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withOpacity(0.42)),
              ),
              child: Icon(
                _iconForKind(pending.kind),
                color: accent,
                size: compact ? 16 : 18,
              ),
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          '已選擇：${pending.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 12.2 : 13.2,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (pending.hasCostLabel) ...<Widget>[
                        const SizedBox(width: 6),
                        _TinyPill(text: pending.costLabel!, color: accent),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pending.subtitle,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.66),
                      fontSize: compact ? 10.8 : 11.6,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: '取消',
              onPressed: onCancel,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white70,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _accentForKind(TwitchPendingSpecialMessageKind kind) {
    switch (kind) {
      case TwitchPendingSpecialMessageKind.preview:
        return const Color(0xFFBF94FF);
      case TwitchPendingSpecialMessageKind.highlightedMessage:
        return const Color(0xFFFFC857);
      case TwitchPendingSpecialMessageKind.watchStreak:
        return const Color(0xFF5CFFB1);
      case TwitchPendingSpecialMessageKind.resub:
        return const Color(0xFFFF75E6);
      case TwitchPendingSpecialMessageKind.channelPointRewardMessage:
        return const Color(0xFFBF94FF);
      case TwitchPendingSpecialMessageKind.officialSpecialMessage:
        return const Color(0xFF00A3FF);
    }
  }

  static IconData _iconForKind(TwitchPendingSpecialMessageKind kind) {
    switch (kind) {
      case TwitchPendingSpecialMessageKind.preview:
        return Icons.science_rounded;
      case TwitchPendingSpecialMessageKind.highlightedMessage:
        return Icons.highlight_rounded;
      case TwitchPendingSpecialMessageKind.watchStreak:
        return Icons.local_fire_department_rounded;
      case TwitchPendingSpecialMessageKind.resub:
        return Icons.workspace_premium_rounded;
      case TwitchPendingSpecialMessageKind.channelPointRewardMessage:
        return Icons.stars_rounded;
      case TwitchPendingSpecialMessageKind.officialSpecialMessage:
        return Icons.verified_rounded;
    }
  }
}

class _TinyPill extends StatelessWidget {
  final String text;
  final Color color;

  const _TinyPill({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          height: 1.0,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
