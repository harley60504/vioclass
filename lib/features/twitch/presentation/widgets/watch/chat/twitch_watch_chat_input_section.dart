// PATCH VERSION: twitch_watch_chat_input_section_stage150
//
// Bottom input chrome for Watch chat. Keeps the panel as composition only.

import 'package:flutter/material.dart';

import '../../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../chat/twitch_chat_input_bar.dart';
import 'twitch_watch_chat_utility_bar.dart';

class TwitchWatchChatInputSection extends StatelessWidget {
  final TwitchChannelPointsRuntimeSnapshot? channelPoints;
  final TextEditingController messageController;
  final bool loadingEmotes;
  final bool compact;
  final bool enabled;
  final bool sending;
  final VoidCallback onOpenChannelPoints;
  final VoidCallback onOpenEmotes;
  final VoidCallback onSend;

  const TwitchWatchChatInputSection({
    super.key,
    required this.channelPoints,
    required this.messageController,
    required this.loadingEmotes,
    required this.compact,
    required this.enabled,
    required this.sending,
    required this.onOpenChannelPoints,
    required this.onOpenEmotes,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: false,
      right: false,
      top: false,
      bottom: true,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111116),
          border: Border(top: BorderSide(color: Color(0xFF2D2D35))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TwitchWatchChatUtilityBar(
              channelPoints: channelPoints,
              loadingEmotes: loadingEmotes,
              compact: compact,
              onOpenChannelPoints: onOpenChannelPoints,
              onOpenEmotes: onOpenEmotes,
            ),
            TwitchChatInputBar(
              controller: messageController,
              enabled: enabled,
              sending: sending,
              compact: compact,
              onSend: onSend,
              onOpenEmotes: onOpenEmotes,
            ),
          ],
        ),
      ),
    );
  }
}
