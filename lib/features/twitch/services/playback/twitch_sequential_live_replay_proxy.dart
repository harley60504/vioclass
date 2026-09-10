import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/playback/twitch_hls_proxy_models.dart';
import '../../parsers/playback/twitch_hls_playlist_parser.dart';

/// Near-live TS replay source.
///
/// The caller supplies an exact behind-live duration. Each request fetches the
/// current Twitch media playlist, converts that delay to a canonical stream
/// position using EXT-X-TWITCH-TOTAL-SECS, resolves the matching segment using
/// EXT-X-TWITCH-ELAPSED-SECS + EXTINF, then emits sequence N, N+1, N+2...
/// without jumping into an unrelated live byte stream.
class TwitchSequentialLiveReplayProxy {
  final String upstreamPlaylistUrl;
  final Map<String, String> upstreamHeaders;
  final void Function(String message)? onLog;

  TwitchSequentialLiveReplayProxy({
    required this.upstreamPlaylistUrl,
    required this.upstreamHeaders,
    this.onLog,
  });

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..idleTimeout = const Duration(seconds: 12)
    ..maxConnectionsPerHost = 8
    ..autoUncompress = false;

  HttpServer? _server;

  bool get isRunning => _server != null;

  String streamUrl({required Duration fromLive}) {
    final server = _server;
    if (server == null) {
      throw StateError('Sequential live replay proxy has not started.');
    }
    final fromLiveUs = fromLive.inMicroseconds.clamp(
      1,
      const Duration(seconds: 20).inMicroseconds,
    );
    return 'http://127.0.0.1:${server.port}/stream.ts?fromLiveUs=$fromLiveUs';
  }

  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    unawaited(_serve(server));
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
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

      final rawUs = int.tryParse(
        request.uri.queryParameters['fromLiveUs'] ?? '',
      );
      final fromLive = Duration(
        microseconds: (rawUs ?? const Duration(seconds: 10).inMicroseconds)
            .clamp(1, const Duration(seconds: 20).inMicroseconds)
            .toInt(),
      );
      request.response.statusCode = HttpStatus.ok;
      request.response.bufferOutput = false;
      await _streamSequentialReplay(request.response, fromLive);
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
  ) async {
    var playlist = await _loadPlaylist();
    var items = _orderedItems(playlist);
    if (items.isEmpty) return;

    final total = _canonicalTotal(playlist, items);
    final targetUs = math.max(
      0,
      total.inMicroseconds - fromLive.inMicroseconds,
    );
    final target = Duration(microseconds: targetUs);
    final resolved = _resolveTarget(
      playlist: playlist,
      items: items,
      targetPosition: target,
    );
    var nextSequence = resolved.item.sequence;
    String? lastMapUrl;

    _log(
      'seek fromLive=${_seconds(fromLive)}s '
      'target=${_seconds(target)}s segment=$nextSequence '
      'segmentStart=${_seconds(resolved.segmentStart)}s '
      'intra=${resolved.intraSegment.inMilliseconds}ms '
      'clock=${resolved.usedTwitchElapsed ? 'twitch-total/elapsed' : 'tail-fallback'}',
    );

    while (_server != null) {
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
        playlist = await _loadPlaylistBestEffort(playlist);
        continue;
      }

      final mapUrl = item.mapUrl;
      if (mapUrl != null && mapUrl != lastMapUrl) {
        await _pipeUrlWithRetry(response, mapUrl, futureLike: false);
        lastMapUrl = mapUrl;
      }

      await _pipeUrlWithRetry(
        response,
        item.url,
        futureLike: item.isPrefetch,
      );
      nextSequence = item.sequence + 1;

      final hasNextInSnapshot = items.any(
        (candidate) => candidate.sequence == nextSequence,
      );
      if (!hasNextInSnapshot) {
        await Future<void>.delayed(const Duration(milliseconds: 70));
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
        );
      }
    }

    final fallback = items.first;
    return _ReplayTarget(
      item: fallback,
      segmentStart: Duration.zero,
      intraSegment: Duration.zero,
      usedTwitchElapsed: false,
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

  Future<void> _pipeUrl(HttpResponse output, String value) async {
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
    final line = '[LiveBufferReplay] $message';
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

  const _ReplayTarget({
    required this.item,
    required this.segmentStart,
    required this.intraSegment,
    required this.usedTwitchElapsed,
  });
}
