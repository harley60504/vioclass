import 'dart:async';
import 'package:flutter/material.dart';
import '../../../watch/controllers/twitch_playback_timeline_controller.dart';

/// A video-only hit surface, placed behind the player chrome.
class PlayerSeekGestures extends StatefulWidget {
  final TwitchPlaybackTimelineController? controller;
  final bool doubleTapEnabled;
  final bool dragEnabled;
  final bool limitToLiveBuffer;
  final bool enabled;
  final bool Function(int) onJump;
  final ValueChanged<Duration> onSeek;
  const PlayerSeekGestures({
    super.key,
    this.controller,
    required this.doubleTapEnabled,
    required this.dragEnabled,
    required this.limitToLiveBuffer,
    required this.enabled,
    required this.onJump,
    required this.onSeek,
  });
  @override
  State<PlayerSeekGestures> createState() => _SeekGestureState();
}

class _SeekGestureState extends State<PlayerSeekGestures> {
  double _tapX = 0;
  double _distance = 0;
  Duration? _origin;
  Duration? _duration;
  Duration? _preview;
  TwitchPlaybackTimelineMode? _mode;
  String? _feedback;
  Timer? _feedbackTimer;
  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlayerSeekGestures oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        !widget.enabled ||
        !widget.dragEnabled) {
      _origin = null;
      _preview = null;
    }
  }

  bool get _canSeek =>
      widget.enabled && widget.controller?.snapshot.canSeek == true;
  String _time(Duration value) {
    final s = value.inSeconds;
    return '${s ~/ 3600}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return Listener(
        onPointerCancel: (_) => setState(() {
          _origin = null;
          _preview = null;
        }),
        child: GestureDetector(
          key: const ValueKey('player-seek-gestures'),
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: widget.doubleTapEnabled
              ? (event) => _tapX = event.localPosition.dx
              : null,
          onDoubleTap: widget.doubleTapEnabled
              ? () {
                  if (!_canSeek) return;
                  final seconds = _tapX < constraints.maxWidth / 2 ? -10 : 10;
                  if (!widget.onJump(seconds)) return;
                  _feedbackTimer?.cancel();
                  setState(
                    () => _feedback = '${seconds > 0 ? '+' : ''}${seconds}s',
                  );
                  _feedbackTimer = Timer(const Duration(milliseconds: 700), () {
                    if (mounted) setState(() => _feedback = null);
                  });
                }
              : null,
          onHorizontalDragStart: widget.dragEnabled
              ? (_) {
                  if (!_canSeek) return;
                  final snapshot = widget.controller!.snapshot;
                  _origin = snapshot.isAtLiveEdge
                      ? snapshot.duration
                      : snapshot.position;
                  _duration = snapshot.duration;
                  _mode = snapshot.mode;
                  _distance = 0;
                }
              : null,
          onHorizontalDragUpdate: widget.dragEnabled
              ? (event) {
                  if (_origin == null || _duration == null || !_canSeek) return;
                  _distance += event.delta.dx;
                  final minimum =
                      widget.limitToLiveBuffer &&
                          _mode == TwitchPlaybackTimelineMode.liveDvr
                      ? (_duration!.inMilliseconds - 20000).clamp(
                          0,
                          _duration!.inMilliseconds,
                        )
                      : 0;
                  final target =
                      (_origin!.inMilliseconds +
                              _distance / constraints.maxWidth * 60000)
                          .round()
                          .clamp(minimum, _duration!.inMilliseconds)
                          .toInt();
                  setState(() => _preview = Duration(milliseconds: target));
                }
              : null,
          onHorizontalDragEnd: widget.dragEnabled
              ? (_) {
                  final target = _preview;
                  if (target != null &&
                      _canSeek &&
                      widget.controller!.snapshot.mode == _mode) {
                    widget.onSeek(target);
                  }
                  setState(() {
                    _origin = null;
                    _preview = null;
                  });
                }
              : null,
          onHorizontalDragCancel: widget.dragEnabled
              ? () => setState(() {
                  _origin = null;
                  _preview = null;
                })
              : null,
          child: Center(
            child: _preview == null && _feedback == null
                ? const SizedBox.expand()
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        _preview == null ? _feedback! : _time(_preview!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      );
    },
  );
}
