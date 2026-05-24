import 'package:flutter/widgets.dart';

enum TwitchResponsiveLayoutMode {
  phonePortrait,
  phoneLandscape,
  tablet,
  desktop,
}

class TwitchResponsiveLayout {
  static const double homeBottomNavigationMaxWidth = 760;
  static const double homeTwoRowToolbarMaxWidth = 720;
  static const double dropsHeaderStackMaxWidth = 760;
  static const double dropsCampaignStackMaxWidth = 680;
  static const double watchDisableResizeHandleMaxWidth = 920;

  final double width;
  final double height;
  final double aspectRatio;
  final double shortestSide;
  final TwitchResponsiveLayoutMode mode;

  const TwitchResponsiveLayout._({
    required this.width,
    required this.height,
    required this.aspectRatio,
    required this.shortestSide,
    required this.mode,
  });

  factory TwitchResponsiveLayout.fromConstraints(BoxConstraints constraints) {
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
    final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
    final safeHeight = height <= 0 ? 1.0 : height;
    final aspectRatio = width / safeHeight;
    final shortestSide = width < height ? width : height;

    final mode = width >= 1024
        ? TwitchResponsiveLayoutMode.desktop
        : shortestSide >= 600
            ? TwitchResponsiveLayoutMode.tablet
            : aspectRatio >= 1.25
                ? TwitchResponsiveLayoutMode.phoneLandscape
                : TwitchResponsiveLayoutMode.phonePortrait;

    return TwitchResponsiveLayout._(
      width: width,
      height: height,
      aspectRatio: aspectRatio,
      shortestSide: shortestSide,
      mode: mode,
    );
  }

  static TwitchResponsiveLayout fromContext(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return TwitchResponsiveLayout.fromConstraints(
      BoxConstraints.tight(size),
    );
  }

  bool get isPhone =>
      mode == TwitchResponsiveLayoutMode.phonePortrait ||
      mode == TwitchResponsiveLayoutMode.phoneLandscape;

  bool get isPhonePortrait => mode == TwitchResponsiveLayoutMode.phonePortrait;
  bool get isPhoneLandscape => mode == TwitchResponsiveLayoutMode.phoneLandscape;
  bool get isTablet => mode == TwitchResponsiveLayoutMode.tablet;
  bool get isDesktop => mode == TwitchResponsiveLayoutMode.desktop;

  bool get shouldUseSideChat =>
      isDesktop || isTablet || isPhoneLandscape || aspectRatio >= 1.45;

  bool get shouldUseBottomChat => !shouldUseSideChat;

  bool get shouldUseIconSidebar => width < homeBottomNavigationMaxWidth;

  bool get shouldUseBottomHomeNavigation {
    return width < homeBottomNavigationMaxWidth;
  }

  bool get shouldUseTwoRowHomeToolbar {
    return width < homeTwoRowToolbarMaxWidth;
  }

  bool get shouldStackDropsHeader {
    return width < dropsHeaderStackMaxWidth;
  }

  bool get shouldStackDropsCampaignCard {
    return width < dropsCampaignStackMaxWidth;
  }

  bool get shouldDisableWatchChatResizeHandle {
    return isPhoneLandscape || width < watchDisableResizeHandleMaxWidth;
  }

  EdgeInsets get contentPadding {
    if (isPhone) return const EdgeInsets.fromLTRB(10, 10, 10, 12);
    if (isTablet) return const EdgeInsets.fromLTRB(14, 14, 14, 16);
    return const EdgeInsets.fromLTRB(18, 18, 18, 18);
  }
}
