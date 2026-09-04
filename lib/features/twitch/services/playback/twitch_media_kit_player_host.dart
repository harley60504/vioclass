import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

const bool _enableWatchPlayer = bool.fromEnvironment(
  'TWITCH_ENABLE_WATCH_PLAYER',
  defaultValue: true,
);

/// Keep the native media_kit [Player] warm for fast re-entry, but do not keep
/// the Flutter [VideoController] / texture surface as a process-wide singleton.
///
/// - CPU profiles showed proxy/player were not the heavy path.
/// - Replacing only the Video widget with a placeholder restored stable 90 FPS.
/// - Therefore the expensive / sticky part is the Flutter video surface.
///
/// This host persists the native Player and currently opened media URI.
/// Each visible owner gets its own VideoController / texture surface so DVR,
/// VOD, clip, and live proxy reopens do not fight over a stale surface.
class TwitchMediaKitPlayerHost {
  static Player? _player;
  static int _refCount = 0;
  static int _generation = 0;
  static String? _currentMediaUri;
  static String? _keepPlayingWithoutSessionUri;
  static Future<void>? _creatingPlayer;

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
            'cache': 'no',
            'cache-pause': 'no',
            'demuxer-seekable-cache': 'no',
            'demuxer-readahead-secs': '0',
            'demuxer-max-back-bytes': '0',
            'demuxer-max-bytes': '1048576',
          },
        ),
      );
      _player = player;
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

  static Future<VideoController> _createVideoController(Player player) {
    return VideoController.create(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
        androidAttachSurfaceAfterVideoParameters: false,
        hwdec: 'auto-safe',
      ),
    );
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
    _currentMediaUri = null;
    _keepPlayingWithoutSessionUri = null;
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
      final controller = await TwitchMediaKitPlayerHost._createVideoController(
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

  Future<void> stopCurrent() => TwitchMediaKitPlayerHost.stopCurrent(this);

  void release() {
    if (_released) return;
    _released = true;
    TwitchMediaKitPlayerHost._release(this);
  }

  void _detachVideoSurface() {
    // media_kit_video's VideoController does not expose a stable public dispose
    // API across the package versions tested in this project. Dropping this
    // session-owned reference lets the WatchPage remove the Video widget and its
    // texture surface from the Flutter tree while the shared Player remains warm.
    _videoController = null;
    _creatingVideoController = null;
  }
}
