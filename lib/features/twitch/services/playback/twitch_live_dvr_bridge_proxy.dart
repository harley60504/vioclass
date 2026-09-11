import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/playback/twitch_hls_proxy_models.dart';
import '../../models/playback/twitch_segment_timeline_index.dart';
import '../../parsers/playback/twitch_hls_playlist_parser.dart';
import 'twitch_playlist_player_runtime.dart';

class TwitchLiveDvrBridgeProxy {
  static const Duration _freshIndexReuseWindow = Duration(seconds: 4);
  static const int _eventInitialSegmentCount = 6;
  static const int _eventAheadSegmentCount = 5;

  final Dio _dio;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..idleTimeout = const Duration(seconds: 12)
    ..autoUncompress = false;

  HttpServer? _server;
  Uri? _dvrPlaylistUri;
  Duration? _latestDuration;
  List<TwitchHlsSegmentItem> _latestItems = const <TwitchHlsSegmentItem>[];
  TwitchSegmentTimelineIndex? _latestTimelineIndex;
  DateTime? _latestItemsObservedAt;

  Duration? _seekPosition;
  Duration? _timelinePosition;
  int _streamGeneration = 0;
  int? _dvrSeekStartIndex;
  Duration _dvrSeekStartOffset = Duration.zero;
  DateTime? _dvrSeekTargetProgramDateTime;
  DateTime _dvrSeekStartedAt = DateTime.now();

  // Canonical time and media time intentionally use different clocks.
  // Canonical/PDT resolves the requested target to one archive segment and an
  // offset inside that segment. mpv then sees an EVENT playlist whose local
  // media time starts at that segment. The event playlist keeps a fixed first
  // media sequence and only appends segments, so player time never has to track
  // the full Twitch archive duration.
  List<TwitchHlsSegmentItem> _snapshotItems = const <TwitchHlsSegmentItem>[];
  int? _snapshotGeneration;
  int? _snapshotSourceStartIndex;
  int? _snapshotStartSequence;
  Duration _snapshotCanonicalStart = Duration.zero;
  Duration _snapshotPlayerStart = Duration.zero;
  int _snapshotPlaybackIndex = 0;

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
      await _refreshLatestItemsBestEffort(force: true);
      return Uri.parse(playlistUrl);
    }

    final items = await _validatePlaylist(dvrPlaylistUri);
    _dvrPlaylistUri = dvrPlaylistUri;
    _rememberLatestItems(items);
    _resetSeekState();
    _clearSnapshot();
    _streamGeneration++;
    final server = await _ensureServer();
    return Uri.parse('http://127.0.0.1:${server.port}/playlist.m3u8');
  }

  Future<Duration> seekToPosition(
    Duration position, {
    DateTime? targetProgramDateTime,
  }) async {
    await _refreshLatestItemsBestEffort();

    final items = _latestItems;
    final timeline = _latestTimelineIndex;
    if (items.isEmpty || timeline == null || timeline.isEmpty) {
      final safe = position < Duration.zero ? Duration.zero : position;
      _seekPosition = safe;
      _timelinePosition = safe;
      _dvrSeekStartIndex = null;
      _dvrSeekStartOffset = Duration.zero;
      _dvrSeekTargetProgramDateTime = targetProgramDateTime?.toUtc();
      _dvrSeekStartedAt = DateTime.now();
      _clearSnapshot();
      _streamGeneration++;
      return Duration.zero;
    }

    final canonicalPosition = position < Duration.zero ? Duration.zero : position;
    final targetUtc = targetProgramDateTime?.toUtc();
    final programSeek = targetUtc == null
        ? null
        : timeline.resolveProgramDateTime(targetUtc);
    final canonicalSeek = timeline.resolveCanonical(canonicalPosition);
    final resolvedSeek = programSeek ?? canonicalSeek;
    if (resolvedSeek == null) return Duration.zero;

    final usedProgramDateTime = programSeek != null;
    final targetIndex = resolvedSeek.index;
    final segmentOffset = resolvedSeek.offset;
    final resolvedTimelinePosition = usedProgramDateTime
        ? resolvedSeek.canonicalPosition
        : canonicalPosition == resolvedSeek.canonicalPosition
        ? canonicalPosition
        : resolvedSeek.canonicalPosition;

    // Important: the player source begins exactly at the target segment. Never
    // carry previous-segment preroll into player time. The only seek mpv sees is
    // the offset within this first segment.
    final snapshotStartIndex = targetIndex;
    final playerStartPosition = segmentOffset;

    _seekPosition = resolvedTimelinePosition;
    _timelinePosition = resolvedTimelinePosition;
    _dvrSeekStartIndex = targetIndex;
    _dvrSeekStartOffset = segmentOffset;
    _dvrSeekTargetProgramDateTime = usedProgramDateTime ? targetUtc : null;
    _dvrSeekStartedAt = DateTime.now();

    _streamGeneration++;
    _snapshotGeneration = _streamGeneration;
    _snapshotSourceStartIndex = snapshotStartIndex;
    _snapshotStartSequence = items[snapshotStartIndex].sequence;
    _snapshotCanonicalStart =
        timeline.entryAt(snapshotStartIndex)?.canonicalStart ?? Duration.zero;
    _snapshotPlayerStart = playerStartPosition;
    _snapshotPlaybackIndex = 0;
    _snapshotItems = List<TwitchHlsSegmentItem>.unmodifiable(
      items.sublist(snapshotStartIndex),
    );

    final snapshotDuration = _durationOfItems(_snapshotItems);
    debugPrint(
      '[SegmentTimelineIndex][DVR] target=${_seconds(canonicalPosition)}s '
      'resolved=${_seconds(resolvedTimelinePosition)}s '
      'sequence=${resolvedSeek.sequence} index=$targetIndex '
      'offset=${_seconds(segmentOffset)}s '
      'indexed=${_seconds(timeline.indexedDuration)}s',
    );
    debugPrint(
      '[LiveDvrBridge] seek position=${_seconds(resolvedTimelinePosition)}s '
      'segment=$targetIndex offset=${segmentOffset.inMilliseconds}ms '
      'eventStart=$snapshotStartIndex '
      'playerStart=${playerStartPosition.inMilliseconds}ms '
      'snapshotItems=${_snapshotItems.length} '
      'snapshotDuration=${_seconds(snapshotDuration)}s '
      'output=event-hls '
      'clock=${usedProgramDateTime ? 'program-date-time' : 'extinf'} '
      'generation=$_streamGeneration',
    );
    return playerStartPosition;
  }

  void stopStreaming() {
    _streamGeneration++;
    _resetSeekState();
    _clearSnapshot();
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    _dvrPlaylistUri = null;
    _latestDuration = null;
    _latestItems = const <TwitchHlsSegmentItem>[];
    _latestTimelineIndex = null;
    _latestItemsObservedAt = null;
    _resetSeekState();
    _clearSnapshot();
    await server?.close(force: true);
    _client.close(force: true);
  }

  void _resetSeekState() {
    _seekPosition = null;
    _timelinePosition = null;
    _dvrSeekStartIndex = null;
    _dvrSeekStartOffset = Duration.zero;
    _dvrSeekTargetProgramDateTime = null;
    _dvrSeekStartedAt = DateTime.now();
  }

  void _clearSnapshot() {
    _snapshotItems = const <TwitchHlsSegmentItem>[];
    _snapshotGeneration = null;
    _snapshotSourceStartIndex = null;
    _snapshotStartSequence = null;
    _snapshotCanonicalStart = Duration.zero;
    _snapshotPlayerStart = Duration.zero;
    _snapshotPlaybackIndex = 0;
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

  Future<void> _refreshLatestItemsBestEffort({bool force = false}) async {
    final uri = _dvrPlaylistUri;
    if (uri == null) return;

    final observedAt = _latestItemsObservedAt;
    if (!force && observedAt != null && _latestItems.isNotEmpty) {
      final age = DateTime.now().toUtc().difference(observedAt);
      if (!age.isNegative && age <= _freshIndexReuseWindow) {
        debugPrint(
          '[LiveDvrBridge] reuse fresh DVR index age=${age.inMilliseconds}ms '
          'items=${_latestItems.length}',
        );
        return;
      }
    }

    try {
      final items = await _validatePlaylist(uri);
      if (items.isNotEmpty) _rememberLatestItems(items);
    } catch (error) {
      debugPrint('[LiveDvrBridge] seek index refresh failed: $error');
    }
  }

  void _rememberLatestItems(List<TwitchHlsSegmentItem> items) {
    _latestItems = List<TwitchHlsSegmentItem>.unmodifiable(items);
    final index = TwitchSegmentTimelineIndex.fromSegments(_latestItems);
    _latestTimelineIndex = index;
    _latestDuration = index.indexedDuration;
    _latestItemsObservedAt = DateTime.now().toUtc();
  }

  void _syncEventItemsFromLatest() {
    final startSequence = _snapshotStartSequence;
    if (startSequence == null || _latestItems.isEmpty) return;

    final start = _latestItems.indexWhere(
      (item) => item.sequence == startSequence,
    );
    if (start < 0) return;

    final candidate = _latestItems.sublist(start);
    if (candidate.length <= _snapshotItems.length) return;
    _snapshotItems = List<TwitchHlsSegmentItem>.unmodifiable(candidate);
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
      switch (request.uri.path) {
        case '/playlist.m3u8':
          await _handlePlaylist(request);
          return;
        case '/segment.ts':
          await _handleSegment(request);
          return;
        case '/stream.ts':
          await _handleStream(request);
          return;
        case '/health':
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
    final requestedGeneration =
        int.tryParse(request.uri.queryParameters['v'] ?? '') ?? _streamGeneration;
    if (requestedGeneration != _streamGeneration) {
      request.response.statusCode = HttpStatus.gone;
      await request.response.close();
      return;
    }

    final rewritten = await _buildPlaylist(requestedGeneration);
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

    final generation =
        int.tryParse(request.uri.queryParameters['g'] ?? '') ?? _streamGeneration;
    if (generation != _streamGeneration) {
      request.response.statusCode = HttpStatus.gone;
      await request.response.close();
      return;
    }

    if (request.method == 'HEAD') {
      request.response.statusCode = HttpStatus.ok;
      _applyStreamHeaders(request.response);
      await request.response.close();
      return;
    }

    _noteSnapshotSegmentRequest(sourceUri, generation);
    request.response.statusCode = HttpStatus.ok;
    _applyStreamHeaders(request.response);
    request.response.bufferOutput = false;
    try {
      await _writeSegment(request.response, sourceUri, generation);
    } finally {
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  void _noteSnapshotSegmentRequest(Uri sourceUri, int generation) {
    if (_snapshotGeneration != generation || _snapshotItems.isEmpty) return;
    final source = sourceUri.toString();
    final index = _snapshotItems.indexWhere((item) => item.url == source);
    if (index < 0) return;
    if (index > _snapshotPlaybackIndex) {
      _snapshotPlaybackIndex = index;
    }
    debugPrint(
      '[DvrEvent] request generation=$generation '
      'index=$index highWater=$_snapshotPlaybackIndex '
      'segment=${_segmentName(sourceUri)}',
    );
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
    final snapshotDuration = _durationOfItems(_snapshotItems);
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.text;
    request.response.write(
      'ok\n'
      'playlist=$playlistUrl\n'
      'dvr=$_dvrPlaylistUri\n'
      'duration=${_latestDuration?.inSeconds ?? 0}\n'
      'snapshot_generation=${_snapshotGeneration ?? -1}\n'
      'snapshot_items=${_snapshotItems.length}\n'
      'snapshot_duration_ms=${snapshotDuration.inMilliseconds}\n'
      'snapshot_player_start_ms=${_snapshotPlayerStart.inMilliseconds}\n'
      'snapshot_playback_index=$_snapshotPlaybackIndex\n'
      'playlist_mode=event-hls\n'
      'clock=${_dvrSeekTargetProgramDateTime != null ? 'program-date-time' : 'extinf'}\n',
    );
    await request.response.close();
  }

  Future<String> _buildPlaylist(int generation) async {
    if (_snapshotGeneration == generation && _snapshotItems.isNotEmpty) {
      return _eventSnapshotPlaylist(generation);
    }
    return _buildGrowingDvrPlaylist(generation);
  }

  Future<String> _eventSnapshotPlaylist(int generation) async {
    await _refreshLatestItemsBestEffort();
    _syncEventItemsFromLatest();

    final items = _snapshotItems;
    if (items.isEmpty) return _emptyPlaylist();

    final visibleCount = math.min(
      items.length,
      math.max(
        _eventInitialSegmentCount,
        _snapshotPlaybackIndex + _eventAheadSegmentCount + 1,
      ),
    ).toInt();
    final visible = items.sublist(0, visibleCount);
    final maxDurationMs = visible.fold<int>(
      1000,
      (currentMax, item) =>
          math.max(currentMax, item.duration.inMilliseconds).toInt(),
    );

    debugPrint(
      '[LiveDvrBridge] playlist event generation=$generation '
      'sourceStart=${_snapshotSourceStartIndex ?? -1} '
      'mediaSeq=${visible.first.sequence} visible=$visibleCount '
      'highWater=$_snapshotPlaybackIndex '
      'playerStart=${_seconds(_snapshotPlayerStart)}s endlist=false',
    );

    return _segmentPlaylist(
      items: visible,
      mediaSequence: visible.first.sequence,
      targetDuration: Duration(milliseconds: maxDurationMs),
      generation: generation,
      playlistTypeEvent: true,
    );
  }

  Future<String> _buildGrowingDvrPlaylist(int generation) async {
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

    final start = math.max(0, items.length - 6).toInt();
    final window = items.sublist(start);
    return _segmentPlaylist(
      items: window,
      mediaSequence: items[start].sequence,
      targetDuration: playlist.targetDuration,
      generation: generation,
      playlistTypeEvent: false,
    );
  }

  String _segmentPlaylist({
    required List<TwitchHlsSegmentItem> items,
    required int mediaSequence,
    required Duration targetDuration,
    required int generation,
    required bool playlistTypeEvent,
  }) {
    final targetSeconds = math.max(
      1,
      (targetDuration.inMilliseconds / 1000).ceil(),
    ).toInt();
    final buffer = StringBuffer()
      ..writeln('#EXTM3U')
      ..writeln('#EXT-X-VERSION:3')
      ..writeln('#EXT-X-TARGETDURATION:$targetSeconds')
      ..writeln('#EXT-X-MEDIA-SEQUENCE:$mediaSequence');

    if (playlistTypeEvent) {
      buffer.writeln('#EXT-X-PLAYLIST-TYPE:EVENT');
    }

    for (final item in items) {
      final programDateTime = item.programDateTime;
      if (programDateTime != null) {
        buffer.writeln(
          '#EXT-X-PROGRAM-DATE-TIME:${programDateTime.toUtc().toIso8601String()}',
        );
      }
      final durationSeconds = (item.duration.inMicroseconds /
              Duration.microsecondsPerSecond)
          .clamp(0.001, 60.0)
          .toStringAsFixed(3);
      buffer
        ..writeln('#EXTINF:$durationSeconds,')
        ..writeln(_segmentProxyPath(item.url, generation));
    }

    return buffer.toString();
  }

  String _segmentProxyPath(String sourceUrl, int generation) {
    final encoded = base64Url.encode(utf8.encode(sourceUrl));
    return '/segment.ts?u=$encoded&g=$generation';
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

      var timelineCursor = _durationBeforeIndex(items, start);
      debugPrint(
        '[LiveDvrBridge] dvr items=${items.length} start=$start '
        'position=${_seekPosition?.inSeconds ?? 0}s generation=$generation',
      );

      for (var i = start; i < items.length; i++) {
        if (generation != _streamGeneration || _server == null) return;
        final item = items[i];
        if (i == start) debugPrint('[LiveDvrBridge] write dvr ${item.label}');
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
    final segment = _segmentName(sourceUri);
    final stopwatch = Stopwatch()..start();
    debugPrint(
      '[DvrSegment] request generation=$generation segment=$segment',
    );

    final upstreamRequest = await _client.openUrl('GET', sourceUri);
    upstreamRequest.followRedirects = true;
    upstreamRequest.maxRedirects = 5;
    for (final entry
        in TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders.entries) {
      upstreamRequest.headers.set(entry.key, entry.value);
    }
    upstreamRequest.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');

    final upstream = await upstreamRequest.close();
    debugPrint(
      '[DvrSegment] headers generation=$generation segment=$segment '
      'ms=${stopwatch.elapsedMilliseconds} status=${upstream.statusCode}',
    );

    var firstByteLogged = false;
    var bytes = 0;
    await for (final chunk in upstream) {
      if (generation != _streamGeneration || _server == null) return;
      bytes += chunk.length;
      if (!firstByteLogged) {
        firstByteLogged = true;
        debugPrint(
          '[DvrSegment] first-byte generation=$generation segment=$segment '
          'ms=${stopwatch.elapsedMilliseconds}',
        );
      }
      response.add(chunk);
      await response.flush().timeout(const Duration(seconds: 1));
    }

    debugPrint(
      '[DvrSegment] done generation=$generation segment=$segment '
      'totalMs=${stopwatch.elapsedMilliseconds} bytes=$bytes',
    );
  }

  String _segmentName(Uri uri) =>
      uri.pathSegments.isEmpty ? uri.path : uri.pathSegments.last;

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
    return items.take(safeIndex).fold<Duration>(
      Duration.zero,
      (total, item) => total + item.duration,
    );
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
      if (targetMs < cursor) return i;
    }
    return math.max(0, items.length - 1).toInt();
  }

  int _indexForSequence(List<TwitchHlsSegmentItem> items, int sequence) {
    if (items.isEmpty) return 0;
    for (var i = 0; i < items.length; i++) {
      if (items[i].sequence >= sequence) return i;
    }
    return items.length;
  }

  String _seconds(Duration value) =>
      (value.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(3);
}
