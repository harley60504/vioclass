// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/twitch/presentation/settings/twitch_chat_appearance_controller.dart';
import '../lib/features/twitch/presentation/settings/twitch_chat_keyboard_controller.dart';
import '../lib/features/twitch/presentation/settings/twitch_player_settings_controller.dart';
import '../lib/features/twitch/presentation/settings/vioclass_update_controller.dart';
import '../lib/features/twitch/presentation/sheets/twitch_app_settings_sheet.dart';

// These panes are deliberately never selected: no player or update side effects.
class _UnusedPlayer extends ChangeNotifier
    implements TwitchPlayerSettingsController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedUpdate extends ChangeNotifier implements VioClassUpdateController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Keep the production singleton queue in one test zone across both layouts.
  testWidgets('App chat settings saves through desktop and phone entries', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(900, 700), const Size(320, 640)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      // All production adapters below use mock platform storage, never host data.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      await twitchChatKeyboardController.reset();
      final appearance = TwitchChatAppearanceController();
      final player = _UnusedPlayer();
      final update = _UnusedUpdate();
      addTearDown(appearance.dispose);
      addTearDown(player.dispose);
      addTearDown(update.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchAppSettingsSheet(
              chatAppearanceController: appearance,
              playerSettingsController: player,
              updateController: update,
              viewerLabel: () => 'test',
              loginStatus: () => 'test',
              loadingLoginState: () => false,
              onLogin: () async {},
              onRefreshLogin: () async {},
              onLogout: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('聊天'));
      await tester.pumpAndSettle();
      final dropdown = find.byKey(const ValueKey('chat-key-user'));
      await tester.scrollUntilVisible(
        dropdown.hitTestable(),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('H').hitTestable(),
        -100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('H').hitTestable().last);
      await tester.pumpAndSettle();
      expect(
        twitchChatKeyboardController.bindings[TwitchChatKeyboardCommand.user],
        'H',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(TwitchChatKeyboardController.storageKey),
        contains('"user":"H"'),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
