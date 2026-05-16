// PATCH VERSION: twitch_media_kit_player_host_stage112_compile_safe

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Shared media_kit player host for Twitch watch pages.
///
/// PiliPlus keeps a player controller instance around and only releases the
/// underlying player when the final owner leaves. This host applies the same
/// idea in a lightweight way:
///
/// - WatchPage calls [acquire] during initState.
/// - WatchPage calls [TwitchMediaKitPlayerSession.release] during dispose.
/// - The Player / VideoController are not disposed immediately; they stay warm
///   for a short grace period so returning to another stream does not cold-start
///   libmpv / texture / decoder again.
class TwitchMediaKitPlayerHost {
  static const Duration _releaseGracePeriod = Duration(seconds: 24);

  static Player? _player;
  static VideoController? _videoController;
  static Timer? _disposeTimer;
  static int _refCount = 0;
  static int _generation = 0;

  TwitchMediaKitPlayerHost._();

  static TwitchMediaKitPlayerSession acquire({
    String title = 'Twitch Raw Proxy',
  }) {
    MediaKit.ensureInitialized();

    _disposeTimer?.cancel();
    _disposeTimer = null;

    var player = _player;
    var controller = _videoController;

    if (player == null || controller == null) {
      _generation++;
      player = Player(
        configuration: PlayerConfiguration(
          title: title,
          bufferSize: defaultTargetPlatform == TargetPlatform.android
              ? 16 * 1024 * 1024
              : 8 * 1024 * 1024,
        ),
      );
      controller = VideoController(player);
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

  static void _release(TwitchMediaKitPlayerSession session) {
    if (session.generation != _generation) return;

    _refCount = (_refCount - 1).clamp(0, 1 << 20).toInt();
    if (_refCount > 0) return;

    _disposeTimer?.cancel();
    _disposeTimer = Timer(_releaseGracePeriod, () {
      if (_refCount > 0) return;
      unawaited(_disposeCurrent());
    });
  }

  static Future<void> disposeNow() async {
    _disposeTimer?.cancel();
    _disposeTimer = null;
    _refCount = 0;
    await _disposeCurrent();
  }

  static Future<void> _disposeCurrent() async {
    final player = _player;
    _player = null;
    _videoController = null;
    _generation++;

    if (player == null) return;

    try {
      await player.pause();
    } catch (_) {
      // Ignore best-effort pause failures during shutdown.
    }

    try {
      await player.dispose();
    } catch (_) {
      // Ignore best-effort dispose failures during shutdown.
    }
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

  void release() {
    if (_released) return;
    _released = true;
    TwitchMediaKitPlayerHost._release(this);
  }
}
