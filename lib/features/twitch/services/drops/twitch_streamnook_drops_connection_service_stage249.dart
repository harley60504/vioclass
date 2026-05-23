import 'dart:convert';

import 'package:dio/dio.dart';

import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../api/drops/twitch_drops_query_presets_stage249.dart';
import '../auth/twitch_drops_auth_service.dart';
import 'twitch_streamnook_drops_connection_check_stage249.dart';

class TwitchStreamNookDropsConnectionServiceStage249 {
  final TwitchApiClient apiClient;
  final TwitchDropsAuthService dropsAuthService;

  const TwitchStreamNookDropsConnectionServiceStage249({
    required this.apiClient,
    required this.dropsAuthService,
  });

  Future<TwitchStreamNookDropsConnectionCheckStage249> checkConnection() async {
    try {
      await dropsAuthService.loadStoredSession();

      final token = await dropsAuthService.getToken();
      final clientId = dropsAuthService.dropsClientId.trim();
      final hasToken = token != null && token.trim().isNotEmpty;

      if (!hasToken) {
        return _result(
          hasToken: false,
          tokenValid: false,
          clientId: clientId,
        );
      }

      final tokenValid = await dropsAuthService.validateToken();
      if (!tokenValid) {
        return _result(
          hasToken: true,
          tokenValid: false,
          clientId: clientId,
        );
      }

      final validToken = await dropsAuthService.getToken();
      if (validToken == null || validToken.trim().isEmpty) {
        return _result(
          hasToken: false,
          tokenValid: false,
          clientId: clientId,
          errorText: 'Drops token disappeared after validation.',
        );
      }

      final inventory = await _postGql(
        token: validToken,
        clientId: clientId,
        bodyJson: TwitchDropsQueryPresetsStage249.inventoryJson(),
      );

      final campaigns = await _postGql(
        token: validToken,
        clientId: clientId,
        bodyJson: TwitchDropsQueryPresetsStage249.campaignsJson(),
      );

      return _result(
        hasToken: true,
        tokenValid: true,
        clientId: clientId,
        inventoryStatusCode: inventory.statusCode,
        inventoryHasErrors: _hasGqlErrors(inventory.data),
        campaignsStatusCode: campaigns.statusCode,
        campaignsHasErrors: _hasGqlErrors(campaigns.data),
      );
    } catch (error) {
      return _result(
        hasToken: false,
        tokenValid: false,
        clientId: dropsAuthService.dropsClientId.trim(),
        errorText: '$error',
      );
    }
  }

  TwitchStreamNookDropsConnectionCheckStage249 _result({
    required bool hasToken,
    required bool tokenValid,
    required String clientId,
    int? inventoryStatusCode,
    bool inventoryHasErrors = false,
    int? campaignsStatusCode,
    bool campaignsHasErrors = false,
    String? errorText,
  }) {
    return TwitchStreamNookDropsConnectionCheckStage249(
      hasToken: hasToken,
      tokenValid: tokenValid,
      clientId: clientId,
      inventoryStatusCode: inventoryStatusCode,
      inventoryHasErrors: inventoryHasErrors,
      campaignsStatusCode: campaignsStatusCode,
      campaignsHasErrors: campaignsHasErrors,
      errorText: errorText,
      checkedAt: DateTime.now(),
    );
  }

  Future<Response<dynamic>> _postGql({
    required String token,
    required String clientId,
    required String bodyJson,
  }) {
    final body = jsonDecode(bodyJson);

    return apiClient.dio.post<dynamic>(
      TwitchApiConstants.gqlEndpoint,
      data: body,
      options: Options(
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
        headers: <String, String>{
          ...TwitchApiConstants.twitchWebHeaders,
          'Client-ID': clientId,
          'Content-Type': 'application/json',
          'Authorization': 'OAuth ${token.trim()}',
        },
      ),
    );
  }

  bool _hasGqlErrors(Object? data) {
    if (data is Map) {
      final errors = data['errors'];
      return errors is List && errors.isNotEmpty;
    }

    if (data is List) {
      return data.any((entry) {
        if (entry is! Map) return false;
        final errors = entry['errors'];
        return errors is List && errors.isNotEmpty;
      });
    }

    return false;
  }
}
