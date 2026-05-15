import 'package:flutter/material.dart';

class TwitchTypography {
  const TwitchTypography._();

  static const double sheetTitle = 13;
  static const double sectionTitle = 12;
  static const double body = 11;
  static const double chatBase = 13;
  static const double secondary = 10;
  static const double badge = 10;

  static TextStyle sheetTitleStyle = const TextStyle(
    fontSize: sheetTitle,
    fontWeight: FontWeight.w900,
    color: Colors.white,
  );

  static TextStyle sectionTitleStyle = const TextStyle(
    fontSize: sectionTitle,
    fontWeight: FontWeight.w900,
    color: Colors.white70,
  );

  static TextStyle bodyStyle = const TextStyle(
    fontSize: body,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static TextStyle secondaryStyle = const TextStyle(
    fontSize: secondary,
    fontWeight: FontWeight.w700,
    color: Colors.white54,
  );

  static double chatFontSize(double scale, {bool compact = false}) {
    final compactScale = compact ? 0.92 : 1.0;
    return chatBase * scale * compactScale;
  }

  static double chatEmoteSize(double scale, {bool compact = false}) {
    return chatFontSize(scale, compact: compact) * 1.65;
  }
}
