import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/engagement/twitch_pinned_chat.dart';
import '../../../models/engagement/twitch_prediction.dart';
import '../../../models/special_actions/twitch_pending_special_message.dart';
import '../../../services/chat/twitch_chat_runtime.dart';
import '../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../../services/engagement/twitch_hype_train_controller.dart';
import '../../../services/engagement/twitch_prediction_hermes_runtime_service.dart';
import '../../settings/twitch_chat_appearance_controller.dart';
import '../../sheets/twitch_chat_appearance_sheet.dart';
import '../../sheets/twitch_chat_message_context_sheet.dart';
import 'chat/twitch_watch_chat_engagement_area.dart';
import 'chat/twitch_watch_chat_header_bar.dart';
import 'chat/twitch_watch_chat_input_section.dart';
import 'chat/twitch_watch_chat_layout_metrics.dart';
import 'chat/twitch_watch_chat_message_area.dart';
import 'hype_train/twitch_hype_train_banner.dart';

class TwitchWatchChatPanel extends StatefulWidget {
  final TwitchChatRuntime? runtime;
  final String? viewerLogin;
  final String? viewerId;
  final String fallbackProfileImageUrl;
  final String fallbackDisplayName;
  final String fallbackUserId;
  final String fallbackLogin;
  final TwitchThirdPartyEmoteCacheService thirdPartyEmoteCache;
  final TwitchOfficialEmoteCacheService officialEmoteCache;
  final int emoteCount;
  final bool loadingEmotes;
  final TwitchChannelPointsRuntimeSnapshot? channelPoints;
  final TwitchPendingSpecialMessage? pendingSpecialMessage;
  final List<dynamic> pinnedMessages;
  final TwitchPredictionSnapshot? prediction;
  final TwitchHypeTrainController hypeTrainController;
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
  final VoidCallback? onOpenSpecialActions;
  final VoidCallback? onCancelPendingSpecialMessage;

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
    this.pendingSpecialMessage,
    required this.pinnedMessages,
    required this.prediction,
    required this.hypeTrainController,
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
    this.onOpenSpecialActions,
    this.onCancelPendingSpecialMessage,
  });

  @override
  State<TwitchWatchChatPanel> createState() => _TwitchWatchChatPanelState();
}

class _TwitchWatchChatPanelState extends State<TwitchWatchChatPanel> {
  static const Duration _closedPredictionAutoHideDelay = Duration(seconds: 15);
  static const Duration _manualPredictionAutoHideDelay = Duration(seconds: 15);
  static const Duration _initialPredictionSuppressWindow = Duration(
    seconds: 12,
  );

  static final Map<String, bool> _showPinnedByChannel = <String, bool>{};
  static final Map<String, bool> _showPredictionByChannel = <String, bool>{};
  static final Map<String, String> _lastPredictionIdByChannel =
      <String, String>{};

  final TwitchChatAppearanceController _appearanceController =
      TwitchChatAppearanceController();

  StreamSubscription<TwitchPredictionSnapshot?>? _predictionSubscription;
  Timer? _predictionAutoHideTimer;

  late DateTime _predictionPanelMountedAt;
  bool _hasObservedPredictionThisSession = false;

  bool showPinned = true;
  bool showPrediction = false;

  String? lastPredictionId;
  TwitchPredictionSnapshot? _visiblePrediction;

  String get _visibilityKey {
    final login = widget.fallbackLogin.trim().toLowerCase();
    if (login.isNotEmpty) return login;
    final userId = widget.fallbackUserId.trim();
    if (userId.isNotEmpty) return 'id:$userId';
    return 'unknown';
  }

  @override
  void initState() {
    super.initState();
    _predictionPanelMountedAt = DateTime.now();
    _appearanceController.load();
    _visiblePrediction = _bestPredictionForPanel(widget.prediction);
    _restoreEngagementVisibility();
    _syncClosedPredictionAutoHide(_visiblePrediction);
    _predictionSubscription = TwitchPredictionHermesRealtimeBus.predictionStream
        .listen(_handleRealtimePrediction);
  }

  @override
  void didUpdateWidget(covariant TwitchWatchChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldPrediction = _visiblePrediction ?? oldWidget.prediction;
    _visiblePrediction = _bestPredictionForPanel(widget.prediction);

    if (_visibilityKey != _keyForWidget(oldWidget)) {
      _predictionPanelMountedAt = DateTime.now();
      _hasObservedPredictionThisSession = false;
      _cancelPredictionAutoHide();
      _restoreEngagementVisibility();
      _syncClosedPredictionAutoHide(_visiblePrediction);
      return;
    }

    _syncPredictionVisibility(
      oldPrediction: oldPrediction,
      prediction: _visiblePrediction,
      sourceRealtime: false,
    );
  }

  @override
  void dispose() {
    _predictionAutoHideTimer?.cancel();
    _predictionSubscription?.cancel();
    _appearanceController.dispose();
    super.dispose();
  }

  TwitchPredictionSnapshot? _bestPredictionForPanel(
    TwitchPredictionSnapshot? fallback,
  ) {
    if (fallback == null || !fallback.hasPrediction) return fallback;

    final realtime = TwitchPredictionHermesRealtimeBus.latestPrediction;
    if (realtime != null &&
        realtime.hasPrediction &&
        _samePredictionFamily(fallback, realtime)) {
      return realtime;
    }
    return fallback;
  }

  void _handleRealtimePrediction(TwitchPredictionSnapshot? prediction) {
    if (!mounted || prediction == null || !prediction.hasPrediction) return;
    if (!_shouldAcceptRealtimePrediction(
      prediction,
      current: _visiblePrediction,
    )) {
      return;
    }

    setState(() {
      final oldPrediction = _visiblePrediction;
      _visiblePrediction = prediction;
      _syncPredictionVisibility(
        oldPrediction: oldPrediction,
        prediction: prediction,
        sourceRealtime: true,
      );
    });
  }

  bool _shouldAcceptRealtimePrediction(
    TwitchPredictionSnapshot prediction, {
    TwitchPredictionSnapshot? current,
  }) {
    final base = current ?? widget.prediction;
    if (base == null || !base.hasPrediction) return true;
    if (_samePredictionFamily(base, prediction)) return true;

    final status = prediction.normalizedStatus;
    return status == 'ACTIVE' || status == 'OPEN';
  }

  bool _samePredictionFamily(
    TwitchPredictionSnapshot current,
    TwitchPredictionSnapshot next,
  ) {
    final currentId = current.id.trim();
    final nextId = next.id.trim();
    if (currentId.isNotEmpty && nextId.isNotEmpty) {
      return currentId == nextId;
    }

    final currentTitle = current.title.trim();
    final nextTitle = next.title.trim();
    if (currentTitle.isNotEmpty && nextTitle.isNotEmpty) {
      return currentTitle == nextTitle;
    }

    return true;
  }

  void _syncPredictionVisibility({
    required TwitchPredictionSnapshot? oldPrediction,
    required TwitchPredictionSnapshot? prediction,
    required bool sourceRealtime,
  }) {
    final id = prediction?.id.trim() ?? '';
    final previousId = lastPredictionId?.trim() ?? '';
    final shouldAutoHidePrediction = _shouldAutoHidePredictionBanner(
      prediction,
    );
    final oldShouldAutoHidePrediction = _shouldAutoHidePredictionBanner(
      oldPrediction,
    );

    if (id.isNotEmpty && id != previousId) {
      lastPredictionId = id;
      _lastPredictionIdByChannel[_visibilityKey] = id;

      if (!_hasObservedPredictionThisSession) {
        _hasObservedPredictionThisSession = true;
        if (_shouldSuppressFirstPredictionObservation(
          sourceRealtime: sourceRealtime,
        )) {
          _setShowPrediction(false, persist: true, rebuild: false);
          _syncClosedPredictionAutoHide(prediction);
          return;
        }
      }

      _setShowPrediction(true, persist: true, rebuild: false);
      _syncClosedPredictionAutoHide(prediction);
      return;
    }

    if (id.isNotEmpty &&
        oldShouldAutoHidePrediction &&
        !shouldAutoHidePrediction &&
        sourceRealtime) {
      _setShowPrediction(true, persist: true, rebuild: false);
      _syncClosedPredictionAutoHide(prediction);
      return;
    }

    if (id.isNotEmpty &&
        !oldShouldAutoHidePrediction &&
        shouldAutoHidePrediction) {
      _setShowPrediction(true, persist: true, rebuild: false);
      _schedulePredictionAutoHide(
        predictionId: id,
        delay: _closedPredictionAutoHideDelay,
        requireClosed: true,
      );
      return;
    }

    _syncClosedPredictionAutoHide(prediction);
  }

  bool _shouldSuppressFirstPredictionObservation({
    required bool sourceRealtime,
  }) {
    if (!sourceRealtime) return true;
    final age = DateTime.now().difference(_predictionPanelMountedAt);
    return age <= _initialPredictionSuppressWindow;
  }

  void _restoreEngagementVisibility() {
    final key = _visibilityKey;
    final prediction = _visiblePrediction;
    final predictionId = prediction?.id.trim() ?? '';

    showPinned = _showPinnedByChannel[key] ?? true;

    if (predictionId.isNotEmpty) {
      lastPredictionId = predictionId;
      _lastPredictionIdByChannel[key] = predictionId;
      _hasObservedPredictionThisSession = true;
    } else {
      lastPredictionId = null;
      _hasObservedPredictionThisSession = false;
    }

    showPrediction = false;
    _showPredictionByChannel[key] = false;
  }

  String _keyForWidget(TwitchWatchChatPanel widget) {
    final login = widget.fallbackLogin.trim().toLowerCase();
    if (login.isNotEmpty) return login;
    final userId = widget.fallbackUserId.trim();
    if (userId.isNotEmpty) return 'id:$userId';
    return 'unknown';
  }

  void _setShowPinned(bool value) {
    _showPinnedByChannel[_visibilityKey] = value;
    setState(() => showPinned = value);
  }

  void _togglePredictionVisibility() {
    final next = !showPrediction;
    final prediction = _visiblePrediction ?? widget.prediction;
    final predictionId = prediction?.id.trim() ?? '';

    _setShowPrediction(next);

    if (next && predictionId.isNotEmpty) {
      _schedulePredictionAutoHide(
        predictionId: predictionId,
        delay: _manualPredictionAutoHideDelay,
        requireClosed: false,
      );
    }
  }

  void _setShowPrediction(
    bool value, {
    bool persist = true,
    bool rebuild = true,
  }) {
    if (persist) {
      _showPredictionByChannel[_visibilityKey] = value;
    }
    if (!value) {
      _cancelPredictionAutoHide();
    }
    if (rebuild) {
      setState(() => showPrediction = value);
    } else {
      showPrediction = value;
    }
  }

  bool _shouldAutoHidePredictionBanner(TwitchPredictionSnapshot? prediction) {
    if (prediction == null || !prediction.hasPrediction) return true;
    final status = prediction.normalizedStatus;
    if (status.isEmpty) return false;
    return status != 'ACTIVE' && status != 'OPEN';
  }

  void _syncClosedPredictionAutoHide(TwitchPredictionSnapshot? prediction) {
    if (prediction == null || !prediction.hasPrediction) {
      _cancelPredictionAutoHide();
      return;
    }

    if (_shouldAutoHidePredictionBanner(prediction)) {
      final predictionId = prediction.id.trim();
      if (predictionId.isNotEmpty) {
        _schedulePredictionAutoHide(
          predictionId: predictionId,
          delay: _closedPredictionAutoHideDelay,
          requireClosed: true,
        );
      }
    } else if (!showPrediction) {
      _cancelPredictionAutoHide();
    }
  }

  void _schedulePredictionAutoHide({
    required String predictionId,
    required Duration delay,
    required bool requireClosed,
  }) {
    if (predictionId.isEmpty) return;

    _predictionAutoHideTimer?.cancel();
    _predictionAutoHideTimer = Timer(delay, () {
      if (!mounted) return;
      final current = _visiblePrediction ?? widget.prediction;
      final currentId = current?.id.trim() ?? '';
      if (currentId != predictionId) return;
      if (requireClosed && !_shouldAutoHidePredictionBanner(current)) return;

      _setShowPrediction(false);
    });
  }

  void _cancelPredictionAutoHide() {
    _predictionAutoHideTimer?.cancel();
    _predictionAutoHideTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final currentRuntime = widget.runtime;
    final pinned = widget.pinnedMessages
        .whereType<TwitchPinnedChatMessage>()
        .toList(growable: false);
    final prediction = _visiblePrediction ?? widget.prediction;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.055)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = TwitchWatchChatLayoutMetrics.resolve(
            constraints: constraints,
            media: MediaQuery.of(context),
          );
          final predictionHasData =
              prediction != null && prediction.hasPrediction;
          final effectiveShowPinned =
              showPinned && !metrics.hideOptionalEngagement;
          final effectiveShowPrediction =
              showPrediction &&
              !metrics.hideOptionalEngagement &&
              predictionHasData;
          final showFloatingEngagement =
              effectiveShowPinned ||
              effectiveShowPrediction ||
              (widget.engagementError != null &&
                  widget.engagementError!.isNotEmpty);
          final chatFontScale = _appearanceController.fontScale;

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
                  _setShowPinned(!showPinned);
                },
                onTogglePrediction: _togglePredictionVisibility,
                onRefresh: widget.onRefreshEngagement,
                onOpenAppearance: () => showTwitchChatAppearanceSheet(
                  context: context,
                  controller: _appearanceController,
                ),
              ),
              TwitchHypeTrainBanner(controller: widget.hypeTrainController),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: TwitchWatchChatMessageArea(
                        runtime: currentRuntime,
                        thirdPartyEmoteCache: widget.thirdPartyEmoteCache,
                        officialEmoteCache: widget.officialEmoteCache,
                        appearanceListenable: _appearanceController,
                        fontScale: chatFontScale,
                        compact: metrics.verticalCompact,
                        onOpenMessageContext: (message) =>
                            showTwitchChatMessageContextSheet(
                              context: context,
                              selectedMessage: message,
                              messages: currentRuntime?.messages ?? const [],
                              thirdPartyEmotes: widget.thirdPartyEmoteCache,
                              fontScale: chatFontScale,
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
                          prediction: effectiveShowPrediction
                              ? prediction
                              : null,
                          loading: widget.loadingEngagement,
                          error: widget.engagementError,
                          showPinned: effectiveShowPinned,
                          showPrediction: effectiveShowPrediction,
                          fontScale: chatFontScale,
                          fallbackProfileImageUrl:
                              widget.fallbackProfileImageUrl,
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
                pendingSpecialMessage: widget.pendingSpecialMessage,
                messageController: widget.messageController,
                loadingEmotes: widget.loadingEmotes,
                compact: metrics.compactUtilityBar,
                enabled: currentRuntime?.connected ?? false,
                sending: widget.sending,
                onOpenChannelPoints: widget.onOpenChannelPoints,
                onOpenEmotes: widget.onOpenEmotes,
                onOpenSpecialActions: widget.onOpenSpecialActions,
                onCancelPendingSpecialMessage:
                    widget.onCancelPendingSpecialMessage,
                onSend: widget.onSend,
              ),
            ],
          );
        },
      ),
    );
  }
}
