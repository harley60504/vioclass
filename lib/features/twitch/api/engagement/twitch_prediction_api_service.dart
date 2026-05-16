import '../../models/engagement/twitch_prediction.dart';
import '../../services/engagement/twitch_prediction_hermes_runtime_service.dart';
import '../core/twitch_api_constants.dart';
import '../core/twitch_web_gql_persisted_api_service.dart';

class TwitchPredictionApiService {
  final TwitchWebGqlPersistedApiService gql;

  const TwitchPredictionApiService({
    required this.gql,
  });

  Future<TwitchPredictionSnapshot> fetchPredictionContext({
    required String channelLogin,
    int count = 1,
  }) async {
    final raw = await fetchPredictionContextRaw(
      channelLogin: channelLogin,
      count: count,
    );

    final snapshot = TwitchPredictionSnapshot.fromRawResponse(raw.response);
    if (snapshot.hasPrediction) {
      TwitchPredictionHermesRealtimeBus.publishPrediction(snapshot);
    }
    return snapshot;
  }

  Future<TwitchWebGqlPersistedResult> fetchPredictionContextRaw({
    required String channelLogin,
    int count = 1,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      throw ArgumentError.value(channelLogin, 'channelLogin', 'channelLogin cannot be empty');
    }

    return gql.single(
      TwitchWebGqlPersistedOperation(
        operationName: 'ChannelPointsPredictionContext',
        variables: <String, dynamic>{
          'count': count.clamp(1, 10),
          'channelLogin': login,
        },
        sha256Hash: 'beb846598256b75bd7c1fe54a80431335996153e358ca9c7837ce7bb83d7d383',
      ),
    );
  }

  Future<dynamic> makePrediction({
    required TwitchPredictionSnapshot prediction,
    required TwitchPredictionOutcome outcome,
    required int points,
  }) {
    if (!prediction.hasPrediction || prediction.id.isEmpty) {
      throw StateError('目前沒有可下注的預測。');
    }

    if (outcome.id.isEmpty) {
      throw StateError('Outcome id 是空的，不能下注。');
    }

    if (points <= 0) {
      throw ArgumentError.value(points, 'points', 'points must be positive');
    }

    return _postGraphQlMutation(
      operationName: 'MakePrediction',
      query: r'''
mutation MakePrediction($input: MakePredictionInput!) {
  makePrediction(input: $input) {
    __typename
  }
}
''',
      variables: <String, dynamic>{
        'input': <String, dynamic>{
          'eventID': prediction.id,
          'outcomeID': outcome.id,
          'points': points,
          'transactionID': _transactionId(),
        },
      },
    );
  }

  Future<dynamic> _postGraphQlMutation({
    required String operationName,
    required String query,
    required Map<String, dynamic> variables,
  }) async {
    final token = await gql.accessTokenProvider?.call();
    final safeToken = token?.trim();

    final raw = await gql.client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': operationName,
        'query': query,
        'variables': variables,
      },
      headers: <String, String>{
        ...TwitchApiConstants.twitchWebHeaders,
        'Client-ID': gql.clientId,
        'Content-Type': 'application/json',
        if (safeToken != null && safeToken.isNotEmpty)
          'Authorization': 'OAuth $safeToken',
      },
    );

    _throwIfGraphQlErrors(raw);
    return raw;
  }

  void _throwIfGraphQlErrors(Object? raw) {
    if (raw is! Map) return;

    final errors = raw['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is Map && first['message'] != null) {
        throw StateError(first['message'].toString());
      }
      throw StateError(errors.toString());
    }
  }

  String _transactionId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'ntapp-$now';
  }
}
