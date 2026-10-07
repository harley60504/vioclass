// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/presentation/settings/twitch_chat_keyboard_controller.dart';
import '../lib/features/twitch/presentation/widgets/settings/twitch_chat_keyboard_settings_card.dart';

Future<void> _open(
  WidgetTester tester,
  TwitchChatKeyboardController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TwitchChatKeyboardSettingsCard(controller: controller),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _visible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Future<void> _choose(WidgetTester tester, String command, String value) async {
  final dropdown = find.byKey(ValueKey('chat-key-$command'));
  await _visible(tester, dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(value).hitTestable(),
    -100,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pump();
  await tester.tap(find.text(value).hitTestable().last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Phone settings saves chosen key, rejects conflict and permits disable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var writes = 0;
      final controller = TwitchChatKeyboardController(
        read: () async => null,
        write: (_) async {
          writes++;
          return true;
        },
      );
      addTearDown(controller.dispose);
      await _open(tester, controller);
      await _choose(tester, 'user', 'H');
      expect(controller.bindings[TwitchChatKeyboardCommand.user], 'H');
      expect(writes, 1);
      await _choose(tester, 'newer', 'H');
      expect(controller.bindings[TwitchChatKeyboardCommand.newer], 'J');
      expect(writes, 1);
      await _visible(tester, find.text('此鍵位已由其他聊天室操作使用。'));
      expect(find.text('此鍵位已由其他聊天室操作使用。'), findsOneWidget);
      await _choose(tester, 'newer', '停用');
      expect(controller.bindings[TwitchChatKeyboardCommand.newer], isNull);
      expect(writes, 2);
      await _visible(tester, find.text('已保存聊天室鍵位。'));
      expect(find.text('已保存聊天室鍵位。'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Failed save shows error and retains active key without success',
    (tester) async {
      final controller = TwitchChatKeyboardController(
        read: () async => null,
        write: (_) async => false,
      );
      addTearDown(controller.dispose);
      await _open(tester, controller);
      await _choose(tester, 'user', 'H');
      expect(controller.bindings[TwitchChatKeyboardCommand.user], 'U');
      expect(find.text('已保存聊天室鍵位。'), findsNothing);
      await _visible(tester, find.text('鍵位保存失敗，未套用變更。'));
      expect(find.text('鍵位保存失敗，未套用變更。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Corrupt data reset requires confirmation; cancel preserves original',
    (tester) async {
      var stored = 'corrupt';
      var writes = 0;
      final controller = TwitchChatKeyboardController(
        read: () async => stored,
        write: (raw) async {
          stored = raw;
          writes++;
          return true;
        },
      );
      addTearDown(controller.dispose);
      await _open(tester, controller);
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const ValueKey('chat-key-older')),
            )
            .onChanged,
        isNull,
      );
      await _visible(tester, find.text('重設聊天室鍵位'));
      await tester.tap(find.text('重設聊天室鍵位'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(stored, 'corrupt');
      expect(writes, 0);
      await tester.tap(find.text('重設聊天室鍵位'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認重設'));
      await tester.pumpAndSettle();
      expect(controller.corrupt, isFalse);
      expect(writes, 1);
      expect(stored, isNot('corrupt'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final success in [true, false]) {
    testWidgets(
      'Close during pending save allows no late UI update: success=$success',
      (tester) async {
        final gate = Completer<bool>();
        final controller = TwitchChatKeyboardController(
          read: () async => null,
          write: (_) => gate.future,
        );
        addTearDown(controller.dispose);
        await _open(tester, controller);
        await _choose(tester, 'user', 'H');
        expect(controller.bindings[TwitchChatKeyboardCommand.user], 'U');
        expect(find.text('已保存聊天室鍵位。'), findsNothing);
        expect(
          tester
              .widget<DropdownButton<String>>(
                find.byKey(const ValueKey('chat-key-user')),
              )
              .onChanged,
          isNull,
        );
        await tester.pumpWidget(const SizedBox());
        gate.complete(success);
        await tester.pumpAndSettle();
        expect(
          controller.bindings[TwitchChatKeyboardCommand.user],
          success ? 'H' : 'U',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
