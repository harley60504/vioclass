import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'twitch_decoded_animated_emote_image.dart';

/// Shared Twitch / third-party emote image renderer.
///
/// Performance-safe behavior:
/// - Most emotes use the normal CachedNetworkImage path.
/// - Known problematic emotes can use the Dart decoded animated renderer directly.
/// - If the normal Flutter image pipeline fails, the same emote switches to the
///   Dart decoded renderer as a fallback.
class TwitchEmoteImage extends StatefulWidget {
  final String id;
  final String name;
  final String imageUrl;
  final String providerLabel;
  final bool isOfficial;
  final bool locked;
  final bool preferStaticOfficial;

  /// Kept for compatibility with existing call sites.
  /// Despite the old name, this controls decoded rendering for both official
  /// and third-party emotes.
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
    this.providerLabel = '',
    this.isOfficial = false,
    this.locked = false,
    this.preferStaticOfficial = true,
    this.tryDecodedAnimatedOfficial = true,
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
}

class _TwitchEmoteImageState extends State<TwitchEmoteImage> {
  static final CacheManager cacheManager = CacheManager(
    Config(
      'twitchSharedEmoteImageCache',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 16000,
    ),
  );

  int imageIndex = 0;
  bool fallbackQueued = false;
  bool forceDecodedAnimated = false;

  @override
  void didUpdateWidget(covariant TwitchEmoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.id != widget.id ||
        oldWidget.name != widget.name ||
        oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.providerLabel != widget.providerLabel ||
        oldWidget.isOfficial != widget.isOfficial ||
        oldWidget.preferStaticOfficial != widget.preferStaticOfficial ||
        oldWidget.tryDecodedAnimatedOfficial != widget.tryDecodedAnimatedOfficial ||
        oldWidget.decodedAnimatedOnlyForKnownProblemEmotes !=
            widget.decodedAnimatedOnlyForKnownProblemEmotes) {
      imageIndex = 0;
      fallbackQueued = false;
      forceDecodedAnimated = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = imageCandidates;
    if (imageIndex >= candidates.length) imageIndex = 0;

    final currentUrl = candidates.isEmpty ? '' : candidates[imageIndex];
    final fallback = widget.errorPlaceholder ??
        Icon(
          widget.locked ? Icons.lock_rounded : Icons.broken_image_rounded,
          color: Colors.white38,
          size: widget.height == null
              ? 22
              : (widget.height! * 0.72).clamp(14.0, 26.0),
        );

    if (widget.debug || isKnownProblemAnimatedEmote) {
      debugLog(
        'build name=${widget.name} id=${widget.id} provider=${widget.providerLabel} '
        'official=${widget.isOfficial} useDecoded=$shouldUseDecodedAnimated '
        'forced=$forceDecodedAnimated decodedUrl=$decodedAnimatedUrl currentUrl=$currentUrl',
      );
    }

    if (shouldUseDecodedAnimated) {
      return Opacity(
        opacity: widget.locked ? 0.62 : 1.0,
        child: TwitchDecodedAnimatedEmoteImage(
          imageUrl: decodedAnimatedUrl,
          cacheKey: '$stableKey:decoded:$decodedAnimatedUrl',
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          fallback: buildNetworkFallback(
            currentUrl: currentUrl,
            fallback: fallback,
            candidates: candidates,
            allowDecodedFallback: false,
          ),
          loading: widget.placeholder,
          debug: widget.debug || isKnownProblemAnimatedEmote,
          debugLabel: 'TwitchDecodedAnimatedEmoteImage:${widget.name}',
        ),
      );
    }

    return buildNetworkFallback(
      currentUrl: currentUrl,
      fallback: fallback,
      candidates: candidates,
      allowDecodedFallback: true,
    );
  }

  Widget buildNetworkFallback({
    required String currentUrl,
    required Widget fallback,
    required List<String> candidates,
    required bool allowDecodedFallback,
  }) {
    if (currentUrl.isEmpty) return fallback;

    final cacheKey = '$stableKey:$currentUrl';

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
        fadeInDuration: const Duration(milliseconds: 160),
        fadeOutDuration: const Duration(milliseconds: 120),
        useOldImageOnUrlChange: false,
        cacheManager: cacheManager,
        memCacheWidth: widget.memCacheWidth,
        memCacheHeight: widget.memCacheHeight,
        placeholder: (_, __) => widget.placeholder ?? const SizedBox.shrink(),
        errorWidget: (_, url, error) {
          handleImageError(
            failedUrl: url,
            error: error,
            candidates: candidates,
            allowDecodedFallback: allowDecodedFallback,
          );
          return fallback;
        },
      ),
    );
  }

  bool get shouldUseDecodedAnimated {
    if (!widget.tryDecodedAnimatedOfficial) return false;
    if (decodedAnimatedUrl.isEmpty) return false;

    if (isKnownProblemAnimatedEmote) return true;
    if (forceDecodedAnimated) return true;

    if (widget.decodedAnimatedOnlyForKnownProblemEmotes) return false;

    return true;
  }

  String get decodedAnimatedUrl {
    if (widget.isOfficial) return officialAnimatedEmoteUrl(widget.id);
    return widget.imageUrl.trim();
  }

  bool get canSwitchToDecodedFallback {
    return widget.tryDecodedAnimatedOfficial && decodedAnimatedUrl.isNotEmpty;
  }

  bool get isKnownProblemAnimatedEmote {
    final id = widget.id.trim();
    final name = widget.name.trim();
    return id == 'emotesv2_8a5801a43a8d4dce893b8c3f28978e3e' ||
        name == 'corgiHHH';
  }

  void handleImageError({
    required String failedUrl,
    required Object error,
    required List<String> candidates,
    required bool allowDecodedFallback,
  }) {
    if (widget.debug || isKnownProblemAnimatedEmote) {
      debugLog(
        'network error name=${widget.name} id=${widget.id} index=$imageIndex '
        'url=$failedUrl error=$error allowDecodedFallback=$allowDecodedFallback '
        'candidates=${candidates.join(' | ')}',
      );
    }

    if (allowDecodedFallback && !forceDecodedAnimated && canSwitchToDecodedFallback) {
      if (widget.debug || isKnownProblemAnimatedEmote) {
        debugLog(
          'switch to decoded fallback name=${widget.name} decodedUrl=$decodedAnimatedUrl',
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          forceDecodedAnimated = true;
        });
      });
      return;
    }

    if (fallbackQueued) return;

    final nextIndex = imageIndex + 1;
    if (nextIndex >= candidates.length) {
      if (widget.debug || isKnownProblemAnimatedEmote) {
        debugLog('network fallback exhausted name=${widget.name} id=${widget.id}');
      }
      return;
    }

    fallbackQueued = true;

    if (widget.debug || isKnownProblemAnimatedEmote) {
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
    if (!widget.isOfficial) return uniqueUrls(<String>[widget.imageUrl]);

    if (widget.preferStaticOfficial) {
      return uniqueUrls(<String>[
        officialStaticEmoteUrl(widget.id),
        widget.imageUrl,
        officialAnimatedEmoteUrl(widget.id),
        officialDefaultEmoteUrl(widget.id),
      ]);
    }

    return uniqueUrls(<String>[
      widget.imageUrl,
      officialAnimatedEmoteUrl(widget.id),
      officialDefaultEmoteUrl(widget.id),
      officialStaticEmoteUrl(widget.id),
    ]);
  }

  String get stableKey {
    final cleanId = widget.id.trim();
    final provider = widget.providerLabel.trim().isEmpty
        ? (widget.isOfficial ? 'Twitch' : 'emote')
        : widget.providerLabel.trim();

    return cleanId.isNotEmpty
        ? '$provider:$cleanId'
        : '$provider:${widget.name.trim().toLowerCase()}';
  }

  void debugLog(String message) {
    debugPrint('[${widget.debugTag}] $message', wrapWidth: 1024);
  }

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
