// PATCH VERSION: twitch_media_kit_player_host_stage115_piliplus_like_media_params

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Shared media_kit player host for Twitch watch pages.
///
/// This intentionally follows the PiliPlus-style direction more closely:
/// keep one app-level Player / VideoController instance alive and reuse it
/// across WatchPage entries. A WatchPage release stops audible playback, but it
/// does not dispose the native media_kit/libmpv/texture stack.
///
/// The player is disposed only by [disposeNow], which should be reserved for
/// explicit shutdown / severe recovery cases.
class TwitchMediaKitPlayerHost {
  static Player? _player;
  static VideoController? _videoController;
  static int _refCount = 0;
  static int _generation = 0;

  TwitchMediaKitPlayerHost._();

  static TwitchMediaKitPlayerSession acquire({
    String title = 'Twitch Raw Proxy',
  }) {
    MediaKit.ensureInitialized();

    var player = _player;
    var controller = _videoController;

    if (player == null || controller == null) {
      _generation++;
      player = Player(
        configuration: PlayerConfiguration(
          title: title,
          // PiliPlus live default is 16 MiB when expanded buffer is off.
          // Twitch is always live in this WatchPage path, so use the same
          // live baseline on all platforms instead of a smaller desktop value.
          bufferSize: 16 * 1024 * 1024,
          logLevel: kDebugMode ? MPVLogLevel.warn : MPVLogLevel.error,
        ),
      );
      controller = VideoController(
        player,
        configuration: const VideoControllerConfiguration(
          // Same direction as PiliPlus: keep hardware rendering enabled and
          // make Android surface attachment less conservative for faster first
          // frame / fewer texture attach stalls on some devices.
          enableHardwareAcceleration: true,
          androidAttachSurfaceAfterVideoParameters: false,
          // media_kit's Android default is auto-safe. Set it explicitly so the
          // current app behavior is deterministic and easier to tune later.
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

  static void _release(TwitchMediaKitPlayerSession session) {
    if (session.generation != _generation) return;

    _refCount = (_refCount - 1).clamp(0, 1 << 20).toInt();
    if (_refCount > 0) return;

    // Stop audible playback immediately when the final WatchPage leaves, but
    // keep the native player object alive. WatchPage already calls stop()
    // before release, so this is an additional safety pause.
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
