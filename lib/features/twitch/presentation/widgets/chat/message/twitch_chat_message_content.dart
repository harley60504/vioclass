import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_render_segment.dart';
import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import 'twitch_chat_message_badges.dart';
import 'twitch_chat_message_chips.dart';
import 'twitch_chat_message_reply_preview.dart';
import 'twitch_chat_message_segments.dart';
import 'twitch_chat_message_timestamp.dart';
import 'twitch_chat_message_visual_metrics.dart';

class TwitchChatMessageContent extends StatefulWidget {
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
  State<TwitchChatMessageContent> createState() =>
      _TwitchChatMessageContentState();
}

class _TwitchChatMessageContentState extends State<TwitchChatMessageContent> {
  List<InlineSpan>? _cachedMessageSpans;
  int _cachedSignature = 0;

  @override
  void didUpdateWidget(covariant TwitchChatMessageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signature = _signatureFor(widget);
    if (signature != _cachedSignature) {
      _cachedMessageSpans = null;
      _cachedSignature = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.message.metadata;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (metadata.hasReply)
          TwitchChatMessageReplyPreview(
            message: widget.message,
            metrics: widget.metrics,
          ),
        if (widget.showSystemMessage && metadata.isSystemLike)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              metadata.systemMessage!,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: const Color(0xFFFFC857),
                fontSize: widget.metrics.compactMessageFontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(children: _messageSpans(context)),
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }

  List<InlineSpan> _messageSpans(BuildContext context) {
    final signature = _signatureFor(widget);
    final cached = _cachedMessageSpans;
    if (cached != null && signature == _cachedSignature) return cached;

    final spans = _buildMessageSpans(context);
    _cachedMessageSpans = spans;
    _cachedSignature = signature;
    return spans;
  }

  int _signatureFor(TwitchChatMessageContent widget) {
    final thirdPartyCache = widget.thirdPartyEmotes;
    final officialCache = widget.officialEmotes;
    return Object.hashAll(<Object?>[
      widget.message,
      widget.message.id,
      widget.message.segments.length,
      widget.message.resolvedBadges.length,
      widget.message.metadata.isFirstMessage,
      widget.message.metadata.hasBits,
      widget.message.metadata.isRewardRedemption,
      widget.displayColor.value,
      widget.displayNameText,
      widget.showTimestamp,
      widget.compact,
      widget.metrics.scale,
      thirdPartyCache,
      thirdPartyCache?.count ?? 0,
      thirdPartyCache?.recentCount ?? 0,
      thirdPartyCache?.favoriteCount ?? 0,
      Object.hashAll(
        thirdPartyCache?.recentEmotes.map((e) => '${e.provider.name}:${e.id}:${e.name}:${e.imageUrl}') ??
            const <String>[],
      ),
      officialCache,
      officialCache?.renderableEmotes.length ?? 0,
      officialCache?.recentCount ?? 0,
      officialCache?.favoriteCount ?? 0,
      Object.hashAll(
        officialCache?.recentEmotes.map((e) => '${e.source.name}:${e.id}:${e.name}:${e.imageUrl}') ??
            const <String>[],
      ),
    ]);
  }

  List<InlineSpan> _buildMessageSpans(BuildContext context) {
    final message = widget.message;
    final metrics = widget.metrics;
    final spans = <InlineSpan>[];

    if (widget.showTimestamp) {
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
            compact: widget.compact,
          ),
        ),
      ));
    }

    spans.add(TextSpan(
      text: widget.displayNameText,
      style: TextStyle(
        color: widget.displayColor,
        fontWeight: FontWeight.w900,
        fontSize: widget.compact
            ? metrics.compactNameFontSize
            : metrics.nameFontSize,
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
          thirdPartyEmotes: widget.thirdPartyEmotes,
          officialEmotes: widget.officialEmotes,
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
