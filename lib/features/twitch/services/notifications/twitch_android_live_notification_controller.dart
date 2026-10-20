import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../models/discovery/twitch_live_stream.dart';
import 'twitch_system_notification_service.dart';

/// Only public followed channel names are sent to Android's persistent worker.
/// OAuth, refresh tokens and cookies remain in the existing auth services.
class TwitchAndroidLiveNotificationController extends ChangeNotifier {
  static final instance = TwitchAndroidLiveNotificationController();
  static const preferenceKey = 'vioclass_android_live_notifications_v1';
  static const channel = MethodChannel('vio_class/background_receiving');
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool enabled = true;
  bool busy = false;
  String? errorText;
  String? _owner;
  List<String> _channels = [];
  int _generation = 0;
  bool _loaded = false;

  Future<void> load() async {
    if (!supported || _loaded) return;
    enabled =
        (await SharedPreferences.getInstance()).getBool(preferenceKey) ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setSession({
    required String? owner,
    Future<TwitchFollowedChannelPageResult> Function(String? after)? fetchPage,
  }) async {
    if (!supported) return;
    final generation = ++_generation;
    final changedOwner = _owner != owner;
    _owner = owner;
    if (changedOwner) _channels = [];
    try {
      await load();
      if (generation != _generation) return;
      // Cancel the old account immediately, before awaiting follows requests.
      if (changedOwner || owner == null) {
        await _configure(preserveExisting: owner != null);
      }
      if (owner == null || fetchPage == null) return;
      final channels = <String>{};
      final cursors = <String>{};
      String? cursor;
      do {
        final page = await fetchPage(cursor);
        if (generation != _generation) return;
        channels.addAll(page.channels.map((item) => item.broadcasterLogin));
        cursor = page.cursor;
        if (cursor != null && cursor.isNotEmpty && !cursors.add(cursor)) {
          throw StateError('Repeated follows cursor');
        }
      } while (cursor != null && cursor.isNotEmpty);
      _channels = channels.toList()..sort();
      await _configure();
      errorText = null;
    } catch (_) {
      if (generation == _generation) errorText = '開台通知同步未完成，請重新檢查登入或網路。';
    }
    if (generation == _generation) notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (!supported || busy) return;
    busy = true;
    var previous = enabled;
    errorText = null;
    notifyListeners();
    try {
      await load();
      previous = enabled;
      if (value &&
          await twitchSystemNotificationService.notificationPermission(
                request: true,
              ) !=
              true) {
        errorText = '系統通知未允許，請前往系統通知設定開啟。';
        return;
      }
      enabled = value;
      await _configure();
      if (!await (await SharedPreferences.getInstance()).setBool(
        preferenceKey,
        value,
      )) {
        throw StateError('Preference was not saved');
      }
    } catch (_) {
      enabled = previous;
      try {
        await _configure();
      } catch (_) {
        // Preserve the failure state instead of claiming a native change.
      }
      errorText = '開台通知設定未完成，請稍後重試。';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _configure({bool preserveExisting = false}) async {
    final applied = await channel.invokeMethod<bool>('configureLive', {
      'owner': _owner,
      'channels': _channels,
      'enabled': enabled,
      'clientId': TwitchApiConstants.twitchAndroidPublicClientId,
      'preserveExisting': preserveExisting,
    });
    if (applied != true) throw StateError('Live schedule was not applied');
  }
}
