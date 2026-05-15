import 'package:flutter/material.dart';

enum TwitchDeviceLayout {
  phonePortrait,
  phoneLandscape,
  tablet,
  desktop,
}

class TwitchBreakpoints {
  const TwitchBreakpoints._();

  static TwitchDeviceLayout resolve(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final shortest = size.shortestSide;
    final isLandscape = media.orientation == Orientation.landscape;

    if (shortest >= 900 || size.width >= 1100) {
      return TwitchDeviceLayout.desktop;
    }

    if (shortest >= 600 || size.width >= 760) {
      return TwitchDeviceLayout.tablet;
    }

    return isLandscape
        ? TwitchDeviceLayout.phoneLandscape
        : TwitchDeviceLayout.phonePortrait;
  }

  static bool isCompactVertical(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.orientation == Orientation.landscape ||
        media.size.height < 540 ||
        media.viewInsets.bottom > 0;
  }

  static bool isPhone(BuildContext context) {
    final layout = resolve(context);
    return layout == TwitchDeviceLayout.phonePortrait ||
        layout == TwitchDeviceLayout.phoneLandscape;
  }
}
