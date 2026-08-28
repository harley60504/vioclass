import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../links/twitch_chat_link_preview.dart';
import '../twitch_chat_text_style.dart';
import 'twitch_chat_message_content.dart';
import 'twitch_chat_message_special_style.dart';
import 'twitch_chat_message_timestamp.dart';
import 'twitch_chat_message_visual_metrics.dart';

class TwitchChatNormalMessageCard extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService? officialEmotes;
  final Color displayColor;
  final String displayNameText;
  final bool showTimestamp;
  final TwitchChatMessageVisualMetrics metrics;
  final bool animateEmotes;
  final VoidCallback? onOpenContext;

  const TwitchChatNormalMessageCard({
    super.key,
    required this.message,
    required this.thirdPartyEmotes,
    required this.officialEmotes,
    required this.displayColor,
    required this.displayNameText,
    required this.showTimestamp,
    required this.metrics,
    this.animateEmotes = true,
    required this.onOpenContext,
  });

  @override
  Widget build(BuildContext context) {
    final previewItems = extractTwitchChatPreviewUrls(message.message);

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
              border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 6, 9, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TwitchChatMessageContent(
                    message: message,
                    thirdPartyEmotes: thirdPartyEmotes,
                    officialEmotes: officialEmotes,
                    displayColor: displayColor,
                    displayNameText: displayNameText,
                    showSystemMessage: true,
                    showTimestamp: showTimestamp,
                    metrics: metrics,
                    animateEmotes: animateEmotes,
                  ),
                  TwitchChatLinkPreviewColumn(
                    items: previewItems,
                    fontScale: metrics.scale,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TwitchChatSpecialMessageCard extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService? officialEmotes;
  final Color displayColor;
  final String displayNameText;
  final TwitchChatSpecialMessageStyle style;
  final bool showTimestamp;
  final TwitchChatMessageVisualMetrics metrics;
  final bool animateEmotes;
  final VoidCallback? onOpenContext;

  const TwitchChatSpecialMessageCard({
    super.key,
    required this.message,
    required this.thirdPartyEmotes,
    required this.officialEmotes,
    required this.displayColor,
    required this.displayNameText,
    required this.style,
    required this.showTimestamp,
    required this.metrics,
    this.animateEmotes = true,
    required this.onOpenContext,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata;
    final bannerText = metadata.systemMessage?.trim();
    final hasVisibleChatText =
        message.message.trim().isNotEmpty || message.segments.isNotEmpty;
    final previewItems = extractTwitchChatPreviewUrls(message.message);

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
                              style: twitchChatTextStyle(
                                TextStyle(
                                  color: style.accentColor,
                                  fontSize: 11 * metrics.scale,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
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
                        const SizedBox(height: 6),
                        Text(
                          bannerText,
                          textAlign: TextAlign.left,
                          style: twitchChatTextStyle(
                            TextStyle(
                              color: Colors.white,
                              fontSize: metrics.compactMessageFontSize,
                              height: metrics.lineHeight,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                      if (hasVisibleChatText) ...[
                        if (bannerText != null && bannerText.isNotEmpty)
                          const SizedBox(height: 6),
                        TwitchChatMessageContent(
                          message: message,
                          thirdPartyEmotes: thirdPartyEmotes,
                          officialEmotes: officialEmotes,
                          displayColor: displayColor,
                          displayNameText: displayNameText,
                          showSystemMessage: false,
                          showTimestamp: false,
                          compact: true,
                          metrics: metrics,
                          animateEmotes: animateEmotes,
                        ),
                        TwitchChatLinkPreviewColumn(
                          items: previewItems,
                          fontScale: metrics.scale,
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
