import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../models/discovery/twitch_live_stream.dart';
import '../../api/notifications/twitch_account_notification_api.dart';
import 'twitch_app_notification_service.dart';
import '../../presentation/settings/twitch_app_settings_launcher.dart';

class TwitchSystemNotificationService {
  Timer? _pointsQuietTimer;
  final Map<String, int> _pointEarns = {};

  /// Match StreamNook's three-second quiet window instead of one popup per tick.
  void recordChannelPointsEarned({
    required String channel,
    required int points,
  }) {
    if (points <= 0) return;
    final name = channel.trim().isEmpty ? 'Twitch' : channel.trim();
    _pointEarns.update(name, (value) => value + points, ifAbsent: () => points);
    _pointsQuietTimer?.cancel();
    _pointsQuietTimer = Timer(const Duration(seconds: 3), () {
      final earns = _pointEarns.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      _pointEarns.clear();
      _pointsQuietTimer = null;
      final total = earns.fold<int>(0, (sum, item) => sum + item.value);
      final channels = earns
          .take(3)
          .map((item) => '${item.key} +${item.value}')
          .join('、');
      unawaited(
        showChannelPoints(
          title: '忠誠點數 +$total',
          message:
              '$channels${earns.length > 3 ? '，另 ${earns.length - 3} 個頻道' : ''}',
        ),
      );
    });
  }

  void clearPendingPointNotifications() {
    _pointsQuietTimer?.cancel();
    _pointsQuietTimer = null;
    _pointEarns.clear();
  }

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
  // ID 1 belongs to flutter_background's foreground-service notification.
  int _nextNotificationId = 1000;

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
    } catch (error, stackTrace) {
      debugPrint('System notification initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _initialized = false;
    } finally {
      _initializing = null;
    }
  }

  Future<bool?> notificationPermission({bool request = false}) async {
    if (!_supportsSystemNotification) return null;
    await initialize();
    if (!_initialized) return null;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final allowed = await android?.areNotificationsEnabled();
      if (allowed != true && request) {
        await android?.requestNotificationsPermission();
        return await android?.areNotificationsEnabled();
      }
      return allowed;
    } catch (_) {
      return null;
    }
  }

  Future<bool> openNotificationSettings() async {
    if (!_supportsSystemNotification) return false;
    try {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.openAppNotificationSettings() ??
          false;
    } catch (_) {
      return false;
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
        category: TwitchAppNotificationCategory.channelPoints,
      );
      return Future<void>.value();
    }
    return _show(title: title, message: message, payload: 'channel-points');
  }

  Future<void> showAppUpdate({
    required String version,
    Future<void> Function()? onOpen,
  }) {
    if (_usesInAppNotification) {
      twitchAppNotificationCenter.show(
        title: 'VioClass 有新版本',
        message: '版本 $version 可供更新',
        category: TwitchAppNotificationCategory.update,
        onOpen: onOpen,
      );
      return Future<void>.value();
    }
    return _show(
      title: 'VioClass 有新版本',
      message: '版本 $version 可供更新，請到設定查看。',
      payload: 'app-update',
    );
  }

  Future<void> showDropClaim({
    required String reward,
    required bool succeeded,
    String? error,
  }) {
    final title = succeeded ? 'Drops 獎勵領取成功' : 'Drops 獎勵領取失敗';
    final message = succeeded ? reward : error ?? '請稍後再試。';
    if (_usesInAppNotification) {
      twitchAppNotificationCenter.show(
        title: title,
        message: message,
        category: TwitchAppNotificationCategory.drops,
        type: succeeded
            ? TwitchAppNotificationType.success
            : TwitchAppNotificationType.warning,
      );
      return Future<void>.value();
    }
    return _show(title: title, message: message, payload: 'drop-claimed');
  }

  Future<void> showAccountNotification(TwitchAccountNotification item) {
    if (_usesInAppNotification) {
      twitchAppNotificationCenter.show(
        title: item.title,
        message: item.body,
        type: TwitchAppNotificationType.success,
        category: item.kind == TwitchAccountNotificationKind.giftSubscription
            ? TwitchAppNotificationCategory.giftSubscription
            : TwitchAppNotificationCategory.badge,
        accountOwnerId: item.ownerId,
        avatarUrls: item.imageUrl.isEmpty ? const [] : [item.imageUrl],
      );
      return Future<void>.value();
    }
    return _show(
      title: item.title,
      message: item.body,
      payload: 'account-reward',
      avatarUrl: item.imageUrl,
    );
  }

  Future<void> showStreamLive(
    TwitchLiveStream stream, {
    Future<void> Function()? onOpen,
  }) {
    final game = stream.gameName.trim();
    final streamTitle = stream.title.trim();
    final details = <String>[
      if (game.isNotEmpty) game,
      if (streamTitle.isNotEmpty) streamTitle,
    ];
    final title = '${stream.displayName} 開台了';
    final message = details.isEmpty ? '可以前往追隨頁查看直播' : details.join(' · ');
    if (_usesInAppNotification) {
      twitchAppNotificationCenter.show(
        title: title,
        message: message,
        duration: TwitchAppNotificationCenter.liveDuration,
        category: TwitchAppNotificationCategory.live,
        liveStream: stream,
        avatarUrls: [stream.profileImageUrl],
        onOpen: onOpen,
      );
      return Future<void>.value();
    }
    return _show(
      title: title,
      message: message,
      payload: 'live:${stream.channelLogin}',
      avatarUrl: stream.profileImageUrl,
    );
  }

  Future<void> showMultipleStreamsLive(List<TwitchLiveStream> streams) {
    final names = streams.map((stream) => stream.displayName).take(4).join('、');
    final title = '${streams.length} 個追隨頻道開台了';
    if (_usesInAppNotification) {
      twitchAppNotificationCenter.show(
        title: title,
        message: names,
        duration: TwitchAppNotificationCenter.liveDuration,
        category: TwitchAppNotificationCategory.live,
        avatarUrls: streams.take(3).map((s) => s.profileImageUrl).toList(),
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
        category: TwitchAppNotificationCategory.whisper,
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
    String? avatarUrl,
  }) async {
    if (_usesInAppNotification) {
      twitchAppNotificationCenter.showInfo(title: title, message: message);
      return;
    }
    if (!_supportsSystemNotification) return;
    await initialize();
    if (!_initialized) return;

    try {
      FilePathAndroidBitmap? avatar;
      final uri = Uri.tryParse(avatarUrl?.trim() ?? '');
      if (uri?.scheme == 'https' && uri?.host.isNotEmpty == true) {
        try {
          final file = await DefaultCacheManager()
              .getSingleFile(uri.toString())
              .timeout(const Duration(seconds: 3));
          avatar = FilePathAndroidBitmap(file.path);
        } catch (_) {
          // Avatar loading must never prevent the system notification.
        }
      }
      await _plugin.show(
        id: _allocateId(),
        title: title,
        body: message,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            icon: 'vio_notification_icon',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.status,
            largeIcon: avatar,
            styleInformation: BigTextStyleInformation(message),
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
        ? 1000
        : _nextNotificationId + 1;
    return id;
  }
}

final TwitchSystemNotificationService twitchSystemNotificationService =
    TwitchSystemNotificationService.instance;
