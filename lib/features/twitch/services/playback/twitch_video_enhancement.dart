import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TwitchVideoEnhancementMode {
  lanczos,
  ewaLanczos,
  ewaLanczosSharp,
  ewaLanczos4Sharpest,
  fsr,
  anime4kFast,
  anime4kHigh,
}

extension TwitchVideoEnhancementModeStorage on TwitchVideoEnhancementMode {
  String get storageValue => name;

  bool get usesShader => switch (this) {
    TwitchVideoEnhancementMode.fsr ||
    TwitchVideoEnhancementMode.anime4kFast ||
    TwitchVideoEnhancementMode.anime4kHigh => true,
    _ => false,
  };

  String get mpvScale => switch (this) {
    TwitchVideoEnhancementMode.lanczos => 'lanczos',
    TwitchVideoEnhancementMode.ewaLanczos => 'ewa_lanczos',
    TwitchVideoEnhancementMode.ewaLanczosSharp => 'ewa_lanczossharp',
    TwitchVideoEnhancementMode.ewaLanczos4Sharpest =>
      'ewa_lanczos4sharpest',
    TwitchVideoEnhancementMode.fsr ||
    TwitchVideoEnhancementMode.anime4kFast ||
    TwitchVideoEnhancementMode.anime4kHigh => 'lanczos',
  };

  static TwitchVideoEnhancementMode parse(String? value) {
    for (final mode in TwitchVideoEnhancementMode.values) {
      if (mode.storageValue == value) return mode;
    }
    return TwitchVideoEnhancementMode.ewaLanczosSharp;
  }
}

class TwitchVideoEnhancementConfig {
  final bool enabled;
  final TwitchVideoEnhancementMode mode;

  const TwitchVideoEnhancementConfig({
    required this.enabled,
    required this.mode,
  });
}

/// Owns mpv GPU scaler / GLSL shader configuration.
///
/// The active media source is never reopened when this changes. VioClass keeps
/// MediaCodec/hardware decoding enabled and only updates mpv GPU renderer
/// properties. Shader files are fetched once from immutable upstream revisions
/// and cached in the app support directory.
class TwitchVideoEnhancementRuntime {
  static const String enabledPreferenceKey =
      'twitch_video_enhancement_enabled_v1';
  static const String modePreferenceKey = 'twitch_video_enhancement_mode_v1';

  // AMD FidelityFX FSR 1.0.2 port for mpv by agyild. MIT licensed.
  static const String _fsrUrl =
      'https://gist.githubusercontent.com/agyild/'
      '82219c545228d70c5604f865ce0b0ce5/raw/'
      '2623d743b9c23f500ba086f05b385dcb1557e15d/FSR.glsl';

  // Anime4K-Ultra is MIT licensed. Pin the exact commit so playback never
  // silently starts using a different shader implementation after an update.
  static const String _anime4kCommit =
      'a9fe6a46f53a7691dc0bf9122d9bbc15f0df48b5';
  static const String _anime4kBaseUrl =
      'https://raw.githubusercontent.com/Th-Underscore/Anime4K-Ultra/'
      '$_anime4kCommit/';

  static TwitchVideoEnhancementConfig _config =
      const TwitchVideoEnhancementConfig(
        enabled: false,
        mode: TwitchVideoEnhancementMode.ewaLanczosSharp,
      );
  static bool _loaded = false;
  static Future<void>? _loading;
  static final Map<TwitchVideoEnhancementMode, Future<String?>> _shaderLoads =
      <TwitchVideoEnhancementMode, Future<String?>>{};

  static TwitchVideoEnhancementConfig get config => _config;

  static Future<TwitchVideoEnhancementConfig> loadPreferences() async {
    if (_loaded) return _config;
    final loading = _loading;
    if (loading != null) {
      await loading;
      return _config;
    }

    _loading = () async {
      final prefs = await SharedPreferences.getInstance();
      _config = TwitchVideoEnhancementConfig(
        enabled: prefs.getBool(enabledPreferenceKey) ?? false,
        mode: TwitchVideoEnhancementModeStorage.parse(
          prefs.getString(modePreferenceKey),
        ),
      );
      _loaded = true;
    }();

    try {
      await _loading;
    } finally {
      _loading = null;
    }
    return _config;
  }

  static Future<void> saveAndApply({
    required Player? player,
    required bool enabled,
    required TwitchVideoEnhancementMode mode,
  }) async {
    _config = TwitchVideoEnhancementConfig(enabled: enabled, mode: mode);
    _loaded = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledPreferenceKey, enabled);
    await prefs.setString(modePreferenceKey, mode.storageValue);

    if (player != null) {
      await applyToPlayer(player, config: _config);
    }
  }

  static Future<void> applyStoredToPlayer(Player player) async {
    final loaded = await loadPreferences();
    await applyToPlayer(player, config: loaded);
  }

  static Future<void> applyToPlayer(
    Player player, {
    required TwitchVideoEnhancementConfig config,
  }) async {
    // glsl-shaders overwrites the full list. Clear it first so changing from a
    // shader mode to a native scaler takes effect without reopening media.
    player.setProperty('glsl-shaders', '');

    if (!config.enabled) {
      player.setProperty('scale', 'lanczos');
      debugPrint('[VideoEnhancement] disabled scale=lanczos');
      return;
    }

    final mode = config.mode;
    player.setProperty('scale', mode.mpvScale);
    if (!mode.usesShader) {
      debugPrint('[VideoEnhancement] mode=${mode.name} scale=${mode.mpvScale}');
      return;
    }

    final shaderPath = await _ensureShader(mode);
    if (shaderPath == null) {
      // A shader download failure must never break Twitch playback. Keep a
      // high-quality built-in scaler active until the user retries a shader.
      player.setProperty('scale', 'ewa_lanczossharp');
      debugPrint(
        '[VideoEnhancement] shader unavailable mode=${mode.name}; '
        'fallback=ewa_lanczossharp',
      );
      return;
    }

    player.setProperty('glsl-shaders', shaderPath);
    debugPrint(
      '[VideoEnhancement] mode=${mode.name} shader=$shaderPath '
      'scale=${mode.mpvScale}',
    );
  }

  static Future<String?> _ensureShader(TwitchVideoEnhancementMode mode) {
    return _shaderLoads.putIfAbsent(mode, () => _downloadShader(mode));
  }

  static Future<String?> _downloadShader(
    TwitchVideoEnhancementMode mode,
  ) async {
    final specification = switch (mode) {
      TwitchVideoEnhancementMode.fsr => (
        fileName: 'FSR_1_0_2.glsl',
        url: _fsrUrl,
      ),
      TwitchVideoEnhancementMode.anime4kFast => (
        fileName: 'Anime4K-Ultra.glsl',
        url: '${_anime4kBaseUrl}Anime4K-Ultra.glsl',
      ),
      TwitchVideoEnhancementMode.anime4kHigh => (
        fileName: 'Anime4K-Ultra_DbL.glsl',
        url: '${_anime4kBaseUrl}Anime4K-Ultra_DbL.glsl',
      ),
      _ => throw StateError('Mode ${mode.name} does not use a shader.'),
    };

    try {
      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        '${support.path}${Platform.pathSeparator}shaders',
      );
      await directory.create(recursive: true);
      final file = File(
        '${directory.path}${Platform.pathSeparator}${specification.fileName}',
      );
      if (await file.exists() && await file.length() > 1024) {
        return file.path;
      }

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8)
        ..idleTimeout = const Duration(seconds: 12);
      try {
        final uri = Uri.parse(specification.url);
        final request = await client.getUrl(uri);
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'VioClass/VideoEnhancement',
        );
        request.headers.set(HttpHeaders.acceptHeader, 'text/plain,*/*;q=0.8');
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          throw HttpException('shader HTTP ${response.statusCode}', uri: uri);
        }

        final temporary = File('${file.path}.part');
        final sink = temporary.openWrite();
        await response.pipe(sink);
        final size = await temporary.length();
        if (size <= 1024) {
          try {
            await temporary.delete();
          } catch (_) {}
          throw StateError('Downloaded shader is unexpectedly small ($size B).');
        }
        if (await file.exists()) await file.delete();
        await temporary.rename(file.path);
        debugPrint(
          '[VideoEnhancement] cached shader mode=${mode.name} bytes=$size',
        );
        return file.path;
      } finally {
        client.close(force: true);
      }
    } catch (error) {
      debugPrint(
        '[VideoEnhancement] shader load failed mode=${mode.name}: $error',
      );
      _shaderLoads.remove(mode);
      return null;
    }
  }
}
