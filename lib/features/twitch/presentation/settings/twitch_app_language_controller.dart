import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TwitchAppLanguageMode { system, zhTw, en }

class TwitchAppLanguageController extends ChangeNotifier {
  static const String _selectedLanguageKey = 'twitch_app_language_selected_v1';

  TwitchAppLanguageMode _mode = TwitchAppLanguageMode.system;
  bool _loaded = false;

  bool get loaded => _loaded;
  TwitchAppLanguageMode get mode => _mode;

  Locale? get locale {
    return switch (_mode) {
      TwitchAppLanguageMode.system => null,
      TwitchAppLanguageMode.zhTw => const Locale('zh', 'TW'),
      TwitchAppLanguageMode.en => const Locale('en'),
    };
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _mode = _modeFromId(prefs.getString(_selectedLanguageKey));
    _loaded = true;
    notifyListeners();
  }

  Future<void> select(TwitchAppLanguageMode mode) async {
    if (mode == _mode) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      if (!await prefs.setString(_selectedLanguageKey, mode.id)) {
        throw StateError('Language selection was not saved');
      }
    } catch (_) {
      await prefs.reload();
      rethrow;
    }
    _mode = mode;
    notifyListeners();
  }

  TwitchAppLanguageMode _modeFromId(String? id) {
    return switch (id) {
      'zhTw' => TwitchAppLanguageMode.zhTw,
      'en' => TwitchAppLanguageMode.en,
      _ => TwitchAppLanguageMode.system,
    };
  }
}

extension TwitchAppLanguageModeInfo on TwitchAppLanguageMode {
  String get id {
    return switch (this) {
      TwitchAppLanguageMode.system => 'system',
      TwitchAppLanguageMode.zhTw => 'zhTw',
      TwitchAppLanguageMode.en => 'en',
    };
  }
}

final TwitchAppLanguageController twitchAppLanguageController =
    TwitchAppLanguageController();
