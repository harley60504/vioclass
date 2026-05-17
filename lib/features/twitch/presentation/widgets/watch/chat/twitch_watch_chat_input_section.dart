// PATCH VERSION: twitch_watch_chat_input_section_stage191_unified_glass
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              const Color(0xFF181020).withOpacity(0.94),
              const Color(0xFF0F0F15).withOpacity(0.98),
            ],
          ),
          border: Border(
            top: BorderSide(color: const Color(0xFF9146FF).withOpacity(0.20)),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.30),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
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
