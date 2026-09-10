import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../parsers/playback/twitch_ts_timing_parser.dart';

class TwitchLocalDvrMediaTimingProbeResult {
  final int segmentIndex;
  final Duration segmentStart;
  final Duration targetOffset;
  final Duration? keyframeOffset;
  final Duration? decodeLead;
  final Duration suggestedDemuxerOffset;
  final TwitchTsTimingInfo timing;

  const TwitchLocalDvrMediaTimingProbeResult({
    required this.segmentIndex,
    required this.segmentStart,
    required this.targetOffset,
    required this.keyframeOffset,
    required this.decodeLead,
    required this.suggestedDemuxerOffset,
    required this.timing,
  });
}

/// Reads the finite local DVR snapshot produced by the DVR bridge, resolves the
/// requested player time to one TS segment, then inspects that segment's
/// MPEG-TS media clock.
///
/// The probe is deliberately best-effort. Playback never depends on it: any
/// timeout, malformed TS, missing PAT/PMT, or unsupported codec returns null.
class TwitchLocalDvrMediaTimingProbe {
  TwitchLocalDvrMediaTimingProbe._();

  static const Duration _requestTimeout = Duration(milliseconds: 1400);
  static const Duration _minimumBackoff = Duration(seconds: 2);
  static const Duration _maximumBackoff = Duration(seconds: 12);
  static const int _maxSegmentBytes = 24 * 1024 * 1024;
  static const int _maxCacheEntries = 64;
  static final Map<String, TwitchTsTimingInfo> _timingCache =
      <String, TwitchTsTimingInfo>{};

  // This is intentionally process-wide. Twitch normally keeps a stable GOP
  // cadence for one rendition. A completed probe teaches later seeks how far
  // mpv should ask the demuxer to look backwards, without blocking the next
  // player.open on another network probe.
  static Duration _learnedDemuxerOffset = _minimumBackoff;

  static Duration get cachedSuggestedDemuxerOffset =>
      _learnedDemuxerOffset;

  static Future<TwitchLocalDvrMediaTimingProbeResult?> probe({
    required String playlistUrl,
    required Duration startPosition,
  }) async {
    try {
      final playlistUri = Uri.parse(playlistUrl);
      final playlistText = await _getText(playlistUri);
      if (!playlistText.contains('#EXTM3U') ||
          !playlistText.contains('#EXT-X-ENDLIST')) {
        return null;
      }

      final segments = _parseSnapshotSegments(playlistText, playlistUri);
      if (segments.isEmpty) return null;

      final safeTarget = startPosition < Duration.zero
          ? Duration.zero
          : startPosition;
      var cursor = Duration.zero;
      var targetIndex = segments.length - 1;
      for (var i = 0; i < segments.length; i++) {
        final end = cursor + segments[i].duration;
        if (safeTarget < end) {
          targetIndex = i;
          break;
        }
        cursor = end;
      }

      final targetSegment = segments[targetIndex];
      final targetOffsetUs = (safeTarget - cursor).inMicroseconds
          .clamp(0, math.max(targetSegment.duration.inMicroseconds - 1, 0))
          .toInt();
      final targetOffset = Duration(microseconds: targetOffsetUs);

      final cacheKey =
          targetSegment.uri.queryParameters['u'] ?? targetSegment.uri.toString();
      var timing = _timingCache.remove(cacheKey);
      if (timing != null) {
        // Reinsertion keeps the simple insertion-ordered map acting as an LRU.
        _timingCache[cacheKey] = timing;
      } else {
        final bytes = await _getBytes(targetSegment.uri);
        if (bytes == null || bytes.isEmpty) return null;
        timing = TwitchTsTimingParser.parse(bytes);
        if (!timing.hasMediaClock) return null;
        _timingCache[cacheKey] = timing;
        while (_timingCache.length > _maxCacheEntries) {
          _timingCache.remove(_timingCache.keys.first);
        }
      }

      final keyframeOffset = timing.keyframeOffsetAtOrBefore(targetOffset);
      final decodeLead = keyframeOffset == null
          ? null
          : targetOffset - keyframeOffset;
      final desiredBackoff = decodeLead == null
          ? _minimumBackoff
          : decodeLead + const Duration(milliseconds: 500);
      final suggestedBackoff = Duration(
        milliseconds: desiredBackoff.inMilliseconds
            .clamp(
              _minimumBackoff.inMilliseconds,
              _maximumBackoff.inMilliseconds,
            )
            .toInt(),
      );

      // Never reduce the learned safety margin during the process lifetime.
      // One longer GOP is enough reason for later seeks to keep the larger
      // demuxer backoff; the cap prevents pathological metadata from growing it
      // without bound.
      if (suggestedBackoff > _learnedDemuxerOffset) {
        _learnedDemuxerOffset = suggestedBackoff;
      }

      return TwitchLocalDvrMediaTimingProbeResult(
        segmentIndex: targetIndex,
        segmentStart: cursor,
        targetOffset: targetOffset,
        keyframeOffset: keyframeOffset,
        decodeLead: decodeLead,
        suggestedDemuxerOffset: suggestedBackoff,
        timing: timing,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String> _getText(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = _requestTimeout
      ..idleTimeout = _requestTimeout;
    try {
      final request = await client.getUrl(uri).timeout(_requestTimeout);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode >= 400) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      return await utf8.decoder.bind(response).join().timeout(_requestTimeout);
    } finally {
      client.close(force: true);
    }
  }

  static Future<Uint8List?> _getBytes(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = _requestTimeout
      ..idleTimeout = _requestTimeout;
    try {
      final request = await client.getUrl(uri).timeout(_requestTimeout);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode >= 400) return null;

      final builder = BytesBuilder(copy: false);
      var total = 0;
      await for (final chunk in response.timeout(_requestTimeout)) {
        total += chunk.length;
        if (total > _maxSegmentBytes) return null;
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  static List<_SnapshotSegment> _parseSnapshotSegments(
    String text,
    Uri playlistUri,
  ) {
    final result = <_SnapshotSegment>[];
    Duration? pendingDuration;
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF:')) {
        final rawDuration = line
            .substring('#EXTINF:'.length)
            .split(',')
            .first
            .trim();
        final seconds = double.tryParse(rawDuration);
        if (seconds != null && seconds > 0 && seconds.isFinite) {
          pendingDuration = Duration(
            microseconds:
                (seconds * Duration.microsecondsPerSecond).round(),
          );
        }
        continue;
      }
      if (line.startsWith('#')) continue;
      final duration = pendingDuration;
      if (duration == null) continue;
      result.add(
        _SnapshotSegment(
          uri: playlistUri.resolve(line),
          duration: duration,
        ),
      );
      pendingDuration = null;
    }
    return result;
  }
}

class _SnapshotSegment {
  final Uri uri;
  final Duration duration;

  const _SnapshotSegment({required this.uri, required this.duration});
}
