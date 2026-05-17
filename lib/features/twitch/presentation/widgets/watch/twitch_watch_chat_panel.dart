// PATCH VERSION: twitch_watch_chat_panel_stage149_wired_extracted_ui

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/engagement/twitch_pinned_chat.dart';
import '../../../models/engagement/twitch_prediction.dart';
import '../../../services/chat/twitch_chat_runtime.dart';
import '../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../settings/twitch_chat_appearance_controller.dart';
import '../../sheets/twitch_chat_appearance_sheet.dart';
import '../../sheets/twitch_chat_message_context_sheet.dart';
import '../chat/twitch_chat_empty_view.dart';
import '../chat/twitch_chat_engagement_strip.dart';
import '../chat/twitch_chat_input_bar.dart';
import '../chat/twitch_chat_message_list.dart';
import 'chat/twitch_watch_chat_header_bar.dart';
import 'chat/twitch_watch_chat_utility_bar.dart';

class TwitchWatchChatPanel extends StatefulWidget {
  final TwitchChatRuntime? runtime;
  final String? viewerLogin;
  final String? viewerId;
  final String fallbackProfileImageUrl;
  final String fallbackDisplayName;
  final String fallbackUserId;
  final String fallbackLogin;
  final TwitchThirdPartyEmoteCacheService thirdPartyEmoteCache;
  final int emoteCount;
  final bool loadingEmotes;
  final TwitchChannelPointsRuntimeSnapshot? channelPoints;
  final List<dynamic> pinnedMessages;
  final TwitchPredictionSnapshot? prediction;
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
  State<TwitchWatchChatPanel> createState() => _TwitchWatchChatPanelState();
}

class _TwitchWatchChatPanelState extends State<TwitchWatchChatPanel> {
  final TwitchChatAppearanceController _appearanceController =
      TwitchChatAppearanceController();

  bool showPinned = true;
  bool showPrediction = true;

  String? lastPredictionId;

  @override
  void initState() {
    super.initState();
    unawaited(_appearanceController.load());
  }

  @override
  void didUpdateWidget(covariant TwitchWatchChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final prediction = widget.prediction;
    final oldPrediction = oldWidget.prediction;
    final id = prediction?.id ?? '';
    final shouldAutoHidePrediction = _shouldAutoHidePredictionBanner(prediction);
    final oldShouldAutoHidePrediction =
        _shouldAutoHidePredictionBanner(oldPrediction);

    if (id.isNotEmpty && id != lastPredictionId) {
      lastPredictionId = id;
      showPrediction = !shouldAutoHidePrediction;
      return;
    }

    if (id.isNotEmpty &&
        oldShouldAutoHidePrediction &&
        !shouldAutoHidePrediction) {
      showPrediction = true;
      return;
    }

    if (id.isNotEmpty &&
        !oldShouldAutoHidePrediction &&
        shouldAutoHidePrediction) {
      showPrediction = false;
    }
  }

  @override
  void dispose() {
    _appearanceController.dispose();
    super.dispose();
  }

  bool _shouldAutoHidePredictionBanner(TwitchPredictionSnapshot? prediction) {
    if (prediction == null || !prediction.hasPrediction) return true;
    final status = prediction.normalizedStatus;
    if (status.isEmpty) return false;
    return status != 'ACTIVE' && status != 'OPEN';
  }

  @override
  Widget build(BuildContext context) {
    final currentRuntime = widget.runtime;
    final pinned = widget.pinnedMessages
        .whereType<TwitchPinnedChatMessage>()
        .toList(growable: false);
    final prediction = widget.prediction;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111116),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final media = MediaQuery.of(context);
          final keyboardVisible = media.viewInsets.bottom > 0;
          final verticalCompact = constraints.maxHeight < 520 ||
              (media.orientation == Orientation.landscape &&
                  constraints.maxHeight < 620) ||
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
          final predictionHasData = prediction != null && prediction.hasPrediction;
          final effectiveShowPinned = showPinned && !hideOptionalEngagement;
          final effectiveShowPrediction =
              showPrediction && !hideOptionalEngagement && predictionHasData;

          return Column(
            children: [
              TwitchWatchChatHeaderBar(
                connected: currentRuntime?.connected ?? false,
                showPinned: effectiveShowPinned,
                showPrediction: showPrediction,
                predictionVisible: effectiveShowPrediction,
                hasPinned: pinned.isNotEmpty && !hideOptionalEngagement,
                hasPrediction: predictionHasData,
                loading: widget.loadingEngagement,
                compact: verticalCompact,
                onTogglePinned: () {
                  setState(() => showPinned = !showPinned);
                },
                onTogglePrediction: () {
                  setState(() => showPrediction = !showPrediction);
                },
                onRefresh: widget.onRefreshEngagement,
                onOpenAppearance: () => showTwitchChatAppearanceSheet(
                  context: context,
                  controller: _appearanceController,
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxUsableEngagementHeight),
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  physics: const ClampingScrollPhysics(),
                  child: TwitchChatEngagementStrip(
                    channelPoints: widget.channelPoints,
                    pinnedMessages: pinned,
                    prediction: effectiveShowPrediction ? prediction : null,
                    loading: widget.loadingEngagement,
                    error: widget.engagementError,
                    onRefresh: widget.onRefreshEngagement,
                    onOpenChannelPoints: widget.onOpenChannelPoints,
                    onOpenPrediction: widget.onOpenPrediction,
                    showPinned: effectiveShowPinned,
                    showPrediction: effectiveShowPrediction,
                    fallbackProfileImageUrl: widget.fallbackProfileImageUrl,
                    fallbackDisplayName: widget.fallbackDisplayName,
                    fallbackUserId: widget.fallbackUserId,
                    fallbackLogin: widget.fallbackLogin,
                  ),
                ),
              ),
              Expanded(
                child: currentRuntime == null
                    ? const TwitchChatEmptyView()
                    : AnimatedBuilder(
                        animation: Listenable.merge([
                          currentRuntime,
                          _appearanceController,
                        ]),
                        builder: (context, _) {
                          return TwitchChatMessageList(
                            runtime: currentRuntime,
                            thirdPartyEmoteCache: widget.thirdPartyEmoteCache,
                            fontScale: _appearanceController.fontScale,
                            compact: verticalCompact,
                            onOpenMessageContext: (message) =>
                                showTwitchChatMessageContextSheet(
                              context: context,
                              selectedMessage: message,
                              messages: currentRuntime.messages,
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                left: false,
                right: false,
                top: false,
                bottom: true,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF111116),
                    border: Border(top: BorderSide(color: Color(0xFF2D2D35))),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TwitchWatchChatUtilityBar(
                        channelPoints: widget.channelPoints,
                        loadingEmotes: widget.loadingEmotes,
                        compact: compactWidth || verticalCompact,
                        onOpenChannelPoints: widget.onOpenChannelPoints,
                        onOpenEmotes: widget.onOpenEmotes,
                      ),
                      TwitchChatInputBar(
                        controller: widget.messageController,
                        enabled: currentRuntime?.connected ?? false,
                        sending: widget.sending,
                        compact: verticalCompact,
                        onSend: widget.onSend,
                        onOpenEmotes: widget.onOpenEmotes,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
