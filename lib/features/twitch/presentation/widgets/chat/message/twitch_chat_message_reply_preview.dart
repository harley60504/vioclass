// PATCH VERSION: twitch_chat_message_reply_preview_stage154
//
// Reply preview widget used by runtime chat message content.

import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_runtime_message.dart';
import 'twitch_chat_message_visual_metrics.dart';

class TwitchChatMessageReplyPreview extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchChatMessageVisualMetrics metrics;

  const TwitchChatMessageReplyPreview({
    super.key,
    required this.message,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final reply = message.metadata.replyInfo;
    if (reply == null) return const SizedBox.shrink();

    final name = reply.parentDisplayName.isEmpty
        ? reply.parentUserLogin
        : reply.parentDisplayName;
    final body = reply.parentMsgBody;

    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 3),
      child: Text(
        name.isEmpty && body.isEmpty ? 'reply' : '$name: $body',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
        style: TextStyle(
          color: Colors.white38,
          fontSize: metrics.metaFontSize,
        ),
      ),
    );
  }
}
