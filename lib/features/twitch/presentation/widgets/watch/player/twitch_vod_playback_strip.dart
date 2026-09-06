import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../localization/vioclass_localizations.dart';
import 'twitch_time_jump_sheet.dart';

const double _liveEdgeSnapRatio = 0.995;
const double _liveEdgeExactRatio = 0.9999;
const double _maxLiveDvrReplayRatio = _liveEdgeSnapRatio - 0.01;
const Duration _seekButtonDebounce = Duration(milliseconds: 520);

class TwitchVodPlaybackStrip extends StatefulWidget {
  final Player player;
  final bool compact;
  final bool showLiveEdgeLabel;
  final bool forceLiveEdge;
  final Duration? liveTimelineDuration;
  final DateTime? liveTimelineStartedAt;
  final double? timelineValue;
  final bool timelineValueAdvancesWithPlayer;
  final ValueChanged<double>? onOpenDvrReplayAt;
  final VoidCallback? onReturnToLive;

  const TwitchVodPlaybackStrip({
    super.key,
    required this.player,
    this.compact = false,
    this.showLiveEdgeLabel = false,
    this.forceLiveEdge = false,
    this.liveTimelineDuration,
    this.liveTimelineStartedAt,
    this.timelineValue,
    this.timelineValueAdvancesWithPlayer = false,
    this.onOpenDvrReplayAt,
    this.onReturnToLive,
  });

  @override
  State<TwitchVodPlaybackStrip> createState() => _TwitchVodPlaybackStripState();
}

class _TwitchVodPlaybackStripState extends State<TwitchVodPlaybackStrip> {
  bool _dragging = false;
  double? _dragValue;
  double? _scrubbedTimelineValue;

  Player get player => widget.player;
  bool get compact => widget.compact;

  Duration? _effectiveLiveTimelineDuration() {
    final base = widget.liveTimelineDuration;
    final startedAt = widget.liveTimelineStartedAt;
    final elapsed = startedAt == null
        ? null
        : DateTime.now().toUtc().difference(startedAt.toUtc());
    final positiveElapsed = elapsed == null || elapsed.isNegative
        ? null
        : elapsed;

    if (base == null) return positiveElapsed;
    if (positiveElapsed == null) return base;
    return positiveElapsed > base ? positiveElapsed : base;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          initialData: player.state.duration,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data ?? Duration.zero;
            final liveDuration = _effectiveLiveTimelineDuration();
            final displayDuration =
                liveDuration != null && liveDuration.inMilliseconds > 500
                ? liveDuration
                : duration;
            final hasDuration = displayDuration.inMilliseconds > 500;
            final hasPlayerDuration = duration.inMilliseconds > 500;
            final rawValue = hasPlayerDuration
                ? position.inMilliseconds / duration.inMilliseconds
                : widget.forceLiveEdge
                ? 1.0
                : 0.0;
            final streamValue = rawValue.clamp(0.0, 1.0).toDouble();
            final manualValue = _scrubbedTimelineValue;
            final externalValue = widget.timelineValue?.clamp(0.0, 1.0);
            final baseValue = _dragging
                ? (_dragValue ?? streamValue).clamp(0.0, 1.0).toDouble()
                : externalValue != null &&
                      (widget.forceLiveEdge || widget.showLiveEdgeLabel)
                ? externalValue.toDouble()
                : manualValue != null &&
                      (widget.forceLiveEdge || widget.showLiveEdgeLabel)
                ? manualValue.clamp(0.0, 1.0).toDouble()
                : widget.showLiveEdgeLabel || widget.forceLiveEdge
                ? 1.0
                : streamValue;
            final advancedValue =
                !_dragging &&
                    widget.timelineValueAdvancesWithPlayer &&
                    externalValue != null &&
                    hasDuration
                ? (externalValue +
                          position.inMilliseconds /
                              displayDuration.inMilliseconds)
                      .clamp(0.0, 1.0)
                      .toDouble()
                : baseValue;
            final value = advancedValue;
            final previewPosition = hasDuration
                ? Duration(
                    milliseconds: (displayDuration.inMilliseconds * value)
                        .round(),
                  )
                : position;
            final liveTailActive =
                widget.showLiveEdgeLabel && value >= _liveEdgeSnapRatio;
            final durationText = hasDuration
                ? widget.showLiveEdgeLabel
                      ? _formatCoarseDuration(displayDuration)
                      : _formatDuration(displayDuration)
                : '--:--';
            final positionText = widget.showLiveEdgeLabel
                ? _formatCoarseDuration(previewPosition)
                : _formatDuration(previewPosition);
            final tailText = widget.showLiveEdgeLabel
                ? context.vio.t('直播')
                : durationText;
            final canTapLiveTail =
                widget.showLiveEdgeLabel && widget.onReturnToLive != null;
            final canJumpByTime = hasDuration;
            final media = MediaQuery.of(context);
            final physicalShortestSide =
                media.size.shortestSide * media.devicePixelRatio;
            final useInlineTimeJump =
                hasDuration &&
                !compact &&
                (media.size.width >= 760 || physicalShortestSide >= 1400);
            final isLiveTimeline =
                widget.forceLiveEdge || widget.showLiveEdgeLabel;

            double replayRatioFor(double ratio) {
              if (!isLiveTimeline) return ratio.clamp(0.0, 1.0).toDouble();
              return ratio.clamp(0.0, _maxLiveDvrReplayRatio).toDouble();
            }

            void jumpToTarget(Duration target) {
              final next = displayDuration.inMilliseconds <= 0
                  ? 0.0
                  : target.inMilliseconds / displayDuration.inMilliseconds;
              final ratio = next.clamp(0.0, 1.0).toDouble();
              final exactLiveEdge =
                  isLiveTimeline &&
                  widget.onReturnToLive != null &&
                  ratio >= _liveEdgeExactRatio;

              if (exactLiveEdge) {
                setState(() {
                  _dragging = false;
                  _dragValue = null;
                  _scrubbedTimelineValue = null;
                });
                widget.onReturnToLive!();
                return;
              }

              setState(() {
                _dragging = false;
                _dragValue = null;
                _scrubbedTimelineValue = isLiveTimeline
                    ? replayRatioFor(ratio)
                    : ratio;
              });

              if (isLiveTimeline && widget.onOpenDvrReplayAt != null) {
                widget.onOpenDvrReplayAt!(replayRatioFor(ratio));
                return;
              }

              unawaited(player.seek(target));
            }

            Future<void> openTimeJumpSheet() async {
              final target = await showTwitchTimeJumpSheet(
                context: context,
                current: previewPosition,
                duration: displayDuration,
                liveTail: widget.showLiveEdgeLabel,
              );
              if (target == null || !context.mounted) return;
              jumpToTarget(target);
            }

            return Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: compact ? 4 : 5,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: compact ? 6 : 7,
                      ),
                    ),
                    child: Slider(
                      value: value,
                      min: 0,
                      max: 1,
                      onChangeStart: hasDuration
                          ? (next) {
                              setState(() {
                                _dragging = true;
                                _dragValue = next;
                              });
                            }
                          : null,
                      onChanged: hasDuration
                          ? (next) {
                              setState(() => _dragValue = next);
                            }
                          : null,
                      onChangeEnd: hasDuration
                          ? (next) {
                              final exactLiveEdge =
                                  isLiveTimeline &&
                                  widget.onReturnToLive != null &&
                                  next >= _liveEdgeExactRatio;
                              if (exactLiveEdge) {
                                setState(() {
                                  _dragging = false;
                                  _dragValue = null;
                                  _scrubbedTimelineValue = null;
                                });
                                widget.onReturnToLive!();
                                return;
                              }

                              setState(() {
                                _dragging = false;
                                _dragValue = null;
                                _scrubbedTimelineValue = isLiveTimeline
                                    ? replayRatioFor(next)
                                    : next;
                              });

                              if (widget.forceLiveEdge &&
                                  next < _liveEdgeSnapRatio &&
                                  widget.onOpenDvrReplayAt != null) {
                                widget.onOpenDvrReplayAt!(replayRatioFor(next));
                                return;
                              }

                              if (widget.forceLiveEdge &&
                                  widget.onOpenDvrReplayAt != null) {
                                widget.onOpenDvrReplayAt!(replayRatioFor(next));
                                return;
                              }

                              final target = Duration(
                                milliseconds:
                                    (displayDuration.inMilliseconds * next)
                                        .round(),
                              );
                              unawaited(player.seek(target));
                            }
                          : null,
                    ),
                  ),
                ),
                SizedBox(width: compact ? 6 : 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: widget.showLiveEdgeLabel
                        ? compact
                              ? 132
                              : 154
                        : compact
                        ? 82
                        : 108,
                    maxWidth: widget.showLiveEdgeLabel
                        ? compact
                              ? 178
                              : useInlineTimeJump
                              ? 340
                              : 220
                        : compact
                        ? 104
                        : useInlineTimeJump
                        ? 260
                        : 136,
                  ),
                  child: useInlineTimeJump
                      ? _InlineTimelineTimeControls(
                          current: previewPosition,
                          duration: displayDuration,
                          liveText: widget.showLiveEdgeLabel
                              ? context.vio.t('直播')
                              : null,
                          liveActive: liveTailActive,
                          canReturnToLive: canTapLiveTail,
                          hideSeconds: widget.showLiveEdgeLabel,
                          onJump: jumpToTarget,
                          onReturnToLive: () {
                            setState(() {
                              _dragging = false;
                              _dragValue = null;
                              _scrubbedTimelineValue = null;
                            });
                            widget.onReturnToLive!();
                          },
                        )
                      : widget.showLiveEdgeLabel
                      ? _LiveTimelineTimeControls(
                          positionText: positionText,
                          durationText: durationText,
                          liveText: tailText,
                          liveActive: liveTailActive,
                          compact: compact,
                          canJumpByTime: canJumpByTime,
                          canReturnToLive: canTapLiveTail,
                          onOpenTimeJump: openTimeJumpSheet,
                          onReturnToLive: () {
                            setState(() {
                              _dragging = false;
                              _dragValue = null;
                              _scrubbedTimelineValue = null;
                            });
                            widget.onReturnToLive!();
                          },
                        )
                      : _VodTimelineTimeControls(
                          positionText: positionText,
                          tailText: tailText,
                          compact: compact,
                          canJumpByTime: canJumpByTime,
                          onOpenTimeJump: openTimeJumpSheet,
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

String _formatCoarseDuration(Duration duration) {
  final totalMinutes = (duration.inSeconds / 60).floor();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}';
  }
  return '$minutes分';
}

class _InlineTimelineTimeControls extends StatefulWidget {
  final Duration current;
  final Duration duration;
  final String? liveText;
  final bool liveActive;
  final bool canReturnToLive;
  final bool hideSeconds;
  final ValueChanged<Duration> onJump;
  final VoidCallback onReturnToLive;

  const _InlineTimelineTimeControls({
    required this.current,
    required this.duration,
    required this.liveText,
    required this.liveActive,
    required this.canReturnToLive,
    required this.hideSeconds,
    required this.onJump,
    required this.onReturnToLive,
  });

  @override
  State<_InlineTimelineTimeControls> createState() =>
      _InlineTimelineTimeControlsState();
}

class _InlineTimelineTimeControlsState
    extends State<_InlineTimelineTimeControls> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _editing = false;
  Timer? _pendingSeekTimer;
  Duration? _pendingSeekBase;
  Duration _pendingSeekDelta = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatTimeline(widget.current));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _InlineTimelineTimeControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pendingSeekTimer?.isActive ?? false) return;
    if (_focusNode.hasFocus) return;
    final next = _formatTimeline(widget.current);
    if (_controller.text == next) return;
    _controller.text = next;
  }

  @override
  void dispose() {
    _pendingSeekTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _jumpBy(Duration delta) {
    final liveDvrTail = Duration(
      milliseconds: (widget.duration.inMilliseconds * _maxLiveDvrReplayRatio)
          .round(),
    );
    final liveDvrTailStepBase = liveDvrTail + delta.abs();
    final base =
        _pendingSeekBase ??
        (widget.liveText != null && widget.liveActive && delta.isNegative
            ? liveDvrTailStepBase
            : widget.current);
    _pendingSeekBase = base;
    _pendingSeekDelta += delta;

    final next = Duration(
      milliseconds: (base.inMilliseconds + _pendingSeekDelta.inMilliseconds)
          .clamp(0, widget.duration.inMilliseconds)
          .toInt(),
    );
    setState(() => _controller.text = _formatTimeline(next));

    _pendingSeekTimer?.cancel();
    _pendingSeekTimer = Timer(_seekButtonDebounce, () {
      _pendingSeekBase = null;
      _pendingSeekDelta = Duration.zero;
      widget.onJump(next);
    });
  }

  void _submit() {
    final parsed = _parseTimeline(_controller.text);
    if (parsed == null) {
      setState(() {
        _editing = false;
        _controller.text = _formatTimeline(widget.current);
      });
      _focusNode.unfocus();
      return;
    }
    final next = Duration(
      milliseconds: parsed.inMilliseconds
          .clamp(0, widget.duration.inMilliseconds)
          .toInt(),
    );
    setState(() => _editing = false);
    _focusNode.unfocus();
    widget.onJump(next);
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _controller.text = _formatTimeline(widget.current);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: Colors.white70,
      fontSize: 12,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w900,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _InlineSeekButton(
            icon: Icons.replay_10_rounded,
            onPressed: () => _jumpBy(const Duration(seconds: -10)),
          ),
          _InlineTimeValue(
            editing: _editing,
            controller: _controller,
            focusNode: _focusNode,
            style: textStyle,
            displayText: widget.hideSeconds
                ? _formatCoarseDuration(widget.current)
                : null,
            onTap: _startEditing,
            onSubmitted: _submit,
            onEditingComplete: _submit,
          ),
          Text(' / ', style: textStyle),
          Text(
            widget.hideSeconds
                ? _formatCoarseDuration(widget.duration)
                : _formatTimeline(widget.duration),
            style: textStyle,
          ),
          if (widget.liveText != null) ...[
            const SizedBox(width: 8),
            _InlineLiveButton(
              text: widget.liveText!,
              active: widget.liveActive,
              enabled: widget.canReturnToLive,
              style: textStyle,
              onPressed: widget.onReturnToLive,
            ),
          ],
          _InlineSeekButton(
            icon: Icons.forward_10_rounded,
            onPressed: () => _jumpBy(const Duration(seconds: 10)),
          ),
        ],
      ),
    );
  }
}

class _InlineTimeValue extends StatelessWidget {
  final bool editing;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final String? displayText;
  final VoidCallback onTap;
  final VoidCallback onSubmitted;
  final VoidCallback onEditingComplete;

  const _InlineTimeValue({
    required this.editing,
    required this.controller,
    required this.focusNode,
    required this.style,
    this.displayText,
    required this.onTap,
    required this.onSubmitted,
    required this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (editing) {
      return SizedBox(
        width: 66,
        height: 28,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmitted(),
          onEditingComplete: onEditingComplete,
          style: style,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          ),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          child: Text(displayText ?? controller.text, style: style),
        ),
      ),
    );
  }
}

class _InlineLiveButton extends StatelessWidget {
  final String text;
  final bool active;
  final bool enabled;
  final TextStyle style;
  final VoidCallback onPressed;

  const _InlineLiveButton({
    required this.text,
    required this.active,
    required this.enabled,
    required this.style,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.redAccent : Colors.white60;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 7, color: color),
              const SizedBox(width: 4),
              Text(text, style: style.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineSeekButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _InlineSeekButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      icon: Icon(icon, color: Colors.white70, size: 19),
      onPressed: onPressed,
    );
  }
}

class _VodTimelineTimeControls extends StatelessWidget {
  final String positionText;
  final String tailText;
  final bool compact;
  final bool canJumpByTime;
  final VoidCallback onOpenTimeJump;

  const _VodTimelineTimeControls({
    required this.positionText,
    required this.tailText,
    required this.compact,
    required this.canJumpByTime,
    required this.onOpenTimeJump,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: canJumpByTime ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canJumpByTime ? onOpenTimeJump : null,
        child: Text.rich(
          TextSpan(text: '$positionText / $tailText'),
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.white60,
            fontSize: compact ? 11 : 12,
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

Duration? _parseTimeline(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  final parts = text.split(':');
  if (parts.length > 3) return null;

  final numbers = <int>[];
  for (final part in parts) {
    final number = int.tryParse(part.trim());
    if (number == null || number < 0) return null;
    numbers.add(number);
  }

  if (numbers.length == 1) return Duration(seconds: numbers[0]);
  if (numbers.length == 2) {
    return Duration(minutes: numbers[0], seconds: numbers[1]);
  }
  return Duration(hours: numbers[0], minutes: numbers[1], seconds: numbers[2]);
}

String _formatTimeline(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _LiveTimelineTimeControls extends StatelessWidget {
  final String positionText;
  final String durationText;
  final String liveText;
  final bool liveActive;
  final bool compact;
  final bool canJumpByTime;
  final bool canReturnToLive;
  final VoidCallback onOpenTimeJump;
  final VoidCallback onReturnToLive;

  const _LiveTimelineTimeControls({
    required this.positionText,
    required this.durationText,
    required this.liveText,
    required this.liveActive,
    required this.compact,
    required this.canJumpByTime,
    required this.canReturnToLive,
    required this.onOpenTimeJump,
    required this.onReturnToLive,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: Colors.white60,
      fontSize: compact ? 11 : 12,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w900,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MouseRegion(
            cursor: canJumpByTime
                ? SystemMouseCursors.click
                : MouseCursor.defer,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canJumpByTime ? onOpenTimeJump : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text('$positionText / $durationText', style: baseStyle),
              ),
            ),
          ),
          const SizedBox(width: 7),
          MouseRegion(
            cursor: canReturnToLive
                ? SystemMouseCursors.click
                : MouseCursor.defer,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canReturnToLive ? onReturnToLive : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: compact ? 6 : 7,
                      color: liveActive ? Colors.redAccent : Colors.white38,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      liveText,
                      style: baseStyle.copyWith(
                        color: liveActive ? Colors.redAccent : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(durationText, style: baseStyle),
        ],
      ),
    );
  }
}
