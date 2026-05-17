import 'dart:ui';

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

  @override
  Widget build(BuildContext context) {
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
        boxShadow: boxShadow,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: clipBehavior,
      child: blurSigma <= 0
          ? decorated
          : BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
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
