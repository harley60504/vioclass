import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'twitch_system_notification_service.dart';

/// Keeps the existing receiver isolate alive; never starts a second receiver.
class TwitchAndroidBackgroundController extends ChangeNotifier {
  static const nativeChannel = MethodChannel('vio_class/background_receiving');
  TwitchAndroidBackgroundController({
    Future<bool?> Function(bool request)? notificationPermission,
    Future<bool> Function()? openNotificationSettings,
  }) : _notificationPermission =
           notificationPermission ??
           ((request) => twitchSystemNotificationService.notificationPermission(
             request: request,
           )),
       _openNotificationSettings =
           openNotificationSettings ??
           twitchSystemNotificationService.openNotificationSettings;

  final Future<bool?> Function(bool request) _notificationPermission;
  final Future<bool> Function() _openNotificationSettings;
  bool? notificationsAllowed;
  static final instance = TwitchAndroidBackgroundController();
  static const preferenceKey = 'vioclass_android_background_receiving_v1';
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool enabled = false;
  bool running = false;
  bool busy = false;
  String? errorText;
  bool _loaded = false;
  bool _foreground = true;
  String? _owner;
  Future<void> _queue = Future<void>.value();

  Future<void> _serialize(Future<void> Function() action) {
    final next = _queue.then((_) async {
      busy = true;
      notifyListeners();
      try {
        await action();
      } catch (_) {
        errorText = '背景收件設定未完成，請稍後重試。';
      } finally {
        busy = false;
        notifyListeners();
      }
    });
    _queue = next;
    return next;
  }

  Future<void> load() => _serialize(() async {
    if (!supported || _loaded) return;
    enabled =
        (await SharedPreferences.getInstance()).getBool(preferenceKey) ?? false;
    _loaded = true;
    await _reconcile();
  });

  Future<void> setSession({
    required String? ownerId,
    required bool foreground,
  }) {
    final changed = _owner != ownerId || _foreground != foreground;
    _owner = ownerId;
    _foreground = foreground;
    if (!supported || !changed) return Future<void>.value();
    return _serialize(() => _reconcile());
  }

  Future<void> setEnabled(bool value) => _serialize(() async {
    if (!supported) return;
    errorText = null;
    if (value && _owner == null) {
      errorText = '請先登入 Twitch，再開啟背景收件。';
      return;
    }
    if (value && !await _checkNotificationPermission(request: true)) return;
    enabled = value;
    try {
      await _reconcile(allowPermissionPrompt: value);
    } catch (_) {
      errorText = '背景收件設定未完成，請檢查系統權限後重試。';
    }
    // A permission dialog may return before Flutter reports resumed. Keep the
    // opt-in pending so that the resumed session can start it without re-prompt.
    if (value && !running && errorText != null) enabled = false;
    final saved = await (await SharedPreferences.getInstance()).setBool(
      preferenceKey,
      enabled,
    );
    if (!saved) errorText = '背景收件偏好尚未保存，重新開啟 App 後可能還原。';
  });

  Future<bool> _checkNotificationPermission({bool request = false}) async {
    notificationsAllowed = await _notificationPermission(request);
    if (notificationsAllowed == true) return true;
    errorText = notificationsAllowed == false
        ? '系統通知未允許，悄悄話與開台提醒不會顯示。請前往系統設定開啟通知。'
        : '無法確認系統通知權限，請檢查系統設定後重試。';
    return false;
  }

  Future<void> refreshNotificationPermission() => _serialize(() async {
    if (!supported) return;
    if (await _checkNotificationPermission()) {
      errorText = null;
      await _reconcile();
    }
  });

  Future<bool> openNotificationSettings() => _openNotificationSettings();

  Future<bool> openReceivingNotificationSettings() async {
    if (!supported) return false;
    try {
      return await nativeChannel.invokeMethod<bool>(
            'openReceivingNotificationSettings',
          ) ==
          true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _reconcile({bool allowPermissionPrompt = false}) async {
    if (!supported || !_loaded) return;
    if (!enabled || _owner == null) {
      if (running) {
        if (await nativeChannel.invokeMethod<bool>('stopWhispers') != true) {
          errorText = '停止背景收件未完成，請再關閉一次。';
          return;
        }
      }
      running = false;
      return;
    }
    if (!_foreground) return;
    if (!await _checkNotificationPermission()) return;
    if (running) {
      running =
          await nativeChannel.invokeMethod<bool>('whispersRunning') == true;
      if (running) return;
    }
    final owner = _owner;
    if (!allowPermissionPrompt && !await FlutterBackground.hasPermissions) {
      errorText = '背景收件需要系統允許，請關閉再開啟此設定完成授權。';
      return;
    }
    final initialized = await FlutterBackground.initialize(
      androidConfig: const FlutterBackgroundAndroidConfig(
        notificationTitle: 'VioClass 背景收件',
        notificationText: '持續接收 Twitch 悄悄話，滑掉 App 後仍運作，可在設定關閉。',
        notificationIcon: AndroidResource(name: 'vio_notification_icon'),
        enableWifiLock: false,
        showBadge: false,
      ),
    );
    if (!initialized) {
      errorText = '未取得背景執行權限，背景收件未啟用。';
      return;
    }
    if (_owner != owner || !_foreground || !enabled) return;
    running = await nativeChannel.invokeMethod<bool>('startWhispers') == true;
    if (running) errorText = null;
    if (!running) {
      await nativeChannel.invokeMethod<bool>('stopWhispers');
      errorText = '無法啟動背景收件，請稍後重試。';
    }
    if (_owner != owner || !enabled) {
      await nativeChannel.invokeMethod<bool>('stopWhispers');
      running = false;
    }
  }
}
