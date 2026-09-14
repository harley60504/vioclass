import 'package:flutter/material.dart';

import '../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../services/chat/twitch_third_party_emote_cache_service.dart';
import 'message/twitch_chat_message_cards.dart';
import 'message/twitch_chat_message_special_style.dart';
import 'message/twitch_chat_message_user_style.dart';
import 'message/twitch_chat_message_visual_metrics.dart';

class TwitchRuntimeMessageTile extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService? officialEmotes;
  final bool showTimestamp;
  final double fontScale;
  final bool compact;
  final bool animateEmotes;
  final VoidCallback? onOpenContext;

  const TwitchRuntimeMessageTile({
    super.key,
    required this.message,
    this.thirdPartyEmotes,
    this.officialEmotes,
    this.showTimestamp = false,
    this.fontScale = 1.0,
    this.compact = false,
    this.animateEmotes = true,
    this.onOpenContext,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = parseTwitchChatUserColorOrFallback(
      color: message.color,
      login: message.userLogin,
    );
    final displayNameText = formatTwitchChatDisplayName(message);
    final metrics = TwitchChatMessageVisualMetrics(fontScale, compact: compact);
    final style = TwitchChatSpecialMessageStyle.fromMetadata(message.metadata);

    final Widget card;
    if (style != null) {
      card = TwitchChatSpecialMessageCard(
        message: message,
        thirdPartyEmotes: thirdPartyEmotes,
        officialEmotes: officialEmotes,
        displayColor: displayColor,
        displayNameText: displayNameText,
        style: style,
        showTimestamp: showTimestamp,
        metrics: metrics,
        animateEmotes: animateEmotes,
        onOpenContext: onOpenContext,
      );
    } else {
      card = TwitchChatNormalMessageCard(
        message: message,
        thirdPartyEmotes: thirdPartyEmotes,
        officialEmotes: officialEmotes,
        displayColor: displayColor,
        displayNameText: displayNameText,
        showTimestamp: showTimestamp,
        metrics: metrics,
        animateEmotes: animateEmotes,
        onOpenContext: onOpenContext,
      );
    }

    // Every message owns a strict paint box. Rich descendants such as link
    // previews, highlighted messages, GIFs and media thumbnails may be taller
    // than plain text, but they are never allowed to paint outside the size the
    // sliver measured for this item.
    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: double.infinity, child: card),
    );
  }
}
