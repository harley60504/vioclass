# Stage 141 apply script - Proxy live status
# Run from project root:
#   python tools/apply_stage141_proxy_live_status.py
#
# This script keeps large files safe by editing small known snippets instead of
# replacing the whole HLS proxy file.

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

MODEL_PATH = ROOT / "lib/features/twitch/models/playback/twitch_hls_proxy_models.dart"
LIVE_STRIP_PATH = ROOT / "lib/features/twitch/presentation/widgets/watch/player/twitch_live_playback_strip.dart"
PROXY_PATH = ROOT / "lib/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart"
RUNTIME_PATH = ROOT / "lib/features/twitch/services/playback/twitch_playlist_player_runtime.dart"

MODEL_CONTENT = "import 'dart:async';\n\nclass TwitchHlsSegmentItem {\n  final String url;\n  final String? mapUrl;\n  final String label;\n  final int sequence;\n  final bool isPrefetch;\n  final Duration duration;\n\n  const TwitchHlsSegmentItem({\n    required this.url,\n    required this.mapUrl,\n    required this.label,\n    required this.sequence,\n    this.isPrefetch = false,\n    this.duration = const Duration(seconds: 2),\n  });\n}\n\nclass TwitchHlsSegmentPrefetchJob {\n  final TwitchHlsSegmentItem item;\n  final StreamController<List<int>> controller = StreamController<List<int>>();\n  final Completer<void> completed = Completer<void>();\n  Object? error;\n  StackTrace? stackTrace;\n  bool cancelled = false;\n\n  TwitchHlsSegmentPrefetchJob(this.item);\n\n  void cancel() {\n    cancelled = true;\n    if (!controller.isClosed) {\n      controller.close();\n    }\n  }\n}\n\nclass TwitchParsedMediaPlaylist {\n  final List<TwitchHlsSegmentItem> items;\n  final Duration reloadDelay;\n  final int normalCount;\n  final int futureCount;\n  final int mediaSequence;\n  final Duration targetDuration;\n  final bool hasEndList;\n\n  const TwitchParsedMediaPlaylist({\n    required this.items,\n    required this.reloadDelay,\n    required this.normalCount,\n    required this.futureCount,\n    required this.mediaSequence,\n    this.targetDuration = const Duration(seconds: 2),\n    this.hasEndList = false,\n  });\n}\n\nclass TwitchHlsLiveStatus {\n  final bool running;\n  final bool hasWriter;\n  final bool hasFutureSegment;\n  final int playlistVersion;\n  final int activeClientCount;\n  final int latestPlayableSequence;\n  final int lastWrittenSequence;\n  final int bufferedBytes;\n  final bool lastWrittenWasPrefetch;\n  final Duration outputDuration;\n  final Duration safeLivePosition;\n  final Duration liveBackoff;\n  final DateTime updatedAt;\n\n  const TwitchHlsLiveStatus({\n    required this.running,\n    required this.hasWriter,\n    required this.hasFutureSegment,\n    required this.playlistVersion,\n    required this.activeClientCount,\n    required this.latestPlayableSequence,\n    required this.lastWrittenSequence,\n    required this.bufferedBytes,\n    required this.lastWrittenWasPrefetch,\n    required this.outputDuration,\n    required this.safeLivePosition,\n    required this.liveBackoff,\n    required this.updatedAt,\n  });\n\n  int get lagSegments {\n    if (latestPlayableSequence < 0 || lastWrittenSequence < 0) return 0;\n    return latestPlayableSequence - lastWrittenSequence;\n  }\n\n  bool get hasOutput => outputDuration.inMilliseconds > 0;\n\n  Map<String, Object?> toJson() {\n    return <String, Object?>{\n      'running': running,\n      'hasWriter': hasWriter,\n      'hasFutureSegment': hasFutureSegment,\n      'playlistVersion': playlistVersion,\n      'activeClientCount': activeClientCount,\n      'latestPlayableSequence': latestPlayableSequence,\n      'lastWrittenSequence': lastWrittenSequence,\n      'lagSegments': lagSegments,\n      'bufferedBytes': bufferedBytes,\n      'lastWrittenWasPrefetch': lastWrittenWasPrefetch,\n      'outputDurationMs': outputDuration.inMilliseconds,\n      'safeLivePositionMs': safeLivePosition.inMilliseconds,\n      'liveBackoffMs': liveBackoff.inMilliseconds,\n      'updatedAtMs': updatedAt.millisecondsSinceEpoch,\n    };\n  }\n\n  factory TwitchHlsLiveStatus.fromJson(Map<String, Object?> json) {\n    int readInt(String key, [int fallback = 0]) {\n      final value = json[key];\n      if (value is int) return value;\n      if (value is num) return value.round();\n      return int.tryParse(value?.toString() ?? '') ?? fallback;\n    }\n\n    bool readBool(String key, [bool fallback = false]) {\n      final value = json[key];\n      if (value is bool) return value;\n      final text = value?.toString().toLowerCase();\n      if (text == 'true') return true;\n      if (text == 'false') return false;\n      return fallback;\n    }\n\n    Duration readDuration(String key) {\n      return Duration(milliseconds: readInt(key));\n    }\n\n    final updatedAtMs = readInt(\n      'updatedAtMs',\n      DateTime.now().millisecondsSinceEpoch,\n    );\n\n    return TwitchHlsLiveStatus(\n      running: readBool('running'),\n      hasWriter: readBool('hasWriter'),\n      hasFutureSegment: readBool('hasFutureSegment'),\n      playlistVersion: readInt('playlistVersion'),\n      activeClientCount: readInt('activeClientCount'),\n      latestPlayableSequence: readInt('latestPlayableSequence', -1),\n      lastWrittenSequence: readInt('lastWrittenSequence', -1),\n      bufferedBytes: readInt('bufferedBytes'),\n      lastWrittenWasPrefetch: readBool('lastWrittenWasPrefetch'),\n      outputDuration: readDuration('outputDurationMs'),\n      safeLivePosition: readDuration('safeLivePositionMs'),\n      liveBackoff: readDuration('liveBackoffMs'),\n      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),\n    );\n  }\n\n  static TwitchHlsLiveStatus stopped() {\n    return TwitchHlsLiveStatus(\n      running: false,\n      hasWriter: false,\n      hasFutureSegment: false,\n      playlistVersion: 0,\n      activeClientCount: 0,\n      latestPlayableSequence: -1,\n      lastWrittenSequence: -1,\n      bufferedBytes: 0,\n      lastWrittenWasPrefetch: false,\n      outputDuration: Duration.zero,\n      safeLivePosition: Duration.zero,\n      liveBackoff: Duration.zero,\n      updatedAt: DateTime.now(),\n    );\n  }\n}\n"
LIVE_STRIP_CONTENT = 'part of twitch_watch_player_area;\n\nclass TwitchLivePlaybackStrip extends StatefulWidget {\n  final Player player;\n  final TwitchPlaylistPlayerRuntime playerRuntime;\n  final bool compact;\n\n  const TwitchLivePlaybackStrip({\n    super.key,\n    required this.player,\n    required this.playerRuntime,\n    this.compact = false,\n  });\n\n  @override\n  State<TwitchLivePlaybackStrip> createState() => _TwitchLivePlaybackStripState();\n}\n\nclass _TwitchLivePlaybackStripState extends State<TwitchLivePlaybackStrip> {\n  static const Duration _liveEdgeUiTolerance = Duration(seconds: 5);\n  static const Duration _liveEdgeSeekBackoff = Duration(milliseconds: 350);\n\n  bool _dragging = false;\n  bool _livePinned = true;\n  double? _dragValue;\n  Timer? _proxyLiveStatusTimer;\n\n  Player get player => widget.player;\n  bool get compact => widget.compact;\n\n  @override\n  void initState() {\n    super.initState();\n    _startProxyLiveStatusPolling();\n  }\n\n  @override\n  void dispose() {\n    _proxyLiveStatusTimer?.cancel();\n    super.dispose();\n  }\n\n  void _startProxyLiveStatusPolling() {\n    _proxyLiveStatusTimer?.cancel();\n    unawaited(widget.playerRuntime.refreshProxyLiveStatus());\n    _proxyLiveStatusTimer = Timer.periodic(\n      const Duration(seconds: 1),\n      (_) => unawaited(widget.playerRuntime.refreshProxyLiveStatus()),\n    );\n  }\n\n  @override\n  void didUpdateWidget(covariant TwitchLivePlaybackStrip oldWidget) {\n    super.didUpdateWidget(oldWidget);\n    if (!identical(oldWidget.playerRuntime, widget.playerRuntime)) {\n      _startProxyLiveStatusPolling();\n    }\n  }\n\n  Duration _liveEdgeSeekTarget(Duration duration) {\n    final ms = duration.inMilliseconds;\n    if (ms <= 0) return Duration.zero;\n\n    final backoff = _liveEdgeSeekBackoff.inMilliseconds;\n    final targetMs = ms <= backoff * 2 ? ms : ms - backoff;\n    return Duration(milliseconds: targetMs);\n  }\n\n  Future<void> _seekToLiveEdge(Duration duration) async {\n    final target = _liveEdgeSeekTarget(duration);\n\n    setState(() {\n      _dragging = true;\n      _dragValue = 1.0;\n      _livePinned = true;\n    });\n\n    try {\n      await player.seek(target);\n      await player.play();\n    } finally {\n      if (!mounted) return;\n      setState(() {\n        _dragging = false;\n        _dragValue = null;\n        _livePinned = true;\n      });\n    }\n  }\n\n  bool _isNearLiveEdge({\n    required bool hasSeekableDuration,\n    required Duration liveLag,\n    required double streamValue,\n  }) {\n    if (!hasSeekableDuration) return true;\n    if (liveLag <= _liveEdgeUiTolerance) return true;\n    return streamValue >= 0.985;\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    return StreamBuilder<Duration>(\n      stream: player.stream.position,\n      initialData: player.state.position,\n      builder: (context, positionSnapshot) {\n        return StreamBuilder<Duration>(\n          stream: player.stream.duration,\n          initialData: player.state.duration,\n          builder: (context, durationSnapshot) {\n            return StreamBuilder<bool>(\n              stream: player.stream.buffering,\n              initialData: player.state.buffering,\n              builder: (context, bufferingSnapshot) {\n                return StreamBuilder<bool>(\n                  stream: player.stream.playing,\n                  initialData: player.state.playing,\n                  builder: (context, playingSnapshot) {\n                    final position = positionSnapshot.data ?? Duration.zero;\n                    final duration = durationSnapshot.data ?? Duration.zero;\n                    final buffering = bufferingSnapshot.data ?? false;\n                    final playing = playingSnapshot.data ?? false;\n\n                    final hasSeekableDuration = duration.inMilliseconds > 500;\n                    final rawValue = hasSeekableDuration\n                        ? position.inMilliseconds / duration.inMilliseconds\n                        : 1.0;\n                    final streamValue = rawValue.clamp(0.0, 1.0).toDouble();\n                    final liveLag = hasSeekableDuration\n                        ? duration - position\n                        : Duration.zero;\n                    final nearLiveEdge = _isNearLiveEdge(\n                      hasSeekableDuration: hasSeekableDuration,\n                      liveLag: liveLag,\n                      streamValue: streamValue,\n                    );\n                    final isAtLiveEdge = _livePinned && nearLiveEdge;\n\n                    final value = _dragging\n                        ? (_dragValue ?? streamValue).clamp(0.0, 1.0).toDouble()\n                        : isAtLiveEdge\n                            ? 1.0\n                            : streamValue;\n                    final previewPosition = hasSeekableDuration\n                        ? isAtLiveEdge && !_dragging\n                            ? duration\n                            : Duration(\n                                milliseconds:\n                                    (duration.inMilliseconds * value).round(),\n                              )\n                        : position;\n                    final positionText = _formatDuration(previewPosition);\n                    final durationText = hasSeekableDuration\n                        ? _formatDuration(duration)\n                        : \'--:--\';\n                    final timeColor = buffering\n                        ? Colors.orangeAccent\n                        : Colors.white60;\n                    final timeText = \'$positionText / $durationText\';\n                    final dynamic proxyLiveStatus =\n                        widget.playerRuntime.proxyLiveStatus;\n\n                    return Row(\n                      children: [\n                        Expanded(\n                          child: SliderTheme(\n                            data: SliderTheme.of(context).copyWith(\n                              trackHeight: compact ? 4 : 5,\n                              thumbShape: RoundSliderThumbShape(\n                                enabledThumbRadius: compact ? 6 : 7,\n                              ),\n                            ),\n                            child: Slider(\n                              value: value,\n                              min: 0,\n                              max: 1,\n                              onChangeStart: hasSeekableDuration\n                                  ? (next) {\n                                      setState(() {\n                                        _dragging = true;\n                                        _dragValue = next;\n                                        _livePinned = next >= 0.985;\n                                      });\n                                    }\n                                  : null,\n                              onChanged: hasSeekableDuration\n                                  ? (next) {\n                                      setState(() {\n                                        _dragValue = next;\n                                        _livePinned = next >= 0.985;\n                                      });\n                                    }\n                                  : null,\n                              onChangeEnd: hasSeekableDuration\n                                  ? (next) {\n                                      final goLive = next >= 0.985;\n                                      final target = goLive\n                                          ? _liveEdgeSeekTarget(duration)\n                                          : Duration(\n                                              milliseconds:\n                                                  (duration.inMilliseconds * next)\n                                                      .round(),\n                                            );\n\n                                      setState(() {\n                                        _dragging = false;\n                                        _dragValue = null;\n                                        _livePinned = goLive;\n                                      });\n\n                                      unawaited(player.seek(target));\n                                    }\n                                  : null,\n                            ),\n                          ),\n                        ),\n                        SizedBox(width: compact ? 6 : 8),\n                        _LiveEdgeButton(\n                          active: isAtLiveEdge,\n                          enabled: hasSeekableDuration,\n                          buffering: buffering,\n                          compact: compact,\n                          onPressed: hasSeekableDuration\n                              ? () => unawaited(_seekToLiveEdge(duration))\n                              : null,\n                        ),\n                        SizedBox(width: compact ? 6 : 8),\n                        Tooltip(\n                          message: _timeStatusTooltip(\n                            position: previewPosition,\n                            duration: duration,\n                            buffering: buffering,\n                            playing: playing,\n                            livePinned: isAtLiveEdge,\n                            proxyLiveStatus: proxyLiveStatus,\n                          ),\n                          child: ConstrainedBox(\n                            constraints: BoxConstraints(\n                              minWidth: compact ? 82 : 108,\n                              maxWidth: compact ? 104 : 136,\n                            ),\n                            child: Padding(\n                              padding: EdgeInsets.symmetric(\n                                horizontal: compact ? 4 : 6,\n                                vertical: compact ? 5 : 6,\n                              ),\n                              child: Text(\n                                timeText,\n                                textAlign: TextAlign.right,\n                                maxLines: 1,\n                                overflow: TextOverflow.fade,\n                                softWrap: false,\n                                style: TextStyle(\n                                  color: timeColor,\n                                  fontSize: compact ? 11 : 12,\n                                  fontWeight: FontWeight.w900,\n                                  fontFeatures: const [\n                                    FontFeature.tabularFigures(),\n                                  ],\n                                ),\n                              ),\n                            ),\n                          ),\n                        ),\n                      ],\n                    );\n                  },\n                );\n              },\n            );\n          },\n        );\n      },\n    );\n  }\n\n  static String _timeStatusTooltip({\n    required Duration position,\n    required Duration duration,\n    required bool buffering,\n    required bool playing,\n    required bool livePinned,\n    required dynamic proxyLiveStatus,\n  }) {\n    final pos = _formatDuration(position);\n    final dur = duration.inMilliseconds > 0 ? _formatDuration(duration) : \'--:--\';\n    final state = buffering\n        ? \'buffering\'\n        : livePinned\n            ? \'live edge\'\n            : playing\n                ? \'playing\'\n                : \'paused\';\n\n    final proxy = _proxyStatusTooltip(proxyLiveStatus);\n    if (proxy.isEmpty) {\n      return \'media_kit $state · $pos / $dur\';\n    }\n\n    return \'media_kit $state · $pos / $dur\\n$proxy\';\n  }\n\n  static String _proxyStatusTooltip(dynamic status) {\n    if (status == null) return \'\';\n\n    try {\n      final safeLivePosition = status.safeLivePosition as Duration;\n      final outputDuration = status.outputDuration as Duration;\n      final backoff = status.liveBackoff as Duration;\n      final lastSequence = status.lastWrittenSequence as int;\n      final latestSequence = status.latestPlayableSequence as int;\n      final bufferedBytes = status.bufferedBytes as int;\n      final hasFutureSegment = status.hasFutureSegment as bool;\n      final lagSegments = latestSequence - lastSequence;\n\n      return \'proxy safe=${_formatDuration(safeLivePosition)} / \'\n          \'out=${_formatDuration(outputDuration)} · \'\n          \'backoff=${backoff.inMilliseconds}ms · \'\n          \'seq=$lastSequence/$latestSequence · \'\n          \'lag=$lagSegments · \'\n          \'future=${hasFutureSegment ? "yes" : "no"} · \'\n          \'buffer=${(bufferedBytes / 1024).toStringAsFixed(0)}KB\';\n    } catch (_) {\n      return \'proxy status unavailable\';\n    }\n  }\n\n  static String _formatDuration(Duration value) {\n    final totalSeconds = value.inSeconds;\n    final seconds = (totalSeconds % 60).toString().padLeft(2, \'0\');\n    final minutesTotal = totalSeconds ~/ 60;\n    final minutes = (minutesTotal % 60).toString().padLeft(2, \'0\');\n    final hours = totalSeconds ~/ 3600;\n    if (hours > 0) {\n      return \'$hours:$minutes:$seconds\';\n    }\n    return \'$minutes:$seconds\';\n  }\n}\n\nclass _LiveEdgeButton extends StatelessWidget {\n  final bool active;\n  final bool enabled;\n  final bool buffering;\n  final bool compact;\n  final VoidCallback? onPressed;\n\n  const _LiveEdgeButton({\n    required this.active,\n    required this.enabled,\n    required this.buffering,\n    required this.compact,\n    required this.onPressed,\n  });\n\n  @override\n  Widget build(BuildContext context) {\n    final foreground = buffering\n        ? Colors.orangeAccent\n        : active\n            ? Colors.redAccent\n            : Colors.white54;\n    final border = buffering\n        ? Colors.orangeAccent.withOpacity(0.42)\n        : active\n            ? Colors.redAccent.withOpacity(0.52)\n            : Colors.white.withOpacity(0.16);\n    final background = active\n        ? Colors.redAccent.withOpacity(0.16)\n        : const Color(0xFF18181B).withOpacity(0.86);\n\n    return Tooltip(\n      message: active ? \'目前在直播最新位置\' : \'跳到直播最新位置\',\n      child: Material(\n        color: background,\n        borderRadius: BorderRadius.circular(999),\n        clipBehavior: Clip.antiAlias,\n        child: InkWell(\n          onTap: enabled ? onPressed : null,\n          borderRadius: BorderRadius.circular(999),\n          child: Container(\n            height: compact ? 25 : 28,\n            padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9),\n            alignment: Alignment.center,\n            decoration: BoxDecoration(\n              borderRadius: BorderRadius.circular(999),\n              border: Border.all(color: enabled ? border : Colors.white10),\n            ),\n            child: Row(\n              mainAxisSize: MainAxisSize.min,\n              children: [\n                Container(\n                  width: compact ? 5 : 6,\n                  height: compact ? 5 : 6,\n                  decoration: BoxDecoration(\n                    color: enabled ? foreground : Colors.white24,\n                    shape: BoxShape.circle,\n                  ),\n                ),\n                SizedBox(width: compact ? 4 : 5),\n                Text(\n                  \'LIVE\',\n                  style: TextStyle(\n                    color: enabled ? foreground : Colors.white24,\n                    fontSize: compact ? 10 : 11,\n                    fontWeight: FontWeight.w900,\n                    letterSpacing: 0.2,\n                  ),\n                ),\n              ],\n            ),\n          ),\n        ),\n      ),\n    );\n  }\n}\n'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        if new in text:
            print(f"[skip] {label} already applied")
            return text
        raise RuntimeError(f"Cannot find patch anchor: {label}")
    print(f"[patch] {label}")
    return text.replace(old, new, 1)


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"[write] {path.relative_to(ROOT)}")


def patch_proxy() -> None:
    text = PROXY_PATH.read_text(encoding="utf-8")

    text = replace_once(
        text,
        "  String? _playlistUrl;\n  String? _streamUrl;\n  String? _streamTsUrl;\n  bool _running = false;",
        "  String? _playlistUrl;\n  String? _streamUrl;\n  String? _streamTsUrl;\n  TwitchHlsLiveStatus? _liveStatus;\n  bool _running = false;",
        "proxy field _liveStatus",
    )

    text = replace_once(
        text,
        """  String get streamTsUrl {
    final value = _streamTsUrl;
    if (value == null) throw StateError('Proxy has not started.');
    return value;
  }
""",
        """  String get streamTsUrl {
    final value = _streamTsUrl;
    if (value == null) throw StateError('Proxy has not started.');
    return value;
  }

  TwitchHlsLiveStatus? get liveStatus => _liveStatus;
""",
        "proxy liveStatus getter",
    )

    text = replace_once(
        text,
        """      } else if (type == 'log') {
        final message = raw['message']?.toString();
        if (message != null) {
          onLog?.call(message);
        }
      } else if (type == 'error') {
""",
        """      } else if (type == 'log') {
        final message = raw['message']?.toString();
        if (message != null) {
          onLog?.call(message);
        }
      } else if (type == 'liveStatus') {
        final rawStatus = raw['status'];
        if (rawStatus is Map) {
          _liveStatus = TwitchHlsLiveStatus.fromJson(
            Map<String, Object?>.from(rawStatus),
          );
        }
      } else if (type == 'error') {
""",
        "proxy event liveStatus",
    )

    text = replace_once(
        text,
        """  Future<void> close() async {
    _starting = false;
""",
        """  Future<TwitchHlsLiveStatus?> requestLiveStatus({
    Duration timeout = const Duration(milliseconds: 280),
  }) async {
    final control = _controlPort;
    if (!_running || control == null) {
      _liveStatus = null;
      return null;
    }

    final reply = ReceivePort();
    try {
      control.send(<String, Object?>{
        'type': 'liveStatus',
        'replyPort': reply.sendPort,
      });

      final raw = await reply.first.timeout(timeout);
      if (raw is Map) {
        final rawStatus = raw['status'];
        if (rawStatus is Map) {
          final status = TwitchHlsLiveStatus.fromJson(
            Map<String, Object?>.from(rawStatus),
          );
          _liveStatus = status;
          return status;
        }
      }
    } catch (_) {
      // Best effort only. Keep the previous status so UI debugging does not
      // flicker to null on a single missed isolate reply.
    } finally {
      reply.close();
    }

    return _liveStatus;
  }

  Future<void> close() async {
    _starting = false;
""",
        "proxy requestLiveStatus method",
    )

    text = replace_once(
        text,
        "    _streamUrl = null;\n    _streamTsUrl = null;\n\n    final isolate = _isolate;",
        "    _streamUrl = null;\n    _streamTsUrl = null;\n    _liveStatus = null;\n\n    final isolate = _isolate;",
        "proxy clear liveStatus on close",
    )

    text = replace_once(
        text,
        """      if (type == 'waitReady') {
        final timeoutMs = raw['timeoutMs'] as int? ?? 700;
        await proxy.waitUntilPrewarmed(
          timeout: Duration(milliseconds: timeoutMs),
        );
        commandReply?.send(<String, Object?>{'type': 'waitReady.done'});
      }
""",
        """      if (type == 'waitReady') {
        final timeoutMs = raw['timeoutMs'] as int? ?? 700;
        await proxy.waitUntilPrewarmed(
          timeout: Duration(milliseconds: timeoutMs),
        );
        commandReply?.send(<String, Object?>{'type': 'waitReady.done'});
      }

      if (type == 'liveStatus') {
        commandReply?.send(<String, Object?>{
          'type': 'liveStatus.done',
          'status': proxy.liveStatus().toJson(),
        });
      }
""",
        "isolate liveStatus command",
    )

    text = replace_once(
        text,
        """  Future<void> close() async {
    final currentServer = server;
""",
        """  TwitchHlsLiveStatus liveStatus() {
    final engine = _prewarmEngine;
    if (engine == null || engine.isStopped) {
      return TwitchHlsLiveStatus.stopped();
    }
    return engine.liveStatus();
  }

  Future<void> close() async {
    final currentServer = server;
""",
        "core liveStatus method",
    )

    text = replace_once(
        text,
        """  int maxOutputBacklogSegments() {
    return _maxOutputBacklogSegments;
  }

  List<TwitchHlsSegmentItem> _buildOutputCandidates({
""",
        """  int maxOutputBacklogSegments() {
    return _maxOutputBacklogSegments;
  }

  TwitchHlsLiveStatus liveStatus() {
    final writer = _writer;
    if (writer != null && !writer.isStopped) {
      return writer.liveStatus();
    }

    final hasFutureSegment = _lastOutputCandidates.any(
      (item) => item.isPrefetch,
    );

    return TwitchHlsLiveStatus(
      running: !_stopped,
      hasWriter: false,
      hasFutureSegment: hasFutureSegment,
      playlistVersion: _playlistVersion,
      activeClientCount: _activeClientCount,
      latestPlayableSequence: _latestPlayableSequence,
      lastWrittenSequence: -1,
      bufferedBytes: _liveBus.bufferedBytes,
      lastWrittenWasPrefetch: false,
      outputDuration: Duration.zero,
      safeLivePosition: Duration.zero,
      liveBackoff: Duration.zero,
      updatedAt: DateTime.now(),
    );
  }

  List<TwitchHlsSegmentItem> _buildOutputCandidates({
""",
        "engine liveStatus method",
    )

    text = replace_once(
        text,
        """  int _lastWrittenSequence = -1;
  int? _startupInitialLatestSequence;
  String? _lastMapUrl;

  final Set<int> _sessionWrittenSequences = <int>{};
""",
        """  int _lastWrittenSequence = -1;
  int? _startupInitialLatestSequence;
  String? _lastMapUrl;
  Duration _writtenOutputDuration = Duration.zero;
  Duration _lastWrittenDuration = Duration.zero;
  bool _lastWrittenWasPrefetch = false;
  DateTime? _lastWrittenAt;

  final Set<int> _sessionWrittenSequences = <int>{};
""",
        "writer live duration fields",
    )

    text = replace_once(
        text,
        """  void stop() {
    if (_stopped) return;
    _stopped = true;
  }

  Future<TwitchHlsSegmentItem?> _selectStartupItem() async {
""",
        """  void stop() {
    if (_stopped) return;
    _stopped = true;
  }

  TwitchHlsLiveStatus liveStatus() {
    final latestPlayable = engine.latestPlayableSequence();
    final backoff = _liveBackoff(_lastWrittenDuration);
    final safeLivePosition = _writtenOutputDuration > backoff
        ? _writtenOutputDuration - backoff
        : Duration.zero;
    final hasFutureSegment = engine._lastOutputCandidates.any(
      (item) => item.isPrefetch,
    );

    return TwitchHlsLiveStatus(
      running: !engine.isStopped && !_stopped,
      hasWriter: true,
      hasFutureSegment: hasFutureSegment,
      playlistVersion: engine.playlistVersion(),
      activeClientCount: engine._activeClientCount,
      latestPlayableSequence: latestPlayable,
      lastWrittenSequence: _lastWrittenSequence,
      bufferedBytes: engine._liveBus.bufferedBytes,
      lastWrittenWasPrefetch: _lastWrittenWasPrefetch,
      outputDuration: _writtenOutputDuration,
      safeLivePosition: safeLivePosition,
      liveBackoff: backoff,
      updatedAt: _lastWrittenAt ?? DateTime.now(),
    );
  }

  Duration _liveBackoff(Duration lastSegmentDuration) {
    final segmentMs = lastSegmentDuration.inMilliseconds;
    if (segmentMs <= 0) return const Duration(milliseconds: 900);

    final backoffMs = (segmentMs * 0.45)
        .round()
        .clamp(700, 1800)
        .toInt();

    return Duration(milliseconds: backoffMs);
  }

  Future<TwitchHlsSegmentItem?> _selectStartupItem() async {
""",
        "writer liveStatus method",
    )

    text = replace_once(
        text,
        """    engine.markWritten(item);
  }
}
""",
        """    engine.markWritten(item);

    _writtenOutputDuration += item.duration;
    _lastWrittenDuration = item.duration;
    _lastWrittenWasPrefetch = item.isPrefetch;
    _lastWrittenAt = DateTime.now();
  }
}
""",
        "writer update live duration",
    )

    PROXY_PATH.write_text(text, encoding="utf-8")
    print(f"[write] {PROXY_PATH.relative_to(ROOT)}")


def patch_runtime() -> None:
    text = RUNTIME_PATH.read_text(encoding="utf-8")

    text = replace_once(
        text,
        "import '../../models/playback/twitch_m3u8_variant.dart';\nimport '../../models/playback/twitch_playback.dart';",
        "import '../../models/playback/twitch_m3u8_variant.dart';\nimport '../../models/playback/twitch_hls_proxy_models.dart';\nimport '../../models/playback/twitch_playback.dart';",
        "runtime import live status model",
    )

    text = replace_once(
        text,
        "  String? _proxyUrl;\n  String? _proxyMpvUrl;\n  TwitchDartHlsLowLatencyProxy? _proxy;",
        "  String? _proxyUrl;\n  String? _proxyMpvUrl;\n  TwitchHlsLiveStatus? _proxyLiveStatus;\n  TwitchDartHlsLowLatencyProxy? _proxy;",
        "runtime live status field",
    )

    text = replace_once(
        text,
        "  String? get proxyUrl => _proxyUrl;\n  String? get proxyMpvUrl => _proxyMpvUrl ?? _proxyUrl;\n  bool get hasProxyUrl",
        "  String? get proxyUrl => _proxyUrl;\n  String? get proxyMpvUrl => _proxyMpvUrl ?? _proxyUrl;\n  TwitchHlsLiveStatus? get proxyLiveStatus => _proxyLiveStatus;\n  bool get hasProxyUrl",
        "runtime live status getter",
    )

    text = replace_once(
        text,
        """    _proxyUrl = proxy.streamTsUrl;
    _proxyMpvUrl = proxy.streamTsUrl;
    return Uri.tryParse(_proxyUrl!) ?? upstreamUri;
  }

  Future<void> _stopProxy({bool notify = true}) async {
""",
        """    _proxyUrl = proxy.streamTsUrl;
    _proxyMpvUrl = proxy.streamTsUrl;
    _proxyLiveStatus = null;
    return Uri.tryParse(_proxyUrl!) ?? upstreamUri;
  }

  Future<TwitchHlsLiveStatus?> refreshProxyLiveStatus({
    bool notify = true,
  }) async {
    final proxy = _proxy;
    if (proxy == null || !proxy.isRunning) {
      if (_proxyLiveStatus != null) {
        _proxyLiveStatus = null;
        if (notify) notifyListeners();
      }
      return null;
    }

    final status = await proxy.requestLiveStatus();
    if (status != null) {
      _proxyLiveStatus = status;
      if (notify) notifyListeners();
    }
    return status;
  }

  Future<void> _stopProxy({bool notify = true}) async {
""",
        "runtime refreshProxyLiveStatus method",
    )

    text = replace_once(
        text,
        "    _proxyUrl = null;\n    _proxyMpvUrl = null;\n\n    if (proxy != null)",
        "    _proxyUrl = null;\n    _proxyMpvUrl = null;\n    _proxyLiveStatus = null;\n\n    if (proxy != null)",
        "runtime clear live status on stop",
    )

    text = replace_once(
        text,
        "    _proxyUrl = null;\n    _proxyMpvUrl = null;\n    _loading = false;",
        "    _proxyUrl = null;\n    _proxyMpvUrl = null;\n    _proxyLiveStatus = null;\n    _loading = false;",
        "runtime clear live status on clear",
    )

    text = replace_once(
        text,
        "      'proxyStreamUrl': proxy?.streamUrl,\n      'proxyRunning': proxy?.isRunning ?? false,",
        "      'proxyStreamUrl': proxy?.streamUrl,\n      'proxyLiveStatus': proxyLiveStatus?.toJson(),\n      'proxyRunning': proxy?.isRunning ?? false,",
        "runtime toJson live status",
    )

    RUNTIME_PATH.write_text(text, encoding="utf-8")
    print(f"[write] {RUNTIME_PATH.relative_to(ROOT)}")


def main() -> None:
    write_text(MODEL_PATH, MODEL_CONTENT)
    write_text(LIVE_STRIP_PATH, LIVE_STRIP_CONTENT)
    patch_proxy()
    patch_runtime()
    print("\nStage 141 applied. Next:")
    print("  flutter analyze")
    print("  flutter run")


if __name__ == "__main__":
    main()
