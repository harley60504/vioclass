import 'package:flutter/material.dart';
import '../../../../api/moderation/twitch_moderation_api_service.dart';
import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../localization/vioclass_localizations.dart';
import 'twitch_moderation_message_actions.dart';
import 'twitch_user_role_actions.dart';

/// Shares fresh official role state within one user card, not historical badges.
class TwitchUserModerationControls extends StatefulWidget {
  final TwitchModerationApiService api;
  final TwitchChatRuntimeMessage message;
  final String channelName;
  const TwitchUserModerationControls({
    super.key,
    required this.api,
    required this.message,
    required this.channelName,
  });
  @override
  State<TwitchUserModerationControls> createState() => _ControlsState();
}

class _ControlsState extends State<TwitchUserModerationControls> {
  bool? _mod;
  bool _roleBusy = false;
  bool _unconfirmedWrite = false;
  void _modChanged(bool? value) {
    if (!mounted || (value == _mod && !(value != null && _unconfirmedWrite))) {
      return;
    }
    setState(() {
      _mod = value;
      if (value != null) _unconfirmedWrite = false;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TwitchModerationMessageActions(
        api: widget.api,
        message: widget.message,
        channelName: widget.channelName,
        currentModeratorStatus: _mod,
        canModerate: () =>
            !_roleBusy &&
            !_unconfirmedWrite &&
            widget.api.canModerate?.call() != false,
      ),
      TwitchUserRoleActions(
        api: widget.api,
        userId: widget.message.source.tags['user-id']!,
        userName: widget.message.displayName,
        channelName: widget.channelName,
        onModeratorStatus: _modChanged,
        onBusyChanged: (value) {
          if (mounted) setState(() => _roleBusy = value);
        },
        onRoleWriteAccepted: () {
          if (mounted) setState(() => _unconfirmedWrite = true);
        },
      ),
      if (_unconfirmedWrite) Text(context.vio.t('角色狀態尚未確認，請先重新整理。')),
    ],
  );
}
