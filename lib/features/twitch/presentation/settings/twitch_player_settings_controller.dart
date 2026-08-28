import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../watch/controllers/twitch_watch_preferences_controller.dart';

class TwitchPlayerSettingsController extends ChangeNotifier {
  static const String androidPipEnabledPreferenceKey =
      'twitch_player_android_pip_enabled_v1';
  static const String homeKeepsMiniPlayerPreferenceKey =
      'twitch_player_home_keeps_mini_player_v1';

  double _volume = 100.0;
  bool _muted = false;
  bool _chatVisible = true;
  bool _androidPipEnabled = true;
  bool _homeKeepsMiniPlayer = true;
  bool _loaded = false;

  double get volume => _volume;
  bool get muted => _muted;
  bool get chatVisible => _chatVisible;
  bool get androidPipEnabled => _androidPipEnabled;
  bool get homeKeepsMiniPlayer => _homeKeepsMiniPlayer;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
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
    _homeKeepsMiniPlayer =
        prefs.getBool(homeKeepsMiniPlayerPreferenceKey) ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setVolume(double value) async {
    final next = value.clamp(0.0, 100.0).toDouble();
    if ((_volume - next).abs() < 0.1) return;
    _volume = next;
    if (next <= 0.0) _muted = true;
    notifyListeners();
    await _savePlayback();
  }

  Future<void> setMuted(bool value) async {
    if (_muted == value) return;
    _muted = value;
    notifyListeners();
    await _savePlayback();
  }

  Future<void> setChatVisible(bool value) async {
    if (_chatVisible == value) return;
    _chatVisible = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      TwitchWatchPreferencesController.chatVisiblePreferenceKey,
      _chatVisible,
    );
  }

  Future<void> setAndroidPipEnabled(bool value) async {
    if (_androidPipEnabled == value) return;
    _androidPipEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(androidPipEnabledPreferenceKey, _androidPipEnabled);
  }

  Future<void> setHomeKeepsMiniPlayer(bool value) async {
    if (_homeKeepsMiniPlayer == value) return;
    _homeKeepsMiniPlayer = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(homeKeepsMiniPlayerPreferenceKey, _homeKeepsMiniPlayer);
  }

  Future<void> resetPlayback() async {
    _volume = 100.0;
    _muted = false;
    notifyListeners();
    await _savePlayback();
  }

  Future<void> _savePlayback() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      TwitchWatchPreferencesController.playerVolumePreferenceKey,
      _volume.clamp(0.0, 100.0).toDouble(),
    );
    await prefs.setBool(
      TwitchWatchPreferencesController.playerMutedPreferenceKey,
      _muted,
    );
  }
}
