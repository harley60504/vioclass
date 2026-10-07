// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/presentation/settings/twitch_chat_keyboard_controller.dart';
import '../lib/features/twitch/presentation/widgets/chat/message/twitch_chat_message_keyboard_access.dart';
import '../lib/features/twitch/presentation/widgets/chat/twitch_chat_message_list.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message_metadata.dart';
import '../lib/features/twitch/models/chat/twitch_chat_runtime_message.dart';
import '../lib/features/twitch/models/chat/twitch_chat_moderation_shortcut.dart';

void main() {
  testWidgets(
    'Focused message dispatches exact Ctrl shortcuts, not editing or repeat',
    (tester) async {
      final focus = FocusNode();
      final editor = FocusNode();
      addTearDown(focus.dispose);
      addTearDown(editor.dispose);
      final actions = <TwitchChatModerationShortcut>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchChatMessageKeyboardAccess(
              focusNode: focus,
              onOpenContext: () {},
              onModerationShortcut: actions.add,
              child: TextField(focusNode: editor),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      for (final key in [
        LogicalKeyboardKey.keyD,
        LogicalKeyboardKey.keyT,
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyB,
      ]) {
        await tester.sendKeyEvent(key);
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(actions, [
        ...TwitchChatModerationShortcut.values,
        TwitchChatModerationShortcut.delete,
      ]);
      editor.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(actions.length, 6);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Shared settings update two independent feeds without moving their focus',
    (tester) async {
      final controller = TwitchChatKeyboardController(
        read: () async => null,
        write: (_) async => true,
      );
      addTearDown(controller.dispose);
      TwitchChatRuntimeMessage message(String id) {
        final raw = TwitchChatMessage(
          raw: '',
          command: 'PRIVMSG',
          channel: id,
          userLogin: 'peer',
          displayName: 'Peer',
          message: 'fixture',
          tags: {'id': id},
        );
        return TwitchChatRuntimeMessage(
          source: raw,
          resolvedBadges: const [],
          receivedAt: DateTime.utc(2026),
          fragments: const [],
          segments: const [],
          metadata: TwitchChatMessageMetadata.fromMessage(raw),
        );
      }

      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                for (final id in ['one', 'two'])
                  Expanded(
                    child: TwitchChatMessageFeed(
                      key: ValueKey(id),
                      messages: [message(id)],
                      keyboardController: controller,
                      onOpenUser: (_) => opened.add(id),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final one = tester
          .widget<TwitchChatMessageKeyboardAccess>(
            find.byKey(const ValueKey('id:one')),
          )
          .focusNode!;
      final two = tester
          .widget<TwitchChatMessageKeyboardAccess>(
            find.byKey(const ValueKey('id:two')),
          )
          .focusNode!;
      one.requestFocus();
      await tester.pump();
      await controller.setBinding(TwitchChatKeyboardCommand.user, 'H');
      await tester.pump();
      expect(one.hasPrimaryFocus, isTrue);
      expect(two.hasPrimaryFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      expect(opened, ['one']);
      two.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      expect(opened, ['one', 'two']);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Saved custom binding updates actual feed and old key no longer runs',
    (tester) async {
      String? stored;
      final controller = TwitchChatKeyboardController(
        read: () async => stored,
        write: (raw) async {
          stored = raw;
          return true;
        },
      );
      addTearDown(controller.dispose);
      final raw = TwitchChatMessage(
        raw: '',
        command: 'PRIVMSG',
        channel: 'fixture',
        userLogin: 'peer',
        displayName: 'Peer',
        message: 'fixture',
        tags: const {'id': 'official'},
      );
      final message = TwitchChatRuntimeMessage(
        source: raw,
        resolvedBadges: const [],
        receivedAt: DateTime.utc(2026),
        fragments: const [],
        segments: const [],
        metadata: TwitchChatMessageMetadata.fromMessage(raw),
      );
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchChatMessageFeed(
              messages: [message],
              keyboardController: controller,
              onOpenUser: (_) => opened++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<TwitchChatMessageKeyboardAccess>(
            find.byKey(const ValueKey('id:official')),
          )
          .focusNode!
          .requestFocus();
      await tester.pump();
      await controller.setBinding(TwitchChatKeyboardCommand.user, 'H');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      expect(opened, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      expect(opened, 1);
      expect(stored, isNotNull);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  for (final startKey in [LogicalKeyboardKey.keyJ, LogicalKeyboardKey.keyK]) {
    testWidgets('MOD starts on latest from pane with ${startKey.keyLabel}', (
      tester,
    ) async {
      final raw = TwitchChatMessage(
        raw: '',
        command: 'PRIVMSG',
        channel: 'fixture',
        userLogin: 'peer',
        displayName: 'Peer',
        message: 'fixture',
        tags: const {'id': 'latest'},
      );
      final message = TwitchChatRuntimeMessage(
        source: raw,
        resolvedBadges: const [],
        receivedAt: DateTime.utc(2026),
        fragments: const [],
        segments: const [],
        metadata: TwitchChatMessageMetadata.fromMessage(raw),
      );
      final users = <TwitchChatRuntimeMessage>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchChatMessageFeed(
              messages: [message],
              canStartKeyboardModeration: () => true,
              onOpenUser: users.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final pane = tester
          .widget<Focus>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Focus &&
                  widget.focusNode?.debugLabel == 'chat keyboard entry',
            ),
          )
          .focusNode!;
      expect(pane.hasPrimaryFocus, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(startKey);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(pane.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(startKey);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      expect(users.single, same(message));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Chat input keeps J and K while authorized pane exists', (
    tester,
  ) async {
    final input = FocusNode();
    addTearDown(input.dispose);
    final raw = TwitchChatMessage(
      raw: '',
      command: 'PRIVMSG',
      channel: 'fixture',
      userLogin: 'peer',
      displayName: 'Peer',
      message: 'fixture',
      tags: const {'id': 'latest'},
    );
    final message = TwitchChatRuntimeMessage(
      source: raw,
      resolvedBadges: const [],
      receivedAt: DateTime.utc(2026),
      fragments: const [],
      segments: const [],
      metadata: TwitchChatMessageMetadata.fromMessage(raw),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: TwitchChatMessageFeed(
                  messages: [message],
                  canStartKeyboardModeration: () => true,
                ),
              ),
              TextField(focusNode: input),
            ],
          ),
        ),
      ),
    );
    input.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(input.hasPrimaryFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  for (final revokeAfterKey in [false, true]) {
    testWidgets(
      'MOD entry rechecks permission: revokeAfterKey=$revokeAfterKey',
      (tester) async {
        var permitted = true;
        var users = 0;
        final raw = TwitchChatMessage(
          raw: '',
          command: 'PRIVMSG',
          channel: 'fixture',
          userLogin: 'peer',
          displayName: 'Peer',
          message: 'fixture',
          tags: const {'id': 'latest'},
        );
        final message = TwitchChatRuntimeMessage(
          source: raw,
          resolvedBadges: const [],
          receivedAt: DateTime.utc(2026),
          fragments: const [],
          segments: const [],
          metadata: TwitchChatMessageMetadata.fromMessage(raw),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TwitchChatMessageFeed(
                messages: [message],
                canStartKeyboardModeration: () => permitted,
                onOpenUser: (_) => users++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        if (!revokeAfterKey) permitted = false;
        await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
        permitted = false;
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
        expect(users, 0);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Navigation clamps boundary, keeps focus across live append and closes during pending jump',
    (tester) async {
      TwitchChatRuntimeMessage message(int index) {
        final raw = TwitchChatMessage(
          raw: '',
          command: 'PRIVMSG',
          channel: 'fixture',
          userLogin: 'peer',
          displayName: 'Peer',
          message: 'fixture',
          tags: {'id': '$index'},
        );
        return TwitchChatRuntimeMessage(
          source: raw,
          resolvedBadges: const [],
          receivedAt: DateTime.utc(2026).add(Duration(seconds: index)),
          fragments: const [],
          segments: const [],
          metadata: TwitchChatMessageMetadata.fromMessage(raw),
        );
      }

      final users = <TwitchChatRuntimeMessage>[];
      Future<void> render(List<TwitchChatRuntimeMessage> messages) =>
          tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TwitchChatMessageFeed(
                  messages: messages,
                  onOpenUser: users.add,
                ),
              ),
            ),
          );
      await render([message(0), message(1), message(2)]);
      await tester.pumpAndSettle();
      tester
          .widget<TwitchChatMessageKeyboardAccess>(
            find.byKey(const ValueKey('id:0')),
          )
          .focusNode!
          .requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      expect(users.last.id, '0');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pumpAndSettle();
      await render([message(0), message(1), message(2), message(3)]);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      expect(users.last.id, '1');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'J and K navigate beyond lazy viewport and initial hundred-message window',
    (tester) async {
      final messages = List.generate(160, (index) {
        final raw = TwitchChatMessage(
          raw: '',
          command: 'PRIVMSG',
          channel: 'fixture',
          userLogin: 'peer',
          displayName: 'Peer $index',
          message: 'fixture $index',
          tags: {'id': '$index', 'user-id': '30'},
        );
        return TwitchChatRuntimeMessage(
          source: raw,
          resolvedBadges: const [],
          receivedAt: DateTime.utc(2026).add(Duration(seconds: index)),
          fragments: const [],
          segments: const [],
          metadata: TwitchChatMessageMetadata.fromMessage(raw),
        );
      });
      final users = <TwitchChatRuntimeMessage>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchChatMessageFeed(
              messages: messages,
              onOpenUser: users.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<TwitchChatMessageKeyboardAccess>(
            find.byKey(const ValueKey('id:159')),
          )
          .focusNode!
          .requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      expect(users.last.id, '159');
      for (var index = 0; index < 115; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.pumpAndSettle();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      expect(users.last.id, '44');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      expect(users.last.id, '45');
      expect(find.byKey(const ValueKey('id:45')).hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Actual feed keyboard entry uses its selected message and disposes with feed',
    (tester) async {
      final raw = TwitchChatMessage(
        raw: '',
        command: 'PRIVMSG',
        channel: 'fixture',
        userLogin: 'peer',
        displayName: 'Peer',
        message: 'fixture text',
        tags: const {'id': 'official', 'user-id': '30'},
      );
      final message = TwitchChatRuntimeMessage(
        source: raw,
        resolvedBadges: const [],
        receivedAt: DateTime.utc(2026),
        fragments: const [],
        segments: const [],
        metadata: TwitchChatMessageMetadata.fromMessage(raw),
      );
      final users = <TwitchChatRuntimeMessage>[];
      final contexts = <TwitchChatRuntimeMessage>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchChatMessageFeed(
              messages: [message],
              onOpenUser: users.add,
              onOpenMessageContext: contexts.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focus = tester
          .widget<Focus>(
            find
                .descendant(
                  of: find.byType(TwitchChatMessageKeyboardAccess),
                  matching: find.byType(Focus),
                )
                .first,
          )
          .focusNode!;
      expect(focus.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(users.single, same(message));
      expect(contexts.single, same(message));
      await tester.pumpWidget(const SizedBox());
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(contexts, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Focused message opens user or context; repeats and modifiers do not dispatch',
    (tester) async {
      var contexts = 0;
      var users = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchChatMessageKeyboardAccess(
              onOpenContext: () => contexts++,
              onOpenUser: () => users++,
              child: const Text('fixture'),
            ),
          ),
        ),
      );
      final focus = tester
          .widget<Focus>(
            find
                .descendant(
                  of: find.byType(TwitchChatMessageKeyboardAccess),
                  matching: find.byType(Focus),
                )
                .first,
          )
          .focusNode!;
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect((users, contexts), (1, 1));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      expect(contexts, 1);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(contexts, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(focus.hasPrimaryFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      expect(users, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Editing descendant keeps letters and Enter without message action',
    (tester) async {
      var opened = 0;
      final input = FocusNode();
      addTearDown(input.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchChatMessageKeyboardAccess(
              onOpenContext: () => opened++,
              onOpenUser: () => opened++,
              child: TextField(focusNode: input),
            ),
          ),
        ),
      );
      input.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(opened, 0);
      expect(input.hasPrimaryFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
