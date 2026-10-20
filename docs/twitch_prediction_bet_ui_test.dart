// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/models/engagement/twitch_prediction.dart';
import '../lib/features/twitch/services/engagement/twitch_prediction_hermes_runtime_service.dart';
import '../lib/features/twitch/presentation/sheets/twitch_prediction_bet_sheet.dart';

TwitchPredictionSnapshot _prediction() => TwitchPredictionSnapshot(
  id: 'fixture-event',
  title: 'fixture prediction',
  status: 'ACTIVE',
  totalPoints: 100,
  totalUsers: 2,
  locksAt: DateTime.now().add(const Duration(minutes: 5)),
  outcomes: const [
    TwitchPredictionOutcome(
      id: 'a',
      title: 'fixture A',
      color: 'BLUE',
      points: 60,
      users: 1,
      isWinner: false,
    ),
    TwitchPredictionOutcome(
      id: 'b',
      title: 'fixture B',
      color: 'PINK',
      points: 40,
      users: 1,
      isWinner: false,
    ),
  ],
);

void main() {
  setUp(() => TwitchPredictionHermesRealtimeBus.publishPrediction(null));
  tearDown(() => TwitchPredictionHermesRealtimeBus.publishPrediction(null));
  for (final size in [const Size(900, 700), const Size(320, 640)]) {
    for (final scenario in ['success', 'failure', 'locked']) {
      testWidgets('Prediction bet page $scenario at $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final prediction = _prediction();
        final gate = Completer<void>();
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TwitchPredictionBetSheet(
                prediction: prediction,
                onRefreshPrediction: () async => null,
                onBet: (outcome, points) {
                  expect(outcome.id, 'a');
                  expect(points, 50);
                  calls++;
                  return gate.future;
                },
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('點數占比 60%'), findsOneWidget);
        expect(find.text('預估回報 1.7×'), findsOneWidget);
        await tester.tap(find.text('fixture A'));
        await tester.pump();
        expect(find.text('已選擇'), findsOneWidget);
        await tester.tap(find.text('100'));
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '100',
        );
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '100'))
              .selected,
          isTrue,
        );
        if (scenario == 'locked') {
          TwitchPredictionHermesRealtimeBus.publishPrediction(
            prediction.copyWith(status: 'LOCKED'),
          );
          await tester.pump();
          expect(find.text('確認下注'), findsNothing);
          expect(calls, 0);
        } else {
          final input = find.byType(TextField);
          await tester.enterText(input, '0');
          await tester.tap(find.text('確認下注'));
          await tester.pump();
          expect(calls, 0);
          expect(find.text('請輸入有效點數'), findsOneWidget);
          await tester.enterText(input, '50');
          await tester.tap(find.text('確認下注'));
          await tester.pump();
          expect(calls, 1);
          final submit = find.byType(FilledButton);
          expect(tester.widget<FilledButton>(submit).onPressed, isNull);
          await tester.tap(submit);
          expect(calls, 1);
          if (scenario == 'failure') {
            gate.completeError(StateError('fixture private bet failure'));
          } else {
            gate.complete();
          }
          await tester.pump(const Duration(milliseconds: 250));
          if (scenario == 'failure') {
            expect(find.text('下注未成功，請稍後重試'), findsOneWidget);
            expect(tester.widget<TextField>(input).controller!.text, '50');
            expect(find.text('fixture private bet failure'), findsNothing);
          } else {
            expect(find.text('加注'), findsOneWidget);
            expect(
              TwitchPredictionHermesRealtimeBus
                  .latestPrediction!
                  .viewerOutcomeId,
              'a',
            );
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }
}
