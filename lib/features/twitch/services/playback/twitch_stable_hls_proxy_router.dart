// PATCH VERSION: twitch_stable_hls_proxy_router_stage232_seamless_stream_loop
import 'dart:async';
import 'dart:io';

import '../../models/playback/twitch_hls_proxy_models.dart';
import 'twitch_hls_low_latency_proxy.dart';

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
    this.prefetchSegmentCount = 3,
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
  String? _upstreamPlaylistUrl;
  bool _starting = false;
  bool _switching = false;
  int _switchGeneration = 0;

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

  Future<void> switchUpstream(String upstreamPlaylistUrl) async {
    final safeUrl = upstreamPlaylistUrl.trim();
    if (safeUrl.isEmpty) {
      throw ArgumentError.value(
        upstreamPlaylistUrl,
        'upstreamPlaylistUrl',
        'cannot be empty',
      );
    }

    if (_inner != null &&
        _inner!.isRunning &&
        _upstreamPlaylistUrl == safeUrl) {
      return;
    }

    _switching = true;
    final previous = _inner;
    _inner = null;
    _switchGeneration++;

    try {
      final next = TwitchDartHlsLowLatencyProxy(
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

      await next.start();
      await next.waitUntilPrewarmed();

      _inner = next;
      _upstreamPlaylistUrl = safeUrl;
      _switchGeneration++;

      // Close the old inner proxy after the new one is ready. Existing outer
      // `/stream.ts` clients keep their HTTP response open; when the old inner
      // stream ends, the stream loop below immediately attaches to the new
      // inner stream instead of requiring media_kit Player.open().
      await previous?.close();
    } catch (_) {
      _inner = previous;
      _switchGeneration++;
      rethrow;
    } finally {
      _switching = false;
      _switchGeneration++;
    }
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
    final server = _server;
    _server = null;
    _switchGeneration++;

    final inner = _inner;
    _inner = null;
    _upstreamPlaylistUrl = null;

    await inner?.close();
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
      if (inner == null || !inner.isRunning) {
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

      if (path == '/playlist.m3u8') {
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
      'inner_running=${_inner?.isRunning ?? false}\n'
      'inner_stream=${_inner?.streamTsUrl}\n'
      'switching=$_switching\n'
      'switch_generation=$_switchGeneration\n',
    );
    await request.response.close();
  }

  Future<void> _proxyStreamLoop(HttpRequest request) async {
    if (request.method == 'HEAD') {
      request.response.statusCode = HttpStatus.ok;
      _applyStreamHeaders(request.response);
      await request.response.close();
      return;
    }

    final response = request.response;
    response.statusCode = HttpStatus.ok;
    _applyStreamHeaders(response);
    response.bufferOutput = false;

    var lastAttachedInnerStreamUrl = '';
    var lastGeneration = -1;

    try {
      while (_server != null) {
        final inner = await _waitForReadyInner(lastGeneration: lastGeneration);
        if (inner == null) break;

        final target = Uri.parse(inner.streamTsUrl);
        lastAttachedInnerStreamUrl = target.toString();
        lastGeneration = _switchGeneration;

        try {
          final upstreamRequest = await _client.openUrl('GET', target);
          upstreamRequest.followRedirects = true;
          upstreamRequest.maxRedirects = 4;
          final upstreamResponse = await upstreamRequest.close();

          await for (final chunk in upstreamResponse) {
            if (_server == null) break;
            response.add(chunk);
            await response.flush();
          }
        } catch (_) {
          if (_server == null) break;
        }

        // If the same inner stream simply ended without a router switch, do not
        // spin aggressively. Give the inner proxy a moment to expose fresh data.
        if (lastGeneration == _switchGeneration &&
            lastAttachedInnerStreamUrl == (_inner?.streamTsUrl ?? '')) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }
      }
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  void _applyStreamHeaders(HttpResponse response) {
    response.headers.set(HttpHeaders.serverHeader, 'Streamlink');
    response.headers.contentType = ContentType('video', 'mp2t');
    response.headers.chunkedTransferEncoding = true;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
  }

  Future<TwitchDartHlsLowLatencyProxy?> _waitForReadyInner({
    required int lastGeneration,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (_server != null && DateTime.now().isBefore(deadline)) {
      final inner = _inner;
      if (inner != null &&
          inner.isRunning &&
          _switchGeneration != lastGeneration) {
        return inner;
      }
      if (inner != null && inner.isRunning && !_switching) {
        return inner;
      }
      await Future<void>.delayed(const Duration(milliseconds: 35));
    }

    return _inner != null && _inner!.isRunning ? _inner : null;
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
