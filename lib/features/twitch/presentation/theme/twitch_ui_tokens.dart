import 'package:flutter/material.dart';

/// Midnight Glass design tokens for VioClass.
///
/// Keep visual decisions semantic and centralized. Feature widgets should
/// prefer these tokens over raw Color / radius / spacing literals.
class TwitchUiBackplatePalette {
  final Color fill;
  final Color fillActive;
  final Color border;
  final Color borderActive;
  final Color foreground;
  final Color foregroundMuted;

  const TwitchUiBackplatePalette({
    required this.fill,
    required this.fillActive,
    required this.border,
    required this.borderActive,
    required this.foreground,
    required this.foregroundMuted,
  });
}

class TwitchUiSheetPalette {
  final Color background;
  final Color scrim;
  final Color shellGradientStart;
  final Color shellGradientEnd;
  final Color headerGradientStart;
  final Color headerGradientEnd;
  final Color border;
  final Color shadow;
  final Color handle;
  final Color cardFill;
  final Color cardFillActive;
  final Color cardBorder;
  final Color cardBorderActive;
  final TwitchUiBackplatePalette backplate;

  const TwitchUiSheetPalette({
    required this.background,
    required this.scrim,
    required this.shellGradientStart,
    required this.shellGradientEnd,
    required this.headerGradientStart,
    required this.headerGradientEnd,
    required this.border,
    required this.shadow,
    required this.handle,
    required this.cardFill,
    required this.cardFillActive,
    required this.cardBorder,
    required this.cardBorderActive,
    required this.backplate,
  });
}

class TwitchUiColors {
  const TwitchUiColors._();

  // Keep the large app background opaque and purple-black. Interactive surfaces
  // above it are neutral translucent black so the UI does not become uniformly
  // purple.
  static const Color appBackground = Color(0xFF0B0812);
  static const Color fallbackAppBackground = appBackground;
  static const Color windowBackground = appBackground;

  // Neutral translucent surface ladder. Cards, buttons, search fields and chat
  // inputs intentionally share the same 40% black fill for visual consistency.
  static const Color surfaceBase = Color(0x24000000);
  static const Color surfacePanel = Color(0x52000000);
  static const Color surfaceCard = Color(0x66000000);
  static const Color surfaceRaised = Color(0x70000000);
  static const Color surfaceInteractive = Color(0x66000000);
  static const Color surfaceHover = Color(0x80000000);
  static const Color surfaceSelected = Color(0x668D7BFF);
  static const Color surfacePlayer = Color(0xB0000000);
  static const Color surfaceGlass = Color(0x66000000);

  // Backward-compatible aliases. New code should prefer semantic names above.
  static const Color surface = surfacePanel;
  static const Color surfaceAlt = surfaceBase;
  static const Color surfaceElevated = surfaceRaised;

  // Brand / accent.
  static const Color primary = Color(0xFF8D7BFF);
  static const Color primaryHover = Color(0xFFA093FF);
  static const Color primarySoft = Color(0xFFC3BAFF);
  static const Color secondary = Color(0xFF5CC8FF);

  // Content.
  static const Color textPrimary = Color(0xFFF4F5F8);
  static const Color textSecondary = Color(0xFFAFB5C1);
  static const Color textMuted = Color(0xFF777F8F);
  static const Color textFaint = Color(0xFF555D6B);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // Neutral borders / separators. Purple is reserved for focus and selected
  // states instead of every surface edge.
  static const Color borderSubtle = Color(0x1AFFFFFF);
  static const Color border = Color(0x2AFFFFFF);
  static const Color borderStrong = Color(0x3DFFFFFF);
  static const Color borderInteractive = Color(0x558D7BFF);
  static const Color divider = Color(0x18FFFFFF);

  // States.
  static const Color hoverOverlay = Color(0x12FFFFFF);
  static const Color pressedOverlay = Color(0x1CFFFFFF);
  static const Color selectedOverlay = Color(0x268D7BFF);
  static const Color disabledForeground = Color(0x59FFFFFF);
  static const Color focusRing = Color(0x998D7BFF);

  // Semantic accents.
  static const Color blue = Color(0xFF68A7FF);
  static const Color red = Color(0xFFFF5D73);
  static const Color gold = Color(0xFFFFCA68);
  static const Color green = Color(0xFF77D99A);
  static const Color cyan = secondary;
  static const Color orange = Color(0xFFFFA86B);
  static const Color live = Color(0xFFFF4D62);

  static const TwitchUiBackplatePalette purpleBackplate =
      TwitchUiBackplatePalette(
        fill: Color(0x1F8D7BFF),
        fillActive: Color(0x318D7BFF),
        border: Color(0x668D7BFF),
        borderActive: Color(0x99C3BAFF),
        foreground: primarySoft,
        foregroundMuted: Color(0xCCB8B2D8),
      );

  static const TwitchUiSheetPalette sheet = TwitchUiSheetPalette(
    background: surfacePanel,
    scrim: Color(0x99000000),
    shellGradientStart: Color(0x52000000),
    shellGradientEnd: Color(0x66000000),
    headerGradientStart: Color(0x5A000000),
    headerGradientEnd: Color(0x42000000),
    border: border,
    shadow: Color(0xB3000000),
    handle: Color(0x5AFFFFFF),
    cardFill: surfaceCard,
    cardFillActive: surfaceSelected,
    cardBorder: borderSubtle,
    cardBorderActive: borderInteractive,
    backplate: purpleBackplate,
  );
}

class TwitchUiSpacing {
  const TwitchUiSpacing._();

  // 4 px grid.
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;

  // Backward-compatible aliases.
  static const double xs = space4;
  static const double sm = space8;
  static const double md = space12;
  static const double lg = space16;
  static const double xl = space20;
  static const double xxl = space24;
}

class TwitchUiRadius {
  const TwitchUiRadius._();

  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double player = 20;
  static const double sheet = 20;
  static const double pill = 999;
}

class TwitchUiBorderWidth {
  const TwitchUiBorderWidth._();

  static const double hairline = 0.75;
  static const double standard = 1;
  static const double emphasized = 1.25;
}

class TwitchUiOpacity {
  const TwitchUiOpacity._();

  static const double disabled = 0.38;
  static const double secondary = 0.72;
  static const double muted = 0.48;
  static const double playerChrome = 0.65;
}

class TwitchUiFontSize {
  const TwitchUiFontSize._();

  static const double display = 24;
  static const double title = 18;
  static const double heading = 15;
  static const double body = 13;
  static const double bodyCompact = 12;
  static const double meta = 11;
  static const double micro = 10;

  static const double chatMessage = body;
  static const double chatName = 12.5;
  static const double chatMeta = 10;
  static const double cardBody = body;
  static const double cardTitle = 13.5;
  static const double chip = 10.5;
}

class TwitchUiFontWeight {
  const TwitchUiFontWeight._();

  static const FontWeight regular = FontWeight.w500;
  static const FontWeight medium = FontWeight.w600;
  static const FontWeight strong = FontWeight.w700;
  static const FontWeight heavy = FontWeight.w800;

  // Backward-compatible alias.
  static const FontWeight body = regular;
}

class TwitchUiControlSize {
  const TwitchUiControlSize._();

  static const double iconCompact = 18;
  static const double icon = 22;
  static const double iconLarge = 26;
  static const double hitCompact = 34;
  static const double hit = 40;
  static const double hitLarge = 46;
  static const double playerBarCompact = 58;
  static const double playerBar = 68;
}

class TwitchUiGlass {
  const TwitchUiGlass._();

  static const double blurSoft = 12;
  static const double blurMedium = 18;
  static const double blurStrong = 24;
  static const Color playerBackground = TwitchUiColors.surfacePlayer;
  static const Color floatingBackground = TwitchUiColors.surfaceGlass;
  static const Color border = TwitchUiColors.border;
}

class TwitchUiMotion {
  const TwitchUiMotion._();

  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 180);
  static const Duration panel = Duration(milliseconds: 220);
  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubicEmphasized;
}

class TwitchUiShadows {
  const TwitchUiShadows._();

  static const List<BoxShadow> none = <BoxShadow>[];

  static const List<BoxShadow> soft = <BoxShadow>[
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(
      color: Color(0x80000000),
      blurRadius: 30,
      spreadRadius: -6,
      offset: Offset(0, 14),
    ),
  ];
}
