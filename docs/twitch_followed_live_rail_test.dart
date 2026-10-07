// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/models/discovery/twitch_live_stream.dart';
import '../lib/features/twitch/presentation/widgets/home/twitch_followed_live_rail.dart';

TwitchLiveStream stream(int index) => TwitchLiveStream(
  id: '$index',
  userId: '$index',
  userLogin: 'peer$index',
  userName: 'Peer $index',
  gameId: '',
  gameName: 'Game $index',
  title: 'Title $index',
  viewerCount: 1301,
  startedAt: null,
  language: '',
  thumbnailUrl: '',
  tags: const [],
  isMature: false,
);

void main() {
  testWidgets(
    'Hover expands translucent rail without resizing the main content',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchFollowedLiveRailShell(
              loadStreams: () async => [stream(1), stream(2)],
              onSelect: (_) async {},
              child: const SizedBox.expand(key: ValueKey('content')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rail = find.byKey(const ValueKey('followed-live-rail'));
      final content = find.byKey(const ValueKey('content'));
      final before = tester.getRect(content);
      expect(find.byIcon(Icons.live_tv), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('live-rail-1'))).dy,
        lessThan(20),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(600, 100));
      await mouse.moveTo(const Offset(20, 100));
      await tester.pumpAndSettle();
      expect(tester.getSize(rail).width, 280);
      expect(tester.getRect(content), before);
      expect(tester.getTopLeft(content).dx, 60);
      expect(find.text('Peer 1'), findsOneWidget);
      expect(find.text('Game 1'), findsOneWidget);
      expect(find.text('1,301'), findsNWidgets(2));
      final background = tester.widget<ColoredBox>(
        find.descendant(of: rail, matching: find.byType(ColoredBox)).first,
      );
      expect(background.color.a, closeTo(.85, .01));
      await mouse.moveTo(const Offset(600, 100));
      await tester.pumpAndSettle();
      expect(tester.getSize(rail).width, 60);
      expect(tester.getRect(content), before);
      expect(tester.getTopLeft(find.byKey(const ValueKey('content'))).dx, 60);
      expect(find.text('Game 1'), findsNothing);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final scenario in [
    (size: const Size(1200, 760), show: true),
    (size: const Size(800, 1000), show: true),
    (size: const Size(700, 1000), show: false),
    (size: const Size(844, 390), show: false),
    (size: const Size(390, 844), show: false),
  ]) {
    testWidgets('Rail responsive at ${scenario.size}', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var loads = 0;
      final selected = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchFollowedLiveRailShell(
              loadStreams: () async {
                loads++;
                return [stream(1), stream(2)];
              },
              selectedLogin: 'peer1',
              onSelect: (value) async => selected.add(value.channelLogin),
              child: const SizedBox.expand(key: ValueKey('content')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(loads, scenario.show ? 1 : 0);
      final rail = find.byKey(const ValueKey('followed-live-rail'));
      expect(rail, scenario.show ? findsOneWidget : findsNothing);
      if (scenario.show) {
        expect(tester.getSize(rail).width, 60);
        expect(tester.getTopLeft(find.byKey(const ValueKey('content'))).dx, 60);
        await tester.tap(find.byKey(const ValueKey('live-rail-1')));
        expect(selected, isEmpty);
        await tester.tap(find.byKey(const ValueKey('live-rail-2')));
        await tester.pump();
        expect(selected, ['peer2']);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('live-rail-1'))).dy,
          lessThan(
            tester.getTopLeft(find.byKey(const ValueKey('live-rail-2'))).dy,
          ),
        );
        await tester.longPress(find.byKey(const ValueKey('live-rail-2')));
        await tester.pumpAndSettle();
        expect(find.text('Peer 2\nTitle 2'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'Rail scrolls, refresh removes offline entries, fullscreen stops polling',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var loads = 0;
      var values = List.generate(30, stream);
      Future<List<TwitchLiveStream>> load() async {
        loads++;
        return values;
      }

      Widget shell(bool enabled) => MaterialApp(
        home: Scaffold(
          body: TwitchFollowedLiveRailShell(
            enabled: enabled,
            loadStreams: load,
            onSelect: (_) async {},
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpWidget(shell(true));
      await tester.pumpAndSettle();
      final rail = find.byKey(const ValueKey('followed-live-rail'));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('live-rail-29')),
        200,
        scrollable: find.descendant(
          of: rail,
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.byKey(const ValueKey('live-rail-29')), findsOneWidget);
      values = [stream(3)];
      await tester.pump(const Duration(minutes: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-rail-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('live-rail-29')), findsNothing);
      await tester.pumpWidget(shell(false));
      await tester.pumpAndSettle();
      final before = loads;
      await tester.pump(const Duration(minutes: 3));
      expect(loads, before);
      expect(rail, findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Old loader response cannot reappear after account/source change',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<List<TwitchLiveStream>>();
      Widget shell(Future<List<TwitchLiveStream>> Function() load) =>
          MaterialApp(
            home: Scaffold(
              body: TwitchFollowedLiveRailShell(
                loadStreams: load,
                onSelect: (_) async {},
                child: const SizedBox.expand(),
              ),
            ),
          );
      await tester.pumpWidget(shell(() => pending.future));
      await tester.pump();
      await tester.pumpWidget(shell(() async => [stream(2)]));
      await tester.pumpAndSettle();
      pending.complete([stream(1)]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-rail-1')), findsNothing);
      expect(find.byKey(const ValueKey('live-rail-2')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
