// PATCH VERSION: twitch_watch_chat_input_section_pending_action_entry

import 'package:flutter/material.dart';

import '../../../../models/special_actions/twitch_pending_special_message.dart';
import '../../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../chat/twitch_chat_input_bar.dart';
import 'twitch_pending_chat_action_banner.dart';
import 'twitch_watch_chat_utility_bar.dart';

class TwitchWatchChatInputSection extends StatelessWidget {
  final TwitchChannelPointsRuntimeSnapshot? channelPoints;
  final TwitchPendingSpecialMessage? pendingSpecialMessage;
  final TextEditingController messageController;
  final bool loadingEmotes;
  final bool compact;
  final bool enabled;
  final bool sending;
  final VoidCallback onOpenChannelPoints;
  final VoidCallback onOpenEmotes;
  final VoidCallback? onOpenSpecialActions;
  final VoidCallback? onCancelPendingSpecialMessage;
  final VoidCallback onSend;

  const TwitchWatchChatInputSection({
    super.key,
    required this.channelPoints,
    this.pendingSpecialMessage,
    required this.messageController,
    required this.loadingEmotes,
    required this.compact,
    required this.enabled,
    required this.sending,
    required this.onOpenChannelPoints,
    required this.onOpenEmotes,
    this.onOpenSpecialActions,
    this.onCancelPendingSpecialMessage,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final pending = pendingSpecialMessage;

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
            onOpenSpecialActions: onOpenSpecialActions,
          ),
          if (pending != null)
            TwitchPendingChatActionBanner(
              pending: pending,
              compact: compact,
              onCancel: onCancelPendingSpecialMessage ?? () {},
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
