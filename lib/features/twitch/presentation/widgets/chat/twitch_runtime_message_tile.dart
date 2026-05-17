// PATCH VERSION: twitch_runtime_message_tile_stage156_segments_extracted

import 'package:flutter/material.dart';

import '../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../shared/twitch_cached_image_layer.dart';
import 'message/twitch_chat_message_chips.dart';
import 'message/twitch_chat_message_reply_preview.dart';
import 'message/twitch_chat_message_segments.dart';
import 'message/twitch_chat_message_special_style.dart';
import 'message/twitch_chat_message_timestamp.dart';
import 'message/twitch_chat_message_user_style.dart';
import 'message/twitch_chat_message_visual_metrics.dart';

class TwitchRuntimeMessageTile extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final bool showTimestamp;
  final double fontScale;
  final bool compact;
  final VoidCallback? onOpenContext;

  const TwitchRuntimeMessageTile({
    super.key,
    required this.message,
    this.thirdPartyEmotes,
    this.showTimestamp = false,
    this.fontScale = 1.0,
    this.compact = false,
    this.onOpenContext,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = parseTwitchChatUserColorOrFallback(
      color: message.color,
      login: message.userLogin,
    );
    final displayNameText = formatTwitchChatDisplayName(message);
    final metrics = TwitchChatMessageVisualMetrics(fontScale, compact: compact);
    final style = TwitchChatSpecialMessageStyle.fromMetadata(message.metadata);

    if (style != null) {
      return _SpecialMessageCard(
        message: message,
        thirdPartyEmotes: thirdPartyEmotes,
        displayColor: displayColor,
        displayNameText: displayNameText,
        style: style,
        showTimestamp: showTimestamp,
        metrics: metrics,
        onOpenContext: onOpenContext,
      );
    }

    return _NormalMessageCard(
      message: message,
      thirdPartyEmotes: thirdPartyEmotes,
      displayColor: displayColor,
      displayNameText: displayNameText,
      showTimestamp: showTimestamp,
      metrics: metrics,
      onOpenContext: onOpenContext,
    );
  }
}

class _NormalMessageCard extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final Color displayColor;
  final String displayNameText;
  final bool showTimestamp;
  final TwitchChatMessageVisualMetrics metrics;
  final VoidCallback? onOpenContext;

  const _NormalMessageCard({
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpenContext,
        onLongPress: onOpenContext,
        onSecondaryTap: onOpenContext,
        child: SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B23),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.075)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 6, 9, 7),
              child: _MessageContent(
                message: message,
                thirdPartyEmotes: thirdPartyEmotes,
                displayColor: displayColor,
                displayNameText: displayNameText,
                showSystemMessage: true,
                showTimestamp: showTimestamp,
                metrics: metrics,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecialMessageCard extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final Color displayColor;
  final String displayNameText;
  final TwitchChatSpecialMessageStyle style;
  final bool showTimestamp;
  final TwitchChatMessageVisualMetrics metrics;
  final VoidCallback? onOpenContext;

  const _SpecialMessageCard({
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpenContext,
        onLongPress: onOpenContext,
        onSecondaryTap: onOpenContext,
        child: SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: style.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: style.borderColor),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: style.accentColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 9, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(style.icon, size: 15, color: style.accentColor),
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
                          if (metadata.msgId != null &&
                              metadata.msgId!.trim().isNotEmpty) ...[
                            const SizedBox(width: 6),
                            TwitchChatSmallChip(
                              label: metadata.msgId!,
                              metrics: metrics,
                            ),
                          ],
                        ],
                      ),
                      if (bannerText != null && bannerText.isNotEmpty) ...[
                        const SizedBox(height: 6),
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
                          const SizedBox(height: 6),
                        _MessageContent(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final Color displayColor;
  final String displayNameText;
  final bool showSystemMessage;
  final bool showTimestamp;
  final bool compact;
  final TwitchChatMessageVisualMetrics metrics;

  const _MessageContent({
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
