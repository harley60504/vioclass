import 'package:flutter/material.dart';

import '../../../models/engagement/twitch_pinned_chat.dart';
import 'twitch_chat_text_style.dart';

class TwitchPinnedChatBar extends StatelessWidget {
  final TwitchPinnedChatMessage message;

  const TwitchPinnedChatBar({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final name =
        message.sender?.displayName ??
        message.pinnedBy?.displayName ??
        'Pinned';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD166).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFFFD166).withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.push_pin, color: Color(0xFFFFD166), size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$name：${message.text}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: twitchChatTextStyle(
                const TextStyle(
                  color: Color(0xFFFFE3A3),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
