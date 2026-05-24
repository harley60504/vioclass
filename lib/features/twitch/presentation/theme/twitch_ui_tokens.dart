// PATCH VERSION: twitch_ui_tokens_stage145
//
// Centralized Twitch UI style tokens.
// Start moving page / sheet / chat / discovery widgets to this file instead of
// scattering raw Color / radius / font-size literals across the app.

import 'package:flutter/material.dart';

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

  static const Color appBackground = Color(0xFF0E0E10);
  static const Color surface = Color(0xFF18181B);
  static const Color surfaceAlt = Color(0xFF111116);
  static const Color surfaceCard = Color(0xFF17171D);
  static const Color surfaceElevated = Color(0xFF23232B);
  static const Color border = Color(0xFF25252C);

  static const Color primary = Color(0xFF9146FF);
  static const Color primarySoft = Color(0xFFBF94FF);

  static const TwitchUiBackplatePalette purpleBackplate =
      TwitchUiBackplatePalette(
        fill: Color(0xFF241632),
        fillActive: Color(0xFF241632),
        border: Color(0x66865CFF),
        borderActive: Color(0x99BF94FF),
        foreground: Color(0xFFBF94FF),
        foregroundMuted: Color(0xCCC9BDEC),
      );

  static const TwitchUiSheetPalette sheet = TwitchUiSheetPalette(
    background: surface,
    scrim: Color(0xA3000000),
    shellGradientStart: Color(0xFA231336),
    shellGradientEnd: Color(0xFC101016),
    headerGradientStart: Color(0xEB2A1740),
    headerGradientEnd: Color(0xF515141C),
    border: Color(0x339146FF),
    shadow: Color(0x299146FF),
    handle: Color(0x2EFFFFFF),
    cardFill: Color(0xFF241632),
    cardFillActive: Color(0x664A267A),
    cardBorder: Color(0x66865CFF),
    cardBorderActive: Color(0x9E9146FF),
    backplate: purpleBackplate,
  );

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0x99FFFFFF);
  static const Color textMuted = Color(0x61FFFFFF);
  static const Color textFaint = Color(0x42FFFFFF);

  static const Color blue = Color(0xFF2B7FFF);
  static const Color red = Color(0xFFFF4B6E);
  static const Color gold = Color(0xFFFFC857);
  static const Color green = Color(0xFF7EE787);
  static const Color cyan = Color(0xFF5CC8FF);
  static const Color orange = Color(0xFFFF9D5C);
}

class TwitchUiRadius {
  const TwitchUiRadius._();

  static const double xs = 6;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 18;
  static const double pill = 999;
}

class TwitchUiSpacing {
  const TwitchUiSpacing._();

  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 14;
  static const double xxl = 18;
}

class TwitchUiFontSize {
  const TwitchUiFontSize._();

  static const double chatMessage = 13;
  static const double chatName = 12.5;
  static const double chatMeta = 9.5;
  static const double cardBody = 13;
  static const double cardTitle = 13;
  static const double chip = 10.5;
}

class TwitchUiFontWeight {
  const TwitchUiFontWeight._();

  static const FontWeight body = FontWeight.w700;
  static const FontWeight strong = FontWeight.w800;
  static const FontWeight heavy = FontWeight.w900;
}

class TwitchUiShadows {
  const TwitchUiShadows._();

  static const List<BoxShadow> soft = <BoxShadow>[
    BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4)),
  ];
}
