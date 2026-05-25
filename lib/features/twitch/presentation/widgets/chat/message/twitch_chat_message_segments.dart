// PATCH VERSION: twitch_chat_message_segments_inline_mentions

import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_render_segment.dart';
import '../../../../models/emotes/twitch_official_emote.dart';
import '../../../../models/emotes/twitch_third_party_emote.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../shared/twitch_emote_image.dart';
import 'twitch_chat_message_visual_metrics.dart';

List<InlineSpan> buildTwitchChatMessageSegmentSpans({
  required BuildContext context,
  required List<TwitchChatRenderSegment> segments,
  required TwitchThirdPartyEmoteCacheService? thirdPartyEmotes,
  required TwitchOfficialEmoteCacheService? officialEmotes,
  required TwitchChatMessageVisualMetrics metrics,
  bool animateEmotes = true,
}) {
  final resolver = _ChatInlineEmoteResolver(
    officialEmotes: officialEmotes,
    thirdPartyEmotes: thirdPartyEmotes,
  );

  final spans = <InlineSpan>[];

  for (final segment in segments) {
    switch (segment.type) {
      case TwitchChatRenderSegmentType.text:
      case TwitchChatRenderSegmentType.emoji:
        _appendTextWithInlineEmotes(
          spans: spans,
          text: segment.content,
          resolver: resolver,
          metrics: metrics,
          animateEmotes: animateEmotes,
        );
        break;
      case TwitchChatRenderSegmentType.link:
        spans.add(
          TextSpan(text: segment.content, style: _linkTextStyle(metrics)),
        );
        break;
      case TwitchChatRenderSegmentType.twitchEmote:
        _appendTwitchEmoteSegment(
          spans: spans,
          segment: segment,
          resolver: resolver,
          metrics: metrics,
          animateEmotes: animateEmotes,
        );
        break;
      case TwitchChatRenderSegmentType.cheermote:
        spans.add(
          TextSpan(text: segment.content, style: _cheermoteTextStyle(metrics)),
        );
        break;
    }
  }

  return spans;
}

void _appendTwitchEmoteSegment({
  required List<InlineSpan> spans,
  required TwitchChatRenderSegment segment,
  required _ChatInlineEmoteResolver resolver,
  required TwitchChatMessageVisualMetrics metrics,
  required bool animateEmotes,
}) {
  final byName = resolver.lookup(segment.content.trim());
  if (byName != null) {
    switch (byName.kind) {
      case _ResolvedInlineEmoteKind.official:
        _appendOfficialEmoteSpan(
          spans: spans,
          emote: byName.official!,
          fallbackText: segment.content,
          metrics: metrics,
          animateEmotes: animateEmotes,
        );
        return;
      case _ResolvedInlineEmoteKind.thirdParty:
        _appendThirdPartyEmoteSpan(
          spans: spans,
          emote: byName.thirdParty!,
          metrics: metrics,
          animateEmotes: animateEmotes,
        );
        return;
    }
  }

  spans.add(
    _twitchEmoteSpan(
      segment: segment,
      metrics: metrics,
      animateEmotes: animateEmotes,
    ),
  );
}

void _appendTextWithInlineEmotes({
  required List<InlineSpan> spans,
  required String text,
  required _ChatInlineEmoteResolver resolver,
  required TwitchChatMessageVisualMetrics metrics,
  required bool animateEmotes,
}) {
  if (text.isEmpty) return;

  if (!resolver.hasAnyEmotes) {
    _appendMentionAwarePlainText(spans: spans, text: text, metrics: metrics);
    return;
  }

  for (final token in _tokenizeChatText(text)) {
    if (token.text.isEmpty) continue;

    if (token.isWhitespace || !token.canLookup) {
      _appendMentionAwarePlainText(
        spans: spans,
        text: token.text,
        metrics: metrics,
      );
      continue;
    }

    final resolved = resolver.lookup(token.lookupText);
    if (resolved == null) {
      _appendMentionAwarePlainText(
        spans: spans,
        text: token.text,
        metrics: metrics,
      );
      continue;
    }

    if (token.leading.isNotEmpty) {
      _appendMentionAwarePlainText(
        spans: spans,
        text: token.leading,
        metrics: metrics,
      );
    }

    switch (resolved.kind) {
      case _ResolvedInlineEmoteKind.official:
        _appendOfficialEmoteSpan(
          spans: spans,
          emote: resolved.official!,
          fallbackText: token.lookupText,
          metrics: metrics,
          animateEmotes: animateEmotes,
        );
        break;
      case _ResolvedInlineEmoteKind.thirdParty:
        _appendThirdPartyEmoteSpan(
          spans: spans,
          emote: resolved.thirdParty!,
          metrics: metrics,
          animateEmotes: animateEmotes,
        );
        break;
    }

    if (token.trailing.isNotEmpty) {
      _appendMentionAwarePlainText(
        spans: spans,
        text: token.trailing,
        metrics: metrics,
      );
    }
  }
}

void _appendMentionAwarePlainText({
  required List<InlineSpan> spans,
  required String text,
  required TwitchChatMessageVisualMetrics metrics,
}) {
  if (text.isEmpty) return;

  var cursor = 0;
  for (final match in _mentionRegex.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(
        TextSpan(
          text: text.substring(cursor, match.start),
          style: _normalTextStyle(metrics),
        ),
      );
    }

    spans.add(
      TextSpan(text: match.group(0) ?? '', style: _mentionTextStyle(metrics)),
    );

    cursor = match.end;
  }

  if (cursor < text.length) {
    spans.add(
      TextSpan(text: text.substring(cursor), style: _normalTextStyle(metrics)),
    );
  }
}

class _ChatInlineEmoteResolver {
  final TwitchOfficialEmoteCacheService? officialEmotes;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;

  _ChatInlineEmoteResolver({
    required this.officialEmotes,
    required this.thirdPartyEmotes,
  });

  bool get hasAnyEmotes {
    return (officialEmotes?.visibleCount ?? 0) > 0 ||
        (thirdPartyEmotes?.hasAnyEmotes ?? false);
  }

  _ResolvedInlineEmote? lookup(String code) {
    final clean = code.trim();
    if (!_canMaybeBeEmoteCode(clean)) return null;

    final official = officialEmotes?.lookupRenderableByName(clean);
    if (official != null) return _ResolvedInlineEmote.official(official);

    final thirdParty = thirdPartyEmotes?.lookupLoose(clean);
    if (thirdParty != null) return _ResolvedInlineEmote.thirdParty(thirdParty);

    return null;
  }
}

class _ResolvedInlineEmote {
  final _ResolvedInlineEmoteKind kind;
  final TwitchOfficialEmote? official;
  final TwitchThirdPartyEmote? thirdParty;

  const _ResolvedInlineEmote._({
    required this.kind,
    this.official,
    this.thirdParty,
  });

  factory _ResolvedInlineEmote.official(TwitchOfficialEmote emote) {
    return _ResolvedInlineEmote._(
      kind: _ResolvedInlineEmoteKind.official,
      official: emote,
    );
  }

  factory _ResolvedInlineEmote.thirdParty(TwitchThirdPartyEmote emote) {
    return _ResolvedInlineEmote._(
      kind: _ResolvedInlineEmoteKind.thirdParty,
      thirdParty: emote,
    );
  }
}

enum _ResolvedInlineEmoteKind { official, thirdParty }

class _ChatTextToken {
  final String text;
  final bool isWhitespace;
  final String leading;
  final String lookupText;
  final String trailing;
  final bool canLookup;

  const _ChatTextToken({
    required this.text,
    required this.isWhitespace,
    this.leading = '',
    this.lookupText = '',
    this.trailing = '',
    this.canLookup = false,
  });
}

const int _tokenCacheLimit = 4096;
final RegExp _chatTokenRegex = RegExp(r'(\s+|\S+)');
final RegExp _mentionRegex = RegExp(r'@[A-Za-z0-9_]{3,25}');
final Map<String, List<_ChatTextToken>> _tokenCache =
    <String, List<_ChatTextToken>>{};

List<_ChatTextToken> _tokenizeChatText(String text) {
  final cached = _tokenCache.remove(text);
  if (cached != null) {
    _tokenCache[text] = cached;
    return cached;
  }

  final output = <_ChatTextToken>[];

  for (final match in _chatTokenRegex.allMatches(text)) {
    final raw = match.group(0) ?? '';
    if (raw.isEmpty) continue;

    if (raw.trim().isEmpty) {
      output.add(_ChatTextToken(text: raw, isWhitespace: true));
      continue;
    }

    final normalized = _normalizeLookupToken(raw);
    output.add(
      _ChatTextToken(
        text: raw,
        isWhitespace: false,
        leading: normalized.leading,
        lookupText: normalized.core,
        trailing: normalized.trailing,
        canLookup: _canMaybeBeEmoteCode(normalized.core),
      ),
    );
  }

  if (_tokenCache.length >= _tokenCacheLimit) {
    _tokenCache.remove(_tokenCache.keys.first);
  }
  final immutable = List<_ChatTextToken>.unmodifiable(output);
  _tokenCache[text] = immutable;
  return immutable;
}

bool _canMaybeBeEmoteCode(String value) {
  final clean = value.trim();
  if (clean.isEmpty || clean.length > 64) return false;

  var hasMeaningfulAscii = false;
  for (var i = 0; i < clean.length; i += 1) {
    final unit = clean.codeUnitAt(i);
    if (unit < 0x21 || unit > 0x7E) return false;
    if (_isAsciiLetterOrDigit(unit) || unit == 0x5F) {
      hasMeaningfulAscii = true;
    }
  }

  return hasMeaningfulAscii;
}

bool _isAsciiLetterOrDigit(int codeUnit) {
  return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A);
}

_NormalizedLookupToken _normalizeLookupToken(String token) {
  var start = 0;
  var end = token.length;

  while (start < end && _isLeadingPunctuation(token.codeUnitAt(start))) {
    start += 1;
  }

  while (end > start && _isTrailingPunctuation(token.codeUnitAt(end - 1))) {
    end -= 1;
  }

  return _NormalizedLookupToken(
    leading: token.substring(0, start),
    core: token.substring(start, end),
    trailing: token.substring(end),
  );
}

bool _isLeadingPunctuation(int codeUnit) {
  return codeUnit == 0x28 ||
      codeUnit == 0x5B ||
      codeUnit == 0x7B ||
      codeUnit == 0x3C ||
      codeUnit == 0x22 ||
      codeUnit == 0x27;
}

bool _isTrailingPunctuation(int codeUnit) {
  return codeUnit == 0x29 ||
      codeUnit == 0x5D ||
      codeUnit == 0x7D ||
      codeUnit == 0x3E ||
      codeUnit == 0x22 ||
      codeUnit == 0x27 ||
      codeUnit == 0x2E ||
      codeUnit == 0x2C ||
      codeUnit == 0x21 ||
      codeUnit == 0x3F ||
      codeUnit == 0x3A ||
      codeUnit == 0x3B;
}

class _NormalizedLookupToken {
  final String leading;
  final String core;
  final String trailing;

  const _NormalizedLookupToken({
    required this.leading,
    required this.core,
    required this.trailing,
  });
}

void _appendOfficialEmoteSpan({
  required List<InlineSpan> spans,
  required TwitchOfficialEmote emote,
  required String fallbackText,
  required TwitchChatMessageVisualMetrics metrics,
  required bool animateEmotes,
}) {
  final imageUrl = _officialImageUrl(emote, animateEmotes: animateEmotes);

  if (imageUrl.isEmpty) {
    _appendMentionAwarePlainText(
      spans: spans,
      text: fallbackText,
      metrics: metrics,
    );
    return;
  }

  final size = metrics.emoteSize;
  spans.add(
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: _ChatMenuStyleEmoteImage(
          id: emote.id,
          name: emote.name,
          imageUrl: imageUrl,
          staticImageUrl: TwitchEmoteImage.officialStaticEmoteUrl(emote.id),
          providerLabel: emote.sourceLabel,
          isOfficial: true,
          animate: animateEmotes,
          width: size,
          height: size,
          fallbackText: fallbackText.isEmpty ? emote.name : fallbackText,
          metrics: metrics,
        ),
      ),
    ),
  );
}

String _officialImageUrl(
  TwitchOfficialEmote emote, {
  required bool animateEmotes,
}) {
  if (!animateEmotes) {
    final staticUrl = TwitchEmoteImage.officialStaticEmoteUrl(emote.id);
    if (staticUrl.isNotEmpty) return staticUrl;
  }

  final direct = emote.imageUrl.trim();
  if (direct.isNotEmpty) return direct;

  final id = emote.id.trim();
  if (id.isEmpty) return '';

  return animateEmotes
      ? 'https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0'
      : TwitchEmoteImage.officialStaticEmoteUrl(id);
}

void _appendThirdPartyEmoteSpan({
  required List<InlineSpan> spans,
  required TwitchThirdPartyEmote emote,
  required TwitchChatMessageVisualMetrics metrics,
  required bool animateEmotes,
}) {
  final image = _ThirdPartyInlineEmoteImage(
    emote: emote,
    metrics: metrics,
    animate: animateEmotes,
  );

  if (emote.isZeroWidth && spans.isNotEmpty) {
    final previous = spans.last;
    if (previous is WidgetSpan) {
      spans[spans.length - 1] = WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            previous.child,
            Positioned.fill(child: IgnorePointer(child: image)),
          ],
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
        child: image,
      ),
    ),
  );
}

WidgetSpan _twitchEmoteSpan({
  required TwitchChatRenderSegment segment,
  required TwitchChatMessageVisualMetrics metrics,
  required bool animateEmotes,
}) {
  final imageUrl = segment.url;
  if (imageUrl == null || imageUrl.isEmpty) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Text(segment.content, style: _normalTextStyle(metrics)),
    );
  }

  final size = metrics.emoteSize;
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: _ChatMenuStyleEmoteImage(
        id: segment.emoteId ?? '',
        name: segment.content,
        imageUrl: imageUrl,
        staticImageUrl: TwitchEmoteImage.officialStaticEmoteUrl(
          segment.emoteId ?? '',
        ),
        providerLabel: 'Twitch',
        isOfficial: true,
        animate: animateEmotes,
        width: size,
        height: size,
        fallbackText: segment.content.isEmpty ? '[emote]' : segment.content,
        metrics: metrics,
      ),
    ),
  );
}

class _ThirdPartyInlineEmoteImage extends StatelessWidget {
  final TwitchThirdPartyEmote emote;
  final TwitchChatMessageVisualMetrics metrics;
  final bool animate;

  const _ThirdPartyInlineEmoteImage({
    required this.emote,
    required this.metrics,
    required this.animate,
  });

  @override
  Widget build(BuildContext context) {
    final height = emote.isZeroWidth
        ? metrics.zeroWidthEmoteSize
        : metrics.thirdPartyEmoteSize;
    final width = (height * emote.aspectRatio)
        .clamp(height * 0.5, height * 4.0)
        .toDouble();

    final shouldAnimate = animate || !emote.isAnimated;
    final url = shouldAnimate ? emote.imageUrl : emote.effectiveStaticImageUrl;

    return _ChatMenuStyleEmoteImage(
      id: emote.id,
      name: emote.name,
      imageUrl: url,
      staticImageUrl: emote.effectiveStaticImageUrl,
      providerLabel: emote.providerLabel,
      isOfficial: false,
      animate: shouldAnimate,
      width: width,
      height: height,
      fallbackText: emote.name,
      metrics: metrics,
    );
  }
}

class _ChatMenuStyleEmoteImage extends StatelessWidget {
  final String id;
  final String name;
  final String imageUrl;
  final String staticImageUrl;
  final String providerLabel;
  final bool isOfficial;
  final bool animate;
  final double width;
  final double height;
  final String fallbackText;
  final TwitchChatMessageVisualMetrics metrics;

  const _ChatMenuStyleEmoteImage({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.staticImageUrl,
    required this.providerLabel,
    required this.isOfficial,
    required this.animate,
    required this.width,
    required this.height,
    required this.fallbackText,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      return Text(fallbackText, style: _normalTextStyle(metrics));
    }

    return SizedBox(
      width: width,
      height: height,
      child: TwitchEmoteImage(
        id: id,
        name: name,
        imageUrl: url,
        staticImageUrl: staticImageUrl,
        providerLabel: providerLabel,
        isOfficial: isOfficial,
        preferStaticOfficial: !animate,
        forceStatic: !animate,
        width: width,
        height: height,
        memCacheWidth: 96,
        memCacheHeight: 96,
        placeholder: const SizedBox.shrink(),
        errorPlaceholder: Text(fallbackText, style: _normalTextStyle(metrics)),
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

TextStyle _mentionTextStyle(TwitchChatMessageVisualMetrics metrics) {
  return TextStyle(
    color: const Color(0xFFD6CCEA),
    fontSize: metrics.messageFontSize,
    height: metrics.lineHeight,
    fontWeight: FontWeight.w800,
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

class TwitchChatMessageSegmentView extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService? officialEmotes;
  final TwitchChatMessageVisualMetrics metrics;
  final bool animateEmotes;

  const TwitchChatMessageSegmentView({
    super.key,
    required this.segment,
    this.thirdPartyEmotes,
    this.officialEmotes,
    required this.metrics,
    this.animateEmotes = true,
  });

  @override
  Widget build(BuildContext context) {
    switch (segment.type) {
      case TwitchChatRenderSegmentType.text:
      case TwitchChatRenderSegmentType.emoji:
        final spans = <InlineSpan>[];
        _appendTextWithInlineEmotes(
          spans: spans,
          text: segment.content,
          resolver: _ChatInlineEmoteResolver(
            officialEmotes: officialEmotes,
            thirdPartyEmotes: thirdPartyEmotes,
          ),
          metrics: metrics,
          animateEmotes: animateEmotes,
        );
        return Text.rich(TextSpan(children: spans));
      case TwitchChatRenderSegmentType.link:
        return _LinkSegment(segment: segment, metrics: metrics);
      case TwitchChatRenderSegmentType.twitchEmote:
        return Text.rich(
          TextSpan(
            children: [
              _twitchEmoteSpan(
                segment: segment,
                metrics: metrics,
                animateEmotes: animateEmotes,
              ),
            ],
          ),
        );
      case TwitchChatRenderSegmentType.cheermote:
        return _CheermoteSegment(segment: segment, metrics: metrics);
    }
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

class _CheermoteSegment extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final TwitchChatMessageVisualMetrics metrics;

  const _CheermoteSegment({required this.segment, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Text(
      segment.content,
      textAlign: TextAlign.left,
      style: _cheermoteTextStyle(metrics),
    );
  }
}
