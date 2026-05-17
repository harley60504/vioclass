// PATCH VERSION: twitch_watch_chat_panel_stage196_floating_engagement_overlay

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
import 'chat/twitch_watch_chat_engagement_area.dart';
import 'chat/twitch_watch_chat_header_bar.dart';
import 'chat/twitch_watch_chat_input_section.dart';
import 'chat/twitch_watch_chat_layout_metrics.dart';
import 'chat/twitch_watch_chat_message_area.dart';

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
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF111018),
            Color(0xFF0E0E10),
          ],
        ),
        border: Border(
          left: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(-8, 0),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = TwitchWatchChatLayoutMetrics.resolve(
            constraints: constraints,
            media: MediaQuery.of(context),
          );
          final predictionHasData = prediction != null && prediction.hasPrediction;
          final effectiveShowPinned = showPinned && !metrics.hideOptionalEngagement;
          final effectiveShowPrediction = showPrediction &&
              !metrics.hideOptionalEngagement &&
              predictionHasData;
          final showFloatingEngagement = effectiveShowPinned ||
              effectiveShowPrediction ||
              (widget.engagementError != null && widget.engagementError!.isNotEmpty);

          return Column(
            children: [
              TwitchWatchChatHeaderBar(
                connected: currentRuntime?.connected ?? false,
                showPinned: effectiveShowPinned,
                showPrediction: showPrediction,
                predictionVisible: effectiveShowPrediction,
                hasPinned: pinned.isNotEmpty && !metrics.hideOptionalEngagement,
                hasPrediction: predictionHasData,
                loading: widget.loadingEngagement,
                compact: metrics.verticalCompact,
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
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: TwitchWatchChatMessageArea(
                        runtime: currentRuntime,
                        thirdPartyEmoteCache: widget.thirdPartyEmoteCache,
                        appearanceListenable: _appearanceController,
                        fontScale: _appearanceController.fontScale,
                        compact: metrics.verticalCompact,
                        onOpenMessageContext: (message) =>
                            showTwitchChatMessageContextSheet(
                          context: context,
                          selectedMessage: message,
                          messages: currentRuntime?.messages ?? const [],
                        ),
                      ),
                    ),
                    if (showFloatingEngagement)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: TwitchWatchChatEngagementArea(
                          maxHeight: metrics.maxUsableEngagementHeight,
                          channelPoints: widget.channelPoints,
                          pinnedMessages: pinned,
                          prediction: effectiveShowPrediction ? prediction : null,
                          loading: widget.loadingEngagement,
                          error: widget.engagementError,
                          showPinned: effectiveShowPinned,
                          showPrediction: effectiveShowPrediction,
                          fallbackProfileImageUrl: widget.fallbackProfileImageUrl,
                          fallbackDisplayName: widget.fallbackDisplayName,
                          fallbackUserId: widget.fallbackUserId,
                          fallbackLogin: widget.fallbackLogin,
                          onRefresh: widget.onRefreshEngagement,
                          onOpenChannelPoints: widget.onOpenChannelPoints,
                          onOpenPrediction: widget.onOpenPrediction,
                        ),
                      ),
                  ],
                ),
              ),
              TwitchWatchChatInputSection(
                channelPoints: widget.channelPoints,
                messageController: widget.messageController,
                loadingEmotes: widget.loadingEmotes,
                compact: metrics.compactUtilityBar,
                enabled: currentRuntime?.connected ?? false,
                sending: widget.sending,
                onOpenChannelPoints: widget.onOpenChannelPoints,
                onOpenEmotes: widget.onOpenEmotes,
                onSend: widget.onSend,
              ),
            ],
          );
        },
      ),
    );
  }
}
