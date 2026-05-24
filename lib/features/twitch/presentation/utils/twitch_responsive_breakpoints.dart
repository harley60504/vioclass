import 'package:flutter/widgets.dart';

class TwitchResponsiveBreakpoints {
  TwitchResponsiveBreakpoints._();

  /// Shared phone/mobile breakpoint for Twitch feature pages and sheets.
  ///
  /// Use this instead of scattering `constraints.maxWidth < ...` checks.
  static const double phoneMaxWidth = 680;

  /// Smaller compact breakpoint for dense controls or button rows.
  static const double compactMaxWidth = 560;

  static bool isPhoneWidth(double width) {
    return width < phoneMaxWidth;
  }

  static bool isCompactWidth(double width) {
    return width < compactMaxWidth;
  }

  static bool isPhoneContext(BuildContext context) {
    return MediaQuery.sizeOf(context).width < phoneMaxWidth;
  }

  static bool isCompactContext(BuildContext context) {
    return MediaQuery.sizeOf(context).width < compactMaxWidth;
  }
}
