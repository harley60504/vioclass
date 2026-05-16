part of twitch_watch_player_area;

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
  static const Duration _liveSeekVerifyDelay = Duration(milliseconds: 420);
  static const Duration _liveSeekSuccessTolerance = Duration(milliseconds: 2200);
  static const List<Duration> _liveSeekBackoffCandidates = <Duration>[
    Duration(milliseconds: 1200),
    Duration(milliseconds: 1800),
    Duration(milliseconds: 2600),
    Duration(milliseconds: 3800),
  ];

  bool _dragging = false;
  bool _livePinned = true;
  bool _seekingLiveEdge = false;
  double? _dragValue;
  String? _lastLiveSeekProbeSummary;
  Timer? _proxyLiveStatusTimer;

  Player get player => widget.player;
  bool get compact => widget.compact;

  @override
  void initState() {
    super.initState();
    _startProxyLiveStatusPolling();
  }

  @override
  void dispose() {
    _proxyLiveStatusTimer?.cancel();
    super.dispose();
  }

  void _startProxyLiveStatusPolling() {
    _proxyLiveStatusTimer?.cancel();
    unawaited(widget.playerRuntime.refreshProxyLiveStatus());
    _proxyLiveStatusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(widget.playerRuntime.refreshProxyLiveStatus()),
    );
  }

  @override
  void didUpdateWidget(covariant TwitchLivePlaybackStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.playerRuntime, widget.playerRuntime)) {
      _stopLiveSeekAttempt();
      _startProxyLiveStatusPolling();
    }
  }

  Duration _liveEdgeSeekTarget(Duration duration) {
    final ms = duration.inMilliseconds;
    if (ms <= 0) return Duration.zero;

    final backoff = _liveEdgeSeekBackoff.inMilliseconds;
    final targetMs = ms <= backoff * 2 ? ms : ms - backoff;
    return Duration(milliseconds: targetMs);
  }

  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  Duration _safeLiveLag({
    required Duration position,
    required Duration duration,
  }) {
    final lag = duration - position;
    return lag.isNegative ? Duration.zero : lag;
  }

  Duration? _proxySafeTargetInMediaTimeline({
    required dynamic proxyLiveStatus,
    required Duration mediaDuration,
  }) {
    if (proxyLiveStatus == null || mediaDuration.inMilliseconds <= 500) {
      return null;
    }

    try {
      final proxyOutput = proxyLiveStatus.outputDuration as Duration;
      final proxySafe = proxyLiveStatus.safeLivePosition as Duration;
      final hasOutput = proxyLiveStatus.hasOutput as bool;

      if (!hasOutput ||
          proxyOutput.inMilliseconds <= 0 ||
          proxySafe.inMilliseconds <= 0) {
        return null;
      }

      // proxy status is measured on the proxy output timeline. media_kit's
      // position/duration timeline can be shifted by about one segment, so map:
      //   media target = proxy safe + (media duration - proxy output)
      final mediaOffset = mediaDuration - proxyOutput;
      final rawTarget = proxySafe + mediaOffset;
      final maxTarget = mediaDuration.inMilliseconds > 800
          ? mediaDuration - const Duration(milliseconds: 150)
          : mediaDuration;

      return _clampDuration(rawTarget, Duration.zero, maxTarget);
    } catch (_) {
      return null;
    }
  }

  Duration _liveEdgeSeekTargetForStatus({
    required Duration mediaDuration,
    required dynamic proxyLiveStatus,
  }) {
    return _proxySafeTargetInMediaTimeline(
          proxyLiveStatus: proxyLiveStatus,
          mediaDuration: mediaDuration,
        ) ??
        _liveEdgeSeekTarget(mediaDuration);
  }

  List<Duration> _liveSeekTargets({
    required Duration mediaDuration,
    required dynamic proxyLiveStatus,
  }) {
    final maxTarget = mediaDuration.inMilliseconds > 900
        ? mediaDuration - const Duration(milliseconds: 250)
        : mediaDuration;
    final targets = <Duration>[];

    void addTarget(Duration value) {
      final target = _clampDuration(value, Duration.zero, maxTarget);
      final duplicate = targets.any((item) {
        final diff = item > target ? item - target : target - item;
        return diff <= const Duration(milliseconds: 180);
      });
      if (!duplicate) targets.add(target);
    }

    // Try several real seek targets near the media tail. Some HLS tail targets
    // are rejected or clamped by media_kit/mpv, so a single magic number is not
    // reliable enough.
    for (final backoff in _liveSeekBackoffCandidates) {
      addTarget(mediaDuration - backoff);
    }

    final proxyTarget = _proxySafeTargetInMediaTimeline(
      proxyLiveStatus: proxyLiveStatus,
      mediaDuration: mediaDuration,
    );
    if (proxyTarget != null) {
      addTarget(proxyTarget);
    }

    addTarget(_liveEdgeSeekTarget(mediaDuration));

    targets.sort((a, b) => b.compareTo(a));
    return targets;
  }

  double _sliderValueForTarget(Duration target, Duration duration) {
    if (duration.inMilliseconds <= 0) return 1.0;
    final value = target.inMilliseconds / duration.inMilliseconds;
    return value.clamp(0.0, 1.0).toDouble();
  }

  void _stopLiveSeekAttempt() {
    if (mounted && _seekingLiveEdge) {
      setState(() {
        _seekingLiveEdge = false;
      });
    } else {
      _seekingLiveEdge = false;
    }
  }

  void _appendLiveSeekProbeLine(List<String> lines, String line) {
    lines.add(line);
    debugPrint('[TwitchLiveSeek] $line');
  }

  String _liveSeekProbeProxyLine(
    dynamic proxyLiveStatus, {
    required Duration mediaDuration,
  }) {
    final mediaTarget = _proxySafeTargetInMediaTimeline(
      proxyLiveStatus: proxyLiveStatus,
      mediaDuration: mediaDuration,
    );
    final proxy = _proxyStatusTooltip(
      proxyLiveStatus,
      proxyMediaTarget: mediaTarget,
    );
    return proxy.isEmpty ? 'proxy=unavailable' : proxy;
  }

  Future<void> _goLive({
    required Duration position,
    required Duration duration,
    required dynamic proxyLiveStatus,
  }) async {
    if (duration.inMilliseconds <= 500) return;

    final targets = _liveSeekTargets(
      mediaDuration: duration,
      proxyLiveStatus: proxyLiveStatus,
    );
    if (targets.isEmpty) return;

    final originalPosition = position;
    final probeLines = <String>[];
    _appendLiveSeekProbeLine(
      probeLines,
      'START before=${_formatDuration(position)}/${_formatDuration(duration)} '
      'targets=${targets.map(_formatDuration).join(', ')}',
    );
    _appendLiveSeekProbeLine(
      probeLines,
      _liveSeekProbeProxyLine(proxyLiveStatus, mediaDuration: duration),
    );

    setState(() {
      _dragging = true;
      _dragValue = 1.0;
      _livePinned = true;
      _seekingLiveEdge = true;
      _lastLiveSeekProbeSummary = probeLines.join('\n');
    });

    var reachedLive = false;
    var lastTarget = targets.first;

    try {
      await player.play();

      for (var index = 0; index < targets.length; index++) {
        final target = targets[index];
        lastTarget = target;
        final beforeTryPosition = player.state.position;
        final beforeTryDuration = player.state.duration;

        _appendLiveSeekProbeLine(
          probeLines,
          'TRY #${index + 1} target=${_formatDuration(target)} '
          'before=${_formatDuration(beforeTryPosition)}/${_formatDuration(beforeTryDuration)}',
        );

        await player.seek(target);
        await Future<void>.delayed(_liveSeekVerifyDelay);

        final currentPosition = player.state.position;
        final currentDuration = player.state.duration;
        final currentProxyStatus = widget.playerRuntime.proxyLiveStatus;
        final liveLag = currentDuration.inMilliseconds > 500
            ? _safeLiveLag(position: currentPosition, duration: currentDuration)
            : Duration.zero;
        final distanceFromTarget = currentPosition > target
            ? currentPosition - target
            : target - currentPosition;
        final movedForward = currentPosition - originalPosition;

        final success = _isLiveSeekSuccessful(
          originalPosition: originalPosition,
          target: target,
          position: currentPosition,
          duration: currentDuration,
          proxyLiveStatus: currentProxyStatus,
        );

        _appendLiveSeekProbeLine(
          probeLines,
          'AFTER #${index + 1} pos=${_formatDuration(currentPosition)}/'
          '${_formatDuration(currentDuration)} lag=${liveLag.inMilliseconds}ms '
          'dist=${distanceFromTarget.inMilliseconds}ms '
          'moved=${movedForward.inMilliseconds}ms '
          'success=$success',
        );

        if (success) {
          reachedLive = true;
          break;
        }
      }
    } catch (error) {
      reachedLive = false;
      _appendLiveSeekProbeLine(probeLines, 'ERROR $error');
    } finally {
      if (!mounted) return;

      final finalPosition = player.state.position;
      final finalDuration = player.state.duration;
      final targetSliderValue = _sliderValueForTarget(lastTarget, finalDuration);
      _appendLiveSeekProbeLine(
        probeLines,
        'END reached=$reachedLive final=${_formatDuration(finalPosition)}/'
        '${_formatDuration(finalDuration)} sliderTarget='
        '${targetSliderValue.toStringAsFixed(3)}',
      );

      setState(() {
        _dragging = false;
        _dragValue = null;
        _seekingLiveEdge = false;
        _livePinned = reachedLive || targetSliderValue >= 0.97;
        _lastLiveSeekProbeSummary = probeLines.join('\n');
      });
    }
  }

  bool _isLiveSeekSuccessful({
    required Duration originalPosition,
    required Duration target,
    required Duration position,
    required Duration duration,
    required dynamic proxyLiveStatus,
  }) {
    if (duration.inMilliseconds <= 500) return false;

    final liveLag = _safeLiveLag(position: position, duration: duration);
    final streamValue = duration.inMilliseconds <= 0
        ? 1.0
        : (position.inMilliseconds / duration.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble();

    final closeEnough = _isCloseEnoughForLive(
      position: position,
      duration: duration,
      liveLag: liveLag,
      streamValue: streamValue,
      proxyLiveStatus: proxyLiveStatus,
    );
    if (closeEnough) return true;

    final distanceFromTarget = position > target ? position - target : target - position;
    if (distanceFromTarget <= _liveSeekSuccessTolerance) return true;

    final movedForward = position - originalPosition;
    return movedForward > const Duration(seconds: 3) &&
        liveLag <= const Duration(seconds: 7);
  }

  bool _isCloseEnoughForLive({
    required Duration position,
    required Duration duration,
    required Duration liveLag,
    required double streamValue,
    required dynamic proxyLiveStatus,
  }) {
    final proxyTarget = _proxySafeTargetInMediaTimeline(
      proxyLiveStatus: proxyLiveStatus,
      mediaDuration: duration,
    );

    if (proxyTarget != null) {
      final distanceFromProxySafe = position > proxyTarget
          ? position - proxyTarget
          : proxyTarget - position;
      if (distanceFromProxySafe <= _liveSeekSuccessTolerance) {
        return true;
      }
    }

    if (liveLag <= _liveSeekSuccessTolerance) return true;
    return streamValue >= 0.992;
  }

  bool _isNearLiveEdge({
    required bool hasSeekableDuration,
    required Duration position,
    required Duration duration,
    required Duration liveLag,
    required double streamValue,
    required dynamic proxyLiveStatus,
  }) {
    if (!hasSeekableDuration) return true;

    final proxyTarget = _proxySafeTargetInMediaTimeline(
      proxyLiveStatus: proxyLiveStatus,
      mediaDuration: duration,
    );

    if (proxyTarget != null) {
      final distanceFromProxySafe = position > proxyTarget
          ? position - proxyTarget
          : proxyTarget - position;

      if (distanceFromProxySafe <= const Duration(milliseconds: 2300)) {
        return true;
      }

      try {
        final lagSegments = proxyLiveStatus.lagSegments as int;
        if (lagSegments <= 1 && liveLag <= const Duration(milliseconds: 2600)) {
          return true;
        }
      } catch (_) {}

      return false;
    }

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
                        ? _safeLiveLag(position: position, duration: duration)
                        : Duration.zero;
                    final dynamic proxyLiveStatus =
                        widget.playerRuntime.proxyLiveStatus;
                    final nearLiveEdge = _isNearLiveEdge(
                      hasSeekableDuration: hasSeekableDuration,
                      position: position,
                      duration: duration,
                      liveLag: liveLag,
                      streamValue: streamValue,
                      proxyLiveStatus: proxyLiveStatus,
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
                    final proxyMediaTarget = _proxySafeTargetInMediaTimeline(
                      proxyLiveStatus: proxyLiveStatus,
                      mediaDuration: duration,
                    );

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
                                      if (next < 0.985) {
                                        _stopLiveSeekAttempt();
                                      }
                                      setState(() {
                                        _dragging = true;
                                        _dragValue = next;
                                        _livePinned = next >= 0.985;
                                      });
                                    }
                                  : null,
                              onChanged: hasSeekableDuration
                                  ? (next) {
                                      if (next < 0.985) {
                                        _stopLiveSeekAttempt();
                                      }
                                      setState(() {
                                        _dragValue = next;
                                        _livePinned = next >= 0.985;
                                      });
                                    }
                                  : null,
                              onChangeEnd: hasSeekableDuration
                                  ? (next) {
                                      final goLive = next >= 0.985;

                                      if (goLive) {
                                        unawaited(
                                          _goLive(
                                            position: position,
                                            duration: duration,
                                            proxyLiveStatus: proxyLiveStatus,
                                          ),
                                        );
                                        return;
                                      }

                                      final target = Duration(
                                        milliseconds:
                                            (duration.inMilliseconds * next)
                                                .round(),
                                      );

                                      _stopLiveSeekAttempt();
                                      setState(() {
                                        _dragging = false;
                                        _dragValue = null;
                                        _livePinned = false;
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
                          seeking: _seekingLiveEdge,
                          compact: compact,
                          onPressed: hasSeekableDuration
                              ? () => unawaited(
                                    _goLive(
                                      position: position,
                                      duration: duration,
                                      proxyLiveStatus: proxyLiveStatus,
                                    ),
                                  )
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
                            seeking: _seekingLiveEdge,
                            proxyLiveStatus: proxyLiveStatus,
                            proxyMediaTarget: proxyMediaTarget,
                            liveSeekProbe: _lastLiveSeekProbeSummary,
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
    required bool seeking,
    required dynamic proxyLiveStatus,
    required Duration? proxyMediaTarget,
    required String? liveSeekProbe,
  }) {
    final pos = _formatDuration(position);
    final dur = duration.inMilliseconds > 0 ? _formatDuration(duration) : '--:--';
    final state = buffering
        ? 'buffering'
        : seeking
            ? 'seeking live edge'
            : livePinned
                ? 'live edge'
                : playing
                    ? 'playing'
                    : 'paused';

    final proxy = _proxyStatusTooltip(
      proxyLiveStatus,
      proxyMediaTarget: proxyMediaTarget,
    );
    final parts = <String>[
      'media_kit $state · $pos / $dur',
      if (proxy.isNotEmpty) proxy,
      if (liveSeekProbe != null && liveSeekProbe.trim().isNotEmpty)
        'last LIVE probe:\n$liveSeekProbe',
    ];

    return parts.join('\n');
  }

  static String _proxyStatusTooltip(
    dynamic status, {
    required Duration? proxyMediaTarget,
  }) {
    if (status == null) return '';

    try {
      final safeLivePosition = status.safeLivePosition as Duration;
      final outputDuration = status.outputDuration as Duration;
      final backoff = status.liveBackoff as Duration;
      final lastSequence = status.lastWrittenSequence as int;
      final latestSequence = status.latestPlayableSequence as int;
      final bufferedBytes = status.bufferedBytes as int;
      final hasFutureSegment = status.hasFutureSegment as bool;
      final lagSegments = latestSequence - lastSequence;

      final mediaTargetText = proxyMediaTarget == null
          ? ''
          : ' · mediaTarget=${_formatDuration(proxyMediaTarget)}';

      return 'proxy safe=${_formatDuration(safeLivePosition)} / '
          'out=${_formatDuration(outputDuration)}$mediaTargetText · '
          'backoff=${backoff.inMilliseconds}ms · '
          'seq=$lastSequence/$latestSequence · '
          'lag=$lagSegments · '
          'future=${hasFutureSegment ? "yes" : "no"} · '
          'buffer=${(bufferedBytes / 1024).toStringAsFixed(0)}KB';
    } catch (_) {
      return 'proxy status unavailable';
    }
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
  final bool seeking;
  final bool compact;
  final VoidCallback? onPressed;

  const _LiveEdgeButton({
    required this.active,
    required this.enabled,
    required this.buffering,
    required this.seeking,
    required this.compact,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = buffering || seeking
        ? Colors.orangeAccent
        : active
            ? Colors.redAccent
            : Colors.white54;
    final border = buffering || seeking
        ? Colors.orangeAccent.withOpacity(0.42)
        : active
            ? Colors.redAccent.withOpacity(0.52)
            : Colors.white.withOpacity(0.16);
    final background = active
        ? Colors.redAccent.withOpacity(0.16)
        : seeking
            ? Colors.orangeAccent.withOpacity(0.12)
            : const Color(0xFF18181B).withOpacity(0.86);

    return Tooltip(
      message: seeking
          ? '正在嘗試跳到直播最新位置'
          : active
              ? '目前在直播最新位置'
              : '跳到直播最新位置',
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
