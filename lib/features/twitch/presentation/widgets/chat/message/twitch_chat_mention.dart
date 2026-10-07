import 'package:flutter/material.dart';

import '../twitch_chat_text_style.dart';

class TwitchChatMentionScope extends InheritedWidget {
  final String? viewerLogin;
  const TwitchChatMentionScope({
    super.key,
    required this.viewerLogin,
    required super.child,
  });

  static String? viewerOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TwitchChatMentionScope>()
      ?.viewerLogin;

  @override
  bool updateShouldNotify(TwitchChatMentionScope oldWidget) =>
      viewerLogin != oldWidget.viewerLogin;
}

InlineSpan twitchChatMentionSpan({
  required BuildContext context,
  required String mention,
  required double fontSize,
}) {
  final login = mention.substring(1);
  final isSelf =
      login.toLowerCase() ==
      TwitchChatMentionScope.viewerOf(context)?.trim().toLowerCase();
  final color = isSelf ? const Color(0xFFFFD166) : const Color(0xFF8BD5FF);
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Semantics(
      label: mention,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelf ? color.withValues(alpha: .16) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isSelf ? 3 : 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelf
                      ? Icons.person_pin_circle_outlined
                      : Icons.person_outline,
                  size: fontSize,
                  color: color,
                ),
                const SizedBox(width: 2),
                Text(
                  login,
                  style: twitchChatTextStyle(
                    TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
