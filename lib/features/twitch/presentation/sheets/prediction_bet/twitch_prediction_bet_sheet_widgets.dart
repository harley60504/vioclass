// PATCH VERSION: twitch_prediction_bet_sheet_widgets_stage166
//
// UI widgets for the prediction bet sheet. Runtime / Hermes / GQL fallback
// logic stays in twitch_prediction_bet_sheet.dart.

import 'package:flutter/material.dart';

import '../../../models/engagement/twitch_prediction.dart';

class TwitchPredictionBetMetaRow extends StatelessWidget {
  final String status;
  final int totalPoints;
  final int totalUsers;
  final TwitchPredictionOutcome? viewerChoice;
  final String? timeLabel;
  final bool refreshingGqlFallback;

  const TwitchPredictionBetMetaRow({
    super.key,
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
        TwitchPredictionBetChip(
          label: status.isEmpty ? 'ACTIVE' : status.toUpperCase(),
        ),
        if (timeLabel != null)
          TwitchPredictionBetChip(
            label: timeLabel!,
            color: Colors.orangeAccent,
          ),
        TwitchPredictionBetChip(label: '${_formatCompact(totalPoints)} 點'),
        TwitchPredictionBetChip(label: '${_formatCompact(totalUsers)} 人'),
        if (choice != null)
          TwitchPredictionBetChip(
            label: '已下注 ${choice.title.isEmpty ? '此邊' : choice.title}',
            color: Colors.greenAccent,
          ),
        if (refreshingGqlFallback)
          const TwitchPredictionBetChip(
            label: '同步中',
            color: Color(0xFF8AB4F8),
          ),
      ],
    );
  }
}

class TwitchPredictionOutcomeBetCard extends StatelessWidget {
  final TwitchPredictionOutcome outcome;
  final int totalPoints;
  final int totalUsers;
  final bool enabled;
  final bool submitting;
  final bool selectedByViewer;
  final bool lockedByViewerChoice;
  final VoidCallback onTap;

  const TwitchPredictionOutcomeBetCard({
    super.key,
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
                      const TwitchPredictionBetChip(
                        label: 'WIN',
                        color: Colors.greenAccent,
                      ),
                    if (selectedByViewer)
                      const TwitchPredictionBetChip(
                        label: '已下注',
                        color: Colors.greenAccent,
                      ),
                    if (lockedByViewerChoice)
                      const TwitchPredictionBetChip(
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
                    TwitchPredictionBetChip(label: '${(percent * 100).round()}%'),
                    TwitchPredictionBetChip(label: '${_formatCompact(outcome.points)} 點'),
                    TwitchPredictionBetChip(label: '${_formatCompact(outcome.users)} 人'),
                    if (outcome.viewerPoints > 0)
                      TwitchPredictionBetChip(
                        label: '我的 ${_formatCompact(outcome.viewerPoints)} 點',
                        color: Colors.greenAccent,
                      ),
                    if (odds != null)
                      TwitchPredictionBetChip(
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

class TwitchPredictionBetChip extends StatelessWidget {
  final String label;
  final Color color;

  const TwitchPredictionBetChip({
    super.key,
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
  return text
      .replaceFirst(RegExp(r'\.0+$'), '')
      .replaceFirst(RegExp(r'(\.\d*[1-9])0+$'), r'$1');
}
