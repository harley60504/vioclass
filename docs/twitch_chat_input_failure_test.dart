import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart';

void main() {
  for (final change in [
    'same',
    'busy-rebuild',
    'disabled',
    'new-controller',
    'new-context',
    'unmounted',
  ]) {
    testWidgets('Late input error follows current composer change=$change', (
      tester,
    ) async {
      final first = TextEditingController(text: 'fixture message');
      final second = TextEditingController(text: 'new fixture draft');
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final gate = Completer<void>();
      var sends = 0;
      Future<void> send() {
        sends++;
        return gate.future;
      }

      Future<void> render({
        bool enabled = true,
        bool busy = false,
        bool replaced = false,
        bool mounted = true,
        int source = 1,
      }) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: mounted
                ? TwitchChatInputBar(
                    key: const ValueKey('composer'),
                    controller: replaced ? second : first,
                    enabled: enabled,
                    sending: busy,
                    onSend: send,
                    sendContext: source,
                  )
                : const SizedBox(),
          ),
        ),
      );
      await render();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(sends, 1);
      await render(
        enabled: change != 'disabled',
        busy: change == 'busy-rebuild',
        replaced: change == 'new-controller',
        mounted: change != 'unmounted',
        source: change == 'new-context' ? 2 : 1,
      );
      gate.completeError(StateError('fixture failure'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.text('fixture failure'),
        change == 'same' || change == 'busy-rebuild'
            ? findsOneWidget
            : findsNothing,
      );
      expect(second.text, 'new fixture draft');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
