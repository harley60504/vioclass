// PATCH VERSION: twitch_chat_message_segments_stage243_official_emote_fallback
//
// Text / link / Twitch emote / third-party emote / cheermote segment renderers
// for runtime chat messages.
//
// Stage 243:
// - Adds official Twitch emote text-token fallback. If an official emote arrives
//   as text because the IRC/recent/local path lacks a complete emotes tag,
//   lookupUsableByName() can still render it as an image. This fixes official
//   emotes such as corgiHHH / OverHip reverting to plain text after rebuilds.

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../../models/chat/twitch_chat_render_segment.dart';
import '../../../../models/emotes/twitch_official_emote.dart';
import '../../../../models/emotes/twitch_third_party_emote.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../shared/twitch_cached_image_layer.dart';
import 'twitch_chat_message_visual_metrics.dart';

final CacheManager _chatInlineEmoteCacheManager = CacheManager(
  Config(
    'twitchChatInlineEmoteImageCache',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 10000,
  ),
);

List<InlineSpan> buildTwitchChatMessageSegmentSpans({
  required BuildContext context,
  required List<TwitchChatRenderSegment> segments,
  required TwitchThirdPartyEmoteCacheService? thirdPartyEmotes,
  required TwitchOfficialEmoteCacheService? officialEmotes,
  required TwitchChatMessageVisualMetrics metrics,
}) {
  final spans = <InlineSpan>[];

  for (final segment in segments) {
    switch (segment.type) {
      case TwitchChatRenderSegmentType.text:
      case TwitchChatRenderSegmentType.emoji:
        _appendTextOrEmoteSpans(
          context: context,
          spans: spans,
          text: segment.content,
          thirdPartyEmotes: thirdPartyEmotes,
          officialEmotes: officialEmotes,
          metrics: metrics,
        );
        break;
      case TwitchChatRenderSegmentType.link:
        spans.add(TextSpan(
          text: segment.content,
          style: _linkTextStyle(metrics),
        ));
        break;
      case TwitchChatRenderSegmentType.twitchEmote:
        spans.add(_twitchEmoteSpan(segment: segment, metrics: metrics));
        break;
      case TwitchChatRenderSegmentType.cheermote:
        spans.add(TextSpan(
          text: segment.content,
          style: _cheermoteTextStyle(metrics),
        ));
        break;
    }
  }

  return spans;
}

void _appendTextOrEmoteSpans({
  required BuildContext context,
  required List<InlineSpan> spans,
  required String text,
  required TwitchThirdPartyEmoteCacheService? thirdPartyEmotes,
  required TwitchOfficialEmoteCacheService? officialEmotes,
  required TwitchChatMessageVisualMetrics metrics,
}) {
  if (text.isEmpty) return;

  final thirdPartyCache = thirdPartyEmotes;
  final officialCache = officialEmotes;
  final hasThirdParty = thirdPartyCache != null && thirdPartyCache.count > 0;
  final hasOfficial = officialCache != null && officialCache.usableEmotes.isNotEmpty;

  if (!hasThirdParty && !hasOfficial) {
    spans.add(TextSpan(text: text, style: _normalTextStyle(metrics)));
    return;
  }

  final parts = _splitPreservingWhitespace(text);
  if (parts.length == 1 && _lookupInlineEmote(
        token: parts.first,
        thirdPartyEmotes: thirdPartyCache,
        officialEmotes: officialCache,
      ) == null) {
    spans.add(TextSpan(text: text, style: _normalTextStyle(metrics)));
    return;
  }

  for (final part in parts) {
    final token = part.trim();
    final emote = token.isEmpty
        ? null
        : _lookupInlineEmote(
            token: part,
            thirdPartyEmotes: thirdPartyCache,
            officialEmotes: officialCache,
          );

    if (emote == null || token.isEmpty) {
      spans.add(TextSpan(text: part, style: _normalTextStyle(metrics)));
      continue;
    }

    if (emote is TwitchThirdPartyEmote) {
      _appendThirdPartyEmoteSpan(
        spans: spans,
        emote: emote,
        metrics: metrics,
      );
    } else if (emote is TwitchOfficialEmote) {
      _appendOfficialEmoteSpan(
        spans: spans,
        emote: emote,
        fallbackText: part,
        metrics: metrics,
      );
    }
  }
}

Object? _lookupInlineEmote({
  required String token,
  required TwitchThirdPartyEmoteCacheService? thirdPartyEmotes,
  required TwitchOfficialEmoteCacheService? officialEmotes,
}) {
  final clean = token.trim();
  if (clean.isEmpty) return null;

  final thirdParty = thirdPartyEmotes?.lookup(clean);
  if (thirdParty != null) return thirdParty;

  final official = officialEmotes?.lookupUsableByName(clean);
  if (official != null) return official;

  return null;
}

void _appendThirdPartyEmoteSpan({
  required List<InlineSpan> spans,
  required TwitchThirdPartyEmote emote,
  required TwitchChatMessageVisualMetrics metrics,
}) {
  final image = _ThirdPartyInlineEmoteImage(
    emote: emote,
    metrics: metrics,
  );

  if (emote.isZeroWidth && spans.isNotEmpty) {
    final previous = spans.last;
    if (previous is WidgetSpan) {
      spans[spans.length - 1] = WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: RepaintBoundary(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              previous.child,
              Positioned.fill(
                child: IgnorePointer(child: image),
              ),
            ],
          ),
        ),
      );
      return;
    }
  }

  spans.add(
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: RepaintBoundary(child: image),
      ),
    ),
  );
}

void _appendOfficialEmoteSpan({
  required List<InlineSpan> spans,
  required TwitchOfficialEmote emote,
  required String fallbackText,
  required TwitchChatMessageVisualMetrics metrics,
}) {
  final imageUrl = emote.imageUrl.trim().isNotEmpty
      ? emote.imageUrl.trim()
      : 'https://static-cdn.jtvnw.net/emoticons/v2/${emote.id}/default/dark/2.0';

  if (imageUrl.trim().isEmpty) {
    spans.add(TextSpan(text: fallbackText, style: _normalTextStyle(metrics)));
    return;
  }

  final size = metrics.emoteSize;
  spans.add(
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: RepaintBoundary(
          child: TwitchCachedImageLayer(
            imageUrl: imageUrl,
            width: size,
            height: size,
            cacheManager: _chatInlineEmoteCacheManager,
            fit: BoxFit.contain,
            fallbackColor: Colors.transparent,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: const SizedBox.shrink(),
            errorWidget: Text(
              fallbackText.isEmpty ? emote.name : fallbackText,
              style: _normalTextStyle(metrics),
            ),
          ),
        ),
      ),
    ),
  );
}

WidgetSpan _twitchEmoteSpan({
  required TwitchChatRenderSegment segment,
  required TwitchChatMessageVisualMetrics metrics,
}) {
  final imageUrl = segment.url;
  if (imageUrl == null || imageUrl.isEmpty) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Text(
        segment.content,
        style: _normalTextStyle(metrics),
      ),
    );
  }

  final size = metrics.emoteSize;
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: RepaintBoundary(
        child: TwitchCachedImageLayer(
          imageUrl: imageUrl,
          width: size,
          height: size,
          cacheManager: _chatInlineEmoteCacheManager,
          fit: BoxFit.contain,
          fallbackColor: Colors.transparent,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: const SizedBox.shrink(),
          errorWidget: Text(
            segment.content.isEmpty ? '[emote]' : segment.content,
            style: _normalTextStyle(metrics),
          ),
        ),
      ),
    ),
  );
}

class _ThirdPartyInlineEmoteImage extends StatelessWidget {
  final TwitchThirdPartyEmote emote;
  final TwitchChatMessageVisualMetrics metrics;

  const _ThirdPartyInlineEmoteImage({
    required this.emote,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final height = emote.isZeroWidth
        ? metrics.zeroWidthEmoteSize
        : metrics.thirdPartyEmoteSize;
    final width = (height * emote.aspectRatio)
        .clamp(height * 0.5, height * 4.0)
        .toDouble();

    return SizedBox(
      width: width,
      height: height,
      child: TwitchCachedImageLayer(
        imageUrl: emote.imageUrl,
        width: width,
        height: height,
        cacheManager: _chatInlineEmoteCacheManager,
        fit: BoxFit.contain,
        fallbackColor: Colors.transparent,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: const SizedBox.shrink(),
        errorWidget: Text(
          emote.name,
          style: _normalTextStyle(metrics),
        ),
      ),
    );
  }
}

TextStyle _normalTextStyle(TwitchChatMessageVisualMetrics metrics) {
  return TextStyle(
    color: Colors.white,
    fontSize: metrics.messageFontSize,
    height: metrics.lineHeight,
  );
}

TextStyle _linkTextStyle(TwitchChatMessageVisualMetrics metrics) {
  return TextStyle(
    color: const Color(0xFF8AB4F8),
    fontSize: metrics.messageFontSize,
    height: metrics.lineHeight,
    decoration: TextDecoration.underline,
  );
}

TextStyle _cheermoteTextStyle(TwitchChatMessageVisualMetrics metrics) {
  return TextStyle(
    color: const Color(0xFFFFC857),
    fontWeight: FontWeight.w900,
    fontSize: metrics.messageFontSize,
    height: metrics.lineHeight,
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

class TwitchChatMessageSegmentView extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService? officialEmotes;
  final TwitchChatMessageVisualMetrics metrics;

  const TwitchChatMessageSegmentView({
    super.key,
    required this.segment,
    this.thirdPartyEmotes,
    this.officialEmotes,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    switch (segment.type) {
      case TwitchChatRenderSegmentType.text:
        return _TextSegment(
          segment: segment,
          thirdPartyEmotes: thirdPartyEmotes,
          officialEmotes: officialEmotes,
          metrics: metrics,
        );
      case TwitchChatRenderSegmentType.link:
        return _LinkSegment(segment: segment, metrics: metrics);
      case TwitchChatRenderSegmentType.twitchEmote:
        return _EmoteSegment(segment: segment, metrics: metrics);
      case TwitchChatRenderSegmentType.emoji:
        return _TextSegment(
          segment: segment,
          thirdPartyEmotes: thirdPartyEmotes,
          officialEmotes: officialEmotes,
          metrics: metrics,
        );
      case TwitchChatRenderSegmentType.cheermote:
        return _CheermoteSegment(segment: segment, metrics: metrics);
    }
  }
}

class _TextSegment extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService? officialEmotes;
  final TwitchChatMessageVisualMetrics metrics;

  const _TextSegment({
    required this.segment,
    this.thirdPartyEmotes,
    this.officialEmotes,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    if (segment.content.isEmpty) return const SizedBox.shrink();

    final spans = <InlineSpan>[];
    _appendTextOrEmoteSpans(
      context: context,
      spans: spans,
      text: segment.content,
      thirdPartyEmotes: thirdPartyEmotes,
      officialEmotes: officialEmotes,
      metrics: metrics,
    );

    return Text.rich(TextSpan(children: spans));
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
        style: _normalTextStyle(metrics),
      );
    }

    return RepaintBoundary(
      child: _ThirdPartyInlineEmoteImage(
        emote: item,
        metrics: metrics,
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
      style: _linkTextStyle(metrics),
    );
  }
}

class _EmoteSegment extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final TwitchChatMessageVisualMetrics metrics;

  const _EmoteSegment({required this.segment, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(children: [_twitchEmoteSpan(segment: segment, metrics: metrics)]));
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
      style: _cheermoteTextStyle(metrics),
    );
  }
}