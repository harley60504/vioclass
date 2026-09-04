import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../localization/vioclass_localizations.dart';

const double _liveEdgeSnapRatio = 0.995;

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
            final tailText = widget.showLiveEdgeLabel
                ? context.vio.t('直播')
                : hasDuration
                ? _formatDuration(displayDuration)
                : '--:--';
            final canTapLiveTail =
                widget.showLiveEdgeLabel && widget.onReturnToLive != null;

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
                              if (widget.showLiveEdgeLabel &&
                                  next >= _liveEdgeSnapRatio &&
                                  widget.onReturnToLive != null) {
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
                                _scrubbedTimelineValue =
                                    next < _liveEdgeSnapRatio ? next : null;
                              });

                              if (widget.forceLiveEdge &&
                                  next < _liveEdgeSnapRatio &&
                                  widget.onOpenDvrReplayAt != null) {
                                widget.onOpenDvrReplayAt!(next);
                                return;
                              }

                              if (widget.forceLiveEdge &&
                                  widget.onOpenDvrReplayAt != null) {
                                widget.onOpenDvrReplayAt!(next);
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
                    minWidth: compact ? 82 : 108,
                    maxWidth: compact ? 104 : 136,
                  ),
                  child: MouseRegion(
                    cursor: canTapLiveTail
                        ? SystemMouseCursors.click
                        : MouseCursor.defer,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: canTapLiveTail
                          ? () {
                              setState(() {
                                _dragging = false;
                                _dragValue = null;
                                _scrubbedTimelineValue = null;
                              });
                              widget.onReturnToLive!();
                            }
                          : null,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${_formatDuration(previewPosition)} / ',
                            ),
                            TextSpan(
                              text: tailText,
                              style: TextStyle(
                                color: liveTailActive
                                    ? Colors.redAccent
                                    : Colors.white60,
                              ),
                            ),
                          ],
                        ),
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
