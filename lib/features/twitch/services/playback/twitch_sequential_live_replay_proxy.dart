import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../models/playback/twitch_hls_proxy_models.dart';
import '../../models/playback/twitch_segment_timeline_index.dart';
import '../../parsers/playback/twitch_hls_playlist_parser.dart';
import '../../parsers/playback/twitch_ts_timing_parser.dart';
import 'twitch_canonical_playback_clock_registry.dart';

/// Near-live TS replay source.
///
/// The main playback path supplies one exact canonical stream position. Each
/// request fetches the current Twitch media playlist only to resolve that fixed
/// position to a segment plus an intra-segment offset; a newer live edge never
/// changes an already-selected seek target. The legacy behind-live entry point
/// remains available for diagnostics. MPEG-TS PTS/PCR/keyframes are indexed
/// while bytes are already being streamed, so media-clock enrichment never
/// blocks replay startup.
class TwitchSequentialLiveReplayProxy {
  final String upstreamPlaylistUrl;
  final Map<String, String> upstreamHeaders;
  final void Function(String message)? onLog;

  TwitchSequentialLiveReplayProxy({
    required this.upstreamPlaylistUrl,
    required this.upstreamHeaders,
    this.onLog,
  });

  static const bool _verboseReplayDebug = false;
  static const int _maxTimingCacheEntries = 48;

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..idleTimeout = const Duration(seconds: 12)
    ..maxConnectionsPerHost = 8
    ..autoUncompress = false;

  final Map<String, TwitchTsTimingInfo> _timingCache =
      <String, TwitchTsTimingInfo>{};

  HttpServer? _server;
  int _seekGeneration = 0;
  int? _publishedAnchorGeneration;

  bool get isRunning => _server != null;

  /// Legacy relative entry point retained for diagnostics only.
  String streamUrl({required Duration fromLive}) {
    final fromLiveUs = fromLive.inMicroseconds.clamp(
      1,
      const Duration(seconds: 20).inMicroseconds,
    );
    return _buildStreamUrl(fromLiveUs: fromLiveUs.toInt());
  }

  /// Playback entry point. [canonicalTarget] is immutable for this generation.
  String streamUrlForCanonicalTarget({required Duration canonicalTarget}) {
    final targetUs = math.max(0, canonicalTarget.inMicroseconds).toInt();
    return _buildStreamUrl(canonicalTargetUs: targetUs);
  }

  String _buildStreamUrl({int? fromLiveUs, int? canonicalTargetUs}) {
    final server = _server;
    if (server == null) {
      throw StateError('Sequential live replay proxy has not started.');
    }
    if (fromLiveUs == null && canonicalTargetUs == null) {
      throw ArgumentError('A replay target is required.');
    }

    final generation = ++_seekGeneration;
    _publishedAnchorGeneration = null;

    // A new absolute timeline seek immediately invalidates every older replay
    // request. Keep the registry empty until this generation resolves its own
    // segment so an old segment anchor cannot be rebound during the switch.
    TwitchCanonicalPlaybackClockRegistry.clearLocalReplayAnchor();

    final targetQuery = canonicalTargetUs != null
        ? 'canonicalTargetUs=$canonicalTargetUs'
        : 'fromLiveUs=$fromLiveUs';
    return 'http://127.0.0.1:${server.port}/stream.ts'
        '?$targetQuery&generation=$generation';
  }

  Future<void> start() async {
    if (_server != null) return;
    TwitchCanonicalPlaybackClockRegistry.clearLocalReplayAnchor();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    unawaited(_serve(server));
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    _seekGeneration++;
    _publishedAnchorGeneration = null;
    _timingCache.clear();
    TwitchCanonicalPlaybackClockRegistry.clearLocalReplayAnchor();
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
      if (request.uri.path != '/stream.ts') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      _applyStreamHeaders(request.response);
      if (request.method == 'HEAD') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      final rawFromLiveUs = int.tryParse(
        request.uri.queryParameters['fromLiveUs'] ?? '',
      );
      final rawCanonicalTargetUs = int.tryParse(
        request.uri.queryParameters['canonicalTargetUs'] ?? '',
      );
      final generation = int.tryParse(
            request.uri.queryParameters['generation'] ?? '',
          ) ??
          _seekGeneration;
      if (generation != _seekGeneration) {
        request.response.statusCode = HttpStatus.gone;
        await request.response.close();
        return;
      }

      final fromLive = Duration(
        microseconds:
            (rawFromLiveUs ?? const Duration(seconds: 10).inMicroseconds)
                .clamp(1, const Duration(seconds: 20).inMicroseconds)
                .toInt(),
      );
      final canonicalTarget = rawCanonicalTargetUs == null
          ? null
          : Duration(microseconds: math.max(0, rawCanonicalTargetUs).toInt());
      request.response.statusCode = HttpStatus.ok;
      request.response.bufferOutput = false;
      await _streamSequentialReplay(
        request.response,
        fromLive,
        generation,
        canonicalTarget: canonicalTarget,
      );
      try {
        await request.response.close();
      } catch (_) {}
    } catch (error) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
      } catch (_) {}
      try {
        await request.response.close();
      } catch (_) {}
      _log('stream error: $error');
    }
  }

  Future<void> _streamSequentialReplay(
    HttpResponse response,
    Duration fromLive,
    int generation, {
    Duration? canonicalTarget,
  }) async {
    var playlist = await _loadPlaylist();
    if (generation != _seekGeneration || _server == null) return;

    var items = _orderedItems(playlist);
    if (items.isEmpty) return;

    final total = _canonicalTotal(playlist, items);
    final target =
        canonicalTarget ??
        Duration(
          microseconds: math.max(
            0,
            total.inMicroseconds - fromLive.inMicroseconds,
          ).toInt(),
        );
    final resolved = _resolveTargetWithCanonicalIndex(
      playlist: playlist,
      items: items,
      targetPosition: target,
    );
    if (generation != _seekGeneration || _server == null) return;

    var nextSequence = resolved.item.sequence;
    String? lastMapUrl;
    final targetSequence = resolved.item.sequence;

    if (_publishedAnchorGeneration != generation) {
      TwitchCanonicalPlaybackClockRegistry.setLocalReplayAnchor(
        canonicalStart: resolved.segmentStart,
        intraSegment: resolved.intraSegment,
        sequence: targetSequence,
      );
      _publishedAnchorGeneration = generation;
      _log(
        '[CanonicalPlaybackClock][LOCAL] '
        'generation=$generation '
        'segment=$targetSequence '
        'canonicalStart=${_seconds(resolved.segmentStart)}s '
        'requested=${_seconds(target)}s '
        'intra=${_seconds(resolved.intraSegment)}s',
      );
    }

    _log(
      'seek generation=$generation '
      'source=${canonicalTarget == null ? 'from-live' : 'canonical-target'} '
      'fromLive=${_seconds(fromLive)}s '
      'target=${_seconds(target)}s segment=$nextSequence '
      'segmentStart=${_seconds(resolved.segmentStart)}s '
      'intra=${_seconds(resolved.intraSegment)}s '
      'clock=${resolved.usedCanonicalIndex ? 'segment-index' : resolved.usedTwitchElapsed ? 'twitch-total/elapsed' : 'tail-fallback'}',
    );

    while (_server != null && generation == _seekGeneration) {
      items = _orderedItems(playlist);
      TwitchHlsSegmentItem? item;
      for (final candidate in items) {
        if (candidate.sequence == nextSequence) {
          item = candidate;
          break;
        }
      }

      if (item == null) {
        if (items.isNotEmpty && nextSequence < items.first.sequence) {
          final previous = nextSequence;
          nextSequence = items.first.sequence;
          _log(
            'sequence discontinuity expected=$previous recovered=$nextSequence '
            'mediaSeq=${playlist.mediaSequence}',
          );
          continue;
        }

        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (generation != _seekGeneration || _server == null) return;
        playlist = await _loadPlaylistBestEffort(playlist);
        continue;
      }

      if (generation != _seekGeneration) return;
      final mapUrl = item.mapUrl;
      if (mapUrl != null && mapUrl != lastMapUrl) {
        await _pipeUrlWithRetry(response, mapUrl, futureLike: false);
        if (generation != _seekGeneration) return;
        lastMapUrl = mapUrl;
      }

      await _pipeItemWithTiming(
        output: response,
        item: item,
        targetOffset: item.sequence == targetSequence
            ? resolved.intraSegment
            : null,
      );
      if (generation != _seekGeneration) return;
      nextSequence = item.sequence + 1;

      final hasNextInSnapshot = items.any(
        (candidate) => candidate.sequence == nextSequence,
      );
      if (!hasNextInSnapshot) {
        await Future<void>.delayed(const Duration(milliseconds: 70));
        if (generation != _seekGeneration || _server == null) return;
        playlist = await _loadPlaylistBestEffort(playlist);
      }
    }
  }

  Duration _canonicalTotal(
    TwitchParsedMediaPlaylist playlist,
    List<TwitchHlsSegmentItem> items,
  ) {
    final twitchTotal = playlist.twitchTotal;
    if (twitchTotal != null) return twitchTotal;

    final elapsed = playlist.twitchElapsed ?? Duration.zero;
    var window = Duration.zero;
    for (final item in items) {
      window += item.duration;
    }
    return elapsed + window;
  }

  _ReplayTarget _resolveTargetWithCanonicalIndex({
    required TwitchParsedMediaPlaylist playlist,
    required List<TwitchHlsSegmentItem> items,
    required Duration targetPosition,
  }) {
    final normalItems = items
        .where((item) => !item.isPrefetch)
        .toList(growable: false);
    final elapsed = playlist.twitchElapsed;
    if (normalItems.isNotEmpty && elapsed != null) {
      final timeline = TwitchSegmentTimelineIndex.fromSegments(
        normalItems,
        canonicalStart: elapsed,
        timelineOrigin: playlist.timelineOrigin,
        twitchElapsed: playlist.twitchElapsed,
        twitchTotal: playlist.twitchTotal,
      );
      if (targetPosition >= timeline.canonicalStart &&
          targetPosition < timeline.canonicalEnd) {
        final seek = timeline.resolveCanonical(targetPosition);
        if (seek != null) {
          _log(
            '[SegmentTimelineIndex][LOCAL] target=${_seconds(targetPosition)}s '
            'resolved=${_seconds(seek.canonicalPosition)}s '
            'sequence=${seek.sequence} index=${seek.index} '
            'offset=${_seconds(seek.offset)}s '
            'window=${_seconds(timeline.indexedDuration)}s',
          );
          return _ReplayTarget(
            item: seek.entry.item,
            segmentStart: seek.entry.canonicalStart,
            intraSegment: seek.offset,
            usedTwitchElapsed: true,
            usedCanonicalIndex: true,
          );
        }
      }
    }

    return _resolveTarget(
      playlist: playlist,
      items: items,
      targetPosition: targetPosition,
    );
  }

  _ReplayTarget _resolveTarget({
    required TwitchParsedMediaPlaylist playlist,
    required List<TwitchHlsSegmentItem> items,
    required Duration targetPosition,
  }) {
    final elapsed = playlist.twitchElapsed;
    if (elapsed != null) {
      var start = elapsed;
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final end = start + item.duration;
        final isLast = index == items.length - 1;
        if (targetPosition < end || isLast) {
          final intraUs = targetPosition.inMicroseconds - start.inMicroseconds;
          final maxUs = math.max(item.duration.inMicroseconds - 1, 0);
          return _ReplayTarget(
            item: item,
            segmentStart: start,
            intraSegment: Duration(
              microseconds: intraUs.clamp(0, maxUs).toInt(),
            ),
            usedTwitchElapsed: true,
            usedCanonicalIndex: false,
          );
        }
        start = end;
      }
    }

    final total = _canonicalTotal(playlist, items);
    final fromTailUs = math.max(
      0,
      total.inMicroseconds - targetPosition.inMicroseconds,
    );
    var behindUs = 0;
    for (var index = items.length - 1; index >= 0; index--) {
      behindUs += items[index].duration.inMicroseconds;
      if (behindUs >= fromTailUs || index == 0) {
        final item = items[index];
        final start = total - Duration(microseconds: behindUs);
        final intraUs = targetPosition.inMicroseconds - start.inMicroseconds;
        final maxUs = math.max(item.duration.inMicroseconds - 1, 0);
        return _ReplayTarget(
          item: item,
          segmentStart: start,
          intraSegment: Duration(
            microseconds: intraUs.clamp(0, maxUs).toInt(),
          ),
          usedTwitchElapsed: false,
          usedCanonicalIndex: false,
        );
      }
    }

    final fallback = items.first;
    return _ReplayTarget(
      item: fallback,
      segmentStart: Duration.zero,
      intraSegment: Duration.zero,
      usedTwitchElapsed: false,
      usedCanonicalIndex: false,
    );
  }

  List<TwitchHlsSegmentItem> _orderedItems(TwitchParsedMediaPlaylist playlist) {
    final bySequence = <int, TwitchHlsSegmentItem>{};
    for (final item in playlist.items) {
      bySequence[item.sequence] = item;
    }
    final items = bySequence.values.toList();
    items.sort((a, b) => a.sequence.compareTo(b.sequence));
    return items;
  }

  Future<TwitchParsedMediaPlaylist> _loadPlaylistBestEffort(
    TwitchParsedMediaPlaylist previous,
  ) async {
    try {
      return await _loadPlaylist();
    } catch (_) {
      return previous;
    }
  }

  Future<TwitchParsedMediaPlaylist> _loadPlaylist() async {
    final request = await _client.getUrl(Uri.parse(upstreamPlaylistUrl));
    request.followRedirects = true;
    request.maxRedirects = 5;
    for (final entry in upstreamHeaders.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty) continue;
      if (key.toLowerCase() == HttpHeaders.hostHeader) continue;
      request.headers.set(key, value);
    }
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    request.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');

    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw HttpException('HLS playlist HTTP ${response.statusCode}');
    }
    final text = await response.transform(utf8.decoder).join();
    return TwitchHlsPlaylistParser.parse(
      text,
      playlistUrl: upstreamPlaylistUrl,
    );
  }

  Future<void> _pipeItemWithTiming({
    required HttpResponse output,
    required TwitchHlsSegmentItem item,
    Duration? targetOffset,
  }) async {
    if (item.isPrefetch) {
      await _pipeUrlWithRetry(output, item.url, futureLike: true);
      return;
    }

    final cached = _timingCache[item.url];
    if (cached != null) {
      if (targetOffset != null) {
        _logTiming(item, cached, targetOffset);
      }
      await _pipeUrlWithRetry(output, item.url, futureLike: false);
      return;
    }

    final attempts = 4;
    Object? lastError;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final bytes = BytesBuilder(copy: false);
        await _pipeUrl(
          output,
          item.url,
          capture: bytes,
        );
        final timing = TwitchTsTimingParser.parse(bytes.takeBytes());
        if (timing.hasMediaClock) {
          _rememberTiming(item.url, timing);
          _logTiming(item, timing, targetOffset);
        }
        return;
      } catch (error) {
        lastError = error;
        if (attempt >= attempts || _server == null) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: math.min(40 + attempt * 20, 240)),
        );
      }
    }
    throw lastError ?? StateError('segment retry failed');
  }

  void _rememberTiming(String url, TwitchTsTimingInfo timing) {
    _timingCache.remove(url);
    _timingCache[url] = timing;
    while (_timingCache.length > _maxTimingCacheEntries) {
      _timingCache.remove(_timingCache.keys.first);
    }
  }

  void _logTiming(
    TwitchHlsSegmentItem item,
    TwitchTsTimingInfo timing,
    Duration? targetOffset,
  ) {
    final keyframeOffset = targetOffset == null
        ? null
        : timing.keyframeOffsetAtOrBefore(targetOffset);
    final decodeLead = targetOffset == null || keyframeOffset == null
        ? null
        : targetOffset - keyframeOffset;
    _log(
      '[TsMediaIndex][LOCAL] sequence=${item.sequence} '
      'firstPts=${timing.firstPts90k ?? -1} '
      'lastPts=${timing.lastPts90k ?? -1} '
      'firstPcr=${timing.firstPcr27m ?? -1} '
      'lastPcr=${timing.lastPcr27m ?? -1} '
      'keyframes=${timing.keyframePts90k.length} '
      'targetOffset=${targetOffset == null ? '-' : '${_seconds(targetOffset)}s'} '
      'keyframeOffset=${keyframeOffset == null ? '-' : '${_seconds(keyframeOffset)}s'} '
      'decodeLead=${decodeLead == null ? '-' : '${_seconds(decodeLead)}s'} '
      'transport=continuous-ts',
    );
  }

  Future<void> _pipeUrlWithRetry(
    HttpResponse output,
    String value, {
    required bool futureLike,
  }) async {
    final attempts = futureLike ? 16 : 4;
    Object? lastError;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        await _pipeUrl(output, value);
        return;
      } catch (error) {
        lastError = error;
        if (attempt >= attempts || _server == null) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: math.min(40 + attempt * 20, 240)),
        );
      }
    }
    throw lastError ?? StateError('segment retry failed');
  }

  Future<void> _pipeUrl(
    HttpResponse output,
    String value, {
    BytesBuilder? capture,
  }) async {
    final request = await _client.getUrl(Uri.parse(value));
    request.followRedirects = true;
    request.maxRedirects = 5;
    for (final entry in upstreamHeaders.entries) {
      final key = entry.key.trim();
      final headerValue = entry.value.trim();
      if (key.isEmpty || headerValue.isEmpty) continue;
      if (key.toLowerCase() == HttpHeaders.hostHeader) continue;
      request.headers.set(key, headerValue);
    }
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');

    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw HttpException('segment HTTP ${response.statusCode}');
    }

    var firstChunk = true;
    var bytesSinceFlush = 0;
    var lastFlushAt = DateTime.now();
    await for (final chunk in response) {
      capture?.add(chunk);
      output.add(chunk);
      bytesSinceFlush += chunk.length;
      final now = DateTime.now();
      if (firstChunk ||
          bytesSinceFlush >= 16 * 1024 ||
          now.difference(lastFlushAt) >= const Duration(milliseconds: 15)) {
        await output.flush().timeout(const Duration(seconds: 1));
        firstChunk = false;
        bytesSinceFlush = 0;
        lastFlushAt = now;
      }
    }
    if (bytesSinceFlush > 0) {
      await output.flush().timeout(const Duration(seconds: 1));
    }
  }

  void _applyStreamHeaders(HttpResponse response) {
    response.headers.set(HttpHeaders.serverHeader, 'VioClass-Replay');
    response.headers.contentType = ContentType('video', 'mp2t');
    response.headers.chunkedTransferEncoding = true;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
  }

  String _seconds(Duration value) =>
      (value.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(3);

  void _log(String message) {
    if (!kDebugMode) return;
    if (!_verboseReplayDebug && !message.startsWith('stream error:')) return;
    final line = message.startsWith('[')
        ? message
        : '[LiveBufferReplay] $message';
    final logger = onLog;
    if (logger != null) {
      logger(line);
    } else {
      debugPrint(line);
    }
  }
}

class _ReplayTarget {
  final TwitchHlsSegmentItem item;
  final Duration segmentStart;
  final Duration intraSegment;
  final bool usedTwitchElapsed;
  final bool usedCanonicalIndex;

  const _ReplayTarget({
    required this.item,
    required this.segmentStart,
    required this.intraSegment,
    required this.usedTwitchElapsed,
    required this.usedCanonicalIndex,
  });
}