// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member, depend_on_referenced_packages
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/platform/android_playback/twitch_android_playback_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import '../lib/features/twitch/presentation/settings/twitch_player_settings_controller.dart';
import '../lib/features/twitch/presentation/settings/twitch_chat_appearance_controller.dart';
import '../lib/features/twitch/presentation/settings/vioclass_update_controller.dart';
import '../lib/features/twitch/presentation/watch/controllers/twitch_watch_preferences_controller.dart';
import '../lib/features/twitch/presentation/sheets/twitch_app_settings_sheet.dart';

class _Update extends ChangeNotifier implements VioClassUpdateController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingMiniStore extends InMemorySharedPreferencesStore {
  _FailingMiniStore(this.throws, this.preferenceKey)
    : super.withData({'flutter.$preferenceKey': true});
  final bool throws;
  final String preferenceKey;
  int attempts = 0;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith(preferenceKey) && value == false) {
      attempts++;
      if (attempts == 1) {
        if (throws) throw StateError('fixture private save error');
        return false;
      }
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  for (final size in [const Size(900, 700), const Size(320, 640)]) {
    for (final setting in [
      (
        '方向鍵快轉／倒退',
        TwitchPlayerSettingsController.keyboardSeekKey,
        (TwitchPlayerSettingsController c) => c.keyboardSeekEnabled,
      ),
      (
        '雙擊快轉／倒退',
        TwitchPlayerSettingsController.doubleTapSeekKey,
        (TwitchPlayerSettingsController c) => c.doubleTapSeekEnabled,
      ),
      (
        '水平拖曳跳轉',
        TwitchPlayerSettingsController.dragSeekKey,
        (TwitchPlayerSettingsController c) => c.dragSeekEnabled,
      ),
      (
        '離開觀看頁保留小窗',
        TwitchPlayerSettingsController.homeKeepsMiniPlayerPreferenceKey,
        (TwitchPlayerSettingsController c) => c.homeKeepsMiniPlayer,
      ),
      (
        '預設顯示聊天室',
        TwitchWatchPreferencesController.chatVisiblePreferenceKey,
        (TwitchPlayerSettingsController c) => c.chatVisible,
      ),
      (
        '允許 Android 子母畫面',
        TwitchPlayerSettingsController.androidPipEnabledPreferenceKey,
        (TwitchPlayerSettingsController c) => c.androidPipEnabled,
      ),
      (
        '背景播放',
        TwitchAndroidPlaybackController.backgroundEnabledKey,
        (TwitchPlayerSettingsController c) => c.backgroundPlaybackEnabled,
      ),
      (
        '開始時靜音',
        TwitchWatchPreferencesController.playerMutedPreferenceKey,
        (TwitchPlayerSettingsController c) => c.muted,
      ),
    ]) {
      for (final throws in [false, true]) {
        testWidgets(
          '${setting.$1} save failure can retry throws=$throws at $size',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            debugDefaultTargetPlatformOverride = TargetPlatform.windows;
            addTearDown(() => debugDefaultTargetPlatformOverride = null);
            SharedPreferences.setMockInitialValues({setting.$2: true});
            final previousStore = SharedPreferencesStorePlatform.instance;
            final store = _FailingMiniStore(throws, setting.$2);
            SharedPreferencesStorePlatform.instance = store;
            addTearDown(
              () => SharedPreferencesStorePlatform.instance = previousStore,
            );
            final player = TwitchPlayerSettingsController();
            final appearance = TwitchChatAppearanceController();
            final update = _Update();
            addTearDown(player.dispose);
            addTearDown(appearance.dispose);
            addTearDown(update.dispose);
            await player.load();
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: TwitchAppSettingsSheet(
                    chatAppearanceController: appearance,
                    playerSettingsController: player,
                    updateController: update,
                    viewerLabel: () => 'fixture',
                    loginStatus: () => 'fixture',
                    loadingLoginState: () => false,
                    onLogin: () async => fail('No account operation'),
                    onRefreshLogin: () async => fail('No account operation'),
                    onLogout: () async => fail('No account operation'),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('播放器'));
            await tester.tap(find.text('播放器').hitTestable());
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text(setting.$1).hitTestable(),
              100,
              scrollable: find
                  .descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            final row = find
                .ancestor(of: find.text(setting.$1), matching: find.byType(Row))
                .first;
            final toggle = find.descendant(
              of: row,
              matching: find.byType(Switch),
            );
            await tester.ensureVisible(toggle);
            await tester.pumpAndSettle();
            await tester.tap(toggle);
            await tester.pumpAndSettle();
            expect(store.attempts, 1);
            expect(setting.$3(player), true);
            expect(tester.widget<Switch>(toggle).value, true);
            expect(
              (await SharedPreferences.getInstance()).getBool(setting.$2),
              true,
            );
            expect(find.text('設定儲存失敗，請稍後再試。'), findsOneWidget);
            expect(find.text('fixture private save error'), findsNothing);
            expect(tester.takeException(), isNull);
            await tester.pump(const Duration(seconds: 5));
            await tester.pumpAndSettle();
            await tester.tap(toggle);
            await tester.pumpAndSettle();
            expect(store.attempts, 2);
            expect(setting.$3(player), false);
            await (await SharedPreferences.getInstance()).reload();
            final reload = TwitchPlayerSettingsController();
            addTearDown(reload.dispose);
            await reload.load();
            expect(setting.$3(reload), false);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            debugDefaultTargetPlatformOverride = null;
          },
        );
      }
    }
  }
  for (final size in [const Size(900, 700), const Size(320, 640)]) {
    testWidgets('Playback defaults persist through settings page at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({
        TwitchWatchPreferencesController.playerVolumePreferenceKey: 20.0,
      });
      final player = TwitchPlayerSettingsController();
      final appearance = TwitchChatAppearanceController();
      final update = _Update();
      await player.load();
      addTearDown(player.dispose);
      addTearDown(appearance.dispose);
      addTearDown(update.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchAppSettingsSheet(
              chatAppearanceController: appearance,
              playerSettingsController: player,
              updateController: update,
              viewerLabel: () => 'fixture',
              loginStatus: () => 'fixture',
              loadingLoginState: () => false,
              onLogin: () async {
                fail('No account operation');
              },
              onRefreshLogin: () async {
                fail('No account operation');
              },
              onLogout: () async {
                fail('No account operation');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('播放器'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('播放器').hitTestable());
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Slider).first, const Offset(45, 0));
      await tester.pumpAndSettle();
      expect(player.volume, isNot(20));
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(player.muted, isTrue);
      for (final label in ['預設顯示聊天室', '離開觀看頁保留小窗']) {
        await tester.scrollUntilVisible(
          find.text(label).hitTestable(),
          100,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final row = find
            .ancestor(of: find.text(label), matching: find.byType(Row))
            .first;
        await tester.tap(
          find.descendant(of: row, matching: find.byType(Switch)),
        );
        await tester.pumpAndSettle();
      }
      expect(player.chatVisible, isFalse);
      expect(player.homeKeepsMiniPlayer, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      final reload = TwitchPlayerSettingsController();
      addTearDown(reload.dispose);
      await reload.load();
      expect(reload.volume, player.volume);
      expect(reload.muted, isTrue);
      expect(reload.chatVisible, isFalse);
      expect(reload.homeKeepsMiniPlayer, isFalse);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
