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
  String? _upstreamPlaylistUrl;
  Uri? _directStreamUri;
  bool _starting = false;
  bool _switching = false;
  int _switchGeneration = 0;
  int _directStreamGeneration = 0;
  int _streamClientGeneration = 0;
  StreamIterator<List<int>>? _activeUpstreamIterator;

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
    final p = port;
    if (p == null) throw StateError('Stable HLS proxy router has not started.');
    final seconds = fromLive.inSeconds.clamp(1, 20).toInt();
    return 'http://127.0.0.1:$p/live-replay.ts?seconds=$seconds';
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

    if (_inner != null &&
        _inner!.isRunning &&
        _directStreamUri == null &&
        _upstreamPlaylistUrl == safeUrl) {
      if (forceReconnect) {
        _switching = true;
        try {
          await _inner!.reconnectAtSegmentBoundary();
          _switchGeneration++;
        } finally {
          _switching = false;
          _switchGeneration++;
        }
      }
      return;
    }

    _switching = true;
    final previous = _inner;
    _directStreamUri = null;
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

      await _interruptActiveUpstream();
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

  Future<void> switchDirectStream(String streamUrl) async {
    final safeUrl = streamUrl.trim();
    final directUri = Uri.tryParse(safeUrl);
    if (directUri == null || safeUrl.isEmpty) {
      throw ArgumentError.value(streamUrl, 'streamUrl', 'cannot be empty');
    }

    if (_directStreamUri == directUri && _server != null) {
      return;
    }

    _switching = true;
    final previous = _inner;
    _inner = null;
    _directStreamUri = directUri;
    _upstreamPlaylistUrl = null;
    _directStreamGeneration++;
    _switchGeneration++;

    try {
      await _interruptActiveUpstream();
      await previous?.close();
    } finally {
      _switching = false;
      _switchGeneration++;
    }
  }

  Future<void> switchLiveReplayStream({required Duration fromLive}) async {
    final inner = _inner;
    if (inner == null || !inner.isRunning) {
      throw StateError('Inner proxy not ready');
    }
    final replayUri = Uri.parse(liveReplayUrl(fromLive: fromLive));
    _switching = true;
    _directStreamUri = replayUri;
    _directStreamGeneration++;
    _switchGeneration++;
    await _interruptActiveUpstream();
    _switching = false;
    _switchGeneration++;
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
    _directStreamUri = null;
    _directStreamGeneration++;
    await _interruptActiveUpstream();

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
        if (inner == null || !inner.isRunning) {
          request.response.statusCode = HttpStatus.badGateway;
          request.response.write('Inner proxy not ready');
          await request.response.close();
          return;
        }
        await _proxyToInner(
          request,
          Uri.parse(
            inner.liveReplayUrl(fromLive: _readReplayDuration(request)),
          ),
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

    // media_kit may open the same stable stream URL again before Windows has
    // reported the previous socket as closed. Keep only the newest stream pump
    // so stale local clients cannot multiply loopback traffic indefinitely.
    final streamClientGeneration = ++_streamClientGeneration;
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

          final iterator = StreamIterator<List<int>>(upstreamResponse);
          _activeUpstreamIterator = iterator;
          try {
            while (await iterator.moveNext()) {
              final chunk = iterator.current;
              if (_server == null ||
                  streamClientGeneration != _streamClientGeneration) {
                break;
              }
              response.add(chunk);
              await response.flush().timeout(const Duration(seconds: 1));
            }
          } finally {
            if (identical(_activeUpstreamIterator, iterator)) {
              _activeUpstreamIterator = null;
            }
            await iterator.cancel();
          }
        } catch (_) {
          // media_kit closes the old HTTP response when the same stable URL is
          // force-opened for a new seek. End this request instead of looping a
          // dead response and piling up stale stream pumps.
          break;
        }

        if (directMode &&
            lastDirectStreamGeneration != _directStreamGeneration) {
          break;
        }

        // If the same inner stream simply ended without a router switch, do not
        // spin aggressively. Give the inner proxy a moment to expose fresh data.
        if (lastGeneration == _switchGeneration &&
            lastAttachedInnerStreamUrl == _currentStreamTargetLabel()) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
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
    final raw = int.tryParse(request.uri.queryParameters['seconds'] ?? '');
    return Duration(seconds: (raw ?? 10).clamp(1, 20).toInt());
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
