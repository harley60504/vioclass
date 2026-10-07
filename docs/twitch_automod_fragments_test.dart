// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/models/chat/twitch_automod_queue.dart';
import '../lib/features/twitch/presentation/widgets/chat/twitch_automod_message_text.dart';
import '../lib/features/twitch/presentation/widgets/chat/twitch_selectable_emote.dart';

Map<String, dynamic> _event() => {
  'message_id': 'held',
  'user_id': '30',
  'held_at': '2026-10-03T12:00:00Z',
  'reason': 'automod',
  'automod': {
    'category': 'aggressive',
    'level': 2,
    'boundaries': [
      {'start_pos': 2, 'end_pos': 8},
    ],
  },
  'message': {
    'text': 'a Kappa b Cheer100',
    'fragments': [
      {'type': 'text', 'text': 'a '},
      {
        'type': 'emote',
        'text': 'Kappa',
        'emote': {'id': '25', 'emote_set_id': '0'},
      },
      {'type': 'text', 'text': ' b '},
      {
        'type': 'cheermote',
        'text': 'Cheer100',
        'cheermote': {'prefix': 'cheer', 'bits': 100, 'tier': 100},
      },
    ],
  },
};

void main() {
  testWidgets(
    'failed emote images keep multiline original copy without duplicate fallback registration',
    (tester) async {
      const urls = [
        'https://static-cdn.jtvnw.net/emoticons/v2/25/default/dark/2.0',
        'https://static-cdn.jtvnw.net/emoticons/v2/1902/default/dark/2.0',
      ];
      final pending = <Completer<ImageInfo>>[];
      for (final url in urls) {
        final provider = NetworkImage(url);
        final completer = Completer<ImageInfo>();
        pending.add(completer);
        PaintingBinding.instance.imageCache.putIfAbsent(
          provider,
          () => OneFrameImageStreamCompleter(completer.future),
        );
        addTearDown(() => PaintingBinding.instance.imageCache.evict(provider));
      }
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
      final row = TwitchHeldAutomodMessage.parse({
        ..._event(),
        'message': {
          'text': 'Kappa\nBibleThump',
          'fragments': [
            {
              'type': 'emote',
              'text': 'Kappa',
              'emote': {'id': '25'},
            },
            {'type': 'text', 'text': '\n'},
            {
              'type': 'emote',
              'text': 'BibleThump',
              'emote': {'id': '1902'},
            },
          ],
        },
      })!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                child: TwitchAutomodMessageText(message: row),
              ),
            ),
          ),
        ),
      );
      for (final completer in pending) {
        completer.completeError(StateError('fixture download failure'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Kappa'), findsOneWidget);
      expect(find.text('BibleThump'), findsOneWidget);
      expect(find.byType(TwitchSelectableEmote), findsNWidgets(2));
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll();
      await tester.pump();
      region.contextMenuButtonItems
          .singleWhere((b) => b.type == ContextMenuButtonType.copy)
          .onPressed!();
      await tester.pump();
      expect(copied, 'Kappa\nBibleThump');
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'two loaded official images span lines and preserve full raw selection',
    (tester) async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 28, 28),
        ui.Paint()..color = const ui.Color(0xff663399),
      );
      final picture = recorder.endRecording();
      final bitmap = (await tester.runAsync(() => picture.toImage(28, 28)))!;
      picture.dispose();
      for (final id in ['25', '1902']) {
        final provider = NetworkImage(
          'https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0',
        );
        PaintingBinding.instance.imageCache.putIfAbsent(
          provider,
          () => OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: bitmap.clone())),
          ),
        );
        addTearDown(() => PaintingBinding.instance.imageCache.evict(provider));
      }
      bitmap.dispose();
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
      final row = TwitchHeldAutomodMessage.parse({
        ..._event(),
        'message': {
          'text': 'Kappa\nBibleThump',
          'fragments': [
            {
              'type': 'emote',
              'text': 'Kappa',
              'emote': {'id': '25'},
            },
            {'type': 'text', 'text': '\n'},
            {
              'type': 'emote',
              'text': 'BibleThump',
              'emote': {'id': '1902'},
            },
          ],
        },
      })!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                child: TwitchAutomodMessageText(message: row),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final images = find.byType(TwitchSelectableEmote);
      expect(
        tester.getCenter(images.last).dy,
        greaterThan(tester.getCenter(images.first).dy),
      );
      expect(
        tester
            .widgetList<RawImage>(find.byType(RawImage))
            .every((image) => image.image != null),
        true,
      );
      expect(find.byType(RawImage), findsNWidgets(2));
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll();
      await tester.pump();
      region.contextMenuButtonItems
          .singleWhere((b) => b.type == ContextMenuButtonType.copy)
          .onPressed!();
      await tester.pump();
      expect(copied, row.text);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );
  test('official fragments preserve text order ID set and Bits metadata', () {
    final row = TwitchHeldAutomodMessage.parse(_event())!;
    expect(row.fragments.map((f) => f.text).join(), row.text);
    expect(row.fragments[1].emote!.id, '25');
    expect(row.fragments[1].emote!.emoteSetId, '0');
    expect(
      row.fragments[1].emote!.imageUrl,
      'https://static-cdn.jtvnw.net/emoticons/v2/25/default/dark/2.0',
    );
    expect(row.fragments.last.bits, 100);
    expect(row.fragments.last.cheerPrefix, 'cheer');
    expect(row.fragments.last.cheerTier, 100);
    expect(() => row.fragments.clear(), throwsUnsupportedError);
  });

  test(
    'invalid IDs and malformed metadata never invent an image or Bits count',
    () {
      for (final id in ['../25', '25?host=evil', 'https://evil.test', '', 25]) {
        final parts = TwitchAutomodFragment.parse('Kappa', [
          {
            'type': 'emote',
            'text': 'Kappa',
            'emote': {'id': id},
          },
        ]);
        expect(parts.single.text, 'Kappa');
        expect(parts.single.emote, isNull);
      }
      final parts = TwitchAutomodFragment.parse('Cheer100', [
        {
          'type': 'cheermote',
          'text': 'Cheer100',
          'cheermote': {'bits': '100', 'prefix': 'cheer', 'tier': 100},
        },
      ]);
      expect(parts.single.bits, isNull);
    },
  );

  test(
    'missing unknown and inconsistent fragments preserve full original only',
    () {
      for (final fragments in [
        null,
        [],
        ['invalid'],
        [
          {'text': 'truncated'},
        ],
      ]) {
        final parts = TwitchAutomodFragment.parse('raw Kappa', fragments);
        expect(parts.single.text, 'raw Kappa');
        expect(parts.single.emote, isNull);
      }
      final unknown = TwitchAutomodFragment.parse('Kappa', [
        {
          'type': 'future',
          'text': 'Kappa',
          'emote': {'id': '25'},
        },
      ]);
      expect(unknown.single.emote, isNull);
    },
  );

  testWidgets(
    'loaded official image retains highlight raw copy and character selection',
    (tester) async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 28, 28),
        ui.Paint()..color = const ui.Color(0xff663399),
      );
      final picture = recorder.endRecording();
      final bitmap = (await tester.runAsync(() => picture.toImage(28, 28)))!;
      picture.dispose();
      const provider = NetworkImage(
        'https://static-cdn.jtvnw.net/emoticons/v2/25/default/dark/2.0',
      );
      PaintingBinding.instance.imageCache.putIfAbsent(
        provider,
        () => OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: bitmap)),
        ),
      );
      addTearDown(() => PaintingBinding.instance.imageCache.evict(provider));
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
      final row = TwitchHeldAutomodMessage.parse(_event())!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: TwitchAutomodMessageText(message: row),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(find.text('Cheer100 · 100 Bits'), findsOneWidget);
      final decoration = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(TwitchSelectableEmote),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((decoration.decoration as BoxDecoration).border, isNotNull);
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll();
      await tester.pump();
      region.contextMenuButtonItems
          .singleWhere((b) => b.type == ContextMenuButtonType.copy)
          .onPressed!();
      await tester.pump();
      expect(copied, row.text);
      region.clearSelection();
      final target = tester.getCenter(find.byType(TwitchSelectableEmote));
      await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(target, kind: ui.PointerDeviceKind.mouse);
      await tester.pump();
      Focus.of(
        tester.element(find.byType(TwitchSelectableEmote)),
      ).requestFocus();
      for (final expected in ['Kappa', 'Kappa ']) {
        if (expected.endsWith(' ')) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        }
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(copied, expected);
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );
}
