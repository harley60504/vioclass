import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../../theme/twitch_ui_tokens.dart';
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
      padding: const EdgeInsets.symmetric(
        horizontal: TwitchUiSpacing.space8,
        vertical: TwitchUiSpacing.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChatHoverSurface(
            onOpenContext: onOpenContext,
            child: TwitchChatMessageContent(
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
          ),
          TwitchChatLinkPreviewColumn(
            items: previewItems,
            fontScale: metrics.scale,
          ),
        ],
      ),
    );
  }
}

class _ChatHoverSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback? onOpenContext;

  const _ChatHoverSurface({required this.child, required this.onOpenContext});

  @override
  State<_ChatHoverSurface> createState() => _ChatHoverSurfaceState();
}

class _ChatHoverSurfaceState extends State<_ChatHoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpenContext,
        onLongPress: widget.onOpenContext,
        onSecondaryTap: widget.onOpenContext,
        child: AnimatedContainer(
          duration: TwitchUiMotion.fast,
          curve: TwitchUiMotion.standardCurve,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
          decoration: BoxDecoration(
            color: _hovered ? TwitchUiColors.hoverOverlay : Colors.transparent,
            borderRadius: BorderRadius.circular(TwitchUiRadius.sm),
            border: Border.all(
              color: _hovered
                  ? TwitchUiColors.borderSubtle
                  : Colors.transparent,
            ),
          ),
          child: widget.child,
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
      padding: const EdgeInsets.symmetric(
        horizontal: TwitchUiSpacing.space8,
        vertical: TwitchUiSpacing.space4,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpenContext,
        onLongPress: onOpenContext,
        onSecondaryTap: onOpenContext,
        child: Material(
          color: Color.alphaBlend(
            style.accentColor.withValues(alpha: 0.06),
            TwitchUiColors.surfaceCard,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TwitchUiRadius.md),
            side: BorderSide(color: style.borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 10, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: style.accentColor,
                          borderRadius: BorderRadius.circular(
                            TwitchUiRadius.pill,
                          ),
                        ),
                      ),
                      const SizedBox(width: TwitchUiSpacing.space8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  style.icon,
                                  size: 14,
                                  color: style.accentColor,
                                ),
                                const SizedBox(width: TwitchUiSpacing.space8),
                                Flexible(
                                  child: Text(
                                    metadata.specialLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: twitchChatTextStyle(
                                      TextStyle(
                                        color: style.accentColor,
                                        fontSize:
                                            TwitchUiFontSize.meta *
                                            metrics.scale,
                                        fontWeight: TwitchUiFontWeight.strong,
                                      ),
                                    ),
                                  ),
                                ),
                                if (showTimestamp) ...[
                                  const SizedBox(width: TwitchUiSpacing.space8),
                                  TwitchChatTimestampChip(
                                    time: message.receivedAt,
                                    metrics: metrics,
                                  ),
                                ],
                              ],
                            ),
                            if (bannerText != null &&
                                bannerText.isNotEmpty) ...[
                              const SizedBox(height: TwitchUiSpacing.space8),
                              Text(
                                bannerText,
                                style: twitchChatTextStyle(
                                  TextStyle(
                                    color: TwitchUiColors.textPrimary,
                                    fontSize: metrics.compactMessageFontSize,
                                    height: metrics.lineHeight,
                                    fontWeight: TwitchUiFontWeight.medium,
                                  ),
                                ),
                              ),
                            ],
                            if (hasVisibleChatText) ...[
                              if (bannerText != null && bannerText.isNotEmpty)
                                const SizedBox(height: TwitchUiSpacing.space8),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
