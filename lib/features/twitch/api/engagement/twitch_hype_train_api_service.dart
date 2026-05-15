import '../../models/engagement/twitch_hype_train.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';

typedef TwitchHypeTrainTokenProvider = Future<String?> Function();

class TwitchHypeTrainApiService {
  final TwitchApiClient client;
  final String clientId;
  final TwitchHypeTrainTokenProvider? accessTokenProvider;

  const TwitchHypeTrainApiService({
    required this.client,
    this.clientId = TwitchApiConstants.twitchWebClientId,
    this.accessTokenProvider,
  });

  Future<TwitchHypeTrainSnapshot> getHypeTrainSnapshot({
    required String channelLogin,
  }) async {
    final raw = await getHypeTrainRaw(channelLogin: channelLogin);
    if (raw is! Map<String, dynamic>) {
      throw StateError('Unexpected GetHypeTrainExecution response: ${raw.runtimeType}');
    }

    return TwitchHypeTrainSnapshot.fromGqlResponse(raw);
  }

  Future<dynamic> getHypeTrainRaw({
    required String channelLogin,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      throw ArgumentError.value(channelLogin, 'channelLogin', 'channelLogin cannot be empty');
    }

    return client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': 'GetHypeTrainExecution',
        'variables': <String, dynamic>{
          'userLogin': login,
        },
        'extensions': <String, dynamic>{
          'persistedQuery': <String, dynamic>{
            'version': 1,
            'sha256Hash': '086b4f88754c8270672b32069ff64695e5ee95c678fb7fe57bb027d12f8c83f7',
          },
        },
      },
      headers: await _headers(),
    );
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
