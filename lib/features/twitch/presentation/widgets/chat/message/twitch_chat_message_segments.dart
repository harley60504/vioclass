import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../../models/chat/twitch_chat_render_segment.dart';
import '../../../../models/emotes/twitch_official_emote.dart';
import '../../../../models/emotes/twitch_third_party_emote.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import 'twitch_chat_message_visual_metrics.dart';

final CacheManager _chatInlineEmoteCacheManager = CacheManager(
  Config(
    'twitchUnifiedEmotePickerImageCache',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 12000,
  ),
);

List<InlineSpan> buildTwitchChatMessageSegmentSpans({
  required BuildContext context,
  required List<TwitchChatRenderSegment> segments,
  required TwitchThirdPartyEmoteCacheService? thirdPartyEmotes,
  required TwitchOfficialEmoteCacheService? officialEmotes,
  required TwitchChatMessageVisualMetrics metrics,
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
        );
        break;
      case TwitchChatRenderSegmentType.link:
        spans.add(TextSpan(text: segment.content, style: _linkTextStyle(metrics)));
        break;
      case TwitchChatRenderSegmentType.twitchEmote:
        _appendTwitchEmoteSegment(
          spans: spans,
          segment: segment,
          resolver: resolver,
          metrics: metrics,
        );
        break;
      case TwitchChatRenderSegmentType.cheermote:
        spans.add(TextSpan(text: segment.content, style: _cheermoteTextStyle(metrics)));
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
        );
        return;
      case _ResolvedInlineEmoteKind.thirdParty:
        _appendThirdPartyEmoteSpan(
          spans: spans,
          emote: byName.thirdParty!,
          metrics: metrics,
        );
        return;
    }
  }

  spans.add(_twitchEmoteSpan(segment: segment, metrics: metrics));
}

void _appendTextWithInlineEmotes({
  required List<InlineSpan> spans,
  required String text,
  required _ChatInlineEmoteResolver resolver,
  required TwitchChatMessageVisualMetrics metrics,
}) {
  if (text.isEmpty) return;

  if (!resolver.hasAnyEmotes) {
    spans.add(TextSpan(text: text, style: _normalTextStyle(metrics)));
    return;
  }

  for (final token in _tokenizeChatText(text)) {
    if (token.text.isEmpty) continue;

    if (token.isWhitespace) {
      spans.add(TextSpan(text: token.text, style: _normalTextStyle(metrics)));
      continue;
    }

    final resolved = resolver.lookup(token.lookupText);
    if (resolved == null) {
      spans.add(TextSpan(text: token.text, style: _normalTextStyle(metrics)));
      continue;
    }

    if (token.leading.isNotEmpty) {
      spans.add(TextSpan(text: token.leading, style: _normalTextStyle(metrics)));
    }

    switch (resolved.kind) {
      case _ResolvedInlineEmoteKind.official:
        _appendOfficialEmoteSpan(
          spans: spans,
          emote: resolved.official!,
          fallbackText: token.lookupText,
          metrics: metrics,
        );
        break;
      case _ResolvedInlineEmoteKind.thirdParty:
        _appendThirdPartyEmoteSpan(
          spans: spans,
          emote: resolved.thirdParty!,
          metrics: metrics,
        );
        break;
    }

    if (token.trailing.isNotEmpty) {
      spans.add(TextSpan(text: token.trailing, style: _normalTextStyle(metrics)));
    }
  }
}

class _ChatInlineEmoteResolver {
  final TwitchOfficialEmoteCacheService? officialEmotes;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;

  late final Map<String, TwitchOfficialEmote> _officialByExact = _buildOfficialExact();
  late final Map<String, TwitchOfficialEmote> _officialByLower = _buildOfficialLower();
  late final Map<String, TwitchThirdPartyEmote> _thirdPartyByExact = _buildThirdPartyExact();
  late final Map<String, TwitchThirdPartyEmote> _thirdPartyByLower = _buildThirdPartyLower();

  _ChatInlineEmoteResolver({
    required this.officialEmotes,
    required this.thirdPartyEmotes,
  });

  bool get hasAnyEmotes {
    return _officialByExact.isNotEmpty || _thirdPartyByExact.isNotEmpty;
  }

  _ResolvedInlineEmote? lookup(String code) {
    final clean = code.trim();
    if (clean.isEmpty) return null;

    final official = _officialByExact[clean] ?? _officialByLower[clean.toLowerCase()];
    if (official != null) return _ResolvedInlineEmote.official(official);

    final thirdParty = _thirdPartyByExact[clean] ?? _thirdPartyByLower[clean.toLowerCase()];
    if (thirdParty != null) return _ResolvedInlineEmote.thirdParty(thirdParty);

    return null;
  }

  Map<String, TwitchOfficialEmote> _buildOfficialExact() {
    final source = officialEmotes;
    if (source == null) return const <String, TwitchOfficialEmote>{};

    final byName = <String, TwitchOfficialEmote>{};

    void add(TwitchOfficialEmote emote) {
      final name = emote.name.trim();
      final url = _officialImageUrl(emote);
      if (name.isEmpty || url.isEmpty) return;
      byName.putIfAbsent(name, () => emote.copyWith(imageUrl: url));
    }

    // Keep this order identical to the emote picker catalog behavior:
    // Recent/Favorite are first because they are the user's known-good entries,
    // then full Twitch catalog pages: channel, global, user/sub/unlocked.
    for (final emote in source.recentEmotes) add(emote);
    for (final emote in source.favoriteEmotes) add(emote);
    for (final emote in source.channelEmotes) add(emote);
    for (final emote in source.globalEmotes) add(emote);
    for (final emote in source.userEmotes) add(emote);
    for (final emote in source.lockedChannelEmotes) add(emote);
    for (final emote in source.renderableEmotes) add(emote);

    return Map<String, TwitchOfficialEmote>.unmodifiable(byName);
  }

  Map<String, TwitchOfficialEmote> _buildOfficialLower() {
    return Map<String, TwitchOfficialEmote>.unmodifiable(<String, TwitchOfficialEmote>{
      for (final entry in _officialByExact.entries)
        entry.key.toLowerCase(): entry.value,
    });
  }

  Map<String, TwitchThirdPartyEmote> _buildThirdPartyExact() {
    final source = thirdPartyEmotes;
    if (source == null) return const <String, TwitchThirdPartyEmote>{};

    final byName = <String, TwitchThirdPartyEmote>{};

    void add(TwitchThirdPartyEmote emote) {
      final name = emote.name.trim();
      if (name.isEmpty || emote.imageUrl.trim().isEmpty) return;
      byName.putIfAbsent(name, () => emote);
    }

    // Same source set as the emote menu, with Recent/Favorite first.
    for (final emote in source.recentEmotes) add(emote);
    for (final emote in source.favoriteEmotes) add(emote);
    for (final emote in source.emotes) add(emote);

    return Map<String, TwitchThirdPartyEmote>.unmodifiable(byName);
  }

  Map<String, TwitchThirdPartyEmote> _buildThirdPartyLower() {
    return Map<String, TwitchThirdPartyEmote>.unmodifiable(<String, TwitchThirdPartyEmote>{
      for (final entry in _thirdPartyByExact.entries)
        entry.key.toLowerCase(): entry.value,
    });
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

enum _ResolvedInlineEmoteKind {
  official,
  thirdParty,
}

class _ChatTextToken {
  final String text;
  final bool isWhitespace;
  final String leading;
  final String lookupText;
  final String trailing;

  const _ChatTextToken({
    required this.text,
    required this.isWhitespace,
    this.leading = '',
    this.lookupText = '',
    this.trailing = '',
  });
}

List<_ChatTextToken> _tokenizeChatText(String text) {
  final output = <_ChatTextToken>[];
  final regex = RegExp(r'(\s+|\S+)');

  for (final match in regex.allMatches(text)) {
    final raw = match.group(0) ?? '';
    if (raw.isEmpty) continue;

    if (raw.trim().isEmpty) {
      output.add(_ChatTextToken(text: raw, isWhitespace: true));
      continue;
    }

    final normalized = _normalizeLookupToken(raw);
    output.add(_ChatTextToken(
      text: raw,
      isWhitespace: false,
      leading: normalized.leading,
      lookupText: normalized.core,
      trailing: normalized.trailing,
    ));
  }

  return output;
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
}) {
  final imageUrl = _officialImageUrl(emote);

  if (imageUrl.isEmpty) {
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
          child: _ChatMenuStyleEmoteImage(
            imageUrl: imageUrl,
            cacheKey: _officialStableKey(emote),
            width: size,
            height: size,
            fallbackText: fallbackText.isEmpty ? emote.name : fallbackText,
            metrics: metrics,
          ),
        ),
      ),
    ),
  );
}

String _officialImageUrl(TwitchOfficialEmote emote) {
  final direct = emote.imageUrl.trim();
  if (direct.isNotEmpty) return direct;

  final id = emote.id.trim();
  if (id.isEmpty) return '';

  return 'https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0';
}

String _officialStableKey(TwitchOfficialEmote emote) {
  final id = emote.id.trim();
  if (id.isNotEmpty) return '${emote.sourceLabel}:$id';
  return '${emote.sourceLabel}:${emote.name.trim().toLowerCase()}';
}

String _thirdPartyStableKey(TwitchThirdPartyEmote emote) {
  final id = emote.id.trim();
  if (id.isNotEmpty) return '${emote.providerLabel}:$id';
  return '${emote.providerLabel}:${emote.name.trim().toLowerCase()}';
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
        child: _ChatMenuStyleEmoteImage(
          imageUrl: imageUrl,
          cacheKey: 'Twitch:$imageUrl',
          width: size,
          height: size,
          fallbackText: segment.content.isEmpty ? '[emote]' : segment.content,
          metrics: metrics,
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

    return _ChatMenuStyleEmoteImage(
      imageUrl: emote.imageUrl,
      cacheKey: _thirdPartyStableKey(emote),
      width: width,
      height: height,
      fallbackText: emote.name,
      metrics: metrics,
    );
  }
}

class _ChatMenuStyleEmoteImage extends StatelessWidget {
  final String imageUrl;
  final String cacheKey;
  final double width;
  final double height;
  final String fallbackText;
  final TwitchChatMessageVisualMetrics metrics;

  const _ChatMenuStyleEmoteImage({
    required this.imageUrl,
    required this.cacheKey,
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
      child: CachedNetworkImage(
        imageUrl: url,
        cacheKey: cacheKey.trim().isEmpty ? url : cacheKey,
        cacheManager: _chatInlineEmoteCacheManager,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.low,
        fadeInDuration: const Duration(milliseconds: 160),
        fadeOutDuration: const Duration(milliseconds: 120),
        useOldImageOnUrlChange: true,
        memCacheWidth: 144,
        memCacheHeight: 144,
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => Text(
          fallbackText,
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
        );
        return Text.rich(TextSpan(children: spans));
      case TwitchChatRenderSegmentType.link:
        return _LinkSegment(segment: segment, metrics: metrics);
      case TwitchChatRenderSegmentType.twitchEmote:
        return Text.rich(TextSpan(children: [
          _twitchEmoteSpan(segment: segment, metrics: metrics),
        ]));
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
