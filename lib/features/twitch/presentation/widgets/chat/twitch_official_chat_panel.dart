import 'package:flutter/material.dart';

import 'twitch_chat_side_panel.dart';

class TwitchOfficialChatPanel extends StatelessWidget {
  final dynamic stream;
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
      accessTokenProvider: accessTokenProvider,
      viewerLogin: viewerLogin,
    );
  }
}
