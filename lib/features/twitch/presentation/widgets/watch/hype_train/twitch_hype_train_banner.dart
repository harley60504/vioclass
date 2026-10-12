import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../../../models/engagement/twitch_hype_train.dart';
import '../../../../services/engagement/twitch_hype_train_controller.dart';
import '../../../localization/vioclass_localizations.dart';

class TwitchHypeTrainBanner extends StatefulWidget {
  final TwitchHypeTrainController controller;

  const TwitchHypeTrainBanner({super.key, required this.controller});

  @override
  State<TwitchHypeTrainBanner> createState() => _TwitchHypeTrainBannerState();
}

class _TwitchHypeTrainBannerState extends State<TwitchHypeTrainBanner>
    with TickerProviderStateMixin {
  static const Duration _endingDuration = Duration(milliseconds: 1800);

  Timer? _timer;
  late final AnimationController _endingController;
  TwitchHypeTrainSnapshot? _visibleSnapshot;
  bool _showEnding = false;
  late final AnimationController _celebrationController;
  bool _levelUp = false;

  @override
  void initState() {
    super.initState();
    _celebrationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2600),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _levelUp = false);
          }
        });
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
    _visibleSnapshot = null;
    _levelUp = false;
    _celebrationController.reset();
    oldWidget.controller.removeListener(_syncTimer);
    widget.controller.addListener(_syncTimer);
    _syncTimer();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncTimer);
    _timer?.cancel();
    _endingController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  void _syncTimer() {
    final snapshot = widget.controller.snapshot;
    if (snapshot != null && snapshot.isActive) {
      final previous = _visibleSnapshot;
      if (previous != null &&
          previous.id == snapshot.id &&
          snapshot.level > previous.level &&
          !MediaQuery.disableAnimationsOf(context)) {
        _levelUp = true;
        _celebrationController.forward(from: 0);
      }
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
          alignment: Alignment.topCenter,
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
                levelUp: _levelUp,
                celebration: _celebrationController,
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
  final bool levelUp;
  final Animation<double> celebration;

  const _HypeTrainBannerBody({
    required this.snapshot,
    required this.ending,
    required this.endingProgress,
    required this.levelUp,
    required this.celebration,
  });

  @override
  Widget build(BuildContext context) {
    final golden = snapshot.isGoldenKappa;
    final colors = golden
        ? const [Color(0xFFE5AC16), Color(0xFFFFDF68)]
        : const [Color(0xFF805AE0), Color(0xFFCD6DAE), Color(0xFF66B4D8)];
    final accent = golden ? const Color(0xFFFFDA65) : const Color(0xFFD3B9FF);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final ratio = ending ? 1.0 : snapshot.progressRatio;
    final remaining = snapshot.remainingDuration;
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 3),
      child: Semantics(
        label:
            '${context.vio.t(snapshot.displayTypeLabel)} Lv.${snapshot.level}',
        value: '${(ratio * 100).round()}%',
        child: Tooltip(
          message:
              '${snapshot.progress} / ${snapshot.goal} · ${context.vio.t(snapshot.displayTypeLabel)}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF19191F),
                border: Border.all(color: accent.withValues(alpha: 0.16)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('${snapshot.id}-${snapshot.level}'),
                      tween: Tween(
                        begin: reducedMotion ? ratio : 0,
                        end: ratio,
                      ),
                      duration: Duration(milliseconds: reducedMotion ? 0 : 550),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: value,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: colors
                                    .map((c) => c.withValues(alpha: 0.72))
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          ending || levelUp
                              ? Icons.celebration_rounded
                              : golden
                              ? Icons.auto_awesome_rounded
                              : Icons.train_rounded,
                          size: 17,
                          color: accent,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Lv.${snapshot.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: Duration(
                              milliseconds: reducedMotion ? 0 : 200,
                            ),
                            child: Text(
                              ending
                                  ? context.vio.t('列車結束')
                                  : levelUp
                                  ? context.vio.t('升級！')
                                  : '${(ratio * 100).round()}%',
                              key: ValueKey(
                                ending
                                    ? 'ended'
                                    : levelUp
                                    ? 'up'
                                    : 'progress',
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          ending ? '' : '$minutes:$seconds',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (levelUp && !reducedMotion)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: celebration,
                          builder: (_, _) => CustomPaint(
                            painter: _TrainCelebrationPainter(
                              celebration.value,
                              accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainCelebrationPainter extends CustomPainter {
  final double progress;
  final Color color;
  _TrainCelebrationPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: (1 - progress) * 0.8);
    for (var i = 0; i < 18; i++) {
      final x = size.width * ((i * 0.137 + progress * 0.13) % 1);
      final y = size.height * ((i * 0.231 + progress) % 1);
      canvas.drawCircle(Offset(x, y), 1.3 + (i % 3) * 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrainCelebrationPainter old) =>
      old.progress != progress || old.color != color;
}
