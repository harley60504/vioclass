import 'dart:async';
import 'dart:io';

import '../../models/playback/twitch_hls_proxy_models.dart';
import 'twitch_hls_low_latency_proxy.dart';
import 'twitch_sequential_live_replay_proxy.dart';

/// Stable local URL wrapper for Twitch HLS playback.
///
/// The outer URL and port stay stable. Quality/channel switching swaps the
/// inner low-latency proxy. For `/stream.ts`, this router keeps the client HTTP
/// response open and re-attaches it to the new inner stream after the inner
/// upstream changes, so media_kit does not need Player.open() on every switch.
class TwitchStableHlsProxyRouter {
  final Map<String, String> upstreamHeaders;
  final int edgeSegmentCount;
  final int prefetchSegmentCount;
  final bool outputFutureSegments;
  final int futureOutputSegmentCount;
  final bool dropBehindLiveEdge;
  final int startupEdgeSegmentCount;
  final bool startupRequirePrefetchedFirstSegment;
  final bool startupSkipCurrentLatestSegment;
  final TwitchHlsStartupMode startupMode;
  final bool verboseLogging;

  TwitchStableHlsProxyRouter({
    required this.upstreamHeaders,
    this.edgeSegmentCount = 1,
    this.prefetchSegmentCount = 1,
    this.outputFutureSegments = true,
    this.futureOutputSegmentCount = 1,
    this.dropBehindLiveEdge = true,
    this.startupEdgeSegmentCount = 1,
    this.startupRequirePrefetchedFirstSegment = false,
    this.startupSkipCurrentLatestSegment = false,
    this.startupMode = TwitchHlsStartupMode.streamlinkLiveEdge,
    this.verboseLogging = false,
  });

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4)
    ..idleTimeout = const Duration(seconds: 8)
    ..autoUncompress = false;

  HttpServer? _server;
  TwitchDartHlsLowLatencyProxy? _inner;
  TwitchSequentialLiveReplayProxy? _replayProxy;
  String? _upstreamPlaylistUrl;
  Uri? _directStreamUri;
  bool _starting = false;
  bool _switching = false;
  int _switchGeneration = 0;
  int _sourceChangeGeneration = 0;
  int _directStreamGeneration = 0;
  int _streamClientGeneration = 0;
  StreamIterator<List<int>>? _activeUpstreamIterator;

  int _streamRequests = 0;
  int _streamHeadRequests = 0;
  int _streamAttachments = 0;
  int _streamReceivedBytes = 0;
  int _streamFlushedBytes = 0;
  int _streamUpstreamStatus = 0;
  int _streamPumpFailures = 0;
  bool _streamFlushPending = false;
  final List<int> _streamHeaderPrefix = <int>[];

  /// Counts for the newest native HTTP reader, not proof of native decoding.
  /// Only fixed header classifications are exposed; never URLs or media bytes.
  Map<String, Object> get streamReadDiagnostics {
    bool boxIs(String name) {
      if (_streamHeaderPrefix.length < 8) return false;
      for (var index = 0; index < 4; index++) {
        if (_streamHeaderPrefix[index + 4] != name.codeUnitAt(index)) {
          return false;
        }
      }
      return true;
    }

    return {
      'requests': _streamRequests,
      'headRequests': _streamHeadRequests,
      'attachments': _streamAttachments,
      'receivedBytes': _streamReceivedBytes,
      'flushedBytes': _streamFlushedBytes,
      'upstreamStatus': _streamUpstreamStatus,
      'pumpFailures': _streamPumpFailures,
      'flushPending': _streamFlushPending,
      'headerBytes': _streamHeaderPrefix.length,
      'startsWithTsSync':
          _streamHeaderPrefix.isNotEmpty && _streamHeaderPrefix.first == 0x47,
      'startsWithMp4Init': boxIs('ftyp') || boxIs('moov'),
      'startsWithMp4Fragment': boxIs('moof') || boxIs('styp'),
    };
  }

  int? get port => _server?.port;

  bool get isRunning => _server != null;

  bool get hasInnerProxy => _inner != null && (_inner?.isRunning ?? false);

  String? get upstreamPlaylistUrl => _upstreamPlaylistUrl;

  String get playlistUrl {
    final p = port;
    if (p == null) throw StateError('Stable HLS proxy router has not started.');
    return 'http://127.0.0.1:$p/playlist.m3u8';
  }

  String get streamUrl {
    final p = port;
    if (p == null) throw StateError('Stable HLS proxy router has not started.');
    return 'http://127.0.0.1:$p/';
  }

  String get streamTsUrl {
    final p = port;
    if (p == null) throw StateError('Stable HLS proxy router has not started.');
    return 'http://127.0.0.1:$p/stream.ts';
  }

  String liveReplayUrl({required Duration fromLive}) {
    final replay = _replayProxy;
    if (replay == null || !replay.isRunning) {
      throw StateError('Sequential replay proxy not ready');
    }
    return replay.streamUrl(fromLive: fromLive);
  }

  Future<void> startDirectStream({required String streamUrl}) async {
    if (_starting) return;
    _starting = true;
    try {
      if (_server == null) {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        _server = server;
        unawaited(_serve(server));
      }
      await switchDirectStream(streamUrl);
    } finally {
      _starting = false;
    }
  }

  Future<void> start({required String upstreamPlaylistUrl}) async {
    if (_starting) return;
    _starting = true;
    try {
      if (_server == null) {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        _server = server;
        unawaited(_serve(server));
      }
      await switchUpstream(upstreamPlaylistUrl);
    } finally {
      _starting = false;
    }
  }

  Future<void> switchUpstream(
    String upstreamPlaylistUrl, {
    bool forceReconnect = false,
  }) async {
    final safeUrl = upstreamPlaylistUrl.trim();
    if (safeUrl.isEmpty) {
      throw ArgumentError.value(
        upstreamPlaylistUrl,
        'upstreamPlaylistUrl',
        'cannot be empty',
      );
    }

    final sourceChangeGeneration = ++_sourceChangeGeneration;
    bool isCurrentChange() =>
        _server != null && sourceChangeGeneration == _sourceChangeGeneration;

    if (_inner != null &&
        _inner!.isRunning &&
        _replayProxy != null &&
        _replayProxy!.isRunning &&
        _directStreamUri == null &&
        _upstreamPlaylistUrl == safeUrl) {
      if (forceReconnect) {
        _switching = true;
        try {
          await _inner!.reconnectAtSegmentBoundary();
          if (isCurrentChange()) _switchGeneration++;
        } finally {
          if (isCurrentChange()) {
            _switching = false;
            _switchGeneration++;
          }
        }
      } else if (_switching) {
        _switching = false;
        _switchGeneration++;
      }
      return;
    }

    _switching = true;
    final previous = _inner;
    final previousReplay = _replayProxy;
    final previousDirectStreamUri = _directStreamUri;
    final previousUpstreamPlaylistUrl = _upstreamPlaylistUrl;
    TwitchDartHlsLowLatencyProxy? next;
    TwitchSequentialLiveReplayProxy? nextReplay;
    _directStreamUri = null;
    _switchGeneration++;

    try {
      next = TwitchDartHlsLowLatencyProxy(
        upstreamPlaylistUrl: safeUrl,
        upstreamHeaders: upstreamHeaders,
        edgeSegmentCount: edgeSegmentCount,
        prefetchSegmentCount: prefetchSegmentCount,
        outputFutureSegments: outputFutureSegments,
        futureOutputSegmentCount: futureOutputSegmentCount,
        dropBehindLiveEdge: dropBehindLiveEdge,
        startupEdgeSegmentCount: startupEdgeSegmentCount,
        startupRequirePrefetchedFirstSegment:
            startupRequirePrefetchedFirstSegment,
        startupSkipCurrentLatestSegment: startupSkipCurrentLatestSegment,
        startupMode: startupMode,
        verboseLogging: verboseLogging,
      );
      nextReplay = TwitchSequentialLiveReplayProxy(
        upstreamPlaylistUrl: safeUrl,
        upstreamHeaders: upstreamHeaders,
      );

      await next.start();
      if (!isCurrentChange()) {
        await next.close();
        await nextReplay.close();
        return;
      }
      await next.waitUntilPrewarmed();
      if (!isCurrentChange()) {
        await next.close();
        await nextReplay.close();
        return;
      }
      // Best-effort prewarming can time out while the playlist is still being
      // retried. Do not commit an uninitialized engine and close a usable
      // previous source merely because its local HTTP server has started.
      final playlistDeadline = DateTime.now().add(const Duration(seconds: 8));
      TwitchHlsLiveStatus? candidateStatus;
      while (true) {
        candidateStatus = await next.requestLiveStatus();
        if (!isCurrentChange()) {
          await next.close();
          await nextReplay.close();
          return;
        }
        if (candidateStatus != null &&
            (!candidateStatus.running || candidateStatus.playlistVersion > 0)) {
          break;
        }
        if (DateTime.now().isAfter(playlistDeadline)) {
          throw TimeoutException('Replacement HLS playlist not ready.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      // An open isolate/server alone is not a viable playback source. A
      // terminal playlist failure can stop its engine during prewarming.
      if (!candidateStatus.running) {
        throw StateError('Replacement HLS engine stopped before handoff.');
      }
      await nextReplay.start();
      if (!isCurrentChange()) {
        await next.close();
        await nextReplay.close();
        return;
      }

      _inner = next;
      _replayProxy = nextReplay;
      _upstreamPlaylistUrl = safeUrl;
      _switchGeneration++;

      await _interruptActiveUpstream();
      await previous?.close();
      await previousReplay?.close();
    } catch (_) {
      if (!identical(next, previous)) await next?.close();
      if (!identical(nextReplay, previousReplay)) await nextReplay?.close();
      if (isCurrentChange()) {
        _inner = previous;
        _replayProxy = previousReplay;
        _directStreamUri = previousDirectStreamUri;
        _upstreamPlaylistUrl = previousUpstreamPlaylistUrl;
        _switchGeneration++;
        rethrow;
      }
    } finally {
      if (isCurrentChange()) {
        _switching = false;
        _switchGeneration++;
      }
    }
  }

  Future<void> switchDirectStream(String streamUrl) async {
    final safeUrl = streamUrl.trim();
    final directUri = Uri.tryParse(safeUrl);
    if (directUri == null || safeUrl.isEmpty) {
      throw ArgumentError.value(streamUrl, 'streamUrl', 'cannot be empty');
    }

    final sourceChangeGeneration = ++_sourceChangeGeneration;
    if (_directStreamUri == directUri && _server != null) {
      return;
    }

    _switching = true;
    final previous = _inner;
    final previousReplay = _replayProxy;
    _inner = null;
    _replayProxy = null;
    _directStreamUri = directUri;
    _upstreamPlaylistUrl = null;
    _directStreamGeneration++;
    _switchGeneration++;

    try {
      await _interruptActiveUpstream();
      await previous?.close();
      await previousReplay?.close();
    } finally {
      if (sourceChangeGeneration == _sourceChangeGeneration &&
          _server != null) {
        _switching = false;
        _switchGeneration++;
      }
    }
  }

  Future<void> switchLiveReplayStream({
    required Duration canonicalTarget,
  }) async {
    final inner = _inner;
    final replay = _replayProxy;
    if (inner == null ||
        !inner.isRunning ||
        replay == null ||
        !replay.isRunning) {
      throw StateError('Live replay source not ready');
    }
    final replayUri = Uri.parse(
      replay.streamUrlForCanonicalTarget(canonicalTarget: canonicalTarget),
    );
    final sourceChangeGeneration = ++_sourceChangeGeneration;
    _switching = true;
    _directStreamUri = replayUri;
    _directStreamGeneration++;
    _switchGeneration++;
    await _interruptActiveUpstream();
    if (sourceChangeGeneration == _sourceChangeGeneration && _server != null) {
      _switching = false;
      _switchGeneration++;
    }
  }

  /// Stops the currently attached stable stream without tearing down the warm
  /// low-latency/live-replay proxies. Used when playback moves to the separate
  /// DVR TS bridge so a stale near-live pump cannot keep consuming bandwidth.
  Future<void> interruptPlaybackStream() async {
    _sourceChangeGeneration++;
    // This operation supersedes a pending source load; its stale finally must
    // not own the switching flag once the separate DVR bridge takes over.
    _switching = false;
    _streamClientGeneration++;
    _directStreamUri = null;
    _directStreamGeneration++;
    _switchGeneration++;
    await _interruptActiveUpstream();
  }

  Future<void> waitUntilPrewarmed({
    Duration timeout = const Duration(milliseconds: 700),
  }) async {
    await _inner?.waitUntilPrewarmed(timeout: timeout);
  }

  Future<TwitchHlsLiveStatus?> requestLiveStatus({
    Duration timeout = const Duration(milliseconds: 280),
  }) async {
    return _inner?.requestLiveStatus(timeout: timeout);
  }

  Future<void> close() async {
    _sourceChangeGeneration++;
    final server = _server;
    _server = null;
    _switchGeneration++;

    final inner = _inner;
    final replay = _replayProxy;
    _inner = null;
    _replayProxy = null;
    _upstreamPlaylistUrl = null;
    _directStreamUri = null;
    _directStreamGeneration++;
    await _interruptActiveUpstream();

    await inner?.close();
    await replay?.close();
    await server?.close(force: true);
    _client.close(force: true);
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handleRequest(request));
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;

      if (path == '/health' || path == '/debug') {
        await _handleHealth(request);
        return;
      }

      final inner = _inner;
      if ((inner == null || !inner.isRunning) && _directStreamUri == null) {
        request.response.statusCode = _switching
            ? HttpStatus.serviceUnavailable
            : HttpStatus.badGateway;
        request.response.headers.contentType = ContentType.text;
        request.response.write(
          _switching ? 'Switching upstream' : 'Inner proxy not ready',
        );
        await request.response.close();
        return;
      }

      if (path == '/' || path == '/stream' || path == '/stream.ts') {
        await _proxyStreamLoop(request);
        return;
      }

      if (path == '/live-replay.ts') {
        final replay = _replayProxy;
        if (replay == null || !replay.isRunning) {
          request.response.statusCode = HttpStatus.badGateway;
          request.response.write('Sequential replay proxy not ready');
          await request.response.close();
          return;
        }
        await _proxyToInner(
          request,
          Uri.parse(replay.streamUrl(fromLive: _readReplayDuration(request))),
        );
        return;
      }

      if (path == '/playlist.m3u8') {
        if (inner == null || !inner.isRunning) {
          request.response.statusCode = HttpStatus.badGateway;
          request.response.write('Inner proxy not ready');
          await request.response.close();
          return;
        }
        await _proxyToInner(request, Uri.parse(inner.playlistUrl));
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not found: $path');
      await request.response.close();
    } catch (error) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.headers.contentType = ContentType.text;
        request.response.write(error.toString());
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleHealth(HttpRequest request) async {
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.text;
    request.response.write(
      'ok\n'
      'stable_port=$port\n'
      'playlist=$playlistUrl\n'
      'stream=$streamUrl\n'
      'stream_ts=$streamTsUrl\n'
      'upstream=$_upstreamPlaylistUrl\n'
      'direct=$_directStreamUri\n'
      'inner_running=${_inner?.isRunning ?? false}\n'
      'replay_running=${_replayProxy?.isRunning ?? false}\n'
      'inner_stream=${_inner?.streamTsUrl}\n'
      'switching=$_switching\n'
      'switch_generation=$_switchGeneration\n',
    );
    await request.response.close();
  }

  Future<void> _proxyStreamLoop(HttpRequest request) async {
    if (request.method == 'HEAD') {
      _streamHeadRequests++;
      request.response.statusCode = HttpStatus.ok;
      _applyStreamHeaders(request.response);
      await request.response.close();
      return;
    }

    // media_kit may open the same stable stream URL again before Windows has
    // reported the previous socket as closed. Keep only the newest stream pump
    // so stale local clients cannot multiply loopback traffic indefinitely.
    final streamClientGeneration = ++_streamClientGeneration;
    _streamRequests++;
    _streamAttachments = 0;
    _streamReceivedBytes = 0;
    _streamFlushedBytes = 0;
    _streamUpstreamStatus = 0;
    _streamPumpFailures = 0;
    _streamFlushPending = false;
    _streamHeaderPrefix.clear();
    await _interruptActiveUpstream();

    final response = request.response;
    response.statusCode = HttpStatus.ok;
    _applyStreamHeaders(response);
    response.bufferOutput = false;

    var lastAttachedInnerStreamUrl = '';
    var lastGeneration = -1;
    var lastDirectStreamGeneration = -1;

    try {
      while (_server != null &&
          streamClientGeneration == _streamClientGeneration) {
        final target = await _waitForReadyStreamTarget(
          lastGeneration: lastGeneration,
        );
        if (target == null ||
            streamClientGeneration != _streamClientGeneration) {
          break;
        }

        final directMode = _directStreamUri != null;
        lastAttachedInnerStreamUrl = target.toString();
        lastGeneration = _switchGeneration;
        lastDirectStreamGeneration = _directStreamGeneration;

        try {
          final upstreamRequest = await _client.openUrl('GET', target);
          upstreamRequest.followRedirects = true;
          upstreamRequest.maxRedirects = 4;
          final upstreamResponse = await upstreamRequest.close();
          // A switch/new reader can finish while response headers are pending.
          // Do not let that obsolete response install an active iterator or
          // splice bytes into the current native stream.
          if (_server == null ||
              streamClientGeneration != _streamClientGeneration ||
              lastGeneration != _switchGeneration) {
            await StreamIterator<List<int>>(upstreamResponse).cancel();
            if (directMode &&
                lastDirectStreamGeneration != _directStreamGeneration) {
              break;
            }
            continue;
          }
          if (streamClientGeneration == _streamClientGeneration) {
            _streamAttachments++;
            _streamUpstreamStatus = upstreamResponse.statusCode;
          }

          final iterator = StreamIterator<List<int>>(upstreamResponse);
          _activeUpstreamIterator = iterator;
          try {
            while (await iterator.moveNext()) {
              final chunk = iterator.current;
              if (_server == null ||
                  streamClientGeneration != _streamClientGeneration ||
                  lastGeneration != _switchGeneration) {
                break;
              }
              response.add(chunk);
              _streamReceivedBytes += chunk.length;
              for (
                var index = 0;
                index < chunk.length && _streamHeaderPrefix.length < 8;
                index++
              ) {
                _streamHeaderPrefix.add(chunk[index]);
              }
              _streamFlushPending = true;
              // Preserve the current stream while the native reader drains.
              // Socket closure still aborts flush; buffering alone must not.
              await response.flush();
              if (streamClientGeneration == _streamClientGeneration) {
                _streamFlushedBytes += chunk.length;
                _streamFlushPending = false;
              }
            }
          } finally {
            if (identical(_activeUpstreamIterator, iterator)) {
              _activeUpstreamIterator = null;
            }
            await iterator.cancel();
          }
        } catch (_) {
          if (streamClientGeneration == _streamClientGeneration) {
            _streamPumpFailures++;
            _streamFlushPending = false;
          }
          // media_kit closes the old HTTP response when the same stable URL is
          // force-opened for a new seek. End this request instead of looping a
          // dead response and piling up stale stream pumps.
          break;
        }

        if (directMode &&
            lastDirectStreamGeneration != _directStreamGeneration) {
          break;
        }

        // Without an explicit switch, EOF may follow a fatal partial segment.
        // Propagate it to the native reader. Reattaching a new initialization
        // to this response would hide EOF and splice into the damaged segment.
        if (lastGeneration == _switchGeneration &&
            lastAttachedInnerStreamUrl == _currentStreamTargetLabel()) {
          break;
        }
      }
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> _interruptActiveUpstream() async {
    final iterator = _activeUpstreamIterator;
    _activeUpstreamIterator = null;
    if (iterator == null) return;
    try {
      await iterator.cancel();
    } catch (_) {}
  }

  void _applyStreamHeaders(HttpResponse response) {
    response.headers.set(HttpHeaders.serverHeader, 'Streamlink');
    response.headers.contentType = ContentType('video', 'mp2t');
    response.headers.chunkedTransferEncoding = true;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
  }

  Duration _readReplayDuration(HttpRequest request) {
    final fromLiveUs = int.tryParse(
      request.uri.queryParameters['fromLiveUs'] ?? '',
    );
    if (fromLiveUs != null) {
      return Duration(
        microseconds: fromLiveUs
            .clamp(1, const Duration(seconds: 20).inMicroseconds)
            .toInt(),
      );
    }
    final fromLiveMs = int.tryParse(
      request.uri.queryParameters['fromLiveMs'] ?? '',
    );
    if (fromLiveMs != null) {
      return Duration(
        milliseconds: fromLiveMs
            .clamp(1, const Duration(seconds: 20).inMilliseconds)
            .toInt(),
      );
    }
    final seconds = int.tryParse(request.uri.queryParameters['seconds'] ?? '');
    return Duration(seconds: (seconds ?? 10).clamp(1, 20).toInt());
  }

  Future<Uri?> _waitForReadyStreamTarget({
    required int lastGeneration,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (_server != null && DateTime.now().isBefore(deadline)) {
      final directStreamUri = _directStreamUri;
      if (directStreamUri != null && _switchGeneration != lastGeneration) {
        return directStreamUri;
      }
      if (directStreamUri != null && !_switching) {
        return directStreamUri;
      }
      final inner = _inner;
      if (inner != null &&
          inner.isRunning &&
          _switchGeneration != lastGeneration) {
        return Uri.parse(inner.streamTsUrl);
      }
      if (inner != null && inner.isRunning && !_switching) {
        return Uri.parse(inner.streamTsUrl);
      }
      await Future<void>.delayed(const Duration(milliseconds: 35));
    }

    final directStreamUri = _directStreamUri;
    if (directStreamUri != null) return directStreamUri;
    return _inner != null && _inner!.isRunning
        ? Uri.parse(_inner!.streamTsUrl)
        : null;
  }

  String _currentStreamTargetLabel() {
    final directStreamUri = _directStreamUri;
    if (directStreamUri != null) return directStreamUri.toString();
    return _inner?.streamTsUrl ?? '';
  }

  Future<void> _proxyToInner(HttpRequest request, Uri target) async {
    if (request.method == 'HEAD') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final upstreamRequest = await _client.openUrl(request.method, target);
    upstreamRequest.followRedirects = true;
    upstreamRequest.maxRedirects = 4;

    final upstreamResponse = await upstreamRequest.close();
    request.response.statusCode = upstreamResponse.statusCode;
    request.response.bufferOutput = false;
    request.response.headers.chunkedTransferEncoding = true;

    final contentType = upstreamResponse.headers.contentType;
    if (contentType != null) {
      request.response.headers.contentType = contentType;
    }

    await request.response.addStream(upstreamResponse);
    await request.response.close();
  }
}
