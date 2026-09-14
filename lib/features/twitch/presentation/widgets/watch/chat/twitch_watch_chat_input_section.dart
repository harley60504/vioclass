import 'package:flutter/material.dart';

import '../../../../models/special_actions/twitch_pending_special_message.dart';
import '../../../../services/chat/twitch_chat_runtime.dart';
import '../../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../../localization/vioclass_localizations.dart';
import '../../../theme/twitch_ui_tokens.dart';
import '../../chat/twitch_chat_input_bar.dart';
import 'twitch_chat_room_mode_banner.dart';
import 'twitch_pending_chat_action_banner.dart';
import 'twitch_watch_chat_utility_bar.dart';

class TwitchWatchChatInputSection extends StatelessWidget {
  final TwitchChannelPointsRuntimeSnapshot? channelPoints;
  final TwitchChatRuntime? runtime;
  final bool viewerIsFollowing;
  final DateTime? viewerFollowedAt;
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
    required this.runtime,
    required this.viewerIsFollowing,
    required this.viewerFollowedAt,
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
    final activeRuntime = runtime;

    return SafeArea(
      left: false,
      right: false,
      top: false,
      bottom: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pending != null)
            TwitchPendingChatActionBanner(
              pending: pending,
              compact: compact,
              onCancel: onCancelPendingSpecialMessage ?? () {},
            ),
          if (activeRuntime == null)
            _buildComposer()
          else
            AnimatedBuilder(
              animation: activeRuntime,
              builder: (context, _) => _buildComposer(
                roomModeHint: twitchChatRoomModeHint(
                  l10n: context.vio,
                  roomState: activeRuntime.roomState,
                  viewerIsFollowing: viewerIsFollowing,
                  viewerFollowedAt: viewerFollowedAt,
                  viewerIsModerator: activeRuntime.viewerIsModerator,
                  viewerIsVip: activeRuntime.viewerIsVip,
                  viewerIsSubscriber: activeRuntime.viewerIsSubscriber,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComposer({String? roomModeHint}) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TwitchUiColors.surfaceRaised,
        border: Border(top: BorderSide(color: TwitchUiColors.borderSubtle)),
        boxShadow: [
          BoxShadow(
            color: Color(0x52000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TwitchWatchChatUtilityBar(
            channelPoints: channelPoints,
            loadingEmotes: loadingEmotes,
            onOpenChannelPoints: onOpenChannelPoints,
            onOpenEmotes: onOpenEmotes,
            onOpenSpecialActions: onOpenSpecialActions,
          ),
          TwitchChatInputBar(
            controller: messageController,
            enabled: enabled,
            sending: sending,
            hintText: roomModeHint,
            hintColor: roomModeHint == null
                ? null
                : Colors.amber.shade200.withValues(alpha: 0.88),
            onSend: onSend,
          ),
        ],
      ),
    );
  }
}
