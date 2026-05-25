class TwitchSpacing {
  const TwitchSpacing._();

  static const double xxs = 3;
  static const double xs = 5;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 18;

  static double compactAware(
    bool compact,
    double regular,
    double compactValue,
  ) {
    return compact ? compactValue : regular;
  }
}

class TwitchRadius {
  const TwitchRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double sheet = 18;
}
