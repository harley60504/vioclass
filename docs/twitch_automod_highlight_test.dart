// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/models/chat/twitch_automod_highlight.dart';
import '../lib/features/twitch/models/chat/twitch_automod_queue.dart';
import '../lib/features/twitch/presentation/widgets/chat/twitch_automod_message_text.dart';

TwitchHeldAutomodMessage _message(String text, List<(int, int)> ranges) =>
    TwitchHeldAutomodMessage(
      id: 'held',
      userId: '30',
      userName: 'Chatter',
      text: text,
      reason: 'AutoMod',
      heldAt: DateTime.utc(2026),
      boundaries: ranges,
    );

List<TextSpan> _spans(WidgetTester tester) => tester
    .widget<SelectableText>(find.byType(SelectableText))
    .textSpan!
    .children!
    .cast<TextSpan>();

void main() {
  test(
    'ASCII inclusive endpoints merge overlap adjacent duplicates and sort',
    () {
      final mapped = TwitchAutomodHighlight.map('one bad word end', [
        (8, 11),
        (4, 6),
        (5, 8),
        (4, 6),
      ]);
      expect(mapped.ambiguous, false);
      expect(mapped.ranges, [(4, 12)]);
      expect(mapped.candidates.single.units, ['UTF-16', 'Unicode', 'UTF-8']);
      expect(
        () => mapped.candidates.single.units.add('fake'),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'reported non ASCII byte offset example maps without inventing padding',
    () {
      final mapped = TwitchAutomodHighlight.map('süßer hund', [(8, 11)]);
      expect(mapped.ranges, [(6, 10)]);
      expect(mapped.candidates.single.units, ['UTF-8']);
    },
  );

  test('valid competing Unicode indexes remain explicitly ambiguous', () {
    final mapped = TwitchAutomodHighlight.map('é bad tail', [(3, 5)]);
    expect(mapped.ambiguous, true);
    expect(mapped.ranges, isEmpty);
    expect(mapped.candidates.map((c) => c.ranges), [
      [(3, 6)],
      [(2, 5)],
    ]);
  });

  test('scalar and byte indexes never cut a surrogate pair', () {
    final scalar = TwitchAutomodHighlight.map('😀', [(0, 0)]);
    expect(scalar.ranges, [(0, 2)]);
    expect(scalar.candidates.single.units, ['Unicode']);
    final bytes = TwitchAutomodHighlight.map('😀', [(0, 3)]);
    expect(bytes.ranges, [(0, 2)]);
    expect(bytes.candidates.single.units, ['UTF-8']);
  });

  test('combining and ZWJ hits expand to whole grapheme clusters', () {
    expect(TwitchAutomodHighlight.map('e\u0301', [(0, 0)]).ranges, [(0, 2)]);
    expect(TwitchAutomodHighlight.map('👨‍👩‍👧‍👦', [(0, 0)]).ranges, [
      (0, 11),
    ]);
  });

  test(
    'invalid ranges reject the complete interpretation rather than clipping',
    () {
      for (final ranges in [
        <(int, int)>[(0, 99)],
        [(-1, 0)],
        [(3, 1)],
        [(0, 1), (9, 99)],
      ]) {
        expect(TwitchAutomodHighlight.map('hello', ranges).candidates, isEmpty);
      }
      expect(TwitchAutomodHighlight.map('', [(0, 0)]).candidates, isEmpty);
      expect(TwitchAutomodHighlight.map('hello', []).candidates, isEmpty);
    },
  );

  testWidgets('highlight keeps full original selectable text and native copy', (
    tester,
  ) async {
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    const raw = 'one bad\nword end';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchAutomodMessageText(message: _message(raw, [(4, 11)])),
        ),
      ),
    );
    final spans = _spans(tester);
    expect(spans.map((s) => s.text).join(), raw);
    expect(
      spans.where((s) => s.style?.backgroundColor != null).single.text,
      'bad\nword',
    );
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    editable.selectAll(SelectionChangedCause.toolbar);
    await tester.pump();
    editable.contextMenuButtonItems
        .singleWhere((b) => b.type == ContextMenuButtonType.copy)
        .onPressed!();
    await tester.pump();
    expect(copied, raw);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ambiguous positions show candidates without misleading main highlight',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchAutomodMessageText(
              message: _message('é bad tail', [(3, 5)]),
            ),
          ),
        ),
      );
      expect(
        _spans(tester).any((s) => s.style?.backgroundColor != null),
        false,
      );
      expect(find.text('命中位置有不同解讀，請核對原文。'), findsOneWidget);
      expect(find.text('UTF-16 / Unicode：ad '), findsOneWidget);
      expect(find.text('UTF-8：bad'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'malformed positions preserve raw text and show a mapping warning',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchAutomodMessageText(
              message: _message('original', [(9, 99)]),
            ),
          ),
        ),
      );
      expect(_spans(tester).map((s) => s.text).join(), 'original');
      expect(find.text('官方命中位置無法對應原文，請核對完整訊息。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
