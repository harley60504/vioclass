// PATCH VERSION: twitch_watch_chat_input_section_stage209_single_translucent_layer
//
// Stage 209: remove the extra translucent shell layer around utility/input.
// The whole chat panel is already translucent, so inner sections should not
// stack another panel background.

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withOpacity(0.055),
          ),
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
    );
  }
}
