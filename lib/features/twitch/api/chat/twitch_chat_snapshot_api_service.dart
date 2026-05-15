import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';

typedef TwitchSnapshotTokenProvider = Future<String?> Function();

class TwitchPersistedGqlOperation {
  final String operationName;
  final Map<String, dynamic> variables;
  final String sha256Hash;

  const TwitchPersistedGqlOperation({
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

class TwitchChatSnapshotResult {
  final String operationName;
  final Map<String, dynamic> variables;
  final dynamic response;

  const TwitchChatSnapshotResult({
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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'operationName': operationName,
      'variables': variables,
      'hasErrors': hasErrors,
      'response': response,
    };
  }
}

/// Twitch chat 週邊資料 snapshot。
///
/// 這裡先用已觀察到的 Twitch Web persisted query 做「可測性驗證」。
/// 正式 UI 層之後不要直接吃 raw response，要再拆成 model/controller。
class TwitchChatSnapshotApiService {
  final TwitchApiClient client;
  final String clientId;
  final TwitchSnapshotTokenProvider? accessTokenProvider;

  const TwitchChatSnapshotApiService({
    required this.client,
    this.clientId = TwitchApiConstants.twitchWebClientId,
    this.accessTokenProvider,
  });

  Future<List<TwitchChatSnapshotResult>> fetchCoreSnapshot({
    required String channelId,
    required String channelLogin,
    String? viewerId,
  }) async {
    final cid = channelId.trim();
    final login = channelLogin.trim().toLowerCase();

    if (cid.isEmpty) {
      throw ArgumentError.value(channelId, 'channelId', 'channelId cannot be empty');
    }

    final operations = <TwitchPersistedGqlOperation>[
      TwitchPersistedGqlOperation(
        operationName: 'GetPinnedChat',
        variables: <String, dynamic>{
          'channelID': cid,
          'count': 10,
        },
        sha256Hash: '2d099d4c9b6af80a07d8440140c4f3dbb04d516b35c401aab7ce8f60765308d5',
      ),
      TwitchPersistedGqlOperation(
        operationName: 'PaidPinnedChat',
        variables: <String, dynamic>{
          'channelID': cid,
          'count': 25,
          'messageType': 'CHEER',
        },
        sha256Hash: '888056ddc92e62a7d2fd7a8e0afae5d61fab767ba621ed1006ba8628f6de8e41',
      ),
      TwitchPersistedGqlOperation(
        operationName: 'RewardList',
        variables: <String, dynamic>{
          'shouldIncludeAllSuspendedStreaks': false,
          'channelID': cid,
        },
        sha256Hash: '0b1471876d7647993731b9e3c6a13bf304c67fb31d07f06a945d42286ee377c4',
      ),
      TwitchPersistedGqlOperation(
        operationName: 'ChannelLeaderboards',
        variables: <String, dynamic>{
          'first': 10,
          'channelID': cid,
        },
        sha256Hash: 'c7cd5116534e0bf47c324dc0ea6f28a3dfb4f429e3d3b274a30f386ea62973e1',
      ),
      TwitchPersistedGqlOperation(
        operationName: 'ChatInput_Badges',
        variables: const <String, dynamic>{},
        sha256Hash: '8cb0eae66555ad6dc76aaa111d191ea6174c743f996d506f530e479f28e6b37c',
      ),
      TwitchPersistedGqlOperation(
        operationName: 'BitsEmotesData',
        variables: <String, dynamic>{
          'channelOwnerID': cid,
        },
        sha256Hash: '20807fd5ba85eac178d3f4db4679a346b3c8058057f9255c50a66fb524c60dee',
      ),
      TwitchPersistedGqlOperation(
        operationName: 'SharedChatSession',
        variables: <String, dynamic>{
          'channelID': cid,
        },
        sha256Hash: '0ff9562b30cfa2b41ab1738485ced6f8f1e725a93abe732c396be5f4f1d13694',
      ),
      if (login.isNotEmpty)
        TwitchPersistedGqlOperation(
          operationName: 'GetHypeTrainExecution',
          variables: <String, dynamic>{
            'userLogin': login,
          },
          sha256Hash: '086b4f88754c8270672b32069ff64695e5ee95c678fb7fe57bb027d12f8c83f7',
        ),
      if (viewerId != null && viewerId.trim().isNotEmpty)
        TwitchPersistedGqlOperation(
          operationName: 'UserModStatus',
          variables: <String, dynamic>{
            'channelID': cid,
            'userID': viewerId.trim(),
          },
          sha256Hash: '511b58faf547070bc95b7d32e7b5cdedf8c289a3aeabfc3c5d3ece2de01ae06f',
        ),
    ];

    return runPersistedOperations(operations);
  }

  Future<List<TwitchChatSnapshotResult>> runPersistedOperations(
    List<TwitchPersistedGqlOperation> operations,
  ) async {
    if (operations.isEmpty) {
      return const <TwitchChatSnapshotResult>[];
    }

    final headers = await _headers();

    final raw = await client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: operations.map((operation) => operation.toJson()).toList(),
      headers: headers,
    );

    if (raw is! List) {
      return <TwitchChatSnapshotResult>[
        TwitchChatSnapshotResult(
          operationName: 'batch',
          variables: const <String, dynamic>{},
          response: raw,
        ),
      ];
    }

    final results = <TwitchChatSnapshotResult>[];

    for (var i = 0; i < operations.length; i++) {
      results.add(
        TwitchChatSnapshotResult(
          operationName: operations[i].operationName,
          variables: operations[i].variables,
          response: i < raw.length ? raw[i] : null,
        ),
      );
    }

    return results;
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
