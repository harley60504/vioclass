import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/playback/twitch_hls_proxy_models.dart';
import '../../parsers/playback/twitch_hls_playlist_parser.dart';
import 'twitch_playlist_player_runtime.dart';

class TwitchLiveDvrBridgeProxy {
  static const double liveEdgeRatio = 0.98;

  final Dio _dio;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..idleTimeout = const Duration(seconds: 12)
    ..autoUncompress = false;

  HttpServer? _server;
  Uri? _dvrPlaylistUri;
  Duration? _latestDuration;
  double _seekRatio = 1.0;
  int _streamGeneration = 0;
  int? _dvrSeekStartIndex;
  DateTime _dvrSeekStartedAt = DateTime.now();

  TwitchLiveDvrBridgeProxy({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  Duration? get latestDuration => _latestDuration;
  bool get isRunning => _server != null;
  bool get isLiveMode => false;
  double get timelineRatio => _seekRatio;
  String get playlistPlaybackUrl => '$playlistUrl?v=$_streamGeneration';
  String get streamTsPlaybackUrl => '$streamTsUrl?v=$_streamGeneration';

  String get playlistUrl {
    final server = _server;
    if (server == null) {
      throw StateError('Live DVR bridge proxy has not started.');
    }
    return 'http://127.0.0.1:${server.port}/playlist.m3u8';
  }

  String get streamTsUrl {
    final server = _server;
    if (server == null) {
      throw StateError('Live DVR bridge proxy has not started.');
    }
    return 'http://127.0.0.1:${server.port}/stream.ts';
  }

  Future<Uri> open({required Uri dvrPlaylistUri}) async {
    if (_server != null && _dvrPlaylistUri == dvrPlaylistUri) {
      return Uri.parse(playlistUrl);
    }

    await _validatePlaylist(dvrPlaylistUri);
    _dvrPlaylistUri = dvrPlaylistUri;
    _seekRatio = 0.92;
    _dvrSeekStartIndex = null;
    _dvrSeekStartedAt = DateTime.now();
    _streamGeneration++;
    final server = await _ensureServer();
    return Uri.parse('http://127.0.0.1:${server.port}/playlist.m3u8');
  }

  String seekToRatio(double ratio) {
    _seekRatio = ratio.clamp(0.0, liveEdgeRatio - 0.01).toDouble();
    _dvrSeekStartIndex = null;
    _dvrSeekStartedAt = DateTime.now();
    _streamGeneration++;
    debugPrint(
      '[LiveDvrBridge] seek ratio=${ratio.toStringAsFixed(3)} '
      'generation=$_streamGeneration',
    );
    return streamTsPlaybackUrl;
  }

  void updateTimelineRatio(double ratio) {
    _seekRatio = ratio.clamp(0.0, liveEdgeRatio - 0.01).toDouble();
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    _dvrPlaylistUri = null;
    _latestDuration = null;
    await server?.close(force: true);
    _client.close(force: true);
  }

  Future<void> _validatePlaylist(Uri uri) async {
    final text = await _fetchPlaylist(uri);
    if (!text.contains('#EXTM3U') || !text.contains('#EXTINF')) {
      throw StateError('Live DVR bridge playlist 載入失敗。');
    }
  }

  Future<HttpServer> _ensureServer() async {
    final existing = _server;
    if (existing != null) return existing;

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    unawaited(_serve(server));
    return server;
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handleRequest(request));
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (path == '/playlist.m3u8') {
        await _handlePlaylist(request);
        return;
      }
      if (path == '/segment.ts') {
        await _handleSegment(request);
        return;
      }
      if (path == '/stream.ts') {
        await _handleStream(request);
        return;
      }
      if (path == '/health') {
        await _handleHealth(request);
        return;
      }
      request.response.statusCode = HttpStatus.notFound;
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

  Future<void> _handlePlaylist(HttpRequest request) async {
    final rewritten = await _buildPlaylist();
    final bytes = utf8.encode(rewritten);
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
    request.response.headers.contentLength = bytes.length;
    if (request.method != 'HEAD') request.response.add(bytes);
    await request.response.close();
  }

  Future<void> _handleSegment(HttpRequest request) async {
    final encoded = request.uri.queryParameters['u'];
    if (encoded == null || encoded.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('missing segment url');
      await request.response.close();
      return;
    }

    Uri sourceUri;
    try {
      sourceUri = Uri.parse(utf8.decode(base64Url.decode(encoded)));
    } catch (_) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('invalid segment url');
      await request.response.close();
      return;
    }

    if (request.method == 'HEAD') {
      request.response.statusCode = HttpStatus.ok;
      _applyStreamHeaders(request.response);
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.ok;
    _applyStreamHeaders(request.response);
    request.response.bufferOutput = false;
    try {
      await _writeSegment(request.response, sourceUri, _streamGeneration);
    } finally {
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleStream(HttpRequest request) async {
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

    var observedGeneration = _streamGeneration;
    try {
      while (_server != null) {
        final generation = _streamGeneration;
        if (generation != observedGeneration) {
          observedGeneration = generation;
          debugPrint('[LiveDvrBridge] switch dvr generation=$generation');
        }
        await _streamDvrFromRatio(response, generation);
      }
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleHealth(HttpRequest request) async {
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.text;
    request.response.write(
      'ok\n'
      'playlist=$playlistUrl\n'
      'dvr=$_dvrPlaylistUri\n'
      'duration=${_latestDuration?.inSeconds ?? 0}\n',
    );
    await request.response.close();
  }

  Future<String> _buildPlaylist() async {
    return _buildDvrPlaylist();
  }

  Future<String> _buildDvrPlaylist() async {
    final dvrUri = _dvrPlaylistUri;
    if (dvrUri == null) return _emptyPlaylist();

    final text = await _fetchPlaylist(dvrUri);
    final playlist = TwitchHlsPlaylistParser.parse(
      text,
      playlistUrl: dvrUri.toString(),
    );
    final items = playlist.items.where((item) => !item.isPrefetch).toList();
    _latestDuration = items.fold<Duration>(
      Duration.zero,
      (total, item) => total + item.duration,
    );
    if (items.isEmpty) return _emptyPlaylist();

    _dvrSeekStartIndex ??= _indexForRatio(items, _seekRatio);
    final averageMs = math.max(
      250,
      (_latestDuration!.inMilliseconds / items.length).round(),
    );
    final elapsedSegments =
        DateTime.now().difference(_dvrSeekStartedAt).inMilliseconds ~/
        averageMs;
    final current = (_dvrSeekStartIndex! + elapsedSegments).clamp(
      0,
      items.length - 1,
    );
    final windowStart = math.max(0, current - 3);
    final window = items.sublist(windowStart, current + 1);
    debugPrint(
      '[LiveDvrBridge] playlist dvr items=${items.length} index=$current '
      'ratio=${_seekRatio.toStringAsFixed(3)} generation=$_streamGeneration',
    );
    return _segmentPlaylist(
      items: window,
      mediaSequence: items[windowStart].sequence,
      targetDuration: playlist.targetDuration,
    );
  }

  String _segmentPlaylist({
    required List<TwitchHlsSegmentItem> items,
    required int mediaSequence,
    required Duration targetDuration,
  }) {
    final targetSeconds = math.max(
      1,
      (targetDuration.inMilliseconds / 1000).ceil(),
    );
    final buffer = StringBuffer()
      ..writeln('#EXTM3U')
      ..writeln('#EXT-X-VERSION:3')
      ..writeln('#EXT-X-TARGETDURATION:$targetSeconds')
      ..writeln('#EXT-X-MEDIA-SEQUENCE:$mediaSequence')
      ..writeln('#EXT-X-DISCONTINUITY-SEQUENCE:$_streamGeneration')
      ..writeln('#EXT-X-DISCONTINUITY');

    for (final item in items) {
      final durationSeconds = (item.duration.inMilliseconds / 1000)
          .clamp(0.1, 60.0)
          .toStringAsFixed(3);
      buffer
        ..writeln('#EXTINF:$durationSeconds,')
        ..writeln(_segmentProxyPath(item.url));
    }
    return buffer.toString();
  }

  String _segmentProxyPath(String sourceUrl) {
    final encoded = base64Url.encode(utf8.encode(sourceUrl));
    return '/segment.ts?u=$encoded&g=$_streamGeneration';
  }

  String _emptyPlaylist() {
    return '#EXTM3U\n'
        '#EXT-X-VERSION:3\n'
        '#EXT-X-TARGETDURATION:2\n'
        '#EXT-X-MEDIA-SEQUENCE:0\n';
  }

  Future<void> _streamDvrFromRatio(
    HttpResponse response,
    int generation,
  ) async {
    final dvrUri = _dvrPlaylistUri;
    if (dvrUri == null) return;

    final text = await _fetchPlaylist(dvrUri);
    final playlist = TwitchHlsPlaylistParser.parse(
      text,
      playlistUrl: dvrUri.toString(),
    );
    final items = playlist.items.where((item) => !item.isPrefetch).toList();
    _latestDuration = items.fold<Duration>(
      Duration.zero,
      (total, item) => total + item.duration,
    );
    if (items.isEmpty) return;

    final start = _indexForRatio(items, _seekRatio);
    debugPrint(
      '[LiveDvrBridge] dvr items=${items.length} start=$start '
      'ratio=${_seekRatio.toStringAsFixed(3)} generation=$generation',
    );
    for (var i = start; i < items.length; i++) {
      if (generation != _streamGeneration) return;
      final item = items[i];
      if (i == start) {
        debugPrint('[LiveDvrBridge] write dvr ${item.label}');
      }
      await _writeSegment(response, Uri.parse(item.url), generation);
    }
  }

  Future<void> _writeSegment(
    HttpResponse response,
    Uri sourceUri,
    int generation,
  ) async {
    final upstreamRequest = await _client.openUrl('GET', sourceUri);
    upstreamRequest.followRedirects = true;
    upstreamRequest.maxRedirects = 5;
    for (final entry
        in TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders.entries) {
      upstreamRequest.headers.set(entry.key, entry.value);
    }
    upstreamRequest.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');

    final upstream = await upstreamRequest.close();
    await for (final chunk in upstream) {
      if (generation != _streamGeneration || _server == null) return;
      response.add(chunk);
      await response.flush();
    }
  }

  void _applyStreamHeaders(HttpResponse response) {
    response.headers.set(HttpHeaders.serverHeader, 'Streamlink');
    response.headers.contentType = ContentType('video', 'mp2t');
    response.headers.chunkedTransferEncoding = true;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
  }

  Future<String> _fetchPlaylist(Uri uri) async {
    final response = await _dio.getUri<String>(
      uri,
      options: Options(
        responseType: ResponseType.plain,
        headers: TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final statusCode = response.statusCode ?? 0;
    final text = response.data ?? '';
    if (statusCode >= 400 || !text.contains('#EXTM3U')) {
      throw StateError('Playlist 載入失敗：HTTP $statusCode');
    }
    return text;
  }

  int _indexForRatio(List<TwitchHlsSegmentItem> items, double ratio) {
    final duration = items.fold<Duration>(
      Duration.zero,
      (total, item) => total + item.duration,
    );
    if (duration.inMilliseconds <= 0) return 0;
    final targetMs = (duration.inMilliseconds * ratio.clamp(0.0, 0.98)).round();
    var cursor = 0;
    for (var i = 0; i < items.length; i++) {
      cursor += items[i].duration.inMilliseconds;
      if (cursor >= targetMs) return i;
    }
    return math.max(0, items.length - 1);
  }
}
