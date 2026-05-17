// PATCH VERSION: twitch_chat_message_content_stage162_author_extracted
//
// Core message content composition: reply preview, system line, badges,
// author, rendered segments and small status chips.

import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import 'twitch_chat_message_author.dart';
import 'twitch_chat_message_badges.dart';
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
              TwitchChatMessageBadgeRow(
                badges: message.resolvedBadges,
                metrics: metrics,
                compact: compact,
              ),
              TwitchChatMessageAuthor(
                displayNameText: displayNameText,
                displayColor: displayColor,
                isAction: message.metadata.isAction,
                isFirstMessage: message.metadata.isFirstMessage,
                compact: compact,
                metrics: metrics,
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
