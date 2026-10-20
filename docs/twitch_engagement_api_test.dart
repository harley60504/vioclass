// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/core/twitch_web_gql_persisted_api_service.dart';
import '../lib/features/twitch/api/engagement/twitch_prediction_api_service.dart';
import '../lib/features/twitch/api/engagement/twitch_hype_train_api_service.dart';

class _Gql extends TwitchWebGqlPersistedApiService {
  Object? response;
  final operations = <TwitchWebGqlPersistedOperation>[];
  _Gql(TwitchApiClient client) : super(client: client);
  @override
  Future<TwitchWebGqlPersistedResult> single(
    TwitchWebGqlPersistedOperation operation,
  ) async {
    operations.add(operation);
    return TwitchWebGqlPersistedResult(
      operationName: operation.operationName,
      variables: operation.variables,
      response: response,
    );
  }
}

void main() {
  late TwitchApiClient client;
  late _Gql gql;
  setUp(() {
    client = TwitchApiClient();
    gql = _Gql(client);
  });
  tearDown(() => client.close(force: true));
  test(
    'Prediction GQL rejection is not a successful empty prediction',
    () async {
      gql.response = {
        'errors': [
          {'message': 'fixture rejected'},
        ],
      };
      await expectLater(
        TwitchPredictionApiService(
          gql: gql,
        ).fetchPredictionContext(channelLogin: 'fixture'),
        throwsStateError,
      );
      expect(
        gql.operations.single.operationName,
        'ChannelPointsPredictionContext',
      );
    },
  );
  for (final count in [0, 99]) {
    test('Prediction no-event response and count clamp count=$count', () async {
      gql.response = {
        'data': {
          'user': {
            'channel': {'activePrediction': null},
          },
        },
      };
      final snapshot = await TwitchPredictionApiService(
        gql: gql,
      ).fetchPredictionContext(channelLogin: ' Fixture ', count: count);
      expect(snapshot.hasPrediction, isFalse);
      expect(gql.operations.single.variables, {
        'channelLogin': 'fixture',
        'count': count == 0 ? 1 : 10,
      });
    });
  }
  test('Empty prediction channel rejects before any request', () async {
    await expectLater(
      TwitchPredictionApiService(
        gql: gql,
      ).fetchPredictionContext(channelLogin: ' '),
      throwsArgumentError,
    );
    expect(gql.operations, isEmpty);
  });
  test('Hype GQL rejection propagates instead of hiding activity', () async {
    gql.response = {
      'errors': [
        {'message': 'fixture rejected'},
      ],
    };
    await expectLater(
      TwitchHypeTrainApiService(
        gql: gql,
      ).getHypeTrainStatus(channelLogin: 'fixture'),
      throwsStateError,
    );
    expect(gql.operations.single.operationName, 'GetHypeTrainExecution');
  });
  test(
    'Hype valid no-event response is inactive with normalized query',
    () async {
      gql.response = {
        'data': {
          'user': {
            'channel': {
              'hypeTrain': {'execution': null},
            },
          },
        },
      };
      final snapshot = await TwitchHypeTrainApiService(
        gql: gql,
      ).getHypeTrainStatus(channelLogin: ' Fixture ');
      expect(snapshot, isNotNull);
      expect(snapshot!.isActive, isFalse);
      expect(snapshot.id, isEmpty);
      expect(gql.operations.single.variables, {'userLogin': 'fixture'});
    },
  );
}
