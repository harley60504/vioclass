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
  ssimSuperRes,
  artCnn,
  anime4kFast,
  anime4kHigh,
}

extension TwitchVideoEnhancementModeStorage on TwitchVideoEnhancementMode {
  String get storageValue => name;

  bool get usesShader => switch (this) {
    TwitchVideoEnhancementMode.fsr ||
    TwitchVideoEnhancementMode.ssimSuperRes ||
    TwitchVideoEnhancementMode.artCnn ||
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
    TwitchVideoEnhancementMode.ssimSuperRes => 'ewa_lanczossharp',
    TwitchVideoEnhancementMode.artCnn => 'ewa_lanczos',
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
  final bool chromaEnhance;
  final bool deband;
  final bool sharpen;

  const TwitchVideoEnhancementConfig({
    required this.enabled,
    required this.mode,
    required this.chromaEnhance,
    required this.deband,
    required this.sharpen,
  });
}

enum _TwitchVideoShaderAsset {
  fsr,
  anime4kFast,
  anime4kHigh,
  ssimSuperRes,
  artCnn,
  chromaCfL,
  adaptiveSharpen,
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
  static const String chromaEnhancePreferenceKey =
      'twitch_video_enhancement_chroma_v1';
  static const String debandPreferenceKey =
      'twitch_video_enhancement_deband_v1';
  static const String sharpenPreferenceKey =
      'twitch_video_enhancement_sharpen_v1';

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

  // Keep the general-purpose mpv shader set on one immutable revision. It
  // provides ArtCNN C4F16, SSimSuperRes, CfL chroma reconstruction, and
  // adaptive sharpening without allowing an upstream update to change output.
  static const String _shaderPackCommit =
      '61b09a0ab9ccfd42c7066474b0e41c9883f82fc2';
  static const String _shaderPackBaseUrl =
      'https://raw.githubusercontent.com/classicjazz/mpv-config/'
      '$_shaderPackCommit/shaders/';

  static TwitchVideoEnhancementConfig _config =
      const TwitchVideoEnhancementConfig(
        enabled: false,
        mode: TwitchVideoEnhancementMode.ewaLanczosSharp,
        chromaEnhance: false,
        deband: false,
        sharpen: false,
      );
  static bool _loaded = false;
  static Future<void>? _loading;
  static final Map<_TwitchVideoShaderAsset, Future<String?>> _shaderLoads =
      <_TwitchVideoShaderAsset, Future<String?>>{};

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
        chromaEnhance: prefs.getBool(chromaEnhancePreferenceKey) ?? false,
        deband: prefs.getBool(debandPreferenceKey) ?? false,
        sharpen: prefs.getBool(sharpenPreferenceKey) ?? false,
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
    required bool chromaEnhance,
    required bool deband,
    required bool sharpen,
  }) async {
    _config = TwitchVideoEnhancementConfig(
      enabled: enabled,
      mode: mode,
      chromaEnhance: chromaEnhance,
      deband: deband,
      sharpen: sharpen,
    );
    _loaded = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledPreferenceKey, enabled);
    await prefs.setString(modePreferenceKey, mode.storageValue);
    await prefs.setBool(chromaEnhancePreferenceKey, chromaEnhance);
    await prefs.setBool(debandPreferenceKey, deband);
    await prefs.setBool(sharpenPreferenceKey, sharpen);

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
    // glsl-shaders is a path-list option. Clear the whole chain first so stale
    // shaders from a previous mode cannot survive a live settings change.
    player.setProperty('glsl-shaders', '');
    player.setProperty('deband', config.enabled && config.deband ? 'yes' : 'no');

    if (!config.enabled) {
      player.setProperty('scale', 'lanczos');
      debugPrint('[VideoEnhancement] disabled scale=lanczos deband=no');
      return;
    }

    final mode = config.mode;
    var activeScale = mode.mpvScale;
    player.setProperty('scale', activeScale);

    final assets = <_TwitchVideoShaderAsset>[];
    final mainAsset = _shaderAssetForMode(mode);
    if (mainAsset != null) assets.add(mainAsset);
    if (config.chromaEnhance) assets.add(_TwitchVideoShaderAsset.chromaCfL);
    if (config.sharpen) assets.add(_TwitchVideoShaderAsset.adaptiveSharpen);

    final shaderPaths = <String>[];
    for (final asset in assets) {
      final shaderPath = await _ensureShader(asset);
      if (shaderPath != null) {
        shaderPaths.add(shaderPath);
        continue;
      }

      if (asset == mainAsset) {
        // A main upscaler failure should never break playback. Optional
        // post-processors can still run on top of the built-in fallback.
        activeScale = 'ewa_lanczossharp';
        player.setProperty('scale', activeScale);
      }
    }

    if (shaderPaths.isNotEmpty) {
      player.setProperty('glsl-shaders', _joinShaderPaths(shaderPaths));
    }

    debugPrint(
      '[VideoEnhancement] mode=${mode.name} scale=$activeScale '
      'shaders=${shaderPaths.length} chroma=${config.chromaEnhance} '
      'deband=${config.deband} sharpen=${config.sharpen}',
    );
  }

  static _TwitchVideoShaderAsset? _shaderAssetForMode(
    TwitchVideoEnhancementMode mode,
  ) {
    return switch (mode) {
      TwitchVideoEnhancementMode.fsr => _TwitchVideoShaderAsset.fsr,
      TwitchVideoEnhancementMode.ssimSuperRes =>
        _TwitchVideoShaderAsset.ssimSuperRes,
      TwitchVideoEnhancementMode.artCnn => _TwitchVideoShaderAsset.artCnn,
      TwitchVideoEnhancementMode.anime4kFast =>
        _TwitchVideoShaderAsset.anime4kFast,
      TwitchVideoEnhancementMode.anime4kHigh =>
        _TwitchVideoShaderAsset.anime4kHigh,
      _ => null,
    };
  }

  static String _joinShaderPaths(List<String> paths) {
    final separator = Platform.isWindows ? ';' : ':';
    return paths.join(separator);
  }

  static Future<String?> _ensureShader(_TwitchVideoShaderAsset asset) {
    return _shaderLoads.putIfAbsent(asset, () => _downloadShader(asset));
  }

  static Future<String?> _downloadShader(_TwitchVideoShaderAsset asset) async {
    final specification = switch (asset) {
      _TwitchVideoShaderAsset.fsr => (
        fileName: 'FSR_1_0_2.glsl',
        url: _fsrUrl,
      ),
      _TwitchVideoShaderAsset.anime4kFast => (
        fileName: 'Anime4K-Ultra.glsl',
        url: '${_anime4kBaseUrl}Anime4K-Ultra.glsl',
      ),
      _TwitchVideoShaderAsset.anime4kHigh => (
        fileName: 'Anime4K-Ultra_DbL.glsl',
        url: '${_anime4kBaseUrl}Anime4K-Ultra_DbL.glsl',
      ),
      _TwitchVideoShaderAsset.ssimSuperRes => (
        fileName: 'SSimSuperRes.glsl',
        url: '${_shaderPackBaseUrl}SSimSuperRes.glsl',
      ),
      _TwitchVideoShaderAsset.artCnn => (
        fileName: 'ArtCNN_C4F16.glsl',
        url: '${_shaderPackBaseUrl}ArtCNN_C4F16.glsl',
      ),
      _TwitchVideoShaderAsset.chromaCfL => (
        fileName: 'CfL_Prediction.glsl',
        url: '${_shaderPackBaseUrl}CfL_Prediction.glsl',
      ),
      _TwitchVideoShaderAsset.adaptiveSharpen => (
        fileName: 'adaptive-sharpen.glsl',
        url: '${_shaderPackBaseUrl}adaptive-sharpen.glsl',
      ),
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
          '[VideoEnhancement] cached shader asset=${asset.name} bytes=$size',
        );
        return file.path;
      } finally {
        client.close(force: true);
      }
    } catch (error) {
      debugPrint(
        '[VideoEnhancement] shader load failed asset=${asset.name}: $error',
      );
      _shaderLoads.remove(asset);
      return null;
    }
  }
}
