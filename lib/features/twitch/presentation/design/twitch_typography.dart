import 'package:flutter/material.dart';

import '../theme/twitch_ui_tokens.dart';

/// Compatibility facade for existing widgets while Midnight Glass typography
/// moves to the central token layer.
class TwitchTypography {
  const TwitchTypography._();

  static const double sheetTitle = TwitchUiFontSize.heading;
  static const double sectionTitle = TwitchUiFontSize.body;
  static const double body = TwitchUiFontSize.bodyCompact;
  static const double chatBase = TwitchUiFontSize.chatMessage;
  static const double secondary = TwitchUiFontSize.meta;
  static const double badge = TwitchUiFontSize.micro;

  static const TextStyle sheetTitleStyle = TextStyle(
    fontSize: sheetTitle,
    fontWeight: TwitchUiFontWeight.heavy,
    color: TwitchUiColors.textPrimary,
  );

  static const TextStyle sectionTitleStyle = TextStyle(
    fontSize: sectionTitle,
    fontWeight: TwitchUiFontWeight.strong,
    color: TwitchUiColors.textSecondary,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: body,
    fontWeight: TwitchUiFontWeight.regular,
    color: TwitchUiColors.textPrimary,
  );

  static const TextStyle secondaryStyle = TextStyle(
    fontSize: secondary,
    fontWeight: TwitchUiFontWeight.medium,
    color: TwitchUiColors.textMuted,
  );

  static double chatFontSize(double scale, {bool compact = false}) {
    final compactScale = compact ? 0.94 : 1.0;
    return chatBase * scale * compactScale;
  }

  static double chatEmoteSize(double scale, {bool compact = false}) {
    return chatFontSize(scale, compact: compact) * 1.65;
  }
}
