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
  final Dio _dio;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..idleTimeout = const Duration(seconds: 12)
    ..autoUncompress = false;

  HttpServer? _server;
  Uri? _dvrPlaylistUri;
  Duration? _latestDuration;
  List<TwitchHlsSegmentItem> _latestItems = const <TwitchHlsSegmentItem>[];
  Duration? _seekPosition;
  Duration? _timelinePosition;
  int _streamGeneration = 0;
  int? _dvrSeekStartIndex;
  Duration _dvrSeekStartOffset = Duration.zero;
  DateTime? _dvrSeekTargetProgramDateTime;
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

  /// Duration represented by media segments that are actually present in the
  /// latest DVR playlist snapshot. Do not extrapolate this value using wall
  /// clock time: seek indexing must only use media that is really available.
  Duration? get latestDuration => _latestDuration;

  bool get isRunning => _server != null;
  bool get isLiveMode => false;
  Duration? get timelinePosition => _timelinePosition ?? _seekPosition;

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
      // A growing DVR URL is stable while its contents continue to grow. Keep
      // the cached index fresh even when the URL itself has not changed.
      try {
        final playlistItems = await _validatePlaylist(dvrPlaylistUri);
        if (playlistItems.isNotEmpty) _rememberLatestItems(playlistItems);
      } catch (_) {
        // Reuse the previous valid snapshot if a single refresh fails.
      }
      return Uri.parse(playlistUrl);
    }

    final playlistItems = await _validatePlaylist(dvrPlaylistUri);
    _dvrPlaylistUri = dvrPlaylistUri;
    _rememberLatestItems(playlistItems);
    _seekPosition = null;
    _timelinePosition = null;
    _dvrSeekStartIndex = null;
    _dvrSeekStartOffset = Duration.zero;
    _dvrSeekTargetProgramDateTime = null;
    _dvrSeekStartedAt = DateTime.now();
    _streamGeneration++;
    final server = await _ensureServer();
    return Uri.parse('http://127.0.0.1:${server.port}/playlist.m3u8');
  }

  /// Resolve a canonical timeline target against a freshly fetched DVR index.
  ///
  /// When PROGRAM-DATE-TIME is present, [targetProgramDateTime] is authoritative
  /// and gives Local TS and DVR a shared absolute clock. Otherwise the bridge
  /// falls back to cumulative EXTINF durations from the start of the DVR.
  Future<Duration> seekToPosition(
    Duration position, {
    DateTime? targetProgramDateTime,
  }) async {
    await _refreshLatestItemsBestEffort();

    final items = _latestItems;
    if (items.isEmpty) {
      _seekPosition = position < Duration.zero ? Duration.zero : position;
      _timelinePosition = _seekPosition;
      _dvrSeekStartIndex = null;
      _dvrSeekStartOffset = Duration.zero;
      _dvrSeekTargetProgramDateTime = targetProgramDateTime?.toUtc();
      _dvrSeekStartedAt = DateTime.now();
      _streamGeneration++;
      return Duration.zero;
    }

    final canonicalPosition = position < Duration.zero ? Duration.zero : position;
    final targetUtc = targetProgramDateTime?.toUtc();
    final programSeek = targetUtc == null
        ? null
        : _resolveProgramDateTimeSeek(items, targetUtc);

    late final int index;
    late final Duration startPosition;
    late final Duration resolvedTimelinePosition;
    var usedProgramDateTime = false;

    if (programSeek != null) {
      index = programSeek.index;
      startPosition = programSeek.offset;
      resolvedTimelinePosition = canonicalPosition;
      usedProgramDateTime = true;
    } else {
      final availableMs = math.max(_durationOfItems(items).inMilliseconds, 1);
      final maxSeekMs = math.max(availableMs - 1, 0);
      final positionMs = canonicalPosition.inMilliseconds
          .clamp(0, maxSeekMs)
          .toInt();
      resolvedTimelinePosition = Duration(milliseconds: positionMs);
      index = _indexForPosition(items, resolvedTimelinePosition);
      final segmentStartMs = _durationBeforeIndex(items, index).inMilliseconds;
      final segmentDurationMs = math.max(
        items[index].duration.inMilliseconds,
        1,
      );
      final offsetMs = (positionMs - segmentStartMs)
          .clamp(0, math.max(segmentDurationMs - 1, 0))
          .toInt();
      startPosition = Duration(milliseconds: offsetMs);
    }

    _seekPosition = resolvedTimelinePosition;
    _timelinePosition = resolvedTimelinePosition;
    _dvrSeekStartIndex = index;
    _dvrSeekStartOffset = startPosition;
    _dvrSeekTargetProgramDateTime = usedProgramDateTime ? targetUtc : null;
    _dvrSeekStartedAt = DateTime.now();
    _streamGeneration++;
    debugPrint(
      '[LiveDvrBridge] seek position=${resolvedTimelinePosition.inSeconds}s '
      'segment=$index offset=${startPosition.inMilliseconds}ms '
      'clock=${usedProgramDateTime ? 'program-date-time' : 'extinf'} '
      'generation=$_streamGeneration',
    );
    return startPosition;
  }

  void stopStreaming() {
    _streamGeneration++;
    _seekPosition = null;
    _timelinePosition = null;
    _dvrSeekStartIndex = null;
    _dvrSeekStartOffset = Duration.zero;
    _dvrSeekTargetProgramDateTime = null;
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    _dvrPlaylistUri = null;
    _latestDuration = null;
    _latestItems = const <TwitchHlsSegmentItem>[];
    _seekPosition = null;
    _timelinePosition = null;
    _dvrSeekStartIndex = null;
    _dvrSeekStartOffset = Duration.zero;
    _dvrSeekTargetProgramDateTime = null;
    await server?.close(force: true);
    _client.close(force: true);
  }

  Future<List<TwitchHlsSegmentItem>> _validatePlaylist(Uri uri) async {
    final text = await _fetchPlaylist(uri);
    if (!text.contains('#EXTM3U') || !text.contains('#EXTINF')) {
      throw StateError('Live DVR bridge playlist 載入失敗。');
    }
    final playlist = TwitchHlsPlaylistParser.parse(
      text,
      playlistUrl: uri.toString(),
    );
    return playlist.items.where((item) => !item.isPrefetch).toList();
  }

  Future<void> _refreshLatestItemsBestEffort() async {
    final uri = _dvrPlaylistUri;
    if (uri == null) return;
    try {
      final items = await _validatePlaylist(uri);
      if (items.isNotEmpty) _rememberLatestItems(items);
    } catch (error) {
      debugPrint('[LiveDvrBridge] seek index refresh failed: $error');
    }
  }

  void _rememberLatestItems(List<TwitchHlsSegmentItem> items) {
    _latestItems = List<TwitchHlsSegmentItem>.unmodifiable(items);
    _latestDuration = _durationOfItems(items);
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
      final generation =
          int.tryParse(request.uri.queryParameters['g'] ?? '') ??
          _streamGeneration;
      await _writeSegment(request.response, sourceUri, generation);
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

    try {
      final generation =
          int.tryParse(request.uri.queryParameters['v'] ?? '') ??
          _streamGeneration;
      await _streamDvrForRequest(response, generation);
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
      'duration=${_latestDuration?.inSeconds ?? 0}\n'
      'clock=${_dvrSeekTargetProgramDateTime != null ? 'program-date-time' : 'extinf'}\n',
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
    _rememberLatestItems(items);
    if (items.isEmpty) return _emptyPlaylist();

    final elapsed = DateTime.now().difference(_dvrSeekStartedAt);
    final targetProgramDateTime = _dvrSeekTargetProgramDateTime;
    int current;

    if (targetProgramDateTime != null) {
      final playbackProgramDateTime = targetProgramDateTime.add(elapsed);
      current =
          _indexForProgramDateTime(items, playbackProgramDateTime) ??
          _indexForCurrentSeek(items);
      final basePosition = _seekPosition ?? Duration.zero;
      _timelinePosition = basePosition + elapsed;
    } else {
      final start = (_dvrSeekStartIndex ?? _indexForCurrentSeek(items))
          .clamp(0, items.length - 1)
          .toInt();
      final baseMs =
          _durationBeforeIndex(items, start).inMilliseconds +
          _dvrSeekStartOffset.inMilliseconds;
      final availableMs = math.max(_durationOfItems(items).inMilliseconds, 1);
      final playbackMs = (baseMs + elapsed.inMilliseconds)
          .clamp(0, math.max(availableMs - 1, 0))
          .toInt();
      current = _indexForPosition(
        items,
        Duration(milliseconds: playbackMs),
      );
      _timelinePosition = Duration(milliseconds: playbackMs);
    }

    final windowStart = current.clamp(0, items.length - 1).toInt();
    final windowEnd = math.min(items.length, windowStart + 5).toInt();
    final window = items.sublist(windowStart, windowEnd);
    debugPrint(
      '[LiveDvrBridge] playlist dvr items=${items.length} index=$windowStart '
      'position=${_timelinePosition?.inSeconds ?? _seekPosition?.inSeconds ?? 0}s '
      'clock=${targetProgramDateTime != null ? 'program-date-time' : 'extinf'} '
      'generation=$_streamGeneration',
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
      final programDateTime = item.programDateTime;
      if (programDateTime != null) {
        buffer.writeln(
          '#EXT-X-PROGRAM-DATE-TIME:${programDateTime.toUtc().toIso8601String()}',
        );
      }
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

  Future<void> _streamDvrForRequest(
    HttpResponse response,
    int generation,
  ) async {
    int? nextSequence;

    while (_server != null && generation == _streamGeneration) {
      final dvrUri = _dvrPlaylistUri;
      if (dvrUri == null) return;

      final text = await _fetchPlaylist(dvrUri);
      final playlist = TwitchHlsPlaylistParser.parse(
        text,
        playlistUrl: dvrUri.toString(),
      );
      final items = playlist.items.where((item) => !item.isPrefetch).toList();
      _rememberLatestItems(items);
      if (items.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        continue;
      }

      final start = nextSequence == null
          ? _dvrSeekStartIndex ?? _indexForCurrentSeek(items)
          : _indexForSequence(items, nextSequence);
      if (start >= items.length) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        continue;
      }
      var timelineCursor = items
          .take(start)
          .fold<Duration>(
            Duration.zero,
            (total, item) => total + item.duration,
          );
      debugPrint(
        '[LiveDvrBridge] dvr items=${items.length} start=$start '
        'position=${_seekPosition?.inSeconds ?? 0}s generation=$generation',
      );

      for (var i = start; i < items.length; i++) {
        if (generation != _streamGeneration || _server == null) return;
        final item = items[i];
        if (i == start) {
          debugPrint('[LiveDvrBridge] write dvr ${item.label}');
        }
        await _writeSegment(response, Uri.parse(item.url), generation);
        timelineCursor += item.duration;
        _timelinePosition = timelineCursor;
        nextSequence = item.sequence + 1;
      }

      final waitMs = playlist.targetDuration.inMilliseconds.clamp(350, 1800);
      await Future<void>.delayed(Duration(milliseconds: waitMs.toInt()));
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
      await response.flush().timeout(const Duration(seconds: 1));
    }
  }

  void _applyStreamHeaders(HttpResponse response) {
    response.headers.set(HttpHeaders.serverHeader, 'Streamlink');
    response.headers.contentType = ContentType('video', 'mp2t');
    response.headers.chunkedTransferEncoding = true;
    response.headers.set(
      HttpHeaders.cacheControlHeader,
      'no-store, no-cache, must-revalidate',
    );
    response.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
    response.headers.set(HttpHeaders.expiresHeader, '0');
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

  Duration _durationOfItems(List<TwitchHlsSegmentItem> items) {
    return items.fold<Duration>(
      Duration.zero,
      (total, item) => total + item.duration,
    );
  }

  Duration _durationBeforeIndex(List<TwitchHlsSegmentItem> items, int index) {
    final safeIndex = index.clamp(0, items.length).toInt();
    return items
        .take(safeIndex)
        .fold<Duration>(
          Duration.zero,
          (total, item) => total + item.duration,
        );
  }

  ({int index, Duration offset})? _resolveProgramDateTimeSeek(
    List<TwitchHlsSegmentItem> items,
    DateTime target,
  ) {
    final index = _indexForProgramDateTime(items, target);
    if (index == null) return null;
    final start = items[index].programDateTime;
    if (start == null) return null;
    final durationMs = math.max(items[index].duration.inMilliseconds, 1);
    final rawOffsetMs = target.difference(start).inMilliseconds;
    final offsetMs = rawOffsetMs
        .clamp(0, math.max(durationMs - 1, 0))
        .toInt();
    return (index: index, offset: Duration(milliseconds: offsetMs));
  }

  int? _indexForProgramDateTime(
    List<TwitchHlsSegmentItem> items,
    DateTime target,
  ) {
    int? firstTimedIndex;
    int? lastTimedIndex;
    final targetUtc = target.toUtc();

    for (var i = 0; i < items.length; i++) {
      final start = items[i].programDateTime?.toUtc();
      if (start == null) continue;
      firstTimedIndex ??= i;
      lastTimedIndex = i;
      if (targetUtc.isBefore(start)) return i;
      final end = start.add(items[i].duration);
      if (targetUtc.isBefore(end)) return i;
    }

    if (firstTimedIndex == null) return null;
    final firstStart = items[firstTimedIndex].programDateTime!.toUtc();
    if (targetUtc.isBefore(firstStart)) return firstTimedIndex;
    return lastTimedIndex;
  }

  int _indexForCurrentSeek(List<TwitchHlsSegmentItem> items) {
    final targetProgramDateTime = _dvrSeekTargetProgramDateTime;
    if (targetProgramDateTime != null) {
      final index = _indexForProgramDateTime(items, targetProgramDateTime);
      if (index != null) return index;
    }
    final position = _seekPosition;
    return _indexForPosition(items, position ?? Duration.zero);
  }

  int _indexForPosition(List<TwitchHlsSegmentItem> items, Duration position) {
    if (items.isEmpty) return 0;
    final duration = _durationOfItems(items);
    if (duration.inMilliseconds <= 0) return 0;
    final maxSeekMs = math.max(duration.inMilliseconds - 1, 0);
    final targetMs = position.inMilliseconds.clamp(0, maxSeekMs).toInt();
    var cursor = 0;
    for (var i = 0; i < items.length; i++) {
      cursor += items[i].duration.inMilliseconds;
      // Segment ranges are [start, end). A target exactly on the boundary
      // belongs to the next segment.
      if (targetMs < cursor) return i;
    }
    return math.max(0, items.length - 1);
  }

  int _indexForSequence(List<TwitchHlsSegmentItem> items, int sequence) {
    if (items.isEmpty) return 0;
    for (var i = 0; i < items.length; i++) {
      if (items[i].sequence >= sequence) return i;
    }
    return items.length;
  }
}
