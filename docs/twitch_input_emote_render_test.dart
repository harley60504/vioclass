import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/models/chat/twitch_chat_message.dart';
import 'package:vioclass/features/twitch/models/chat/twitch_chat_message_metadata.dart';
import 'package:vioclass/features/twitch/models/chat/twitch_chat_runtime_message.dart';
import 'package:vioclass/features/twitch/models/chat/twitch_chat_render_segment.dart';
import 'package:vioclass/features/twitch/presentation/widgets/chat/twitch_chat_input_emote_state.dart';
import 'package:vioclass/features/twitch/presentation/widgets/chat/twitch_input_emote_span_builder.dart';
import 'package:vioclass/features/twitch/presentation/widgets/chat/twitch_runtime_message_tile.dart';

const emote = TwitchChatInputEmote(
  id: '25',
  name: 'Kappa',
  imageUrl: 'https://example.invalid/emote.png',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Incoming keyboard value can render before controller is updated', () {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final span = TwitchInputEmoteSpanBuilder(
      controller: controller,
      resolve: (code) => code == 'Kappa' ? emote : null,
    ).build('hello Kappa');
    expect(
      span.children!.whereType<ExtendedWidgetSpan>().single.actualText,
      'Kappa',
    );
    expect(controller.text, isEmpty);
  });
  test('Typed codes render as emotes without changing draft or wire text', () {
    final controller = TextEditingController(text: '你好 Kappa unknown Kappa');
    addTearDown(controller.dispose);
    final span = TwitchInputEmoteSpanBuilder(
      controller: controller,
      resolve: (code) => code == 'Kappa' ? emote : null,
    ).build(controller.text);
    final images = span.children!.whereType<ExtendedWidgetSpan>().toList();
    expect(images.map((image) => image.actualText), ['Kappa', 'Kappa']);
    expect(images.map((image) => image.start), [3, 17]);
    expect(controller.text, '你好 Kappa unknown Kappa');
    expect(TwitchChatInputEmoteState.serialize(controller), controller.text);
  });

  test('IME composing text remains text until committed', () {
    final controller = TextEditingController.fromValue(
      const TextEditingValue(
        text: 'Kappa',
        composing: TextRange(start: 0, end: 5),
      ),
    );
    addTearDown(controller.dispose);
    final span = TwitchInputEmoteSpanBuilder(
      controller: controller,
      resolve: (_) => emote,
    ).build(controller.text);
    expect(span.children!.whereType<ExtendedWidgetSpan>(), isEmpty);
    expect(controller.value.composing, const TextRange(start: 0, end: 5));
  });

  test('Existing picker markers and typed codes coexist', () {
    final controller = TextEditingController(text: 'Kappa ');
    addTearDown(controller.dispose);
    TwitchChatInputEmoteState.insert(controller, emote);
    final span = TwitchInputEmoteSpanBuilder(
      controller: controller,
      resolve: (code) => code == 'Kappa' ? emote : null,
    ).build(controller.text);
    expect(TwitchChatInputEmoteState.serialize(controller), 'Kappa Kappa ');
    expect(span.children!.whereType<ExtendedWidgetSpan>(), hasLength(1));
    expect(
      span.children!.whereType<TextSpan>().any(
        (part) =>
            part.children?.any((child) => child is ExtendedWidgetSpan) == true,
      ),
      isTrue,
    );
  });

  testWidgets(
    'Chat long press copies raw message while tap still opens context',
    (tester) async {
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final raw = TwitchChatMessage(
        raw: '',
        command: 'PRIVMSG',
        channel: 'fixture',
        userLogin: 'peer',
        displayName: 'Peer',
        message: 'Kappa hello',
        tags: const {},
      );
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchRuntimeMessageTile(
              message: TwitchChatRuntimeMessage(
                source: raw,
                resolvedBadges: const [],
                receivedAt: DateTime.utc(2026),
                fragments: const [],
                segments: [TwitchChatRenderSegment.text(raw.message)],
                metadata: TwitchChatMessageMetadata.fromMessage(raw),
              ),
              onOpenContext: () => opened++,
            ),
          ),
        ),
      );
      await tester.longPress(find.textContaining('Kappa hello'));
      await tester.pump();
      expect(copied, 'Kappa hello');
      expect(opened, 0);
      await tester.tap(find.textContaining('Kappa hello'));
      expect(opened, 1);
    },
  );
}
