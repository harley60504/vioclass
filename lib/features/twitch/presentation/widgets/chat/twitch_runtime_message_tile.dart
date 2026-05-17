// PATCH VERSION: twitch_runtime_message_tile_stage154_extracted_helpers

import 'package:flutter/material.dart';

import '../../../models/chat/twitch_chat_render_segment.dart';
import '../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../models/emotes/twitch_third_party_emote.dart';
import '../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../shared/twitch_cached_image_layer.dart';
import 'message/twitch_chat_message_chips.dart';
import 'message/twitch_chat_message_reply_preview.dart';
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
                  _MessageSegmentView(
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

class _MessageSegmentView extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchChatMessageVisualMetrics metrics;

  const _MessageSegmentView({
    required this.segment,
    this.thirdPartyEmotes,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    switch (segment.type) {
      case TwitchChatRenderSegmentType.text:
        return _TextSegment(
          segment: segment,
          thirdPartyEmotes: thirdPartyEmotes,
          metrics: metrics,
        );
      case TwitchChatRenderSegmentType.link:
        return _LinkSegment(segment: segment, metrics: metrics);
      case TwitchChatRenderSegmentType.twitchEmote:
        return _EmoteSegment(segment: segment, metrics: metrics);
      case TwitchChatRenderSegmentType.emoji:
        return _TextSegment(segment: segment, metrics: metrics);
      case TwitchChatRenderSegmentType.cheermote:
        return _CheermoteSegment(segment: segment, metrics: metrics);
    }
  }
}

class _TextSegment extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchChatMessageVisualMetrics metrics;

  const _TextSegment({
    required this.segment,
    this.thirdPartyEmotes,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    if (segment.content.isEmpty) return const SizedBox.shrink();

    final cache = thirdPartyEmotes;
    if (cache == null || cache.count == 0) {
      return Text(
        segment.content,
        textAlign: TextAlign.left,
        style: TextStyle(
          color: Colors.white,
          fontSize: metrics.messageFontSize,
          height: metrics.lineHeight,
        ),
      );
    }

    final parts = _splitPreservingWhitespace(segment.content);
    if (parts.length == 1 && cache.lookup(parts.first) == null) {
      return Text(
        segment.content,
        textAlign: TextAlign.left,
        style: TextStyle(
          color: Colors.white,
          fontSize: metrics.messageFontSize,
          height: metrics.lineHeight,
        ),
      );
    }

    return Wrap(
      spacing: 0,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.start,
      children: [
        for (final part in parts)
          _TextOrThirdPartyEmote(
            text: part,
            emote: cache.lookup(part),
            metrics: metrics,
          ),
      ],
    );
  }

  List<String> _splitPreservingWhitespace(String text) {
    final output = <String>[];
    final regex = RegExp(r'(\s+|\S+)');

    for (final match in regex.allMatches(text)) {
      final value = match.group(0);
      if (value != null && value.isNotEmpty) output.add(value);
    }

    return output;
  }
}

class _TextOrThirdPartyEmote extends StatelessWidget {
  final String text;
  final TwitchThirdPartyEmote? emote;
  final TwitchChatMessageVisualMetrics metrics;

  const _TextOrThirdPartyEmote({
    required this.text,
    required this.emote,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final item = emote;
    if (item == null || text.trim().isEmpty) {
      return Text(
        text,
        textAlign: TextAlign.left,
        style: TextStyle(
          color: Colors.white,
          fontSize: metrics.messageFontSize,
          height: metrics.lineHeight,
        ),
      );
    }

    final height = item.isZeroWidth
        ? metrics.zeroWidthEmoteSize
        : metrics.thirdPartyEmoteSize;
    final width = (height * item.aspectRatio)
        .clamp(height * 0.5, height * 4.0)
        .toDouble();
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (width * devicePixelRatio).round().clamp(32, 160).toInt();
    final cacheHeight = (height * devicePixelRatio).round().clamp(32, 96).toInt();

    return Tooltip(
      message: '${item.name} · ${item.providerLabel}',
      child: TwitchCachedImageLayer(
        imageUrl: item.imageUrl,
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        fit: BoxFit.contain,
        fallbackColor: Colors.transparent,
        errorWidget: Text(
          item.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: metrics.messageFontSize,
          ),
        ),
      ),
    );
  }
}

class _LinkSegment extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final TwitchChatMessageVisualMetrics metrics;

  const _LinkSegment({required this.segment, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Text(
      segment.content,
      textAlign: TextAlign.left,
      style: TextStyle(
        color: const Color(0xFF8AB4F8),
        fontSize: metrics.messageFontSize,
        height: metrics.lineHeight,
        decoration: TextDecoration.underline,
      ),
    );
  }
}

class _EmoteSegment extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final TwitchChatMessageVisualMetrics metrics;

  const _EmoteSegment({required this.segment, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final imageUrl = segment.url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Text(
        segment.content,
        style: TextStyle(
          color: Colors.white,
          fontSize: metrics.messageFontSize,
          height: metrics.lineHeight,
        ),
      );
    }

    final height = metrics.emoteSize;
    final width = height;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (height * devicePixelRatio)
        .round()
        .clamp(32, 96)
        .toInt();

    return Tooltip(
      message: segment.content.isEmpty
          ? (segment.emoteId == null
              ? 'Twitch emote'
              : 'Twitch emote ${segment.emoteId}')
          : segment.content,
      child: TwitchCachedImageLayer(
        imageUrl: imageUrl,
        width: width,
        height: height,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        fit: BoxFit.contain,
        fallbackColor: Colors.transparent,
        errorWidget: Text(
          segment.content.isEmpty ? '[emote]' : segment.content,
          style: TextStyle(
            color: Colors.white,
            fontSize: metrics.messageFontSize,
          ),
        ),
      ),
    );
  }
}

class _CheermoteSegment extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final TwitchChatMessageVisualMetrics metrics;

  const _CheermoteSegment({required this.segment, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Text(
      segment.content,
      style: TextStyle(
        color: const Color(0xFFFFC857),
        fontWeight: FontWeight.w900,
        fontSize: metrics.messageFontSize,
      ),
    );
  }
}
