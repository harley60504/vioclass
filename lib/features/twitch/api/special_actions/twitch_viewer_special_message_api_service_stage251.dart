import '../../api/core/twitch_web_gql_persisted_api_service.dart';
import '../../models/special_actions/twitch_viewer_special_message_models_stage251.dart';

class TwitchViewerSpecialMessageOperationStage251 {
  final String operationName;
  final String sha256Hash;

  const TwitchViewerSpecialMessageOperationStage251({
    required this.operationName,
    required this.sha256Hash,
  });

  bool get isConfigured =>
      operationName.trim().isNotEmpty && sha256Hash.trim().isNotEmpty;

  TwitchWebGqlPersistedOperation build(Map<String, dynamic> variables) {
    if (!isConfigured) {
      throw StateError('Operation $operationName is not configured.');
    }
    return TwitchWebGqlPersistedOperation(
      operationName: operationName,
      variables: variables,
      sha256Hash: sha256Hash,
    );
  }
}

class TwitchViewerSpecialMessageOperationConfigStage251 {
  final TwitchViewerSpecialMessageOperationStage251 getWatchStreak;
  final TwitchViewerSpecialMessageOperationStage251 shareWatchStreak;
  final TwitchViewerSpecialMessageOperationStage251 getResubNotification;
  final TwitchViewerSpecialMessageOperationStage251 useResubToken;
  final TwitchViewerSpecialMessageOperationStage251 fetchChatIdentityBadges;
  final TwitchViewerSpecialMessageOperationStage251 updateChatIdentity;

  const TwitchViewerSpecialMessageOperationConfigStage251({
    required this.getWatchStreak,
    required this.shareWatchStreak,
    required this.getResubNotification,
    required this.useResubToken,
    required this.fetchChatIdentityBadges,
    required this.updateChatIdentity,
  });

  /// StreamNook command names mapped to Flutter backend method names.
  ///
  /// The persisted query hashes are intentionally left empty here. They should
  /// be filled only after capturing the matching Twitch Web/StreamNook requests.
  /// This keeps the backend structure compile-safe without guessing hashes.
  static const streamNookNamesOnly = TwitchViewerSpecialMessageOperationConfigStage251(
    getWatchStreak: TwitchViewerSpecialMessageOperationStage251(
      operationName: 'get_watch_streak',
      sha256Hash: '',
    ),
    shareWatchStreak: TwitchViewerSpecialMessageOperationStage251(
      operationName: 'share_watch_streak',
      sha256Hash: '',
    ),
    getResubNotification: TwitchViewerSpecialMessageOperationStage251(
      operationName: 'get_resub_notification',
      sha256Hash: '',
    ),
    useResubToken: TwitchViewerSpecialMessageOperationStage251(
      operationName: 'use_resub_token',
      sha256Hash: '',
    ),
    fetchChatIdentityBadges: TwitchViewerSpecialMessageOperationStage251(
      operationName: 'fetch_chat_identity_badges',
      sha256Hash: '',
    ),
    updateChatIdentity: TwitchViewerSpecialMessageOperationStage251(
      operationName: 'update_chat_identity',
      sha256Hash: '',
    ),
  );
}

class TwitchViewerSpecialMessageApiServiceStage251 {
  final TwitchWebGqlPersistedApiService gql;
  final TwitchViewerSpecialMessageOperationConfigStage251 operations;

  const TwitchViewerSpecialMessageApiServiceStage251({
    required this.gql,
    this.operations = TwitchViewerSpecialMessageOperationConfigStage251.streamNookNamesOnly,
  });

  Future<TwitchWatchStreakStatusStage251> getWatchStreak({
    required String channelLogin,
    String? channelId,
    String? viewerId,
  }) async {
    final raw = await _single(
      operation: operations.getWatchStreak,
      variables: _channelVariables(
        channelLogin: channelLogin,
        channelId: channelId,
        viewerId: viewerId,
      ),
    );
    return TwitchWatchStreakStatusStage251.fromRaw(
      channelLogin: channelLogin,
      channelId: channelId,
      raw: raw,
    );
  }

  Future<dynamic> shareWatchStreak({
    required String channelLogin,
    String? channelId,
    String? viewerId,
    String? shareToken,
    String message = '',
  }) {
    return _single(
      operation: operations.shareWatchStreak,
      variables: <String, dynamic>{
        ..._channelVariables(
          channelLogin: channelLogin,
          channelId: channelId,
          viewerId: viewerId,
        ),
        if (shareToken != null && shareToken.trim().isNotEmpty)
          'token': shareToken.trim(),
        if (message.trim().isNotEmpty) 'message': message.trim(),
      },
    );
  }

  Future<TwitchResubNotificationStage251> getResubNotification({
    required String channelLogin,
    String? channelId,
    String? viewerId,
  }) async {
    final raw = await _single(
      operation: operations.getResubNotification,
      variables: _channelVariables(
        channelLogin: channelLogin,
        channelId: channelId,
        viewerId: viewerId,
      ),
    );
    return TwitchResubNotificationStage251.fromRaw(
      channelLogin: channelLogin,
      channelId: channelId,
      raw: raw,
    );
  }

  Future<dynamic> useResubToken({
    required String channelLogin,
    String? channelId,
    String? viewerId,
    required String token,
    String message = '',
  }) {
    return _single(
      operation: operations.useResubToken,
      variables: <String, dynamic>{
        ..._channelVariables(
          channelLogin: channelLogin,
          channelId: channelId,
          viewerId: viewerId,
        ),
        'token': token.trim(),
        if (message.trim().isNotEmpty) 'message': message.trim(),
      },
    );
  }

  Future<TwitchChatIdentityStatusStage251> fetchChatIdentityBadges({
    required String channelLogin,
    String? channelId,
    String? viewerId,
  }) async {
    final raw = await _single(
      operation: operations.fetchChatIdentityBadges,
      variables: _channelVariables(
        channelLogin: channelLogin,
        channelId: channelId,
        viewerId: viewerId,
      ),
    );
    return TwitchChatIdentityStatusStage251.fromRaw(
      channelLogin: channelLogin,
      channelId: channelId,
      raw: raw,
    );
  }

  Future<dynamic> updateChatIdentity({
    required String channelLogin,
    String? channelId,
    String? viewerId,
    required String badgeSetId,
    required String badgeVersion,
  }) {
    return _single(
      operation: operations.updateChatIdentity,
      variables: <String, dynamic>{
        ..._channelVariables(
          channelLogin: channelLogin,
          channelId: channelId,
          viewerId: viewerId,
        ),
        'badgeSetId': badgeSetId.trim(),
        'badgeVersion': badgeVersion.trim(),
      },
    );
  }

  Future<dynamic> _single({
    required TwitchViewerSpecialMessageOperationStage251 operation,
    required Map<String, dynamic> variables,
  }) async {
    if (!operation.isConfigured) {
      throw StateError(
        '${operation.operationName} has no persisted query hash configured yet.',
      );
    }

    final result = await gql.single(operation.build(variables));
    if (result.hasErrors) {
      throw StateError('${operation.operationName} returned GraphQL errors: ${result.response}');
    }
    return result.response;
  }

  Map<String, dynamic> _channelVariables({
    required String channelLogin,
    String? channelId,
    String? viewerId,
  }) {
    final login = channelLogin.trim().toLowerCase();
    return <String, dynamic>{
      if (login.isNotEmpty) 'channelLogin': login,
      if (channelId != null && channelId.trim().isNotEmpty)
        'channelID': channelId.trim(),
      if (channelId != null && channelId.trim().isNotEmpty)
        'channelId': channelId.trim(),
      if (viewerId != null && viewerId.trim().isNotEmpty)
        'viewerID': viewerId.trim(),
      if (viewerId != null && viewerId.trim().isNotEmpty)
        'viewerId': viewerId.trim(),
    };
  }
}
