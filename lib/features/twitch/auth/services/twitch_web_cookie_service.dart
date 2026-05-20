import 'package:shared_preferences/shared_preferences.dart';

class TwitchWebCookieService {
  const TwitchWebCookieService._();

  static const List<String> tokenKeys = <String>[
    'twitch_access_token',
    'twitch_auth_token',
    'twitch_oauth_token',
    'twitch_web_auth_token',
    'twitch_web_access_token',
    'twitch_web_cookie_auth_token',
  ];

  static Future<String?> readAuthToken() async {
    final prefs = await SharedPreferences.getInstance();

    for (final key in tokenKeys) {
      final value = prefs.getString(key)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }

    return null;
  }

  static Future<void> saveAuthToken(String token) async {
    final clean = token.trim();
    if (clean.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('twitch_web_auth_token', clean);
    await prefs.setString('twitch_access_token', clean);
  }

  static Future<void> clearCookies() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in tokenKeys) {
      await prefs.remove(key);
    }
  }
}
