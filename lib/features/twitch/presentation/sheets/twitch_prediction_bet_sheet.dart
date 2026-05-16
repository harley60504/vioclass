import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/engagement/twitch_prediction.dart';
import '../../services/engagement/twitch_prediction_hermes_runtime_service.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

Future<void> showTwitchPredictionBetSheet({
  required BuildContext context,
  required TwitchPredictionSnapshot prediction,
  required Future<void> Function(TwitchPredictionOutcome outcome, int points) onBet,
}) {
  TwitchPredictionHermesRealtimeBus.publishPrediction(prediction);

  return showTwitchResponsiveSheet<void>(
    context: context,
    size: TwitchUnifiedSheetSize.medium,
    builder: (_) => TwitchPredictionBetSheet(
      prediction: prediction,
      onBet: onBet,
    ),
  );
}

class TwitchPredictionBetSheet extends StatefulWidget {
  final TwitchPredictionSnapshot prediction;
  final Future<void> Function(TwitchPredictionOutcome outcome, int points) onBet;

  const TwitchPredictionBetSheet({
    super.key,
    required this.prediction,
    required this.onBet,
  });

  @override
  State<TwitchPredictionBetSheet> createState() => _TwitchPredictionBetSheetState();
}

class _TwitchPredictionBetSheetState extends State<TwitchPredictionBetSheet> {
  final TextEditingController _pointsController = TextEditingController(text: '10');

  StreamSubscription<TwitchPredictionSnapshot?>? _predictionSubscription;
  late TwitchPredictionSnapshot _visiblePrediction;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _visiblePrediction = _bestInitialPrediction();
    _predictionSubscription = TwitchPredictionHermesRealtimeBus.predictionStream.listen(
      (prediction) {
        if (!mounted || prediction == null || !prediction.hasPrediction) return;
        if (!_samePredictionFamily(_visiblePrediction, prediction)) return;
        setState(() {
          _visiblePrediction = prediction;
        });
      },
    );
  }

  @override
  void dispose() {
    _predictionSubscription?.cancel();
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
            subtitle: '${prediction.status.isEmpty ? 'ACTIVE' : prediction.status.toUpperCase()} · ${_formatCompact(totalPoints)} 點 · ${_formatCompact(totalUsers)} 人',
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
                      itemCount: prediction.outcomes.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index >= prediction.outcomes.length) {
                          return _PredictionDebugIdPanel(
                            prediction: prediction,
                            viewerChoiceId: viewerChoiceId,
                          );
                        }

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

    setState(() => _submitting = true);

    try {
      await widget.onBet(outcome, points);
      final outcomeId = _outcomeIdentity(outcome);
      final optimistic = _visiblePrediction.withViewerPrediction(
        outcomeId: outcomeId,
        points: points,
      );
      TwitchPredictionHermesRealtimeBus.publishPrediction(optimistic);

      if (mounted) {
        setState(() {
          _visiblePrediction = optimistic;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _PredictionMetaRow extends StatelessWidget {
  final String status;
  final int totalPoints;
  final int totalUsers;
  final TwitchPredictionOutcome? viewerChoice;

  const _PredictionMetaRow({
    required this.status,
    required this.totalPoints,
    required this.totalUsers,
    this.viewerChoice,
  });

  @override
  Widget build(BuildContext context) {
    final choice = viewerChoice;

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _PredictionChip(label: status.isEmpty ? 'ACTIVE' : status.toUpperCase()),
        _PredictionChip(label: '${_formatCompact(totalPoints)} 點'),
        _PredictionChip(label: '${_formatCompact(totalUsers)} 人'),
        if (choice != null)
          _PredictionChip(
            label: '已下注 ${choice.title.isEmpty ? '此邊' : choice.title}',
            color: Colors.greenAccent,
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

class _PredictionDebugIdPanel extends StatelessWidget {
  final TwitchPredictionSnapshot prediction;
  final String viewerChoiceId;

  const _PredictionDebugIdPanel({
    required this.prediction,
    required this.viewerChoiceId,
  });

  @override
  Widget build(BuildContext context) {
    final viewerOutcome = viewerChoiceId.trim().isEmpty ? '--' : viewerChoiceId.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111116),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF9146FF).withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bug_report_rounded,
                size: 15,
                color: Color(0xFFBF94FF),
              ),
              const SizedBox(width: 6),
              Text(
                'Prediction Debug ID',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _PredictionDebugLine(
            label: 'pid',
            value: prediction.id.trim().isEmpty ? '--' : prediction.id.trim(),
          ),
          _PredictionDebugLine(
            label: 'viewerOutcomeId',
            value: viewerOutcome,
            highlight: viewerOutcome != '--',
          ),
          const SizedBox(height: 7),
          ...prediction.outcomes.map((outcome) {
            final oid = outcome.id.trim().isEmpty ? '--' : outcome.id.trim();
            final identity = _outcomeIdentity(outcome);
            final selected = viewerChoiceId.trim().isNotEmpty &&
                identity.trim().isNotEmpty &&
                identity.trim() == viewerChoiceId.trim();
            final viewerText = outcome.viewerPoints > 0
                ? ' · viewerPoints=${outcome.viewerPoints}'
                : '';

            return _PredictionDebugLine(
              label: selected ? 'oid ✓' : 'oid',
              value: '$oid · ${outcome.title}$viewerText',
              highlight: selected,
            );
          }),
        ],
      ),
    );
  }
}

class _PredictionDebugLine extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _PredictionDebugLine({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? Colors.greenAccent : Colors.white54;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: Colors.white.withOpacity(highlight ? 0.88 : 0.62),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        style: const TextStyle(
          fontSize: 11,
          height: 1.25,
          fontFamily: 'monospace',
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
