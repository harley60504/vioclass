// PATCH VERSION: twitch_prediction_banner_stage192_glass_card
//
// Extracted prediction banner UI from TwitchChatEngagementStrip. Keep the
// prediction card, countdown pill and split bar here so engagement strip remains
// a simple composition layer.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../models/engagement/twitch_prediction.dart';
import '../../../theme/twitch_ui_tokens.dart';

class TwitchPredictionBanner extends StatelessWidget {
  final TwitchPredictionSnapshot prediction;
  final VoidCallback onOpen;

  const TwitchPredictionBanner({
    super.key,
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
    final effectiveLocksAt = _effectiveLocksAt(prediction);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                const Color(0xFF251640).withOpacity(0.97),
                const Color(0xFF171420).withOpacity(0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TwitchUiColors.primary.withOpacity(0.44)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: TwitchUiColors.primary.withOpacity(0.20),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.32),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: TwitchUiColors.primary.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: TwitchUiColors.primarySoft.withOpacity(0.38),
                      ),
                    ),
                    child: Icon(
                      canceled
                          ? Icons.remove_circle_outline_rounded
                          : resolved
                              ? Icons.emoji_events_rounded
                              : Icons.how_to_vote_rounded,
                      color: canceled ? Colors.orangeAccent : TwitchUiColors.primarySoft,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      prediction.title.isEmpty ? '賭盤預測' : prediction.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF3EAFE),
                        fontSize: TwitchUiFontSize.cardTitle,
                        height: 1.16,
                        fontWeight: TwitchUiFontWeight.heavy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PredictionStatusPill(
                    label: status,
                    locksAt: effectiveLocksAt,
                    active: active,
                    resolved: resolved,
                    canceled: canceled,
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                ],
              ),
              if (left != null && right != null) ...[
                const SizedBox(height: 10),
                _PredictionSplitBar(
                  left: left,
                  right: right,
                  totalPoints: totalPoints,
                ),
              ],
            ],
          ),
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
                : TwitchUiColors.primarySoft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        border: Border.all(color: color.withOpacity(0.40)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withOpacity(0.14),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(
        displayLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: TwitchUiFontSize.chip,
          fontWeight: TwitchUiFontWeight.heavy,
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
      child: Container(
        height: 31,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: (leftPercent * 1000).round().clamp(1, 999).toInt(),
              child: Container(
                height: 31,
                color: TwitchUiColors.blue.withOpacity(left.isWinner ? 0.96 : 0.82),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  '${(leftPercent * 100).round()}%',
                  style: const TextStyle(
                    color: TwitchUiColors.textPrimary,
                    fontSize: 10,
                    fontWeight: TwitchUiFontWeight.heavy,
                  ),
                ),
              ),
            ),
            Container(width: 1, color: Colors.black.withOpacity(0.30)),
            Expanded(
              flex: (rightPercent * 1000).round().clamp(1, 999).toInt(),
              child: Container(
                height: 31,
                color: TwitchUiColors.red.withOpacity(right.isWinner ? 0.96 : 0.82),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '${(rightPercent * 100).round()}%',
                  style: const TextStyle(
                    color: TwitchUiColors.textPrimary,
                    fontSize: 10,
                    fontWeight: TwitchUiFontWeight.heavy,
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

DateTime? _effectiveLocksAt(TwitchPredictionSnapshot prediction) {
  final explicit = prediction.locksAt;
  if (explicit != null) return explicit;

  final createdAt = prediction.createdAt ??
      _readDateFromRaw(prediction.rawPrediction, const <String>[
        'created_at',
        'createdAt',
      ]);
  if (createdAt == null) return null;

  final windowSeconds = _readIntFromRaw(prediction.rawPrediction, const <String>[
    'prediction_window_seconds',
    'predictionWindowSeconds',
  ]);
  if (windowSeconds == null || windowSeconds <= 0) return null;

  return createdAt.add(Duration(seconds: windowSeconds));
}

DateTime? _readDateFromRaw(Map<String, dynamic>? raw, List<String> keys) {
  if (raw == null) return null;
  for (final key in keys) {
    final value = raw[key];
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) continue;
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;
  }
  return null;
}

int? _readIntFromRaw(Map<String, dynamic>? raw, List<String> keys) {
  if (raw == null) return null;
  for (final key in keys) {
    final value = raw[key];
    if (value == null) continue;
    if (value is int) return value;
    if (value is num) return value.round();
    final parsed = int.tryParse(value.toString().replaceAll(',', '').trim());
    if (parsed != null) return parsed;
  }
  return null;
}

String _formatLockCountdown(Duration duration) {
  final safeSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final seconds = safeSeconds % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
  return '$minutes:${two(seconds)}';
}
