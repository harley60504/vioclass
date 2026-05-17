// PATCH VERSION: twitch_watch_chat_layout_metrics_stage150
//
// Pure layout calculations for Watch chat. Keeping these numbers here makes
// TwitchWatchChatPanel read like composition instead of a block of geometry.

import 'package:flutter/material.dart';

class TwitchWatchChatLayoutMetrics {
  final bool keyboardVisible;
  final bool verticalCompact;
  final bool ultraVerticalCompact;
  final bool compactWidth;
  final bool hideOptionalEngagement;
  final double maxUsableEngagementHeight;

  const TwitchWatchChatLayoutMetrics({
    required this.keyboardVisible,
    required this.verticalCompact,
    required this.ultraVerticalCompact,
    required this.compactWidth,
    required this.hideOptionalEngagement,
    required this.maxUsableEngagementHeight,
  });

  bool get compactUtilityBar => compactWidth || verticalCompact;

  static TwitchWatchChatLayoutMetrics resolve({
    required BoxConstraints constraints,
    required MediaQueryData media,
  }) {
    final keyboardVisible = media.viewInsets.bottom > 0;
    final verticalCompact = constraints.maxHeight < 520 ||
        (media.orientation == Orientation.landscape && constraints.maxHeight < 620) ||
        keyboardVisible;
    final ultraVerticalCompact = constraints.maxHeight < 410;
    final compactWidth = constraints.maxWidth < 300;

    final maxEngagementHeight = ultraVerticalCompact
        ? (constraints.maxHeight * 0.34).clamp(110.0, 180.0).toDouble()
        : verticalCompact
            ? (constraints.maxHeight * 0.38).clamp(130.0, 230.0).toDouble()
            : (constraints.maxHeight * 0.42).clamp(160.0, 320.0).toDouble();

    final headerHeight = verticalCompact ? 42.0 : 54.0;
    final utilityBarHeight = (compactWidth || verticalCompact) ? 41.0 : 48.0;
    final inputBarHeight = verticalCompact ? 48.0 : 54.0;
    final fixedChromeHeight = headerHeight + utilityBarHeight + inputBarHeight;
    final minMessageListHeight = keyboardVisible ? 84.0 : 56.0;
    final maxUsableEngagementHeight = (constraints.maxHeight -
            fixedChromeHeight -
            minMessageListHeight)
        .clamp(0.0, maxEngagementHeight)
        .toDouble();
    final minScrollableEngagementHeight = verticalCompact ? 72.0 : 88.0;
    final hideOptionalEngagement =
        keyboardVisible || maxUsableEngagementHeight < minScrollableEngagementHeight;

    return TwitchWatchChatLayoutMetrics(
      keyboardVisible: keyboardVisible,
      verticalCompact: verticalCompact,
      ultraVerticalCompact: ultraVerticalCompact,
      compactWidth: compactWidth,
      hideOptionalEngagement: hideOptionalEngagement,
      maxUsableEngagementHeight: maxUsableEngagementHeight,
    );
  }
}
