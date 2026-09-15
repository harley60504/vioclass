part of '../twitch_hls_low_latency_proxy.dart';

enum TwitchHlsStartupMode {
  latestNormalImmediate,
  nextNormalFresh,
  firstFutureIfAvailable,
  firstReadyFutureIfAvailable,
  stableFreshEdge,

  /// 更接近 Streamlink 的起播方式：
  /// normal + Twitch future/prefetch 合成同一個 segment list，
  /// 再用 live-edge 從尾端倒數選起始 segment。
  ///
  /// edgeSegmentCount = 1 時：
  /// - 如果尾端是 future/prefetch，就直接選 future
  /// - 不要求 future 已經 firstChunk
  /// - 交給 HTTP request 掛著等 Twitch 開始吐資料
  streamlinkLiveEdge,
}

const Duration _liveReplayCacheDuration = Duration(seconds: 22);

class _TwitchHlsPrefetchRuntimeState {
  DateTime? requestStartedAt;
  DateTime? responseOpenedAt;
  DateTime? firstChunkAt;
  int bytesReceived = 0;
  bool failed = false;

  bool get responseOpened => responseOpenedAt != null;
  bool get hasFirstChunk => firstChunkAt != null && bytesReceived > 0;
}

class TwitchDartHlsLowLatencyProxy {
  final String upstreamPlaylistUrl;
  final Map<String, String> upstreamHeaders;
  final int edgeSegmentCount;
  final int prefetchSegmentCount;
  final bool outputFutureSegments;
  final int futureOutputSegmentCount;
  final void Function(String message)? onLog;
  final bool verboseLogging;
  final Duration minPlaylistReloadDelay;
  final Duration maxPlaylistReloadDelay;
  final bool dropBehindLiveEdge;
  final int startupEdgeSegmentCount;
  final bool startupRequirePrefetchedFirstSegment;
  final bool startupSkipCurrentLatestSegment;
  final Duration startupPrefetchWaitTimeout;
  final Duration startupFutureReadyWaitTimeout;
  final Duration idleKeepAliveDuration;
  final TwitchHlsStartupMode startupMode;
  final DateTime? timelineOrigin;
  final Duration isolateStartupTimeout;

  TwitchDartHlsLowLatencyProxy({
    required this.upstreamPlaylistUrl,
    required this.upstreamHeaders,
    this.edgeSegmentCount = 1,
    this.prefetchSegmentCount = 3,
    this.outputFutureSegments = true,
    this.futureOutputSegmentCount = 1,
    this.onLog,
    this.verboseLogging = false,
    this.minPlaylistReloadDelay = const Duration(milliseconds: 30),
    this.maxPlaylistReloadDelay = const Duration(milliseconds: 180),
    this.dropBehindLiveEdge = true,
    this.startupEdgeSegmentCount = 1,
    this.startupRequirePrefetchedFirstSegment = false,
    this.startupSkipCurrentLatestSegment = false,
    this.startupPrefetchWaitTimeout = const Duration(milliseconds: 1400),
    this.startupFutureReadyWaitTimeout = const Duration(milliseconds: 140),
    this.idleKeepAliveDuration = const Duration(seconds: 3),
    this.startupMode = TwitchHlsStartupMode.streamlinkLiveEdge,
    this.timelineOrigin,
    this.isolateStartupTimeout = const Duration(seconds: 12),
  });

  Isolate? _isolate;
  ReceivePort? _eventPort;
  StreamSubscription<dynamic>? _eventSub;
  SendPort? _controlPort;

  int? port;
  String? _playlistUrl;
  String? _streamUrl;
  String? _streamTsUrl;
  TwitchHlsLiveStatus? _liveStatus;
  bool _running = false;
  bool _starting = false;

  bool get isRunning => _running && port != null && _streamUrl != null;

  String get playlistUrl {
    final value = _playlistUrl;
    if (value == null) throw StateError('Proxy has not started.');
    return value;
  }

  String get streamUrl {
    final value = _streamUrl;
    if (value == null) throw StateError('Proxy has not started.');
    return value;
  }

  String get streamTsUrl {
    final value = _streamTsUrl;
    if (value == null) throw StateError('Proxy has not started.');
    return value;
  }

  String liveReplayUrl({required Duration fromLive}) {
    final p = port;
    if (p == null) throw StateError('Proxy has not started.');
    final seconds = fromLive.inSeconds.clamp(1, 20).toInt();
    return 'http://127.0.0.1:$p/live-replay.ts?seconds=$seconds';
  }

  TwitchHlsLiveStatus? get liveStatus => _liveStatus;

  Future<void> start() async {
    if (_running) return;
    if (_starting) return;

    _starting = true;

    final started = Completer<void>();
    final eventPort = ReceivePort();
    _eventPort = eventPort;

    _eventSub = eventPort.listen((dynamic raw) {
      if (raw == null) {
        _running = false;
        if (!started.isCompleted) {
          started.completeError(
            StateError('Twitch HLS proxy isolate exited before start.'),
          );
        }
        return;
      }

      if (raw is List && raw.isNotEmpty) {
        _running = false;
        if (!started.isCompleted) {
          started.completeError(
            StateError('Twitch HLS proxy isolate error: $raw'),
          );
        }
        return;
      }

      if (raw is! Map) return;

      final type = raw['type']?.toString();

      if (type == 'started') {
        port = raw['port'] is int ? raw['port'] as int : null;
        _playlistUrl = raw['playlistUrl']?.toString();
        _streamUrl = raw['streamUrl']?.toString();
        _streamTsUrl = raw['streamTsUrl']?.toString();
        _controlPort = raw['controlPort'] is SendPort
            ? raw['controlPort'] as SendPort
            : null;
        _running = true;

        if (!started.isCompleted) {
          started.complete();
        }
      } else if (type == 'log') {
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
        _running = false;
        final message = raw['message']?.toString() ?? 'Unknown isolate error';
        if (!started.isCompleted) {
          started.completeError(StateError(message));
        } else {
          onLog?.call(message);
        }
      } else if (type == 'closed') {
        _running = false;
      }
    });

    final args = <String, Object?>{
      'replyPort': eventPort.sendPort,
      'upstreamPlaylistUrl': upstreamPlaylistUrl,
      'upstreamHeaders': upstreamHeaders,
      'edgeSegmentCount': edgeSegmentCount,
      'prefetchSegmentCount': prefetchSegmentCount,
      'outputFutureSegments': outputFutureSegments,
      'futureOutputSegmentCount': futureOutputSegmentCount,
      'verboseLogging': verboseLogging,
      'minPlaylistReloadDelayMs': minPlaylistReloadDelay.inMilliseconds,
      'maxPlaylistReloadDelayMs': maxPlaylistReloadDelay.inMilliseconds,
      'dropBehindLiveEdge': dropBehindLiveEdge,
      'startupEdgeSegmentCount': startupEdgeSegmentCount,
      'startupRequirePrefetchedFirstSegment':
          startupRequirePrefetchedFirstSegment,
      'startupSkipCurrentLatestSegment': startupSkipCurrentLatestSegment,
      'startupPrefetchWaitTimeoutMs': startupPrefetchWaitTimeout.inMilliseconds,
      'startupFutureReadyWaitTimeoutMs':
          startupFutureReadyWaitTimeout.inMilliseconds,
      'idleKeepAliveDurationMs': idleKeepAliveDuration.inMilliseconds,
      'startupMode': startupMode.name,
      'timelineOriginMs': timelineOrigin?.millisecondsSinceEpoch,
    };

    try {
      _isolate = await Isolate.spawn<Map<String, Object?>>(
        _twitchHlsProxyIsolateEntry,
        args,
        onExit: eventPort.sendPort,
        onError: eventPort.sendPort,
        errorsAreFatal: true,
      );

      await started.future.timeout(isolateStartupTimeout);
    } catch (_) {
      await close();
      rethrow;
    } finally {
      _starting = false;
    }
  }

  Future<void> waitUntilPrewarmed({
    Duration timeout = const Duration(milliseconds: 700),
  }) async {
    final control = _controlPort;
    if (!_running || control == null) return;

    final reply = ReceivePort();
    try {
      control.send(<String, Object?>{
        'type': 'waitReady',
        'timeoutMs': timeout.inMilliseconds,
        'replyPort': reply.sendPort,
      });

      await reply.first.timeout(timeout + const Duration(milliseconds: 80));
    } catch (_) {
      // Best effort only.
    } finally {
      reply.close();
    }
  }

  Future<TwitchHlsLiveStatus?> requestLiveStatus({
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

  Future<void> reconnectAtSegmentBoundary({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final control = _controlPort;
    if (!_running || control == null) return;

    final reply = ReceivePort();
    try {
      control.send(<String, Object?>{
        'type': 'reconnectAtSegmentBoundary',
        'timeoutMs': timeout.inMilliseconds,
        'replyPort': reply.sendPort,
      });
      await reply.first.timeout(timeout + const Duration(milliseconds: 120));
    } finally {
      reply.close();
    }
  }

  Future<void> close() async {
    _starting = false;

    final control = _controlPort;
    _controlPort = null;

    if (control != null) {
      final reply = ReceivePort();

      try {
        control.send(<String, Object?>{
          'type': 'close',
          'replyPort': reply.sendPort,
        });

        await reply.first.timeout(const Duration(seconds: 2));
      } catch (_) {
        // Force kill below.
      } finally {
        reply.close();
      }
    }

    _running = false;
    port = null;
    _playlistUrl = null;
    _streamUrl = null;
    _streamTsUrl = null;
    _liveStatus = null;

    final isolate = _isolate;
    _isolate = null;
    isolate?.kill(priority: Isolate.immediate);

    await _eventSub?.cancel().catchError((_) {});
    _eventSub = null;

    _eventPort?.close();
    _eventPort = null;
  }
}

Future<void> _twitchHlsProxyIsolateEntry(Map<String, Object?> args) async {
  final replyPort = args['replyPort'] as SendPort;
  final controlPort = ReceivePort();

  try {
    final startupModeName =
        args['startupMode']?.toString() ??
        TwitchHlsStartupMode.streamlinkLiveEdge.name;

    final startupMode = TwitchHlsStartupMode.values.firstWhere(
      (item) => item.name == startupModeName,
      orElse: () => TwitchHlsStartupMode.streamlinkLiveEdge,
    );

    DateTime? origin;
    final originMs = args['timelineOriginMs'];
    if (originMs is int) {
      origin = DateTime.fromMillisecondsSinceEpoch(originMs);
    }

    final headersRaw = args['upstreamHeaders'];
    final headers = <String, String>{};
    if (headersRaw is Map) {
      for (final entry in headersRaw.entries) {
        headers[entry.key.toString()] = entry.value.toString();
      }
    }

    final proxy = _TwitchDartHlsLowLatencyProxyCore(
      upstreamPlaylistUrl: args['upstreamPlaylistUrl']?.toString() ?? '',
      upstreamHeaders: headers,
      edgeSegmentCount: args['edgeSegmentCount'] as int? ?? 1,
      prefetchSegmentCount: args['prefetchSegmentCount'] as int? ?? 3,
      outputFutureSegments: args['outputFutureSegments'] as bool? ?? true,
      futureOutputSegmentCount: args['futureOutputSegmentCount'] as int? ?? 1,
      verboseLogging: args['verboseLogging'] as bool? ?? false,
      minPlaylistReloadDelay: Duration(
        milliseconds: args['minPlaylistReloadDelayMs'] as int? ?? 30,
      ),
      maxPlaylistReloadDelay: Duration(
        milliseconds: args['maxPlaylistReloadDelayMs'] as int? ?? 180,
      ),
      dropBehindLiveEdge: args['dropBehindLiveEdge'] as bool? ?? true,
      startupEdgeSegmentCount: args['startupEdgeSegmentCount'] as int? ?? 1,
      startupRequirePrefetchedFirstSegment:
          args['startupRequirePrefetchedFirstSegment'] as bool? ?? false,
      startupSkipCurrentLatestSegment:
          args['startupSkipCurrentLatestSegment'] as bool? ?? false,
      startupPrefetchWaitTimeout: Duration(
        milliseconds: args['startupPrefetchWaitTimeoutMs'] as int? ?? 1400,
      ),
      startupFutureReadyWaitTimeout: Duration(
        milliseconds: args['startupFutureReadyWaitTimeoutMs'] as int? ?? 140,
      ),
      idleKeepAliveDuration: Duration(
        milliseconds: args['idleKeepAliveDurationMs'] as int? ?? 3000,
      ),
      startupMode: startupMode,
      timelineOrigin: origin,
      onLog: (message) {
        replyPort.send(<String, Object?>{'type': 'log', 'message': message});
      },
    );

    await proxy.start();

    replyPort.send(<String, Object?>{
      'type': 'started',
      'port': proxy.port,
      'playlistUrl': proxy.playlistUrl,
      'streamUrl': proxy.streamUrl,
      'streamTsUrl': proxy.streamTsUrl,
      'controlPort': controlPort.sendPort,
    });

    await for (final raw in controlPort) {
      if (raw is! Map) continue;

      final type = raw['type']?.toString();
      final commandReply = raw['replyPort'] is SendPort
          ? raw['replyPort'] as SendPort
          : null;

      if (type == 'close') {
        await proxy.close();
        commandReply?.send(<String, Object?>{'type': 'closed'});
        replyPort.send(<String, Object?>{'type': 'closed'});
        break;
      }

      if (type == 'waitReady') {
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

      if (type == 'reconnectAtSegmentBoundary') {
        final timeoutMs = raw['timeoutMs'] as int? ?? 3000;
        await proxy.reconnectAtSegmentBoundary(
          timeout: Duration(milliseconds: timeoutMs),
        );
        commandReply?.send(<String, Object?>{
          'type': 'reconnectAtSegmentBoundary.done',
        });
      }
    }

    controlPort.close();
  } catch (e, stackTrace) {
    replyPort.send(<String, Object?>{
      'type': 'error',
      'message': e.toString(),
      'stackTrace': stackTrace.toString(),
    });

    controlPort.close();
  }
}
