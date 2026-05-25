// PATCH VERSION: twitch_hls_low_latency_proxy_streamlink_tuning_v43
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../models/playback/twitch_hls_proxy_models.dart';
import '../../parsers/playback/twitch_hls_playlist_parser.dart';

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

class _TwitchDartHlsLowLatencyProxyCore {
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

  _TwitchDartHlsLowLatencyProxyCore({
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
  });

  final HttpClient httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..idleTimeout = const Duration(seconds: 12)
    ..maxConnectionsPerHost = 32
    ..autoUncompress = false;

  final Expando<_TwitchHlsPrefetchRuntimeState> _prefetchRuntimeStates =
      Expando<_TwitchHlsPrefetchRuntimeState>(
        'twitch_hls_prefetch_runtime_state',
      );

  final LinkedHashMap<String, List<int>> _initMapBytesCache =
      LinkedHashMap<String, List<int>>();

  HttpServer? server;
  int? port;
  _TwitchHlsLowLatencyEngine? _prewarmEngine;

  bool get isRunning => server != null && port != null;

  String get playlistUrl {
    final p = port;
    if (p == null) throw StateError('Proxy has not started.');
    return 'http://127.0.0.1:$p/playlist.m3u8';
  }

  String get streamUrl {
    final p = port;
    if (p == null) throw StateError('Proxy has not started.');
    return 'http://127.0.0.1:$p/';
  }

  String get streamTsUrl {
    final p = port;
    if (p == null) throw StateError('Proxy has not started.');
    return 'http://127.0.0.1:$p/stream.ts';
  }

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server!.port;

    unawaited(_serve(server!));

    final engine = _TwitchHlsLowLatencyEngine(
      owner: this,
      playlistUrl: upstreamPlaylistUrl,
    );

    _prewarmEngine = engine;
    engine.startPrewarm();

    unawaited(
      engine.waitUntilReady(timeout: const Duration(milliseconds: 900)),
    );
  }

  Future<void> waitUntilPrewarmed({
    Duration timeout = const Duration(milliseconds: 700),
  }) async {
    final engine = _prewarmEngine;
    if (engine == null || engine.isStopped) return;
    await engine.waitUntilReady(timeout: timeout);
  }

  TwitchHlsLiveStatus liveStatus() {
    final engine = _prewarmEngine;
    if (engine == null || engine.isStopped) {
      return TwitchHlsLiveStatus.stopped();
    }
    return engine.liveStatus();
  }

  Future<void> close() async {
    final currentServer = server;
    final currentEngine = _prewarmEngine;

    _prewarmEngine = null;
    server = null;
    port = null;

    currentEngine?.stop();
    httpClient.close(force: true);
    await currentServer?.close(force: true);
  }

  void log(String message) {}

  void timeLog(
    String event, [
    Map<String, Object?> fields = const <String, Object?>{},
  ]) {}

  _TwitchHlsPrefetchRuntimeState _prefetchState(
    TwitchHlsSegmentPrefetchJob job,
  ) {
    final existing = _prefetchRuntimeStates[job];
    if (existing != null) return existing;

    final created = _TwitchHlsPrefetchRuntimeState();
    _prefetchRuntimeStates[job] = created;
    return created;
  }

  _TwitchHlsPrefetchRuntimeState? prefetchStateForJob(
    TwitchHlsSegmentPrefetchJob? job,
  ) {
    if (job == null) return null;
    return _prefetchRuntimeStates[job];
  }

  Future<void> _serve(HttpServer httpServer) async {
    await for (final request in httpServer) {
      unawaited(_handleRequest(request));
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;

      if (path == '/' || path == '/stream' || path == '/stream.ts') {
        await _handleStream(request, upstreamPlaylistUrl);
      } else if (path == '/playlist.m3u8') {
        await _handlePlaylist(request, upstreamPlaylistUrl);
      } else if (path == '/hls.m3u8') {
        final upstream = _readUrlQuery(request);
        if (upstream == null) {
          await _badRequest(request, 'Missing playlist url');
        } else {
          await _handlePlaylist(request, upstream);
        }
      } else if (path.startsWith('/segment')) {
        final upstream = _readUrlQuery(request);
        if (upstream == null) {
          await _badRequest(request, 'Missing segment url');
        } else {
          await _handleSegment(request, upstream);
        }
      } else if (path == '/health' || path == '/debug') {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.text;
        request.response.write(
          'ok\n'
          'playlist=$playlistUrl\n'
          'stream=$streamUrl\n'
          'stream_ts=$streamTsUrl\n'
          'upstream=$upstreamPlaylistUrl\n'
          'live_edge=$edgeSegmentCount\n'
          'startup_edge=$startupEdgeSegmentCount\n'
          'startup_require_prefetch=$startupRequirePrefetchedFirstSegment\n'
          'startup_skip_current_latest=$startupSkipCurrentLatestSegment\n'
          'startup_prefetch_timeout_ms=${startupPrefetchWaitTimeout.inMilliseconds}\n'
          'startup_future_ready_wait_ms=${startupFutureReadyWaitTimeout.inMilliseconds}\n'
          'startup_mode=${startupMode.name}\n'
          'prefetch=$prefetchSegmentCount\n'
          'prefetch_max=$_maxActivePrefetchJobs\n'
          'output_future_segments=$outputFutureSegments\n'
          'future_output_count=$futureOutputSegmentCount\n'
          'reload=${minPlaylistReloadDelay.inMilliseconds}-${maxPlaylistReloadDelay.inMilliseconds}ms\n'
          'dropBehindLiveEdge=$dropBehindLiveEdge\n'
          'idle_keep_alive_ms=${idleKeepAliveDuration.inMilliseconds}\n'
          'isolate=true\n',
        );
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not found: $path');
        await request.response.close();
      }
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.headers.contentType = ContentType.text;
        request.response.write(e.toString());
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleStream(HttpRequest request, String url) async {
    if (request.method == 'HEAD') {
      request.response.statusCode = HttpStatus.ok;
      _applyStreamlinkLikeHeaders(request.response);
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.ok;
    _applyStreamlinkLikeHeaders(request.response);
    request.response.bufferOutput = false;

    final engine = _takePrewarmedEngine(url);
    engine.startPrewarm();

    try {
      await engine.pipeClientToResponse(request.response);
    } catch (_) {
      try {
        await request.response.close();
      } catch (_) {}
    } finally {
      if (server != null && identical(_prewarmEngine, engine)) {
        engine.scheduleIdleStop();
      } else if (!identical(_prewarmEngine, engine)) {
        engine.stop();
      }
    }
  }

  _TwitchHlsLowLatencyEngine _takePrewarmedEngine(String url) {
    final engine = _prewarmEngine;

    if (engine != null && !engine.isStopped && engine.playlistUrl == url) {
      engine.cancelIdleStop();
      return engine;
    }

    engine?.stop();

    final fresh = _TwitchHlsLowLatencyEngine(owner: this, playlistUrl: url);

    _prewarmEngine = fresh;
    fresh.startPrewarm();

    return fresh;
  }

  void _applyStreamlinkLikeHeaders(HttpResponse response) {
    response.headers.set(HttpHeaders.serverHeader, 'Streamlink');
    response.headers.contentType = ContentType('video', 'mp2t');
    response.headers.chunkedTransferEncoding = true;
  }

  Future<void> _pipeEngineOutputToResponse({
    required HttpResponse response,
    required Stream<List<int>> stream,
  }) async {
    var flushedFirstChunk = false;
    var bytesSinceFlush = 0;
    var lastFlushAt = DateTime.now();

    await for (final chunk in stream) {
      response.add(chunk);
      bytesSinceFlush += chunk.length;

      final now = DateTime.now();
      final shouldFlush =
          !flushedFirstChunk ||
          bytesSinceFlush >= 16 * 1024 ||
          now.difference(lastFlushAt) >= const Duration(milliseconds: 15);

      if (shouldFlush) {
        await response.flush();
        flushedFirstChunk = true;
        bytesSinceFlush = 0;
        lastFlushAt = now;
      }
    }

    if (bytesSinceFlush > 0) {
      await response.flush();
    }
  }

  String? _readUrlQuery(HttpRequest request) {
    final raw = request.uri.queryParameters['u'];
    if (raw == null || raw.isEmpty) return null;
    return _decodeUrl(raw);
  }

  Future<void> _badRequest(HttpRequest request, String message) async {
    request.response.statusCode = HttpStatus.badRequest;
    request.response.headers.contentType = ContentType.text;
    request.response.write(message);
    await request.response.close();
  }

  Duration _strictReloadDelay(Duration targetDelay, Duration elapsed) {
    final remaining = targetDelay - elapsed;
    if (remaining <= minPlaylistReloadDelay) return minPlaylistReloadDelay;
    if (remaining >= maxPlaylistReloadDelay) return maxPlaylistReloadDelay;
    return remaining;
  }

  int get _maxActivePrefetchJobs {
    return math.max(prefetchSegmentCount + 2, 6);
  }

  Future<TwitchParsedMediaPlaylist> _loadMediaPlaylist(String url) async {
    final upstreamResponse = await _openSuccessfulUpstream(
      method: 'GET',
      url: url,
      range: null,
      retryLiveSegment: true,
      label: 'playlist',
    );

    final bytes = await _readAll(upstreamResponse);
    final playlistText = utf8.decode(bytes, allowMalformed: true);
    return _parseMediaPlaylist(playlistText, playlistUrl: url);
  }

  TwitchParsedMediaPlaylist _parseMediaPlaylist(
    String playlistText, {
    required String playlistUrl,
  }) {
    return TwitchHlsPlaylistParser.parse(
      playlistText,
      playlistUrl: playlistUrl,
    );
  }

  void _schedulePrefetches({
    required List<TwitchHlsSegmentItem> items,
    required Set<String> servedUrls,
    required LinkedHashMap<String, TwitchHlsSegmentPrefetchJob> prefetches,
  }) {
    if (prefetchSegmentCount <= 0) return;

    final maxPrefetchJobs = _maxActivePrefetchJobs;
    _trimPrefetchJobs(prefetches, maxPrefetchJobs);

    var added = 0;

    for (final item in items) {
      if (added >= prefetchSegmentCount) break;
      if (prefetches.length >= maxPrefetchJobs) break;
      if (servedUrls.contains(item.url) || prefetches.containsKey(item.url)) {
        continue;
      }

      final job = TwitchHlsSegmentPrefetchJob(item);
      final state = _prefetchState(job);
      state.requestStartedAt = DateTime.now();

      prefetches[item.url] = job;
      added++;

      unawaited(_runPrefetchJob(job));
    }

    _trimPrefetchJobs(prefetches, maxPrefetchJobs);
  }

  void _trimPrefetchJobs(
    LinkedHashMap<String, TwitchHlsSegmentPrefetchJob> prefetches,
    int maxPrefetchJobs,
  ) {
    while (prefetches.length > maxPrefetchJobs) {
      String? removeKey;

      for (final entry in prefetches.entries) {
        if (!entry.value.item.isPrefetch) {
          removeKey = entry.key;
          break;
        }
      }

      removeKey ??= prefetches.keys.first;

      final removed = prefetches.remove(removeKey);
      removed?.cancel();
    }
  }

  Future<void> _runPrefetchJob(TwitchHlsSegmentPrefetchJob job) async {
    if (job.cancelled) return;

    final state = _prefetchState(job);
    state.requestStartedAt ??= DateTime.now();

    try {
      final upstreamResponse = await _openSuccessfulUpstream(
        method: 'GET',
        url: job.item.url,
        range: null,
        retryLiveSegment: true,
        label: 'prefetch',
      );

      state.responseOpenedAt = DateTime.now();

      await for (final chunk in upstreamResponse) {
        if (job.cancelled) break;

        state.bytesReceived += chunk.length;
        state.firstChunkAt ??= DateTime.now();

        if (!job.controller.isClosed) {
          job.controller.add(chunk);
        }
      }

      if (!job.controller.isClosed) {
        await job.controller.close();
      }

      if (!job.completed.isCompleted) {
        job.completed.complete();
      }
    } catch (e, stackTrace) {
      if (job.cancelled) return;

      state.failed = true;
      job.error = e;
      job.stackTrace = stackTrace;

      if (!job.controller.isClosed) {
        job.controller.addError(e, stackTrace);
        await job.controller.close();
      }

      if (!job.completed.isCompleted) {
        job.completed.complete();
      }
    }
  }

  Future<void> _pipeSegmentToOutputBuffer({
    required TwitchHlsByteSink output,
    required TwitchHlsSegmentItem item,
    TwitchHlsSegmentPrefetchJob? prefetchJob,
  }) async {
    final job = prefetchJob;

    if (job != null) {
      try {
        await output.addStream(job.controller.stream);
        return;
      } catch (_) {}
    }

    final upstreamResponse = await _openSuccessfulUpstream(
      method: 'GET',
      url: item.url,
      range: null,
      retryLiveSegment: true,
      label: 'segment',
    );

    await output.addStream(upstreamResponse);
  }

  Future<HttpClientResponse> _openSuccessfulUpstream({
    required String method,
    required String url,
    String? range,
    bool retryLiveSegment = false,
    String label = '',
  }) async {
    final maxAttempts = retryLiveSegment ? 14 : 3;
    var delay = retryLiveSegment
        ? const Duration(milliseconds: 35)
        : const Duration(milliseconds: 100);
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final upstreamResponse = await _openRawUpstream(
          method: method,
          url: url,
          range: range,
        );

        final status = upstreamResponse.statusCode;
        if ((status >= 200 && status < 300) ||
            status == HttpStatus.partialContent) {
          return upstreamResponse;
        }

        await _discardUpstreamResponse(upstreamResponse);
        lastError = HttpException('Upstream HTTP $status for $label');

        if (!retryLiveSegment || attempt >= maxAttempts) {
          throw lastError;
        }
      } catch (e, stackTrace) {
        lastError = e;
        lastStackTrace = stackTrace;

        if (!retryLiveSegment || attempt >= maxAttempts) {
          Error.throwWithStackTrace(e, stackTrace);
        }
      }

      await Future<void>.delayed(delay);

      final nextMs = math
          .min(
            (delay.inMilliseconds * 1.45).round() + 20,
            retryLiveSegment ? 260 : 520,
          )
          .toInt();

      delay = Duration(milliseconds: nextMs);
    }

    Error.throwWithStackTrace(
      lastError ?? StateError('Unknown upstream error for $label'),
      lastStackTrace ?? StackTrace.current,
    );
  }

  Future<void> _discardUpstreamResponse(HttpClientResponse response) async {
    try {
      await for (final _ in response) {}
    } catch (_) {}
  }

  Future<HttpClientResponse> _openRawUpstream({
    required String method,
    required String url,
    String? range,
  }) async {
    final uri = Uri.parse(url);
    final upstreamRequest = await httpClient.openUrl(method, uri);
    upstreamRequest.followRedirects = true;
    upstreamRequest.maxRedirects = 5;

    for (final entry in upstreamHeaders.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();

      if (key.isEmpty || value.isEmpty) continue;
      if (key.toLowerCase() == HttpHeaders.hostHeader) continue;

      upstreamRequest.headers.set(key, value);
    }

    if (range != null && range.trim().isNotEmpty) {
      upstreamRequest.headers.set(HttpHeaders.rangeHeader, range.trim());
    }

    final lowerPath = uri.path.toLowerCase();
    if (lowerPath.endsWith('.m3u8') || lowerPath.contains('.m3u8')) {
      upstreamRequest.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      upstreamRequest.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
    }

    upstreamRequest.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    upstreamRequest.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

    return upstreamRequest.close();
  }

  Future<void> _handlePlaylist(HttpRequest request, String url) async {
    final upstreamResponse = await _openUpstream(
      method: 'GET',
      url: url,
      incomingRequest: request,
      forwardRange: false,
    );

    final bytes = await _readAll(upstreamResponse);
    final playlistText = utf8.decode(bytes, allowMalformed: true);
    final rewritten = _rewritePlaylistCompat(playlistText, playlistUrl: url);
    final rewrittenBytes = utf8.encode(rewritten);

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType(
      'application',
      'vnd.apple.mpegurl',
      charset: 'utf-8',
    );
    request.response.headers.set(
      HttpHeaders.cacheControlHeader,
      'no-store, no-cache, must-revalidate',
    );
    request.response.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
    request.response.headers.set(
      HttpHeaders.accessControlAllowOriginHeader,
      '*',
    );
    request.response.headers.contentLength = rewrittenBytes.length;

    if (request.method != 'HEAD') {
      request.response.add(rewrittenBytes);
    }

    await request.response.close();
  }

  Future<void> _handleSegment(HttpRequest request, String url) async {
    final upstreamResponse = await _openUpstream(
      method: request.method == 'HEAD' ? 'HEAD' : 'GET',
      url: url,
      incomingRequest: request,
      forwardRange: true,
    );

    request.response.statusCode = upstreamResponse.statusCode;

    _copySelectedResponseHeaders(
      upstreamResponse,
      request.response,
      fallbackUrl: url,
    );

    request.response.headers.set(
      HttpHeaders.accessControlAllowOriginHeader,
      '*',
    );

    if (request.method != 'HEAD') {
      await upstreamResponse.pipe(request.response);
    } else {
      await request.response.close();
    }
  }

  Future<HttpClientResponse> _openUpstream({
    required String method,
    required String url,
    required HttpRequest incomingRequest,
    required bool forwardRange,
  }) async {
    final uri = Uri.parse(url);
    final upstreamRequest = await httpClient.openUrl(method, uri);
    upstreamRequest.followRedirects = true;
    upstreamRequest.maxRedirects = 5;

    for (final entry in upstreamHeaders.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();

      if (key.isEmpty || value.isEmpty) continue;
      if (key.toLowerCase() == HttpHeaders.hostHeader) continue;

      upstreamRequest.headers.set(key, value);
    }

    final incomingUserAgent = incomingRequest.headers.value(
      HttpHeaders.userAgentHeader,
    );
    if (incomingUserAgent != null && incomingUserAgent.trim().isNotEmpty) {
      upstreamRequest.headers.set(
        HttpHeaders.userAgentHeader,
        incomingUserAgent.trim(),
      );
    }

    if (forwardRange) {
      final range = incomingRequest.headers.value(HttpHeaders.rangeHeader);
      if (range != null && range.trim().isNotEmpty) {
        upstreamRequest.headers.set(HttpHeaders.rangeHeader, range.trim());
      }
    }

    upstreamRequest.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    upstreamRequest.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

    return upstreamRequest.close();
  }

  Future<List<int>> _readAll(Stream<List<int>> stream) async {
    final bytes = BytesBuilder(copy: false);

    await for (final chunk in stream) {
      bytes.add(chunk);
    }

    return bytes.takeBytes();
  }

  Future<List<int>> _loadInitMapBytes(String url) async {
    final cached = _initMapBytesCache.remove(url);
    if (cached != null) {
      // Refresh LRU order.
      _initMapBytesCache[url] = cached;
      return cached;
    }

    final response = await _openSuccessfulUpstream(
      method: 'GET',
      url: url,
      range: null,
      retryLiveSegment: true,
      label: 'init map',
    );

    final bytes = List<int>.unmodifiable(await _readAll(response));
    _initMapBytesCache[url] = bytes;

    while (_initMapBytesCache.length > 8) {
      _initMapBytesCache.remove(_initMapBytesCache.keys.first);
    }

    return bytes;
  }

  void _copySelectedResponseHeaders(
    HttpClientResponse upstreamResponse,
    HttpResponse localResponse, {
    required String fallbackUrl,
  }) {
    final passthroughHeaders = <String>{
      HttpHeaders.contentLengthHeader,
      HttpHeaders.contentRangeHeader,
      HttpHeaders.acceptRangesHeader,
      HttpHeaders.lastModifiedHeader,
      HttpHeaders.etagHeader,
      HttpHeaders.cacheControlHeader,
    };

    upstreamResponse.headers.forEach((name, values) {
      final lower = name.toLowerCase();

      if (!passthroughHeaders.contains(lower)) return;
      if (values.isEmpty) return;

      localResponse.headers.set(name, values);
    });

    localResponse.headers.contentType = _guessSegmentContentType(
      upstreamResponse.headers.value(HttpHeaders.contentTypeHeader),
      fallbackUrl,
    );

    localResponse.headers.set(
      HttpHeaders.cacheControlHeader,
      'public, max-age=10',
    );
  }

  ContentType _guessSegmentContentType(
    String? upstreamContentType,
    String url,
  ) {
    final lowerType = (upstreamContentType ?? '').toLowerCase();

    if (lowerType.contains('mp2t')) return ContentType('video', 'mp2t');
    if (lowerType.contains('mp4')) return ContentType('video', 'mp4');

    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();

    if (path.endsWith('.ts')) return ContentType('video', 'mp2t');

    if (path.endsWith('.m4s') ||
        path.endsWith('.mp4') ||
        path.contains('.mp4')) {
      return ContentType('video', 'mp4');
    }

    if (path.endsWith('.aac')) return ContentType('audio', 'aac');

    return ContentType('video', 'mp4');
  }

  String _rewritePlaylistCompat(
    String playlistText, {
    required String playlistUrl,
  }) {
    final upstreamBase = Uri.parse(playlistUrl);
    final output = StringBuffer();

    var skipNextUriLineForLowLatencyTag = false;

    for (final rawLine in playlistText.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();

      if (line.isEmpty) {
        output.writeln();
        continue;
      }

      if (_isLowLatencyOnlyTag(line)) {
        skipNextUriLineForLowLatencyTag =
            line.startsWith('#EXT-X-TWITCH-PREFETCH') ||
            line.startsWith('#EXT-X-PREFETCH');
        continue;
      }

      if (skipNextUriLineForLowLatencyTag && !line.startsWith('#')) {
        skipNextUriLineForLowLatencyTag = false;
        continue;
      }

      skipNextUriLineForLowLatencyTag = false;

      if (line.startsWith('#')) {
        output.writeln(_rewriteTagUris(line, upstreamBase));
        continue;
      }

      final absoluteUrl = upstreamBase.resolve(line).toString();

      if (_looksLikePlaylistUrl(absoluteUrl)) {
        output.writeln(_proxyPlaylistUrl(absoluteUrl));
      } else {
        output.writeln(_proxySegmentUrl(absoluteUrl));
      }
    }

    return output.toString();
  }

  bool _isLowLatencyOnlyTag(String line) {
    return line.startsWith('#EXT-X-PART') ||
        line.startsWith('#EXT-X-PRELOAD-HINT') ||
        line.startsWith('#EXT-X-RENDITION-REPORT') ||
        line.startsWith('#EXT-X-SERVER-CONTROL') ||
        line.startsWith('#EXT-X-TWITCH-PREFETCH') ||
        line.startsWith('#EXT-X-PREFETCH');
  }

  String _rewriteTagUris(String line, Uri upstreamBase) {
    return line.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (match) {
      final rawUri = match.group(1) ?? '';
      if (rawUri.isEmpty) return match.group(0) ?? '';

      final absoluteUrl = upstreamBase.resolve(rawUri).toString();

      if (_looksLikePlaylistUrl(absoluteUrl)) {
        return 'URI="${_proxyPlaylistUrl(absoluteUrl)}"';
      }

      return 'URI="${_proxySegmentUrl(absoluteUrl)}"';
    });
  }

  bool _looksLikePlaylistUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final path = uri.path.toLowerCase();
    return path.endsWith('.m3u8') || path.contains('.m3u8/');
  }

  String _proxyPlaylistUrl(String absoluteUrl) {
    return 'http://127.0.0.1:$port/hls.m3u8?u=${_encodeUrl(absoluteUrl)}';
  }

  String _proxySegmentUrl(String absoluteUrl) {
    final path = Uri.tryParse(absoluteUrl)?.path.toLowerCase() ?? '';

    final ext = path.endsWith('.ts')
        ? 'ts'
        : path.endsWith('.aac')
        ? 'aac'
        : 'm4s';

    return 'http://127.0.0.1:$port/segment.$ext?u=${_encodeUrl(absoluteUrl)}';
  }

  String _encodeUrl(String value) {
    return Uri.encodeComponent(base64Url.encode(utf8.encode(value)));
  }

  String _decodeUrl(String value) {
    return utf8.decode(base64Url.decode(Uri.decodeComponent(value)));
  }
}

class _TwitchHlsLowLatencyEngine {
  final _TwitchDartHlsLowLatencyProxyCore owner;
  final String playlistUrl;

  _TwitchHlsLowLatencyEngine({required this.owner, required this.playlistUrl});

  final Set<int> _writtenSequences = <int>{};
  final Set<String> _writtenUrls = <String>{};

  final LinkedHashMap<String, TwitchHlsSegmentPrefetchJob> _prefetches =
      LinkedHashMap<String, TwitchHlsSegmentPrefetchJob>();

  final TwitchHlsLiveByteBus _liveBus = TwitchHlsLiveByteBus(
    // Keep a full current media segment available for late/reconnecting clients.
    // The byte value is treated as a soft limit; TwitchHlsLiveByteBus avoids
    // trimming inside the current segment unless an emergency hard limit is hit.
    maxReplayBytes: 4 * 1024 * 1024,
  );

  bool _stopped = false;
  bool _pollerStarted = false;
  int _activeClientCount = 0;

  final Completer<void> _firstSnapshotReady = Completer<void>();

  String? _lastPlaylistSignature;
  int _unchangedPlaylistReloadStreak = 0;

  int _latestPlayableSequence = -1;
  int _playlistVersion = 0;

  List<TwitchHlsSegmentItem> _lastNormalItems = const <TwitchHlsSegmentItem>[];
  List<TwitchHlsSegmentItem> _lastOutputCandidates =
      const <TwitchHlsSegmentItem>[];

  Completer<void>? _playlistUpdateWaiter;
  Timer? _idleStopTimer;
  _TwitchHlsPersistentWriter? _writer;

  bool get isStopped => _stopped;
  bool get hasFirstStartupSegment => _firstSnapshotReady.isCompleted;

  int get _maxOutputBacklogSegments {
    final futureAllowance = owner.outputFutureSegments
        ? math.max(owner.futureOutputSegmentCount, 0)
        : 0;

    return math.max(owner.edgeSegmentCount + futureAllowance, 1);
  }

  void startPrewarm() {
    if (_stopped) return;

    if (!_pollerStarted) {
      _pollerStarted = true;
      unawaited(_runPlaylistPoller());
    }

    _ensurePersistentWriterStarted();
  }

  void _ensurePersistentWriterStarted() {
    if (_stopped) return;

    final existing = _writer;
    if (existing != null && !existing.isStopped) return;

    final writer = _TwitchHlsPersistentWriter(engine: this, output: _liveBus);

    _writer = writer;
    unawaited(writer.start());
  }

  Future<void> waitUntilReady({required Duration timeout}) async {
    if (_firstSnapshotReady.isCompleted) return;

    try {
      await _firstSnapshotReady.future.timeout(timeout);
    } catch (_) {}
  }

  void cancelIdleStop() {
    _idleStopTimer?.cancel();
    _idleStopTimer = null;
  }

  void scheduleIdleStop() {
    if (_stopped) return;
    if (_activeClientCount > 0) return;

    _idleStopTimer?.cancel();
    _idleStopTimer = Timer(owner.idleKeepAliveDuration, () {
      if (_activeClientCount <= 0) {
        stop();
      }
    });
  }

  void stop() {
    if (_stopped) return;

    _stopped = true;

    _idleStopTimer?.cancel();
    _idleStopTimer = null;

    _writer?.stop();
    _writer = null;
    _liveBus.close();

    if (!_firstSnapshotReady.isCompleted) {
      _firstSnapshotReady.complete();
    }

    for (final job in _prefetches.values) {
      job.cancel();
    }

    _prefetches.clear();

    final waiter = _playlistUpdateWaiter;
    _playlistUpdateWaiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  Future<void> pipeClientToResponse(HttpResponse response) async {
    cancelIdleStop();
    startPrewarm();
    _ensurePersistentWriterStarted();

    _activeClientCount++;

    try {
      await owner._pipeEngineOutputToResponse(
        response: response,
        stream: _liveBus.createClientStream(includeReplay: true),
      );
    } catch (_) {
      // Silent by design.
    } finally {
      _activeClientCount = math.max(0, _activeClientCount - 1);

      try {
        await response.close();
      } catch (_) {}

      if (_activeClientCount <= 0) {
        scheduleIdleStop();
      }
    }
  }

  Future<void> _runPlaylistPoller() async {
    try {
      while (!_stopped && owner.server != null) {
        final loopStartedAt = DateTime.now();
        final media = await owner._loadMediaPlaylist(playlistUrl);
        final allItems = media.items;
        final playlistChanged = _updatePlaylistChangeState(allItems);

        if (allItems.isEmpty) {
          await _delayForNextPlaylist(
            media,
            loopStartedAt,
            playlistChanged: playlistChanged,
          );
          continue;
        }

        final normalItems = allItems.where((item) => !item.isPrefetch).toList();
        final futureItems = allItems.where((item) => item.isPrefetch).toList();

        if (normalItems.isEmpty) {
          await _delayForNextPlaylist(
            media,
            loopStartedAt,
            playlistChanged: playlistChanged,
          );
          continue;
        }

        final outputFutureItems = owner.outputFutureSegments
            ? futureItems
                  .take(math.max(owner.futureOutputSegmentCount, 0))
                  .toList()
            : const <TwitchHlsSegmentItem>[];

        final outputCandidates = _buildOutputCandidates(
          normalItems: normalItems,
          futureItems: outputFutureItems,
        );

        if (outputCandidates.isEmpty) {
          await _delayForNextPlaylist(
            media,
            loopStartedAt,
            playlistChanged: playlistChanged,
          );
          continue;
        }

        _lastNormalItems = normalItems;
        _lastOutputCandidates = outputCandidates;
        _latestPlayableSequence = outputCandidates.last.sequence;
        _playlistVersion++;

        final normalTailCount = math.min(2, owner.prefetchSegmentCount);
        final normalPrefetchStart = normalItems.length > normalTailCount
            ? normalItems.length - normalTailCount
            : 0;

        owner._schedulePrefetches(
          items: <TwitchHlsSegmentItem>[
            ...futureItems,
            ...normalItems.skip(normalPrefetchStart),
          ],
          servedUrls: _writtenUrls,
          prefetches: _prefetches,
        );

        if (!_firstSnapshotReady.isCompleted) {
          _firstSnapshotReady.complete();
        }

        _notifyPlaylistUpdated();
        _ensurePersistentWriterStarted();

        await _delayForNextPlaylist(
          media,
          loopStartedAt,
          playlistChanged: playlistChanged,
        );
      }
    } catch (_) {
      // Silent by design.
    } finally {
      stop();
    }
  }

  bool _updatePlaylistChangeState(List<TwitchHlsSegmentItem> items) {
    final signature = _playlistSignature(items);
    final changed = signature != _lastPlaylistSignature;

    if (changed) {
      _lastPlaylistSignature = signature;
      _unchangedPlaylistReloadStreak = 0;
    } else {
      _unchangedPlaylistReloadStreak = math.min(
        _unchangedPlaylistReloadStreak + 1,
        8,
      );
    }

    return changed;
  }

  String _playlistSignature(List<TwitchHlsSegmentItem> items) {
    if (items.isEmpty) return 'empty';

    final tail = items.length > 8 ? items.sublist(items.length - 8) : items;
    return tail
        .map(
          (item) => '${item.sequence}:${item.isPrefetch ? 1 : 0}:${item.url}',
        )
        .join('|');
  }

  Future<void> _delayForNextPlaylist(
    TwitchParsedMediaPlaylist media,
    DateTime loopStartedAt, {
    required bool playlistChanged,
  }) async {
    final elapsed = DateTime.now().difference(loopStartedAt);
    var wait = owner._strictReloadDelay(media.reloadDelay, elapsed);

    // Streamlink-style stability: if the playlist did not move, back off instead
    // of hammering the endpoint every 30ms. Twitch low-latency playlists are
    // still kept responsive by using a small cap when prefetch/future segments
    // exist, and a larger cap for normal-only playlists.
    if (!playlistChanged && _unchangedPlaylistReloadStreak > 0) {
      final hasFutureItems = media.items.any((item) => item.isPrefetch);
      final maxUnchangedDelayMs = hasFutureItems ? 240 : 520;
      final multiplier = math.min(
        1 << math.min(_unchangedPlaylistReloadStreak, 4),
        12,
      );
      final backedOffMs = math.min(
        wait.inMilliseconds * multiplier,
        maxUnchangedDelayMs,
      );
      wait = Duration(milliseconds: math.max(backedOffMs, wait.inMilliseconds));
    }

    await Future<void>.delayed(wait);
  }

  void _notifyPlaylistUpdated() {
    final waiter = _playlistUpdateWaiter;
    _playlistUpdateWaiter = null;

    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  Future<void> waitForPlaylistUpdate({
    Duration timeout = const Duration(milliseconds: 250),
  }) async {
    if (_stopped) return;

    final waiter = Completer<void>();
    _playlistUpdateWaiter = waiter;

    try {
      await waiter.future.timeout(timeout);
    } catch (_) {}
  }

  Future<void> waitForSnapshot({
    Duration timeout = const Duration(milliseconds: 900),
  }) async {
    if (_lastOutputCandidates.isNotEmpty && _lastNormalItems.isNotEmpty) {
      return;
    }

    try {
      await _firstSnapshotReady.future.timeout(timeout);
    } catch (_) {}
  }

  List<TwitchHlsSegmentItem> snapshotNormalItems() {
    return List<TwitchHlsSegmentItem>.of(_lastNormalItems);
  }

  List<TwitchHlsSegmentItem> snapshotOutputCandidates() {
    return List<TwitchHlsSegmentItem>.of(_lastOutputCandidates);
  }

  TwitchHlsSegmentPrefetchJob? takePrefetchJob(String url) {
    return _prefetches.remove(url);
  }

  TwitchHlsSegmentPrefetchJob? peekPrefetchJob(String url) {
    return _prefetches[url];
  }

  _TwitchHlsPrefetchRuntimeState? prefetchStateForItem(
    TwitchHlsSegmentItem item,
  ) {
    return owner.prefetchStateForJob(_prefetches[item.url]);
  }

  void markWritten(TwitchHlsSegmentItem item) {
    _writtenUrls.add(item.url);
    _writtenSequences.add(item.sequence);

    if (_writtenSequences.length > 320) {
      final minKeep = item.sequence - 180;
      _writtenSequences.removeWhere((value) => value < minKeep);
    }

    if (_lastNormalItems.isNotEmpty && _writtenUrls.length > 260) {
      final recentUrls = _lastNormalItems.map((item) => item.url).toSet();
      _writtenUrls.removeWhere((value) => !recentUrls.contains(value));
    }
  }

  void markSkipped(TwitchHlsSegmentItem item) {
    _writtenUrls.add(item.url);
    _writtenSequences.add(item.sequence);

    final removed = _prefetches.remove(item.url);
    removed?.cancel();
  }

  int latestPlayableSequence() {
    return _latestPlayableSequence;
  }

  int playlistVersion() {
    return _playlistVersion;
  }

  int maxOutputBacklogSegments() {
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
    required List<TwitchHlsSegmentItem> normalItems,
    required List<TwitchHlsSegmentItem> futureItems,
  }) {
    final output = <TwitchHlsSegmentItem>[];
    final seenUrls = <String>{};
    final seenSequences = <int>{};

    void addItem(TwitchHlsSegmentItem item) {
      final url = item.url.trim();

      if (url.isNotEmpty && !seenUrls.add(url)) return;

      final seq = item.sequence;
      if (!seenSequences.add(seq)) return;

      output.add(item);
    }

    for (final item in normalItems) {
      addItem(item);
    }

    for (final item in futureItems) {
      addItem(item);
    }

    output.sort((a, b) => a.sequence.compareTo(b.sequence));
    return output;
  }
}

class _TwitchHlsPersistentWriter {
  final _TwitchHlsLowLatencyEngine engine;
  final TwitchHlsByteSink output;

  bool _stopped = false;
  bool _started = false;

  int _lastWrittenSequence = -1;
  int? _startupInitialLatestSequence;
  String? _lastMapUrl;
  Duration _writtenOutputDuration = Duration.zero;
  Duration _lastWrittenDuration = Duration.zero;
  bool _lastWrittenWasPrefetch = false;
  DateTime? _lastWrittenAt;

  final Set<int> _sessionWrittenSequences = <int>{};
  final Set<String> _sessionWrittenUrls = <String>{};

  _TwitchHlsPersistentWriter({required this.engine, required this.output});

  bool get isStopped => _stopped;

  Future<void> start() async {
    if (_started || _stopped) return;
    _started = true;

    try {
      await engine.waitForSnapshot();

      final startup = await _selectStartupItem();
      if (startup == null) return;

      await _writeItem(startup);

      while (!_stopped && !engine.isStopped && engine.owner.server != null) {
        final next = _selectNextItem();

        if (next == null) {
          await engine.waitForPlaylistUpdate();
          continue;
        }

        await _writeItem(next);
      }
    } catch (_) {
      // Silent by design.
    } finally {
      stop();
    }
  }

  void stop() {
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

    final backoffMs = (segmentMs * 0.45).round().clamp(700, 1800).toInt();

    return Duration(milliseconds: backoffMs);
  }

  Future<TwitchHlsSegmentItem?> _selectStartupItem() async {
    final normalItems = engine.snapshotNormalItems();
    final outputCandidates = engine.snapshotOutputCandidates();

    if (normalItems.isEmpty || outputCandidates.isEmpty) return null;

    _startupInitialLatestSequence ??= normalItems.last.sequence;

    switch (engine.owner.startupMode) {
      case TwitchHlsStartupMode.latestNormalImmediate:
        return _latestNormalStartup(normalItems);

      case TwitchHlsStartupMode.nextNormalFresh:
        return _nextNormalFreshStartup();

      case TwitchHlsStartupMode.firstFutureIfAvailable:
        return _firstFutureStartup(normalItems, outputCandidates) ??
            _latestNormalStartup(normalItems);

      case TwitchHlsStartupMode.firstReadyFutureIfAvailable:
        return await _firstReadyFutureStartup(normalItems, outputCandidates) ??
            _latestNormalStartup(normalItems);

      case TwitchHlsStartupMode.stableFreshEdge:
        return _stableFreshEdgeStartup(
          initialNormalItems: normalItems,
          initialOutputCandidates: outputCandidates,
        );

      case TwitchHlsStartupMode.streamlinkLiveEdge:
        return _streamlinkLiveEdgeStartup();
    }
  }

  TwitchHlsSegmentItem? _latestNormalStartup(
    List<TwitchHlsSegmentItem> normalItems,
  ) {
    if (normalItems.isEmpty) return null;

    final startSequence = _edgeStartSequence(normalItems);

    final candidates = _candidatesFromPool(
      pool: normalItems,
      startSequence: startSequence,
    );

    if (candidates.isEmpty) return null;
    return candidates.last;
  }

  Future<TwitchHlsSegmentItem?> _nextNormalFreshStartup() async {
    final targetSequence = (_startupInitialLatestSequence ?? -1) + 1;
    final deadline = DateTime.now().add(const Duration(milliseconds: 900));

    while (!_stopped && DateTime.now().isBefore(deadline)) {
      final normalItems = engine.snapshotNormalItems();

      final candidates = _candidatesFromPool(
        pool: normalItems,
        startSequence: targetSequence,
      );

      if (candidates.isNotEmpty) {
        return candidates.first;
      }

      await engine.waitForPlaylistUpdate(
        timeout: const Duration(milliseconds: 120),
      );
    }

    final normalItems = engine.snapshotNormalItems();
    return _latestNormalStartup(normalItems);
  }

  TwitchHlsSegmentItem? _firstFutureStartup(
    List<TwitchHlsSegmentItem> normalItems,
    List<TwitchHlsSegmentItem> outputCandidates,
  ) {
    final futureCandidates = _futureStartupCandidates(
      normalItems: normalItems,
      outputCandidates: outputCandidates,
    );

    if (futureCandidates.isEmpty) return null;
    return futureCandidates.first;
  }

  Future<TwitchHlsSegmentItem?> _firstReadyFutureStartup(
    List<TwitchHlsSegmentItem> normalItems,
    List<TwitchHlsSegmentItem> outputCandidates,
  ) async {
    var candidates = _futureStartupCandidates(
      normalItems: normalItems,
      outputCandidates: outputCandidates,
    );

    if (candidates.isEmpty) return null;

    var hot = _findFutureWithPrefetchState(
      candidates: candidates,
      requireFirstChunk: true,
      allowResponseOpened: false,
    );

    if (hot != null) return hot;

    var opened = _findFutureWithPrefetchState(
      candidates: candidates,
      requireFirstChunk: false,
      allowResponseOpened: true,
    );

    final timeout = engine.owner.startupFutureReadyWaitTimeout;

    if (timeout > Duration.zero) {
      final deadline = DateTime.now().add(timeout);

      while (!_stopped && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));

        candidates = _futureStartupCandidates(
          normalItems: engine.snapshotNormalItems(),
          outputCandidates: engine.snapshotOutputCandidates(),
        );

        hot = _findFutureWithPrefetchState(
          candidates: candidates,
          requireFirstChunk: true,
          allowResponseOpened: false,
        );

        if (hot != null) return hot;

        opened ??= _findFutureWithPrefetchState(
          candidates: candidates,
          requireFirstChunk: false,
          allowResponseOpened: true,
        );
      }
    }

    opened ??= _findFutureWithPrefetchState(
      candidates: candidates,
      requireFirstChunk: false,
      allowResponseOpened: true,
    );

    return opened;
  }

  Future<TwitchHlsSegmentItem?> _stableFreshEdgeStartup({
    required List<TwitchHlsSegmentItem> initialNormalItems,
    required List<TwitchHlsSegmentItem> initialOutputCandidates,
  }) async {
    if (initialNormalItems.isEmpty || initialOutputCandidates.isEmpty) {
      return _latestNormalStartup(initialNormalItems);
    }

    final initialLatestNormalSequence = initialNormalItems.last.sequence;

    final maxWait = engine.owner.startupPrefetchWaitTimeout > Duration.zero
        ? engine.owner.startupPrefetchWaitTimeout
        : const Duration(milliseconds: 1200);

    final deadline = DateTime.now().add(maxWait);

    TwitchHlsSegmentItem? bestOpenedFuture;

    while (!_stopped &&
        !engine.isStopped &&
        DateTime.now().isBefore(deadline)) {
      final normalItems = engine.snapshotNormalItems();
      final outputCandidates = engine.snapshotOutputCandidates();

      if (normalItems.isNotEmpty && outputCandidates.isNotEmpty) {
        final futureCandidates = _futureStartupCandidates(
          normalItems: normalItems,
          outputCandidates: outputCandidates,
        );

        final hotFuture = _findFutureWithPrefetchState(
          candidates: futureCandidates,
          requireFirstChunk: true,
          allowResponseOpened: false,
        );

        if (hotFuture != null) {
          return hotFuture;
        }

        bestOpenedFuture ??= _findFutureWithPrefetchState(
          candidates: futureCandidates,
          requireFirstChunk: false,
          allowResponseOpened: true,
        );

        final freshNormalCandidates = _candidatesFromPool(
          pool: normalItems,
          startSequence: initialLatestNormalSequence + 1,
        );

        if (freshNormalCandidates.isNotEmpty) {
          return bestOpenedFuture ?? freshNormalCandidates.first;
        }
      }

      await engine.waitForPlaylistUpdate(
        timeout: const Duration(milliseconds: 80),
      );
    }

    final latestNormalItems = engine.snapshotNormalItems();
    final latestOutputCandidates = engine.snapshotOutputCandidates();

    if (latestNormalItems.isNotEmpty && latestOutputCandidates.isNotEmpty) {
      final futureCandidates = _futureStartupCandidates(
        normalItems: latestNormalItems,
        outputCandidates: latestOutputCandidates,
      );

      final hotFuture = _findFutureWithPrefetchState(
        candidates: futureCandidates,
        requireFirstChunk: true,
        allowResponseOpened: false,
      );

      if (hotFuture != null) return hotFuture;

      bestOpenedFuture ??= _findFutureWithPrefetchState(
        candidates: futureCandidates,
        requireFirstChunk: false,
        allowResponseOpened: true,
      );

      if (bestOpenedFuture != null) return bestOpenedFuture;

      final freshNormalCandidates = _candidatesFromPool(
        pool: latestNormalItems,
        startSequence: initialLatestNormalSequence + 1,
      );

      if (freshNormalCandidates.isNotEmpty) {
        return freshNormalCandidates.first;
      }

      return _latestNormalStartup(latestNormalItems);
    }

    return _latestNormalStartup(initialNormalItems);
  }

  Future<TwitchHlsSegmentItem?> _streamlinkLiveEdgeStartup() async {
    final maxWait = engine.owner.startupPrefetchWaitTimeout > Duration.zero
        ? engine.owner.startupPrefetchWaitTimeout
        : const Duration(milliseconds: 1400);

    final deadline = DateTime.now().add(maxWait);

    TwitchHlsSegmentItem? bestFallback;

    while (!_stopped &&
        !engine.isStopped &&
        DateTime.now().isBefore(deadline)) {
      final outputCandidates = engine.snapshotOutputCandidates();

      final selected = _streamlinkLiveEdgeCandidate(outputCandidates);

      if (selected != null) {
        if (selected.isPrefetch) {
          // Streamlink-like:
          // 選到 prefetch/future 就直接拿它，不要求 firstChunk。
          // 真正等待發生在 _writeItem() 裡的 active prefetch stream / direct GET。
          return selected;
        }

        bestFallback = selected;

        // 如果 live_edge > 1，選到 normal 是合理行為。
        // 如果 live_edge == 1 但目前還沒有 future，就多等一點看 future 會不會出現。
        if (!engine.owner.outputFutureSegments ||
            engine.owner.edgeSegmentCount > 1) {
          return selected;
        }
      }

      await engine.waitForPlaylistUpdate(
        timeout: const Duration(milliseconds: 80),
      );
    }

    return bestFallback ?? _latestNormalStartup(engine.snapshotNormalItems());
  }

  TwitchHlsSegmentItem? _streamlinkLiveEdgeCandidate(
    List<TwitchHlsSegmentItem> outputCandidates,
  ) {
    final pool =
        outputCandidates
            .where(
              (item) =>
                  !_sessionWrittenUrls.contains(item.url) &&
                  !_sessionWrittenSequences.contains(item.sequence) &&
                  item.sequence > _lastWrittenSequence,
            )
            .toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));

    if (pool.isEmpty) return null;

    final liveEdge = math.max(engine.owner.edgeSegmentCount, 1);
    final index = math.max(pool.length - liveEdge, 0);

    return pool[index];
  }

  List<TwitchHlsSegmentItem> _futureStartupCandidates({
    required List<TwitchHlsSegmentItem> normalItems,
    required List<TwitchHlsSegmentItem> outputCandidates,
  }) {
    if (normalItems.isEmpty) return const <TwitchHlsSegmentItem>[];

    final latestNormalSequence = normalItems.last.sequence;

    final futurePool = outputCandidates
        .where((item) => item.sequence > latestNormalSequence)
        .toList();

    return _candidatesFromPool(
      pool: futurePool,
      startSequence: latestNormalSequence + 1,
    );
  }

  TwitchHlsSegmentItem? _findFutureWithPrefetchState({
    required List<TwitchHlsSegmentItem> candidates,
    required bool requireFirstChunk,
    required bool allowResponseOpened,
  }) {
    for (final item in candidates) {
      final state = engine.prefetchStateForItem(item);
      final job = engine.peekPrefetchJob(item.url);

      if (job == null || job.cancelled) continue;
      if (state == null || state.failed) continue;

      if (requireFirstChunk) {
        if (state.hasFirstChunk) return item;
        continue;
      }

      if (allowResponseOpened && state.responseOpened) {
        return item;
      }
    }

    return null;
  }

  TwitchHlsSegmentItem? _selectNextItem() {
    final outputCandidates = engine.snapshotOutputCandidates();
    if (outputCandidates.isEmpty) return null;

    final latestPlayable = engine.latestPlayableSequence();
    final maxBacklog = engine.maxOutputBacklogSegments();
    final minSequenceToKeep = latestPlayable - maxBacklog + 1;

    final candidates = outputCandidates.where((item) {
      if (_sessionWrittenUrls.contains(item.url)) return false;
      if (_sessionWrittenSequences.contains(item.sequence)) return false;
      if (item.sequence <= _lastWrittenSequence) return false;

      if (engine.owner.dropBehindLiveEdge &&
          item.sequence < minSequenceToKeep) {
        engine.markSkipped(item);
        return false;
      }

      return true;
    }).toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => a.sequence.compareTo(b.sequence));

    if (engine.owner.dropBehindLiveEdge && _lastWrittenSequence >= 0) {
      final lagSegments = latestPlayable - _lastWrittenSequence;
      if (lagSegments > maxBacklog + 1) {
        final liveEdge = math.max(engine.owner.edgeSegmentCount, 1);
        final catchupStartSequence = latestPlayable - liveEdge + 1;

        final catchupCandidates = candidates
            .where((item) => item.sequence >= catchupStartSequence)
            .toList();

        if (catchupCandidates.isNotEmpty) {
          for (final item in candidates) {
            if (item.sequence < catchupStartSequence) {
              engine.markSkipped(item);
            }
          }

          catchupCandidates.sort((a, b) => a.sequence.compareTo(b.sequence));
          return catchupCandidates.first;
        }
      }
    }

    return candidates.first;
  }

  int _edgeStartSequence(List<TwitchHlsSegmentItem> pool) {
    final safeStartupEdgeSegmentCount = math
        .max(
          engine.owner.startupEdgeSegmentCount,
          engine.owner.edgeSegmentCount,
        )
        .clamp(1, pool.length)
        .toInt();

    final startAt = pool.length > safeStartupEdgeSegmentCount
        ? pool.length - safeStartupEdgeSegmentCount
        : 0;

    return pool[startAt].sequence;
  }

  List<TwitchHlsSegmentItem> _candidatesFromPool({
    required List<TwitchHlsSegmentItem> pool,
    required int startSequence,
  }) {
    return pool
        .where(
          (item) =>
              item.sequence >= startSequence &&
              !_sessionWrittenUrls.contains(item.url) &&
              !_sessionWrittenSequences.contains(item.sequence) &&
              item.sequence > _lastWrittenSequence,
        )
        .toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
  }

  Future<void> _writeItem(TwitchHlsSegmentItem item) async {
    if (_stopped) return;

    if (engine.owner.dropBehindLiveEdge) {
      final latestPlayable = engine.latestPlayableSequence();
      final maxBacklog = engine.maxOutputBacklogSegments();
      final minSequenceToKeep = latestPlayable - maxBacklog + 1;

      if (item.sequence < minSequenceToKeep) {
        engine.markSkipped(item);
        return;
      }
    }

    final liveOutput = output;
    if (liveOutput is TwitchHlsLiveByteBus) {
      // Keep replay aligned to a media-segment boundary.
      // If media_kit reconnects while the writer is already running, it gets
      // the current segment from its beginning instead of arbitrary old bytes.
      liveOutput.beginSegment();
    }

    if (item.mapUrl != null && item.mapUrl != _lastMapUrl) {
      _lastMapUrl = item.mapUrl;

      final mapBytes = await engine.owner._loadInitMapBytes(item.mapUrl!);
      await output.addStream(Stream<List<int>>.value(mapBytes));
    }

    final prefetchJob = engine.takePrefetchJob(item.url);

    await engine.owner._pipeSegmentToOutputBuffer(
      output: output,
      item: item,
      prefetchJob: prefetchJob,
    );

    _sessionWrittenUrls.add(item.url);
    _sessionWrittenSequences.add(item.sequence);

    if (item.sequence > _lastWrittenSequence) {
      _lastWrittenSequence = item.sequence;
    }

    engine.markWritten(item);

    _writtenOutputDuration += item.duration;
    _lastWrittenDuration = item.duration;
    _lastWrittenWasPrefetch = item.isPrefetch;
    _lastWrittenAt = DateTime.now();
  }
}

abstract class TwitchHlsByteSink {
  int get bufferedBytes;

  Future<void> addStream(Stream<List<int>> stream);

  void close();
}

class TwitchHlsLiveByteBus implements TwitchHlsByteSink {
  final int maxReplayBytes;

  TwitchHlsLiveByteBus({required this.maxReplayBytes});

  final ListQueue<List<int>> _replayChunks = ListQueue<List<int>>();
  final Set<StreamController<List<int>>> _clients =
      <StreamController<List<int>>>{};

  bool _closed = false;
  int _bufferedBytes = 0;

  @override
  int get bufferedBytes => _bufferedBytes;

  Stream<List<int>> createClientStream({bool includeReplay = true}) {
    late final StreamController<List<int>> controller;

    controller = StreamController<List<int>>(
      sync: true,
      onListen: () {
        if (_closed) {
          controller.close();
          return;
        }

        _clients.add(controller);

        if (includeReplay) {
          for (final chunk in _replayChunks) {
            if (controller.isClosed) break;
            controller.add(chunk);
          }
        }
      },
      onCancel: () {
        _clients.remove(controller);
      },
    );

    return controller.stream;
  }

  void beginSegment() {
    if (_closed) return;
    _replayChunks.clear();
    _bufferedBytes = 0;
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      if (_closed) return;
      _add(chunk);
    }
  }

  void _add(List<int> chunk) {
    if (_closed || chunk.isEmpty) return;

    final safeChunk = List<int>.of(chunk, growable: false);
    _replayChunks.addLast(safeChunk);
    _bufferedBytes += safeChunk.length;

    // Soft segment-aware replay:
    // beginSegment() clears the replay queue at media-segment boundaries, so all
    // chunks here belong to the current segment. Avoid trimming inside the
    // current segment; otherwise a late client can start from a partial H264/TS
    // packet and spam PPS/no-frame decoder warnings before the next keyframe.
    // Keep only an emergency cap for pathological segments.
    final emergencyLimit = math.max(maxReplayBytes * 4, 16 * 1024 * 1024);
    while (_bufferedBytes > emergencyLimit && _replayChunks.length > 1) {
      final removed = _replayChunks.removeFirst();
      _bufferedBytes -= removed.length;
    }

    final disconnected = <StreamController<List<int>>>[];

    for (final client in _clients) {
      if (client.isClosed) {
        disconnected.add(client);
        continue;
      }

      try {
        client.add(safeChunk);
      } catch (_) {
        disconnected.add(client);
      }
    }

    for (final client in disconnected) {
      _clients.remove(client);
    }
  }

  @override
  void close() {
    if (_closed) return;

    _closed = true;

    for (final client in List<StreamController<List<int>>>.of(_clients)) {
      try {
        client.close();
      } catch (_) {}
    }

    _clients.clear();
    _replayChunks.clear();
    _bufferedBytes = 0;
  }
}

class TwitchHlsOutputBuffer implements TwitchHlsByteSink {
  final int maxBufferedBytes;

  TwitchHlsOutputBuffer({required this.maxBufferedBytes});

  final StreamController<List<int>> _controller = StreamController<List<int>>(
    sync: true,
  );

  bool _closed = false;
  int _bufferedBytes = 0;

  Stream<List<int>> get stream => _controller.stream;
  @override
  int get bufferedBytes => _bufferedBytes;

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      if (_closed) return;

      _bufferedBytes += chunk.length;
      _controller.add(chunk);

      if (_bufferedBytes > maxBufferedBytes) {
        _bufferedBytes = maxBufferedBytes;
      }
    }

    _bufferedBytes = 0;
  }

  @override
  void close() {
    if (_closed) return;

    _closed = true;
    _controller.close();
  }
}
