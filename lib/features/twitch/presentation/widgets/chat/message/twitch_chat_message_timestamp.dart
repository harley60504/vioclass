//
// Timestamp widgets and formatting for runtime chat messages.

import 'package:flutter/material.dart';

import '../twitch_chat_text_style.dart';
import 'twitch_chat_message_visual_metrics.dart';

class TwitchChatTimestampText extends StatelessWidget {
  final DateTime time;
  final TwitchChatMessageVisualMetrics metrics;

  const TwitchChatTimestampText({
    super.key,
    required this.time,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      formatTwitchChatMessageTime(time),
      style: twitchChatTextStyle(
        TextStyle(
          color: Colors.white38,
          fontSize: metrics.metaFontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class TwitchChatTimestampChip extends StatelessWidget {
  final DateTime time;
  final TwitchChatMessageVisualMetrics metrics;

  const TwitchChatTimestampChip({
    super.key,
    required this.time,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        formatTwitchChatMessageTime(time),
        style: twitchChatTextStyle(
          TextStyle(
            color: Colors.white60,
            fontSize: metrics.chipFontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String formatTwitchChatMessageTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
