import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../models/discovery/twitch_live_stream.dart';

class TwitchSystemNotificationService {
  TwitchSystemNotificationService._();

  static final TwitchSystemNotificationService instance =
      TwitchSystemNotificationService._();

  static const String _channelId = 'vioclass_twitch_updates';
  static const String _channelName = 'Twitch 更新';
  static const String _channelDescription = '忠誠點數與追隨頻道開台通知';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initializing;
  bool _initialized = false;
  int _nextNotificationId = 1;

  bool get _isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  Future<void> initialize() {
    if (_initialized || !_isSupported) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      final initialized = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('vio_notification_icon'),
          windows: WindowsInitializationSettings(
            appName: 'VioClass',
            appUserModelId: 'VioClass.Streaming.App.1',
            guid: '7E392AF5-9475-4CB8-978B-4D89A243E391',
          ),
        ),
      );
      _initialized = initialized ?? false;

      if (_initialized && defaultTargetPlatform == TargetPlatform.android) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }
    } catch (error, stackTrace) {
      debugPrint('System notification initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _initialized = false;
    } finally {
      _initializing = null;
    }
  }

  Future<void> showChannelPoints({
    required String title,
    required String message,
  }) {
    return _show(title: title, message: message, payload: 'channel-points');
  }

  Future<void> showStreamLive(TwitchLiveStream stream) {
    final game = stream.gameName.trim();
    final streamTitle = stream.title.trim();
    final details = <String>[
      if (game.isNotEmpty) game,
      if (streamTitle.isNotEmpty) streamTitle,
    ];
    return _show(
      title: '${stream.displayName} 開台了',
      message: details.isEmpty ? '點擊 VioClass 查看直播' : details.join(' · '),
      payload: 'live:${stream.channelLogin}',
    );
  }

  Future<void> showMultipleStreamsLive(List<TwitchLiveStream> streams) {
    final names = streams.map((stream) => stream.displayName).take(4).join('、');
    return _show(
      title: '${streams.length} 個追隨頻道開台了',
      message: names,
      payload: 'live:multiple',
    );
  }

  Future<void> _show({
    required String title,
    required String message,
    required String payload,
  }) async {
    if (!_isSupported) return;
    await initialize();
    if (!_initialized) return;

    try {
      await _plugin.show(
        id: _allocateId(),
        title: title,
        body: message,
        payload: payload,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            icon: 'vio_notification_icon',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.status,
          ),
          windows: WindowsNotificationDetails(
            duration: WindowsNotificationDuration.short,
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('System notification could not be shown: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  int _allocateId() {
    final id = _nextNotificationId;
    _nextNotificationId = _nextNotificationId >= 0x7ffffffe
        ? 1
        : _nextNotificationId + 1;
    return id;
  }
}

final TwitchSystemNotificationService twitchSystemNotificationService =
    TwitchSystemNotificationService.instance;
