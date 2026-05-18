// PATCH VERSION: twitch_chat_message_cards_stage219r_frosty_lightweight_rows
//
// Normal and special chat message card shells. The runtime tile chooses which
// card to render; this file owns the visual card frames.
//
// Stage 219R:
// - Makes normal chat rows closer to Frosty's lightweight model: no per-message
//   rounded card, no border, and smaller vertical padding.
// - Keeps special messages visually grouped because they are much less frequent
//   and need semantic emphasis.

import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import 'twitch_chat_message_content.dart';
import 'twitch_chat_message_special_style.dart';
import 'twitch_chat_message_timestamp.dart';
import 'twitch_chat_message_visual_metrics.dart';

class TwitchChatNormalMessageCard extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final Color displayColor;
  final String displayNameText;
  final bool showTimestamp;
  final TwitchChatMessageVisualMetrics metrics;
  final VoidCallback? onOpenContext;

  const TwitchChatNormalMessageCard({
    super.key,
    required this.message,
    required this.thirdPartyEmotes,
    required this.displayColor,
    required this.displayNameText,
    required this.showTimestamp,
    required this.metrics,
    required this.onOpenContext,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpenContext,
      onLongPress: onOpenContext,
      onSecondaryTap: onOpenContext,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 2.5, 10, 2.5),
        child: TwitchChatMessageContent(
          message: message,
          thirdPartyEmotes: thirdPartyEmotes,
          displayColor: displayColor,
          displayNameText: displayNameText,
          showSystemMessage: true,
          showTimestamp: showTimestamp,
          metrics: metrics,
        ),
      ),
    );
  }
}

class TwitchChatSpecialMessageCard extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final Color displayColor;
  final String displayNameText;
  final TwitchChatSpecialMessageStyle style;
  final bool showTimestamp;
  final TwitchChatMessageVisualMetrics metrics;
  final VoidCallback? onOpenContext;

  const TwitchChatSpecialMessageCard({
    super.key,
    required this.message,
    required this.thirdPartyEmotes,
    required this.displayColor,
    required this.displayNameText,
    required this.style,
    required this.showTimestamp,
    required this.metrics,
    required this.onOpenContext,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata;
    final bannerText = metadata.systemMessage?.trim();
    final hasVisibleChatText =
        message.message.trim().isNotEmpty || message.segments.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: InkWell(
        onTap: onOpenContext,
        onLongPress: onOpenContext,
        onSecondaryTap: onOpenContext,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: style.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: style.accentColor, width: 3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 7, 8, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(style.icon, size: 14, color: style.accentColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        metadata.specialLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: style.accentColor,
                          fontSize: 11 * metrics.scale,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    if (showTimestamp) ...[
                      const SizedBox(width: 7),
                      TwitchChatTimestampChip(
                        time: message.receivedAt,
                        metrics: metrics,
                      ),
                    ],
                  ],
                ),
                if (bannerText != null && bannerText.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    bannerText,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: metrics.compactMessageFontSize,
                      height: metrics.lineHeight,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (hasVisibleChatText) ...[
                  if (bannerText != null && bannerText.isNotEmpty)
                    const SizedBox(height: 5),
                  TwitchChatMessageContent(
                    message: message,
                    thirdPartyEmotes: thirdPartyEmotes,
                    displayColor: displayColor,
                    displayNameText: displayNameText,
                    showSystemMessage: false,
                    showTimestamp: false,
                    compact: true,
                    metrics: metrics,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}