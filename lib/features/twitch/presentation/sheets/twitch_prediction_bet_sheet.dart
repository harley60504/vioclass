import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/engagement/twitch_prediction_api_service.dart';
import '../../models/engagement/twitch_prediction.dart';
import '../../services/engagement/twitch_prediction_hermes_runtime_service.dart';
import '../localization/vioclass_localizations.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import 'prediction_bet/twitch_prediction_bet_helpers.dart';
import 'prediction_bet/twitch_prediction_bet_sheet_widgets.dart';

Future<void> showTwitchPredictionBetSheet({
  required BuildContext context,
  required TwitchPredictionSnapshot prediction,
  required Future<void> Function(TwitchPredictionOutcome outcome, int points)
  onBet,
  Future<TwitchPredictionSnapshot?> Function()? onRefreshPrediction,
}) {
  TwitchPredictionHermesRealtimeBus.publishPrediction(prediction);

  return showTwitchResponsiveSheet<void>(
    context: context,
    size: TwitchUnifiedSheetSize.medium,
    builder: (_) => TwitchPredictionBetSheet(
      prediction: prediction,
      onBet: onBet,
      onRefreshPrediction: onRefreshPrediction,
    ),
  );
}

class TwitchPredictionBetSheet extends StatefulWidget {
  final TwitchPredictionSnapshot prediction;
  final Future<void> Function(TwitchPredictionOutcome outcome, int points)
  onBet;
  final Future<TwitchPredictionSnapshot?> Function()? onRefreshPrediction;

  const TwitchPredictionBetSheet({
    super.key,
    required this.prediction,
    required this.onBet,
    this.onRefreshPrediction,
  });

  @override
  State<TwitchPredictionBetSheet> createState() =>
      _TwitchPredictionBetSheetState();
}

class _TwitchPredictionBetSheetState extends State<TwitchPredictionBetSheet> {
  final TextEditingController _pointsController = TextEditingController(
    text: '10',
  );

  StreamSubscription<TwitchPredictionSnapshot?>? _predictionSubscription;
  Timer? _countdownTimer;
  Timer? _gqlFallbackTimer;
  late TwitchPredictionSnapshot _visiblePrediction;
  bool _submitting = false;
  bool _refreshingGqlFallback = false;
  bool _showRefreshingGqlFallbackChip = false;

  String? _localViewerOutcomeId;
  int _localViewerPoints = 0;

  @override
  void initState() {
    super.initState();
    _visiblePrediction = _bestInitialPrediction();
    _rememberViewerPredictionFrom(_visiblePrediction);
    _predictionSubscription = TwitchPredictionHermesRealtimeBus.predictionStream
        .listen((prediction) {
          if (!mounted || prediction == null || !prediction.hasPrediction) {
            return;
          }
          if (!_samePredictionFamily(_visiblePrediction, prediction)) return;
          setState(() {
            _visiblePrediction = _mergeIncomingPrediction(prediction);
          });
        });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final hasLiveTime =
          twitchPredictionEffectiveLocksAt(_visiblePrediction) != null ||
          _visiblePrediction.endedAt != null;
      if (hasLiveTime) setState(() {});
    });
    _gqlFallbackTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _submitting || _refreshingGqlFallback) return;
      final status = _visiblePrediction.normalizedStatus;
      final shouldRefresh =
          status == 'ACTIVE' ||
          status == 'OPEN' ||
          status.contains('LOCKED') ||
          status.contains('RESOLVE_PENDING') ||
          status.isEmpty;
      if (shouldRefresh) {
        // Background safety refresh should not show the blue 「同步中」 chip.
        // Hermes outcome / odds updates are expected to be silent while the
        // user is reading or typing in the sheet.
        unawaited(_refreshPredictionFromGqlFallback(showSyncIndicator: false));
      }
    });
    unawaited(_refreshPredictionFromGqlFallback(showSyncIndicator: false));
  }

  @override
  void dispose() {
    _predictionSubscription?.cancel();
    _countdownTimer?.cancel();
    _gqlFallbackTimer?.cancel();
    _pointsController.dispose();
    super.dispose();
  }

  TwitchPredictionSnapshot _bestInitialPrediction() {
    final realtime = TwitchPredictionHermesRealtimeBus.latestPrediction;
    if (realtime != null &&
        realtime.hasPrediction &&
        _samePredictionFamily(widget.prediction, realtime)) {
      return realtime;
    }
    return widget.prediction;
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

  TwitchPredictionSnapshot _mergeIncomingPrediction(
    TwitchPredictionSnapshot incoming,
  ) {
    _rememberViewerPredictionFrom(_visiblePrediction);

    final incomingViewer = incoming.viewerOutcome;
    final incomingViewerId = twitchPredictionViewerChoiceId(incoming);
    if (incomingViewer != null && incomingViewerId.isNotEmpty) {
      _rememberViewerPredictionFrom(incoming);
      return incoming;
    }

    final localOutcomeId = _localViewerOutcomeId?.trim() ?? '';
    if (localOutcomeId.isEmpty) return incoming;

    return incoming.withViewerPrediction(
      outcomeId: localOutcomeId,
      points: _localViewerPoints,
      addToExisting: false,
    );
  }

  void _rememberViewerPredictionFrom(TwitchPredictionSnapshot prediction) {
    final viewerChoiceId = twitchPredictionViewerChoiceId(prediction).trim();
    if (viewerChoiceId.isEmpty) return;

    final viewerChoice = twitchPredictionOutcomeByIdentity(
      prediction.outcomes,
      viewerChoiceId,
    );
    final points = viewerChoice?.viewerPoints ?? 0;

    _localViewerOutcomeId = viewerChoiceId;
    if (points > 0) {
      _localViewerPoints = points;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    final prediction = _visiblePrediction;
    final status = prediction.status.toUpperCase();
    final isActive = status == 'ACTIVE' || status == 'OPEN';
    final viewerChoiceId = twitchPredictionViewerChoiceId(prediction);
    final hasViewerChoice = viewerChoiceId.isNotEmpty;
    final viewerChoice = hasViewerChoice
        ? twitchPredictionOutcomeByIdentity(prediction.outcomes, viewerChoiceId)
        : null;
    final totalPoints = prediction.totalPoints > 0
        ? prediction.totalPoints
        : prediction.outcomes.fold<int>(0, (sum, item) => sum + item.points);
    final totalUsers = prediction.totalUsers > 0
        ? prediction.totalUsers
        : prediction.outcomes.fold<int>(0, (sum, item) => sum + item.users);
    final timeLabel = twitchPredictionTimeLabel(prediction, l10n);
    final helperText = !isActive
        ? l10n.t('這個賭盤目前不能下注')
        : hasViewerChoice
        ? '${l10n.t('已下注')}「${viewerChoice?.title ?? viewerChoiceId}」，${l10n.t('只能繼續加注同一邊，另一邊已鎖住')}'
        : l10n.t('選擇下方選項送出下注');

    return SafeArea(
      child: TwitchUnifiedSheetScaffold(
        title: prediction.title.isEmpty ? l10n.t('賭盤預測') : prediction.title,
        subtitle:
            '${prediction.status.isEmpty ? 'ACTIVE' : prediction.status.toUpperCase()} · ${twitchPredictionFormatCompact(totalPoints)} ${l10n.t('點')} · ${twitchPredictionFormatCompact(totalUsers)} ${l10n.t('人')}${timeLabel == null ? '' : ' · $timeLabel'}',
        icon: Icons.how_to_vote_rounded,
        showRefresh: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8,
          ),
          child: Column(
            children: [
              TwitchPredictionBetMetaRow(
                status: prediction.status,
                totalPoints: totalPoints,
                totalUsers: totalUsers,
                viewerChoice: viewerChoice,
                timeLabel: timeLabel,
                refreshingGqlFallback: _showRefreshingGqlFallbackChip,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pointsController,
                enabled: !_submitting && isActive,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  labelText: l10n.t('下注點數'),
                  helperText: helperText,
                  helperMaxLines: 2,
                  helperStyle: TextStyle(
                    color: isActive ? Colors.white38 : Colors.orangeAccent,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: prediction.outcomes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final outcome = prediction.outcomes[index];
                    final outcomeIdentity = twitchPredictionOutcomeIdentity(
                      outcome,
                    );
                    final selectedByViewer =
                        hasViewerChoice &&
                        outcomeIdentity.isNotEmpty &&
                        outcomeIdentity == viewerChoiceId;
                    final lockedByViewerChoice =
                        isActive && hasViewerChoice && !selectedByViewer;
                    final enabled =
                        !_submitting && isActive && !lockedByViewerChoice;

                    return TwitchPredictionOutcomeBetCard(
                      outcome: outcome,
                      totalPoints: totalPoints,
                      totalUsers: totalUsers,
                      enabled: enabled,
                      submitting: _submitting,
                      selectedByViewer: selectedByViewer,
                      lockedByViewerChoice: lockedByViewerChoice,
                      onTap: () => _submit(context, outcome),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    TwitchPredictionOutcome outcome,
  ) async {
    final points = int.tryParse(_pointsController.text.trim()) ?? 0;
    if (points <= 0) return;

    final outcomeId = twitchPredictionOutcomeIdentity(outcome);
    if (outcomeId.isEmpty) return;

    setState(() {
      _submitting = true;
      _localViewerOutcomeId = outcomeId;
      _localViewerPoints += points;
    });

    try {
      await widget.onBet(outcome, points);
      final optimistic = _visiblePrediction.withViewerPrediction(
        outcomeId: outcomeId,
        points: _localViewerPoints,
        addToExisting: false,
      );
      TwitchPredictionHermesRealtimeBus.publishPrediction(optimistic);

      if (mounted) {
        setState(() {
          _visiblePrediction = optimistic;
        });
      }

      // Only user-triggered post-bet refresh should expose a visible sync chip.
      unawaited(_refreshPredictionFromGqlFallback(showSyncIndicator: true));
    } catch (_) {
      final nextPoints = _localViewerPoints - points;
      _localViewerPoints = nextPoints < 0 ? 0 : nextPoints;
      if (_localViewerPoints <= 0) {
        _localViewerOutcomeId = null;
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _refreshPredictionFromGqlFallback({
    bool showSyncIndicator = false,
  }) async {
    final loader =
        widget.onRefreshPrediction ??
        TwitchPredictionApiService.refreshLastPredictionContext;
    if (_refreshingGqlFallback) return;

    if (mounted) {
      setState(() {
        _refreshingGqlFallback = true;
        _showRefreshingGqlFallbackChip = showSyncIndicator;
      });
    }

    try {
      final refreshed = await loader();
      if (!mounted || refreshed == null || !refreshed.hasPrediction) return;
      if (!_samePredictionFamily(_visiblePrediction, refreshed)) return;

      final merged = _mergeIncomingPrediction(refreshed);
      _rememberViewerPredictionFrom(merged);
      TwitchPredictionHermesRealtimeBus.publishPrediction(merged);

      if (mounted) {
        setState(() {
          _visiblePrediction = merged;
        });
      }
    } catch (_) {
      // GQL fallback is best-effort. Keep optimistic/local state if it fails.
    } finally {
      if (mounted) {
        setState(() {
          _refreshingGqlFallback = false;
          _showRefreshingGqlFallbackChip = false;
        });
      }
    }
  }
}
