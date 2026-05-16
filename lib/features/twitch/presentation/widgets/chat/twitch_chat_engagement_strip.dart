import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/engagement/twitch_pinned_chat.dart';
import '../../../models/engagement/twitch_prediction.dart';

class TwitchChatEngagementStrip extends StatelessWidget {
  final List<TwitchPinnedChatMessage> pinnedMessages;
  final TwitchPredictionSnapshot? prediction;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onOpenPrediction;
  final bool showPinned;
  final bool showPrediction;

  const TwitchChatEngagementStrip({
    super.key,
    required Object? channelPoints,
    required this.pinnedMessages,
    required this.prediction,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required VoidCallback onOpenChannelPoints,
    required this.onOpenPrediction,
    this.showPinned = true,
    this.showPrediction = true,
  });

  @override
  Widget build(BuildContext context) {
    final activePinned = showPinned
        ? pinnedMessages
            .where((item) => item.isActive && item.text.isNotEmpty)
            .toList(growable: false)
        : const <TwitchPinnedChatMessage>[];
    final firstPinned = activePinned.isEmpty ? null : activePinned.first;

    final currentPrediction = showPrediction ? prediction : null;
    final hasPrediction = currentPrediction != null && currentPrediction.hasPrediction;

    if (firstPinned == null && !hasPrediction && (error == null || error!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: const BoxDecoration(
        color: Color(0xFF111116),
        border: Border(bottom: BorderSide(color: Color(0xFF2D2D35))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (firstPinned != null) ...[
            _PinnedCard(message: firstPinned),
            const SizedBox(height: 4),
          ],
          if (hasPrediction) ...[
            _PredictionCard(
              prediction: currentPrediction,
              onOpen: onOpenPrediction,
            ),
          ],
          if (error != null && error!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PinnedCard extends StatelessWidget {
  final TwitchPinnedChatMessage message;

  const _PinnedCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final sender = message.sender?.displayName ?? message.pinnedBy?.displayName ?? 'Pinned';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2315),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.push_pin_rounded, color: Color(0xFFFFD166), size: 14),
              SizedBox(width: 7),
              Text(
                '置頂留言',
                style: TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            message.text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFFE3A3),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pinned by $sender',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final TwitchPredictionSnapshot prediction;
  final VoidCallback onOpen;

  const _PredictionCard({
    required this.prediction,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final status = prediction.normalizedStatus.isEmpty
        ? 'ACTIVE'
        : prediction.normalizedStatus;
    final outcomes = prediction.outcomes.take(2).toList(growable: false);
    final left = outcomes.isNotEmpty ? outcomes[0] : null;
    final right = outcomes.length >= 2 ? outcomes[1] : null;
    final totalPoints = prediction.totalPoints > 0
        ? prediction.totalPoints
        : outcomes.fold<int>(0, (sum, outcome) => sum + outcome.points);
    final resolved = prediction.isResolvedLike;
    final canceled = prediction.isCanceledLike;
    final active = status == 'ACTIVE' || status == 'OPEN';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onOpen,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xE61A1328),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF9146FF).withOpacity(0.42)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9146FF).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFBF94FF).withOpacity(0.32),
                    ),
                  ),
                  child: Icon(
                    canceled
                        ? Icons.remove_circle_outline_rounded
                        : resolved
                            ? Icons.emoji_events_rounded
                            : Icons.how_to_vote_rounded,
                    color: canceled ? Colors.orangeAccent : const Color(0xFFBF94FF),
                    size: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prediction.title.isEmpty ? '賭盤預測' : prediction.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF0E8FF),
                      fontSize: 13,
                      height: 1.16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _PredictionStatusPill(
                  label: status,
                  locksAt: prediction.locksAt,
                  active: active,
                  resolved: resolved,
                  canceled: canceled,
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              ],
            ),
            if (left != null && right != null) ...[
              const SizedBox(height: 9),
              _PredictionSplitBar(
                left: left,
                right: right,
                totalPoints: totalPoints,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PredictionStatusPill extends StatefulWidget {
  final String label;
  final DateTime? locksAt;
  final bool active;
  final bool resolved;
  final bool canceled;

  const _PredictionStatusPill({
    required this.label,
    required this.locksAt,
    required this.active,
    required this.resolved,
    required this.canceled,
  });

  @override
  State<_PredictionStatusPill> createState() => _PredictionStatusPillState();
}

class _PredictionStatusPillState extends State<_PredictionStatusPill> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _PredictionStatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locksAt != widget.locksAt ||
        oldWidget.active != widget.active ||
        oldWidget.resolved != widget.resolved ||
        oldWidget.canceled != widget.canceled) {
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;

    if (!_shouldTick) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_shouldTick) {
        _timer?.cancel();
        _timer = null;
      }
      setState(() {});
    });
  }

  bool get _shouldTick {
    final locksAt = widget.locksAt;
    if (!widget.active || widget.resolved || widget.canceled || locksAt == null) {
      return false;
    }
    return locksAt.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final locksAt = widget.locksAt;
    final remaining = locksAt == null ? null : locksAt.difference(DateTime.now());
    final displayLabel = widget.active &&
            !widget.resolved &&
            !widget.canceled &&
            remaining != null
        ? remaining.inSeconds > 0
            ? '關盤 ${_formatLockCountdown(remaining)}'
            : '即將關盤'
        : widget.label;
    final urgent = widget.active &&
        !widget.resolved &&
        !widget.canceled &&
        remaining != null &&
        remaining.inSeconds <= 30;
    final color = widget.canceled
        ? Colors.orangeAccent
        : widget.resolved
            ? Colors.greenAccent
            : urgent
                ? Colors.orangeAccent
                : const Color(0xFFBF94FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.34)),
      ),
      child: Text(
        displayLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PredictionSplitBar extends StatelessWidget {
  final TwitchPredictionOutcome left;
  final TwitchPredictionOutcome right;
  final int totalPoints;

  const _PredictionSplitBar({
    required this.left,
    required this.right,
    required this.totalPoints,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalPoints <= 0 ? left.points + right.points : totalPoints;
    final leftPercent = total <= 0
        ? 0.5
        : (left.points / total).clamp(0.0, 1.0).toDouble();
    final rightPercent = (1.0 - leftPercent).clamp(0.0, 1.0).toDouble();
    final leftLabel = '${(leftPercent * 100).round()}%';
    final rightLabel = '${(rightPercent * 100).round()}%';

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 30,
        child: Row(
          children: [
            Expanded(
              flex: (leftPercent * 1000).round().clamp(1, 999).toInt(),
              child: Container(
                height: 30,
                color: const Color(0xFF2B7FFF).withOpacity(left.isWinner ? 0.96 : 0.78),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  leftLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Container(width: 1, color: const Color(0xFF111116)),
            Expanded(
              flex: (rightPercent * 1000).round().clamp(1, 999).toInt(),
              child: Container(
                height: 30,
                color: const Color(0xFFFF4B6E).withOpacity(right.isWinner ? 0.96 : 0.78),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  rightLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _OutcomeSide { left, right }

class _OutcomeSummary extends StatelessWidget {
  final TwitchPredictionOutcome outcome;
  final int totalPoints;
  final int totalUsers;
  final _OutcomeSide side;

  const _OutcomeSummary({
    required this.outcome,
    required this.totalPoints,
    required this.totalUsers,
    required this.side,
  });

  @override
  Widget build(BuildContext context) {
    final accent = side == _OutcomeSide.left
        ? const Color(0xFF5BA1FF)
        : const Color(0xFFFF6B85);
    final total = totalPoints <= 0 ? outcome.points : totalPoints;
    final odds = outcome.points <= 0 || total <= 0 ? null : total / outcome.points;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: outcome.isWinner
              ? Colors.greenAccent.withOpacity(0.62)
              : accent.withOpacity(0.34),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (outcome.isWinner)
                const _TinyOutcomeBadge(label: 'WIN', color: Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _TinyOutcomeBadge(
                label: '${_formatCompact(outcome.points)} 點',
                color: accent,
              ),
              _TinyOutcomeBadge(
                label: '${_formatCompact(outcome.users)} 人',
                color: const Color(0xFFD9E4FF),
              ),
              if (odds != null)
                _TinyOutcomeBadge(
                  label: '${odds.toStringAsFixed(odds >= 10 ? 1 : 2)}x',
                  color: const Color(0xFFBFA8FF),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SingleOutcomeBar extends StatelessWidget {
  final TwitchPredictionOutcome outcome;
  final int totalPoints;

  const _SingleOutcomeBar({
    required this.outcome,
    required this.totalPoints,
  });

  @override
  Widget build(BuildContext context) {
    final odds =
        outcome.points <= 0 || totalPoints <= 0 ? null : totalPoints / outcome.points;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              outcome.title.isEmpty ? 'Outcome' : outcome.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _TinyOutcomeBadge(
                label: '${_formatCompact(outcome.points)} 點',
                color: const Color(0xFF8A68FF),
              ),
              _TinyOutcomeBadge(
                label: '${_formatCompact(outcome.users)} 人',
                color: const Color(0xFF5BA1FF),
              ),
              if (odds != null)
                _TinyOutcomeBadge(
                  label: '${odds.toStringAsFixed(odds >= 10 ? 1 : 2)}x',
                  color: const Color(0xFFFF6B85),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyOutcomeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TinyOutcomeBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.36)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;

  const _MiniStat({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _formatCompact(int value) {
  final absValue = value.abs();
  if (absValue >= 1000000000) {
    final v = value / 1000000000;
    return '${v.toStringAsFixed(v.abs() >= 10 ? 1 : 2)}B';
  }
  if (absValue >= 1000000) {
    final v = value / 1000000;
    return '${v.toStringAsFixed(v.abs() >= 10 ? 1 : 2)}M';
  }
  if (absValue >= 1000) {
    final v = value / 1000;
    return '${v.toStringAsFixed(v.abs() >= 10 ? 1 : 2)}k';
  }
  return value.toString();
}

String _formatLockCountdown(Duration duration) {
  final safeSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final seconds = safeSeconds % 60;

  String two(int value) => value.toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:${two(minutes)}:${two(seconds)}';
  }
  return '$minutes:${two(seconds)}';
}
