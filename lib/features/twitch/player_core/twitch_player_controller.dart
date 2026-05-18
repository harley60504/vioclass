// Stage 220F: Independent Twitch player controller.
//
// Design goals:
// - Keep media_kit lifecycle out of WatchPage.
// - Centralize play / pause / volume / mute / open source operations.
// - Reduce UI rebuild pressure by publishing position / buffered changes only
//   when their second value changes, similar to PiliPlus' player controller.
//
// PiliPlus media_kit stream compatibility:
// - PlayerStream exposes playing / completed / position / duration / buffer /
//   buffering / log / error.
// - It does not expose volume / width / height streams, so volume is maintained
//   by this controller and video size is left as an optional future probe.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'twitch_media_kit_player_engine.dart';
import 'twitch_player_profile.dart';
import 'twitch_player_state.dart';

class TwitchPlayerController extends ChangeNotifier {
  final TwitchMediaKitPlayerEngine engine;

  TwitchPlayerState _state;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  bool _disposed = false;
  bool _listenersAttached = false;
  double _lastNonZeroVolume = 100.0;
  int _lastPublishedPositionSecond = -1;
  int _lastPublishedBufferedSecond = -1;

  TwitchPlayerController({
    TwitchPlayerProfile? profile,
    TwitchMediaKitPlayerEngine? engine,
  })  : engine = engine ??
            TwitchMediaKitPlayerEngine(
              profile: profile ?? TwitchPlayerProfile.forCurrentPlatform(),
            ),
        _state = TwitchPlayerState.initial(
          profile ?? TwitchPlayerProfile.forCurrentPlatform(),
        );

  TwitchPlayerState get state => _state;
  bool get initialized => engine.initialized;

  Player? get playerOrNull {
    if (!engine.initialized || engine.disposed) return null;
    return engine.player;
  }

  VideoController? get videoControllerOrNull {
    if (!engine.initialized || engine.disposed) return null;
    return engine.videoController;
  }

  Future<void> initialize() async {
    if (_disposed) return;
    if (_state.initialized) return;

    await engine.ensureInitialized();
    _attachPlayerListeners();
    _emit(_state.copyWith(initialized: true, profile: engine.profile));
  }

  Future<void> open({
    required String uri,
    bool play = true,
    bool force = false,
  }) async {
    if (_disposed) return;

    final safeUri = uri.trim();
    if (safeUri.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'uri cannot be empty');
    }

    _emit(_state.copyWith(
      opening: true,
      clearError: true,
      mediaUri: safeUri,
      clearVideoSize: force || _state.mediaUri != safeUri,
    ));

    try {
      await initialize();
      await engine.open(uri: safeUri, play: play, force: force);
      _emit(_state.copyWith(
        opening: false,
        mediaUri: safeUri,
        clearError: true,
      ));
    } catch (error) {
      _emit(_state.copyWith(opening: false, error: error));
      rethrow;
    }
  }

  Future<void> play() async {
    await initialize();
    await engine.play();
  }

  Future<void> pause() async {
    if (!initialized) return;
    await engine.pause();
  }

  Future<void> togglePlayPause() async {
    if (_state.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> stop() async {
    if (!initialized) return;
    await engine.stop();
    _lastPublishedPositionSecond = -1;
    _lastPublishedBufferedSecond = -1;
    _emit(_state.copyWith(
      playing: false,
      buffering: false,
      position: Duration.zero,
      buffered: Duration.zero,
      clearMediaUri: true,
      clearVideoSize: true,
    ));
  }

  Future<void> setVolume(double value) async {
    final next = value.clamp(0.0, 100.0).toDouble();
    if (next > 0) _lastNonZeroVolume = next;
    _emit(_state.copyWith(volume: next, muted: next <= 0));
    await initialize();
    await engine.setVolume(next);
  }

  Future<void> setMuted(bool muted) async {
    if (muted) {
      _emit(_state.copyWith(muted: true, volume: 0.0));
      await initialize();
      await engine.setVolume(0.0);
      return;
    }

    final next = (_lastNonZeroVolume <= 0 ? 100.0 : _lastNonZeroVolume)
        .clamp(1.0, 100.0)
        .toDouble();
    _emit(_state.copyWith(muted: false, volume: next));
    await initialize();
    await engine.setVolume(next);
  }

  Future<void> toggleMute() => setMuted(!_state.muted);

  void _attachPlayerListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    final player = engine.player;
    final stream = player.stream;

    _subscriptions.add(stream.playing.listen((playing) {
      _emit(_state.copyWith(playing: playing));
    }));

    _subscriptions.add(stream.completed.listen((completed) {
      if (!completed) return;
      _emit(_state.copyWith(playing: false, buffering: false));
    }));

    _subscriptions.add(stream.position.listen((position) {
      final second = position.inSeconds;
      if (second == _lastPublishedPositionSecond) return;
      _lastPublishedPositionSecond = second;
      _emit(_state.copyWith(position: position));
    }));

    _subscriptions.add(stream.duration.listen((duration) {
      _emit(_state.copyWith(duration: duration));
    }));

    _subscriptions.add(stream.buffer.listen((buffered) {
      final second = buffered.inSeconds;
      if (second == _lastPublishedBufferedSecond) return;
      _lastPublishedBufferedSecond = second;
      _emit(_state.copyWith(buffered: buffered));
    }));

    _subscriptions.add(stream.buffering.listen((buffering) {
      _emit(_state.copyWith(buffering: buffering));
    }));

    if (kDebugMode) {
      _subscriptions.add(stream.log.listen((log) {
        final text = log.toString();
        if (text.contains('error') || text.contains('fatal')) {
          debugPrint('[TwitchPlayerCore][mpv] $text');
        }
      }));
    }

    _subscriptions.add(stream.error.listen((error) {
      _emit(_state.copyWith(error: error));
    }));
  }

  void _emit(TwitchPlayerState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  Future<void> disposeAsync() async {
    if (_disposed) return;
    _disposed = true;

    for (final subscription
        in List<StreamSubscription<dynamic>>.from(_subscriptions)) {
      try {
        await subscription.cancel();
      } catch (_) {}
    }
    _subscriptions.clear();

    await engine.dispose();
    super.dispose();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    for (final subscription
        in List<StreamSubscription<dynamic>>.from(_subscriptions)) {
      unawaited(subscription.cancel().catchError((_) {}));
    }
    _subscriptions.clear();

    unawaited(engine.dispose());
    super.dispose();
  }
}
