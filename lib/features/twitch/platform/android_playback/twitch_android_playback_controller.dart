import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Canonical display times, not the native timestamps of a DVR segment.
class TwitchAndroidMediaState {
  const TwitchAndroidMediaState({
    required this.id,
    required this.title,
    required this.artist,
    this.artworkUrl = '',
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.minimum = Duration.zero,
    this.seekable = false,
    this.rate = 1,
    this.buffering = false,
  });

  final String id, title, artist, artworkUrl;
  final Duration position, duration, minimum;
  final bool seekable, buffering;
  final double rate;

  int get minimumMs => minimum.inMilliseconds.clamp(0, duration.inMilliseconds);

  Map<String, Object> toMap() => {
    'id': id,
    'title': title,
    'artist': artist,
    'artworkUrl': artworkUrl,
    'position': (position.inMilliseconds - minimumMs).clamp(
      0,
      duration.inMilliseconds - minimumMs,
    ),
    'duration': seekable ? duration.inMilliseconds - minimumMs : 0,
    'seekable': seekable && duration > Duration.zero,
    'rate': rate,
    'buffering': buffering,
  };
}

/// The native mediaPlayback service grants foreground playback its proper
/// Android process/network lifecycle. It does not store account information.
class TwitchAndroidPlaybackController {
  TwitchAndroidPlaybackController._() {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'stopPlayback') {
        _pausedFromControls = true;
        await onStopRequested?.call();
      }
      if (call.method == 'playPlayback') {
        _pausedFromControls = false;
        await onPlayRequested?.call();
      }
      if (call.method == 'pausePlayback') {
        _pausedFromControls = true;
        await onPauseRequested?.call();
      }
      if (call.method == 'seekPlayback') {
        final args = call.arguments;
        final media = _media;
        if (!_enabled ||
            !_hasMedia ||
            media == null ||
            !media.seekable ||
            media.duration <= Duration.zero ||
            args is! Map ||
            args['id'] != media.id ||
            args['position'] is! num) {
          return;
        }
        final target = ((args['position'] as num).toInt() + media.minimumMs)
            .clamp(media.minimumMs, media.duration.inMilliseconds);
        await onSeekRequested?.call(Duration(milliseconds: target));
      }
    });
  }

  static final instance = TwitchAndroidPlaybackController._();
  static const channel = MethodChannel('vio_class/playback_service');
  static const backgroundEnabledKey = 'twitch_player_background_playback_v1';
  Future<void> Function()? onStopRequested;
  Future<void> Function()? onPlayRequested;
  Future<void> Function()? onPauseRequested;
  Future<void> Function(Duration)? onSeekRequested;
  TwitchAndroidMediaState? _media;
  int _mediaRevision = 0;
  int _appliedMediaRevision = -1;
  Future<void> _pending = Future<void>.value();
  (bool, bool)? _applied;
  bool _enabled = false;
  bool _playing = false;
  bool _hasMedia = false;
  bool _pausedFromControls = false;
  bool get enabled => _enabled;
  bool get pausedFromControls => _pausedFromControls;
  int _revision = 0;

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await setEnabled(prefs.getBool(backgroundEnabledKey) ?? false);
  }

  Future<void> setEnabled(bool enabled) {
    _enabled = enabled;
    return _sync();
  }

  Future<void> clearMedia() {
    _media = null;
    _mediaRevision++;
    _hasMedia = false;
    _playing = false;
    return _sync();
  }

  Future<void> setMedia(TwitchAndroidMediaState media) {
    _media = media;
    _mediaRevision++;
    return _sync();
  }

  Future<void> setActive(bool playing) {
    _playing = playing;
    if (playing) _pausedFromControls = false;
    if (playing) _hasMedia = true;
    return _sync();
  }

  Future<void> _sync() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return Future<void>.value();
    }
    final revision = ++_revision;
    return _pending = _pending.then((_) async {
      final desired = (_enabled && _hasMedia, _playing);
      if (revision != _revision ||
          (_applied == desired &&
              (!desired.$1 || _appliedMediaRevision == _mediaRevision))) {
        return;
      }
      try {
        final mediaRevision = _mediaRevision;
        await channel.invokeMethod<void>('setActive', {
          'active': desired.$1,
          'playing': desired.$2,
          'media': _media?.toMap(),
        });
        _applied = desired;
        _appliedMediaRevision = mediaRevision;
      } catch (error) {
        _applied = null;
        debugPrint('[PlaybackService] sync failed type=${error.runtimeType}');
      }
    });
  }
}
