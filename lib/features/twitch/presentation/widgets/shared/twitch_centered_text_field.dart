import 'package:flutter/material.dart';

import 'twitch_text_field.dart';

class TwitchCenteredTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  final TextInputAction textInputAction;
  final double height;
  final double radius;
  final double fontSize;
  final FontWeight fontWeight;
  final Color fillColor;
  final Color borderColor;
  final Color textColor;
  final Color hintColor;
  final Color iconColor;

  const TwitchCenteredTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.onChanged,
    this.onSubmitted,
    this.suffixIcon,
    this.textInputAction = TextInputAction.search,
    this.height = 48,
    this.radius = 16,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w700,
    this.fillColor = const Color(0xFF0E0E10),
    this.borderColor = Colors.transparent,
    this.textColor = Colors.white,
    this.hintColor = Colors.white54,
    this.iconColor = Colors.white70,
  });

  static const double _lineHeight = 1.20;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: textColor,
      fontSize: fontSize,
      height: _lineHeight,
      fontWeight: fontWeight,
    );

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: borderColor),
    );

    return TwitchTextField(
      height: height,
      controller: controller,
      maxLines: 1,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: style,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: style.copyWith(color: hintColor),
        prefixIcon: Icon(prefixIcon, color: iconColor, size: height * 0.42),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor,
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
    );
  }
}
