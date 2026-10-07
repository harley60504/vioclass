import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../models/discovery/twitch_live_stream.dart';
import 'twitch_app_notification_service.dart';
import '../../presentation/settings/twitch_app_settings_launcher.dart';

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
  bool _responseReceived = false;
  bool _launchDetailsRead = false;
  int _nextNotificationId = 1;

  bool get _supportsSystemNotification {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  bool get _usesInAppNotification =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<void> initialize() {
    if (_initialized || !_supportsSystemNotification) {
      return Future<void>.value();
    }
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      final initialized = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('vio_notification_icon'),
        ),
        onDidReceiveNotificationResponse: (response) {
          _responseReceived = true;
          final target = TwitchWhisperNotificationTarget.fromPayload(
            response.payload,
          );
          if (target != null) {
            twitchAppSettingsLauncher.queueWhisperNotification(target);
          }
        },
      );
      _initialized = initialized ?? false;

      if (_initialized && !_launchDetailsRead) {
        try {
          final launch = await _plugin.getNotificationAppLaunchDetails();
          _launchDetailsRead = true;
          if (!_responseReceived && launch?.didNotificationLaunchApp == true) {
            final target = TwitchWhisperNotificationTarget.fromPayload(
              launch?.notificationResponse?.payload,
            );
            if (target != null) {
              twitchAppSettingsLauncher.queueWhisperNotification(target);
            }
          }
        } catch (_) {
          debugPrint('Notification launch details could not be read.');
        }
      }

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
    if (_usesInAppNotification) {
      final failed = title.contains('失敗');
      twitchAppNotificationCenter.show(
        title: title,
        message: message,
        type: failed
            ? TwitchAppNotificationType.warning
            : TwitchAppNotificationType.success,
      );
      return Future<void>.value();
    }
    return _show(title: title, message: message, payload: 'channel-points');
  }

  Future<void> showStreamLive(TwitchLiveStream stream) {
    final game = stream.gameName.trim();
    final streamTitle = stream.title.trim();
    final details = <String>[
      if (game.isNotEmpty) game,
      if (streamTitle.isNotEmpty) streamTitle,
    ];
    final title = '${stream.displayName} 開台了';
    final message = details.isEmpty ? '可以前往追隨頁查看直播' : details.join(' · ');
    if (_usesInAppNotification) {
      twitchAppNotificationCenter.showInfo(
        title: title,
        message: message,
        duration: const Duration(seconds: 10),
      );
      return Future<void>.value();
    }
    return _show(
      title: title,
      message: message,
      payload: 'live:${stream.channelLogin}',
    );
  }

  Future<void> showMultipleStreamsLive(List<TwitchLiveStream> streams) {
    final names = streams.map((stream) => stream.displayName).take(4).join('、');
    final title = '${streams.length} 個追隨頻道開台了';
    if (_usesInAppNotification) {
      twitchAppNotificationCenter.showInfo(
        title: title,
        message: names,
        duration: const Duration(seconds: 10),
      );
      return Future<void>.value();
    }
    return _show(title: title, message: names, payload: 'live:multiple');
  }

  Future<void> showDebugTest() {
    if (!kDebugMode) return Future<void>.value();
    final now = DateTime.now();
    final sentAt =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    return _show(
      title: 'VioClass App 內通知測試',
      message: '如果看到這則通知，代表通知列正常。測試時間 $sentAt',
      payload: 'debug:notification-test',
    );
  }

  Future<void> showWhisper({
    required String sender,
    required String userId,
    required String ownerId,
  }) {
    final target = TwitchWhisperNotificationTarget.fromPayload(
      'whisper:$ownerId:$userId',
    );
    if (target == null) return Future<void>.value();
    if (_usesInAppNotification) {
      twitchAppNotificationCenter.show(
        title: '$sender 傳來 Twitch 私訊',
        message: '開啟私訊查看對話',
        whisperTarget: target,
      );
      return Future<void>.value();
    }
    return _show(
      title: '$sender 傳來 Twitch 私訊',
      message: '開啟私訊查看對話',
      payload: target.payload,
    );
  }

  Future<void> _show({
    required String title,
    required String message,
    required String payload,
  }) async {
    if (_usesInAppNotification) {
      twitchAppNotificationCenter.showInfo(title: title, message: message);
      return;
    }
    if (!_supportsSystemNotification) return;
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
