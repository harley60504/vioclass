import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TwitchChatAppearanceController extends ChangeNotifier {
  static const String _fontScaleKey = 'twitch_chat_font_scale_v1';

  double _fontScale = 1.0;
  bool _loaded = false;

  double get fontScale => _fontScale;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _fontScale = (prefs.getDouble(_fontScaleKey) ?? 1.0).clamp(0.82, 1.45);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    final next = value.clamp(0.82, 1.45);
    if ((_fontScale - next).abs() < 0.001) return;

    _fontScale = next;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScaleKey, _fontScale);
  }

  Future<void> reset() => setFontScale(1.0);
}
