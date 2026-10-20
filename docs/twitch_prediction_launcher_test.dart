// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../lib/features/twitch/models/engagement/twitch_prediction.dart';
import '../lib/features/twitch/models/engagement/twitch_channel_points_models.dart';
import '../lib/features/twitch/services/engagement/twitch_channel_points_runtime_service.dart';
import '../lib/features/twitch/presentation/watch/twitch_watch_feature_ports.dart';
import '../lib/features/twitch/presentation/watch/sheets/twitch_watch_sheet_port_launcher.dart';

const outcome = TwitchPredictionOutcome(
  id: 'a',
  title: 'fixture A',
  color: 'BLUE',
  points: 0,
  users: 0,
  isWinner: false,
);

class _Emotes implements TwitchWatchEmotePort {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Engagement implements TwitchWatchEngagementPort {
  int bets = 0;
  @override
  Future<TwitchWatchPredictionBetResult> placePredictionBet({
    required TwitchPredictionSnapshot prediction,
    required TwitchPredictionOutcome outcome,
    required int points,
  }) async {
    bets++;
    return TwitchWatchPredictionBetResult(
      outcomeTitle: outcome.title,
      points: points,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final change in ['none', 'channel', 'prediction']) {
    testWidgets(
      'Open prediction sheet retains its destination change=$change',
      (tester) async {
        final port = _Engagement();
        var login = 'fixture';
        var eventId = 'fixture-event';
        final launcher = TwitchWatchSheetPortLauncher(
          emotes: _Emotes(),
          engagement: port,
          showMessage: (_) {},
          insertMessageText: (_) {},
          refreshEngagement: ({bool showSnackOnError = false}) async {},
          refreshEmotes: ({bool forceRefresh = false}) async {},
          channelLogin: () => login,
          channelId: () => '7',
          channelPointsSnapshot: () => TwitchChannelPointsRuntimeSnapshot(
            channelLogin: login,
            startedAt: DateTime.now(),
            completedAt: DateTime.now(),
            publicRead: null,
            publicError: null,
            contextError: null,
            rewardsResult: null,
            rewardsError: null,
            context: TwitchChannelPointsContext(
              channelId: '7',
              channelLogin: login,
              balance: 100,
              availableClaimId: null,
              availableClaimPoints: 0,
              pointsName: null,
              pointsIconUrl: null,
              raw: null,
            ),
          ),
          predictionSnapshot: () => TwitchPredictionSnapshot(
            id: eventId,
            title: 'fixture event',
            status: 'ACTIVE',
            locksAt: DateTime.now().add(const Duration(minutes: 5)),
            totalPoints: 0,
            totalUsers: 0,
            outcomes: const [outcome],
          ),
          loadingEmotes: () => false,
          emoteBootstrapping: () => false,
          loadingEngagement: () => false,
          engagementBootstrapping: () => false,
          canPlacePredictionBet: () => true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => launcher.openPredictionBetSheet(context),
                  child: const Text('fixture open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('fixture open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('fixture A'));
        await tester.pump();
        if (change == 'channel') login = 'replacement';
        if (change == 'prediction') eventId = 'replacement-event';
        await tester.tap(find.text('確認下注'));
        await tester.pump();
        expect(port.bets, change == 'none' ? 1 : 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
  for (final authenticated in [false, true]) {
    for (final balance in <int?>[null, 0, 9, 10]) {
      test(
        'Prediction launcher validates known sufficient balance=$balance authenticated=$authenticated',
        () async {
          final port = _Engagement();
          final notices = <String>[];
          var refreshes = 0;
          final prediction = TwitchPredictionSnapshot(
            id: 'fixture-event',
            title: 'fixture',
            status: 'ACTIVE',
            totalPoints: 0,
            totalUsers: 0,
            outcomes: const [outcome],
          );
          final snapshot = TwitchChannelPointsRuntimeSnapshot(
            channelLogin: 'fixture',
            startedAt: DateTime.now(),
            completedAt: DateTime.now(),
            publicRead: null,
            publicError: null,
            context: balance == null
                ? null
                : TwitchChannelPointsContext(
                    channelId: '7',
                    channelLogin: 'fixture',
                    balance: balance,
                    availableClaimId: null,
                    availableClaimPoints: 0,
                    pointsName: null,
                    pointsIconUrl: null,
                    raw: null,
                  ),
            contextError: balance == null ? 'fixture unavailable' : null,
            rewardsResult: null,
            rewardsError: null,
          );
          final launcher = TwitchWatchSheetPortLauncher(
            emotes: _Emotes(),
            engagement: port,
            showMessage: notices.add,
            insertMessageText: (_) {},
            refreshEngagement: ({bool showSnackOnError = false}) async {
              refreshes++;
            },
            refreshEmotes: ({bool forceRefresh = false}) async {},
            channelLogin: () => 'fixture',
            channelId: () => '7',
            channelPointsSnapshot: () => snapshot,
            predictionSnapshot: () => prediction,
            loadingEmotes: () => false,
            emoteBootstrapping: () => false,
            loadingEngagement: () => false,
            engagementBootstrapping: () => false,
            canPlacePredictionBet: () => authenticated,
          );
          final allowed = authenticated && balance == 10;
          await expectLater(
            launcher.placePredictionBet(outcome, 10),
            allowed ? completes : throwsStateError,
          );
          expect(port.bets, allowed ? 1 : 0);
          expect(refreshes, allowed ? 1 : 0);
          if (!authenticated) expect(notices, ['請先完成登入再下注。']);
        },
      );
    }
  }
}
