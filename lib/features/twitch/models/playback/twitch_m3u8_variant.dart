class TwitchPlaybackResult {
  final Uri usherUri;
  final String masterPlaylistUrl;
  final String masterPlaylistText;
  final List<TwitchM3u8Variant> variants;
  final String token;
  final String signature;

  const TwitchPlaybackResult({
    required this.usherUri,
    required this.masterPlaylistUrl,
    required this.masterPlaylistText,
    required this.variants,
    required this.token,
    required this.signature,
  });
}

class TwitchM3u8Variant {
  final String name;
  final String url;
  final int? bandwidth;
  final String? resolution;
  final double? frameRate;
  final String? codecs;
  final String? videoGroupId;
  final String? audioGroupId;
  final bool isAudioOnly;
  final Map<String, String> attributes;

  /// Whether this variant came from a playback source that is likely to contain
  /// Twitch server-side ad markers. This is a source-level signal, not a hard
  /// guarantee about every future media playlist reload.
  final bool hasAds;

  /// Human-readable source label used by the runtime selector, for example
  /// `web-site`, `ios-site`, or `android-autoplay`.
  final String sourceTag;

  const TwitchM3u8Variant({
    required this.name,
    required this.url,
    this.bandwidth,
    this.resolution,
    this.frameRate,
    this.codecs,
    this.videoGroupId,
    this.audioGroupId,
    this.isAudioOnly = false,
    this.attributes = const <String, String>{},
    this.hasAds = false,
    this.sourceTag = '',
  });

  String get displayName => name;

  int get height {
    final text = resolution ?? '';
    final parts = text.split('x');
    if (parts.length != 2) return 0;
    return int.tryParse(parts[1]) ?? 0;
  }

  int get fpsRounded => frameRate == null ? 0 : frameRate!.round();

  /// Stable-ish quality key for matching equivalent variants returned by
  /// different Twitch playback token contexts. The CRX no-ads approach compares
  /// variants by quality and swaps the URL to the cleaner candidate when a match
  /// exists; this key gives Dart code the same behavior.
  String get adAwareQualityKey {
    if (isAudioOnly) return 'audio_only';

    final explicitHeight = height;
    final explicitFps = fpsRounded;
    if (explicitHeight > 0) {
      return '${explicitHeight}p${explicitFps > 0 ? explicitFps : ''}';
    }

    final group = videoGroupId?.trim().toLowerCase();
    if (group != null && group.isNotEmpty) return group;

    final cleanName = name.trim().toLowerCase();
    return cleanName.isEmpty ? 'unknown' : cleanName;
  }

  TwitchM3u8Variant copyWith({
    String? name,
    String? url,
    int? bandwidth,
    String? resolution,
    double? frameRate,
    String? codecs,
    String? videoGroupId,
    String? audioGroupId,
    bool? isAudioOnly,
    Map<String, String>? attributes,
    bool? hasAds,
    String? sourceTag,
  }) {
    return TwitchM3u8Variant(
      name: name ?? this.name,
      url: url ?? this.url,
      bandwidth: bandwidth ?? this.bandwidth,
      resolution: resolution ?? this.resolution,
      frameRate: frameRate ?? this.frameRate,
      codecs: codecs ?? this.codecs,
      videoGroupId: videoGroupId ?? this.videoGroupId,
      audioGroupId: audioGroupId ?? this.audioGroupId,
      isAudioOnly: isAudioOnly ?? this.isAudioOnly,
      attributes: attributes ?? this.attributes,
      hasAds: hasAds ?? this.hasAds,
      sourceTag: sourceTag ?? this.sourceTag,
    );
  }

  @override
  String toString() {
    return 'TwitchM3u8Variant(name: $name, url: $url, bandwidth: $bandwidth, resolution: $resolution, frameRate: $frameRate, isAudioOnly: $isAudioOnly, hasAds: $hasAds, sourceTag: $sourceTag)';
  }
}

class TwitchM3u8Parser {
  static List<TwitchM3u8Variant> parseMasterPlaylist(
    String playlistText, {
    Uri? masterUri,
    bool defaultHasAds = false,
    String sourceTag = '',
  }) {
    final lines = playlistText.split(RegExp(r'\r?\n'));
    final videoGroupNames = <String, String>{};
    final audioGroupNames = <String, String>{};
    final variants = <TwitchM3u8Variant>[];

    Map<String, String>? pendingStreamAttributes;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXT-X-MEDIA:')) {
        final attrs = parseAttributeList(line.substring('#EXT-X-MEDIA:'.length));
        final type = attrs['TYPE']?.toUpperCase();
        final groupId = attrs['GROUP-ID'];
        final name = attrs['NAME'];
        if (groupId != null && name != null && name.trim().isNotEmpty) {
          if (type == 'VIDEO') {
            videoGroupNames[groupId] = name;
          } else if (type == 'AUDIO') {
            audioGroupNames[groupId] = name;
          }
        }
        continue;
      }

      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        pendingStreamAttributes = parseAttributeList(line.substring('#EXT-X-STREAM-INF:'.length));
        continue;
      }

      if (line.startsWith('#')) continue;

      final attrs = pendingStreamAttributes;
      if (attrs == null) continue;
      pendingStreamAttributes = null;

      final absoluteUrl = masterUri == null ? line : masterUri.resolve(line).toString();
      final videoGroupId = attrs['VIDEO'];
      final audioGroupId = attrs['AUDIO'];
      final resolution = attrs['RESOLUTION'];
      final frameRate = double.tryParse(attrs['FRAME-RATE'] ?? '');
      final bandwidth = int.tryParse(attrs['BANDWIDTH'] ?? '');
      final codecs = attrs['CODECS'];

      final lowerVideoGroup = (videoGroupId ?? '').toLowerCase();
      final lowerUrl = absoluteUrl.toLowerCase();
      final inferredAudioOnly = lowerVideoGroup.contains('audio') ||
          lowerUrl.contains('audio_only') ||
          (resolution == null && (videoGroupId == null || videoGroupId.isEmpty));

      final name = _buildVariantName(
        videoGroupName: videoGroupId == null ? null : videoGroupNames[videoGroupId],
        audioGroupName: audioGroupId == null ? null : audioGroupNames[audioGroupId],
        videoGroupId: videoGroupId,
        resolution: resolution,
        frameRate: frameRate,
        isAudioOnly: inferredAudioOnly,
      );

      variants.add(
        TwitchM3u8Variant(
          name: name,
          url: absoluteUrl,
          bandwidth: bandwidth,
          resolution: resolution,
          frameRate: frameRate,
          codecs: codecs,
          videoGroupId: videoGroupId,
          audioGroupId: audioGroupId,
          isAudioOnly: inferredAudioOnly,
          attributes: Map<String, String>.unmodifiable(attrs),
          hasAds: defaultHasAds,
          sourceTag: sourceTag,
        ),
      );
    }

    return variants;
  }

  static Map<String, String> parseAttributeList(String text) {
    final attrs = <String, String>{};
    var index = 0;

    while (index < text.length) {
      while (index < text.length && (text[index] == ',' || text[index].trim().isEmpty)) {
        index++;
      }
      if (index >= text.length) break;

      final keyStart = index;
      while (index < text.length && text[index] != '=') {
        index++;
      }
      if (index >= text.length) break;

      final key = text.substring(keyStart, index).trim();
      index++; // '='

      String value;
      if (index < text.length && text[index] == '"') {
        index++;
        final valueStart = index;
        while (index < text.length && text[index] != '"') {
          index++;
        }
        value = text.substring(valueStart, index);
        if (index < text.length && text[index] == '"') index++;
      } else {
        final valueStart = index;
        while (index < text.length && text[index] != ',') {
          index++;
        }
        value = text.substring(valueStart, index).trim();
      }

      if (key.isNotEmpty) {
        attrs[key] = value;
      }

      while (index < text.length && text[index] != ',') {
        index++;
      }
      if (index < text.length && text[index] == ',') index++;
    }

    return attrs;
  }

  static String _buildVariantName({
    required String? videoGroupName,
    required String? audioGroupName,
    required String? videoGroupId,
    required String? resolution,
    required double? frameRate,
    required bool isAudioOnly,
  }) {
    final explicitName = videoGroupName?.trim();
    if (explicitName != null && explicitName.isNotEmpty) {
      return explicitName;
    }

    if (isAudioOnly) {
      final audioName = audioGroupName?.trim();
      return audioName == null || audioName.isEmpty ? 'Audio Only' : audioName;
    }

    final group = videoGroupId?.trim().toLowerCase();
    final height = _heightFromResolution(resolution);
    final fps = frameRate == null ? 0 : frameRate.round();

    if (group == 'chunked') {
      if (height > 0 && fps > 0) return '${height}p$fps (source)';
      if (height > 0) return '${height}p (source)';
      return 'Source';
    }

    if (height > 0 && fps > 0) return '${height}p$fps';
    if (height > 0) return '${height}p';
    if (group != null && group.isNotEmpty) return group;
    return 'Unknown';
  }

  static int _heightFromResolution(String? resolution) {
    if (resolution == null || !resolution.contains('x')) return 0;
    final parts = resolution.split('x');
    if (parts.length != 2) return 0;
    return int.tryParse(parts[1]) ?? 0;
  }
}
