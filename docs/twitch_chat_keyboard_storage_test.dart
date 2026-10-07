// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/twitch/presentation/settings/twitch_chat_keyboard_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Default SharedPreferences adapter reloads and reset preserves other settings',
    () async {
      // Mock-only platform storage in a flutter test fixture.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({
        'fixture_unrelated_setting': 'keep',
      });
      final first = TwitchChatKeyboardController();
      addTearDown(first.dispose);
      await first.load();
      await first.setBinding(TwitchChatKeyboardCommand.user, 'H');
      await first.setBinding(TwitchChatKeyboardCommand.context, null);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(TwitchChatKeyboardController.storageKey),
        contains('"user":"H"'),
      );
      final reloaded = TwitchChatKeyboardController();
      addTearDown(reloaded.dispose);
      await reloaded.load();
      expect(reloaded.bindings[TwitchChatKeyboardCommand.user], 'H');
      expect(reloaded.bindings[TwitchChatKeyboardCommand.context], isNull);
      await reloaded.reset();
      final afterReset = TwitchChatKeyboardController();
      addTearDown(afterReset.dispose);
      await afterReset.load();
      expect(afterReset.bindings, TwitchChatKeyboardController.defaults);
      expect(prefs.getString('fixture_unrelated_setting'), 'keep');
      expect(prefs.getKeys(), {
        'fixture_unrelated_setting',
        TwitchChatKeyboardController.storageKey,
      });
    },
  );
  test(
    'Saved bindings and disabled action reload, conflicts never write',
    () async {
      String? stored;
      var writes = 0;
      final first = TwitchChatKeyboardController(
        read: () async => stored,
        write: (raw) async {
          stored = raw;
          writes++;
          return true;
        },
      );
      addTearDown(first.dispose);
      await first.load();
      await first.setBinding(TwitchChatKeyboardCommand.user, 'H');
      await first.setBinding(TwitchChatKeyboardCommand.context, null);
      await expectLater(
        first.setBinding(TwitchChatKeyboardCommand.newer, 'H'),
        throwsArgumentError,
      );
      await expectLater(
        first.setBinding(TwitchChatKeyboardCommand.newer, 'Tab'),
        throwsArgumentError,
      );
      expect(writes, 2);
      final second = TwitchChatKeyboardController(
        read: () async => stored,
        write: (_) async => throw StateError('no write on read'),
      );
      addTearDown(second.dispose);
      await second.load();
      expect(
        second.keyFor(TwitchChatKeyboardCommand.user),
        LogicalKeyboardKey.keyH,
      );
      expect(second.keyFor(TwitchChatKeyboardCommand.context), isNull);
    },
  );
  test(
    'Corrupt or unsupported data is preserved until explicit reset',
    () async {
      for (final original in ['broken', '{"version":2,"bindings":{}}']) {
        var stored = original;
        var writes = 0;
        final controller = TwitchChatKeyboardController(
          read: () async => stored,
          write: (raw) async {
            writes++;
            stored = raw;
            return true;
          },
        );
        await controller.load();
        expect(controller.corrupt, isTrue);
        await expectLater(
          controller.setBinding(TwitchChatKeyboardCommand.user, 'H'),
          throwsStateError,
        );
        expect(stored, original);
        expect(writes, 0);
        await controller.reset();
        expect(controller.corrupt, isFalse);
        expect(writes, 1);
        controller.dispose();
      }
    },
  );
  test(
    'Failed persistence never changes active binding and can be retried',
    () async {
      var accepted = false;
      final controller = TwitchChatKeyboardController(
        read: () async => null,
        write: (_) async => accepted,
      );
      addTearDown(controller.dispose);
      await controller.load();
      await expectLater(
        controller.setBinding(TwitchChatKeyboardCommand.user, 'H'),
        throwsStateError,
      );
      expect(
        controller.keyFor(TwitchChatKeyboardCommand.user),
        LogicalKeyboardKey.keyU,
      );
      accepted = true;
      await controller.setBinding(TwitchChatKeyboardCommand.user, 'H');
      expect(
        controller.keyFor(TwitchChatKeyboardCommand.user),
        LogicalKeyboardKey.keyH,
      );
    },
  );
  test(
    'Concurrent changes serialize, waiting save is not reported as applied',
    () async {
      final gate = Completer<bool>();
      final saved = <String>[];
      final controller = TwitchChatKeyboardController(
        read: () async => null,
        write: (raw) async {
          saved.add(raw);
          return saved.length == 1 ? gate.future : true;
        },
      );
      addTearDown(controller.dispose);
      await controller.load();
      final first = controller.setBinding(TwitchChatKeyboardCommand.user, 'H');
      final second = controller.setBinding(
        TwitchChatKeyboardCommand.newer,
        'N',
      );
      await Future<void>.delayed(Duration.zero);
      expect(saved, hasLength(1));
      expect(
        controller.keyFor(TwitchChatKeyboardCommand.user),
        LogicalKeyboardKey.keyU,
      );
      gate.complete(true);
      await Future.wait([first, second]);
      expect(controller.bindings[TwitchChatKeyboardCommand.user], 'H');
      expect(controller.bindings[TwitchChatKeyboardCommand.newer], 'N');
      expect(saved, hasLength(2));
    },
  );
}
