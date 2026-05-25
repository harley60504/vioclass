import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../models/engagement/twitch_hype_train.dart';
import '../../../../services/engagement/twitch_hype_train_controller.dart';
import '../../../sheets/twitch_hype_train_sheet.dart';

class TwitchHypeTrainBanner extends StatefulWidget {
  final TwitchHypeTrainController controller;

  const TwitchHypeTrainBanner({super.key, required this.controller});

  @override
  State<TwitchHypeTrainBanner> createState() => _TwitchHypeTrainBannerState();
}

class _TwitchHypeTrainBannerState extends State<TwitchHypeTrainBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncTimer);
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant TwitchHypeTrainBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_syncTimer);
    widget.controller.addListener(_syncTimer);
    _syncTimer();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncTimer);
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    final snapshot = widget.controller.snapshot;
    final shouldTick = snapshot != null && snapshot.isActive;
    if (!shouldTick) {
      _timer?.cancel();
      _timer = null;
      if (mounted) setState(() {});
      return;
    }

    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final snapshot = widget.controller.snapshot;
      if (snapshot == null || !snapshot.isActive) {
        _timer?.cancel();
        _timer = null;
      }
      setState(() {});
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final snapshot = widget.controller.snapshot;
        if (snapshot == null || !snapshot.isActive) {
          return const SizedBox.shrink();
        }
        return _HypeTrainBannerBody(snapshot: snapshot);
      },
    );
  }
}

class _HypeTrainBannerBody extends StatelessWidget {
  final TwitchHypeTrainSnapshot snapshot;

  const _HypeTrainBannerBody({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = _formatRemaining(snapshot.remainingDuration);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () =>
            showTwitchHypeTrainSheet(context: context, snapshot: snapshot),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB02E).withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFFFB02E).withValues(alpha: 0.38),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFFFB02E),
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '發燒列車 / Hype Train Lv.${snapshot.level}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    remaining,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  value: snapshot.progressRatio,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFFFB02E),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${snapshot.progress} / ${snapshot.goal}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    snapshot.isSharedTrain
                        ? '${snapshot.displayTypeLabel} · Shared'
                        : snapshot.displayTypeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFFFD28A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRemaining(Duration value) {
    final safe = value.isNegative ? Duration.zero : value;
    final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (safe.inHours > 0) {
      return '${safe.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
