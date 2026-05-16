// PATCH VERSION: twitch_cached_image_layer_stage109

import 'package:flutter/material.dart';

/// Lightweight shared image layer for Twitch UI.
///
/// This intentionally stays on top of Flutter's built-in [Image.network]
/// instead of adding a new dependency. The goal is the same direction as
/// PiliPlus' NetworkImgLayer: every high-frequency image should explicitly
/// control decode size, filter quality, fallback UI, and clipping behavior.
class TwitchCachedImageLayer extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final int? cacheWidth;
  final int? cacheHeight;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final BorderRadius? borderRadius;
  final bool circular;
  final bool gaplessPlayback;
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
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.borderRadius,
    this.circular = false,
    this.gaplessPlayback = true,
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
  })  : width = size,
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
      child = Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: filterQuality,
        gaplessPlayback: gaplessPlayback,
        errorBuilder: (_, __, ___) => errorWidget ?? _fallback(),
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
