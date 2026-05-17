// PATCH VERSION: twitch_chat_message_badges_stage161_fix_badge_type
//
// Badge renderer for runtime chat messages. Badge sizing is controlled by
// TwitchChatMessageVisualMetrics, while this file owns badge image rendering.

import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_badge.dart';
import '../../shared/twitch_cached_image_layer.dart';
import 'twitch_chat_message_visual_metrics.dart';

class TwitchChatMessageBadgeRow extends StatelessWidget {
  final List<TwitchChatBadge> badges;
  final TwitchChatMessageVisualMetrics metrics;
  final bool compact;

  const TwitchChatMessageBadgeRow({
    super.key,
    required this.badges,
    required this.metrics,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final visibleBadges = badges
        .where((badge) => badge.image1x.trim().isNotEmpty)
        .toList(growable: false);

    if (visibleBadges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 3,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final badge in visibleBadges)
          TwitchChatMessageBadge(
            badge: badge,
            metrics: metrics,
            compact: compact,
          ),
      ],
    );
  }
}

class TwitchChatMessageBadge extends StatelessWidget {
  final TwitchChatBadge badge;
  final TwitchChatMessageVisualMetrics metrics;
  final bool compact;

  const TwitchChatMessageBadge({
    super.key,
    required this.badge,
    required this.metrics,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? metrics.compactBadgeSize : metrics.badgeSize;

    return Tooltip(
      message: badge.title,
      child: TwitchCachedImageLayer(
        imageUrl: badge.image1x,
        width: size,
        height: size,
        cacheWidth: 36,
        cacheHeight: 36,
        fit: BoxFit.contain,
        fallbackColor: Colors.transparent,
        errorWidget: const SizedBox.shrink(),
      ),
    );
  }
}
