import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../services/playback/twitch_playlist_player_runtime.dart';
import '../../../localization/vioclass_localizations.dart';

const double _liveEdgeSnapRatio = 0.995;

class TwitchLivePlaybackStrip extends StatefulWidget {
  final Player player;
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final bool compact;
  final Duration? dvrTimelineDuration;
  final DateTime? dvrTimelineStartedAt;
  final ValueChanged<double>? onOpenDvrReplayAt;

  const TwitchLivePlaybackStrip({
    super.key,
    required this.player,
    required this.playerRuntime,
    this.compact = false,
    this.dvrTimelineDuration,
    this.dvrTimelineStartedAt,
    this.onOpenDvrReplayAt,
  });

  @override
  State<TwitchLivePlaybackStrip> createState() =>
      _TwitchLivePlaybackStripState();
}

class _TwitchLivePlaybackStripState extends State<TwitchLivePlaybackStrip> {
  bool _dragging = false;
  bool _livePinned = true;
  double? _dragValue;

  Player get player => widget.player;
  bool get compact => widget.compact;

  Duration? _effectiveDvrTimelineDuration() {
    final base = widget.dvrTimelineDuration;
    final startedAt = widget.dvrTimelineStartedAt;
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
            return StreamBuilder<bool>(
              stream: player.stream.buffering,
              initialData: player.state.buffering,
              builder: (context, bufferingSnapshot) {
                return StreamBuilder<bool>(
                  stream: player.stream.playing,
                  initialData: player.state.playing,
                  builder: (context, playingSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    final duration = durationSnapshot.data ?? Duration.zero;
                    final buffering = bufferingSnapshot.data ?? false;
                    final playing = playingSnapshot.data ?? false;

                    final dvrTimelineDuration = _effectiveDvrTimelineDuration();
                    final hasDvrTimeline =
                        dvrTimelineDuration != null &&
                        dvrTimelineDuration.inMilliseconds > 500;
                    final hasSeekableDuration = duration.inMilliseconds > 500;
                    final canScrubTimeline =
                        (hasSeekableDuration || hasDvrTimeline) &&
                        widget.onOpenDvrReplayAt != null;
                    final rawPlayerValue = hasSeekableDuration
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 1.0;
                    final playerValue = rawPlayerValue
                        .clamp(0.0, 1.0)
                        .toDouble();
                    final value = _dragging
                        ? (_dragValue ?? 1.0).clamp(0.0, 1.0).toDouble()
                        : hasDvrTimeline
                        ? 1.0
                        : _livePinned
                        ? 1.0
                        : playerValue;
                    final displayDuration = hasDvrTimeline
                        ? dvrTimelineDuration
                        : duration;
                    final previewPosition = displayDuration.inMilliseconds > 500
                        ? value >= _liveEdgeSnapRatio && !_dragging
                              ? displayDuration
                              : Duration(
                                  milliseconds:
                                      (displayDuration.inMilliseconds * value)
                                          .round(),
                                )
                        : position;
                    final positionText = _formatDuration(previewPosition);
                    final durationText = context.vio.t('直播');
                    final timeColor = buffering
                        ? Colors.orangeAccent
                        : Colors.white60;
                    final liveLabelActive = value >= _liveEdgeSnapRatio;

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
                              onChangeStart: canScrubTimeline
                                  ? (next) {
                                      setState(() {
                                        _dragging = true;
                                        _dragValue = next;
                                        _livePinned =
                                            next >= _liveEdgeSnapRatio;
                                      });
                                    }
                                  : null,
                              onChanged: canScrubTimeline
                                  ? (next) {
                                      setState(() {
                                        _dragValue = next;
                                        _livePinned =
                                            next >= _liveEdgeSnapRatio;
                                      });
                                    }
                                  : null,
                              onChangeEnd: canScrubTimeline
                                  ? (next) {
                                      setState(() {
                                        _dragging = false;
                                        _dragValue = null;
                                        _livePinned =
                                            next >= _liveEdgeSnapRatio;
                                      });

                                      if (next < _liveEdgeSnapRatio &&
                                          widget.onOpenDvrReplayAt != null) {
                                        widget.onOpenDvrReplayAt!(next);
                                        return;
                                      }
                                    }
                                  : null,
                            ),
                          ),
                        ),
                        SizedBox(width: compact ? 6 : 8),
                        Tooltip(
                          message: _timeStatusTooltip(
                            context: context,
                            position: previewPosition,
                            duration: duration,
                            buffering: buffering,
                            playing: playing,
                            livePinned: value >= _liveEdgeSnapRatio,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: compact ? 82 : 108,
                              maxWidth: compact ? 104 : 136,
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 4 : 6,
                                vertical: compact ? 5 : 6,
                              ),
                              child: _TimelineTimeText(
                                positionText: positionText,
                                tailText: durationText,
                                liveTail: true,
                                liveTailActive: liveLabelActive,
                                textAlign: TextAlign.right,
                                color: timeColor,
                                fontSize: compact ? 11 : 12,
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
          },
        );
      },
    );
  }

  static String _timeStatusTooltip({
    required BuildContext context,
    required Duration position,
    required Duration duration,
    required bool buffering,
    required bool playing,
    required bool livePinned,
  }) {
    final pos = _formatDuration(position);
    final dur = duration.inMilliseconds > 0
        ? _formatDuration(duration)
        : '--:--';
    final l10n = context.vio;
    final state = buffering
        ? l10n.t('緩衝中')
        : livePinned
        ? l10n.t('直播最新')
        : playing
        ? l10n.t('播放中')
        : l10n.t('已暫停');

    return '$state · $pos / $dur';
  }

  static String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    final minutesTotal = totalSeconds ~/ 60;
    final minutes = (minutesTotal % 60).toString().padLeft(2, '0');
    final hours = totalSeconds ~/ 3600;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _TimelineTimeText extends StatelessWidget {
  final String positionText;
  final String tailText;
  final bool liveTail;
  final bool liveTailActive;
  final TextAlign textAlign;
  final Color color;
  final double fontSize;

  const _TimelineTimeText({
    required this.positionText,
    required this.tailText,
    required this.liveTail,
    required this.liveTailActive,
    required this.textAlign,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$positionText / ', style: baseStyle),
          TextSpan(
            text: tailText,
            style: baseStyle.copyWith(
              color: liveTail && liveTailActive ? Colors.redAccent : color,
            ),
          ),
        ],
      ),
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
    );
  }
}
