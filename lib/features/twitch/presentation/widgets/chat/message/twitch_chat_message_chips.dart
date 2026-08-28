//
// Small reusable chips used inside chat messages.

import 'package:flutter/material.dart';

import '../twitch_chat_text_style.dart';
import 'twitch_chat_message_visual_metrics.dart';

class TwitchChatSmallChip extends StatelessWidget {
  final String label;
  final TwitchChatMessageVisualMetrics metrics;

  const TwitchChatSmallChip({
    super.key,
    required this.label,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF9146FF).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: const Color(0xFF9146FF).withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: twitchChatTextStyle(
          TextStyle(
            color: const Color(0xFFBF94FF),
            fontSize: metrics.chipFontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class TwitchChatFirstMessageChip extends StatelessWidget {
  final TwitchChatMessageVisualMetrics metrics;

  const TwitchChatFirstMessageChip({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: const Color(0xFFBF94FF).withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        '首聊',
        style: twitchChatTextStyle(
          TextStyle(
            color: const Color(0xFFCBB2FF),
            fontSize: (metrics.chipFontSize - 0.5).clamp(8.0, 12.0),
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class TwitchChatBitsChip extends StatelessWidget {
  final int bits;
  final TwitchChatMessageVisualMetrics metrics;

  const TwitchChatBitsChip({
    super.key,
    required this.bits,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return TwitchChatSmallChip(label: '$bits bits', metrics: metrics);
  }
}
