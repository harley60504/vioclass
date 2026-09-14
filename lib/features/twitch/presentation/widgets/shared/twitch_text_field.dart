import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/twitch_ui_tokens.dart';

class TwitchTextField extends StatelessWidget {
  static const double lineHeight = 1.2;
  static const double defaultHeight = 40;

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final SpecialTextSpanBuilder? specialTextSpanBuilder;
  final bool enabled;
  final bool autofocus;
  final bool readOnly;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final double? height;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextAlign textAlign;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final TextSelectionControls? selectionControls;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final TapRegionCallback? onTapOutside;
  final VoidCallback? onTap;
  final Color? cursorColor;

  const TwitchTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.style,
    this.strutStyle,
    this.specialTextSpanBuilder,
    this.enabled = true,
    this.autofocus = false,
    this.readOnly = false,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.height,
    this.keyboardType,
    this.textInputAction,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.selectionControls,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTapOutside,
    this.onTap,
    this.cursorColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = const TextStyle(
      color: TwitchUiColors.textPrimary,
      fontSize: TwitchUiFontSize.bodyCompact,
      height: lineHeight,
      fontWeight: TwitchUiFontWeight.medium,
    );
    final effectiveStyle = baseStyle
        .merge(style)
        .copyWith(height: style?.height ?? lineHeight);
    final effectiveStrut =
        strutStyle ??
        StrutStyle.fromTextStyle(effectiveStyle, forceStrutHeight: true);
    final fixedSingleLine =
        maxLines == 1 &&
        decoration.labelText == null &&
        decoration.helperText == null &&
        decoration.errorText == null;
    final effectiveHeight = fixedSingleLine
        ? (height ?? defaultHeight)
        : height;
    final suppliedHintStyle = decoration.hintStyle;
    final radius = BorderRadius.circular(TwitchUiRadius.md);
    final defaultBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: TwitchUiColors.border),
    );
    final effectiveDecoration = decoration.copyWith(
      isDense: true,
      isCollapsed: fixedSingleLine,
      filled: decoration.filled ?? true,
      fillColor: decoration.fillColor ?? TwitchUiColors.surfaceInteractive,
      hintStyle: effectiveStyle.copyWith(
        color: suppliedHintStyle?.color ?? TwitchUiColors.textMuted,
        fontWeight: suppliedHintStyle?.fontWeight ?? effectiveStyle.fontWeight,
      ),
      labelStyle:
          decoration.labelStyle ??
          effectiveStyle.copyWith(color: TwitchUiColors.textSecondary),
      floatingLabelStyle:
          decoration.floatingLabelStyle ??
          effectiveStyle.copyWith(color: TwitchUiColors.primarySoft),
      border: decoration.border ?? defaultBorder,
      enabledBorder: decoration.enabledBorder ?? defaultBorder,
      focusedBorder:
          decoration.focusedBorder ??
          OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: TwitchUiColors.primarySoft),
          ),
      disabledBorder:
          decoration.disabledBorder ??
          OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: TwitchUiColors.borderSubtle),
          ),
      contentPadding: fixedSingleLine
          ? EdgeInsets.symmetric(
              horizontal: TwitchUiSpacing.space12,
              vertical:
                  ((effectiveHeight! -
                              (effectiveStyle.fontSize ??
                                      TwitchUiFontSize.bodyCompact) *
                                  (effectiveStyle.height ?? lineHeight)) /
                          2)
                      .clamp(0, effectiveHeight / 2)
                      .toDouble(),
            )
          : (decoration.contentPadding ??
                const EdgeInsets.symmetric(
                  horizontal: TwitchUiSpacing.space12,
                  vertical: TwitchUiSpacing.space12,
                )),
      prefixIconConstraints: decoration.prefixIcon == null
          ? decoration.prefixIconConstraints
          : BoxConstraints(
              minWidth: effectiveHeight ?? 40,
              minHeight: effectiveHeight ?? 40,
              maxHeight: effectiveHeight ?? double.infinity,
            ),
      suffixIconConstraints: decoration.suffixIcon == null
          ? decoration.suffixIconConstraints
          : BoxConstraints(
              minWidth: effectiveHeight ?? 40,
              minHeight: effectiveHeight ?? 40,
              maxHeight: effectiveHeight ?? double.infinity,
            ),
    );

    final field = specialTextSpanBuilder == null
        ? TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: effectiveDecoration,
            style: effectiveStyle,
            strutStyle: effectiveStrut,
            enabled: enabled,
            autofocus: autofocus,
            readOnly: readOnly,
            minLines: minLines,
            maxLines: maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            textAlign: textAlign,
            textAlignVertical: TextAlignVertical.center,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            selectionControls: selectionControls,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            onEditingComplete: onEditingComplete,
            onTapOutside: onTapOutside,
            onTap: onTap,
            cursorColor: cursorColor ?? TwitchUiColors.primarySoft,
          )
        : ExtendedTextField(
            controller: controller,
            focusNode: focusNode,
            decoration: effectiveDecoration,
            style: effectiveStyle,
            strutStyle: effectiveStrut,
            specialTextSpanBuilder: specialTextSpanBuilder,
            enabled: enabled,
            autofocus: autofocus,
            readOnly: readOnly,
            minLines: minLines,
            maxLines: maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            textAlign: textAlign,
            textAlignVertical: TextAlignVertical.center,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            selectionControls: selectionControls,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            onEditingComplete: onEditingComplete,
            onTapOutside: onTapOutside,
            onTap: onTap,
            cursorColor: cursorColor ?? TwitchUiColors.primarySoft,
          );

    return effectiveHeight == null
        ? field
        : SizedBox(height: effectiveHeight, child: field);
  }
}
