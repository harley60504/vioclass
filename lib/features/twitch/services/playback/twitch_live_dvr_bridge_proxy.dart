import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/playback/twitch_hls_proxy_models.dart';
import '../../models/playback/twitch_segment_timeline_index.dart';
import '../../parsers/playback/twitch_hls_playlist_parser.dart';
import 'twitch_playlist_player_runtime.dart';

/// DVR transport that keeps canonical time resolution separate from media I/O.
///
/// [seekToPosition] resolves canonical/PDT time to one Twitch archive segment
/// plus an offset inside that segment. Playback is then exposed as one
/// continuous MPEG-TS HTTP response. Only this proxy chooses which upstream
/// segment is downloaded, so mpv/FFmpeg cannot fan out concurrent DVR segment
/// requests as it can with an HLS media playlist.
class TwitchLiveDvrBridgeProxy {
  static const Duration _freshIndexReuseWindow = Duration(seconds: 4);
  static const Duration _emptyPlaylistRetryDelay = Duration(milliseconds: 250);
  static const Duration _tailRefreshDelay = Duration(milliseconds: 180);
  static const int _flushByteThreshold = 64 * 1024;
  static const Duration _flushTimeThreshold = Duration(milliseconds: 20);

  final Dio _dio;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..idleTimeout = const Duration(seconds: 12)
    ..maxConnectionsPerHost = 1
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
  int _streamClientGeneration = 0;
  int? _dvrSeekStartIndex;
  int? _dvrSeekStartSequence;
  Duration _dvrSeekStartOffset = Duration.zero;
  Duration? _dvrSeekCanonicalSegmentStart;
  DateTime? _dvrSeekTargetProgramDateTime;

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

  /// Kept for callers that used the previous HLS bridge API. DVR playback is
  /// intentionally TS-only now, so this compatibility getter points at the
  /// same sequential stream as [streamTsPlaybackUrl].
  String get playlistPlaybackUrl => streamTsPlaybackUrl;

  String get streamTsPlaybackUrl => '$streamTsUrl?v=$_streamGeneration';

  /// Compatibility alias. The active DVR transport no longer serves HLS.
  String get playlistUrl => streamTsUrl;

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
      return Uri.parse(streamTsUrl);
    }

    final items = await _validatePlaylist(dvrPlaylistUri);
    _dvrPlaylistUri = dvrPlaylistUri;
    _rememberLatestItems(items);
    _resetSeekState();
    _streamGeneration++;
    _streamClientGeneration++;
    final server = await _ensureServer();
    return Uri.parse('http://127.0.0.1:${server.port}/stream.ts');
  }

  /// Resolves the requested canonical time but does not download media.
  ///
  /// The returned duration is relative to the first TS segment that will be
  /// emitted for this generation. The player therefore only needs to skip the
  /// intra-segment offset while this proxy keeps full control of segment order.
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
      _dvrSeekStartSequence = null;
      _dvrSeekStartOffset = Duration.zero;
      _dvrSeekCanonicalSegmentStart = null;
      _dvrSeekTargetProgramDateTime = targetProgramDateTime?.toUtc();
      _streamGeneration++;
      _streamClientGeneration++;
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
    final canonicalSegmentStart =
        resolvedSeek.canonicalPosition - segmentOffset;

    _seekPosition = resolvedTimelinePosition;
    _timelinePosition = resolvedTimelinePosition;
    _dvrSeekStartIndex = targetIndex;
    _dvrSeekStartSequence = resolvedSeek.sequence;
    _dvrSeekStartOffset = segmentOffset;
    _dvrSeekCanonicalSegmentStart = canonicalSegmentStart;
    _dvrSeekTargetProgramDateTime = usedProgramDateTime ? targetUtc : null;

    // Every seek owns a new stream generation. Existing /stream.ts readers and
    // their active upstream segment stop as soon as their next chunk arrives.
    _streamGeneration++;
    _streamClientGeneration++;

    debugPrint(
      '[SegmentTimelineIndex][DVR] target=${_seconds(canonicalPosition)}s '
      'resolved=${_seconds(resolvedTimelinePosition)}s '
      'sequence=${resolvedSeek.sequence} index=$targetIndex '
      'offset=${_seconds(segmentOffset)}s '
      'indexed=${_seconds(timeline.indexedDuration)}s',
    );
    debugPrint(
      '[LiveDvrBridge] seek position=${_seconds(resolvedTimelinePosition)}s '
      'segment=$targetIndex sequence=${resolvedSeek.sequence} '
      'offset=${segmentOffset.inMilliseconds}ms '
      'playerStart=${segmentOffset.inMilliseconds}ms '
      'output=sequential-ts '
      'clock=${usedProgramDateTime ? 'program-date-time' : 'extinf'} '
      'generation=$_streamGeneration',
    );
    return segmentOffset;
  }

  void stopStreaming() {
    _streamGeneration++;
    _streamClientGeneration++;
    _resetSeekState();
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    _streamGeneration++;
    _streamClientGeneration++;
    _dvrPlaylistUri = null;
    _latestDuration = null;
    _latestItems = const <TwitchHlsSegmentItem>[];
    _latestTimelineIndex = null;
    _latestItemsObservedAt = null;
    _resetSeekState();
    await server?.close(force: true);
    _client.close(force: true);
  }

  void _resetSeekState() {
    _seekPosition = null;
    _timelinePosition = null;
    _dvrSeekStartIndex = null;
    _dvrSeekStartSequence = null;
    _dvrSeekStartOffset = Duration.zero;
    _dvrSeekCanonicalSegmentStart = null;
    _dvrSeekTargetProgramDateTime = null;
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
      debugPrint('[DvrSequential] request error: $error');
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleStream(HttpRequest request) async {
    final generation =
        int.tryParse(request.uri.queryParameters['v'] ?? '') ??
        _streamGeneration;
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

    // Only the newest player connection is allowed to own the sequential pump.
    // A reconnect/seek invalidates the previous client before opening upstream.
    final clientGeneration = ++_streamClientGeneration;
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    _applyStreamHeaders(response);
    response.bufferOutput = false;

    debugPrint(
      '[DvrSequential] client generation=$generation '
      'client=$clientGeneration startSequence=${_dvrSeekStartSequence ?? -1} '
      'offset=${_dvrSeekStartOffset.inMilliseconds}ms',
    );

    try {
      await _streamDvrForRequest(
        response,
        generation,
        clientGeneration,
      );
    } catch (error) {
      if (_isActiveStream(generation, clientGeneration)) {
        debugPrint(
          '[DvrSequential] stream error generation=$generation '
          'client=$clientGeneration error=$error',
        );
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
      'stream=$streamTsUrl\n'
      'dvr=$_dvrPlaylistUri\n'
      'duration=${_latestDuration?.inSeconds ?? 0}\n'
      'generation=$_streamGeneration\n'
      'client_generation=$_streamClientGeneration\n'
      'start_index=${_dvrSeekStartIndex ?? -1}\n'
      'start_sequence=${_dvrSeekStartSequence ?? -1}\n'
      'start_offset_ms=${_dvrSeekStartOffset.inMilliseconds}\n'
      'transport=sequential-ts\n'
      'clock=${_dvrSeekTargetProgramDateTime != null ? 'program-date-time' : 'extinf'}\n',
    );
    await request.response.close();
  }

  Future<void> _streamDvrForRequest(
    HttpResponse response,
    int generation,
    int clientGeneration,
  ) async {
    var nextSequence = _dvrSeekStartSequence;
    var firstSegment = true;

    while (_isActiveStream(generation, clientGeneration)) {
      var items = _latestItems;
      if (items.isEmpty) {
        await _refreshLatestItemsBestEffort(force: true);
        items = _latestItems;
        if (items.isEmpty) {
          await Future<void>.delayed(_emptyPlaylistRetryDelay);
          continue;
        }
      }

      var start = nextSequence == null
          ? (_dvrSeekStartIndex ?? _indexForCurrentSeek(items))
          : _indexForSequence(items, nextSequence);

      // The archive playlist may have advanced between seek resolution and the
      // first media read. Refresh once before treating a missing sequence as a
      // discontinuity.
      if (start >= items.length) {
        await _refreshLatestItemsBestEffort(force: true);
        items = _latestItems;
        start = nextSequence == null
            ? (_dvrSeekStartIndex ?? _indexForCurrentSeek(items))
            : _indexForSequence(items, nextSequence);
        if (items.isEmpty || start >= items.length) {
          await Future<void>.delayed(_tailRefreshDelay);
          continue;
        }
      }

      for (var i = start; i < items.length; i++) {
        if (!_isActiveStream(generation, clientGeneration)) return;
        final item = items[i];
        if (nextSequence != null && item.sequence < nextSequence) continue;

        if (firstSegment) {
          debugPrint(
            '[DvrSequential] start generation=$generation '
            'client=$clientGeneration index=$i sequence=${item.sequence} '
            'segment=${_segmentName(Uri.parse(item.url))}',
          );
        }

        await _writeSegment(
          response,
          Uri.parse(item.url),
          generation,
          clientGeneration,
        );
        if (!_isActiveStream(generation, clientGeneration)) return;

        final segmentStart = firstSegment
            ? _dvrSeekCanonicalSegmentStart
            : _canonicalStartForSequence(items, item.sequence);
        if (segmentStart != null) {
          _timelinePosition = segmentStart + item.duration;
        } else if (_timelinePosition != null) {
          _timelinePosition = _timelinePosition! + item.duration;
        }

        firstSegment = false;
        nextSequence = item.sequence + 1;
      }

      if (!_isActiveStream(generation, clientGeneration)) return;
      await Future<void>.delayed(_tailRefreshDelay);
      await _refreshLatestItemsBestEffort(force: true);
    }
  }

  Future<void> _writeSegment(
    HttpResponse response,
    Uri sourceUri,
    int generation,
    int clientGeneration,
  ) async {
    if (!_isActiveStream(generation, clientGeneration)) return;

    final segment = _segmentName(sourceUri);
    final stopwatch = Stopwatch()..start();
    debugPrint(
      '[DvrSegment] request generation=$generation client=$clientGeneration '
      'segment=$segment',
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
      '[DvrSegment] headers generation=$generation client=$clientGeneration '
      'segment=$segment ms=${stopwatch.elapsedMilliseconds} '
      'status=${upstream.statusCode}',
    );

    if (upstream.statusCode < 200 || upstream.statusCode >= 300) {
      await upstream.drain<void>();
      throw HttpException('DVR segment HTTP ${upstream.statusCode}');
    }

    var firstByteLogged = false;
    var bytes = 0;
    var bytesSinceFlush = 0;
    var lastFlushAt = DateTime.now();

    await for (final chunk in upstream) {
      if (!_isActiveStream(generation, clientGeneration)) return;

      bytes += chunk.length;
      bytesSinceFlush += chunk.length;
      if (!firstByteLogged) {
        firstByteLogged = true;
        debugPrint(
          '[DvrSegment] first-byte generation=$generation '
          'client=$clientGeneration segment=$segment '
          'ms=${stopwatch.elapsedMilliseconds}',
        );
      }

      response.add(chunk);
      final now = DateTime.now();
      if (bytesSinceFlush >= _flushByteThreshold ||
          now.difference(lastFlushAt) >= _flushTimeThreshold) {
        await response.flush().timeout(const Duration(seconds: 1));
        bytesSinceFlush = 0;
        lastFlushAt = now;
      }
    }

    if (bytesSinceFlush > 0 &&
        _isActiveStream(generation, clientGeneration)) {
      await response.flush().timeout(const Duration(seconds: 1));
    }

    debugPrint(
      '[DvrSegment] done generation=$generation client=$clientGeneration '
      'segment=$segment totalMs=${stopwatch.elapsedMilliseconds} bytes=$bytes',
    );
  }

  bool _isActiveStream(int generation, int clientGeneration) =>
      _server != null &&
      generation == _streamGeneration &&
      clientGeneration == _streamClientGeneration;

  Duration? _canonicalStartForSequence(
    List<TwitchHlsSegmentItem> items,
    int sequence,
  ) {
    final timeline = _latestTimelineIndex;
    if (timeline == null || timeline.isEmpty) return null;
    final index = items.indexWhere((item) => item.sequence == sequence);
    if (index < 0) return null;
    return timeline.entryAt(index)?.canonicalStart;
  }

  String _segmentName(Uri uri) =>
      uri.pathSegments.isEmpty ? uri.path : uri.pathSegments.last;

  void _applyStreamHeaders(HttpResponse response) {
    response.headers.set(HttpHeaders.serverHeader, 'VioClass-DVR');
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
    final duration = items.fold<Duration>(
      Duration.zero,
      (total, item) => total + item.duration,
    );
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
