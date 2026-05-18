// Stage 220A: Independent media_kit engine for Twitch player core.
//
// This engine owns the media_kit Player + VideoController pair. It intentionally
// exposes only a small API so WatchPage can later depend on a controller instead
// of directly owning media_kit objects.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'twitch_player_profile.dart';

class TwitchMediaKitPlayerEngine {
  final TwitchPlayerProfile profile;
  final String title;

  Player? _player;
  VideoController? _videoController;
  String? _currentUri;
  bool _disposed = false;

  TwitchMediaKitPlayerEngine({
    required this.profile,
    this.title = 'StreamNook Twitch Player',
  });

  bool get initialized => _player != null && _videoController != null;
  bool get disposed => _disposed;
  String? get currentUri => _currentUri;

  Player get player {
    final value = _player;
    if (value == null) {
      throw StateError('TwitchMediaKitPlayerEngine has not been initialized.');
    }
    return value;
  }

  VideoController get videoController {
    final value = _videoController;
    if (value == null) {
      throw StateError('TwitchMediaKitPlayerEngine has not been initialized.');
    }
    return value;
  }

  Future<void> ensureInitialized() async {
    if (_disposed) {
      throw StateError('TwitchMediaKitPlayerEngine has been disposed.');
    }
    if (initialized) return;

    MediaKit.ensureInitialized();

    final player = await Player.create(
      configuration: PlayerConfiguration(
        title: title,
        bufferSize: profile.bufferSize,
        logLevel: kDebugMode ? MPVLogLevel.warn : MPVLogLevel.error,
        options: profile.mpvOptions,
      ),
    );

    final controller = await VideoController.create(
      player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: profile.enableHardwareAcceleration,
        androidAttachSurfaceAfterVideoParameters:
            profile.androidAttachSurfaceAfterVideoParameters,
        hwdec: profile.hwdec,
      ),
    );

    _player = player;
    _videoController = controller;
  }

  Future<void> open({
    required String uri,
    bool play = true,
    bool force = false,
  }) async {
    await ensureInitialized();
    if (_disposed) return;

    final safeUri = uri.trim();
    if (safeUri.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'uri cannot be empty');
    }

    final p = player;
    if (!force && _currentUri == safeUri) {
      if (play && !p.state.playing) {
        await p.play();
      }
      return;
    }

    await p.open(Media(safeUri), play: play);
    _currentUri = safeUri;
  }

  Future<void> play() async {
    if (!initialized || _disposed) return;
    await player.play();
  }

  Future<void> pause() async {
    if (!initialized || _disposed) return;
    await player.pause();
  }

  Future<void> stop() async {
    if (!initialized || _disposed) return;
    await player.stop();
    _currentUri = null;
  }

  Future<void> setVolume(double volume) async {
    if (!initialized || _disposed) return;
    await player.setVolume(volume.clamp(0.0, 100.0).toDouble());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    final p = _player;
    _player = null;
    _videoController = null;
    _currentUri = null;

    if (p == null) return;

    try {
      await p.pause();
    } catch (_) {}

    try {
      await p.dispose();
    } catch (_) {}
  }
}
