import 'package:flutter/material.dart';

import '../../../data/models/twitch_stream_model.dart';
import 'twitch_chat_side_panel.dart';

/// Compatibility wrapper for older call sites.
///
/// Stage 252: the visible chat UI should use the rebuilt simple chat panel.
/// Any older widget importing TwitchOfficialChatPanel will now land on the
/// same rewritten IRC + emote picker path instead of the old Frosty renderer.
class TwitchOfficialChatPanel extends StatelessWidget {
  final TwitchStreamModel stream;
  final String? clientId;
  final Future<String?> Function()? accessTokenProvider;
  final String? viewerId;
  final String? viewerLogin;

  const TwitchOfficialChatPanel({
    super.key,
    required this.stream,
    this.clientId,
    this.accessTokenProvider,
    this.viewerId,
    this.viewerLogin,
  });

  @override
  Widget build(BuildContext context) {
    return TwitchChatSidePanel(
      stream: stream,
      width: 380,
      onWidthDelta: (_) {},
      onWidthDragEnd: () {},
    );
  }
}
