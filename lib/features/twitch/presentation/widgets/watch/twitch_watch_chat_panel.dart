import 'package:flutter/material.dart';

import '../../../data/models/twitch_stream_model.dart';
import '../chat/twitch_chat_side_panel.dart';

class TwitchWatchChatPanel extends StatelessWidget {
  final dynamic runtime;
  final String? viewerLogin;
  final String? viewerId;
  final String fallbackProfileImageUrl;
  final String fallbackDisplayName;
  final String fallbackUserId;
  final String fallbackLogin;
  final dynamic thirdPartyEmoteCache;
  final dynamic officialEmoteCache;
  final int emoteCount;
  final bool loadingEmotes;
  final dynamic channelPoints;
  final List<dynamic> pinnedMessages;
  final dynamic prediction;
  final bool loadingEngagement;
  final String? engagementError;
  final TextEditingController messageController;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onOpenEmotes;
  final VoidCallback onRefreshEmotes;
  final VoidCallback onRefreshEngagement;
  final VoidCallback onOpenChannelPoints;
  final VoidCallback onOpenPrediction;

  const TwitchWatchChatPanel({
    super.key,
    required this.runtime,
    required this.viewerLogin,
    required this.viewerId,
    this.fallbackProfileImageUrl = '',
    this.fallbackDisplayName = '',
    this.fallbackUserId = '',
    this.fallbackLogin = '',
    required this.thirdPartyEmoteCache,
    required this.officialEmoteCache,
    required this.emoteCount,
    required this.loadingEmotes,
    required this.channelPoints,
    required this.pinnedMessages,
    required this.prediction,
    required this.loadingEngagement,
    required this.engagementError,
    required this.messageController,
    required this.sending,
    required this.onSend,
    required this.onOpenEmotes,
    required this.onRefreshEmotes,
    required this.onRefreshEngagement,
    required this.onOpenChannelPoints,
    required this.onOpenPrediction,
  });

  @override
  Widget build(BuildContext context) {
    final login = fallbackLogin.trim();
    final displayName = fallbackDisplayName.trim();

    final stream = TwitchStreamModel(
      userId: fallbackUserId.trim(),
      userLogin: login,
      userName: displayName.isNotEmpty ? displayName : login,
      profileImageUrl: fallbackProfileImageUrl.trim(),
    );

    return TwitchChatSidePanel(
      stream: stream,
      width: 380,
      onWidthDelta: (_) {},
      onWidthDragEnd: () {},
    );
  }
}
