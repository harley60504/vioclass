import 'package:flutter/material.dart';

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
    final verticalPadding = (height - fontSize * _lineHeight) / 2;
    final style = TextStyle(
      color: textColor,
      fontSize: fontSize,
      height: _lineHeight,
      fontWeight: fontWeight,
    );

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        maxLines: 1,
        textAlignVertical: TextAlignVertical.center,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: style,
        strutStyle: StrutStyle(
          fontSize: fontSize,
          height: _lineHeight,
          forceStrutHeight: true,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          hintText: hintText,
          hintStyle: style.copyWith(color: hintColor),
          prefixIcon: Icon(prefixIcon, color: iconColor, size: height * 0.42),
          prefixIconConstraints: BoxConstraints(
            minWidth: height,
            minHeight: height,
          ),
          suffixIcon: suffixIcon,
          suffixIconConstraints: BoxConstraints(
            minWidth: height,
            minHeight: height,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: verticalPadding,
          ),
        ),
      ),
    );
  }
}
