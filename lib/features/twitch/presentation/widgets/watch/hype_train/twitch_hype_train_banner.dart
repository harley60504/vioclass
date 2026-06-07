import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../models/engagement/twitch_hype_train.dart';
import '../../../../services/engagement/twitch_hype_train_controller.dart';

class TwitchHypeTrainBanner extends StatefulWidget {
  final TwitchHypeTrainController controller;

  const TwitchHypeTrainBanner({super.key, required this.controller});

  @override
  State<TwitchHypeTrainBanner> createState() => _TwitchHypeTrainBannerState();
}

class _TwitchHypeTrainBannerState extends State<TwitchHypeTrainBanner>
    with SingleTickerProviderStateMixin {
  static const Duration _endingDuration = Duration(milliseconds: 1800);

  Timer? _timer;
  late final AnimationController _endingController;
  TwitchHypeTrainSnapshot? _visibleSnapshot;
  bool _showEnding = false;

  @override
  void initState() {
    super.initState();
    _endingController =
        AnimationController(vsync: this, duration: _endingDuration)
          ..addStatusListener((status) {
            if (status != AnimationStatus.completed || !mounted) return;
            setState(() {
              _visibleSnapshot = null;
              _showEnding = false;
            });
          });
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
    _endingController.dispose();
    super.dispose();
  }

  void _syncTimer() {
    final snapshot = widget.controller.snapshot;
    if (snapshot != null && snapshot.isActive) {
      _visibleSnapshot = snapshot;
      _showEnding = false;
      _endingController.reset();
      _startTimer();
      if (mounted) setState(() {});
      return;
    }

    if (_visibleSnapshot != null &&
        !_showEnding &&
        _visibleSnapshot!.remainingDuration == Duration.zero) {
      _startEndingAnimation();
      return;
    }

    if (!_showEnding) {
      _timer?.cancel();
      _timer = null;
      _visibleSnapshot = null;
      if (mounted) setState(() {});
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final snapshot = widget.controller.snapshot;
      if (snapshot == null || !snapshot.isActive) {
        _timer?.cancel();
        _timer = null;
        if (_visibleSnapshot != null &&
            _visibleSnapshot!.remainingDuration == Duration.zero) {
          _startEndingAnimation();
          return;
        }
      }
      setState(() {});
    });
  }

  void _startEndingAnimation() {
    _timer?.cancel();
    _timer = null;
    _showEnding = true;
    _endingController.forward(from: 0);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final snapshot = _visibleSnapshot;
        if (snapshot == null) {
          return const SizedBox.shrink();
        }
        return SizeTransition(
          sizeFactor: Tween<double>(begin: 1, end: 0).animate(
            CurvedAnimation(
              parent: _endingController,
              curve: const Interval(0.68, 1, curve: Curves.easeInCubic),
            ),
          ),
          axisAlignment: -1,
          child: FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0).animate(
              CurvedAnimation(
                parent: _endingController,
                curve: const Interval(0.55, 1, curve: Curves.easeOut),
              ),
            ),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: Offset.zero,
                    end: const Offset(0, -0.18),
                  ).animate(
                    CurvedAnimation(
                      parent: _endingController,
                      curve: const Interval(
                        0.55,
                        1,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  ),
              child: _HypeTrainBannerBody(
                snapshot: snapshot,
                ending: _showEnding,
                endingProgress: _endingController.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HypeTrainBannerBody extends StatelessWidget {
  final TwitchHypeTrainSnapshot snapshot;
  final bool ending;
  final double endingProgress;

  const _HypeTrainBannerBody({
    required this.snapshot,
    required this.ending,
    required this.endingProgress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = _formatRemaining(snapshot.remainingDuration);
    final glow = ending ? (1 - endingProgress).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(
            0xFFFFB02E,
          ).withValues(alpha: ending ? 0.18 : 0.13),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(
              0xFFFFB02E,
            ).withValues(alpha: ending ? 0.70 : 0.38),
          ),
          boxShadow: [
            if (ending)
              BoxShadow(
                color: const Color(0xFFFFB02E).withValues(alpha: 0.24 * glow),
                blurRadius: 18 + 8 * glow,
                spreadRadius: 1 + 2 * glow,
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    ending
                        ? Icons.celebration_rounded
                        : Icons.local_fire_department_rounded,
                    color: const Color(0xFFFFB02E),
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      ending
                          ? '發燒列車結束 / Hype Train Complete'
                          : '發燒列車 / Hype Train Lv.${snapshot.level}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    ending ? 'Lv.${snapshot.level}' : remaining,
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
                  value: ending ? 1 : snapshot.progressRatio,
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
                      ending
                          ? '感謝大家的支援'
                          : '${snapshot.progress} / ${snapshot.goal}',
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
