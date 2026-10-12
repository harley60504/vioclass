import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Notification metadata only: no OAuth tokens, cookies or whisper bodies.
class TwitchNotificationHistoryStore {
  static const key = 'vioclass_notification_history_v1';
  static const retention = Duration(days: 7);
  static const capacity = 20;

  Future<List<Map<String, dynamic>>> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = jsonDecode(prefs.getString(key) ?? '[]');
      if (value is! List) return [];
      return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> write(List<Map<String, dynamic>> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(entries));
  }
}
