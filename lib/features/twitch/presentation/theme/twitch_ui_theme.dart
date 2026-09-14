import 'package:flutter/material.dart';

import 'twitch_ui_tokens.dart';

class TwitchUiTheme {
  const TwitchUiTheme._();

  static ThemeData dark({
    String? fontFamily,
    List<String>? fontFamilyFallback,
  }) {
    final colorScheme = const ColorScheme.dark(
      primary: TwitchUiColors.primary,
      secondary: TwitchUiColors.secondary,
      surface: TwitchUiColors.surfacePanel,
      onPrimary: TwitchUiColors.textOnAccent,
      onSecondary: Color(0xFF061018),
      onSurface: TwitchUiColors.textPrimary,
      error: TwitchUiColors.red,
      onError: TwitchUiColors.textOnAccent,
    );

    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: TwitchUiColors.windowBackground,
      canvasColor: TwitchUiColors.surfaceBase,
      cardColor: TwitchUiColors.surfaceCard,
      dividerColor: TwitchUiColors.divider,
      disabledColor: TwitchUiColors.disabledForeground,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );

    final textTheme = base.textTheme.apply(
      bodyColor: TwitchUiColors.textPrimary,
      displayColor: TwitchUiColors.textPrimary,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: const IconThemeData(color: TwitchUiColors.textSecondary),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: TwitchUiColors.surfaceRaised,
          borderRadius: BorderRadius.circular(TwitchUiRadius.sm),
          border: Border.all(color: TwitchUiColors.border),
          boxShadow: TwitchUiShadows.soft,
        ),
        textStyle: const TextStyle(
          color: TwitchUiColors.textPrimary,
          fontSize: TwitchUiFontSize.meta,
          fontWeight: TwitchUiFontWeight.medium,
        ),
      ),
      cardTheme: CardThemeData(
        color: TwitchUiColors.surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TwitchUiRadius.lg),
          side: const BorderSide(color: TwitchUiColors.borderSubtle),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: TwitchUiColors.divider,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: TwitchUiColors.primarySoft,
        linearTrackColor: TwitchUiColors.borderSubtle,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: TwitchUiColors.primary,
        inactiveTrackColor: TwitchUiColors.borderStrong,
        thumbColor: TwitchUiColors.primarySoft,
        overlayColor: TwitchUiColors.selectedOverlay,
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TwitchUiColors.surfaceInteractive,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TwitchUiSpacing.space12,
          vertical: TwitchUiSpacing.space8,
        ),
        hintStyle: const TextStyle(color: TwitchUiColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TwitchUiRadius.sm),
          borderSide: const BorderSide(color: TwitchUiColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TwitchUiRadius.sm),
          borderSide: const BorderSide(color: TwitchUiColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TwitchUiRadius.sm),
          borderSide: const BorderSide(
            color: TwitchUiColors.primarySoft,
            width: TwitchUiBorderWidth.emphasized,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return TwitchUiColors.disabledForeground;
            }
            if (states.contains(WidgetState.selected)) {
              return TwitchUiColors.primarySoft;
            }
            return TwitchUiColors.textPrimary;
          }),
          overlayColor: const WidgetStatePropertyAll(
            TwitchUiColors.hoverOverlay,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TwitchUiRadius.sm),
            ),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TwitchUiColors.primary,
          foregroundColor: TwitchUiColors.textOnAccent,
          disabledBackgroundColor: TwitchUiColors.surfaceInteractive,
          disabledForegroundColor: TwitchUiColors.disabledForeground,
          textStyle: const TextStyle(fontWeight: TwitchUiFontWeight.strong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TwitchUiRadius.sm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TwitchUiColors.textPrimary,
          side: const BorderSide(color: TwitchUiColors.borderStrong),
          textStyle: const TextStyle(fontWeight: TwitchUiFontWeight.strong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TwitchUiRadius.sm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TwitchUiColors.primarySoft,
          textStyle: const TextStyle(fontWeight: TwitchUiFontWeight.strong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TwitchUiRadius.sm),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: TwitchUiColors.surfacePanel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TwitchUiRadius.xl),
          side: const BorderSide(color: TwitchUiColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TwitchUiColors.surfacePanel,
        modalBackgroundColor: TwitchUiColors.surfacePanel,
        modalBarrierColor: TwitchUiColors.sheet.scrim,
        showDragHandle: false,
      ),
    );
  }
}
