import '../../models/playback/twitch_hls_proxy_models.dart';

class TwitchHlsPlaylistParser {
  const TwitchHlsPlaylistParser._();

  static TwitchParsedMediaPlaylist parse(
    String playlistText, {
    required String playlistUrl,
  }) {
    final base = Uri.parse(playlistUrl);
    final items = <TwitchHlsSegmentItem>[];
    final seenUrls = <String>{};

    String? currentMapUrl;
    String? pendingLabel;
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
        mediaSequence = int.tryParse(
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

      if (line.startsWith('#EXT-X-MAP:')) {
        final mapUri = _parseQuotedUriAttribute(line);
        if (mapUri != null && mapUri.isNotEmpty) {
          currentMapUrl = base.resolve(mapUri).toString();
        }
        continue;
      }

      if (line.startsWith('#EXTINF:')) {
        final durationText =
            line.substring('#EXTINF:'.length).split(',').first.trim();
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
        items.add(
          TwitchHlsSegmentItem(
            url: absoluteUrl,
            mapUrl: currentMapUrl,
            label: pendingLabel ??
                _lastPathSegment(absoluteUrl, fallback: 'segment'),
            sequence: mediaSequence + segmentIndex,
            isPrefetch: false,
            duration: pendingDuration,
          ),
        );
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

    return TwitchParsedMediaPlaylist(
      items: items,
      reloadDelay: reloadDelay,
      normalCount: normalCount,
      futureCount: futureCount,
      mediaSequence: mediaSequence,
      targetDuration: targetDuration,
      hasEndList: hasEndList,
    );
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
