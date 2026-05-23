import 'dart:convert';

import 'package:dio/dio.dart';

import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../api/drops/twitch_drops_query_presets_stage249.dart';
import '../auth/twitch_drops_auth_service.dart';
import 'twitch_streamnook_drops_connection_check_stage249.dart';
import 'twitch_streamnook_drops_snapshot_stage249.dart';

class TwitchStreamNookDropsCollectResultStage249 {
  final bool ok;
  final int? statusCode;
  final bool hasGraphQLErrors;
  final Object? data;
  final String? errorText;

  const TwitchStreamNookDropsCollectResultStage249({
    required this.ok,
    required this.statusCode,
    required this.hasGraphQLErrors,
    required this.data,
    required this.errorText,
  });

  String get message {
    if (ok) return 'Drop 領取請求成功';
    if (errorText != null && errorText!.trim().isNotEmpty) return errorText!;
    return 'Drop 領取請求失敗：HTTP ${statusCode ?? '-'}';
  }
}

class TwitchStreamNookDropsConnectionServiceStage249 {
  final TwitchApiClient apiClient;
  final TwitchDropsAuthService dropsAuthService;

  const TwitchStreamNookDropsConnectionServiceStage249({
    required this.apiClient,
    required this.dropsAuthService,
  });

  Future<TwitchStreamNookDropsConnectionCheckStage249> checkConnection() async {
    String clientId = dropsAuthService.dropsClientId.trim();
    var hasToken = false;
    var tokenValid = false;

    try {
      await dropsAuthService.loadStoredSession();

      final token = await dropsAuthService.getToken();
      clientId = dropsAuthService.dropsClientId.trim();
      hasToken = token != null && token.trim().isNotEmpty;

      if (!hasToken) {
        return _result(
          hasToken: false,
          tokenValid: false,
          clientId: clientId,
        );
      }

      tokenValid = await dropsAuthService.validateToken();
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

      final inventoryHasErrors = _hasGqlErrors(inventory.data);
      final campaignsHasErrors = _hasGqlErrors(campaigns.data);
      final snapshot = !inventoryHasErrors && !campaignsHasErrors
          ? TwitchStreamNookDropsSnapshotStage249.fromResponses(
              inventoryResponse: inventory.data,
              campaignsResponse: campaigns.data,
            )
          : null;

      return _result(
        hasToken: true,
        tokenValid: true,
        clientId: clientId,
        inventoryStatusCode: inventory.statusCode,
        inventoryHasErrors: inventoryHasErrors,
        inventoryRootSummary: _rootSummary(inventory.data),
        inventoryPreview: _preview(inventory.data),
        campaignsStatusCode: campaigns.statusCode,
        campaignsHasErrors: campaignsHasErrors,
        campaignsRootSummary: _rootSummary(campaigns.data),
        campaignsPreview: _preview(campaigns.data),
        snapshot: snapshot,
      );
    } catch (error) {
      return _result(
        hasToken: hasToken,
        tokenValid: tokenValid,
        clientId: clientId,
        errorText: '$error',
      );
    }
  }

  Future<TwitchStreamNookDropsCollectResultStage249> collectDrop({
    required String dropInstanceId,
  }) async {
    final safeDropInstanceId = dropInstanceId.trim();
    if (safeDropInstanceId.isEmpty) {
      return const TwitchStreamNookDropsCollectResultStage249(
        ok: false,
        statusCode: null,
        hasGraphQLErrors: false,
        data: null,
        errorText: 'Drop instance id is empty.',
      );
    }

    try {
      await dropsAuthService.loadStoredSession();
      final token = await dropsAuthService.getToken();
      final clientId = dropsAuthService.dropsClientId.trim();
      if (token == null || token.trim().isEmpty) {
        return const TwitchStreamNookDropsCollectResultStage249(
          ok: false,
          statusCode: null,
          hasGraphQLErrors: false,
          data: null,
          errorText: 'No Drops token.',
        );
      }

      final tokenValid = await dropsAuthService.validateToken();
      if (!tokenValid) {
        return const TwitchStreamNookDropsCollectResultStage249(
          ok: false,
          statusCode: null,
          hasGraphQLErrors: false,
          data: null,
          errorText: 'Drops token validation failed.',
        );
      }

      final validToken = await dropsAuthService.getToken();
      if (validToken == null || validToken.trim().isEmpty) {
        return const TwitchStreamNookDropsCollectResultStage249(
          ok: false,
          statusCode: null,
          hasGraphQLErrors: false,
          data: null,
          errorText: 'Drops token disappeared after validation.',
        );
      }

      final response = await _postGql(
        token: validToken,
        clientId: clientId,
        bodyJson: TwitchDropsQueryPresetsStage249.collectRewardJson(
          dropInstanceId: safeDropInstanceId,
        ),
      );
      final hasErrors = _hasGqlErrors(response.data);
      final statusCode = response.statusCode ?? 0;
      return TwitchStreamNookDropsCollectResultStage249(
        ok: statusCode >= 200 && statusCode < 300 && !hasErrors,
        statusCode: response.statusCode,
        hasGraphQLErrors: hasErrors,
        data: response.data,
        errorText: null,
      );
    } catch (error) {
      return TwitchStreamNookDropsCollectResultStage249(
        ok: false,
        statusCode: null,
        hasGraphQLErrors: false,
        data: null,
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
    String inventoryRootSummary = '-',
    String inventoryPreview = '',
    int? campaignsStatusCode,
    bool campaignsHasErrors = false,
    String campaignsRootSummary = '-',
    String campaignsPreview = '',
    TwitchStreamNookDropsSnapshotStage249? snapshot,
    String? errorText,
  }) {
    return TwitchStreamNookDropsConnectionCheckStage249(
      hasToken: hasToken,
      tokenValid: tokenValid,
      clientId: clientId,
      inventoryStatusCode: inventoryStatusCode,
      inventoryHasErrors: inventoryHasErrors,
      inventoryRootSummary: inventoryRootSummary,
      inventoryPreview: inventoryPreview,
      campaignsStatusCode: campaignsStatusCode,
      campaignsHasErrors: campaignsHasErrors,
      campaignsRootSummary: campaignsRootSummary,
      campaignsPreview: campaignsPreview,
      snapshot: snapshot,
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

  String _rootSummary(Object? data) {
    if (data == null) return 'null';

    if (data is Map) {
      final keys = data.keys.map((key) => key.toString()).join(', ');
      final hasData = data.containsKey('data');
      final hasErrors = data.containsKey('errors');
      return 'Map(keys=[$keys], hasData=$hasData, hasErrors=$hasErrors)';
    }

    if (data is List) {
      return 'List(length=${data.length})';
    }

    return data.runtimeType.toString();
  }

  String _preview(Object? data) {
    if (data == null) return 'null';

    try {
      final text = const JsonEncoder.withIndent('  ').convert(data);
      return _truncate(text, 6000);
    } catch (_) {
      return _truncate(data.toString(), 6000);
    }
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}\n... <truncated ${text.length - maxLength} chars>';
  }
}
