import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../services/playback/twitch_playlist_player_runtime.dart';

class TwitchLivePlaybackStrip extends StatefulWidget {
  final Player player;
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final bool compact;

  const TwitchLivePlaybackStrip({
    super.key,
    required this.player,
    required this.playerRuntime,
    this.compact = false,
  });

  @override
  State<TwitchLivePlaybackStrip> createState() => _TwitchLivePlaybackStripState();
}

class _TwitchLivePlaybackStripState extends State<TwitchLivePlaybackStrip> {
  static const Duration _liveEdgeUiTolerance = Duration(seconds: 5);
  static const Duration _liveEdgeSeekBackoff = Duration(milliseconds: 350);

  bool _dragging = false;
  bool _livePinned = true;
  double? _dragValue;

  Player get player => widget.player;
  bool get compact => widget.compact;

  Duration _liveEdgeSeekTarget(Duration duration) {
    final ms = duration.inMilliseconds;
    if (ms <= 0) return Duration.zero;

    final backoff = _liveEdgeSeekBackoff.inMilliseconds;
    final targetMs = ms <= backoff * 2 ? ms : ms - backoff;
    return Duration(milliseconds: targetMs);
  }

  Future<void> _seekToLiveEdge(Duration duration) async {
    final target = _liveEdgeSeekTarget(duration);

    setState(() {
      _dragging = true;
      _dragValue = 1.0;
      _livePinned = true;
    });

    try {
      await player.seek(target);
      await player.play();
    } finally {
      if (!mounted) return;
      setState(() {
        _dragging = false;
        _dragValue = null;
        _livePinned = true;
      });
    }
  }

  bool _isNearLiveEdge({
    required bool hasSeekableDuration,
    required Duration liveLag,
    required double streamValue,
  }) {
    if (!hasSeekableDuration) return true;
    if (liveLag <= _liveEdgeUiTolerance) return true;
    return streamValue >= 0.985;
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

                    final hasSeekableDuration = duration.inMilliseconds > 500;
                    final rawValue = hasSeekableDuration
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 1.0;
                    final streamValue = rawValue.clamp(0.0, 1.0).toDouble();
                    final liveLag = hasSeekableDuration
                        ? duration - position
                        : Duration.zero;
                    final nearLiveEdge = _isNearLiveEdge(
                      hasSeekableDuration: hasSeekableDuration,
                      liveLag: liveLag,
                      streamValue: streamValue,
                    );
                    final isAtLiveEdge = _livePinned && nearLiveEdge;

                    final value = _dragging
                        ? (_dragValue ?? streamValue).clamp(0.0, 1.0).toDouble()
                        : isAtLiveEdge
                            ? 1.0
                            : streamValue;
                    final previewPosition = hasSeekableDuration
                        ? isAtLiveEdge && !_dragging
                            ? duration
                            : Duration(
                                milliseconds:
                                    (duration.inMilliseconds * value).round(),
                              )
                        : position;
                    final positionText = _formatDuration(previewPosition);
                    final durationText = hasSeekableDuration
                        ? _formatDuration(duration)
                        : '--:--';
                    final timeColor = buffering
                        ? Colors.orangeAccent
                        : Colors.white60;
                    final timeText = '$positionText / $durationText';

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
                              onChangeStart: hasSeekableDuration
                                  ? (next) {
                                      setState(() {
                                        _dragging = true;
                                        _dragValue = next;
                                        _livePinned = next >= 0.985;
                                      });
                                    }
                                  : null,
                              onChanged: hasSeekableDuration
                                  ? (next) {
                                      setState(() {
                                        _dragValue = next;
                                        _livePinned = next >= 0.985;
                                      });
                                    }
                                  : null,
                              onChangeEnd: hasSeekableDuration
                                  ? (next) {
                                      final goLive = next >= 0.985;
                                      final target = goLive
                                          ? _liveEdgeSeekTarget(duration)
                                          : Duration(
                                              milliseconds:
                                                  (duration.inMilliseconds * next)
                                                      .round(),
                                            );

                                      setState(() {
                                        _dragging = false;
                                        _dragValue = null;
                                        _livePinned = goLive;
                                      });

                                      unawaited(player.seek(target));
                                    }
                                  : null,
                            ),
                          ),
                        ),
                        SizedBox(width: compact ? 6 : 8),
                        _LiveEdgeButton(
                          active: isAtLiveEdge,
                          enabled: hasSeekableDuration,
                          buffering: buffering,
                          compact: compact,
                          onPressed: hasSeekableDuration
                              ? () => unawaited(_seekToLiveEdge(duration))
                              : null,
                        ),
                        SizedBox(width: compact ? 6 : 8),
                        Tooltip(
                          message: _timeStatusTooltip(
                            position: previewPosition,
                            duration: duration,
                            buffering: buffering,
                            playing: playing,
                            livePinned: isAtLiveEdge,
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
                              child: Text(
                                timeText,
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: TextStyle(
                                  color: timeColor,
                                  fontSize: compact ? 11 : 12,
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
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
          },
        );
      },
    );
  }

  static String _timeStatusTooltip({
    required Duration position,
    required Duration duration,
    required bool buffering,
    required bool playing,
    required bool livePinned,
  }) {
    final pos = _formatDuration(position);
    final dur = duration.inMilliseconds > 0 ? _formatDuration(duration) : '--:--';
    final state = buffering
        ? 'buffering'
        : livePinned
            ? 'live edge'
            : playing
                ? 'playing'
                : 'paused';
    return 'media_kit $state · $pos / $dur';
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

class _LiveEdgeButton extends StatelessWidget {
  final bool active;
  final bool enabled;
  final bool buffering;
  final bool compact;
  final VoidCallback? onPressed;

  const _LiveEdgeButton({
    required this.active,
    required this.enabled,
    required this.buffering,
    required this.compact,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = buffering
        ? Colors.orangeAccent
        : active
            ? Colors.redAccent
            : Colors.white54;
    final border = buffering
        ? Colors.orangeAccent.withOpacity(0.42)
        : active
            ? Colors.redAccent.withOpacity(0.52)
            : Colors.white.withOpacity(0.16);
    final background = active
        ? Colors.redAccent.withOpacity(0.16)
        : const Color(0xFF18181B).withOpacity(0.86);

    return Tooltip(
      message: active ? '目前在直播最新位置' : '跳到直播最新位置',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: compact ? 25 : 28,
            padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: enabled ? border : Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: compact ? 5 : 6,
                  height: compact ? 5 : 6,
                  decoration: BoxDecoration(
                    color: enabled ? foreground : Colors.white24,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: compact ? 4 : 5),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: enabled ? foreground : Colors.white24,
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
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
