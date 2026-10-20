// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/engagement/twitch_hype_train_api_service.dart';
import '../lib/features/twitch/models/engagement/twitch_hype_train.dart';
import '../lib/features/twitch/services/engagement/twitch_hype_train_controller.dart';
import '../lib/features/twitch/presentation/widgets/watch/hype_train/twitch_hype_train_banner.dart';
import '../lib/features/twitch/presentation/sheets/twitch_hype_train_sheet.dart';

TwitchHypeTrainSnapshot _train({
  int level = 3,
  int progress = 25,
  int goal = 100,
  bool ended = false,
  DateTime? expiresAt,
  List<TwitchHypeTrainParticipant> participants = const [],
}) => TwitchHypeTrainSnapshot(
  id: 'fixture-train',
  channelId: '7',
  channelLogin: 'fixture',
  channelDisplayName: 'Fixture',
  level: level,
  total: 125,
  progress: progress,
  goal: goal,
  startedAt: DateTime.now().subtract(const Duration(minutes: 1)),
  expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 5)),
  endedAt: ended ? DateTime.now() : null,
  cooldownEndsAt: null,
  type: 'hype',
  isSharedTrain: participants.isNotEmpty,
  topContributions: const [],
  sharedTrainParticipants: participants,
);

class _Api extends TwitchHypeTrainApiService {
  TwitchHypeTrainSnapshot? next;
  @override
  Future<TwitchHypeTrainSnapshot?> getHypeTrainStatus({
    required String channelLogin,
    String? channelId,
  }) async => next;
}

void main() {
  for (final size in [const Size(900, 700), const Size(320, 640)]) {
    testWidgets('Expired train finishes its ending animation at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      final api = _Api()..next = _train(expiresAt: deadline);
      final controller = TwitchHypeTrainController(api: api);
      addTearDown(controller.dispose);
      await controller.refresh(channelLogin: 'fixture');
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              disableAnimations: false,
              textScaler: TextScaler.linear(size.width < 400 ? 2 : 1),
            ),
            child: Scaffold(
              body: TwitchHypeTrainBanner(controller: controller),
            ),
          ),
        ),
      );
      expect(find.text('Lv.3'), findsOneWidget);
      // The model uses wall-clock time; only wait until this fixed deadline.
      await tester.runAsync(() async {
        final remaining = deadline.difference(DateTime.now());
        if (!remaining.isNegative) await Future<void>.delayed(remaining);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('列車結束'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.text('列車結束'), findsNothing);
      expect(find.text('Lv.3'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'Shared train participants and level-up animation stay current at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const first = TwitchHypeTrainParticipant(
          channelId: '8',
          channelLogin: 'fixture_first',
          displayName: 'Fixture first',
          profileImageUrl: '',
          level: 2,
          progress: 20,
          goal: 100,
        );
        const next = TwitchHypeTrainParticipant(
          channelId: '9',
          channelLogin: 'fixture_next',
          displayName: '',
          profileImageUrl: '',
          level: 4,
          progress: 60,
          goal: 100,
        );
        final api = _Api()..next = _train(participants: [first]);
        final controller = TwitchHypeTrainController(api: api);
        addTearDown(controller.dispose);
        await controller.refresh(channelLogin: 'fixture');
        await tester.pumpWidget(
          MaterialApp(
            home: AnimatedBuilder(
              animation: controller,
              builder: (_, _) => MediaQuery(
                data: MediaQueryData(
                  size: size,
                  disableAnimations: false,
                  textScaler: TextScaler.linear(size.width < 400 ? 2 : 1),
                ),
                child: Scaffold(
                  body: Column(
                    children: [
                      TwitchHypeTrainBanner(controller: controller),
                      Expanded(
                        child: controller.snapshot == null
                            ? const SizedBox()
                            : TwitchHypeTrainSheet(
                                snapshot: controller.snapshot!,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -1800),
        );
        await tester.pump();
        expect(find.text('Fixture first'), findsOneWidget);
        expect(find.text('Lv.2 20 / 100'), findsOneWidget);
        api.next = _train(level: 4, progress: 60, participants: [next]);
        await controller.refresh(channelLogin: 'fixture');
        await tester.pump();
        expect(find.text('升級！'), findsOneWidget);
        expect(find.text('Fixture first'), findsNothing);
        expect(find.text('fixture_next'), findsOneWidget);
        expect(find.text('Lv.4 60 / 100'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1300));
        expect(find.text('升級！'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1400));
        // Celebration completes first; the outgoing label then fades for 200ms.
        expect(find.byKey(const ValueKey('progress')), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('升級！'), findsNothing);
        expect(find.text('Lv.4'), findsOneWidget);
        expect(tester.takeException(), isNull);
        controller.clear();
        await tester.pump();
        expect(find.text('fixture_next'), findsNothing);
        expect(find.text('Lv.4'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('Progress is bounded and ended train is inactive', () {
    expect(_train(progress: -5).progressRatio, 0);
    expect(_train(progress: 150).progressRatio, 1);
    expect(_train(goal: 0).progressRatio, 0);
    expect(_train(ended: true).isActive, isFalse);
  });
  for (final layout in [
    (const Size(900, 700), 1.0),
    (const Size(320, 640), 2.0),
    (const Size(844, 290), 2.0),
  ]) {
    testWidgets('Hype banner and details update without overflow at $layout', (
      tester,
    ) async {
      tester.view.physicalSize = layout.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _Api()..next = _train();
      final controller = TwitchHypeTrainController(api: api);
      addTearDown(controller.dispose);
      await controller.refresh(channelLogin: 'fixture');
      Widget page() => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: layout.$1,
            textScaler: TextScaler.linear(layout.$2),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: Column(
              children: [
                TwitchHypeTrainBanner(controller: controller),
                Expanded(
                  child: TwitchHypeTrainSheet(snapshot: controller.snapshot!),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(page());
      await tester.pump();
      expect(find.text('Lv.3'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('25 / 100'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1800),
      );
      await tester.pump();
      expect(find.text('目前沒有共享列車參與者'), findsOneWidget);
      api.next = _train(level: 4, progress: 60);
      await controller.refresh(channelLogin: 'fixture');
      await tester.pumpWidget(page());
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Lv.4'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      controller.clear();
      await tester.pump();
      expect(find.text('Lv.4'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  }
}
