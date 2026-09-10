import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/playback/twitch_hls_proxy_models.dart';
import '../../parsers/playback/twitch_hls_playlist_parser.dart';

/// A small TS replay source used only for the near-live window.
///
/// It resolves a canonical Twitch stream position against
/// EXT-X-TWITCH-ELAPSED-SECS + EXTINF and then emits media segments strictly in
/// sequence order. Unlike the low-latency live byte bus, a replay request never
/// jumps from cached segment N to arbitrary live bytes: it follows N, N+1, ...
/// until the client closes or the router switches away.
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

  String streamUrl({required Duration targetPosition}) {
    final server = _server;
    if (server == null) {
      throw StateError('Sequential live replay proxy has not started.');
    }
    final targetUs = math.max(0, targetPosition.inMicroseconds);
    return 'http://127.0.0.1:${server.port}/stream.ts?targetUs=$targetUs';
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

      final targetUs = int.tryParse(request.uri.queryParameters['targetUs'] ?? '');
      final target = Duration(microseconds: math.max(0, targetUs ?? 0));
      request.response.statusCode = HttpStatus.ok;
      request.response.bufferOutput = false;
      await _streamSequentialReplay(request.response, target);
    } catch (error) {
      try {
        if (!request.response.headersSent) {
          request.response.statusCode = HttpStatus.internalServerError;
        }
        await request.response.close();
      } catch (_) {}
      _log('stream error: $error');
    }
  }

  Future<void> _streamSequentialReplay(
    HttpResponse response,
    Duration targetPosition,
  ) async {
    var playlist = await _loadPlaylist();
    var normalItems = _normalItems(playlist);
    if (normalItems.isEmpty) return;

    final resolved = _resolveTarget(
      playlist: playlist,
      normalItems: normalItems,
      targetPosition: targetPosition,
    );
    var nextSequence = resolved.item.sequence;
    String? lastMapUrl;

    _log(
      'target=${_seconds(targetPosition)}s '
      'segment=$nextSequence segmentStart=${_seconds(resolved.segmentStart)}s '
      'intra=${resolved.intraSegment.inMilliseconds}ms '
      'clock=${resolved.usedTwitchElapsed ? 'twitch-elapsed' : 'tail-fallback'}',
    );

    while (_server != null) {
      normalItems = _normalItems(playlist);
      TwitchHlsSegmentItem? item;
      for (final candidate in normalItems) {
        if (candidate.sequence == nextSequence) {
          item = candidate;
          break;
        }
      }

      if (item == null) {
        if (normalItems.isNotEmpty && nextSequence < normalItems.first.sequence) {
          final previous = nextSequence;
          nextSequence = normalItems.first.sequence;
          _log(
            'sequence gap expected=$previous recovered=$nextSequence '
            'mediaSeq=${playlist.mediaSequence}',
          );
          continue;
        }

        await Future<void>.delayed(const Duration(milliseconds: 120));
        playlist = await _loadPlaylistBestEffort(playlist);
        continue;
      }

      final mapUrl = item.mapUrl;
      if (mapUrl != null && mapUrl != lastMapUrl) {
        await _pipeUrl(response, mapUrl);
        lastMapUrl = mapUrl;
      }

      await _pipeUrl(response, item.url);
      nextSequence = item.sequence + 1;

      final hasNextInSnapshot = normalItems.any(
        (candidate) => candidate.sequence == nextSequence,
      );
      if (!hasNextInSnapshot) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        playlist = await _loadPlaylistBestEffort(playlist);
      }
    }
  }

  _ReplayTarget _resolveTarget({
    required TwitchParsedMediaPlaylist playlist,
    required List<TwitchHlsSegmentItem> normalItems,
    required Duration targetPosition,
  }) {
    final elapsed = playlist.twitchElapsed;
    if (elapsed != null) {
      var start = elapsed;
      for (var index = 0; index < normalItems.length; index++) {
        final item = normalItems[index];
        final end = start + item.duration;
        final isLast = index == normalItems.length - 1;
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

    final total = playlist.twitchTotal;
    if (total != null) {
      final fromLiveUs = math.max(
        0,
        total.inMicroseconds - targetPosition.inMicroseconds,
      );
      var behindUs = 0;
      for (var index = normalItems.length - 1; index >= 0; index--) {
        behindUs += normalItems[index].duration.inMicroseconds;
        if (behindUs >= fromLiveUs || index == 0) {
          final item = normalItems[index];
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
    }

    final fallback = normalItems.first;
    return _ReplayTarget(
      item: fallback,
      segmentStart: Duration.zero,
      intraSegment: Duration.zero,
      usedTwitchElapsed: false,
    );
  }

  List<TwitchHlsSegmentItem> _normalItems(TwitchParsedMediaPlaylist playlist) {
    final items = playlist.items.where((item) => !item.isPrefetch).toList();
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
    final text = await response.transform(const SystemEncoding().decoder).join();
    return TwitchHlsPlaylistParser.parse(
      text,
      playlistUrl: upstreamPlaylistUrl,
    );
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
