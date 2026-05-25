// PATCH VERSION: twitch_cached_image_layer_stage219ad_optional_cache_manager

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared image layer for Twitch UI.
///
/// This mirrors the direction of PiliPlus' NetworkImgLayer: high-frequency
/// images such as stream thumbnails, avatars, badges, emotes and channel point
/// icons should all explicitly control decode size, filter quality, fallback
/// UI, clipping behavior and cache behavior in one place.
class TwitchCachedImageLayer extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final int? cacheWidth;
  final int? cacheHeight;
  final BaseCacheManager? cacheManager;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final BorderRadius? borderRadius;
  final bool circular;
  final bool gaplessPlayback;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color fallbackColor;
  final IconData fallbackIcon;
  final Color fallbackIconColor;
  final double? fallbackIconSize;

  const TwitchCachedImageLayer({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.cacheManager,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.borderRadius,
    this.circular = false,
    this.gaplessPlayback = true,
    this.fadeInDuration = const Duration(milliseconds: 80),
    this.fadeOutDuration = const Duration(milliseconds: 80),
    this.placeholder,
    this.errorWidget,
    this.fallbackColor = const Color(0xFF111116),
    this.fallbackIcon = Icons.image_not_supported_rounded,
    this.fallbackIconColor = Colors.white38,
    this.fallbackIconSize,
  });

  const TwitchCachedImageLayer.avatar({
    super.key,
    required this.imageUrl,
    required double size,
    this.cacheWidth = 64,
    this.cacheHeight = 64,
    this.cacheManager,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.placeholder,
    this.errorWidget,
    this.fallbackColor = const Color(0x1AFFFFFF),
    this.fallbackIcon = Icons.person_rounded,
    this.fallbackIconColor = Colors.white38,
    this.fallbackIconSize,
    this.gaplessPlayback = true,
    this.fadeInDuration = const Duration(milliseconds: 80),
    this.fadeOutDuration = const Duration(milliseconds: 80),
  }) : width = size,
       height = size,
       circular = true,
       borderRadius = null;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final fallback = placeholder ?? _fallback();

    Widget child;
    if (url.isEmpty) {
      child = fallback;
    } else {
      child = CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,
        cacheManager: cacheManager,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        fadeInDuration: fadeInDuration,
        fadeOutDuration: fadeOutDuration,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => errorWidget ?? _fallback(),
      );
    }

    if (circular) {
      return ClipOval(child: child);
    }

    final radius = borderRadius;
    if (radius != null) {
      return ClipRRect(borderRadius: radius, child: child);
    }

    return child;
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      color: fallbackColor,
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        color: fallbackIconColor,
        size: fallbackIconSize ?? (width < height ? width : height) * 0.55,
      ),
    );
  }

  static int physicalWidthFor({
    required BuildContext context,
    required double logicalWidth,
    int minPhysicalWidth = 64,
    int maxPhysicalWidth = 512,
  }) {
    final safeLogicalWidth = logicalWidth.isFinite && logicalWidth > 0
        ? logicalWidth
        : minPhysicalWidth.toDouble();
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final physicalWidth = (safeLogicalWidth * devicePixelRatio).round();
    return physicalWidth.clamp(minPhysicalWidth, maxPhysicalWidth).toInt();
  }

  static int heightForAspectRatio({
    required int width,
    required double aspectRatio,
  }) {
    if (aspectRatio <= 0) return width;
    return (width / aspectRatio).round();
  }
}
