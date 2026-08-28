import 'package:flutter/material.dart';

import '../../settings/twitch_app_font_controller.dart';

class TwitchChatTextScope extends StatelessWidget {
  final Widget child;

  const TwitchChatTextScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: twitchChatTextStyle(DefaultTextStyle.of(context).style),
      child: child,
    );
  }
}

TextStyle twitchChatTextStyle(TextStyle style) {
  return style.copyWith(
    fontFamily: twitchAppFontController.fontFamily,
    fontFamilyFallback: TwitchAppFontController.fontFallback,
  );
}
