// PATCH VERSION: twitch_chat_message_content_stage157
//
// Core message content composition: reply preview, system line, badges,
// display name, first-message chip, rendered segments and small status chips.

import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../shared/twitch_cached_image_layer.dart';
import 'twitch_chat_message_chips.dart';
import 'twitch_chat_message_reply_preview.dart';
import 'twitch_chat_message_segments.dart';
import 'twitch_chat_message_timestamp.dart';
import 'twitch_chat_message_visual_metrics.dart';

class TwitchChatMessageContent extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final Color displayColor;
  final String displayNameText;
  final bool showSystemMessage;
  final bool showTimestamp;
  final bool compact;
  final TwitchChatMessageVisualMetrics metrics;

  const TwitchChatMessageContent({
    super.key,
    required this.message,
    required this.thirdPartyEmotes,
    required this.displayColor,
    required this.displayNameText,
    required this.showSystemMessage,
    required this.showTimestamp,
    required this.metrics,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final segments = message.segments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.metadata.hasReply)
          TwitchChatMessageReplyPreview(message: message, metrics: metrics),
        if (showSystemMessage && message.metadata.isSystemLike)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              message.metadata.systemMessage!,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: const Color(0xFFFFC857),
                fontSize: metrics.compactMessageFontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.start,
            spacing: 4,
            runSpacing: 3,
            children: [
              if (showTimestamp)
                TwitchChatTimestampText(time: message.receivedAt, metrics: metrics),
              for (final badge in message.resolvedBadges)
                if (badge.image1x.isNotEmpty)
                  Tooltip(
                    message: badge.title,
                    child: TwitchCachedImageLayer(
                      imageUrl: badge.image1x,
                      width: compact
                          ? metrics.compactBadgeSize
                          : metrics.badgeSize,
                      height: compact
                          ? metrics.compactBadgeSize
                          : metrics.badgeSize,
                      cacheWidth: 36,
                      cacheHeight: 36,
                      fit: BoxFit.contain,
                      fallbackColor: Colors.transparent,
                      errorWidget: const SizedBox.shrink(),
                    ),
                  ),
              Text(
                displayNameText,
                style: TextStyle(
                  color: displayColor,
                  fontWeight: FontWeight.w900,
                  fontSize: compact
                      ? metrics.compactNameFontSize
                      : metrics.nameFontSize,
                  fontStyle: message.metadata.isAction
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
              if (message.metadata.isFirstMessage)
                TwitchChatFirstMessageChip(metrics: metrics),
              Text(
                ':',
                style: TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w700,
                  fontSize: metrics.messageFontSize,
                ),
              ),
              if (segments.isEmpty)
                Text(
                  '〔空訊息〕',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: metrics.compactMessageFontSize,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                for (final segment in segments)
                  TwitchChatMessageSegmentView(
                    segment: segment,
                    thirdPartyEmotes: thirdPartyEmotes,
                    metrics: metrics,
                  ),
              if (message.metadata.hasBits)
                TwitchChatBitsChip(
                  bits: message.metadata.bitsAmount!,
                  metrics: metrics,
                ),
              if (message.metadata.isRewardRedemption)
                TwitchChatSmallChip(label: 'reward', metrics: metrics),
            ],
          ),
        ),
      ],
    );
  }
}
