import 'package:flutter/material.dart';

/// Legacy compatibility widget.
///
/// The standalone rebuilt chat side panel was removed in Stage 261 because the
/// watch page must use the original chat UI path:
/// TwitchWatchChatPanel -> TwitchWatchChatMessageArea -> TwitchChatMessageList.
///
/// Keep this class only so older imports do not break analyzer/build.
/// Do not route this widget to TwitchChatSidePanel.
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
    return const SizedBox.shrink();
  }
}
 