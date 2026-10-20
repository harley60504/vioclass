import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/engagement/twitch_prediction_api_service.dart';
import '../../models/engagement/twitch_prediction.dart';
import '../../services/engagement/twitch_prediction_hermes_runtime_service.dart';
import '../localization/vioclass_localizations.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import '../widgets/shared/twitch_text_field.dart';
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
  String? _selectedOutcomeId;
  String? _feedback;
  int _predictionRevision = 0;
  int _syncFailures = 0;

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
          _predictionRevision++;
          setState(() {
            _syncFailures = 0;
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
    if (twitchPredictionStatusRank(incoming) <
        twitchPredictionStatusRank(_visiblePrediction)) {
      return _visiblePrediction;
    }
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
    final isActive = twitchPredictionCanBet(prediction);
    final viewerChoiceId = twitchPredictionViewerChoiceId(prediction);
    final choiceId = viewerChoiceId.isNotEmpty
        ? viewerChoiceId
        : _selectedOutcomeId ?? '';
    final chosen = twitchPredictionOutcomeByIdentity(
      prediction.outcomes,
      choiceId,
    );
    final totalPoints = prediction.totalPoints > 0
        ? prediction.totalPoints
        : prediction.outcomes.fold<int>(0, (sum, item) => sum + item.points);
    final totalUsers = prediction.totalUsers > 0
        ? prediction.totalUsers
        : prediction.outcomes.fold<int>(0, (sum, item) => sum + item.users);
    final status =
        !isActive &&
            (prediction.normalizedStatus == 'ACTIVE' ||
                prediction.normalizedStatus == 'OPEN')
        ? 'LOCKED'
        : prediction.status;
    return SafeArea(
      child: TwitchUnifiedSheetScaffold(
        title: prediction.title.isEmpty ? l10n.t('賭盤預測') : prediction.title,
        icon: Icons.how_to_vote_rounded,
        showRefresh: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 430;
            final content = Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Column(
                mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  TwitchPredictionBetMetaRow(
                    status: status,
                    totalPoints: totalPoints,
                    totalUsers: totalUsers,
                    viewerChoice: prediction.viewerOutcome,
                    winnerTitle: prediction.winningOutcome?.title,
                    timeLabel: twitchPredictionTimeLabel(prediction, l10n),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    fit: compact ? FlexFit.loose : FlexFit.tight,
                    child: ListView.separated(
                      shrinkWrap: compact,
                      physics: compact
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: prediction.outcomes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final outcome = prediction.outcomes[index];
                        final identity = twitchPredictionOutcomeIdentity(
                          outcome,
                        );
                        final mine =
                            viewerChoiceId.isNotEmpty &&
                            identity == viewerChoiceId;
                        final locked = viewerChoiceId.isNotEmpty && !mine;
                        return TwitchPredictionOutcomeBetCard(
                          key: ValueKey(identity),
                          outcome: outcome,
                          totalPoints: totalPoints,
                          totalUsers: totalUsers,
                          enabled: isActive && !_submitting && !locked,
                          submitting: _submitting,
                          selectedByViewer: mine,
                          lockedByViewerChoice: locked,
                          selectedForBet: identity == choiceId,
                          onTap: () => setState(() {
                            _selectedOutcomeId = identity;
                            _feedback = null;
                          }),
                        );
                      },
                    ),
                  ),
                  if (_feedback != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _feedback!,
                        style: const TextStyle(
                          color: Color(0xFFEBA1C9),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (_syncFailures >= 2)
                    Row(
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 15,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.t('連線暫時中斷，保留目前結果'),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.t('重試'),
                          onPressed: _refreshingGqlFallback
                              ? null
                              : () => _refreshPredictionFromGqlFallback(
                                  showSyncIndicator: true,
                                ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                        ),
                      ],
                    ),
                  if (isActive) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.035),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            chosen == null
                                ? l10n.t('先選擇一個選項')
                                : '${l10n.t('選擇')}：${chosen.title}',
                            style: TextStyle(
                              color: chosen == null
                                  ? Colors.white54
                                  : const Color(0xFFBEA6EB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.t('快速選擇'),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final amount in [10, 100, 1000])
                                ChoiceChip(
                                  selected:
                                      int.tryParse(_pointsController.text) ==
                                      amount,
                                  onSelected: _submitting
                                      ? null
                                      : (_) => setState(() {
                                          _pointsController.text = '$amount';
                                          _feedback = null;
                                        }),
                                  label: Text('$amount'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: TwitchTextField(
                                  controller: _pointsController,
                                  enabled: !_submitting,
                                  onChanged: (_) => setState(() {}),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                    labelText: l10n.t('下注點數'),
                                    suffixText: l10n.t('點'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                onPressed: !_submitting && chosen != null
                                    ? () => _submit(context, chosen)
                                    : null,
                                child: _submitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        l10n.t(
                                          viewerChoiceId.isEmpty
                                              ? '確認下注'
                                              : '加注',
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_showRefreshingGqlFallbackChip)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                ],
              ),
            );
            return compact ? SingleChildScrollView(child: content) : content;
          },
        ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    TwitchPredictionOutcome outcome,
  ) async {
    if (_submitting || !twitchPredictionCanBet(_visiblePrediction)) return;
    final points = int.tryParse(_pointsController.text.trim()) ?? 0;
    if (points <= 0) {
      setState(() => _feedback = context.vio.t('請輸入有效點數'));
      return;
    }

    final outcomeId = twitchPredictionOutcomeIdentity(outcome);
    if (outcomeId.isEmpty) return;
    final mine = twitchPredictionViewerChoiceId(_visiblePrediction);
    if (mine.isNotEmpty && mine != outcomeId) return;
    final confirmedPointsBefore = _localViewerPoints;

    setState(() {
      _submitting = true;
      _feedback = null;
    });

    try {
      await widget.onBet(outcome, points);
      if (!mounted) return;
      _localViewerOutcomeId = outcomeId;
      final expectedPoints = confirmedPointsBefore + points;
      if (_localViewerPoints < expectedPoints) {
        _localViewerPoints = expectedPoints;
      }
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

      // Post-bet reconciliation uses a quiet progress line, not debug text.
      unawaited(_refreshPredictionFromGqlFallback(showSyncIndicator: true));
    } catch (_) {
      if (mounted) setState(() => _feedback = context.vio.t('下注未成功，請稍後重試'));
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
    final revision = _predictionRevision;

    if (mounted) {
      setState(() {
        _refreshingGqlFallback = true;
        _showRefreshingGqlFallbackChip = showSyncIndicator;
      });
    }

    try {
      final refreshed = await loader();
      if (!mounted || refreshed == null || !refreshed.hasPrediction) return;
      // Do not let a slow fallback replace a newer Hermes update.
      if (revision != _predictionRevision) return;
      if (!_samePredictionFamily(_visiblePrediction, refreshed)) return;

      final merged = _mergeIncomingPrediction(refreshed);
      _rememberViewerPredictionFrom(merged);
      TwitchPredictionHermesRealtimeBus.publishPrediction(merged);
      final latest = TwitchPredictionHermesRealtimeBus.latestPrediction;
      final visible =
          latest != null &&
              latest.hasPrediction &&
              _samePredictionFamily(merged, latest)
          ? _mergeIncomingPrediction(latest)
          : merged;

      if (mounted) {
        setState(() {
          _visiblePrediction = visible;
          _syncFailures = 0;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _syncFailures++);
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
