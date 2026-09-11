import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'twitch_video_enhancement.dart';

const bool _enableWatchPlayer = bool.fromEnvironment(
  'TWITCH_ENABLE_WATCH_PLAYER',
  defaultValue: true,
);

enum _TwitchHlsCacheProfile { lowLatency, liveDvr }

/// Keep the native media_kit [Player] and its [VideoController] warm for fast
/// re-entry.
///
/// - CPU profiles showed proxy/player were not the heavy path.
/// - Replacing only the Video widget with a placeholder restored stable 90 FPS.
/// - Therefore the expensive / sticky part is the Flutter video surface.
///
/// The controller is created once for each native Player. Visible sessions only
/// transfer the reference to that controller, preventing route, mini-player,
/// DVR, and live transitions from repeatedly allocating native video textures.
class TwitchMediaKitPlayerHost {
  static Player? _player;
  static VideoController? _videoController;
  static int _refCount = 0;
  static int _generation = 0;
  static String? _currentMediaUri;
  static String? _keepPlayingWithoutSessionUri;
  static Future<void>? _creatingPlayer;
  static Future<void>? _creatingVideoController;
  static _TwitchHlsCacheProfile _hlsCacheProfile =
      _TwitchHlsCacheProfile.lowLatency;

  static const Map<String, String> _lowLatencyHlsOptions = <String, String>{
    'cache': 'no',
    'cache-pause': 'no',
    'cache-secs': '0',
    'demuxer-seekable-cache': 'no',
    'demuxer-readahead-secs': '0',
    'demuxer-max-back-bytes': '0',
    'demuxer-max-bytes': '1048576',
    'demuxer-donate-buffer': 'yes',
  };

  static const Map<String, String> _liveDvrHlsOptions = <String, String>{
    'cache': 'yes',
    'cache-pause': 'yes',
    'cache-secs': '8',
    'demuxer-seekable-cache': 'yes',
    'demuxer-readahead-secs': '8',
    'demuxer-max-back-bytes': '8388608',
    'demuxer-max-bytes': '25165824',
    'demuxer-donate-buffer': 'no',
  };

  TwitchMediaKitPlayerHost._();

  static String? get currentMediaUri => _currentMediaUri;
  static Player? get playerOrNull => _player;

  static bool get hasKeepAlivePlayback {
    final keepUri = _keepPlayingWithoutSessionUri;
    return keepUri != null && keepUri.isNotEmpty && keepUri == _currentMediaUri;
  }

  static void keepPlayingWithoutSession(String? uri) {
    final safeUri = uri?.trim();
    _keepPlayingWithoutSessionUri = safeUri == null || safeUri.isEmpty
        ? null
        : safeUri;
  }

  static TwitchMediaKitPlayerSession acquire({
    String title = 'Twitch Raw Proxy',
  }) {
    MediaKit.ensureInitialized();
    _refCount++;

    final player = _player;
    if (player != null) {
      return TwitchMediaKitPlayerSession._(
        title: title,
        player: player,
        generation: _generation,
      );
    }

    return TwitchMediaKitPlayerSession._lazy(
      title: title,
      generation: _generation,
    );
  }

  static Future<Player> _ensurePlayerCreated(String title) async {
    final existing = _player;
    if (existing != null) return existing;
    if (_creatingPlayer != null) {
      await _creatingPlayer;
      final created = _player;
      if (created == null) {
        throw StateError(
          'media_kit Player creation completed without a Player.',
        );
      }
      return created;
    }

    _creatingPlayer = () async {
      _generation++;
      _currentMediaUri = null;
      _hlsCacheProfile = _TwitchHlsCacheProfile.lowLatency;
      final player = await Player.create(
        configuration: PlayerConfiguration(
          title: title,
          // Match the low-latency profile used in the isolated Android test
          // page.
          bufferSize: 8 * 1024 * 1024,
          logLevel: kDebugMode ? MPVLogLevel.warn : MPVLogLevel.error,
          options: const <String, String>{
            'volume': '100',
            'volume-max': '100',
            'force-seekable': 'yes',
            'video-sync': 'audio',
            'autosync': '0',
            ..._lowLatencyHlsOptions,
          },
        ),
      );
      _player = player;
      await TwitchVideoEnhancementRuntime.applyStoredToPlayer(player);
    }();

    try {
      await _creatingPlayer;
    } finally {
      _creatingPlayer = null;
    }

    final created = _player;
    if (created == null) {
      throw StateError('media_kit Player creation failed.');
    }
    return created;
  }

  static Future<VideoController> _ensureVideoController(Player player) async {
    final existing = _videoController;
    if (existing != null) return existing;

    final creating = _creatingVideoController;
    if (creating != null) {
      await creating;
      final created = _videoController;
      if (created == null) {
        throw StateError(
          'VideoController creation completed without a controller.',
        );
      }
      return created;
    }

    _creatingVideoController = () async {
      final controller = await VideoController.create(
        player,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
          androidAttachSurfaceAfterVideoParameters: false,
          hwdec: 'auto-safe',
        ),
      );
      _videoController = controller;
    }();

    try {
      await _creatingVideoController;
    } finally {
      _creatingVideoController = null;
    }

    final created = _videoController;
    if (created == null) {
      throw StateError('VideoController creation failed.');
    }
    return created;
  }

  static Future<void> openOrResume(
    TwitchMediaKitPlayerSession session, {
    required String uri,
    bool play = true,
    bool forceOpen = false,
    Duration? startPosition,
  }) async {
    if (!_enableWatchPlayer) {
      _currentMediaUri = null;
      if (!session._released) {
        await session.ensureReady();
        await session.player.stop();
      }
      return;
    }

    await session.ensureReady();
    if (session._released) return;
    session._generation = _generation;

    final safeUri = uri.trim();
    if (safeUri.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'uri cannot be empty');
    }

    if (!forceOpen && _currentMediaUri == safeUri) {
      if (startPosition != null && !session._released) {
        await session.player.seek(startPosition);
      }
      if (play && !session.player.state.playing && !session._released) {
        await session.player.play();
      }
      return;
    }

    if (session._released) return;
    await session.player.open(Media(safeUri, start: startPosition), play: play);
    if (!session._released) {
      _currentMediaUri = safeUri;
    } else {
      unawaited(session.player.pause().catchError((_) {}));
    }
  }

  static Future<void> restoreSharedMedia({
    required String uri,
    bool play = true,
    bool forceOpen = false,
  }) async {
    final player = _player;
    if (player == null) return;

    final safeUri = uri.trim();
    if (safeUri.isEmpty) return;

    if (!forceOpen && _currentMediaUri == safeUri) {
      if (play && !player.state.playing) {
        await player.play();
      }
      return;
    }

    await player.open(Media(safeUri), play: play);
    _currentMediaUri = safeUri;
  }

  static Future<void> pauseShared() async {
    final player = _player;
    if (player == null) return;
    await player.pause();
  }

  static Future<void> _applyHlsCacheProfile(
    TwitchMediaKitPlayerSession session,
    _TwitchHlsCacheProfile profile,
  ) async {
    await session.ensureReady();
    if (session._released || session.generation != _generation) return;
    if (_hlsCacheProfile == profile) return;

    final player = session.player;
    final options = profile == _TwitchHlsCacheProfile.liveDvr
        ? _liveDvrHlsOptions
        : _lowLatencyHlsOptions;
    for (final entry in options.entries) {
      player.setProperty(entry.key, entry.value);
    }
    _hlsCacheProfile = profile;
    debugPrint('[TwitchPlayer] HLS cache profile=${profile.name}');
  }

  static Future<void> pauseCurrent(TwitchMediaKitPlayerSession session) async {
    await session.ensureReady();
    if (session.generation != _generation) return;
    await session.player.pause();
  }

  static Future<void> stopCurrent(TwitchMediaKitPlayerSession session) async {
    await session.ensureReady();
    if (session.generation != _generation) return;
    await session.player.stop();
    _currentMediaUri = null;
    _keepPlayingWithoutSessionUri = null;
  }

  static void _release(TwitchMediaKitPlayerSession session) {
    if (session.generation != _generation) return;

    session._detachVideoSurface();

    _refCount = (_refCount - 1).clamp(0, 1 << 20).toInt();
    if (_refCount > 0) return;

    // Keep the native player and current media attached after the last
    // WatchPage leaves. Re-entering a stream can resume the same local source
    // without rebuilding media_kit, but audio stays paused while off-page.
    if (hasKeepAlivePlayback) return;

    final player = _player;
    if (player != null) {
      unawaited(player.pause().catchError((_) {}));
    }
  }

  static Future<void> disposeNow() async {
    _refCount = 0;
    await _disposeCurrent();
  }

  static Future<void> _disposeCurrent() async {
    final player = _player;
    _player = null;
    _videoController = null;
    _creatingVideoController = null;
    _currentMediaUri = null;
    _keepPlayingWithoutSessionUri = null;
    _hlsCacheProfile = _TwitchHlsCacheProfile.lowLatency;
    _generation++;

    if (player == null) return;

    try {
      await player.pause();
    } catch (_) {}

    try {
      await player.dispose();
    } catch (_) {}
  }
}

class TwitchMediaKitPlayerSession {
  final String _title;
  Player? _player;
  VideoController? _videoController;
  int _generation;

  bool _released = false;
  Future<void>? _creatingVideoController;

  TwitchMediaKitPlayerSession._({
    required String title,
    required Player player,
    required int generation,
  }) : _title = title,
       _player = player,
       _generation = generation;

  TwitchMediaKitPlayerSession._lazy({
    required String title,
    required int generation,
  }) : _title = title,
       _generation = generation;

  Player? get playerOrNull => _player ?? TwitchMediaKitPlayerHost.playerOrNull;

  VideoController? get videoControllerOrNull => _videoController;

  Player get player {
    final value = playerOrNull;
    if (value == null) {
      throw StateError(
        'TwitchMediaKitPlayerSession is not ready. Call ensureReady() first.',
      );
    }
    return value;
  }

  VideoController get videoController {
    final value = videoControllerOrNull;
    if (value == null) {
      throw StateError(
        'TwitchMediaKitPlayerSession video surface is not ready. Call ensureReady() first.',
      );
    }
    return value;
  }

  int get generation => _generation;

  String? get currentMediaUri => TwitchMediaKitPlayerHost.currentMediaUri;

  bool moveSurfaceFrom(TwitchMediaKitPlayerSession other) {
    if (_released || other._released) return false;
    if (other.generation != TwitchMediaKitPlayerHost._generation) {
      return false;
    }

    final otherPlayer = other.playerOrNull;
    final otherController = other.videoControllerOrNull;
    if (otherPlayer == null || otherController == null) return false;

    _player = otherPlayer;
    _videoController = otherController;
    _generation = other.generation;
    other._detachVideoSurface();
    return true;
  }

  Future<void> ensureReady() async {
    final hostPlayer = await TwitchMediaKitPlayerHost._ensurePlayerCreated(
      _title,
    );
    if (_released) return;

    _player = hostPlayer;
    _generation = TwitchMediaKitPlayerHost._generation;

    if (_videoController != null) return;
    if (_creatingVideoController != null) {
      await _creatingVideoController;
      return;
    }

    _creatingVideoController = () async {
      final controller = await TwitchMediaKitPlayerHost._ensureVideoController(
        hostPlayer,
      );
      if (_released) return;
      _videoController = controller;
    }();

    try {
      await _creatingVideoController;
    } finally {
      _creatingVideoController = null;
    }
  }

  Future<void> openOrResume({
    required String uri,
    bool play = true,
    bool forceOpen = false,
    Duration? startPosition,
  }) {
    return TwitchMediaKitPlayerHost.openOrResume(
      this,
      uri: uri,
      play: play,
      forceOpen: forceOpen,
      startPosition: startPosition,
    );
  }

  Future<void> pauseCurrent() => TwitchMediaKitPlayerHost.pauseCurrent(this);

  Future<void> useLiveDvrHlsCacheProfile() =>
      TwitchMediaKitPlayerHost._applyHlsCacheProfile(
        this,
        _TwitchHlsCacheProfile.liveDvr,
      );

  Future<void> useLowLatencyHlsProfile() =>
      TwitchMediaKitPlayerHost._applyHlsCacheProfile(
        this,
        _TwitchHlsCacheProfile.lowLatency,
      );

  Future<void> stopCurrent() => TwitchMediaKitPlayerHost.stopCurrent(this);

  void release() {
    if (_released) return;
    _released = true;
    TwitchMediaKitPlayerHost._release(this);
  }

  void _detachVideoSurface() {
    // The session releases ownership of the shared surface. The host keeps the
    // controller alive so the next visible owner reuses the same native texture.
    _videoController = null;
    _creatingVideoController = null;
  }
}
