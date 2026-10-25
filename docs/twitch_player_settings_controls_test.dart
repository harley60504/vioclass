import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vioclass/features/twitch/models/playback/twitch_m3u8_variant.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/player/twitch_player_more_actions_button.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/player/twitch_player_quality_button.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/player/twitch_player_settings_drawer.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_playlist_player_runtime.dart';

class _Player implements Player {
  double rate = 1;
  @override
  PlayerState get state => PlayerState(rate: rate);
  @override
  Future<void> setRate(double value, {bool synchronized = true}) async {
    rate = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Runtime implements TwitchPlaylistPlayerRuntime {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    // These Flutter tests live in docs under the repository workflow.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
  });
  for (final height in [160.0, 360.0]) {
    testWidgets(
      'Settings slide inside player and do not block chat height=$height',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var chatTaps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      key: const ValueKey('video-viewport'),
                      width: 640,
                      height: height,
                      child: PlayerSettingsDrawerHost(
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: PlayerMoreActionsButton(
                            playerRuntime: _Runtime(),
                            player: _Player(),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => chatTaps++,
                        child: const SizedBox(
                          height: 360,
                          child: Center(child: Text('chat remains usable')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('播放器設定'));
        await tester.pumpAndSettle();
        final viewport = tester.getRect(
          find.byKey(const ValueKey('video-viewport')),
        );
        final panel = tester.getRect(
          find.byKey(const ValueKey('player-settings-drawer')),
        );
        expect(panel.right, viewport.right);
        expect(panel.top, viewport.top);
        expect(panel.bottom, viewport.bottom);
        expect(panel.left, greaterThanOrEqualTo(viewport.left));
        expect(find.byType(Dialog), findsNothing);
        await tester.tap(find.text('chat remains usable'));
        expect(chatTaps, 1);
        expect(
          find.byKey(const ValueKey('player-settings-drawer')),
          findsOneWidget,
        );
        await tester.tapAt(viewport.topLeft + const Offset(8, 8));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('player-settings-drawer')),
          findsNothing,
        );
        await tester.tap(find.byTooltip('播放器設定'));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('player-settings-drawer')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final width in [320.0, 1000.0]) {
    testWidgets(
      'Player settings keep preferences without speed controls width=$width',
      (tester) async {
        tester.view.physicalSize = Size(width, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final player = _Player();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlayerSettingsDrawerHost(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: PlayerMoreActionsButton(
                    playerRuntime: _Runtime(),
                    player: player,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('播放器設定'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(
          find.byKey(const ValueKey('player-settings-drawer')),
          findsOneWidget,
        );
        expect(find.text('播放預設'), findsOneWidget);
        expect(find.text('播放速度'), findsNothing);
        await tester.tap(find.byTooltip('關閉'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('player-settings-drawer')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Highest and auto modes select video and persist mode', (
    tester,
  ) async {
    const high = TwitchM3u8Variant(
      name: '1080p',
      url: 'fixture-high',
      resolution: '1920x1080',
    );
    const low = TwitchM3u8Variant(
      name: '360p',
      url: 'fixture-low',
      resolution: '640x360',
    );
    var current = low;
    final player = _Player();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => QualityButton(
              player: player,
              variants: const [low, high],
              currentVariant: current,
              onChanged: (value) => update(() => current = value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('畫質'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最高畫質'));
    await tester.pumpAndSettle();
    expect(current, high);
    expect(find.byTooltip('畫質：最高畫質'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('畫質'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自動'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('畫質：自動'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Quick menu changes speed and returns home when reopened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final player = _Player();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: QualityButton(
              player: player,
              variants: const [],
              currentVariant: null,
              onChanged: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.text('1×'), findsOneWidget);
    await tester.tap(find.text('播放速度'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('1×'), findsOneWidget);
    await tester.tap(find.text('播放速度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5×'));
    await tester.pumpAndSettle();
    expect(player.rate, 1.5);
    expect(find.byKey(const ValueKey('player-anchored-popover')), findsNothing);
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.text('1.5×'), findsOneWidget);
    expect(find.text('播放速度'), findsOneWidget);
    expect(find.text('畫質'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
