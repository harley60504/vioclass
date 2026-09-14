import '../theme/twitch_ui_tokens.dart';

/// Compatibility facade. New code should import twitch_ui_tokens.dart directly.
class TwitchSpacing {
  const TwitchSpacing._();

  static const double xxs = TwitchUiSpacing.space2;
  static const double xs = TwitchUiSpacing.space4;
  static const double sm = TwitchUiSpacing.space8;
  static const double md = TwitchUiSpacing.space12;
  static const double lg = TwitchUiSpacing.space16;
  static const double xl = TwitchUiSpacing.space20;

  static double compactAware(
    bool compact,
    double regular,
    double compactValue,
  ) {
    return compact ? compactValue : regular;
  }
}

/// Compatibility facade. New code should use TwitchUiRadius.
class TwitchRadius {
  const TwitchRadius._();

  static const double sm = TwitchUiRadius.sm;
  static const double md = TwitchUiRadius.md;
  static const double lg = TwitchUiRadius.lg;
  static const double sheet = TwitchUiRadius.sheet;
}
