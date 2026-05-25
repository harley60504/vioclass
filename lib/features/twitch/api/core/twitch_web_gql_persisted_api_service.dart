import './twitch_api_client.dart';
import './twitch_api_constants.dart';

typedef TwitchWebGqlTokenProvider = Future<String?> Function();

class TwitchWebGqlPersistedOperation {
  final String operationName;
  final Map<String, dynamic> variables;
  final String sha256Hash;

  const TwitchWebGqlPersistedOperation({
    required this.operationName,
    required this.variables,
    required this.sha256Hash,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'operationName': operationName,
      'variables': variables,
      'extensions': <String, dynamic>{
        'persistedQuery': <String, dynamic>{
          'version': 1,
          'sha256Hash': sha256Hash,
        },
      },
    };
  }
}

class TwitchWebGqlPersistedResult {
  final String operationName;
  final Map<String, dynamic> variables;
  final dynamic response;

  const TwitchWebGqlPersistedResult({
    required this.operationName,
    required this.variables,
    required this.response,
  });

  bool get hasErrors {
    final raw = response;
    if (raw is Map) {
      final errors = raw['errors'];
      return errors is List && errors.isNotEmpty;
    }
    return false;
  }

  Object? get data {
    final raw = response;
    if (raw is Map) return raw['data'];
    return null;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'operationName': operationName,
      'variables': variables,
      'hasErrors': hasErrors,
      'response': response,
    };
  }
}

/// Twitch Web persisted GraphQL transport。
///
/// 這層只負責 persisted query batch，feature service 再負責拆 model。
class TwitchWebGqlPersistedApiService {
  final TwitchApiClient client;
  final String clientId;
  final TwitchWebGqlTokenProvider? accessTokenProvider;

  const TwitchWebGqlPersistedApiService({
    required this.client,
    this.clientId = TwitchApiConstants.twitchWebClientId,
    this.accessTokenProvider,
  });

  Future<List<TwitchWebGqlPersistedResult>> batch(
    List<TwitchWebGqlPersistedOperation> operations,
  ) async {
    if (operations.isEmpty) return const <TwitchWebGqlPersistedResult>[];

    final raw = await client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: operations
          .map((operation) => operation.toJson())
          .toList(growable: false),
      headers: await _headers(),
    );

    if (raw is! List) {
      return <TwitchWebGqlPersistedResult>[
        TwitchWebGqlPersistedResult(
          operationName: 'batch',
          variables: const <String, dynamic>{},
          response: raw,
        ),
      ];
    }

    return List<TwitchWebGqlPersistedResult>.generate(
      operations.length,
      (index) => TwitchWebGqlPersistedResult(
        operationName: operations[index].operationName,
        variables: operations[index].variables,
        response: index < raw.length ? raw[index] : null,
      ),
      growable: false,
    );
  }

  Future<TwitchWebGqlPersistedResult> single(
    TwitchWebGqlPersistedOperation operation,
  ) async {
    final results = await batch(<TwitchWebGqlPersistedOperation>[operation]);
    return results.isEmpty
        ? TwitchWebGqlPersistedResult(
            operationName: operation.operationName,
            variables: operation.variables,
            response: null,
          )
        : results.first;
  }

  Future<Map<String, String>> _headers() async {
    final token = await accessTokenProvider?.call();
    final safeToken = token?.trim();

    return <String, String>{
      ...TwitchApiConstants.twitchWebHeaders,
      'Client-ID': clientId,
      'Content-Type': 'application/json',
      if (safeToken != null && safeToken.isNotEmpty)
        'Authorization': 'OAuth $safeToken',
    };
  }
}
