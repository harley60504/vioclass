import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/engagement/twitch_prediction.dart';
import '../../services/engagement/twitch_prediction_hermes_runtime_service.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

Future<void> showTwitchPredictionBetSheet({
  required BuildContext context,
  required TwitchPredictionSnapshot prediction,
  required Future<void> Function(TwitchPredictionOutcome outcome, int points) onBet,
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
  final Future<void> Function(TwitchPredictionOutcome outcome, int points) onBet;
  final Future<TwitchPredictionSnapshot?> Function()? onRefreshPrediction;

  const TwitchPredictionBetSheet({
    super.key,
    required this.prediction,
    required this.onBet,
    this.onRefreshPrediction,
  });

  @override
  State<TwitchPredictionBetSheet> createState() => _TwitchPredictionBetSheetState();
}

class _TwitchPredictionBetSheetState extends State<TwitchPredictionBetSheet> {
  final TextEditingController _pointsController = TextEditingController(text: '10');

  StreamSubscription<TwitchPredictionSnapshot?>? _predictionSubscription;
  Timer? _countdownTimer;
  late TwitchPredictionSnapshot _visiblePrediction;
  bool _submitting = false;
  bool _refreshingGqlFallback = false;

  // Local viewer bet draft/optimistic state.
  //
  // Hermes event-updated packets often carry global outcome totals but may not
  // immediately include the current viewer's prediction. Without keeping this
  // local state, each realtime update can overwrite the sheet and make the UI
  // look like the user's selected side / amount disappeared.
  String? _localViewerOutcomeId;
  int _localViewerPoints = 0;

  @override
  void initState() {
    super.initState();
    _visiblePrediction = _bestInitialPrediction();
    _rememberViewerPredictionFrom(_visiblePrediction);
    _predictionSubscription = TwitchPredictionHermesRealtimeBus.predictionStream.listen(
      (prediction) {
        if (!mounted || prediction == null || !prediction.hasPrediction) return;
        if (!_samePredictionFamily(_visiblePrediction, prediction)) return;
        setState(() {
          _visiblePrediction = _mergeIncomingPrediction(prediction);
        });
      },
    );
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final hasLiveTime = _visiblePrediction.locksAt != null ||
          _visiblePrediction.endedAt != null;
      if (hasLiveTime) setState(() {});
    });
  }

  @override
  void dispose() {
    _predictionSubscription?.cancel();
    _countdownTimer?.cancel();
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
    final incomingViewerId = _viewerChoiceId(incoming);
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
    final viewerChoiceId = _viewerChoiceId(prediction).trim();
    if (viewerChoiceId.isEmpty) return;

    final viewerChoice = _outcomeByIdentity(prediction.outcomes, viewerChoiceId);
    final points = viewerChoice?.viewerPoints ?? 0;

    _localViewerOutcomeId = viewerChoiceId;
    if (points > 0) {
      _localViewerPoints = points;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prediction = _visiblePrediction;
    final status = prediction.status.toUpperCase();
    final isActive = status == 'ACTIVE' || status == 'OPEN';
    final viewerChoiceId = _viewerChoiceId(prediction);
    final hasViewerChoice = viewerChoiceId.isNotEmpty;
    final viewerChoice = hasViewerChoice
        ? _outcomeByIdentity(prediction.outcomes, viewerChoiceId)
        : null;
    final totalPoints = prediction.totalPoints > 0
        ? prediction.totalPoints
        : prediction.outcomes.fold<int>(0, (sum, item) => sum + item.points);
    final totalUsers = prediction.totalUsers > 0
        ? prediction.totalUsers
        : prediction.outcomes.fold<int>(0, (sum, item) => sum + item.users);
    final timeLabel = _predictionTimeLabel(prediction);
    final helperText = !isActive
        ? '這個賭盤目前不能下注'
        : hasViewerChoice
            ? '已下注「${viewerChoice?.title ?? viewerChoiceId}」，只能繼續加注同一邊，另一邊已鎖住'
            : '選擇下方選項送出下注';

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return TwitchUnifiedSheetScaffold(
            title: prediction.title.isEmpty ? '賭盤預測' : prediction.title,
            subtitle: '${prediction.status.isEmpty ? 'ACTIVE' : prediction.status.toUpperCase()} · ${_formatCompact(totalPoints)} 點 · ${_formatCompact(totalUsers)} 人${timeLabel == null ? '' : ' · $timeLabel'}',
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
                  _PredictionMetaRow(
                    status: prediction.status,
                    totalPoints: totalPoints,
                    totalUsers: totalUsers,
                    viewerChoice: viewerChoice,
                    timeLabel: timeLabel,
                    refreshingGqlFallback: _refreshingGqlFallback,
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
                      labelText: '下注點數',
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
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final outcome = prediction.outcomes[index];
                        final outcomeIdentity = _outcomeIdentity(outcome);
                        final selectedByViewer = hasViewerChoice &&
                            outcomeIdentity.isNotEmpty &&
                            outcomeIdentity == viewerChoiceId;
                        final lockedByViewerChoice = isActive &&
                            hasViewerChoice &&
                            !selectedByViewer;
                        final enabled = !_submitting &&
                            isActive &&
                            !lockedByViewerChoice;

                        return _PredictionOutcomeBetCard(
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
          );
        },
      ),
    );
  }

  Future<void> _submit(BuildContext context, TwitchPredictionOutcome outcome) async {
    final points = int.tryParse(_pointsController.text.trim()) ?? 0;
    if (points <= 0) return;

    final outcomeId = _outcomeIdentity(outcome);
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

      unawaited(_refreshPredictionFromGqlFallback());
    } catch (_) {
      _localViewerPoints = (_localViewerPoints - points).clamp(0, 1 << 62).toInt();
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

  Future<void> _refreshPredictionFromGqlFallback() async {
    final loader = widget.onRefreshPrediction;
    if (loader == null || _refreshingGqlFallback) return;

    if (mounted) {
      setState(() => _refreshingGqlFallback = true);
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
        setState(() => _refreshingGqlFallback = false);
      }
    }
  }
}

class _PredictionMetaRow extends StatelessWidget {
  final String status;
  final int totalPoints;
  final int totalUsers;
  final TwitchPredictionOutcome? viewerChoice;
  final String? timeLabel;
  final bool refreshingGqlFallback;

  const _PredictionMetaRow({
    required this.status,
    required this.totalPoints,
    required this.totalUsers,
    this.viewerChoice,
    this.timeLabel,
    this.refreshingGqlFallback = false,
  });

  @override
  Widget build(BuildContext context) {
    final choice = viewerChoice;

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _PredictionChip(label: status.isEmpty ? 'ACTIVE' : status.toUpperCase()),
        if (timeLabel != null)
          _PredictionChip(
            label: timeLabel!,
            color: Colors.orangeAccent,
          ),
        _PredictionChip(label: '${_formatCompact(totalPoints)} 點'),
        _PredictionChip(label: '${_formatCompact(totalUsers)} 人'),
        if (choice != null)
          _PredictionChip(
            label: '已下注 ${choice.title.isEmpty ? '此邊' : choice.title}',
            color: Colors.greenAccent,
          ),
        if (refreshingGqlFallback)
          const _PredictionChip(
            label: '同步中',
            color: Color(0xFF8AB4F8),
          ),
      ],
    );
  }
}

class _PredictionOutcomeBetCard extends StatelessWidget {
  final TwitchPredictionOutcome outcome;
  final int totalPoints;
  final int totalUsers;
  final bool enabled;
  final bool submitting;
  final bool selectedByViewer;
  final bool lockedByViewerChoice;
  final VoidCallback onTap;

  const _PredictionOutcomeBetCard({
    required this.outcome,
    required this.totalPoints,
    required this.totalUsers,
    required this.enabled,
    required this.submitting,
    required this.selectedByViewer,
    required this.lockedByViewerChoice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalPoints <= 0 ? outcome.points : totalPoints;
    final percent = total <= 0 ? 0.0 : (outcome.points / total).clamp(0.0, 1.0);
    final odds = outcome.points <= 0 || total <= 0 ? null : total / outcome.points;
    final borderColor = outcome.isWinner
        ? Colors.greenAccent.withOpacity(0.55)
        : selectedByViewer
            ? Colors.greenAccent.withOpacity(0.55)
            : lockedByViewerChoice
                ? Colors.white.withOpacity(0.10)
                : const Color(0xFF9146FF).withOpacity(0.26);
    final cardColor = lockedByViewerChoice
        ? const Color(0xFF17171D)
        : selectedByViewer
            ? const Color(0xFF1A2A22)
            : const Color(0xFF1F1F27);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: lockedByViewerChoice ? 0.62 : 1.0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        outcome.title.isEmpty ? 'Outcome' : outcome.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (outcome.isWinner)
                      const _PredictionChip(
                        label: 'WIN',
                        color: Colors.greenAccent,
                      ),
                    if (selectedByViewer)
                      const _PredictionChip(
                        label: '已下注',
                        color: Colors.greenAccent,
                      ),
                    if (lockedByViewerChoice)
                      const _PredictionChip(
                        label: '已鎖住',
                        color: Colors.white54,
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      selectedByViewer
                          ? Icons.check_circle_rounded
                          : enabled
                              ? Icons.arrow_forward_ios_rounded
                              : Icons.lock_rounded,
                      color: selectedByViewer
                          ? Colors.greenAccent
                          : enabled
                              ? Colors.white38
                              : Colors.white24,
                      size: 15,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      outcome.isWinner || selectedByViewer
                          ? Colors.greenAccent
                          : const Color(0xFF9146FF),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _PredictionChip(label: '${(percent * 100).round()}%'),
                    _PredictionChip(label: '${_formatCompact(outcome.points)} 點'),
                    _PredictionChip(label: '${_formatCompact(outcome.users)} 人'),
                    if (outcome.viewerPoints > 0)
                      _PredictionChip(
                        label: '我的 ${_formatCompact(outcome.viewerPoints)} 點',
                        color: Colors.greenAccent,
                      ),
                    if (odds != null)
                      _PredictionChip(
                        label: '${odds.toStringAsFixed(odds >= 10 ? 1 : 2)}x 賠率',
                        color: const Color(0xFFBFA8FF),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PredictionChip extends StatelessWidget {
  final String label;
  final Color color;

  const _PredictionChip({
    required this.label,
    this.color = const Color(0xFFBF94FF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.34)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _viewerChoiceId(TwitchPredictionSnapshot prediction) {
  final direct = prediction.viewerOutcomeId?.trim();
  if (direct != null && direct.isNotEmpty) return direct;

  for (final outcome in prediction.outcomes) {
    if (outcome.isViewerChoice || outcome.viewerPoints > 0) {
      return _outcomeIdentity(outcome);
    }
  }

  return '';
}

TwitchPredictionOutcome? _outcomeByIdentity(
  List<TwitchPredictionOutcome> outcomes,
  String identity,
) {
  final safeIdentity = identity.trim();
  if (safeIdentity.isEmpty) return null;

  for (final outcome in outcomes) {
    if (_outcomeIdentity(outcome) == safeIdentity) return outcome;
  }

  return null;
}

String _outcomeIdentity(TwitchPredictionOutcome outcome) {
  final id = outcome.id.trim();
  if (id.isNotEmpty) return id;
  return outcome.title.trim();
}

String? _predictionTimeLabel(TwitchPredictionSnapshot prediction) {
  final status = prediction.normalizedStatus;
  final now = DateTime.now();

  if (status == 'ACTIVE' || status == 'OPEN') {
    final locksAt = prediction.locksAt;
    if (locksAt == null) return null;
    final remaining = locksAt.difference(now);
    if (remaining.inSeconds > 0) {
      return '鎖盤剩 ${_formatDuration(remaining)}';
    }
    return '已鎖盤';
  }

  if (prediction.isLockedLike) {
    final endedAt = prediction.endedAt;
    if (endedAt != null) {
      final remaining = endedAt.difference(now);
      if (remaining.inSeconds > 0) {
        return '結算剩 ${_formatDuration(remaining)}';
      }
    }
    return '等待結算';
  }

  final endedAt = prediction.endedAt;
  if (endedAt != null) {
    return '結算 ${_formatClock(endedAt)}';
  }

  return null;
}

String _formatDuration(Duration value) {
  final totalSeconds = value.inSeconds <= 0 ? 0 : value.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String _formatClock(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatCompact(int value) {
  if (value >= 1000000000) {
    final text = (value / 1000000000).toStringAsFixed(value >= 10000000000 ? 1 : 2);
    return '${_trimTrailingZero(text)}B';
  }
  if (value >= 1000000) {
    final text = (value / 1000000).toStringAsFixed(value >= 10000000 ? 1 : 2);
    return '${_trimTrailingZero(text)}M';
  }
  if (value >= 1000) {
    final text = (value / 1000).toStringAsFixed(value >= 10000 ? 1 : 2);
    return '${_trimTrailingZero(text)}k';
  }
  return value.toString();
}

String _trimTrailingZero(String text) {
  return text.replaceFirst(RegExp(r'\.0+$'), '').replaceFirst(RegExp(r'(\.\d*[1-9])0+$'), r'$1');
}
