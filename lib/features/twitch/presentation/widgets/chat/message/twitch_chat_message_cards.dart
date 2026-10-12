import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../../models/chat/twitch_chat_message_metadata.dart';
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
  final VoidCallback? onOpenUser;
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
    this.onOpenUser,
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
              onOpenUser: onOpenUser,
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
  final VoidCallback? onOpenUser;
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
    this.onOpenUser,
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
    final bannerText = metadata.systemMessage?.trim() ?? '';
    final hasChat =
        message.message.trim().isNotEmpty || message.segments.isNotEmpty;
    final kind = metadata.specialKind;
    final compactEvent =
        kind == TwitchChatSpecialMessageKind.subGift ||
        kind == TwitchChatSpecialMessageKind.notice ||
        kind == TwitchChatSpecialMessageKind.clearChat ||
        kind == TwitchChatSpecialMessageKind.clearMsg ||
        kind == TwitchChatSpecialMessageKind.system;
    final subscription =
        kind == TwitchChatSpecialMessageKind.sub ||
        kind == TwitchChatSpecialMessageKind.resub ||
        kind == TwitchChatSpecialMessageKind.subMysteryGift ||
        kind == TwitchChatSpecialMessageKind.giftPaidUpgrade;
    final announcementColor = switch (message.source.tags['msg-param-color']) {
      'BLUE' => const Color(0xFF79B9F7),
      'GREEN' => const Color(0xFF76D5A3),
      'ORANGE' => const Color(0xFFE9B17B),
      'PURPLE' || 'PRIMARY' => const Color(0xFFC894F4),
      _ => style.accentColor,
    };
    final accent = subscription
        ? const Color(0xFFC894F4)
        : kind == TwitchChatSpecialMessageKind.announcement
        ? announcementColor
        : style.accentColor;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compactEvent)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                Icon(style.icon, size: 18 * metrics.scale, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    metadata.specialLabel,
                    style: twitchChatTextStyle(
                      TextStyle(
                        color: accent,
                        fontSize: 11 * metrics.scale,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (showTimestamp)
                  TwitchChatTimestampChip(
                    time: message.receivedAt,
                    metrics: metrics,
                  ),
              ],
            ),
          ),
        if (bannerText.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compactEvent) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    style.icon,
                    size: 14 * metrics.scale,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Text.rich(
                  _eventText(bannerText),
                  style: twitchChatTextStyle(
                    TextStyle(
                      color: TwitchUiColors.textPrimary,
                      fontSize: metrics.compactMessageFontSize,
                      height: metrics.lineHeight,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (hasChat) ...[
          if (bannerText.isNotEmpty) const SizedBox(height: 7),
          TwitchChatMessageContent(
            onOpenUser: onOpenUser,
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
            items: extractTwitchChatPreviewUrls(message.message),
            fontScale: metrics.scale,
          ),
        ],
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: compactEvent ? 3 : 5,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpenContext,
        onLongPress: onOpenContext,
        onSecondaryTap: onOpenContext,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compactEvent ? 7 : 12),
          decoration: BoxDecoration(
            gradient: compactEvent
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.13),
                      const Color(0xFF1A1A21).withValues(alpha: 0.6),
                      accent.withValues(alpha: 0.035),
                    ],
                  ),
            borderRadius: BorderRadius.circular(10),
            border: compactEvent
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: content,
        ),
      ),
    );
  }

  TextSpan _eventText(String text) {
    final actor = message.displayName.isNotEmpty
        ? message.displayName
        : message.userLogin;
    final index = actor.isEmpty
        ? -1
        : text.toLowerCase().indexOf(actor.toLowerCase());
    if (index < 0) return TextSpan(text: text);
    return TextSpan(
      children: [
        TextSpan(text: text.substring(0, index)),
        TextSpan(
          text: text.substring(index, index + actor.length),
          style: TextStyle(color: displayColor, fontWeight: FontWeight.w600),
        ),
        TextSpan(text: text.substring(index + actor.length)),
      ],
    );
  }
}
