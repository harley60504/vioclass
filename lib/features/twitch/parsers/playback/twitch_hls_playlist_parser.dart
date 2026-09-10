import 'package:flutter/foundation.dart';

import '../../models/playback/twitch_hls_proxy_models.dart';

class TwitchHlsPlaylistParser {
  const TwitchHlsPlaylistParser._();

  static const Duration _timingDebugInterval = Duration(seconds: 10);
  static final Map<String, DateTime> _lastTimingDebugAt = <String, DateTime>{};
  static final Map<String, String> _lastTimingCapabilitySignature =
      <String, String>{};

  static TwitchParsedMediaPlaylist parse(
    String playlistText, {
    required String playlistUrl,
  }) {
    final base = Uri.parse(playlistUrl);
    final items = <TwitchHlsSegmentItem>[];
    final seenUrls = <String>{};

    String? currentMapUrl;
    String? pendingLabel;
    DateTime? nextProgramDateTime;
    var pendingDuration = const Duration(seconds: 2);
    var lastSegmentDuration = const Duration(seconds: 2);
    var targetDuration = const Duration(seconds: 2);
    var hasFutureSegment = false;
    var hasEndList = false;
    var mediaSequence = 0;
    var segmentIndex = 0;

    final lines = playlistText.split(RegExp(r'\r?\n'));

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
        mediaSequence =
            int.tryParse(
              line.substring('#EXT-X-MEDIA-SEQUENCE:'.length).trim(),
            ) ??
            mediaSequence;
        segmentIndex = 0;
        continue;
      }

      if (line.startsWith('#EXT-X-TARGETDURATION:')) {
        final seconds = double.tryParse(
          line.substring('#EXT-X-TARGETDURATION:'.length).trim(),
        );
        if (seconds != null && seconds > 0) {
          final nextTargetMilliseconds = (seconds * 1000).round();
          targetDuration = Duration(
            milliseconds: nextTargetMilliseconds > 250
                ? nextTargetMilliseconds
                : 250,
          );
          pendingDuration = targetDuration;
        }
        continue;
      }

      if (line.startsWith('#EXT-X-PART-INF:')) {
        final partTarget = _parseM3u8AttributeDouble(line, 'PART-TARGET');
        if (partTarget != null && partTarget > 0) {
          final nextPartTargetMilliseconds = (partTarget * 1000).round();
          targetDuration = Duration(
            milliseconds: nextPartTargetMilliseconds > 120
                ? nextPartTargetMilliseconds
                : 120,
          );
        }
        continue;
      }

      if (line == '#EXT-X-ENDLIST') {
        hasEndList = true;
        continue;
      }

      if (line.startsWith('#EXT-X-PROGRAM-DATE-TIME:')) {
        final raw = line.substring('#EXT-X-PROGRAM-DATE-TIME:'.length).trim();
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) {
          nextProgramDateTime = parsed.toUtc();
        }
        continue;
      }

      if (line.startsWith('#EXT-X-MAP:')) {
        final mapUri = _parseQuotedUriAttribute(line);
        if (mapUri != null && mapUri.isNotEmpty) {
          currentMapUrl = base.resolve(mapUri).toString();
        }
        continue;
      }

      if (line.startsWith('#EXTINF:')) {
        final durationText = line
            .substring('#EXTINF:'.length)
            .split(',')
            .first
            .trim();
        final durationSeconds = double.tryParse(durationText);
        if (durationSeconds != null && durationSeconds > 0) {
          final nextPendingMilliseconds = (durationSeconds * 1000).round();
          pendingDuration = Duration(
            milliseconds: nextPendingMilliseconds > 100
                ? nextPendingMilliseconds
                : 100,
          );
        }
        pendingLabel = line;
        continue;
      }

      if (line.startsWith('#EXT-X-PART:')) {
        continue;
      }

      if (line.startsWith('#EXT-X-TWITCH-PREFETCH:')) {
        hasFutureSegment = true;
        final rawUrl = line.substring('#EXT-X-TWITCH-PREFETCH:'.length).trim();
        if (rawUrl.isNotEmpty) {
          final absoluteUrl = base.resolve(rawUrl).toString();
          if (seenUrls.add(absoluteUrl)) {
            items.add(
              TwitchHlsSegmentItem(
                url: absoluteUrl,
                mapUrl: currentMapUrl,
                label:
                    "TWITCH-PREFETCH ${_lastPathSegment(absoluteUrl, fallback: 'future')}",
                sequence: mediaSequence + segmentIndex,
                isPrefetch: true,
                duration: _durationForFutureSegment(
                  lastSegmentDuration,
                  targetDuration,
                ),
              ),
            );
            segmentIndex++;
          }
        }
        continue;
      }

      if (line.startsWith('#EXT-X-PREFETCH:')) {
        hasFutureSegment = true;
        final rawUrl = line.substring('#EXT-X-PREFETCH:'.length).trim();
        if (rawUrl.isNotEmpty) {
          final absoluteUrl = base.resolve(rawUrl).toString();
          if (seenUrls.add(absoluteUrl)) {
            items.add(
              TwitchHlsSegmentItem(
                url: absoluteUrl,
                mapUrl: currentMapUrl,
                label:
                    "PREFETCH ${_lastPathSegment(absoluteUrl, fallback: 'future')}",
                sequence: mediaSequence + segmentIndex,
                isPrefetch: true,
                duration: _durationForFutureSegment(
                  lastSegmentDuration,
                  targetDuration,
                ),
              ),
            );
            segmentIndex++;
          }
        }
        continue;
      }

      if (line.startsWith('#EXT-X-PRELOAD-HINT')) {
        final hintType = _parseM3u8AttributeString(line, 'TYPE');
        final hintUri = _parseM3u8AttributeString(line, 'URI');
        if (hintUri != null &&
            hintUri.isNotEmpty &&
            (hintType == null || hintType.toUpperCase() == 'SEGMENT')) {
          hasFutureSegment = true;
          final absoluteUrl = base.resolve(hintUri).toString();
          if (seenUrls.add(absoluteUrl)) {
            items.add(
              TwitchHlsSegmentItem(
                url: absoluteUrl,
                mapUrl: currentMapUrl,
                label:
                    "PRELOAD-HINT ${_lastPathSegment(absoluteUrl, fallback: 'future')}",
                sequence: mediaSequence + segmentIndex,
                isPrefetch: true,
                duration: _durationForFutureSegment(
                  lastSegmentDuration,
                  targetDuration,
                ),
              ),
            );
            segmentIndex++;
          }
        }
        continue;
      }

      if (line.startsWith('#')) {
        continue;
      }

      final absoluteUrl = base.resolve(line).toString();
      if (seenUrls.add(absoluteUrl)) {
        final programDateTime = nextProgramDateTime;
        items.add(
          TwitchHlsSegmentItem(
            url: absoluteUrl,
            mapUrl: currentMapUrl,
            label:
                pendingLabel ??
                _lastPathSegment(absoluteUrl, fallback: 'segment'),
            sequence: mediaSequence + segmentIndex,
            isPrefetch: false,
            duration: pendingDuration,
            programDateTime: programDateTime,
          ),
        );
        if (programDateTime != null) {
          nextProgramDateTime = programDateTime.add(pendingDuration);
        }
        lastSegmentDuration = pendingDuration;
        segmentIndex++;
      }
      pendingLabel = null;
      pendingDuration = targetDuration;
    }

    final normalCount = items.where((item) => !item.isPrefetch).length;
    final futureCount = items.length - normalCount;
    final reloadDelay = hasEndList
        ? Duration.zero
        : hasFutureSegment
        ? const Duration(milliseconds: 160)
        : _halfDuration(targetDuration);
    final normalItems = items
        .where((item) => !item.isPrefetch)
        .toList(growable: false);
    final twitchElapsed = _parseTwitchDuration(
      lines,
      '#EXT-X-TWITCH-ELAPSED-SECS:',
    );
    final twitchTotal = _parseTwitchDuration(
      lines,
      '#EXT-X-TWITCH-TOTAL-SECS:',
    );
    final firstProgramDateTime = normalItems
        .map((item) => item.programDateTime)
        .whereType<DateTime>()
        .firstOrNull;
    final timelineOrigin = firstProgramDateTime != null && twitchElapsed != null
        ? firstProgramDateTime.subtract(twitchElapsed)
        : null;
    final timingObservedAt = DateTime.now().toUtc();

    _debugTimingMetadata(
      lines: lines,
      playlistUrl: playlistUrl,
      items: items,
      mediaSequence: mediaSequence,
      targetDuration: targetDuration,
    );

    return TwitchParsedMediaPlaylist(
      items: items,
      reloadDelay: reloadDelay,
      normalCount: normalCount,
      futureCount: futureCount,
      mediaSequence: mediaSequence,
      targetDuration: targetDuration,
      hasEndList: hasEndList,
      twitchElapsed: twitchElapsed,
      twitchTotal: twitchTotal,
      timelineOrigin: timelineOrigin,
      timingObservedAt: timingObservedAt,
    );
  }

  static void _debugTimingMetadata({
    required List<String> lines,
    required String playlistUrl,
    required List<TwitchHlsSegmentItem> items,
    required int mediaSequence,
    required Duration targetDuration,
  }) {
    if (!kDebugMode) return;

    final lowerUrl = playlistUrl.toLowerCase();
    final kind = lowerUrl.contains('index-dvr.m3u8') ? 'DVR' : 'LIVE';
    final pdtLines = lines
        .map((line) => line.trim())
        .where((line) => line.startsWith('#EXT-X-PROGRAM-DATE-TIME:'))
        .toList(growable: false);
    final elapsedSecs = _firstTagValue(lines, '#EXT-X-TWITCH-ELAPSED-SECS:');
    final totalSecs = _firstTagValue(lines, '#EXT-X-TWITCH-TOTAL-SECS:');
    final extinfCount = lines
        .where((line) => line.trim().startsWith('#EXTINF:'))
        .length;
    final partCount = lines
        .where((line) => line.trim().startsWith('#EXT-X-PART:'))
        .length;
    final preloadCount = lines
        .where((line) => line.trim().startsWith('#EXT-X-PRELOAD-HINT:'))
        .length;
    final twitchPrefetchCount = lines
        .where((line) => line.trim().startsWith('#EXT-X-TWITCH-PREFETCH:'))
        .length;
    final normalItems = items
        .where((item) => !item.isPrefetch)
        .toList(growable: false);
    final durationMs = normalItems.fold<int>(
      0,
      (total, item) => total + item.duration.inMilliseconds,
    );
    final firstPdt = normalItems
        .map((item) => item.programDateTime)
        .whereType<DateTime>()
        .firstOrNull;
    final lastPdt = normalItems
        .map((item) => item.programDateTime)
        .whereType<DateTime>()
        .lastOrNull;

    final capabilitySignature = <Object?>[
      pdtLines.isNotEmpty,
      elapsedSecs != null,
      totalSecs != null,
      partCount > 0,
      preloadCount > 0,
      twitchPrefetchCount > 0,
    ].join('|');
    final now = DateTime.now();
    final lastAt = _lastTimingDebugAt[kind];
    final capabilityChanged =
        _lastTimingCapabilitySignature[kind] != capabilitySignature;
    final intervalElapsed =
        lastAt == null || now.difference(lastAt) >= _timingDebugInterval;
    if (!capabilityChanged && !intervalElapsed) return;

    _lastTimingDebugAt[kind] = now;
    _lastTimingCapabilitySignature[kind] = capabilitySignature;

    debugPrint(
      '[HlsTimingDebug][$kind] '
      'pdt=${pdtLines.length} '
      'firstPdt=${firstPdt?.toUtc().toIso8601String() ?? '-'} '
      'lastPdt=${lastPdt?.toUtc().toIso8601String() ?? '-'} '
      'mediaSeq=$mediaSequence '
      'extinf=$extinfCount '
      'duration=${(durationMs / 1000).toStringAsFixed(3)}s '
      'target=${(targetDuration.inMilliseconds / 1000).toStringAsFixed(3)}s '
      'twitchElapsed=${elapsedSecs ?? '-'} '
      'twitchTotal=${totalSecs ?? '-'} '
      'parts=$partCount preload=$preloadCount twitchPrefetch=$twitchPrefetchCount '
      'url=${_shortPlaylistUrl(playlistUrl)}',
    );
  }

  static Duration? _parseTwitchDuration(List<String> lines, String prefix) {
    final raw = _firstTagValue(lines, prefix);
    final seconds = double.tryParse(raw ?? '');
    if (seconds == null || seconds < 0 || !seconds.isFinite) return null;
    return Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());
  }

  static String? _firstTagValue(List<String> lines, String prefix) {
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.startsWith(prefix)) {
        final value = line.substring(prefix.length).trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  static String _shortPlaylistUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return value.length <= 80 ? value : '${value.substring(0, 77)}...';
    final segments = uri.pathSegments;
    if (segments.isEmpty) return uri.host;
    final last = segments.last;
    final shortLast = last.length <= 48
        ? last
        : '${last.substring(0, 20)}...${last.substring(last.length - 20)}';
    final parent = segments.length >= 2 ? segments[segments.length - 2] : null;
    return parent == null
        ? '${uri.host}/$shortLast'
        : '${uri.host}/$parent/$shortLast';
  }

  static Duration _durationForFutureSegment(
    Duration lastSegmentDuration,
    Duration targetDuration,
  ) {
    if (lastSegmentDuration.inMilliseconds > 0) return lastSegmentDuration;
    if (targetDuration.inMilliseconds > 0) return targetDuration;
    return const Duration(seconds: 2);
  }

  static Duration _halfDuration(Duration duration) {
    final milliseconds = (duration.inMilliseconds / 2).round();
    return Duration(milliseconds: milliseconds > 120 ? milliseconds : 120);
  }

  static String _lastPathSegment(String url, {required String fallback}) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return fallback;
    final last = uri.pathSegments.last.trim();
    return last.isEmpty ? fallback : last;
  }

  static String? _parseQuotedUriAttribute(String line) {
    final match = RegExp(r'URI="([^"]+)"').firstMatch(line);
    return match?.group(1);
  }

  static String? _parseM3u8AttributeString(String line, String attributeName) {
    final quoted = RegExp('$attributeName="([^"]+)"').firstMatch(line);
    if (quoted != null) return quoted.group(1);

    final plain = RegExp('$attributeName=([^,]+)').firstMatch(line);
    return plain?.group(1)?.trim();
  }

  static double? _parseM3u8AttributeDouble(String line, String attributeName) {
    final match = RegExp('$attributeName=([0-9.]+)').firstMatch(line);
    if (match == null) return null;
    return double.tryParse(match.group(1) ?? '');
  }
}
