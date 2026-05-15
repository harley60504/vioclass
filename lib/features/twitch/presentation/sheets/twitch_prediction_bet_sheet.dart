import 'package:flutter/material.dart';

import '../../models/engagement/twitch_prediction.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';


Future<void> showTwitchPredictionBetSheet({
  required BuildContext context,
  required TwitchPredictionSnapshot prediction,
  required Future<void> Function(TwitchPredictionOutcome outcome, int points) onBet,
}) {
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

  bool _submitting = false;

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prediction = widget.prediction;
    final status = prediction.status.toUpperCase();
    final isActive = status == 'ACTIVE' || status == 'OPEN';
    final totalPoints = prediction.totalPoints > 0
        ? prediction.totalPoints
        : prediction.outcomes.fold<int>(0, (sum, item) => sum + item.points);
    final totalUsers = prediction.totalUsers > 0
        ? prediction.totalUsers
        : prediction.outcomes.fold<int>(0, (sum, item) => sum + item.users);

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
                    helperText: isActive ? '選擇下方選項送出下注' : '這個賭盤目前不能下注',
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
                      return _PredictionOutcomeBetCard(
                        outcome: outcome,
                        totalPoints: totalPoints,
                        totalUsers: totalUsers,
                        enabled: !_submitting && isActive,
                        submitting: _submitting,
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
      if (context.mounted) {
        Navigator.of(context).pop();
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

  const _PredictionMetaRow({
    required this.status,
    required this.totalPoints,
    required this.totalUsers,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _PredictionChip(label: status.isEmpty ? 'ACTIVE' : status.toUpperCase()),
        _PredictionChip(label: '${_formatCompact(totalPoints)} 點'),
        _PredictionChip(label: '${_formatCompact(totalUsers)} 人'),
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
  final VoidCallback onTap;

  const _PredictionOutcomeBetCard({
    required this.outcome,
    required this.totalPoints,
    required this.totalUsers,
    required this.enabled,
    required this.submitting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalPoints <= 0 ? outcome.points : totalPoints;
    final percent = total <= 0 ? 0.0 : (outcome.points / total).clamp(0.0, 1.0);
    final odds = outcome.points <= 0 || total <= 0 ? null : total / outcome.points;

    return Material(
      color: const Color(0xFF1F1F27),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: outcome.isWinner
                  ? Colors.greenAccent.withOpacity(0.55)
                  : const Color(0xFF9146FF).withOpacity(0.26),
            ),
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
                  const SizedBox(width: 8),
                  Icon(
                    enabled ? Icons.arrow_forward_ios_rounded : Icons.lock_rounded,
                    color: enabled ? Colors.white38 : Colors.white24,
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
                    outcome.isWinner ? Colors.greenAccent : const Color(0xFF9146FF),
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
