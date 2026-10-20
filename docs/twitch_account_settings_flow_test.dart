// Repository test files are intentionally stored in docs.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vioclass/features/twitch/presentation/settings/twitch_app_language_controller.dart';
import 'package:vioclass/features/twitch/presentation/localization/vioclass_localizations.dart';
import 'package:vioclass/features/twitch/presentation/settings/twitch_chat_appearance_controller.dart';
import 'package:vioclass/features/twitch/presentation/settings/twitch_player_settings_controller.dart';
import 'package:vioclass/features/twitch/presentation/settings/vioclass_update_controller.dart';
import 'package:vioclass/features/twitch/presentation/sheets/twitch_app_settings_sheet.dart';

class _Player extends ChangeNotifier implements TwitchPlayerSettingsController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Update extends ChangeNotifier implements VioClassUpdateController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final size in [const Size(1000, 760), const Size(390, 844)]) {
    testWidgets('Unified settings all tabs close and reopen size=$size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'vioclass_auto_check_updates_v1': false,
      });
      await twitchAppLanguageController.select(TwitchAppLanguageMode.zhTw);
      final chat = TwitchChatAppearanceController();
      final player = TwitchPlayerSettingsController();
      final update = VioClassUpdateController();
      await chat.load();
      await player.load();
      await update.load();
      addTearDown(chat.dispose);
      addTearDown(player.dispose);
      addTearDown(update.dispose);
      var accountCalls = 0;
      var returns = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  await showTwitchAppSettingsSheet(
                    context: context,
                    chatAppearanceController: chat,
                    playerSettingsController: player,
                    updateController: update,
                    viewerLabel: () => 'Fixture viewer',
                    loginStatus: () => 'Fixture signed status',
                    loadingLoginState: () => false,
                    onLogin: () async {
                      accountCalls++;
                    },
                    onRefreshLogin: () async {
                      accountCalls++;
                    },
                    onLogout: () async {
                      accountCalls++;
                    },
                  );
                  returns++;
                },
                child: const Text('fixture settings open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('fixture settings open'));
      await tester.pumpAndSettle();
      expect(find.text('Fixture viewer'), findsOneWidget);
      final sheet = tester.getRect(find.byType(TwitchAppSettingsSheet));
      expect(sheet.left, greaterThanOrEqualTo(0));
      expect(sheet.right, lessThanOrEqualTo(size.width));
      expect(sheet.top, greaterThanOrEqualTo(0));
      expect(sheet.bottom, lessThanOrEqualTo(size.height));
      for (final item in [
        ('聊天', '聊天室字體'),
        ('播放器', '播放預設'),
        ('外觀', 'App 語言'),
        ('更新', 'App 更新'),
        ('帳號', 'Fixture viewer'),
      ]) {
        await tester.ensureVisible(find.text(item.$1));
        await tester.pumpAndSettle();
        await tester.tap(find.text(item.$1).hitTestable());
        await tester.pumpAndSettle();
        expect(find.text(item.$2), findsWidgets);
        expect(tester.takeException(), isNull);
      }
      expect(accountCalls, 0);
      expect(update.latest, isNull);
      expect(update.checking, false);
      expect(update.installing, false);
      await tester.tap(find.byTooltip('關閉').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(TwitchAppSettingsSheet), findsNothing);
      expect(find.text('fixture settings open'), findsOneWidget);
      expect(returns, 1);
      await tester.tap(find.text('fixture settings open'));
      await tester.pumpAndSettle();
      expect(find.text('Fixture viewer'), findsOneWidget);
      await tester.tap(find.byTooltip('關閉').hitTestable());
      await tester.pumpAndSettle();
      expect(returns, 2);
      expect(accountCalls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  test('Account failure has an English translation', () {
    expect(
      const VioClassLocalizations(Locale('en')).t('帳號操作暫時失敗，請稍後再試。'),
      'Account action failed. Please try again later.',
    );
  });
  for (final size in [const Size(1000, 760), const Size(390, 844)]) {
    for (final action in ['完整登入 / 修復登入', '重新檢查', '登出', 'close-failure']) {
      testWidgets(
        'Account settings action failure retries action=$action size=$size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          await twitchAppLanguageController.select(TwitchAppLanguageMode.zhTw);
          final chat = TwitchChatAppearanceController();
          final player = _Player();
          final update = _Update();
          addTearDown(chat.dispose);
          addTearDown(player.dispose);
          addTearDown(update.dispose);
          final gate = Completer<void>();
          var calls = 0;
          Future<void> operate() {
            calls++;
            return calls == 1 ? gate.future : Future<void>.value();
          }

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showTwitchAppSettingsSheet(
                      context: context,
                      chatAppearanceController: chat,
                      playerSettingsController: player,
                      updateController: update,
                      viewerLabel: () => 'Fixture viewer',
                      loginStatus: () => 'Fixture signed status',
                      loadingLoginState: () => false,
                      onLogin: operate,
                      onRefreshLogin: operate,
                      onLogout: operate,
                    ),
                    child: const Text('fixture account open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('fixture account open'));
          await tester.pumpAndSettle();
          final label = action == 'close-failure' ? '重新檢查' : action;
          await tester.ensureVisible(find.text(label));
          await tester.pumpAndSettle();
          await tester.tap(find.text(label));
          await tester.pump();
          expect(calls, 1);
          for (final buttonLabel in ['完整登入 / 修復登入', '重新檢查', '登出']) {
            final button = find.ancestor(
              of: find.text(buttonLabel),
              matching: find.byWidgetPredicate(
                (widget) => widget is ButtonStyleButton,
              ),
            );
            expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
          }
          if (action == 'close-failure') {
            await tester.pumpWidget(const SizedBox());
          }
          gate.completeError(StateError('fixture private account failure'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
          expect(
            find.textContaining('fixture private account failure'),
            findsNothing,
          );
          if (action == 'close-failure') {
            expect(find.text('帳號操作暫時失敗，請稍後再試。'), findsNothing);
          } else {
            expect(find.text('帳號操作暫時失敗，請稍後再試。'), findsOneWidget);
            await tester.tap(find.text(label));
            await tester.pumpAndSettle();
            expect(calls, 2);
            final button = find.ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate(
                (widget) => widget is ButtonStyleButton,
              ),
            );
            expect(
              tester.widget<ButtonStyleButton>(button).onPressed,
              isNotNull,
            );
          }
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpWidget(const SizedBox());
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
