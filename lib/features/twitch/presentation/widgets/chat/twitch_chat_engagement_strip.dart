// PATCH VERSION: twitch_chat_engagement_strip_streamnook_pinned_avatar_stage144

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/engagement/twitch_pinned_chat.dart';
import '../../../models/engagement/twitch_prediction.dart';
import '../shared/twitch_cached_image_layer.dart';

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
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
      decoration: const BoxDecoration(
        color: Color(0xFF111116),
        border: Border(bottom: BorderSide(color: Color(0xFF25252C))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (firstPinned != null) ...[
            _PinnedCard(message: firstPinned),
            if (hasPrediction) const SizedBox(height: 5),
          ],
          if (hasPrediction)
            _PredictionCard(
              prediction: currentPrediction,
              onOpen: onOpenPrediction,
            ),
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
    final senderUser = message.sender ?? message.pinnedBy;
    final sender = _cleanName(senderUser?.displayName) ?? 'Pinned';
    final pinnedBy = _cleanName(message.pinnedBy?.displayName);
    final senderColor = _parseUserColor(senderUser?.chatColor) ?? const Color(0xFFBF94FF);
    final avatarUrl = senderUser?.profileImageUrl.trim() ?? '';
    final metaText = pinnedBy == null || pinnedBy == sender
        ? 'PINNED MESSAGE'
        : 'PINNED BY $pinnedBy';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: BoxDecoration(
        color: const Color(0xFF17171D),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PinnedAvatar(
            imageUrl: avatarUrl,
            displayName: sender,
            color: senderColor,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.push_pin_rounded,
                      color: Color(0xFF9AA4B2),
                      size: 12,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        sender,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: senderColor,
                          fontSize: 12.5,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        metaText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9.5,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF2F2F4),
                    fontSize: 13,
                    height: 1.24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _cleanName(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  Color? _parseUserColor(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    if (!text.startsWith('#') || text.length != 7) return null;
    final parsed = int.tryParse(text.substring(1), radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }
}

class _PinnedAvatar extends StatelessWidget {
  final String imageUrl;
  final String displayName;
  final Color color;

  const _PinnedAvatar({
    required this.imageUrl,
    required this.displayName,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    const size = 32.0;
    final fallback = _fallbackText(displayName);

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withOpacity(0.25),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                color.withOpacity(0.85),
                const Color(0xFF23232B),
              ],
            ),
          ),
          child: imageUrl.isEmpty
              ? _PinnedAvatarFallback(text: fallback)
              : TwitchCachedImageLayer(
                  imageUrl: imageUrl,
                  width: size,
                  height: size,
                  cacheWidth: 64,
                  cacheHeight: 64,
                  fit: BoxFit.cover,
                  fallbackColor: Colors.transparent,
                  errorWidget: _PinnedAvatarFallback(text: fallback),
                ),
        ),
      ),
    );
  }

  String _fallbackText(String value) {
    final text = value.trim();
    if (text.isEmpty) return '?';
    return String.fromCharCode(text.runes.first).toUpperCase();
  }
}

class _PinnedAvatarFallback extends StatelessWidget {
  final String text;

  const _PinnedAvatarFallback({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
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
    final effectiveLocksAt = _effectiveLocksAt(prediction);

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

  if (hours > 0) {
    return '$hours:${two(minutes)}:${two(seconds)}';
  }
  return '$minutes:${two(seconds)}';
}
