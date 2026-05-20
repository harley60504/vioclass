import 'package:shared_preferences/shared_preferences.dart';

class TwitchWebCookieService {
  const TwitchWebCookieService._();

  static Future<String?> readAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    const keys = <String>[
      'twitch_access_token',
      'twitch_auth_token',
      'twitch_oauth_token',
      'twitch_web_auth_token',
      'twitch_web_access_token',
    ];

    for (final key in keys) {
      final value = prefs.getString(key)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }

    return null;
  }
}
