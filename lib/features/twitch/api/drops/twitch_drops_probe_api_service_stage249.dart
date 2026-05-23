import 'dart:convert';

import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';
import '../core/twitch_api_exception.dart';

/// Token slot used by the Stage 249 Drops probe.
///
/// The probe intentionally supports both Web/GQL and Drops/Android tokens so
/// we can verify which one works for Twitch Drops inventory/campaign queries
/// before wiring a real monitor.
enum TwitchDropsProbeTokenSlotStage249 {
  webGql,
  dropsAndroid,
}

class TwitchDropsProbeResultStage249 {
  final TwitchDropsProbeTokenSlotStage249 tokenSlot;
  final String clientId;
  final String operationName;
  final int? statusCode;
  final Object? data;
  final DateTime createdAt;

  const TwitchDropsProbeResultStage249({
    required this.tokenSlot,
    required this.clientId,
    required this.operationName,
    required this.statusCode,
    required this.data,
    required this.createdAt,
  });

  bool get hasGraphQLErrors {
    final root = data;
    if (root is Map) {
      final errors = root['errors'];
      return errors is List && errors.isNotEmpty;
    }
    if (root is List) {
      return root.any((entry) {
        if (entry is! Map) return false;
        final errors = entry['errors'];
        return errors is List && errors.isNotEmpty;
      });
    }
    return false;
  }

  String get prettyJson {
    const encoder = JsonEncoder.withIndent('  ');
    try {
      return encoder.convert(data);
    } catch (_) {
      return data?.toString() ?? 'null';
    }
  }
}

class TwitchDropsProbeApiServiceStage249 {
  final TwitchApiClient client;

  const TwitchDropsProbeApiServiceStage249({
    required this.client,
  });

  Future<TwitchDropsProbeResultStage249> probeCurrentUser({
    required TwitchDropsProbeTokenSlotStage249 tokenSlot,
    required String accessToken,
    required String clientId,
  }) async {
    final trimmedToken = accessToken.trim();
    final trimmedClientId = clientId.trim();

    if (trimmedToken.isEmpty) {
      throw const TwitchApiException('Stage 249 probe token is empty.');
    }

    if (trimmedClientId.isEmpty) {
      throw const TwitchApiException('Stage 249 probe Client-ID is empty.');
    }

    final body = <String, dynamic>{
      'operationName': 'Stage249DropsProbeCurrentUser',
      'variables': <String, dynamic>{},
      'query': r'''
        query Stage249DropsProbeCurrentUser {
          currentUser {
            id
            login
            displayName
          }
        }
      ''',
    };

    final response = await client.dio.post<dynamic>(
      TwitchApiConstants.gqlEndpoint,
      data: body,
      options: _gqlOptions(
        clientId: trimmedClientId,
        accessToken: trimmedToken,
      ),
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw TwitchApiException(
        'Stage 249 Twitch GQL probe failed with HTTP $statusCode.',
        statusCode: statusCode,
        uri: response.realUri,
        details: response.data,
      );
    }

    return TwitchDropsProbeResultStage249(
      tokenSlot: tokenSlot,
      clientId: trimmedClientId,
      operationName: 'Stage249DropsProbeCurrentUser',
      statusCode: statusCode,
      data: response.data,
      createdAt: DateTime.now(),
    );
  }

  static Options _gqlOptions({
    required String clientId,
    required String accessToken,
  }) {
    return Options(
      responseType: ResponseType.json,
      validateStatus: (status) => status != null && status < 500,
      headers: <String, String>{
        ...TwitchApiConstants.twitchWebHeaders,
        'Client-ID': clientId,
        'Content-Type': 'application/json',
        'Authorization': 'OAuth $accessToken',
      },
    );
  }
}
