//
// Reply preview widget used by runtime chat message content.
// Highlights @mentions in the compact reply preview so tags remain
// readable on dark chat cards.

import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../twitch_chat_text_style.dart';
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
      child: Text.rich(
        TextSpan(
          children: _buildPreviewSpans(name: name, body: body),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
      ),
    );
  }

  List<InlineSpan> _buildPreviewSpans({
    required String name,
    required String body,
  }) {
    final cleanName = name.trim();
    final cleanBody = body.trim();

    if (cleanName.isEmpty && cleanBody.isEmpty) {
      return <InlineSpan>[TextSpan(text: 'reply', style: _baseStyle())];
    }

    final spans = <InlineSpan>[];

    if (cleanName.isNotEmpty) {
      spans.add(
        TextSpan(
          text: cleanBody.isEmpty ? cleanName : '$cleanName: ',
          style: _nameStyle(),
        ),
      );
    }

    if (cleanBody.isNotEmpty) {
      _appendMentionAwareText(spans, cleanBody);
    }

    return spans;
  }

  void _appendMentionAwareText(List<InlineSpan> spans, String text) {
    var cursor = 0;

    for (final match in _mentionRegex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, match.start),
            style: _baseStyle(),
          ),
        );
      }

      spans.add(TextSpan(text: match.group(0) ?? '', style: _mentionStyle()));

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: _baseStyle()));
    }
  }

  TextStyle _nameStyle() {
    return twitchChatTextStyle(
      TextStyle(
        color: Colors.white60,
        fontSize: metrics.metaFontSize,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
    );
  }

  TextStyle _baseStyle() {
    return twitchChatTextStyle(
      TextStyle(
        color: Colors.white54,
        fontSize: metrics.metaFontSize,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
    );
  }

  TextStyle _mentionStyle() {
    return twitchChatTextStyle(
      TextStyle(
        color: const Color(0xFFD6CCEA),
        fontSize: metrics.metaFontSize,
        fontWeight: FontWeight.w900,
        height: 1.15,
      ),
    );
  }
}

final RegExp _mentionRegex = RegExp(r'@[A-Za-z0-9_]{3,25}');
