import '../../models/engagement/twitch_pinned_chat.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';

typedef TwitchPinnedChatTokenProvider = Future<String?> Function();

class TwitchPinnedChatApiService {
  final TwitchApiClient client;
  final String clientId;
  final TwitchPinnedChatTokenProvider? accessTokenProvider;

  const TwitchPinnedChatApiService({
    required this.client,
    this.clientId = TwitchApiConstants.twitchWebClientId,
    this.accessTokenProvider,
  });

  Future<List<TwitchPinnedChatMessage>> getPinnedChatMessages({
    required String channelId,
    int count = 10,
  }) async {
    final raw = await getPinnedChatRaw(
      channelId: channelId,
      count: count,
    );

    return TwitchPinnedChatMessage.listFromGqlResponse(raw);
  }

  Future<dynamic> getPinnedChatRaw({
    required String channelId,
    int count = 10,
  }) async {
    final cid = channelId.trim();
    if (cid.isEmpty) {
      throw ArgumentError.value(channelId, 'channelId', 'channelId cannot be empty');
    }

    final headers = await _headers();

    return client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': 'GetPinnedChat',
        'variables': <String, dynamic>{
          'channelID': cid,
          'count': count.clamp(1, 25),
        },
        'extensions': <String, dynamic>{
          'persistedQuery': <String, dynamic>{
            'version': 1,
            'sha256Hash': '2d099d4c9b6af80a07d8440140c4f3dbb04d516b35c401aab7ce8f60765308d5',
          },
        },
      },
      headers: headers,
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
