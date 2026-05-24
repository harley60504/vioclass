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
      operationName: operationName.trim(),
      variables: variables,
      sha256Hash: sha256Hash.trim(),
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

  static const streamNook = TwitchViewerSpecialMessageOperationConfigStage251(
    getWatchStreak: TwitchViewerSpecialMessageOperationStage251(
      operationName: 'RewardList',
      sha256Hash:
          '0b1471876d7647993731b9e3c6a13bf304c67fb31d07f06a945d42286ee377c4',
    ),
    shareWatchStreak: TwitchViewerSpecialMessageOperationStage251(
      operationName: 'ShareMilestone',
      sha256Hash:
          '25d20e60945d10123e8d466e30f21a1f1f578dfdea52c72095030b118eda9f39',
    ),
    getResubNotification: TwitchViewerSpecialMessageOperationStage251(
      operationName: 'Chat_ShareResub_ChannelData',
      sha256Hash:
          'beb55e2ecdbae3dd29c51a60597014d526466bc8f94fb88f3c3482110f4da1aa',
    ),
    useResubToken: TwitchViewerSpecialMessageOperationStage251(
      operationName: 'Chat_ShareResub_UseResubToken',
      sha256Hash:
          '61045d4a4bb10d25080bc0a01a74232f1fa67a6a530e0f2ebf05df2f1ba3fa59',
    ),
    fetchChatIdentityBadges: TwitchViewerSpecialMessageOperationStage251(
      operationName: 'ChatSettings_Badges',
      sha256Hash:
          'f30c0381c916b81bad77302c3cf986094364fa2dfc63a598804cb5ee3743225c',
    ),
    updateChatIdentity: TwitchViewerSpecialMessageOperationStage251(
      operationName: 'ChatSettings_SelectGlobalBadge',
      sha256Hash:
          '5e1b7f0ba771ca8eb81c0fcd5b8f4ff559ec2dc71cc9256e04ec2665049fc4e5',
    ),
  );

  static const streamNookNamesOnly = streamNook;
}

class TwitchViewerSpecialMessageApiServiceStage251 {
  final TwitchWebGqlPersistedApiService webGql;
  final TwitchWebGqlPersistedApiService androidGql;
  final TwitchViewerSpecialMessageOperationConfigStage251 operations;

  const TwitchViewerSpecialMessageApiServiceStage251({
    required this.webGql,
    required this.androidGql,
    this.operations =
        TwitchViewerSpecialMessageOperationConfigStage251.streamNook,
  });

  Future<TwitchWatchStreakStatusStage251> getWatchStreak({
    required String channelLogin,
    String? channelId,
    String? viewerId,
  }) async {
    final raw = await _single(
      gql: webGql,
      operation: operations.getWatchStreak,
      variables: <String, dynamic>{
        'channelID': _requiredValue(channelId, 'channelId'),
        'shouldIncludeAllSuspendedStreaks': false,
      },
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
      gql: webGql,
      operation: operations.shareWatchStreak,
      variables: <String, dynamic>{
        'input': <String, dynamic>{
          'milestoneID': _requiredValue(shareToken, 'shareToken'),
          'channelID': _requiredValue(channelId, 'channelId'),
          'messageBody': message,
        },
      },
    );
  }

  Future<TwitchResubNotificationStage251> getResubNotification({
    required String channelLogin,
    String? channelId,
    String? viewerId,
  }) async {
    final raw = await _single(
      gql: androidGql,
      operation: operations.getResubNotification,
      variables: <String, dynamic>{
        'channelLogin': _requiredLogin(channelLogin),
        'giftRecipientLogin': '',
        'withStandardGifting': false,
      },
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
      gql: androidGql,
      operation: operations.useResubToken,
      variables: <String, dynamic>{
        'input': <String, dynamic>{
          'channelLogin': _requiredLogin(channelLogin),
          'includeStreak': true,
          'message': message,
          'tokenID': _requiredValue(token, 'token'),
        },
      },
    );
  }

  Future<TwitchChatIdentityStatusStage251> fetchChatIdentityBadges({
    required String channelLogin,
    String? channelId,
    String? viewerId,
  }) async {
    final raw = await _single(
      gql: androidGql,
      operation: operations.fetchChatIdentityBadges,
      variables: <String, dynamic>{
        'channelLogin': _requiredLogin(channelLogin),
      },
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
      gql: androidGql,
      operation: operations.updateChatIdentity,
      variables: <String, dynamic>{
        'input': <String, dynamic>{
          'badgeSetID': _requiredValue(badgeSetId, 'badgeSetId'),
          'badgeSetVersion': _requiredValue(badgeVersion, 'badgeVersion'),
        },
      },
    );
  }

  Future<TwitchWebGqlPersistedResult> runCustomPersistedOperation({
    required String operationName,
    required String sha256Hash,
    required Map<String, dynamic> variables,
    bool useAndroidClient = false,
  }) async {
    final operation = TwitchViewerSpecialMessageOperationStage251(
      operationName: operationName,
      sha256Hash: sha256Hash,
    );
    final gql = useAndroidClient ? androidGql : webGql;
    final result = await gql.single(operation.build(variables));
    return result;
  }

  Future<dynamic> _single({
    required TwitchWebGqlPersistedApiService gql,
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
      throw StateError(
        '${operation.operationName} returned GraphQL errors: ${result.response}',
      );
    }
    return result.response;
  }

  String _requiredLogin(String channelLogin) {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      throw StateError('channelLogin is required.');
    }
    return login;
  }

  String _requiredValue(String? value, String name) {
    final safe = value?.trim();
    if (safe == null || safe.isEmpty) {
      throw StateError('$name is required.');
    }
    return safe;
  }
}
