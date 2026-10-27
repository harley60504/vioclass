import 'package:flutter/material.dart';
import '../../../models/engagement/twitch_prediction.dart';
import '../../localization/vioclass_localizations.dart';
import 'twitch_prediction_bet_helpers.dart';

class TwitchPredictionBetMetaRow extends StatelessWidget {
  final String status;
  final int totalPoints;
  final int totalUsers;
  final TwitchPredictionOutcome? viewerChoice;
  final String? timeLabel;
  final bool refreshingGqlFallback;
  final String? winnerTitle;
  const TwitchPredictionBetMetaRow({
    super.key,
    required this.status,
    required this.totalPoints,
    required this.totalUsers,
    this.viewerChoice,
    this.timeLabel,
    this.refreshingGqlFallback = false,
    this.winnerTitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = status.toUpperCase().contains('RESOLVED')
        ? const Color(0xFF76D5A3)
        : const Color(0xFFBEA6EB);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                status.toUpperCase().contains('RESOLVED')
                    ? Icons.emoji_events_outlined
                    : Icons.timelapse_rounded,
                size: 16,
                color: color,
              ),
              Text(
                context.vio.t(twitchPredictionStatusLabel(status)),
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              if (timeLabel != null)
                Text(
                  timeLabel!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${twitchPredictionFormatCompact(totalUsers)} ${context.vio.t('人')} · '
            '${twitchPredictionFormatCompact(totalPoints)} ${context.vio.t('點')}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (winnerTitle?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              '${context.vio.t('勝出')}：$winnerTitle',
              style: const TextStyle(color: Color(0xFF76D5A3)),
            ),
          ],
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
  final bool selectedForBet;
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
    this.selectedForBet = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalPoints <= 0 ? outcome.points : totalPoints;
    final percent = total <= 0 ? 0.0 : (outcome.points / total).clamp(0.0, 1.0);
    final odds = outcome.points <= 0 || total <= 0
        ? null
        : total / outcome.points;
    final accent = outcome.isWinner
        ? const Color(0xFF76D5A3)
        : outcome.color.toUpperCase() == 'BLUE'
        ? const Color(0xFF79B9F7)
        : outcome.color.toUpperCase() == 'PINK'
        ? const Color(0xFFEBA1C9)
        : const Color(0xFFBEA6EB);
    final selected = selectedByViewer || selectedForBet;
    return Semantics(
      selected: selected,
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B23),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected || outcome.isWinner
                    ? accent.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: percent, end: percent),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 450),
                    builder: (_, value, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: value,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent.withValues(
                                  alpha: selected ? 0.20 : 0.10,
                                ),
                                accent.withValues(alpha: 0.035),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            outcome.isWinner
                                ? Icons.emoji_events_outlined
                                : selected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 18,
                            color: accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              outcome.title.isEmpty
                                  ? context.vio.t('選項')
                                  : outcome.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 5,
                        children: [
                          Text(
                            '${context.vio.t('點數占比')} ${(percent * 100).round()}%',
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${twitchPredictionFormatCompact(outcome.users)} ${context.vio.t('人')}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${twitchPredictionFormatCompact(outcome.points)} ${context.vio.t('點')}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          if (odds != null)
                            Tooltip(
                              message: context.vio.t('目前估算報酬率，結算前可能變動'),
                              child: Text(
                                '${context.vio.t('預估回報')} ${odds.toStringAsFixed(1)}×',
                                style: TextStyle(color: accent, fontSize: 12),
                              ),
                            ),
                          if (outcome.viewerPoints > 0)
                            Text(
                              '${context.vio.t('我的')} ${twitchPredictionFormatCompact(outcome.viewerPoints)}',
                              style: TextStyle(color: accent, fontSize: 12),
                            ),
                          if (outcome.isWinner)
                            Text(
                              context.vio.t('勝出'),
                              style: TextStyle(color: accent, fontSize: 12),
                            ),
                          if (selectedByViewer)
                            Text(
                              context.vio.t('已提交預測'),
                              style: TextStyle(color: accent, fontSize: 12),
                            ),
                          if (selectedForBet && !selectedByViewer)
                            Text(
                              context.vio.t('已選擇'),
                              style: TextStyle(
                                color: accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (lockedByViewerChoice)
                            Text(
                              context.vio.t('已選另一選項'),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
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
    this.color = const Color(0xFFBEA6EB),
  });
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
  );
}
