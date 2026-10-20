// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/models/playback/twitch_m3u8_variant.dart';
import '../lib/features/twitch/presentation/widgets/player/twitch_quality_overlay_menu.dart';
import '../lib/features/twitch/presentation/widgets/watch/player/twitch_player_quality_button.dart';

const source = TwitchM3u8Variant(
  name: '1080p source',
  url: 'https://fixture.invalid/source',
  resolution: '1920x1080',
);
const low = TwitchM3u8Variant(
  name: '360p',
  url: 'https://fixture.invalid/low',
  resolution: '640x360',
);
const audio = TwitchM3u8Variant(
  name: 'Audio Only',
  url: 'https://fixture.invalid/audio',
  isAudioOnly: true,
);

void main() {
  for (final enabled in [true, false]) {
    testWidgets('quality popup availability follows callback $enabled', (
      tester,
    ) async {
      final selections = <TwitchM3u8Variant>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QualityButton(
              variants: const [source, low],
              currentVariant: source,
              onChanged: enabled ? selections.add : null,
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      final items = tester.widgetList<PopupMenuItem<TwitchM3u8Variant>>(
        find.byType(PopupMenuItem<TwitchM3u8Variant>),
      );
      expect(items.length, 2);
      expect(items.every((item) => item.enabled == enabled), isTrue);
      await tester.tap(find.text('360p'));
      await tester.pumpAndSettle();
      expect(selections, enabled ? [low] : isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('empty quality popup has no selectable placeholder', (
    tester,
  ) async {
    final selections = <TwitchM3u8Variant>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QualityButton(
            variants: const [],
            currentVariant: null,
            onChanged: selections.add,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<TwitchM3u8Variant>>(
            find.byType(PopupMenuItem<TwitchM3u8Variant>),
          )
          .enabled,
      isFalse,
    );
    expect(selections, isEmpty);
    expect(tester.takeException(), isNull);
  });
  for (final busy in [true, false]) {
    testWidgets('quality overlay guards busy and selected rows $busy', (
      tester,
    ) async {
      final selections = <TwitchM3u8Variant>[];
      var closes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: TwitchQualityOverlayMenu(
                variants: const [source, low, audio],
                currentVariant: source,
                busy: busy,
                onSelected: selections.add,
                onClose: () => closes++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('1080p source'));
      await tester.tap(find.text('360p'));
      expect(selections, busy ? isEmpty : [low]);
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(closes, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('quality overlay scrolls to audio in short narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selections = <TwitchM3u8Variant>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: TwitchQualityOverlayMenu(
              variants: const [source, low, audio],
              currentVariant: source,
              busy: false,
              onSelected: selections.add,
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Audio Only'), 60);
    await tester.tap(find.text('Audio Only'));
    expect(selections, [audio]);
    expect(tester.takeException(), isNull);
  });
}
