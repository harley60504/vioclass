// Regression harness kept in the permitted docs scope.
// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

import '../lib/features/twitch/presentation/widgets/chat/twitch_selectable_emote.dart';

Future<Selectable> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SelectionArea(
            child: TwitchSelectableEmote(
              text: 'Kappa',
              child: const SizedBox(width: 28, height: 28),
            ),
          ),
        ),
      ),
    ),
  );
  return tester.renderObject(find.byType(TwitchSelectableEmote)) as Selectable;
}

void main() {
  for (final useSpan in [false, true]) {
    testWidgets(
      '${useSpan ? "unmodified Flutter WidgetSpan diagnostic" : "plain Flutter one-character baseline"} for Shift Right',
      (tester) async {
        String? copied;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SelectionArea(
                  child: useSpan
                      ? const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'before '),
                              WidgetSpan(child: Text('Kappa')),
                              TextSpan(text: ' after'),
                            ],
                          ),
                        )
                      : const Text('before Kappa after'),
                ),
              ),
            ),
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text(useSpan ? 'Kappa' : 'before Kappa after'),
            matching: find.byType(RichText),
          ),
        );
        final box = paragraph
            .getBoxesForSelection(
              TextSelection(
                baseOffset: useSpan ? 0 : 7,
                extentOffset: useSpan ? 5 : 12,
              ),
            )
            .first
            .toRect();
        final target = paragraph.localToGlobal(box.center);
        await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        // This diagnostic records the SDK behavior; product regression still
        // requires the correct single-character result in the inbox harness.
        expect(copied, useSpan ? 'Kappa after' : 'Kappa ');
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.windows}),
    );
  }
  testWidgets(
    'keyboard character and word selection treats emote as one token and traverses edges',
    (tester) async {
      final selectable = await _open(tester);
      for (final granularity in [
        TextGranularity.character,
        TextGranularity.word,
      ]) {
        selectable.dispatchSelectionEvent(const ClearSelectionEvent());
        final forward = GranularlyExtendSelectionEvent(
          forward: true,
          isEnd: true,
          granularity: granularity,
        );
        expect(selectable.dispatchSelectionEvent(forward), SelectionResult.end);
        expect(selectable.getSelectedContent()!.plainText, 'Kappa');
        expect(
          selectable.dispatchSelectionEvent(forward),
          SelectionResult.next,
        );
        final backward = GranularlyExtendSelectionEvent(
          forward: false,
          isEnd: true,
          granularity: granularity,
        );
        expect(
          selectable.dispatchSelectionEvent(backward),
          SelectionResult.end,
        );
        expect(selectable.value.status, SelectionStatus.collapsed);
        expect(selectable.getSelectedContent(), isNull);
        expect(
          selectable.dispatchSelectionEvent(backward),
          SelectionResult.previous,
        );
      }
      selectable.dispatchSelectionEvent(const ClearSelectionEvent());
      expect(
        selectable.dispatchSelectionEvent(
          const GranularlyExtendSelectionEvent(
            forward: true,
            isEnd: false,
            granularity: TextGranularity.character,
          ),
        ),
        SelectionResult.end,
      );
      expect(selectable.getSelectedContent()!.plainText, 'Kappa');
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'vertical and horizontal directional selection respect image bounds',
    (tester) async {
      final selectable = await _open(tester);
      final rect = tester.getRect(find.byType(TwitchSelectableEmote));
      expect(
        selectable.dispatchSelectionEvent(
          DirectionallyExtendSelectionEvent(
            dx: rect.right,
            isEnd: true,
            direction: SelectionExtendDirection.forward,
          ),
        ),
        SelectionResult.end,
      );
      expect(selectable.getSelectedContent()!.plainText, 'Kappa');
      expect(
        selectable.dispatchSelectionEvent(
          DirectionallyExtendSelectionEvent(
            dx: rect.left,
            isEnd: true,
            direction: SelectionExtendDirection.backward,
          ),
        ),
        SelectionResult.end,
      );
      expect(selectable.getSelectedContent(), isNull);
      expect(
        selectable.dispatchSelectionEvent(
          DirectionallyExtendSelectionEvent(
            dx: rect.center.dx,
            isEnd: true,
            direction: SelectionExtendDirection.nextLine,
          ),
        ),
        SelectionResult.next,
      );
      expect(selectable.getSelectedContent()!.plainText, 'Kappa');
      expect(
        selectable.dispatchSelectionEvent(
          DirectionallyExtendSelectionEvent(
            dx: rect.center.dx,
            isEnd: true,
            direction: SelectionExtendDirection.previousLine,
          ),
        ),
        SelectionResult.previous,
      );
      expect(selectable.getSelectedContent(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'paragraph hit and absorption include whole token without selecting outside hit',
    (tester) async {
      final selectable = await _open(tester);
      final rect = tester.getRect(find.byType(TwitchSelectableEmote));
      selectable.dispatchSelectionEvent(
        SelectParagraphSelectionEvent(
          globalPosition: rect.topLeft - const Offset(5, 5),
        ),
      );
      expect(selectable.getSelectedContent(), isNull);
      selectable.dispatchSelectionEvent(
        SelectParagraphSelectionEvent(globalPosition: rect.center),
      );
      expect(selectable.getSelectedContent()!.plainText, 'Kappa');
      selectable.dispatchSelectionEvent(const ClearSelectionEvent());
      selectable.dispatchSelectionEvent(
        SelectParagraphSelectionEvent(
          globalPosition: rect.topLeft - const Offset(5, 5),
          absorb: true,
        ),
      );
      expect(selectable.getSelectedContent()!.plainText, 'Kappa');
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'emote selection has real image bounds and original code; clearing unregisters safely',
    (tester) async {
      final selectable = await _open(tester);
      var updates = 0;
      void changed() => updates++;
      selectable.addListener(changed);
      expect(selectable.boundingBoxes, [const Rect.fromLTWH(0, 0, 28, 28)]);
      expect(selectable.contentLength, 5);
      selectable.dispatchSelectionEvent(const SelectAllSelectionEvent());
      expect(selectable.getSelectedContent()!.plainText, 'Kappa');
      expect(selectable.getSelection()!.startOffset, 0);
      expect(selectable.getSelection()!.endOffset, 5);
      expect(selectable.value.selectionRects, selectable.boundingBoxes);
      selectable.dispatchSelectionEvent(const ClearSelectionEvent());
      expect(selectable.getSelectedContent(), isNull);
      expect(selectable.value.status, SelectionStatus.none);
      expect(updates, greaterThanOrEqualTo(2));
      selectable.removeListener(changed);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'image edge selection is atomic in both directions and reports traversal',
    (tester) async {
      final selectable = await _open(tester);
      final rect = tester.getRect(find.byType(TwitchSelectableEmote));
      final before = rect.centerLeft - const Offset(1, 0);
      final after = rect.centerRight + const Offset(1, 0);
      expect(
        selectable.dispatchSelectionEvent(
          SelectionEdgeUpdateEvent.forStart(globalPosition: before),
        ),
        SelectionResult.previous,
      );
      expect(selectable.value.status, SelectionStatus.collapsed);
      expect(selectable.getSelectedContent(), isNull);
      expect(
        selectable.dispatchSelectionEvent(
          SelectionEdgeUpdateEvent.forEnd(globalPosition: after),
        ),
        SelectionResult.next,
      );
      expect(selectable.getSelectedContent()!.plainText, 'Kappa');
      selectable.dispatchSelectionEvent(const ClearSelectionEvent());
      selectable.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forStart(globalPosition: after),
      );
      selectable.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forEnd(globalPosition: before),
      );
      expect(selectable.getSelectedContent()!.plainText, 'Kappa');
      expect(selectable.getSelection()!.startOffset, 5);
      expect(selectable.getSelection()!.endOffset, 0);
      selectable.dispatchSelectionEvent(const ClearSelectionEvent());
      selectable.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forStart(globalPosition: before),
      );
      selectable.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forEnd(globalPosition: before),
      );
      expect(selectable.getSelectedContent(), isNull);
      expect(selectable.value.status, SelectionStatus.collapsed);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
