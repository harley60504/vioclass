// PATCH VERSION: twitch_chat_engagement_strip_prediction_extracted_stage151

import 'package:flutter/material.dart';

import '../../../models/engagement/twitch_pinned_chat.dart';
import '../../../models/engagement/twitch_prediction.dart';
import '../../theme/twitch_ui_tokens.dart';
import 'cards/twitch_pinned_message_banner.dart';
import 'cards/twitch_prediction_banner.dart';

class TwitchChatEngagementStrip extends StatelessWidget {
  final List<TwitchPinnedChatMessage> pinnedMessages;
  final TwitchPredictionSnapshot? prediction;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onOpenPrediction;
  final bool showPinned;
  final bool showPrediction;
  final String fallbackProfileImageUrl;
  final String fallbackDisplayName;
  final String fallbackUserId;
  final String fallbackLogin;

  const TwitchChatEngagementStrip({
    super.key,
    required Object? channelPoints,
    required this.pinnedMessages,
    required this.prediction,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required VoidCallback onOpenChannelPoints,
    required this.onOpenPrediction,
    this.showPinned = true,
    this.showPrediction = true,
    this.fallbackProfileImageUrl = '',
    this.fallbackDisplayName = '',
    this.fallbackUserId = '',
    this.fallbackLogin = '',
  });

  @override
  Widget build(BuildContext context) {
    final activePinned = showPinned
        ? pinnedMessages
            .where((item) => item.isActive && item.text.isNotEmpty)
            .toList(growable: false)
        : const <TwitchPinnedChatMessage>[];
    final firstPinned = activePinned.isEmpty ? null : activePinned.first;

    final currentPrediction = showPrediction ? prediction : null;
    final hasPrediction = currentPrediction != null && currentPrediction.hasPrediction;

    if (firstPinned == null && !hasPrediction && (error == null || error!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
      decoration: const BoxDecoration(
        color: TwitchUiColors.surfaceAlt,
        border: Border(bottom: BorderSide(color: TwitchUiColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (firstPinned != null) ...[
            TwitchPinnedMessageBanner(
              message: firstPinned,
              fallbackProfileImageUrl: fallbackProfileImageUrl,
              fallbackDisplayName: fallbackDisplayName,
              fallbackUserId: fallbackUserId,
              fallbackLogin: fallbackLogin,
            ),
            if (hasPrediction) const SizedBox(height: 5),
          ],
          if (hasPrediction)
            TwitchPredictionBanner(
              prediction: currentPrediction,
              onOpen: onOpenPrediction,
            ),
          if (error != null && error!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
