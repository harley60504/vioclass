//
// Author name + first-message chip + colon renderer for runtime chat messages.
// Keep this separate so author styling can change without touching segment or
// badge rendering.

import 'package:flutter/material.dart';

import '../twitch_chat_text_style.dart';
import 'twitch_chat_message_chips.dart';
import 'twitch_chat_message_visual_metrics.dart';

class TwitchChatMessageAuthor extends StatelessWidget {
  final String displayNameText;
  final Color displayColor;
  final bool isAction;
  final bool isFirstMessage;
  final bool compact;
  final TwitchChatMessageVisualMetrics metrics;

  const TwitchChatMessageAuthor({
    super.key,
    required this.displayNameText,
    required this.displayColor,
    required this.isAction,
    required this.isFirstMessage,
    required this.compact,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.start,
      children: [
        Text(
          displayNameText,
          style: twitchChatTextStyle(
            TextStyle(
              color: displayColor,
              fontWeight: FontWeight.w900,
              fontSize: compact
                  ? metrics.compactNameFontSize
                  : metrics.nameFontSize,
              fontStyle: isAction ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
        if (isFirstMessage) TwitchChatFirstMessageChip(metrics: metrics),
        Text(
          ':',
          style: twitchChatTextStyle(
            TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.w700,
              fontSize: metrics.messageFontSize,
            ),
          ),
        ),
      ],
    );
  }
}
