import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

const bool _enableWatchPlayer = bool.fromEnvironment(
  'TWITCH_ENABLE_WATCH_PLAYER',
  defaultValue: true,
);

class TwitchMediaKitPlayerHost {
  static Player? _player;
  static VideoController? _videoController;
  static int _refCount = 0;
  static int _generation = 0;
  static String? _currentMediaUri;
  static Future<void>? _creating;

  TwitchMediaKitPlayerHost._();

  static String? get currentMediaUri => _currentMediaUri;

  static TwitchMediaKitPlayerSession acquire({
    String title = 'Twitch Raw Proxy',
  }) {
    MediaKit.ensureInitialized();
    _refCount++;

    final player = _player;
    final controller = _videoController;
    if (player != null && controller != null) {
      return TwitchMediaKitPlayerSession._(
        player: player,
        videoController: controller,
        generation: _generation,
      );
    }

    // PiliPlus media_kit fork exposes async Player.create / VideoController.create.
    // The legacy host API is synchronous, so return a lazy session that creates
    // the native player before first use. WatchPage accesses player/video only
    // during build after services are constructed, so this keeps the branch
    // compile-safe while the new player_core remains the main test target.
    return TwitchMediaKitPlayerSession._lazy(
      title: title,
      generation: _generation,
    );
  }

  static Future<void> _ensureCreated(String title) async {
    if (_player != null && _videoController != null) return;
    if (_creating != null) return _creating;

    _creating = () async {
      _generation++;
      _currentMediaUri = null;
      final player = await Player.create(
        configuration: PlayerConfiguration(
          title: title,
          bufferSize: 16 * 1024 * 1024,
          logLevel: kDebugMode ? MPVLogLevel.warn : MPVLogLevel.error,
          options: const <String, String>{
            'volume': '100',
            'volume-max': '100',
            'video-sync': 'audio',
            'autosync': '30',
            'force-seekable': 'yes',
            'cache': 'yes',
            'demuxer-seekable-cache': 'yes',
          },
        ),
      );
      final controller = await VideoController.create(
        player,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
          androidAttachSurfaceAfterVideoParameters: false,
          hwdec: 'auto-safe',
        ),
      );
      _player = player;
      _videoController = controller;
    }();

    try {
      await _creating;
    } finally {
      _creating = null;
    }
  }

  static Future<void> openOrResume(
    TwitchMediaKitPlayerSession session, {
    required String uri,
    bool play = true,
    bool forceOpen = false,
  }) async {
    if (!_enableWatchPlayer) {
      _currentMediaUri = null;
      if (!session._released) {
        await session.player.stop();
      }
      return;
    }

    await session.ensureReady();
    if (session._released) return;
    if (session.generation != _generation) {
      session._generation = _generation;
    }

    final safeUri = uri.trim();
    if (safeUri.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'uri cannot be empty');
    }

    if (!forceOpen && _currentMediaUri == safeUri) {
      if (play && !session.player.state.playing && !session._released) {
        await session.player.play();
      }
      return;
    }

    if (session._released) return;
    await session.player.open(Media(safeUri), play: play);
    if (!session._released) {
      _currentMediaUri = safeUri;
    } else {
      unawaited(session.player.pause().catchError((_) {}));
    }
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
  }

  static void _release(TwitchMediaKitPlayerSession session) {
    if (session.generation != _generation) return;

    final player = _player;
    if (player != null) {
      unawaited(player.pause().catchError((_) {}));
    }

    _refCount = (_refCount - 1).clamp(0, 1 << 20).toInt();
    if (_refCount > 0) return;

    // Keep the native player and current media attached after the last
    // WatchPage leaves. Re-entering a stream can resume the same local source
    // without rebuilding media_kit, but audio stays paused while off-page.
  }

  static Future<void> disposeNow() async {
    _refCount = 0;
    await _disposeCurrent();
  }

  static Future<void> _disposeCurrent() async {
    final player = _player;
    _player = null;
    _videoController = null;
    _currentMediaUri = null;
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

  TwitchMediaKitPlayerSession._({
    required Player player,
    required VideoController videoController,
    required int generation,
  })  : _player = player,
        _videoController = videoController,
        _generation = generation,
        _title = 'Twitch Raw Proxy';

  TwitchMediaKitPlayerSession._lazy({
    required String title,
    required int generation,
  })  : _title = title,
        _generation = generation;

  Player get player {
    final value = _player ?? TwitchMediaKitPlayerHost._player;
    if (value == null) {
      throw StateError('TwitchMediaKitPlayerSession is not ready. Call ensureReady() first.');
    }
    return value;
  }

  VideoController get videoController {
    final value = _videoController ?? TwitchMediaKitPlayerHost._videoController;
    if (value == null) {
      throw StateError('TwitchMediaKitPlayerSession is not ready. Call ensureReady() first.');
    }
    return value;
  }

  int get generation => _generation;

  String? get currentMediaUri => TwitchMediaKitPlayerHost.currentMediaUri;

  Future<void> ensureReady() async {
    await TwitchMediaKitPlayerHost._ensureCreated(_title);
    _player = TwitchMediaKitPlayerHost._player;
    _videoController = TwitchMediaKitPlayerHost._videoController;
    _generation = TwitchMediaKitPlayerHost._generation;
  }

  Future<void> openOrResume({
    required String uri,
    bool play = true,
    bool forceOpen = false,
  }) {
    return TwitchMediaKitPlayerHost.openOrResume(
      this,
      uri: uri,
      play: play,
      forceOpen: forceOpen,
    );
  }

  Future<void> pauseCurrent() => TwitchMediaKitPlayerHost.pauseCurrent(this);

  Future<void> stopCurrent() => TwitchMediaKitPlayerHost.stopCurrent(this);

  void release() {
    if (_released) return;
    _released = true;
    TwitchMediaKitPlayerHost._release(this);
  }
}
