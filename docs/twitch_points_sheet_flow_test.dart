// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/engagement/twitch_channel_points_api_service.dart';
import '../lib/features/twitch/services/engagement/twitch_channel_points_runtime_service.dart';
import '../lib/features/twitch/presentation/watch/twitch_watch_feature_ports.dart';
import '../lib/features/twitch/presentation/watch/sheets/twitch_watch_sheet_port_launcher.dart';
import '../lib/features/twitch/presentation/sheets/channel_points/twitch_channel_points_sheet_models.dart';
import '../lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_widgets.dart';
import '../lib/features/twitch/models/special_actions/twitch_pending_special_message.dart';
import '../lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_emote_overlay.dart';

class _Emotes implements TwitchWatchEmotePort {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Engagement implements TwitchWatchEngagementPort {
  final gate = Completer<TwitchWatchRewardRedeemResult>();
  var claimGate = Completer<TwitchChannelPointsClaimResult>();
  int claims = 0;
  @override
  Future<TwitchChannelPointsClaimResult> claimCommunityPoints({
    required String channelId, required String claimId,
  }) {
    expect(channelId, '7');
    expect(claimId, 'fixture-claim');
    claims++;
    return claimGate.future;
  }
  String expectedChannelId = '7';
  String expectedInput = '';
  int emoteLoads = 0;
  bool failFirstEmoteLoad = false;
  @override
  Future<List<TwitchChannelPointEmoteOption>> loadChannelPointEmotes({
    required String channelLogin, required String? channelId,
  }) async {
    expect(channelLogin, 'fixture');
    expect(channelId, '7');
    emoteLoads++;
    if (failFirstEmoteLoad && emoteLoads == 1) {
      throw StateError('fixture private emote load failure');
    }
    return const [TwitchChannelPointEmoteOption(
      id: 'fixture-emote', token: 'FixtureEmote', emoteType: 'subscriptions',
      modifications: [TwitchChannelPointEmoteModification(
        id: 'fixture-emote_BW', modifierId: 'BW', token: 'FixtureEmoteBW',
      )],
    )];
  }
  int calls = 0;
  @override
  Future<TwitchWatchRewardRedeemResult> redeemReward({
    required String channelId,
    required Map<String, dynamic> reward,
    required String textInput,
  }) {
    expect(channelId, expectedChannelId);
    expect(reward['id'], 'fixture-reward');
    expect(reward['cost'], 10);
    expect(textInput, expectedInput);
    calls++;
    return gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final size in [const Size(900, 700), const Size(320, 640)]) {
    for (final scenario in ['success', 'failure', 'unknown', 'text', 'text-stale', 'text-cancel', 'redeem-stale', 'emote', 'emote-cancel', 'emote-stale', 'modify', 'modify-cancel', 'modify-stale', 'claim-success', 'claim-failure', 'claim-rejected', 'claim-stale', 'claim-repeat', 'claim-retry', 'emote-retry', 'claim-late-success', 'claim-late-failure']) {
      testWidgets('Whole points sheet through launcher $scenario at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final port = _Engagement();
        port.failFirstEmoteLoad = scenario == 'emote-retry';
        final notices = <String>[];
        final pending = <TwitchPendingSpecialMessage>[];
        var login = 'fixture';
        var channelId = '7';
        final textReward = scenario.startsWith('text');
        final modifyReward = scenario.startsWith('modify');
        final emoteReward = scenario.startsWith('emote') || modifyReward;
        final title = textReward ? 'Highlight My Message'
            : modifyReward ? 'Modify a single emote'
            : emoteReward ? 'Choose an emote' : 'fixture reward';
        var refreshes = 0;
        final reward = TwitchChannelReward.fromJson({
          'id': 'fixture-reward',
          'title': title,
          if (modifyReward) 'rewardType': 'CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK',
          'cost': 10,
          'isEnabled': true,
          'isInStock': true,
        }, source: 'custom');
        var snapshot = TwitchChannelPointsRuntimeSnapshot(
          channelLogin: 'fixture',
          startedAt: DateTime.now(),
          completedAt: DateTime.now(),
          publicRead: null,
          publicError: null,
          context: scenario == 'unknown'
              ? null
              : TwitchChannelPointsContext(
                  channelId: '7',
                  channelLogin: 'fixture',
                  balance: 10,
                  availableClaimId: scenario.startsWith('claim') ? 'fixture-claim' : null,
                  availableClaimPoints: scenario.startsWith('claim') ? 50 : 0,
                  pointsName: null,
                  pointsIconUrl: null,
                  raw: null,
                ),
          contextError: null,
          rewardsError: null,
          rewardsResult: TwitchChannelRewardsResult(
            channelLogin: 'fixture',
            channelId: '7',
            pointsName: 'Fixture points',
            pointsIconUrl: null,
            rewards: [reward],
            raw: null,
          ),
        );
        final launcher = TwitchWatchSheetPortLauncher(
          emotes: _Emotes(),
          engagement: port,
          showMessage: notices.add,
          insertMessageText: (_) {},
          setPendingSpecialMessage: pending.add,
          refreshEngagement: ({bool showSnackOnError = false}) async {
            refreshes++;
          },
          refreshEmotes: ({bool forceRefresh = false}) async {},
          channelLogin: () => login,
          channelId: () => channelId,
          channelPointsSnapshot: () => snapshot,
          predictionSnapshot: () => null,
          loadingEmotes: () => false,
          emoteBootstrapping: () => false,
          loadingEngagement: () => false,
          engagementBootstrapping: () => false,
          canPlacePredictionBet: () => false,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => launcher.openChannelPointsSheet(context),
                  child: const Text('fixture open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('fixture open'));
        await tester.pumpAndSettle();
        if (scenario.startsWith('claim')) {
          if (scenario == 'claim-stale') {
            login = 'replacement';
            channelId = '8';
          }
          await tester.tap(find.byIcon(Icons.card_giftcard_rounded));
          await tester.pump();
          if (scenario == 'claim-repeat' || scenario == 'claim-retry') {
            await tester.tap(find.byIcon(Icons.card_giftcard_rounded));
            await tester.pump();
            expect(port.claims, 1);
            if (scenario == 'claim-retry') {
              port.claimGate.completeError(StateError('fixture retryable claim error'));
            } else {
              port.claimGate.complete(const TwitchChannelPointsClaimResult(
                ok: true, pointsEarned: 50, raw: null,
              ));
            }
            await tester.pumpAndSettle();
            if (scenario == 'claim-retry') {
              expect(refreshes, 0);
              expect(notices, ['領取點數失敗，請稍後再試。']);
              port.claimGate = Completer<TwitchChannelPointsClaimResult>();
              await tester.tap(find.byIcon(Icons.card_giftcard_rounded));
              await tester.pump();
              expect(port.claims, 2);
              port.claimGate.complete(const TwitchChannelPointsClaimResult(
                ok: true, pointsEarned: 50, raw: null,
              ));
              await tester.pumpAndSettle();
            }
            expect(refreshes, 1);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 1));
            return;
          }
          final late = scenario.startsWith('claim-late-');
          if (late) {
            expect(port.claims, 1);
            login = 'replacement';
            channelId = '8';
          }
          if (scenario == 'claim-failure' || scenario == 'claim-late-failure') {
            port.claimGate.completeError(StateError('fixture private claim error'));
          } else {
            port.claimGate.complete(TwitchChannelPointsClaimResult(
              ok: scenario != 'claim-rejected', pointsEarned: 50, raw: null,
            ));
          }
          await tester.pumpAndSettle();
          expect(port.claims, scenario == 'claim-stale' ? 0 : 1);
          expect(refreshes, scenario == 'claim-success' ? 1 : 0);
          expect(notices, scenario == 'claim-success' || late ? isEmpty : ['領取點數失敗，請稍後再試。']);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          return;
        }
        await tester.tap(find.byType(ChannelPointsRewardTile));
        await tester.pumpAndSettle();
        if (emoteReward) {
          port.expectedInput = modifyReward
              ? jsonEncode({'emoteId': 'fixture-emote_BW', 'modifierId': 'BW'})
              : 'fixture-emote';
          expect(port.emoteLoads, 1);
          expect(find.byType(ChannelPointEmoteMenuOverlay), findsOneWidget);
          expect(port.calls, 0);
          if (scenario == 'emote-retry') {
            expect(find.text('貼圖清單暫時載入失敗，稍後再試。'), findsOneWidget);
            expect(find.text('fixture private emote load failure'), findsNothing);
            expect(find.text('FixtureEmote'), findsNothing);
            await tester.tap(find.descendant(
              of: find.byType(ChannelPointEmoteMenuOverlay),
              matching: find.byIcon(Icons.refresh_rounded),
            ));
            await tester.pumpAndSettle();
            expect(port.emoteLoads, 2);
            expect(port.calls, 0);
            expect(find.text('貼圖清單暫時載入失敗，稍後再試。'), findsNothing);
            expect(find.text('FixtureEmote'), findsOneWidget);
          }
          if (modifyReward) {
            await tester.tap(find.text('FixtureEmote'));
            await tester.pumpAndSettle();
            expect(port.calls, 0);
            final confirm = find.widgetWithText(FilledButton, '選擇');
            expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
            await tester.tap(find.byTooltip('黑白'));
            await tester.pumpAndSettle();
            expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
          }
          if (scenario.endsWith('-cancel')) {
            await tester.tap(find.descendant(
              of: find.byType(ChannelPointEmoteMenuOverlay),
              matching: find.byIcon(Icons.close_rounded),
            ));
          } else {
            if (scenario.endsWith('-stale')) {
              login = 'replacement';
              channelId = '8';
            }
            final selection = modifyReward
                ? find.widgetWithText(FilledButton, '選擇') : find.text('FixtureEmote');
            await tester.ensureVisible(selection);
            await tester.tap(selection);
          }
          await tester.pump();
          port.gate.complete(const TwitchWatchRewardRedeemResult(
            title: 'fixture emote reward',
            displayResult: TwitchChannelPointRedeemUiResult(title: 'fixture emote reward'),
          ));
          await tester.pumpAndSettle();
          final succeeds = scenario == 'emote' || scenario == 'modify' || scenario == 'emote-retry';
          expect(port.calls, succeeds ? 1 : 0);
          expect(refreshes, succeeds ? 1 : 0);
          expect(find.text('兌換完成'), succeeds ? findsOneWidget : findsNothing);
          expect(find.byType(ChannelPointEmoteMenuOverlay), findsNothing);
          expect(find.text('兌換失敗，請稍後再試。'),
            scenario.endsWith('-stale') ? findsOneWidget : findsNothing);
          expect(pending, isEmpty);
        } else if (scenario == 'redeem-stale') {
          login = 'replacement';
          channelId = '8';
          port.expectedChannelId = '8';
          snapshot = TwitchChannelPointsRuntimeSnapshot(
            channelLogin: login,
            startedAt: DateTime.now(), completedAt: DateTime.now(),
            publicRead: null, publicError: null, contextError: null,
            rewardsError: null, rewardsResult: null,
            context: const TwitchChannelPointsContext(
              channelId: '8', channelLogin: 'replacement', balance: 10,
              availableClaimId: null, availableClaimPoints: 0,
              pointsName: null, pointsIconUrl: null, raw: null,
            ),
          );
          await tester.tap(find.widgetWithText(ElevatedButton, '立即兌換'));
          await tester.pump();
          port.gate.complete(const TwitchWatchRewardRedeemResult(
            title: 'fixture reward',
            displayResult: TwitchChannelPointRedeemUiResult(title: 'fixture reward'),
          ));
          await tester.pumpAndSettle();
          expect(port.calls, 0);
          expect(refreshes, 0);
          expect(find.text('兌換完成'), findsNothing);
          expect(find.text('兌換失敗，請稍後再試。'), findsOneWidget);
        } else if (textReward) {
          if (scenario == 'text-cancel') {
            Navigator.of(tester.element(find.byType(ChannelPointsRewardDetailPane))).pop();
          } else {
            if (scenario == 'text-stale') {
              login = 'replacement';
              channelId = '8';
            }
            await tester.tap(find.widgetWithText(ElevatedButton, '立即兌換'));
          }
          await tester.pumpAndSettle();
          expect(port.calls, 0);
          expect(refreshes, 0);
          expect(pending, hasLength(scenario == 'text' ? 1 : 0));
          if (scenario == 'text') {
            expect(pending.single.channelLogin, 'fixture');
            expect(pending.single.channelId, '7');
            expect(pending.single.kind, TwitchPendingSpecialMessageKind.highlightedMessage);
            expect((pending.single.payload['reward'] as Map)['id'], 'fixture-reward');
            expect(pending.single.costLabel, '10 點');
            expect(find.byType(ChannelPointsRewardDetailPane), findsNothing);
          }
        } else if (scenario == 'unknown') {
          expect(find.byType(ChannelPointsRewardDetailPane), findsOneWidget);
          final button = find.widgetWithText(ElevatedButton, '立即兌換');
          expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
          await tester.tap(button);
          await tester.pump();
          expect(port.calls, 0);
        } else {
          expect(find.byType(ChannelPointsRewardDetailPane), findsOneWidget);
          final button = find.widgetWithText(ElevatedButton, '立即兌換');
          await tester.tap(button);
          await tester.pump();
          expect(port.calls, 1);
          expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
          if (scenario == 'failure') {
            port.gate.completeError(
              StateError('fixture private reward rejection'),
            );
          } else {
            port.gate.complete(
              const TwitchWatchRewardRedeemResult(
                title: 'fixture reward',
                displayResult: TwitchChannelPointRedeemUiResult(
                  title: 'fixture reward',
                ),
              ),
            );
          }
          await tester.pumpAndSettle();
          expect(
            find.text('兌換完成'),
            scenario == 'success' ? findsOneWidget : findsNothing,
          );
          expect(refreshes, scenario == 'success' ? 1 : 0);
          expect(notices, scenario == 'failure' ? ['兌換失敗，請稍後再試。'] : isEmpty);
          expect(find.text('fixture private reward rejection'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
