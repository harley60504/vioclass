import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class TwitchGlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final double blurSigma;
  final List<BoxShadow> boxShadow;
  final Clip clipBehavior;

  const TwitchGlassSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.backgroundColor = const Color(0x6618181B),
    this.borderColor = const Color(0x1FFFFFFF),
    this.blurSigma = 14,
    this.boxShadow = const <BoxShadow>[],
    this.clipBehavior = Clip.antiAlias,
  });

  bool get _useLowCostMobileGlass {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // BackdropFilter blur over a video surface is expensive on mobile/tablet.
    // It forces extra compositing/raster work whenever the video frame changes.
    // Keep the glass look on desktop, but use a plain translucent surface on
    // Android/iOS to avoid the FPS drop when player controls are visible.
    final lowCostMobile = _useLowCostMobileGlass;
    final effectiveBlurSigma = lowCostMobile ? 0.0 : blurSigma;
    final effectiveBoxShadow = lowCostMobile ? const <BoxShadow>[] : boxShadow;
    final effectiveBackgroundColor = lowCostMobile
        ? Color.alphaBlend(
            Colors.black.withOpacity(0.10),
            backgroundColor,
          )
        : backgroundColor;

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
        boxShadow: effectiveBoxShadow,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: clipBehavior,
      child: effectiveBlurSigma <= 0
          ? decorated
          : BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: effectiveBlurSigma,
                sigmaY: effectiveBlurSigma,
              ),
              child: decorated,
            ),
    );
  }
}

class TwitchGlassPanelShadow {
  const TwitchGlassPanelShadow._();

  static List<BoxShadow> soft({double opacity = 0.34}) {
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withOpacity(opacity),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ];
  }

  static List<BoxShadow> compact({double opacity = 0.24}) {
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withOpacity(opacity),
        blurRadius: 14,
        offset: const Offset(0, 7),
      ),
    ];
  }
}
