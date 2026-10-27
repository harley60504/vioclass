import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/playback/twitch_media_kit_player_host.dart';
import '../../services/playback/twitch_video_enhancement.dart';
import '../../platform/android_playback/twitch_android_playback_controller.dart';
import '../watch/controllers/twitch_watch_preferences_controller.dart';

class TwitchPlayerSettingsController extends ChangeNotifier {
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static final gestureSettingsChanged = ChangeNotifier();
  static const keyboardSeekKey = 'twitch_player_keyboard_seek_v1';
  static const doubleTapSeekKey = 'twitch_player_double_tap_seek_v1';
  static const dragSeekKey = 'twitch_player_drag_seek_v1';
  bool _keyboardSeekEnabled = true;
  bool _doubleTapSeekEnabled = true;
  bool _dragSeekEnabled = true;
  bool get keyboardSeekEnabled => _keyboardSeekEnabled;
  bool get doubleTapSeekEnabled => _doubleTapSeekEnabled;
  bool get dragSeekEnabled => _dragSeekEnabled;

  Future<void> reloadGestures() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    _keyboardSeekEnabled = prefs.getBool(keyboardSeekKey) ?? true;
    _doubleTapSeekEnabled = prefs.getBool(doubleTapSeekKey) ?? true;
    _dragSeekEnabled = prefs.getBool(dragSeekKey) ?? true;
    notifyListeners();
  }

  Future<void> _setGesture(String key, bool value) =>
      _queuePlaybackWrite(() async {
        await _saveBoolPreference(key, value);
        await reloadGestures();
        gestureSettingsChanged.notifyListeners();
      });
  Future<void> setKeyboardSeekEnabled(bool value) =>
      _setGesture(keyboardSeekKey, value);
  Future<void> setDoubleTapSeekEnabled(bool value) =>
      _setGesture(doubleTapSeekKey, value);
  Future<void> setDragSeekEnabled(bool value) =>
      _setGesture(dragSeekKey, value);
  static const String androidPipEnabledPreferenceKey =
      'twitch_player_android_pip_enabled_v1';
  static const String homeKeepsMiniPlayerPreferenceKey =
      'twitch_player_home_keeps_mini_player_v1';

  double _volume = 100.0;
  bool _muted = false;
  bool _chatVisible = true;
  bool _androidPipEnabled = true;
  bool _backgroundPlaybackEnabled = false;
  bool _homeKeepsMiniPlayer = true;
  bool _videoEnhancementEnabled = false;
  TwitchVideoEnhancementMode _videoEnhancementMode =
      TwitchVideoEnhancementMode.ewaLanczosSharp;
  bool _videoChromaEnhance = false;
  bool _videoDeband = false;
  bool _videoSharpen = false;
  bool _videoEnhancementBusy = false;
  bool _loaded = false;
  Future<void> _playbackWrites = Future<void>.value();

  double get volume => _volume;
  bool get muted => _muted;
  bool get chatVisible => _chatVisible;
  bool get androidPipEnabled => _androidPipEnabled;
  bool get backgroundPlaybackEnabled => _backgroundPlaybackEnabled;
  bool get homeKeepsMiniPlayer => _homeKeepsMiniPlayer;
  bool get videoEnhancementEnabled => _videoEnhancementEnabled;
  TwitchVideoEnhancementMode get videoEnhancementMode => _videoEnhancementMode;
  bool get videoChromaEnhance => _videoChromaEnhance;
  bool get videoDeband => _videoDeband;
  bool get videoSharpen => _videoSharpen;
  bool get videoEnhancementUsesShader =>
      _videoEnhancementMode.usesShader || _videoChromaEnhance || _videoSharpen;
  bool get videoEnhancementBusy => _videoEnhancementBusy;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    await reloadGestures();
    _volume =
        (prefs.getDouble(
                  TwitchWatchPreferencesController.playerVolumePreferenceKey,
                ) ??
                prefs.getDouble(
                  TwitchWatchPreferencesController
                      .legacyPlayerVolumePreferenceKey,
                ) ??
                100.0)
            .clamp(0.0, 100.0)
            .toDouble();
    _muted =
        prefs.getBool(
          TwitchWatchPreferencesController.playerMutedPreferenceKey,
        ) ??
        prefs.getBool(
          TwitchWatchPreferencesController.legacyPlayerMutedPreferenceKey,
        ) ??
        false;
    _chatVisible =
        prefs.getBool(
          TwitchWatchPreferencesController.chatVisiblePreferenceKey,
        ) ??
        true;
    _androidPipEnabled = prefs.getBool(androidPipEnabledPreferenceKey) ?? true;
    _backgroundPlaybackEnabled =
        prefs.getBool(TwitchAndroidPlaybackController.backgroundEnabledKey) ??
        false;
    await TwitchAndroidPlaybackController.instance.setEnabled(
      _backgroundPlaybackEnabled,
    );
    _homeKeepsMiniPlayer =
        prefs.getBool(homeKeepsMiniPlayerPreferenceKey) ?? true;

    final enhancement = await TwitchVideoEnhancementRuntime.loadPreferences();
    _videoEnhancementEnabled = enhancement.enabled;
    _videoEnhancementMode = enhancement.mode;
    _videoChromaEnhance = enhancement.chromaEnhance;
    _videoDeband = enhancement.deband;
    _videoSharpen = enhancement.sharpen;

    _loaded = true;
    notifyListeners();
  }

  Future<void> setVolume(double value) => _queuePlaybackWrite(() async {
    final next = value.clamp(0.0, 100.0).toDouble();
    if ((_volume - next).abs() < 0.1) return;
    final nextMuted = next <= 0.0 ? true : _muted;
    await _savePlayback(volume: next, muted: nextMuted);
    _volume = next;
    _muted = nextMuted;
    notifyListeners();
  });

  Future<void> setMuted(bool value) => _queuePlaybackWrite(() async {
    if (_muted == value) return;
    await _savePlayback(muted: value);
    _muted = value;
    notifyListeners();
  });

  Future<void> _queuePlaybackWrite(Future<void> Function() write) {
    final result = _playbackWrites.then((_) => write());
    _playbackWrites = result.catchError((Object _) {});
    return result;
  }

  Future<void> setChatVisible(bool value) async {
    if (_chatVisible == value) return;
    await _saveBoolPreference(
      TwitchWatchPreferencesController.chatVisiblePreferenceKey,
      value,
    );
    _chatVisible = value;
    notifyListeners();
  }

  Future<void> setAndroidPipEnabled(bool value) async {
    if (_androidPipEnabled == value) return;
    await _saveBoolPreference(androidPipEnabledPreferenceKey, value);
    _androidPipEnabled = value;
    notifyListeners();
  }

  Future<void> setBackgroundPlaybackEnabled(bool value) async {
    if (_backgroundPlaybackEnabled == value) return;
    await _saveBoolPreference(
      TwitchAndroidPlaybackController.backgroundEnabledKey,
      value,
    );
    _backgroundPlaybackEnabled = value;
    await TwitchAndroidPlaybackController.instance.setEnabled(value);
    notifyListeners();
  }

  Future<void> setHomeKeepsMiniPlayer(bool value) async {
    if (_homeKeepsMiniPlayer == value) return;
    await _saveBoolPreference(homeKeepsMiniPlayerPreferenceKey, value);
    _homeKeepsMiniPlayer = value;
    notifyListeners();
  }

  Future<void> _saveBoolPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (!await prefs.setBool(key, value)) {
        throw StateError('Player preference was not saved');
      }
    } catch (_) {
      // SharedPreferences updates its cache before the platform write finishes.
      await prefs.reload();
      rethrow;
    }
  }

  Future<void> setVideoEnhancementEnabled(bool value) async {
    if (_videoEnhancementBusy || _videoEnhancementEnabled == value) return;
    _videoEnhancementEnabled = value;
    notifyListeners();
    await _saveAndApplyVideoEnhancement();
  }

  Future<void> setVideoEnhancementMode(TwitchVideoEnhancementMode mode) async {
    if (_videoEnhancementBusy || _videoEnhancementMode == mode) return;
    _videoEnhancementMode = mode;
    notifyListeners();
    await _saveAndApplyVideoEnhancement();
  }

  Future<void> setVideoChromaEnhance(bool value) async {
    if (_videoEnhancementBusy || _videoChromaEnhance == value) return;
    _videoChromaEnhance = value;
    notifyListeners();
    await _saveAndApplyVideoEnhancement();
  }

  Future<void> setVideoDeband(bool value) async {
    if (_videoEnhancementBusy || _videoDeband == value) return;
    _videoDeband = value;
    notifyListeners();
    await _saveAndApplyVideoEnhancement();
  }

  Future<void> setVideoSharpen(bool value) async {
    if (_videoEnhancementBusy || _videoSharpen == value) return;
    _videoSharpen = value;
    notifyListeners();
    await _saveAndApplyVideoEnhancement();
  }

  Future<void> _saveAndApplyVideoEnhancement() async {
    _videoEnhancementBusy = true;
    notifyListeners();
    try {
      await TwitchVideoEnhancementRuntime.saveAndApply(
        player: TwitchMediaKitPlayerHost.playerOrNull,
        enabled: _videoEnhancementEnabled,
        mode: _videoEnhancementMode,
        chromaEnhance: _videoChromaEnhance,
        deband: _videoDeband,
        sharpen: _videoSharpen,
      );
    } catch (_) {
      final saved = TwitchVideoEnhancementRuntime.config;
      _videoEnhancementEnabled = saved.enabled;
      _videoEnhancementMode = saved.mode;
      _videoChromaEnhance = saved.chromaEnhance;
      _videoDeband = saved.deband;
      _videoSharpen = saved.sharpen;
      rethrow;
    } finally {
      _videoEnhancementBusy = false;
      notifyListeners();
    }
  }

  Future<void> resetPlayback() => _queuePlaybackWrite(() async {
    if (_videoEnhancementBusy) return;
    final prefs = await SharedPreferences.getInstance();
    const volumeKey =
        TwitchWatchPreferencesController.playerVolumePreferenceKey;
    const mutedKey = TwitchWatchPreferencesController.playerMutedPreferenceKey;
    final previousVolume = prefs.getDouble(volumeKey);
    final previousMuted = prefs.getBool(mutedKey);
    await _savePlayback(volume: 100, muted: false);
    _videoEnhancementEnabled = false;
    _videoEnhancementMode = TwitchVideoEnhancementMode.ewaLanczosSharp;
    _videoChromaEnhance = false;
    _videoDeband = false;
    _videoSharpen = false;
    try {
      await _saveAndApplyVideoEnhancement();
    } catch (_) {
      try {
        final restoredVolume = previousVolume == null
            ? await prefs.remove(volumeKey)
            : await prefs.setDouble(volumeKey, previousVolume);
        final restoredMuted = previousMuted == null
            ? await prefs.remove(mutedKey)
            : await prefs.setBool(mutedKey, previousMuted);
        if (!restoredVolume || !restoredMuted) {
          throw StateError('Playback reset rollback failed');
        }
      } finally {
        await prefs.reload();
      }
      rethrow;
    }
    _volume = 100;
    _muted = false;
    notifyListeners();
  });

  Future<void> _savePlayback({double? volume, bool? muted}) async {
    final prefs = await SharedPreferences.getInstance();
    const volumeKey =
        TwitchWatchPreferencesController.playerVolumePreferenceKey;
    const mutedKey = TwitchWatchPreferencesController.playerMutedPreferenceKey;
    final previousVolume = prefs.getDouble(volumeKey);
    final previousMuted = prefs.getBool(mutedKey);
    try {
      if (!await prefs.setDouble(
        volumeKey,
        (volume ?? _volume).clamp(0.0, 100.0).toDouble(),
      )) {
        throw StateError('Player volume was not saved');
      }
      if (!await prefs.setBool(mutedKey, muted ?? _muted)) {
        throw StateError('Player mute preference was not saved');
      }
    } catch (_) {
      // The two preference writes are not atomic; restore a partial write.
      try {
        final restoredVolume = previousVolume == null
            ? await prefs.remove(volumeKey)
            : await prefs.setDouble(volumeKey, previousVolume);
        final restoredMuted = previousMuted == null
            ? await prefs.remove(mutedKey)
            : await prefs.setBool(mutedKey, previousMuted);
        if (!restoredVolume || !restoredMuted) {
          throw StateError('Playback preference rollback failed');
        }
      } finally {
        await prefs.reload();
      }
      rethrow;
    }
  }
}
