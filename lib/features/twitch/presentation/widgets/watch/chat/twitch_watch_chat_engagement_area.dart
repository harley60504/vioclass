//
// Pinned message / prediction engagement section used by Watch chat.

import 'package:flutter/material.dart';

import '../../../../models/engagement/twitch_pinned_chat.dart';
import '../../../../models/engagement/twitch_prediction.dart';
import '../../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../chat/twitch_chat_engagement_strip.dart';

class TwitchWatchChatEngagementArea extends StatelessWidget {
  final double maxHeight;
  final TwitchChannelPointsRuntimeSnapshot? channelPoints;
  final List<TwitchPinnedChatMessage> pinnedMessages;
  final TwitchPredictionSnapshot? prediction;
  final bool loading;
  final String? error;
  final bool showPinned;
  final bool showPrediction;
  final double fontScale;
  final String fallbackProfileImageUrl;
  final String fallbackDisplayName;
  final String fallbackUserId;
  final String fallbackLogin;
  final VoidCallback onRefresh;
  final VoidCallback onOpenChannelPoints;
  final VoidCallback onOpenPrediction;

  const TwitchWatchChatEngagementArea({
    super.key,
    required this.maxHeight,
    required this.channelPoints,
    required this.pinnedMessages,
    required this.prediction,
    required this.loading,
    required this.error,
    required this.showPinned,
    required this.showPrediction,
    this.fontScale = 1.0,
    required this.fallbackProfileImageUrl,
    required this.fallbackDisplayName,
    required this.fallbackUserId,
    required this.fallbackLogin,
    required this.onRefresh,
    required this.onOpenChannelPoints,
    required this.onOpenPrediction,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        child: TwitchChatEngagementStrip(
          channelPoints: channelPoints,
          pinnedMessages: pinnedMessages,
          prediction: prediction,
          loading: loading,
          error: error,
          onRefresh: onRefresh,
          onOpenChannelPoints: onOpenChannelPoints,
          onOpenPrediction: onOpenPrediction,
          showPinned: showPinned,
          showPrediction: showPrediction,
          fontScale: fontScale,
          fallbackProfileImageUrl: fallbackProfileImageUrl,
          fallbackDisplayName: fallbackDisplayName,
          fallbackUserId: fallbackUserId,
          fallbackLogin: fallbackLogin,
        ),
      ),
    );
  }
}
