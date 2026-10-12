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
  final bool readOnlyGuest;
  final bool missingSendPermission;
  final VoidCallback onOpenChannelPoints;
  final VoidCallback onOpenEmotes;
  final VoidCallback? onOpenSpecialActions;
  final VoidCallback? onCancelPendingSpecialMessage;
  final VoidCallback? onLoginPressed;
  final VoidCallback onSend;
  final Object? sendContext;

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
    this.readOnlyGuest = false,
    this.missingSendPermission = false,
    required this.onOpenChannelPoints,
    required this.onOpenEmotes,
    this.onOpenSpecialActions,
    this.onCancelPendingSpecialMessage,
    this.onLoginPressed,
    required this.onSend,
    this.sendContext,
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
            _buildComposer(context)
          else
            AnimatedBuilder(
              animation: activeRuntime,
              builder: (context, _) => _buildComposer(
                context,
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

  Widget _buildComposer(BuildContext context, {String? roomModeHint}) {
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
          if (readOnlyGuest || missingSendPermission)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    color: TwitchUiColors.textSecondary,
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      context.vio.t(
                        readOnlyGuest
                            ? '訪客模式可讀取聊天室；登入後才能發言與使用點數。'
                            : '已登入，但缺少聊天室發言權限。請重新授權後再發言。',
                      ),
                      style: const TextStyle(
                        color: TwitchUiColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onLoginPressed,
                    icon: const Icon(Icons.login_rounded, size: 17),
                    label: Text(context.vio.t(readOnlyGuest ? '登入' : '重新授權')),
                  ),
                ],
              ),
            )
          else
            TwitchChatInputBar(
              controller: messageController,
              enabled: enabled,
              sending: sending,
              hintText: roomModeHint,
              hintColor: roomModeHint == null
                  ? null
                  : Colors.amber.shade200.withValues(alpha: 0.88),
              leadingActions: TwitchWatchChatUtilityBar(
                channelPoints: channelPoints,
                loadingEmotes: loadingEmotes,
                onOpenChannelPoints: onOpenChannelPoints,
                onOpenEmotes: onOpenEmotes,
                padding: EdgeInsets.zero,
              ),
              trailingActions: TwitchWatchChatIdentityButton(
                onTap: onOpenSpecialActions,
              ),
              onSend: onSend,
              sendContext: sendContext,
            ),
        ],
      ),
    );
  }
}
