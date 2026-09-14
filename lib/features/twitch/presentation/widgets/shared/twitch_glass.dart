import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/twitch_ui_tokens.dart';

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
    this.borderRadius = const BorderRadius.all(
      Radius.circular(TwitchUiRadius.player),
    ),
    this.backgroundColor = TwitchUiGlass.floatingBackground,
    this.borderColor = TwitchUiGlass.border,
    this.blurSigma = TwitchUiGlass.blurMedium,
    this.boxShadow = TwitchUiShadows.floating,
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
    final lowCostMobile = _useLowCostMobileGlass;
    final legacyPlayerDock =
        blurSigma == 0 &&
        boxShadow.isEmpty &&
        backgroundColor == const Color(0x8F000000);

    final requestedBlur = legacyPlayerDock ? TwitchUiGlass.blurSoft : blurSigma;
    final requestedShadow = legacyPlayerDock
        ? TwitchUiShadows.soft
        : boxShadow;
    final requestedBackground = legacyPlayerDock
        ? TwitchUiGlass.playerBackground
        : backgroundColor;

    final effectiveBlurSigma = lowCostMobile ? 0.0 : requestedBlur;
    final effectiveBoxShadow = lowCostMobile
        ? TwitchUiShadows.none
        : requestedShadow;
    final effectiveBackgroundColor = lowCostMobile
        ? Color.alphaBlend(
            Colors.black.withValues(alpha: 0.12),
            requestedBackground,
          )
        : requestedBackground;

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
        boxShadow: effectiveBoxShadow,
      ),
      child: Padding(padding: padding, child: child),
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
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ];
  }

  static List<BoxShadow> compact({double opacity = 0.24}) {
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 14,
        offset: const Offset(0, 7),
      ),
    ];
  }
}
