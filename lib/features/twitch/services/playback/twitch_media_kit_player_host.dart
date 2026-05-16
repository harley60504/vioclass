import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class TwitchMediaKitPlayerHost {
  static Player? _player;
  static VideoController? _videoController;
  static int _refCount = 0;
  static int _generation = 0;
  static String? _currentMediaUri;

  TwitchMediaKitPlayerHost._();

  static String? get currentMediaUri => _currentMediaUri;

  static TwitchMediaKitPlayerSession acquire({
    String title = 'Twitch Raw Proxy',
  }) {
    MediaKit.ensureInitialized();

    var player = _player;
    var controller = _videoController;

    if (player == null || controller == null) {
      _generation++;
      _currentMediaUri = null;
      player = Player(
        configuration: PlayerConfiguration(
          title: title,
          bufferSize: 16 * 1024 * 1024,
          logLevel: kDebugMode ? MPVLogLevel.warn : MPVLogLevel.error,
        ),
      );
      controller = VideoController(
        player,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
          androidAttachSurfaceAfterVideoParameters: false,
          hwdec: 'auto-safe',
        ),
      );
      _player = player;
      _videoController = controller;
    }

    _refCount++;

    return TwitchMediaKitPlayerSession._(
      player: player,
      videoController: controller,
      generation: _generation,
    );
  }

  static Future<void> openOrResume(
    TwitchMediaKitPlayerSession session, {
    required String uri,
    bool play = true,
    bool forceOpen = false,
  }) async {
    if (session.generation != _generation) {
      throw StateError('Stale Twitch media_kit player session.');
    }

    final safeUri = uri.trim();
    if (safeUri.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'uri cannot be empty');
    }

    if (!forceOpen && _currentMediaUri == safeUri) {
      if (play && !session.player.state.playing) {
        await session.player.play();
      }
      return;
    }

    await session.player.open(Media(safeUri), play: play);
    _currentMediaUri = safeUri;
  }

  static Future<void> pauseCurrent(TwitchMediaKitPlayerSession session) async {
    if (session.generation != _generation) return;
    await session.player.pause();
  }

  static Future<void> stopCurrent(TwitchMediaKitPlayerSession session) async {
    if (session.generation != _generation) return;
    await session.player.stop();
    _currentMediaUri = null;
  }

  static void _release(TwitchMediaKitPlayerSession session) {
    if (session.generation != _generation) return;

    _refCount = (_refCount - 1).clamp(0, 1 << 20).toInt();
    if (_refCount > 0) return;

    // Keep the native player and current media attached. Only pause audio when
    // the last WatchPage leaves, so returning to a page can resume the same
    // local source instead of reopening media_kit.
    unawaited(session.player.pause().catchError((_) {}));
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
  final Player player;
  final VideoController videoController;
  final int generation;

  bool _released = false;

  TwitchMediaKitPlayerSession._({
    required this.player,
    required this.videoController,
    required this.generation,
  });

  String? get currentMediaUri => TwitchMediaKitPlayerHost.currentMediaUri;

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
