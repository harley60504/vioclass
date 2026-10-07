// Regression harness kept in the permitted docs scope.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/models/chat/twitch_whisper_emote_catalog.dart';
import '../lib/features/twitch/models/emotes/twitch_official_emote.dart';
import '../lib/features/twitch/presentation/widgets/chat/twitch_selectable_emote.dart';
import '../lib/features/twitch/presentation/widgets/chat/twitch_whisper_selection.dart';

final _catalog = TwitchWhisperEmoteCatalog(const [
  TwitchOfficialEmote(
    id: '25',
    name: 'Kappa',
    imageUrl: 'https://example.test/kappa.png',
    emoteType: '',
    tier: '',
    emoteSetId: '',
    ownerId: '',
    source: TwitchOfficialEmoteSource.global,
    unlocked: true,
  ),
]);

class _ClipboardProbe {
  String? text;
  _ClipboardProbe() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        text = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }
}

Future<void> _show(
  WidgetTester tester,
  String raw, {
  TwitchWhisperEmoteCatalog? catalog,
  double width = 280,
}) async {
  final parts = (catalog ?? _catalog).parse(raw);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SelectionArea(
              child: TwitchWhisperSelection(
                parts: parts,
                span: TextSpan(
                  children: [
                    for (final part in parts)
                      if (part.emote == null)
                        TextSpan(text: part.text)
                      else
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: TwitchSelectableEmote(
                            text: part.text,
                            child: const SizedBox(
                              width: 28,
                              height: 28,
                              child: ColoredBox(color: Colors.purple),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _keyboardCopy(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  testWidgets(
    'keyboard selection crosses soft wrap without inserting a newline',
    (tester) async {
      final clipboard = _ClipboardProbe();
      await _show(tester, 'before Kappa x Kappa end', width: 128);
      final images = find.byType(TwitchSelectableEmote);
      expect(
        tester.getCenter(images.last).dy,
        greaterThan(tester.getCenter(images.first).dy),
      );
      final target = tester.getCenter(images.first);
      await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
      await tester.pump();
      for (final expected in [
        'Kappa ',
        'Kappa x',
        'Kappa x ',
        'Kappa x Kappa',
      ]) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        clipboard.text = null;
        await _keyboardCopy(tester);
        expect(clipboard.text, expected);
      }
      for (final expected in ['Kappa x ', 'Kappa x', 'Kappa ', 'Kappa']) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        clipboard.text = null;
        await _keyboardCopy(tester);
        expect(clipboard.text, expected);
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );
  testWidgets(
    'catalog arrival and removal keep original copy with updated token geometry',
    (tester) async {
      final clipboard = _ClipboardProbe();
      const raw = 'before Kappa after';
      await _show(
        tester,
        raw,
        catalog: const TwitchWhisperEmoteCatalog.empty(),
      );
      expect(find.byType(TwitchSelectableEmote), findsNothing);
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pump();
      Focus.of(
        tester.element(find.byType(TwitchWhisperSelection)),
      ).requestFocus();
      await _keyboardCopy(tester);
      expect(clipboard.text, raw);
      await _show(tester, raw);
      expect(tester.takeException(), isNull);
      expect(
        tester.state<SelectableRegionState>(find.byType(SelectableRegion)),
        same(region),
      );
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pump();
      expect(
        (tester.renderObject(find.byType(TwitchSelectableEmote)) as Selectable)
            .getSelectedContent()
            ?.plainText,
        'Kappa',
      );
      Focus.of(
        tester.element(find.byType(TwitchWhisperSelection)),
      ).requestFocus();
      clipboard.text = null;
      await _keyboardCopy(tester);
      expect(clipboard.text, raw);
      region.clearSelection();
      region.hideToolbar();
      await tester.pump(const Duration(milliseconds: 500));
      final target = tester.getCenter(find.byType(TwitchSelectableEmote));
      await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
      await tester.pump();
      expect(
        (tester.renderObject(find.byType(TwitchSelectableEmote)) as Selectable)
            .getSelectedContent()
            ?.plainText,
        'Kappa',
      );
      Focus.of(
        tester.element(find.byType(TwitchSelectableEmote)),
      ).requestFocus();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      clipboard.text = null;
      await _keyboardCopy(tester);
      expect(clipboard.text, 'Kappa ');
      await _show(
        tester,
        raw,
        catalog: const TwitchWhisperEmoteCatalog.empty(),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(TwitchSelectableEmote), findsNothing);
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pump();
      Focus.of(
        tester.element(find.byType(TwitchWhisperSelection)),
      ).requestFocus();
      clipboard.text = null;
      await _keyboardCopy(tester);
      expect(clipboard.text, raw);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets(
    'keyboard selection crosses explicit newline and image on next line',
    (tester) async {
      final clipboard = _ClipboardProbe();
      await _show(tester, 'before Kappa\nx Kappa end');
      final images = find.byType(TwitchSelectableEmote);
      expect(
        tester.getCenter(images.last).dy,
        greaterThan(tester.getCenter(images.first).dy),
      );
      final target = tester.getCenter(images.first);
      await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
      await tester.pump();
      for (final expected in [
        'Kappa\n',
        'Kappa\nx',
        'Kappa\nx ',
        'Kappa\nx Kappa',
      ]) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        clipboard.text = null;
        await _keyboardCopy(tester);
        expect(clipboard.text, expected);
      }
      for (final expected in ['Kappa\nx ', 'Kappa\nx', 'Kappa\n', 'Kappa']) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        clipboard.text = null;
        await _keyboardCopy(tester);
        expect(clipboard.text, expected);
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );
  testWidgets(
    'unchanged rebuild preserves selected image and keyboard movement',
    (tester) async {
      final clipboard = _ClipboardProbe();
      await _show(tester, 'before Kappa after');
      final target = tester.getCenter(find.byType(TwitchSelectableEmote));
      await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
      await tester.pump();
      await _show(tester, 'before Kappa after');
      await _keyboardCopy(tester);
      expect(clipboard.text, 'Kappa');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      clipboard.text = null;
      await _keyboardCopy(tester);
      expect(clipboard.text, 'Kappa ');
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );
  testWidgets(
    'updated message uses current raw offsets without an external key',
    (tester) async {
      final clipboard = _ClipboardProbe();
      await _show(tester, 'a Kappa old');
      await _show(tester, 'longer prefix Kappa 👨‍👩‍👧‍👦 end');
      final target = tester.getCenter(find.byType(TwitchSelectableEmote));
      await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
      await tester.pump();
      for (final expected in ['Kappa ', 'Kappa 👨‍👩‍👧‍👦']) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        clipboard.text = null;
        await _keyboardCopy(tester);
        expect(clipboard.text, expected);
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );
  testWidgets(
    'Android long press image copies its token and clears selection',
    (tester) async {
      final clipboard = _ClipboardProbe();
      await _show(tester, 'before Kappa after');
      await tester.longPress(find.byType(TwitchSelectableEmote));
      await tester.pumpAndSettle();
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.contextMenuButtonItems
          .singleWhere((item) => item.type == ContextMenuButtonType.copy)
          .onPressed!();
      await tester.pumpAndSettle();
      expect(clipboard.text, 'Kappa');
      expect(
        region.contextMenuButtonItems.where(
          (item) => item.type == ContextMenuButtonType.copy,
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'keyboard crosses emoji combining mark and a second image atomically',
    (tester) async {
      final clipboard = _ClipboardProbe();
      await _show(tester, 'before Kappa 👨‍👩‍👧‍👦 e\u0301 Kappa end');
      final target = tester.getCenter(find.byType(TwitchSelectableEmote).first);
      await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
      await tester.pump();
      for (final expected in [
        'Kappa ',
        'Kappa 👨‍👩‍👧‍👦',
        'Kappa 👨‍👩‍👧‍👦 ',
        'Kappa 👨‍👩‍👧‍👦 e\u0301',
        'Kappa 👨‍👩‍👧‍👦 e\u0301 ',
        'Kappa 👨‍👩‍👧‍👦 e\u0301 Kappa',
      ]) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        clipboard.text = null;
        await _keyboardCopy(tester);
        expect(clipboard.text, expected);
      }
      for (final expected in [
        'Kappa 👨‍👩‍👧‍👦 e\u0301 ',
        'Kappa 👨‍👩‍👧‍👦 e\u0301',
        'Kappa 👨‍👩‍👧‍👦 ',
        'Kappa 👨‍👩‍👧‍👦',
        'Kappa ',
        'Kappa',
      ]) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        clipboard.text = null;
        await _keyboardCopy(tester);
        expect(clipboard.text, expected);
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );
}
