// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/twitch/services/notifications/twitch_android_background_controller.dart';
import '../lib/features/twitch/presentation/widgets/settings/twitch_android_background_settings_card.dart';
import '../lib/features/twitch/services/notifications/twitch_app_notification_service.dart';
import '../lib/features/twitch/presentation/widgets/notifications/twitch_app_notification_overlay.dart';
import '../lib/features/twitch/presentation/widgets/home/twitch_stream_home_toolbar.dart';
import '../lib/features/twitch/presentation/pages/twitch_stream_home_models.dart';
import '../lib/features/twitch/presentation/settings/twitch_app_settings_launcher.dart';
import '../lib/features/twitch/presentation/settings/vioclass_update_controller.dart';
import '../lib/features/twitch/presentation/settings/twitch_chat_appearance_controller.dart';
import '../lib/features/twitch/presentation/settings/twitch_player_settings_controller.dart';
import '../lib/features/twitch/presentation/sheets/twitch_app_settings_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_background');
  const receiving = MethodChannel('vio_class/background_receiving');
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  late List<String> calls;
  bool grant = true;
  bool notificationGrant = true;
  late List<String> notificationCalls;
  Completer<bool>? initializeGate;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    calls = [];
    grant = true;
    notificationGrant = true;
    notificationCalls = [];
    initializeGate = null;
    var nativeRunning = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(receiving, (call) async {
          if (call.method == 'whispersRunning') return nativeRunning;
          if (call.method == 'startWhispers') {
            calls.add('enableBackgroundExecution');
            nativeRunning = true;
          }
          if (call.method == 'stopWhispers') {
            calls.add('disableBackgroundExecution');
            nativeRunning = false;
          }
          return true;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (call) async {
          notificationCalls.add(call.method);
          if (call.method == 'getNotificationAppLaunchDetails') {
            return {'notificationLaunchedApp': false};
          }
          if (call.method == 'areNotificationsEnabled' ||
              call.method == 'requestNotificationsPermission') {
            return notificationGrant;
          }
          return true;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'initialize') {
            expect((call.arguments as Map)['android.enableWifiLock'], false);
            return initializeGate == null
                ? grant
                : await initializeGate!.future;
          }
          return call.method == 'hasPermissions' ? grant : true;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(receiving, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, null);
    twitchAppNotificationCenter.clear();
  });

  for (final available in [true, false]) {
    testWidgets(
      'Background notification shortcut only opens its category: $available',
      (tester) async {
        final controller = TwitchAndroidBackgroundController(
          notificationPermission: (_) async => true,
        );
        await controller.load();
        final receivingCalls = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(receiving, (call) async {
              receivingCalls.add(call.method);
              if (!available) throw PlatformException(code: 'unavailable');
              return true;
            });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TwitchAndroidBackgroundSettingsCard(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('隱藏背景服務通知'));
        await tester.pumpAndSettle();
        expect(receivingCalls, ['openReceivingNotificationSettings']);
        expect(controller.enabled, false);
        expect(controller.running, false);
        expect(
          find.textContaining('無法開啟通知分類'),
          available ? findsNothing : findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  test(
    'Permission query failure cannot enable the receiver or escape',
    () async {
      var queries = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notifications, (call) async {
            if (call.method == 'getNotificationAppLaunchDetails') {
              return {'notificationLaunchedApp': false};
            }
            if (call.method == 'areNotificationsEnabled') {
              if (queries++ > 0) throw PlatformException(code: 'unavailable');
              return false;
            }
            return true;
          });
      final controller = TwitchAndroidBackgroundController();
      addTearDown(controller.dispose);
      await controller.load();
      await controller.setSession(ownerId: '1', foreground: true);
      await controller.setEnabled(true);
      expect(controller.notificationsAllowed, isNull);
      expect(controller.enabled, false);
      expect(controller.running, false);
      expect(controller.errorText, contains('無法確認'));
      expect(calls, isNot(contains('enableBackgroundExecution')));
    },
  );

  test('Notification denial prevents enabling the receiver', () async {
    notificationGrant = false;
    final controller = TwitchAndroidBackgroundController();
    addTearDown(controller.dispose);
    await controller.load();
    await controller.setSession(ownerId: '1', foreground: true);
    await controller.setEnabled(true);
    expect(controller.enabled, false);
    expect(controller.running, false);
    expect(controller.notificationsAllowed, false);
    expect(controller.errorText, contains('系統通知未允許'));
    expect(notificationCalls, contains('requestNotificationsPermission'));
    expect(calls, isNot(contains('enableBackgroundExecution')));
    expect(await controller.openNotificationSettings(), true);
    expect(notificationCalls.last, 'openAppNotificationSettings');
  });

  test(
    'Saved opt-in waits for notification permission without prompting',
    () async {
      SharedPreferences.setMockInitialValues({
        TwitchAndroidBackgroundController.preferenceKey: true,
      });
      notificationGrant = false;
      final controller = TwitchAndroidBackgroundController();
      addTearDown(controller.dispose);
      await controller.setSession(ownerId: '1', foreground: true);
      await controller.load();
      expect(controller.enabled, true);
      expect(controller.running, false);
      expect(
        notificationCalls,
        isNot(contains('requestNotificationsPermission')),
      );
      notificationGrant = true;
      await controller.refreshNotificationPermission();
      expect(controller.running, true);
      await controller.setEnabled(false);
    },
  );

  testWidgets('Denied toggle offers settings and refreshes after return', (
    tester,
  ) async {
    var allowed = false;
    var opened = 0;
    final controller = TwitchAndroidBackgroundController(
      notificationPermission: (_) async => allowed,
      openNotificationSettings: () async {
        opened++;
        return true;
      },
    );
    await controller.load();
    await controller.setSession(ownerId: '1', foreground: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchAndroidBackgroundSettingsCard(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(find.text('允許 VioClass 通知'), findsOneWidget);
    expect(controller.enabled, false);
    await tester.tap(find.text('前往設定'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    allowed = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(controller.notificationsAllowed, true);
    expect(find.text('通知權限未開啟'), findsNothing);
    expect(find.textContaining('15 分鐘'), findsNothing);
    expect(find.text('背景收件運作中'), findsNothing);
    expect(find.text('系統通知已允許；背景收件未啟用'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  for (final size in [const Size(1000, 760), const Size(390, 844)]) {
    testWidgets('Notification preferences have a separate tab size=$size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final chat = TwitchChatAppearanceController();
      final player = TwitchPlayerSettingsController();
      final update = VioClassUpdateController();
      addTearDown(chat.dispose);
      addTearDown(player.dispose);
      addTearDown(update.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchAppSettingsSheet(
              chatAppearanceController: chat,
              playerSettingsController: player,
              updateController: update,
              viewerLabel: () => 'Fixture',
              loginStatus: () => '',
              loadingLoginState: () => false,
              onLogin: () async {},
              onRefreshLogin: () async {},
              onLogout: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TwitchAndroidBackgroundSettingsCard), findsNothing);
      await tester.tap(find.byIcon(Icons.notifications_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(TwitchAndroidBackgroundSettingsCard), findsOneWidget);
      expect(find.text('開台通知'), findsOneWidget);
      expect(find.text('背景悄悄話'), findsOneWidget);
      expect(find.textContaining('15 分鐘'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });
  }

  test(
    'Default off; enabling, background and logout use a single service',
    () async {
      final controller = TwitchAndroidBackgroundController();
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.enabled, false);
      expect(calls, isEmpty);
      await controller.setSession(ownerId: '1', foreground: true);
      await controller.setEnabled(true);
      expect(controller.running, true);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          TwitchAndroidBackgroundController.preferenceKey,
        ),
        true,
      );
      await controller.setSession(ownerId: '1', foreground: false);
      await controller.setSession(ownerId: '1', foreground: true);
      expect(
        calls.where((call) => call == 'enableBackgroundExecution'),
        hasLength(1),
      );
      await controller.setSession(ownerId: null, foreground: true);
      expect(controller.running, false);
      expect(calls.last, 'disableBackgroundExecution');
      await controller.setEnabled(false);
      expect(controller.enabled, false);
    },
  );

  test('Denied authorization leaves preference off', () async {
    grant = false;
    final controller = TwitchAndroidBackgroundController();
    addTearDown(controller.dispose);
    await controller.load();
    await controller.setSession(ownerId: '1', foreground: true);
    await controller.setEnabled(true);
    expect(controller.running, false);
    expect(controller.enabled, false);
    expect(controller.errorText, isNotNull);
    expect(calls, isNot(contains('enableBackgroundExecution')));
  });

  test('Restoring preference never prompts for missing permission', () async {
    SharedPreferences.setMockInitialValues({
      TwitchAndroidBackgroundController.preferenceKey: true,
    });
    grant = false;
    final controller = TwitchAndroidBackgroundController();
    addTearDown(controller.dispose);
    await controller.setSession(ownerId: '1', foreground: true);
    await controller.load();
    expect(controller.enabled, true);
    expect(controller.running, false);
    expect(calls, ['hasPermissions']);
  });

  test(
    'Logout while system prompt is pending cannot start old account',
    () async {
      final controller = TwitchAndroidBackgroundController();
      addTearDown(controller.dispose);
      await controller.load();
      await controller.setSession(ownerId: '1', foreground: true);
      initializeGate = Completer<bool>();
      final enabling = controller.setEnabled(true);
      await Future<void>.delayed(Duration.zero);
      final logout = controller.setSession(ownerId: null, foreground: true);
      initializeGate!.complete(true);
      await enabling;
      await logout;
      expect(controller.running, false);
      expect(calls, isNot(contains('enableBackgroundExecution')));
    },
  );

  test('Windows does not invoke Android plugin', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final controller = TwitchAndroidBackgroundController();
    addTearDown(controller.dispose);
    await controller.load();
    await controller.setSession(ownerId: '1', foreground: true);
    await controller.setEnabled(true);
    expect(calls, isEmpty);
  });

  test(
    'Permission result while paused resumes without another prompt',
    () async {
      final controller = TwitchAndroidBackgroundController();
      addTearDown(controller.dispose);
      await controller.load();
      await controller.setSession(ownerId: '1', foreground: true);
      initializeGate = Completer<bool>();
      final enabling = controller.setEnabled(true);
      await Future<void>.delayed(Duration.zero);
      final paused = controller.setSession(ownerId: '1', foreground: false);
      initializeGate!.complete(true);
      await enabling;
      await paused;
      expect(controller.enabled, true);
      expect(controller.running, false);
      await controller.setSession(ownerId: '1', foreground: true);
      expect(controller.running, true);
      expect(
        calls.where((call) => call == 'enableBackgroundExecution'),
        hasLength(1),
      );
      await controller.setEnabled(false);
    },
  );

  test('Initialization exception cannot save enabled preference', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'denied');
        });
    final controller = TwitchAndroidBackgroundController();
    addTearDown(controller.dispose);
    await controller.load();
    await controller.setSession(ownerId: '1', foreground: true);
    await controller.setEnabled(true);
    expect(controller.enabled, false);
    expect(controller.running, false);
    expect(controller.errorText, isNotNull);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        TwitchAndroidBackgroundController.preferenceKey,
      ),
      false,
    );
  });

  testWidgets('Android has no notification island or in-app toast', (
    tester,
  ) async {
    twitchAppNotificationCenter.showInfo(
      title: '開台測試',
      message: '不得在 App 重複顯示',
    );
    await tester.pumpWidget(
      const MaterialApp(home: TwitchAppNotificationOverlay(child: Text('主畫面'))),
    );
    expect(find.text('主畫面'), findsOneWidget);
    expect(find.text('開台測試'), findsNothing);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    twitchAppNotificationCenter.clear();
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android home directly opens whispers without update menu', (
    tester,
  ) async {
    final search = TextEditingController();
    final updates = VioClassUpdateController();
    var opened = 0;
    twitchAppSettingsLauncher.attach(
      () async {},
      updateController: updates,
      updateOpener: () async {},
      whisperOpener: () async {
        opened++;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchStreamHomeToolbar(
            selectedSection: TwitchHomeSection.following,
            onSelectSection: (_) {},
            searchController: search,
            onSearchChanged: (_) {},
            onClearSearch: () {},
            onShowGameMenu: () {},
            onShowLanguageMenu: () {},
            onRefresh: () async {},
            onOpenDropsConnector: () async {},
            onOpenSettings: () async {},
            forceTwoRows: true,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('mobile-whispers')), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mobile-whispers')));
    await tester.pump();
    expect(opened, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    twitchAppSettingsLauncher.detach();
    search.dispose();
    updates.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
