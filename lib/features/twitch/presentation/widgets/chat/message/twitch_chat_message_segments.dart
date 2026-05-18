// PATCH VERSION: twitch_chat_message_segments_stage219r_lightweight_emote_images
//
// Text / link / Twitch emote / third-party emote / cheermote segment renderers
// for runtime chat messages.
//
// Stage 219R:
// - Removes Tooltip wrappers around inline emotes. Tooltips are useful on
//   desktop hover, but they add many overlay/semantics targets to a busy chat.
// - Disables resize-cache for inline emotes so chat uses a lighter image path
//   closer to the emote picker's Frosty-like rendering.

import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_render_segment.dart';
import '../../../../models/emotes/twitch_third_party_emote.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../shared/twitch_cached_image_layer.dart';
import 'twitch_chat_message_visual_metrics.dart';

class TwitchChatMessageSegmentView extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchChatMessageVisualMetrics metrics;

  const TwitchChatMessageSegmentView({
    super.key,
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

    return TwitchCachedImageLayer(
      imageUrl: item.imageUrl,
      width: width,
      height: height,
      useResizeCache: false,
      fit: BoxFit.contain,
      fallbackColor: Colors.transparent,
      errorWidget: Text(
        item.name,
        style: TextStyle(
          color: Colors.white,
          fontSize: metrics.messageFontSize,
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

    return TwitchCachedImageLayer(
      imageUrl: imageUrl,
      width: width,
      height: height,
      useResizeCache: false,
      fit: BoxFit.contain,
      fallbackColor: Colors.transparent,
      errorWidget: Text(
        segment.content.isEmpty ? '[emote]' : segment.content,
        style: TextStyle(
          color: Colors.white,
          fontSize: metrics.messageFontSize,
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