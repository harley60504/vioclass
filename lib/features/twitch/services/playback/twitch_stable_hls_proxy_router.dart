import 'dart:async';
import 'dart:io';

import '../../models/playback/twitch_hls_proxy_models.dart';
import 'twitch_hls_low_latency_proxy.dart';

/// Stable local URL wrapper for Twitch HLS playback.
///
/// media_kit is sensitive to repeatedly opening different local URLs such as
/// `http://127.0.0.1:PORT/stream.ts`. This router keeps one outer HTTP server
/// and port stable while swapping the inner low-latency proxy when the Twitch
/// upstream playlist changes.
///
/// Stage 125 intentionally keeps the existing low-latency proxy implementation
/// intact for safety. It reduces player-side churn first; a later stage can
/// move the inner proxy itself to true in-place upstream switching.
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
      throw ArgumentError.value(upstreamPlaylistUrl, 'upstreamPlaylistUrl', 'cannot be empty');
    }

    if (_inner != null && _inner!.isRunning && _upstreamPlaylistUrl == safeUrl) {
      return;
    }

    _switching = true;
    final previous = _inner;
    _inner = null;

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
        startupRequirePrefetchedFirstSegment: startupRequirePrefetchedFirstSegment,
        startupSkipCurrentLatestSegment: startupSkipCurrentLatestSegment,
        startupMode: startupMode,
        verboseLogging: verboseLogging,
      );

      await next.start();
      await next.waitUntilPrewarmed();

      _inner = next;
      _upstreamPlaylistUrl = safeUrl;
      await previous?.close();
    } catch (_) {
      _inner = previous;
      rethrow;
    } finally {
      _switching = false;
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
        request.response.write(_switching ? 'Switching upstream' : 'Inner proxy not ready');
        await request.response.close();
        return;
      }

      if (path == '/' || path == '/stream' || path == '/stream.ts') {
        await _proxyToInner(request, Uri.parse(inner.streamTsUrl));
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
      'switching=$_switching\n',
    );
    await request.response.close();
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
