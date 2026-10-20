/// Retain at most 4 KiB even if the upstream ignores HTTP Range.
/// Breaking the subscription cancels the remaining response body.
Future<List<int>> twitchReadMediaPrefix(Stream<List<int>> stream) async {
  final bytes = <int>[];
  await for (final chunk in stream) {
    bytes.addAll(chunk.take(4096 - bytes.length));
    if (bytes.length == 4096) break;
  }
  return bytes;
}

/// The switch probe exports only these fixed keyword flags, never message text.
Iterable<String> twitchNativeLogFlags(String message) {
  final lower = message.toLowerCase().replaceAll(
    RegExp(r'https?://\S+'),
    '<url>',
  );
  return const [
    'option',
    'property',
    'shader',
    'device',
    'connection',
    'format',
    'unrecognized',
    'decoder',
    'probe',
    'mpeg',
    'timestamp',
    'moov',
    'error',
    'failed',
    'demux',
    'codec',
    'video',
    'audio',
    'http',
    'eof',
    'invalid',
    '403',
    '404',
  ].where(lower.contains);
}

/// Only fixed numeric/boolean properties, never paths, metadata or native text.
Map<String, String> twitchNativePlaybackProperties(
  String Function(String name) readProperty,
) {
  final result = <String, String>{};
  for (final name in const [
    'paused-for-cache',
    'demuxer-cache-duration',
    'cache-buffering-state',
    'eof-reached',
    'idle-active',
    'video-params/w',
    'video-params/h',
    'video-out-params/w',
    'video-out-params/h',
    'decoder-frame-drop-count',
    'frame-drop-count',
    'vo-delayed-frame-count',
    'audio-params/samplerate',
    'audio-params/channel-count',
    'audio-out-params/samplerate',
    'avsync',
    'volume',
    'mute',
    'stream-pos',
    'cache-speed',
    'demuxer-cache-time',
    'demuxer-cache-idle',
    'demuxer-cache-state/fw-bytes',
    'demuxer-cache-state/total-bytes',
    'demuxer-cache-state/underrun',
    'core-idle',
  ]) {
    try {
      final value = readProperty(name);
      if (value.length <= 32 &&
          RegExp(r'^(?:yes|no|-?\d+(?:\.\d+)?)$').hasMatch(value)) {
        result[name] = value;
      }
    } catch (_) {
      // Unsupported/unavailable properties are omitted, not treated as zero.
    }
  }
  return result;
}

/// Fixed categories only. Never retain or return raw native messages.
class TwitchNativeLogDiagnostics {
  final _counts = <String, int>{};

  static const _patterns = <String, List<String>>{
    'audio_decode_failed': [
      'error decoding audio',
      'failed to decode audio',
      'audio decoding failed',
    ],
    'audio_output_failed': [
      'could not open/initialize audio device',
      'audio output initialization failed',
      'audio device could not be opened',
    ],
    'format_unrecognized': [
      'failed to recognize file format',
      'unrecognized file format',
      'invalid data found',
    ],
    'open_failed': [
      'failed to open',
      'could not open',
      'unable to open',
      'error opening',
      'cannot open',
    ],
    'connection_refused': ['connection refused'],
    'http_failure': ['http error', 'server returned'],
    'read_failed': ['failed to read', 'error reading', 'read error'],
    'missing_moov': ['moov atom not found'],
    'no_streams': ['no streams added', 'no video or audio streams'],
    'decoder_failed': [
      'failed to initialize decoder',
      'could not find codec',
      'error while decoding',
    ],
    'option_failed': [
      'failed to set option',
      'error parsing option',
      'unrecognized option',
      'option not found',
    ],
    'property_failed': [
      'failed to set property',
      'unknown property',
      'property not found',
    ],
    'hardware_decode_failed': [
      'hwaccel initialisation returned error',
      'failed setup for format',
      'failed to create hw device',
    ],
    'video_output_failed': [
      'failed initializing any suitable gpu context',
      'failed to initialize video output',
      'error opening/initializing the selected video_out',
    ],
    'end_of_file': ['end of file'],
  };

  // Hints are not causes. Export only a fixed allowlist, never message tokens.
  static const _unclassifiedHintPatterns = <String, List<String>>{
    'audio': ['audio', 'wasapi'],
    'video': ['video', 'video_out'],
    'gpu': [
      'gpu',
      'd3d11',
      'direct3d',
      'dxgi',
      'vulkan',
      'opengl',
      'egl',
      'wgl',
    ],
    'hardware_decode': ['hwdec', 'hwaccel', 'cuda', 'vaapi', 'vdpau'],
    'gpu_egl': ['egl'],
    'gpu_opengl': ['opengl', 'wgl'],
    'gpu_d3d11': ['d3d11', 'direct3d', 'dxgi'],
    'gpu_vulkan': ['vulkan'],
    'decoder': ['decoder', 'codec'],
    'device': ['device', 'driver'],
    'configuration': ['option', 'property', 'config'],
    'filter': ['filter', 'lavfi'],
    'demux': ['demux', 'moof', 'mdat', 'packet'],
    'screenshot': ['screenshot'],
    'permission': ['permission', 'access denied'],
    'library': ['library', '.dll'],
    'initialization': ['initializ', 'initialis'],
  };

  void record(String message) {
    // URL paths/query values describe the source, not a native failure.
    final lower = message.toLowerCase().replaceAll(
      RegExp(r'https?://\S+'),
      '<url>',
    );
    var matched = false;
    for (final entry in _patterns.entries) {
      if (entry.value.any(lower.contains)) {
        matched = true;
        _counts.update(entry.key, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    if (!matched && (lower.contains('error') || lower.contains('failed'))) {
      _counts.update(
        'unclassified_failure',
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      for (final entry in _unclassifiedHintPatterns.entries) {
        if (entry.value.any(lower.contains)) {
          _counts.update(
            'unclassified_hint_${entry.key}',
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }
  }

  Map<String, int> get snapshot => Map.unmodifiable(_counts);
}

/// Aggregate frame pixels only; never return or retain image data.
Map<String, num> twitchFramePixelSummary({
  required List<int> rgba,
  required int width,
  required int height,
  int? left,
  int? top,
  int? right,
  int? bottom,
}) {
  if (width <= 0 || height <= 0 || rgba.length != width * height * 4) {
    throw ArgumentError('Invalid RGBA frame dimensions');
  }
  final x0 = (left ?? 0).clamp(0, width);
  final y0 = (top ?? 0).clamp(0, height);
  final x1 = (right ?? width).clamp(0, width);
  final y1 = (bottom ?? height).clamp(0, height);
  var total = 0;
  var nonBlack = 0;
  final colors = <int>{};
  for (var y = y0; y < y1; y += 2) {
    for (var x = x0; x < x1; x += 2) {
      final offset = (y * width + x) * 4;
      final r = rgba[offset];
      final g = rgba[offset + 1];
      final b = rgba[offset + 2];
      if (r > 16 || g > 16 || b > 16) {
        nonBlack++;
      }
      colors.add((r << 16) | (g << 8) | b);
      total++;
    }
  }
  return {
    'samples': total,
    'nonBlackFraction': total == 0 ? 0 : nonBlack / total,
    'colors': colors.length,
  };
}

/// Matches the central 60% region used by the Flutter texture probe.
/// Compare only when source/texture aspect ratios match; not pixel identity.
Map<String, num> twitchCentralFramePixelSummary({
  required List<int> rgba,
  required int width,
  required int height,
}) => twitchFramePixelSummary(
  rgba: rgba,
  width: width,
  height: height,
  left: (width * .2).ceil(),
  top: (height * .2).ceil(),
  right: (width * .8).floor(),
  bottom: (height * .8).floor(),
);

/// Header signatures are hints, not proof that the media can be decoded.
Map<String, bool> twitchMediaHeaderHints(List<int> bytes) {
  final ts =
      bytes.length > 376 &&
      bytes[0] == 0x47 &&
      bytes[188] == 0x47 &&
      bytes[376] == 0x47;
  final box = bytes.length >= 8
      ? String.fromCharCodes(bytes.skip(4).take(4))
      : '';
  return {
    'tsSyncAtStart': ts,
    'mp4BoxAtStart': const {
      'ftyp',
      'styp',
      'moof',
      'sidx',
      'mdat',
      'moov',
      'emsg',
      'prft',
      'uuid',
      'free',
      'skip',
    }.contains(box),
  };
}
