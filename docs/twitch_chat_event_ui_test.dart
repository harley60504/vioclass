// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/core/twitch_web_gql_persisted_api_service.dart';
import '../lib/features/twitch/api/engagement/twitch_hype_train_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message_metadata.dart';
import '../lib/features/twitch/models/chat/twitch_chat_runtime_message.dart';
import '../lib/features/twitch/models/engagement/twitch_hype_train.dart';
import '../lib/features/twitch/models/engagement/twitch_prediction.dart';
import '../lib/features/twitch/services/engagement/twitch_hype_train_controller.dart';
import '../lib/features/twitch/services/engagement/twitch_prediction_hermes_runtime_service.dart';
import '../lib/features/twitch/presentation/widgets/chat/twitch_runtime_message_tile.dart';
import '../lib/features/twitch/presentation/widgets/chat/cards/twitch_prediction_banner.dart';
import '../lib/features/twitch/presentation/widgets/watch/hype_train/twitch_hype_train_banner.dart';
import '../lib/features/twitch/presentation/sheets/twitch_prediction_bet_sheet.dart';
import '../lib/features/twitch/presentation/sheets/prediction_bet/twitch_prediction_bet_helpers.dart';

TwitchPredictionSnapshot prediction({
  String status = 'ACTIVE',
  DateTime? locksAt,
}) => TwitchPredictionSnapshot(
  id: 'ui-test',
  title: '這次能不能挑戰成功？',
  status: status,
  totalPoints: 100,
  totalUsers: 8,
  locksAt: locksAt,
  outcomes: const [
    TwitchPredictionOutcome(
      id: 'a',
      title: '挑戰成功',
      color: 'BLUE',
      points: 100,
      users: 8,
      isWinner: false,
    ),
    TwitchPredictionOutcome(
      id: 'b',
      title: '下一次一定會成功',
      color: 'PINK',
      points: 0,
      users: 0,
      isWinner: false,
    ),
  ],
);

TwitchHypeTrainSnapshot train({
  int level = 2,
  String id = 'train-ui',
  bool golden = false,
}) => TwitchHypeTrainSnapshot.fromJson({
  'id': id,
  'channelLogin': 'tester',
  'channelId': '123',
  'level': level,
  'progress': 60,
  'goal': 100,
  'expiresAt': DateTime.now().add(const Duration(minutes: 4)).toIso8601String(),
  'isGoldenKappaTrain': golden,
});

class FakeTrainApi extends TwitchHypeTrainApiService {
  TwitchHypeTrainSnapshot? next = train();
  bool fail = false;
  Completer<TwitchHypeTrainSnapshot?>? pending;
  int calls = 0;
  @override
  Future<TwitchHypeTrainSnapshot?> getHypeTrainStatus({
    required String channelLogin,
    String? channelId,
  }) async {
    calls++;
    if (pending != null) return pending!.future;
    if (fail) throw StateError('offline');
    return next;
  }
}

class FakeGql extends TwitchWebGqlPersistedApiService {
  final operations = <TwitchWebGqlPersistedOperation>[];
  bool rejectStatus = false;
  FakeGql() : super(client: TwitchApiClient());
  @override
  Future<TwitchWebGqlPersistedResult> single(
    TwitchWebGqlPersistedOperation op,
  ) async {
    operations.add(op);
    final execution = op.operationName == 'GetHypeTrainExecution';
    return TwitchWebGqlPersistedResult(
      operationName: op.operationName,
      variables: op.variables,
      response: !execution && rejectStatus
          ? {
              'errors': [
                {'message': 'unavailable'},
              ],
            }
          : {
              'data': execution
                  ? {
                      'user': {
                        'id': '123',
                        'login': 'tester',
                        'channel': {
                          'hypeTrain': {
                            'execution': {
                              'id': rejectStatus ? 'status-error' : 'status-ok',
                              'expiresAt': DateTime.now()
                                  .add(const Duration(minutes: 4))
                                  .toIso8601String(),
                              'progress': {
                                'level': {'value': 3},
                                'progression': 60,
                                'goal': 100,
                              },
                            },
                          },
                        },
                      },
                    }
                  : {
                      'allActiveHypeTrainStatuses': [
                        {
                          'id': 'status-ok',
                          'channel': {'id': '123'},
                          'isGoldenKappaTrain': true,
                        },
                      ],
                    },
            },
    );
  }
}

Widget host(
  Widget child, {
  double width = 320,
  double height = 650,
  double scale = 1,
}) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        height: height,
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(scale),
          ),
          child: child,
        ),
      ),
    ),
  ),
);

TwitchChatRuntimeMessage event(String type) {
  final source = TwitchChatMessage(
    raw: '',
    command: 'USERNOTICE',
    channel: 'tester',
    userLogin: 'gifter',
    displayName: 'Gifter',
    message: '',
    tags: {
      'msg-id': type,
      'system-msg': 'Gifter 支援這個頻道，謝謝大家！',
      'msg-param-recipient-display-name': 'Recipient',
      'msg-param-sub-plan': '1000',
      'msg-param-mass-gift-count': '5',
      'msg-param-cumulative-months': '103',
    },
  );
  return TwitchChatRuntimeMessage(
    source: source,
    resolvedBadges: const [],
    receivedAt: DateTime.now(),
    fragments: const [],
    segments: const [],
    metadata: TwitchChatMessageMetadata.fromMessage(source),
  );
}

void main() {
  test('clearing a channel invalidates its delayed refresh', () async {
    final api = FakeTrainApi()..pending = Completer<TwitchHypeTrainSnapshot?>();
    final controller = TwitchHypeTrainController(api: api);
    final request = controller.refresh(channelLogin: 'tester');
    controller.clear();
    api.pending!.complete(train());
    await request;
    expect(controller.snapshot, isNull);
    controller.dispose();
  });
  testWidgets('failed refresh backs off without hiding the train', (
    tester,
  ) async {
    final api = FakeTrainApi();
    final controller = TwitchHypeTrainController(api: api);
    await controller.refresh(channelLogin: 'tester');
    controller.startPolling(channelLogin: 'tester', shouldPoll: () => true);
    api.fail = true;
    await tester.pump(const Duration(seconds: 3));
    expect(api.calls, 2);
    await tester.pump(const Duration(seconds: 3));
    expect(api.calls, 2);
    expect(controller.snapshot, isNotNull);
    await tester.pump(const Duration(seconds: 12));
    expect(api.calls, 3);
    controller.dispose();
  });
  testWidgets('repeated refresh failure offers compact recovery', (
    tester,
  ) async {
    TwitchPredictionHermesRealtimeBus.publishPrediction(null);
    await tester.pumpWidget(
      host(
        TwitchPredictionBetSheet(
          prediction: prediction(),
          onRefreshPrediction: () async => throw StateError('offline'),
          onBet: (_, _) async {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('連線暫時中斷，保留目前結果'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(find.text('連線暫時中斷，保留目前結果'), findsOneWidget);
    expect(find.text('挑戰成功'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    TwitchPredictionHermesRealtimeBus.publishPrediction(null);
  });
  testWidgets('short mobile sheet remains scrollable with large text', (
    tester,
  ) async {
    TwitchPredictionHermesRealtimeBus.publishPrediction(null);
    await tester.pumpWidget(
      host(
        TwitchPredictionBetSheet(
          prediction: prediction(),
          onRefreshPrediction: () async => null,
          onBet: (_, _) async {},
        ),
        width: 280,
        height: 320,
        scale: 1.45,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    TwitchPredictionHermesRealtimeBus.publishPrediction(null);
  });
  testWidgets(
    'single submission and realtime confirmation never doubles stake',
    (tester) async {
      TwitchPredictionHermesRealtimeBus.publishPrediction(null);
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        host(
          TwitchPredictionBetSheet(
            prediction: prediction(),
            onRefreshPrediction: () async => null,
            onBet: (_, _) {
              calls++;
              return pending.future;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('挑戰成功'));
      await tester.pump();
      await tester.tap(find.text('確認下注'));
      await tester.tap(find.text('確認下注'));
      await tester.pump();
      expect(calls, 1);
      TwitchPredictionHermesRealtimeBus.publishPrediction(
        prediction().withViewerPrediction(
          outcomeId: 'a',
          points: 10,
          addToExisting: false,
        ),
      );
      await tester.pump();
      pending.complete();
      await tester.pump();
      expect(
        TwitchPredictionHermesRealtimeBus
            .latestPrediction!
            .viewerOutcome!
            .viewerPoints,
        10,
      );
      await tester.pumpWidget(const SizedBox());
      TwitchPredictionHermesRealtimeBus.publishPrediction(null);
    },
  );
  test('golden uses explicit flag and survives serialization', () {
    final value = train(golden: true);
    expect(value.isGoldenKappa, isTrue);
    expect(
      TwitchHypeTrainSnapshot.fromJson(value.toJson()).isGoldenKappa,
      isTrue,
    );
    expect(value.copyWith(channelLogin: 'other').isGoldenKappa, isTrue);
    expect(train().isGoldenKappa, isFalse);
  });
  test('official golden query keeps original execution hash', () async {
    final gql = FakeGql();
    final api = TwitchHypeTrainApiService(gql: gql);
    expect(
      (await api.getHypeTrainStatus(channelLogin: 'tester'))!.isGoldenKappa,
      isTrue,
    );
    expect(
      gql.operations.first.sha256Hash,
      '8a39e843c94c5109a4cfb9badc641733e2205c60f5ee30e9b55edf0ad9db870a',
    );
    expect(gql.operations.last.variables, {
      'channelIDs': ['123'],
    });
    await api.getHypeTrainStatus(channelLogin: 'tester');
    expect(
      gql.operations.length,
      3,
    ); // Same train needs no repeated status query.
  });
  test('optional status failure preserves progress', () async {
    final gql = FakeGql()..rejectStatus = true;
    final value = await TwitchHypeTrainApiService(
      gql: gql,
    ).getHypeTrainStatus(channelLogin: 'tester');
    expect(value!.progress, 60);
    expect(value.isActive, isTrue);
  });
  test('deadline and terminal states disable betting', () {
    final now = DateTime.now();
    expect(twitchPredictionCanBet(prediction(locksAt: now), now: now), isFalse);
    for (final state in ['LOCKED', 'RESOLVE_PENDING', 'RESOLVED', 'CANCELED']) {
      expect(twitchPredictionCanBet(prediction(status: state)), isFalse);
    }
    expect(twitchPredictionStatusRank(prediction(status: 'RESOLVED')), 3);
  });
  test('temporary refresh error preserves active train', () async {
    final api = FakeTrainApi();
    final controller = TwitchHypeTrainController(api: api);
    await controller.refresh(channelLogin: 'tester');
    api.fail = true;
    await controller.refresh(channelLogin: 'tester');
    expect(controller.snapshot!.id, 'train-ui');
    expect(controller.error, isNotNull);
    controller.dispose();
  });
  testWidgets('one polling timer, active cadence and dispose', (tester) async {
    final api = FakeTrainApi();
    final controller = TwitchHypeTrainController(api: api);
    await controller.refresh(channelLogin: 'tester');
    for (var i = 0; i < 3; i++) {
      controller.startPolling(channelLogin: 'tester', shouldPoll: () => true);
    }
    await tester.pump(const Duration(seconds: 3));
    expect(api.calls, 2);
    controller.dispose();
    await tester.pump(const Duration(seconds: 20));
    expect(api.calls, 2);
  });
  testWidgets('compact train upgrades once, not on repeat refresh', (
    tester,
  ) async {
    final api = FakeTrainApi();
    final controller = TwitchHypeTrainController(api: api);
    await controller.refresh(channelLogin: 'tester');
    await tester.pumpWidget(
      host(TwitchHypeTrainBanner(controller: controller)),
    );
    expect(find.text('升級！'), findsNothing);
    api.next = train(level: 3, golden: true);
    await controller.refresh(channelLogin: 'tester');
    await tester.pump();
    expect(find.text('升級！'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await controller.refresh(channelLogin: 'tester');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('升級！'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  for (final type in [
    'sub',
    'resub',
    'subgift',
    'submysterygift',
    'raid',
    'announcement',
    'ritual',
    'bitsbadgetier',
    'giftpaidupgrade',
  ]) {
    testWidgets('$type at narrow width and enlarged text', (tester) async {
      await tester.pumpWidget(
        host(
          TwitchRuntimeMessageTile(message: event(type)),
          width: 280,
          scale: 1.45,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('zero-share prediction remains readable', (tester) async {
    await tester.pumpWidget(
      host(
        TwitchPredictionBanner(prediction: prediction(), onOpen: () {}),
        width: 280,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('select then confirm, no submit by selecting', (tester) async {
    TwitchPredictionHermesRealtimeBus.publishPrediction(null);
    var calls = 0;
    await tester.pumpWidget(
      host(
        TwitchPredictionBetSheet(
          prediction: prediction(),
          onRefreshPrediction: () async => null,
          onBet: (_, points) async {
            expect(points, 10);
            calls++;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('挑戰成功'));
    await tester.pump();
    expect(calls, 0);
    await tester.tap(find.text('確認下注'));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('加注'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    TwitchPredictionHermesRealtimeBus.publishPrediction(null);
  });
  testWidgets('failed bet is recoverable, not optimistic success', (
    tester,
  ) async {
    TwitchPredictionHermesRealtimeBus.publishPrediction(null);
    await tester.pumpWidget(
      host(
        TwitchPredictionBetSheet(
          prediction: prediction(),
          onRefreshPrediction: () async => null,
          onBet: (_, _) async => throw StateError('rejected'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('挑戰成功'));
    await tester.pump();
    await tester.tap(find.text('確認下注'));
    await tester.pump();
    expect(find.text('下注未成功，請稍後重試'), findsOneWidget);
    expect(find.text('加注'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    TwitchPredictionHermesRealtimeBus.publishPrediction(null);
  });
  testWidgets('late ACTIVE refresh cannot reopen resolved prediction', (
    tester,
  ) async {
    TwitchPredictionHermesRealtimeBus.publishPrediction(null);
    final pending = Completer<TwitchPredictionSnapshot?>();
    await tester.pumpWidget(
      host(
        TwitchPredictionBetSheet(
          prediction: prediction(),
          onRefreshPrediction: () => pending.future,
          onBet: (_, _) async {},
        ),
      ),
    );
    TwitchPredictionHermesRealtimeBus.publishPrediction(
      prediction(status: 'RESOLVED'),
    );
    await tester.pump();
    pending.complete(prediction());
    await tester.pump();
    expect(find.text('已結算'), findsOneWidget);
    expect(find.text('確認下注'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    TwitchPredictionHermesRealtimeBus.publishPrediction(null);
  });
}
