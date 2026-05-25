// PATCH VERSION: twitch_playback_api_service_ad_aware_contexts_v34

import '../../models/playback/twitch_playback.dart';
import '../core/twitch_gql_api_service.dart';

class TwitchPlaybackApiService {
  final TwitchGqlApiService gql;

  const TwitchPlaybackApiService({required this.gql});

  Future<TwitchPlaybackAccessToken> getLivePlaybackAccessToken({
    required String channelLogin,
    String platform = 'web',
    String playerType = 'site',
  }) async {
    final login = channelLogin.trim().toLowerCase();
    final cleanPlatform = platform.trim().isEmpty ? 'web' : platform.trim();
    final cleanPlayerType = playerType.trim().isEmpty
        ? 'site'
        : playerType.trim();

    if (login.isEmpty) {
      throw ArgumentError.value(
        channelLogin,
        'channelLogin',
        'channel login cannot be empty',
      );
    }

    final data = await gql.request(
      operationName: 'PlaybackAccessToken',
      query: r'''
        query PlaybackAccessToken(
          $login: String!
          $isLive: Boolean!
          $vodID: ID!
          $isVod: Boolean!
          $platform: String!
          $playerType: String!
        ) {
          streamPlaybackAccessToken(
            channelName: $login
            params: {
              platform: $platform
              playerBackend: "mediaplayer"
              playerType: $playerType
            }
          ) @include(if: $isLive) {
            value
            signature
          }
          videoPlaybackAccessToken(
            id: $vodID
            params: {
              platform: $platform
              playerBackend: "mediaplayer"
              playerType: $playerType
            }
          ) @include(if: $isVod) {
            value
            signature
          }
        }
      ''',
      variables: <String, dynamic>{
        'login': login,
        'isLive': true,
        'vodID': '',
        'isVod': false,
        'platform': cleanPlatform,
        'playerType': cleanPlayerType,
      },
    );

    final raw = data['streamPlaybackAccessToken'];
    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'GQL response does not contain streamPlaybackAccessToken.',
      );
    }

    final token = TwitchPlaybackAccessToken.fromJson(raw);
    if (!token.isValid) {
      throw StateError('Playback token is incomplete.');
    }

    return token;
  }

  Uri buildLivePlaylistUri({
    required String channelLogin,
    required TwitchPlaybackAccessToken accessToken,
    bool allowSource = true,
    bool allowAudioOnly = true,
    String supportedCodecs = 'avc1',
  }) {
    final login = channelLogin.trim().toLowerCase();

    return TwitchPlaybackPlaylistRequest(
      channelLogin: login,
      accessToken: accessToken,
      clientId: gql.clientId,
      allowSource: allowSource,
      allowAudioOnly: allowAudioOnly,
      supportedCodecs: supportedCodecs.trim().isEmpty
          ? 'avc1'
          : supportedCodecs.trim(),
    ).buildUsherUri();
  }
}
