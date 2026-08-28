//
// UI widgets for the prediction bet sheet. Runtime / Hermes / GQL fallback
// logic stays in twitch_prediction_bet_sheet.dart.

import 'package:flutter/material.dart';

import '../../../models/engagement/twitch_prediction.dart';
import '../../theme/twitch_ui_tokens.dart';
import 'twitch_prediction_bet_helpers.dart';

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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TwitchUiColors.sheet.cardFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TwitchUiColors.sheet.backplate.border),
      ),
      child: Wrap(
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
          TwitchPredictionBetChip(
            label: '${twitchPredictionFormatCompact(totalPoints)} 點',
          ),
          TwitchPredictionBetChip(
            label: '${twitchPredictionFormatCompact(totalUsers)} 人',
          ),
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
      ),
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
    final odds = outcome.points <= 0 || total <= 0
        ? null
        : total / outcome.points;
    final accent = outcome.isWinner || selectedByViewer
        ? Colors.greenAccent
        : lockedByViewerChoice
        ? Colors.white38
        : TwitchUiColors.sheet.backplate.foreground;
    final borderColor = outcome.isWinner
        ? Colors.greenAccent.withValues(alpha: 0.58)
        : selectedByViewer
        ? Colors.greenAccent.withValues(alpha: 0.58)
        : lockedByViewerChoice
        ? Colors.white.withValues(alpha: 0.10)
        : TwitchUiColors.sheet.backplate.borderActive;
    final opacity = lockedByViewerChoice ? 0.62 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  selectedByViewer
                      ? const Color(0xFF162C22).withValues(alpha: 0.98)
                      : TwitchUiColors.sheet.cardFillActive,
                  TwitchUiColors.sheet.shellGradientEnd,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(
                    alpha: enabled || selectedByViewer ? 0.18 : 0.04,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.26),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        outcome.title.isEmpty ? '選項' : outcome.title,
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
                        label: '勝出',
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
                          ? Colors.white60
                          : Colors.white24,
                      size: 15,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 9,
                    backgroundColor: TwitchUiColors.sheet.cardBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      outcome.isWinner || selectedByViewer
                          ? Colors.greenAccent
                          : TwitchUiColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    TwitchPredictionBetChip(
                      label: '${(percent * 100).round()}%',
                    ),
                    TwitchPredictionBetChip(
                      label:
                          '${twitchPredictionFormatCompact(outcome.points)} 點',
                    ),
                    TwitchPredictionBetChip(
                      label:
                          '${twitchPredictionFormatCompact(outcome.users)} 人',
                    ),
                    if (outcome.viewerPoints > 0)
                      TwitchPredictionBetChip(
                        label:
                            '我的 ${twitchPredictionFormatCompact(outcome.viewerPoints)} 點',
                        color: Colors.greenAccent,
                      ),
                    if (odds != null)
                      TwitchPredictionBetChip(
                        label:
                            '${odds.toStringAsFixed(odds >= 10 ? 1 : 2)}x 賠率',
                        color: TwitchUiColors.sheet.backplate.foreground,
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
    this.color = TwitchUiColors.primarySoft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8),
        ],
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
