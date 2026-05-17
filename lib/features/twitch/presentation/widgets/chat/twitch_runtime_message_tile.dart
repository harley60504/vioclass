// PATCH VERSION: twitch_runtime_message_tile_stage157_card_shells

import 'package:flutter/material.dart';

import '../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../services/chat/twitch_third_party_emote_cache_service.dart';
import 'message/twitch_chat_message_cards.dart';
import 'message/twitch_chat_message_special_style.dart';
import 'message/twitch_chat_message_user_style.dart';
import 'message/twitch_chat_message_visual_metrics.dart';

class TwitchRuntimeMessageTile extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final bool showTimestamp;
  final double fontScale;
  final bool compact;
  final VoidCallback? onOpenContext;

  const TwitchRuntimeMessageTile({
    super.key,
    required this.message,
    this.thirdPartyEmotes,
    this.showTimestamp = false,
    this.fontScale = 1.0,
    this.compact = false,
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

    if (style != null) {
      return TwitchChatSpecialMessageCard(
        message: message,
        thirdPartyEmotes: thirdPartyEmotes,
        displayColor: displayColor,
        displayNameText: displayNameText,
        style: style,
        showTimestamp: showTimestamp,
        metrics: metrics,
        onOpenContext: onOpenContext,
      );
    }

    return TwitchChatNormalMessageCard(
      message: message,
      thirdPartyEmotes: thirdPartyEmotes,
      displayColor: displayColor,
      displayNameText: displayNameText,
      showTimestamp: showTimestamp,
      metrics: metrics,
      onOpenContext: onOpenContext,
    );
  }
}
