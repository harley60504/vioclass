import 'twitch_viewer_special_message_runtime.dart';
import '../../api/special_actions/twitch_viewer_special_message_api_service.dart';

class TwitchViewerSpecialMessageDebugProbeStage251 {
  final TwitchViewerSpecialMessageApiServiceStage251 api;
  final TwitchViewerSpecialMessageRuntimeStage251 runtime;
  final Future<String?> Function()? webTokenProvider;
  final Future<String?> Function()? dropsTokenProvider;
  final String Function()? dropsClientIdProvider;

  const TwitchViewerSpecialMessageDebugProbeStage251({
    required this.api,
    required this.runtime,
    this.webTokenProvider,
    this.dropsTokenProvider,
    this.dropsClientIdProvider,
  });

  Future<Map<String, dynamic>> run({
    required String channelLogin,
    String? channelId,
    String? viewerId,
    bool includeWatchStreak = true,
    bool includeResub = true,
    bool includeChatIdentity = true,
  }) async {
    final checkedAt = DateTime.now();
    final webToken = await _safeToken(webTokenProvider);
    final dropsToken = await _safeToken(dropsTokenProvider);
    final dropsClientId = _safeString(dropsClientIdProvider);

    final snapshot = await runtime.load(
      channelLogin: channelLogin,
      channelId: channelId,
      viewerId: viewerId,
      includeWatchStreak: includeWatchStreak,
      includeResub: includeResub,
      includeChatIdentity: includeChatIdentity,
    );

    return <String, dynamic>{
      'stage': '251B',
      'feature': 'viewer_special_messages_debug_probe',
      'checkedAt': checkedAt.toIso8601String(),
      'channelLogin': channelLogin.trim().toLowerCase(),
      'channelId': channelId,
      'viewerId': viewerId,
      'auth': <String, dynamic>{
        'hasWebToken': webToken != null && webToken.isNotEmpty,
        'webTokenLength': webToken?.length ?? 0,
        'hasDropsToken': dropsToken != null && dropsToken.isNotEmpty,
        'dropsTokenLength': dropsToken?.length ?? 0,
        'dropsClientId': dropsClientId,
      },
      'operations': _operationSummary(api.operations),
      'snapshot': snapshot.toJson(),
      'notes': const <String>[
        'If an operation has configured=false, the persisted query hash is not filled yet.',
        'This probe is intentionally safe: it collects per-area issues instead of crashing the page.',
      ],
    };
  }

  Future<Map<String, dynamic>> runCustomPersistedOperation({
    required String operationName,
    required String sha256Hash,
    required Map<String, dynamic> variables,
    bool useAndroidClient = false,
  }) async {
    final checkedAt = DateTime.now();
    final webToken = await _safeToken(webTokenProvider);
    final dropsToken = await _safeToken(dropsTokenProvider);
    final dropsClientId = _safeString(dropsClientIdProvider);

    try {
      final result = await api.runCustomPersistedOperation(
        operationName: operationName,
        sha256Hash: sha256Hash,
        variables: variables,
        useAndroidClient: useAndroidClient,
      );
      return <String, dynamic>{
        'stage': '251D',
        'feature': 'viewer_special_messages_custom_persisted_operation',
        'checkedAt': checkedAt.toIso8601String(),
        'ok': !result.hasErrors,
        'auth': <String, dynamic>{
          'hasWebToken': webToken != null && webToken.isNotEmpty,
          'webTokenLength': webToken?.length ?? 0,
          'hasDropsToken': dropsToken != null && dropsToken.isNotEmpty,
          'dropsTokenLength': dropsToken?.length ?? 0,
          'dropsClientId': dropsClientId,
        },
        'request': <String, dynamic>{
          'operationName': operationName.trim(),
          'sha256Hash': sha256Hash.trim(),
          'hashLength': sha256Hash.trim().length,
          'variables': variables,
          'client': useAndroidClient ? 'androidGql' : 'webGql',
        },
        'result': result.toJson(),
      };
    } catch (error) {
      return <String, dynamic>{
        'stage': '251D',
        'feature': 'viewer_special_messages_custom_persisted_operation',
        'checkedAt': checkedAt.toIso8601String(),
        'ok': false,
        'auth': <String, dynamic>{
          'hasWebToken': webToken != null && webToken.isNotEmpty,
          'webTokenLength': webToken?.length ?? 0,
          'hasDropsToken': dropsToken != null && dropsToken.isNotEmpty,
          'dropsTokenLength': dropsToken?.length ?? 0,
          'dropsClientId': dropsClientId,
        },
        'request': <String, dynamic>{
          'operationName': operationName.trim(),
          'sha256Hash': sha256Hash.trim(),
          'hashLength': sha256Hash.trim().length,
          'variables': variables,
          'client': useAndroidClient ? 'androidGql' : 'webGql',
        },
        'error': error.toString(),
      };
    }
  }

  Map<String, dynamic> _operationSummary(
    TwitchViewerSpecialMessageOperationConfigStage251 operations,
  ) {
    return <String, dynamic>{
      'getWatchStreak': _oneOperation(operations.getWatchStreak),
      'shareWatchStreak': _oneOperation(operations.shareWatchStreak),
      'getResubNotification': _oneOperation(operations.getResubNotification),
      'useResubToken': _oneOperation(operations.useResubToken),
      'fetchChatIdentityBadges': _oneOperation(
        operations.fetchChatIdentityBadges,
      ),
      'updateChatIdentity': _oneOperation(operations.updateChatIdentity),
    };
  }

  Map<String, dynamic> _oneOperation(
    TwitchViewerSpecialMessageOperationStage251 operation,
  ) {
    final hash = operation.sha256Hash.trim();
    return <String, dynamic>{
      'operationName': operation.operationName,
      'configured': operation.isConfigured,
      'hasHash': hash.isNotEmpty,
      'hashLength': hash.length,
    };
  }

  Future<String?> _safeToken(Future<String?> Function()? provider) async {
    if (provider == null) return null;
    try {
      return (await provider())?.trim();
    } catch (_) {
      return null;
    }
  }

  String? _safeString(String Function()? provider) {
    if (provider == null) return null;
    try {
      final value = provider().trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }
}
