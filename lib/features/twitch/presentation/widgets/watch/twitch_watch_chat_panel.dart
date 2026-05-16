import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/engagement/twitch_pinned_chat.dart';
import '../../../models/engagement/twitch_prediction.dart';
import '../../../services/chat/twitch_chat_runtime.dart';
import '../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../chat/twitch_chat_empty_view.dart';
import '../chat/twitch_chat_engagement_strip.dart';
import '../chat/twitch_chat_input_bar.dart';
import '../chat/twitch_chat_message_list.dart';
import '../shared/twitch_default_channel_points_icon.dart';
import '../channel_points/twitch_channel_points_sheet_utils.dart';
import '../../settings/twitch_chat_appearance_controller.dart';
import '../../sheets/twitch_chat_appearance_sheet.dart';
import '../../sheets/twitch_chat_message_context_sheet.dart';

class TwitchWatchChatPanel extends StatefulWidget {
  final TwitchChatRuntime? runtime;
  final String? viewerLogin;
  final String? viewerId;
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
    return prediction.isResolvedLike || prediction.isLockedLike;
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
          final predictionHasData = prediction != null && prediction.hasPrediction;
          final hasActivePinned = pinned.any(
            (item) => item.isActive && item.text.trim().isNotEmpty,
          );
          final wantsPinned = showPinned && hasActivePinned;
          final wantsPrediction = showPrediction && predictionHasData;
          final hasEngagementError = (widget.engagementError ?? '').isNotEmpty;
          final estimatedPinnedHeight = wantsPinned ? 86.0 : 0.0;
          final estimatedPredictionHeight = wantsPrediction ? 104.0 : 0.0;
          final estimatedErrorHeight = hasEngagementError ? 26.0 : 0.0;
          final estimatedSpacing =
              [wantsPinned, wantsPrediction, hasEngagementError]
                      .where((value) => value)
                      .length >
                  1
              ? 8.0
              : 0.0;
          final estimatedEngagementHeight = (
            estimatedPinnedHeight +
                estimatedPredictionHeight +
                estimatedErrorHeight +
                estimatedSpacing,
          ).$1.clamp(0.0, maxEngagementHeight).toDouble();
          final availableMessageListHeight = constraints.maxHeight -
              headerHeight -
              utilityBarHeight -
              inputBarHeight -
              estimatedEngagementHeight;
          final minMessageListHeight = keyboardVisible ? 84.0 : 72.0;
          final hideOptionalEngagement = keyboardVisible ||
              (estimatedEngagementHeight > 0 &&
                  availableMessageListHeight < minMessageListHeight);
          final effectiveShowPinned = showPinned && !hideOptionalEngagement;
          final effectiveShowPrediction =
              showPrediction && !hideOptionalEngagement && predictionHasData;

          return Column(
            children: [
              _ChatHeader(
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
                constraints: BoxConstraints(maxHeight: maxEngagementHeight),
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
                      _ChatUtilityBar(
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

class _ChatHeader extends StatelessWidget {
  final bool connected;
  final bool showPinned;
  final bool showPrediction;
  final bool predictionVisible;
  final bool hasPinned;
  final bool hasPrediction;
  final bool loading;
  final bool compact;
  final VoidCallback onTogglePinned;
  final VoidCallback onTogglePrediction;
  final VoidCallback onRefresh;
  final VoidCallback onOpenAppearance;

  const _ChatHeader({
    required this.connected,
    required this.showPinned,
    required this.showPrediction,
    required this.predictionVisible,
    required this.hasPinned,
    required this.hasPrediction,
    required this.loading,
    required this.compact,
    required this.onTogglePinned,
    required this.onTogglePrediction,
    required this.onRefresh,
    required this.onOpenAppearance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 42 : 54,
      padding: EdgeInsets.fromLTRB(12, compact ? 5 : 8, 10, compact ? 5 : 8),
      decoration: const BoxDecoration(
        color: Color(0xFF111116),
        border: Border(bottom: BorderSide(color: Color(0xFF2D2D35))),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.circle : Icons.circle_outlined,
            size: 10,
            color: connected ? Colors.greenAccent : Colors.white38,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'STREAM CHAT',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
          _HeaderToggleButton(
            tooltip: showPinned ? '隱藏置頂留言' : '顯示置頂留言',
            icon: Icons.push_pin_rounded,
            active: showPinned && hasPinned,
            enabled: hasPinned,
            onTap: onTogglePinned,
          ),
          const SizedBox(width: 5),
          _HeaderToggleButton(
            tooltip: predictionVisible
                ? '隱藏賭盤通知'
                : hasPrediction
                    ? '顯示賭盤通知'
                    : '沒有賭盤',
            icon: Icons.how_to_vote_rounded,
            active: predictionVisible,
            enabled: hasPrediction,
            onTap: onTogglePrediction,
          ),
          const SizedBox(width: 5),
          IconButton(
            tooltip: '聊天室字體',
            visualDensity: VisualDensity.compact,
            onPressed: onOpenAppearance,
            icon: const Icon(Icons.format_size_rounded, size: 19),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: '刷新互動',
            visualDensity: VisualDensity.compact,
            onPressed: loading ? null : onRefresh,
            icon: loading
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _HeaderToggleButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  const _HeaderToggleButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFBF94FF) : Colors.white38;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF9146FF).withOpacity(0.20)
                : const Color(0xFF1B1B22),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? const Color(0xFF9146FF).withOpacity(0.38)
                  : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Icon(icon, size: 16, color: enabled ? color : Colors.white24),
        ),
      ),
    );
  }
}

class _ChatUtilityBar extends StatelessWidget {
  final TwitchChannelPointsRuntimeSnapshot? channelPoints;
  final bool loadingEmotes;
  final bool compact;
  final VoidCallback onOpenChannelPoints;
  final VoidCallback onOpenEmotes;

  const _ChatUtilityBar({
    required this.channelPoints,
    required this.loadingEmotes,
    required this.compact,
    required this.onOpenChannelPoints,
    required this.onOpenEmotes,
  });

  @override
  Widget build(BuildContext context) {
    final balance = channelPoints?.balance;
    final pointsIconUrl = channelPoints?.pointsIconUrl;
    final hasClaim = (channelPoints?.availableClaimId ?? '').isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(10, compact ? 7 : 9, 10, compact ? 4 : 5),
      child: Row(
        children: [
          _ChannelPointsCompactButton(
            balance: balance,
            iconUrl: pointsIconUrl,
            hasClaim: hasClaim,
            compact: compact,
            onTap: onOpenChannelPoints,
          ),
          if (!compact) const Spacer() else const SizedBox(width: 6),
          _UtilityButton(
            tooltip: '貼圖',
            icon: Icons.tag_faces_rounded,
            compact: compact,
            onTap: onOpenEmotes,
          ),
        ],
      ),
    );
  }
}

class _ChannelPointsCompactButton extends StatelessWidget {
  final int? balance;
  final String? iconUrl;
  final bool hasClaim;
  final bool compact;
  final VoidCallback onTap;

  const _ChannelPointsCompactButton({
    required this.balance,
    required this.iconUrl,
    required this.hasClaim,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = balance == null ? '--' : formatChannelPointCompactNumber(balance!);
    final fullLabel = balance == null ? '--' : formatChannelPointFullNumber(balance!);

    return Tooltip(
      message: hasClaim ? '忠誠點數 $fullLabel · 有可領獎勵' : '忠誠點數 $fullLabel',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: compact ? 30 : 34,
          padding: EdgeInsets.fromLTRB(compact ? 8 : 10, 0, compact ? 9 : 12, 0),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B22),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: hasClaim
                  ? const Color(0xFF9146FF).withOpacity(0.48)
                  : Colors.white.withOpacity(0.07),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChannelPointsIcon(
                iconUrl: iconUrl,
                hasClaim: hasClaim,
              ),
              if (balance != null) ...[
                SizedBox(width: compact ? 5 : 7),
                Text(
                  label,
                  style: TextStyle(
                    color: hasClaim ? const Color(0xFFD9C5FF) : Colors.white70,
                    fontSize: compact ? 11 : 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}

class _ChannelPointsIcon extends StatelessWidget {
  final String? iconUrl;
  final bool hasClaim;

  const _ChannelPointsIcon({
    required this.iconUrl,
    required this.hasClaim,
  });

  @override
  Widget build(BuildContext context) {
    final url = iconUrl?.trim();

    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: 18,
          height: 18,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(),
        ),
      );
    }

    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    if (hasClaim) {
      return const Icon(
        Icons.card_giftcard_rounded,
        color: Color(0xFFBF94FF),
        size: 17,
      );
    }

    return const TwitchDefaultChannelPointsIcon(size: 18);
  }
}


class _UtilityButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool compact;
  final VoidCallback? onTap;

  const _UtilityButton({
    required this.tooltip,
    required this.icon,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 34,
          height: compact ? 30 : 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B22),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Icon(icon, size: compact ? 15 : 17, color: Colors.white60),
        ),
      ),
    );
  }
}