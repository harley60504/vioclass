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

    if (style != null) {
      return TwitchChatSpecialMessageCard(
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
    }

    return TwitchChatNormalMessageCard(
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
}
