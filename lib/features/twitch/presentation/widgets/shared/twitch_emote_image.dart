// PATCH VERSION: twitch_emote_image_stage233h_frosty_like_no_fade

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../services/chat/twitch_emote_image_cache_manager.dart';

/// Shared Twitch / third-party emote image renderer.
///
/// The default path intentionally stays close to Frosty's behavior:
/// - one stable animated URL for normal chat rendering,
/// - shared CachedNetworkImage cache manager,
/// - no image fade in chat-sized emotes,
/// - static URL only when a policy explicitly asks for it.
class TwitchEmoteImage extends StatefulWidget {
  final String id;
  final String name;
  final String imageUrl;
  final String staticImageUrl;
  final String providerLabel;
  final bool isOfficial;
  final bool locked;
  final bool preferStaticOfficial;
  final bool forceStatic;

  /// Kept only for compatibility with existing call sites.
  /// This stable version intentionally ignores decoded rendering.
  final bool tryDecodedAnimatedOfficial;
  final bool decodedAnimatedOnlyForKnownProblemEmotes;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final FilterQuality filterQuality;
  final Widget? placeholder;
  final Widget? errorPlaceholder;
  final bool debug;
  final String debugTag;

  const TwitchEmoteImage({
    super.key,
    required this.id,
    required this.name,
    required this.imageUrl,
    this.staticImageUrl = '',
    this.providerLabel = '',
    this.isOfficial = false,
    this.locked = false,
    this.preferStaticOfficial = false,
    this.forceStatic = false,
    this.tryDecodedAnimatedOfficial = false,
    this.decodedAnimatedOnlyForKnownProblemEmotes = true,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.filterQuality = FilterQuality.low,
    this.placeholder,
    this.errorPlaceholder,
    this.debug = false,
    this.debugTag = 'TwitchEmoteImage',
  });

  @override
  State<TwitchEmoteImage> createState() => _TwitchEmoteImageState();

  static String officialAnimatedEmoteUrl(String id) {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return '';
    return 'https://static-cdn.jtvnw.net/emoticons/v2/$cleanId/animated/dark/2.0';
  }

  static String officialDefaultEmoteUrl(String id) {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return '';
    return 'https://static-cdn.jtvnw.net/emoticons/v2/$cleanId/default/dark/2.0';
  }

  static String officialStaticEmoteUrl(String id) {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return '';
    return 'https://static-cdn.jtvnw.net/emoticons/v2/$cleanId/static/dark/2.0';
  }
}

class _TwitchEmoteImageState extends State<TwitchEmoteImage> {
  int imageIndex = 0;
  bool fallbackQueued = false;

  @override
  void didUpdateWidget(covariant TwitchEmoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.id != widget.id ||
        oldWidget.name != widget.name ||
        oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.staticImageUrl != widget.staticImageUrl ||
        oldWidget.providerLabel != widget.providerLabel ||
        oldWidget.isOfficial != widget.isOfficial ||
        oldWidget.preferStaticOfficial != widget.preferStaticOfficial ||
        oldWidget.forceStatic != widget.forceStatic) {
      imageIndex = 0;
      fallbackQueued = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = imageCandidates;
    if (imageIndex >= candidates.length) imageIndex = 0;

    final currentUrl = candidates.isEmpty ? '' : candidates[imageIndex];
    final fallback =
        widget.errorPlaceholder ??
        Icon(
          widget.locked ? Icons.lock_rounded : Icons.broken_image_rounded,
          color: Colors.white38,
          size: widget.height == null
              ? 22
              : (widget.height! * 0.72).clamp(14.0, 26.0),
        );

    if (widget.debug) {
      debugLog(
        'network build name=${widget.name} id=${widget.id} '
        'provider=${widget.providerLabel} official=${widget.isOfficial} '
        'forceStatic=${widget.forceStatic} index=$imageIndex '
        'currentUrl=$currentUrl candidates=${candidates.join(' | ')}',
      );
    }

    if (currentUrl.isEmpty) return fallback;

    final cacheKey = TwitchEmoteImageCacheManager.buildCacheKey(
      providerLabel: widget.providerLabel.trim().isEmpty
          ? (widget.isOfficial ? 'Twitch' : 'emote')
          : widget.providerLabel,
      id: widget.id,
      name: widget.name,
      staticVariant: widget.forceStatic,
      url: currentUrl,
    );

    return Opacity(
      opacity: widget.locked ? 0.62 : 1.0,
      child: CachedNetworkImage(
        key: ValueKey<String>(cacheKey),
        imageUrl: currentUrl,
        cacheKey: cacheKey,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        filterQuality: widget.filterQuality,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        useOldImageOnUrlChange: !widget.forceStatic,
        cacheManager: TwitchEmoteImageCacheManager.instance,
        memCacheWidth: widget.memCacheWidth,
        memCacheHeight: widget.memCacheHeight,
        placeholder: (_, _) => widget.placeholder ?? const SizedBox.shrink(),
        errorWidget: (_, url, error) {
          handleImageError(
            failedUrl: url,
            error: error,
            candidates: candidates,
          );
          return fallback;
        },
      ),
    );
  }

  void handleImageError({
    required String failedUrl,
    required Object error,
    required List<String> candidates,
  }) {
    if (widget.debug) {
      debugLog(
        'network error name=${widget.name} id=${widget.id} index=$imageIndex '
        'url=$failedUrl error=$error candidates=${candidates.join(' | ')}',
      );
    }

    if (fallbackQueued) return;

    final nextIndex = imageIndex + 1;
    if (nextIndex >= candidates.length) {
      if (widget.debug) {
        debugLog(
          'network fallback exhausted name=${widget.name} id=${widget.id}',
        );
      }
      return;
    }

    fallbackQueued = true;

    if (widget.debug) {
      debugLog(
        'network fallback queued name=${widget.name} from=$failedUrl to=${candidates[nextIndex]}',
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        imageIndex = nextIndex;
        fallbackQueued = false;
      });
    });
  }

  List<String> get imageCandidates {
    final staticUrl = widget.staticImageUrl.trim();

    if (!widget.isOfficial) {
      if (widget.forceStatic) {
        return uniqueUrls(<String>[staticUrl, widget.imageUrl]);
      }
      return uniqueUrls(<String>[widget.imageUrl, staticUrl]);
    }

    if (widget.forceStatic || widget.preferStaticOfficial) {
      return uniqueUrls(<String>[
        staticUrl,
        TwitchEmoteImage.officialStaticEmoteUrl(widget.id),
        widget.imageUrl,
        TwitchEmoteImage.officialDefaultEmoteUrl(widget.id),
      ]);
    }

    return uniqueUrls(<String>[
      widget.imageUrl,
      TwitchEmoteImage.officialAnimatedEmoteUrl(widget.id),
      TwitchEmoteImage.officialDefaultEmoteUrl(widget.id),
      staticUrl,
      TwitchEmoteImage.officialStaticEmoteUrl(widget.id),
    ]);
  }

  void debugLog(String message) {
    debugPrint('[${widget.debugTag}] $message', wrapWidth: 1024);
  }

  static List<String> uniqueUrls(Iterable<String> urls) {
    final seen = <String>{};
    final result = <String>[];

    for (final url in urls) {
      final clean = url.trim();
      if (clean.isEmpty || seen.contains(clean)) continue;
      seen.add(clean);
      result.add(clean);
    }

    return result;
  }
}
