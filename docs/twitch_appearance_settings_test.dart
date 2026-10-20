// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member, depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import '../lib/features/twitch/presentation/localization/vioclass_localizations.dart';
import '../lib/features/twitch/presentation/settings/twitch_app_font_controller.dart';
import '../lib/features/twitch/presentation/settings/twitch_app_language_controller.dart';
import '../lib/features/twitch/presentation/settings/twitch_chat_appearance_controller.dart';
import '../lib/features/twitch/presentation/settings/twitch_player_settings_controller.dart';
import '../lib/features/twitch/presentation/settings/vioclass_update_controller.dart';
import '../lib/features/twitch/presentation/sheets/twitch_app_settings_sheet.dart';

class _Player extends ChangeNotifier implements TwitchPlayerSettingsController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Update extends ChangeNotifier implements VioClassUpdateController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TimestampFailureStore extends InMemorySharedPreferencesStore {
  _TimestampFailureStore(this.throws, {
    this.key = 'twitch_chat_message_timestamps_enabled_v1',
  }) : super.withData({
    'flutter.twitch_chat_message_timestamps_enabled_v1': false,
    'flutter.twitch_app_language_selected_v1': 'zhTw',
    'flutter.twitch_app_font_selected_v1': 'vioClass',
  });
  final bool throws;
  final String key;
  int attempts = 0;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${this.key}') {
      attempts++;
      if (attempts == 1) {
        if (throws) throw StateError('fixture timestamp save failure');
        return false;
      }
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  for (final size in [const Size(900, 700), const Size(320, 640)]) {
    for (final font in [false, true]) {
      for (final throws in [false, true]) {
        testWidgets('Appearance selection UI preserves failed save and retries size=$size font=$font throws=$throws', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({
            'twitch_app_language_selected_v1': 'zhTw',
            'twitch_app_font_selected_v1': 'vioClass',
          });
          await twitchAppLanguageController.load();
          await twitchAppFontController.load();
          await twitchAppLanguageController.select(TwitchAppLanguageMode.zhTw);
          await twitchAppFontController.select(TwitchAppFontController.vioClass);
          final previous = SharedPreferencesStorePlatform.instance;
          final store = _TimestampFailureStore(throws, key: font
            ? 'twitch_app_font_selected_v1' : 'twitch_app_language_selected_v1');
          SharedPreferencesStorePlatform.instance = store;
          addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
          await (await SharedPreferences.getInstance()).reload();
          final appearance = TwitchChatAppearanceController();
          final player = _Player();
          final update = _Update();
          addTearDown(appearance.dispose);
          addTearDown(player.dispose);
          addTearDown(update.dispose);
          await appearance.load();
          Future<void> noAccountWrite() async => fail('No account operation allowed');
          await tester.pumpWidget(AnimatedBuilder(
            animation: twitchAppLanguageController,
            builder: (_, _) => MaterialApp(
              locale: twitchAppLanguageController.locale,
              supportedLocales: const [Locale('zh', 'TW'), Locale('en')],
              localizationsDelegates: const [VioClassLocalizations.delegate,
                GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate],
              home: Scaffold(body: TwitchAppSettingsSheet(
                chatAppearanceController: appearance, playerSettingsController: player,
                updateController: update, viewerLabel: () => 'fixture',
                loginStatus: () => 'fixture', loadingLoginState: () => false,
                onLogin: noAccountWrite, onRefreshLogin: noAccountWrite,
                onLogout: noAccountWrite,
              )),
            ),
          ));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('外觀'));
          await tester.tap(find.text('外觀').hitTestable());
          await tester.pumpAndSettle();
          final choice = find.text(font ? '系統字體' : 'English');
          await tester.scrollUntilVisible(choice.hitTestable(), 150,
            scrollable: find.descendant(of: find.byType(ListView),
              matching: find.byType(Scrollable)).first);
          await tester.tap(choice.hitTestable());
          await tester.pumpAndSettle();
          expect(font ? twitchAppFontController.selectedId : twitchAppLanguageController.mode.id,
            font ? 'vioClass' : 'zhTw');
          expect(find.text(font ? '字體切換失敗，請稍後再試或重新匯入。'
              : '設定儲存失敗，請稍後再試。'), findsOneWidget);
          expect(store.attempts, 1);
          await tester.tap(choice.hitTestable());
          await tester.pumpAndSettle();
          expect(font ? twitchAppFontController.selectedId : twitchAppLanguageController.mode.id,
            font ? 'system' : 'en');
          expect(store.attempts, 2);
          await (await SharedPreferences.getInstance()).reload();
          final restoredFont = TwitchAppFontController();
          final restoredLanguage = TwitchAppLanguageController();
          addTearDown(restoredFont.dispose);
          addTearDown(restoredLanguage.dispose);
          await restoredFont.load();
          await restoredLanguage.load();
          expect(font ? restoredFont.selectedId : restoredLanguage.mode.id,
            font ? 'system' : 'en');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  for (final size in [const Size(900, 700), const Size(320, 640)]) {
    for (final throws in [false, true]) {
      testWidgets('Chat timestamp UI preserves failed save and retries size=$size throws=$throws', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        await twitchAppLanguageController.select(TwitchAppLanguageMode.zhTw);
        final previous = SharedPreferencesStorePlatform.instance;
        final store = _TimestampFailureStore(throws);
        SharedPreferencesStorePlatform.instance = store;
        addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
        await (await SharedPreferences.getInstance()).reload();
        final appearance = TwitchChatAppearanceController();
        final player = _Player();
        final update = _Update();
        addTearDown(appearance.dispose);
        addTearDown(player.dispose);
        addTearDown(update.dispose);
        await appearance.load();
        Future<void> noAccountWrite() async => fail('No account operation allowed');
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('zh', 'TW'),
          supportedLocales: const [Locale('zh', 'TW'), Locale('en')],
          localizationsDelegates: const [VioClassLocalizations.delegate,
            GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate],
          home: Scaffold(body: TwitchAppSettingsSheet(
            chatAppearanceController: appearance, playerSettingsController: player,
            updateController: update, viewerLabel: () => 'fixture',
            loginStatus: () => 'fixture', loadingLoginState: () => false,
            onLogin: noAccountWrite, onRefreshLogin: noAccountWrite,
            onLogout: noAccountWrite,
          )),
        ));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('聊天'));
        await tester.tap(find.text('聊天').hitTestable());
        await tester.pumpAndSettle();
        final toggle = find.byType(Switch).first;
        await tester.scrollUntilVisible(toggle.hitTestable(), 120,
          scrollable: find.descendant(of: find.byType(ListView),
            matching: find.byType(Scrollable)).first);
        expect(tester.widget<Switch>(toggle).value, false);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(appearance.messageTimestampsEnabled, false);
        expect(tester.widget<Switch>(toggle).value, false);
        expect(find.text('設定儲存失敗，請稍後再試。'), findsOneWidget);
        expect(find.textContaining('fixture timestamp save failure'), findsNothing);
        expect(store.attempts, 1);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(appearance.messageTimestampsEnabled, true);
        expect(tester.widget<Switch>(toggle).value, true);
        expect(store.attempts, 2);
        await (await SharedPreferences.getInstance()).reload();
        final restored = TwitchChatAppearanceController();
        addTearDown(restored.dispose);
        await restored.load();
        expect(restored.messageTimestampsEnabled, true);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
    'Appearance and chat choices persist via desktop and narrow settings UI',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await twitchAppLanguageController.load();
      await twitchAppFontController.load();
      for (final size in [const Size(900, 700), const Size(320, 640)]) {
        tester.view.physicalSize = size;
        await twitchAppLanguageController.select(TwitchAppLanguageMode.zhTw);
        await twitchAppFontController.select(TwitchAppFontController.vioClass);
        final appearance = TwitchChatAppearanceController();
        await appearance.load();
        await appearance.setMessageTimestampsEnabled(false);
        final player = _Player();
        final update = _Update();
        addTearDown(appearance.dispose);
        addTearDown(player.dispose);
        addTearDown(update.dispose);
        Widget page() => AnimatedBuilder(
          animation: twitchAppLanguageController,
          builder: (_, _) => MaterialApp(
            locale: twitchAppLanguageController.locale,
            supportedLocales: const [Locale('zh', 'TW'), Locale('en')],
            localizationsDelegates: const [
              VioClassLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: TwitchAppSettingsSheet(
                chatAppearanceController: appearance,
                playerSettingsController: player,
                updateController: update,
                viewerLabel: () => 'fixture',
                loginStatus: () => 'fixture',
                loadingLoginState: () => false,
                onLogin: () async {
                  fail('No account operation allowed');
                },
                onRefreshLogin: () async {
                  fail('No account operation allowed');
                },
                onLogout: () async {
                  fail('No account operation allowed');
                },
              ),
            ),
          ),
        );
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('外觀'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('外觀').hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        expect(twitchAppLanguageController.mode, TwitchAppLanguageMode.en);
        expect(find.text('Appearance'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('System font').hitTestable(),
          150,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.text('System font'));
        await tester.pumpAndSettle();
        expect(twitchAppFontController.selectedId, 'system');
      await tester.ensureVisible(find.text('Chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chat').hitTestable());
        await tester.pumpAndSettle();
        final slider = find.byType(Slider).first;
        final oldScale = appearance.fontScale;
        await tester.drag(slider, const Offset(35, 0));
        await tester.pumpAndSettle();
        expect(appearance.fontScale, isNot(oldScale));
        await tester.scrollUntilVisible(
          find.byType(Switch).first.hitTestable(),
          120,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        expect(appearance.messageTimestampsEnabled, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        final languageReload = TwitchAppLanguageController();
        final fontReload = TwitchAppFontController();
        final appearanceReload = TwitchChatAppearanceController();
        addTearDown(languageReload.dispose);
        addTearDown(fontReload.dispose);
        addTearDown(appearanceReload.dispose);
        await languageReload.load();
        await fontReload.load();
        await appearanceReload.load();
        expect(languageReload.mode, TwitchAppLanguageMode.en);
        expect(fontReload.selectedId, 'system');
        expect(appearanceReload.fontScale, appearance.fontScale);
        expect(appearanceReload.messageTimestampsEnabled, isTrue);
      }
    },
  );
}
