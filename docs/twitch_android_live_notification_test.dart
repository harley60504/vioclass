// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/twitch/models/discovery/twitch_live_stream.dart';
import '../lib/features/twitch/services/notifications/twitch_android_live_notification_controller.dart';

TwitchFollowedChannelPageResult page(List<String> names, [String? cursor]) =>
    TwitchFollowedChannelPageResult(
      channels: names
          .map(
            (name) => TwitchFollowedChannel(
              broadcasterId: name,
              broadcasterLogin: name,
              broadcasterName: name,
              followedAt: null,
            ),
          )
          .toList(),
      cursor: cursor,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannel('vio_class/background_receiving');
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  late List<Map<dynamic, dynamic>> configs;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    configs = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          expect(call.method, 'configureLive');
          final config = Map<dynamic, dynamic>.from(call.arguments as Map);
          expect(config.keys.toSet(), {
            'owner',
            'channels',
            'enabled',
            'clientId',
            'preserveExisting',
          });
          configs.add(config);
          return true;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (call) async {
          if (call.method == 'getNotificationAppLaunchDetails') {
            return {'notificationLaunchedApp': false};
          }
          return true;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, null);
  });

  test('Caches every follows page without copying credentials', () async {
    final controller = TwitchAndroidLiveNotificationController();
    await controller.setSession(
      owner: 'owner',
      fetchPage: (after) async =>
          after == null ? page(['b'], 'next') : page(['a', 'b']),
    );
    expect(configs.first['channels'], isEmpty);
    expect(configs.first['preserveExisting'], true);
    expect(configs.last['preserveExisting'], false);
    expect(configs.last['channels'], ['a', 'b']);
    expect(controller.errorText, isNull);
    // Refreshing the same account must not cancel its existing worker first.
    configs.clear();
    await controller.setSession(
      owner: 'owner',
      fetchPage: (_) async => page(['b', 'c']),
    );
    expect(configs, hasLength(1));
    expect(configs.single['channels'], ['b', 'c']);
    controller.dispose();
  });

  test('Late follows cannot schedule after logout', () async {
    final gate = Completer<TwitchFollowedChannelPageResult>();
    final started = Completer<void>();
    final controller = TwitchAndroidLiveNotificationController();
    final syncing = controller.setSession(
      owner: 'old',
      fetchPage: (_) {
        started.complete();
        return gate.future;
      },
    );
    await started.future;
    await controller.setSession(owner: null);
    gate.complete(page(['stale']));
    await syncing;
    expect(configs.last['owner'], isNull);
    expect(
      configs.any((config) => (config['channels'] as List).contains('stale')),
      false,
    );
    controller.dispose();
  });

  test(
    'Repeated cursor is rejected without applying a partial snapshot',
    () async {
      final controller = TwitchAndroidLiveNotificationController();
      await controller.setSession(
        owner: 'owner',
        fetchPage: (_) async => page(['a'], 'loop'),
      );
      expect(configs, hasLength(1));
      expect(configs.single['channels'], isEmpty);
      expect(controller.errorText, isNotNull);
      controller.dispose();
    },
  );

  test(
    'Disabling cancels the worker and persists only the preference',
    () async {
      final controller = TwitchAndroidLiveNotificationController();
      await controller.setSession(
        owner: 'owner',
        fetchPage: (_) async => page(['a']),
      );
      await controller.setEnabled(false);
      expect(configs.last['enabled'], false);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          TwitchAndroidLiveNotificationController.preferenceKey,
        ),
        false,
      );
      await controller.setEnabled(true);
      expect(configs.last['enabled'], true);
      controller.dispose();
    },
  );

  test('Non-Android does not configure a worker', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final controller = TwitchAndroidLiveNotificationController();
    await controller.setSession(
      owner: 'owner',
      fetchPage: (_) async => page(['a']),
    );
    await controller.setEnabled(true);
    expect(configs, isEmpty);
    controller.dispose();
  });

  test('Failed native opt-out is not shown as disabled', () async {
    final controller = TwitchAndroidLiveNotificationController();
    await controller.load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (_) async => false);
    await controller.setEnabled(false);
    expect(controller.enabled, true);
    expect(controller.errorText, isNotNull);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        TwitchAndroidLiveNotificationController.preferenceKey,
      ),
      isNull,
    );
    controller.dispose();
  });
}
