import './twitch_api_client.dart';
import './twitch_api_constants.dart';
import './twitch_api_exception.dart';

typedef TwitchAccessTokenProvider = Future<String?> Function();

/// Twitch GraphQL transport layer。
///
/// 只處理 GQL request / batch request，不把 prediction、channel points、pinned chat
/// 這些 feature 邏輯塞在這裡。
class TwitchGqlApiService {
  final TwitchApiClient client;
  final String clientId;
  final TwitchAccessTokenProvider? accessTokenProvider;
  final String authorizationPrefix;

  const TwitchGqlApiService({
    required this.client,
    this.clientId = TwitchApiConstants.twitchWebClientId,
    this.accessTokenProvider,
    this.authorizationPrefix = 'OAuth',
  });

  Future<Map<String, dynamic>> request({
    String? operationName,
    required String query,
    Map<String, dynamic> variables = const <String, dynamic>{},
    bool requireData = true,
  }) async {
    final body = await rawRequest(
      operationName: operationName,
      query: query,
      variables: variables,
    );

    if (body is! Map<String, dynamic>) {
      throw TwitchApiException(
        'Unexpected GQL response type: ${body.runtimeType}.',
        details: body,
      );
    }

    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw TwitchApiException(
        'Twitch GQL returned errors.',
        details: errors,
      );
    }

    if (!requireData) return body;

    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }

    throw TwitchApiException(
      'Twitch GQL response does not contain data object.',
      details: body,
    );
  }

  Future<List<Map<String, dynamic>>> batchRequest(
    List<TwitchGqlOperation> operations,
  ) async {
    if (operations.isEmpty) return const <Map<String, dynamic>>[];

    final headers = await _buildHeaders();
    final payload = operations.map((operation) => operation.toJson()).toList();

    final response = await client.postJson<dynamic>(
      TwitchApiConstants.gqlEndpoint,
      data: payload,
      headers: headers,
    );

    if (response is! List) {
      throw TwitchApiException(
        'Unexpected GQL batch response type: ${response.runtimeType}.',
        details: response,
      );
    }

    return response.map<Map<String, dynamic>>((item) {
      if (item is Map<String, dynamic>) return item;
      throw TwitchApiException(
        'Unexpected GQL batch item type: ${item.runtimeType}.',
        details: item,
      );
    }).toList(growable: false);
  }

  Future<dynamic> rawRequest({
    String? operationName,
    required String query,
    Map<String, dynamic> variables = const <String, dynamic>{},
  }) async {
    final headers = await _buildHeaders();

    return client.postJson<dynamic>(
      TwitchApiConstants.gqlEndpoint,
      data: <String, dynamic>{
        if (operationName != null && operationName.trim().isNotEmpty)
          'operationName': operationName.trim(),
        'query': query,
        'variables': variables,
      },
      headers: headers,
    );
  }

  Future<Map<String, String>> _buildHeaders() async {
    final token = await accessTokenProvider?.call();
    final safeToken = token?.trim();

    return <String, String>{
      ...TwitchApiConstants.twitchWebHeaders,
      'Client-ID': clientId,
      'Content-Type': 'application/json',
      if (safeToken != null && safeToken.isNotEmpty)
        'Authorization': '$authorizationPrefix $safeToken',
    };
  }
}

class TwitchGqlOperation {
  final String? operationName;
  final String query;
  final Map<String, dynamic> variables;

  const TwitchGqlOperation({
    this.operationName,
    required this.query,
    this.variables = const <String, dynamic>{},
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (operationName != null && operationName!.trim().isNotEmpty)
        'operationName': operationName!.trim(),
      'query': query,
      'variables': variables,
    };
  }
}
