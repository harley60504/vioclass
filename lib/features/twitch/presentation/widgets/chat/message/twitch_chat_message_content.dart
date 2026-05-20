import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import 'twitch_chat_message_badges.dart';
import 'twitch_chat_message_chips.dart';
import 'twitch_chat_message_reply_preview.dart';
import 'twitch_chat_message_segments.dart';
import 'twitch_chat_message_timestamp.dart';
import 'twitch_chat_message_visual_metrics.dart';

class TwitchChatMessageContent extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService? officialEmotes;
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
    this.officialEmotes,
    required this.displayColor,
    required this.displayNameText,
    required this.showSystemMessage,
    required this.showTimestamp,
    required this.metrics,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (metadata.hasReply)
          TwitchChatMessageReplyPreview(
            message: message,
            metrics: metrics,
          ),
        if (showSystemMessage && metadata.isSystemLike)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              metadata.systemMessage!,
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
          child: Text.rich(
            TextSpan(children: _buildMessageSpans(context)),
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }

  List<InlineSpan> _buildMessageSpans(BuildContext context) {
    final spans = <InlineSpan>[];

    if (showTimestamp) {
      spans.add(TextSpan(
        text: '${formatTwitchChatMessageTime(message.receivedAt)} ',
        style: TextStyle(
          color: Colors.white38,
          fontSize: metrics.metaFontSize,
          fontWeight: FontWeight.w700,
          height: metrics.lineHeight,
        ),
      ));
    }

    for (final badge in message.resolvedBadges) {
      if (badge.image1x.trim().isEmpty) continue;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(right: 3),
          child: TwitchChatMessageBadge(
            badge: badge,
            metrics: metrics,
            compact: compact,
          ),
        ),
      ));
    }

    spans.add(TextSpan(
      text: displayNameText,
      style: TextStyle(
        color: displayColor,
        fontWeight: FontWeight.w900,
        fontSize: compact ? metrics.compactNameFontSize : metrics.nameFontSize,
        fontStyle: message.metadata.isAction ? FontStyle.italic : FontStyle.normal,
        height: metrics.lineHeight,
      ),
    ));

    if (message.metadata.isFirstMessage) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(left: 4, right: 3),
          child: TwitchChatFirstMessageChip(metrics: metrics),
        ),
      ));
    }

    spans.add(TextSpan(
      text: ': ',
      style: TextStyle(
        color: Colors.white54,
        fontWeight: FontWeight.w700,
        fontSize: metrics.messageFontSize,
        height: metrics.lineHeight,
      ),
    ));

    final segments = message.segments;
    if (segments.isEmpty) {
      spans.add(TextSpan(
        text: '〔空訊息〕',
        style: TextStyle(
          color: Colors.white38,
          fontSize: metrics.compactMessageFontSize,
          fontStyle: FontStyle.italic,
          height: metrics.lineHeight,
        ),
      ));
    } else {
      spans.addAll(
        buildTwitchChatMessageSegmentSpans(
          context: context,
          segments: segments,
          thirdPartyEmotes: thirdPartyEmotes,
          officialEmotes: officialEmotes,
          metrics: metrics,
        ),
      );
    }

    if (message.metadata.hasBits) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: TwitchChatBitsChip(
            bits: message.metadata.bitsAmount!,
            metrics: metrics,
          ),
        ),
      ));
    }

    if (message.metadata.isRewardRedemption) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: TwitchChatSmallChip(label: 'reward', metrics: metrics),
        ),
      ));
    }

    return spans;
  }
}
