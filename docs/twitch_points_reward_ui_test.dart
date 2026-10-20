// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_widgets.dart';

void main() {
  for (final size in [const Size(900, 700), const Size(320, 640)]) {
    for (final scenario in [
      'unknown',
      'insufficient',
      'paused',
      'success',
      'failure',
    ]) {
      testWidgets('Reward detail $scenario at $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final gate = Completer<void>();
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChannelPointsRewardDetailPane(
                reward: {
                  'id': 'fixture-reward',
                  'title': 'fixture reward',
                  'cost': 10,
                  'isEnabled': true,
                  'isInStock': true,
                  'isPaused': scenario == 'paused',
                },
                balance: scenario == 'unknown'
                    ? null
                    : scenario == 'insufficient'
                    ? 9
                    : 10,
                pointsIconUrl: null,
                onBack: () {},
                onRedeem: () {
                  calls++;
                  return gate.future;
                },
              ),
            ),
          ),
        );
        await tester.pump();
        final button = find.widgetWithText(ElevatedButton, '立即兌換');
        final allowed = scenario == 'success' || scenario == 'failure';
        expect(
          tester.widget<ElevatedButton>(button).onPressed,
          allowed ? isNotNull : isNull,
        );
        await tester.tap(button);
        await tester.pump();
        expect(calls, allowed ? 1 : 0);
        if (allowed) {
          expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
          await tester.tap(button);
          expect(calls, 1);
          if (scenario == 'failure') {
            gate.completeError(
              StateError('fixture private redemption failure'),
            );
          } else {
            gate.complete();
          }
          await tester.pump(const Duration(milliseconds: 250));
          expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
          expect(
            find.text('兌換失敗，請稍後再試。'),
            scenario == 'failure' ? findsOneWidget : findsNothing,
          );
          expect(find.text('fixture private redemption failure'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      });
    }
  }
}
