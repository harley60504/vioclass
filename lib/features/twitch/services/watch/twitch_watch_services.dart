// PATCH VERSION: twitch_watch_services_stage250d_streamnook_channel_points_auth
//
// Owns the Watch composition dependency graph. WatchPage should assemble UI and
// route lifecycle; feature services are exposed as small groups so Player,
// Chat, Emote, Engagement, and Relationship components can receive their own
// dependency object instead of routing every API call through WatchPage.

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/channel/twitch_private_gql_relationship_api_service_v1.dart';
import '../../api/chat/twitch_chat_startup_api_service.dart';
import '../../api/chat/twitch_recent_messages_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../api/core/twitch_gql_api_service.dart';
import '../../api/core/twitch_web_gql_persisted_api_service.dart';
import '../../api/emotes/twitch_official_emote_api_service.dart';
import '../../api/emotes/twitch_third_party_emote_api_service.dart';
import '../../api/engagement/twitch_channel_points_api_service.dart';
import '../../api/engagement/twitch_drops_prediction_api_service.dart';
import '../../api/engagement/twitch_pinned_chat_api_service.dart';
import '../../api/engagement/twitch_prediction_api_service.dart';
import '../../api/engagement/twitch_subscribe_api_service_v1.dart';
import '../../api/playback/twitch_playback_api_service.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../../services/chat/twitch_official_emote_cache_service.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../services/playback/twitch_media_kit_player_host.dart';
import '../../services/playback/twitch_playlist_player_runtime.dart';
import 'twitch_watch_feature_services.dart';

class TwitchWatchServices {
  final TwitchApiClient apiClient;
  final TwitchAuthService authService;
  final TwitchDropsAuthService dropsAuthService;
  final TwitchWebGqlAuthService webGqlAuthService;
  final TwitchAuthApiService authApi;
  final TwitchGqlApiService publicGqlApi;
  final TwitchWebGqlPersistedApiService publicWebGqlApi;
  final TwitchPlaybackApiService playbackApi;
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final TwitchChatStartupApiService chatStartupApi;
  final TwitchRecentMessagesApiService recentMessagesApi;
  final TwitchThirdPartyEmoteCacheService thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService officialEmotes;
  final TwitchChannelPointsApiService channelPointsApi;
  final TwitchPrivateGqlRelationshipApiServiceV1 relationshipApi;
  final TwitchSubscribeApiServiceV1 subscribeApi;
  final TwitchChannelPointsRuntimeService channelPointsRuntimeService;
  final TwitchPinnedChatApiService pinnedChatApi;
  final TwitchPredictionApiService publicPredictionApi;
  final TwitchDropsPredictionApiService dropsPredictionApi;
  final TwitchMediaKitPlayerSession playerSession;

  final TwitchWatchCoreServices core;
  final TwitchWatchAuthServices auth;
  final TwitchWatchPlayerServices player;
  final TwitchWatchChatServices chat;
  final TwitchWatchEmoteServices emotes;
  final TwitchWatchEngagementServices engagement;
  final TwitchWatchRelationshipServices relationship;

  const TwitchWatchServices({
    required this.apiClient,
    required this.authService,
    required this.dropsAuthService,
    required this.webGqlAuthService,
    required this.authApi,
    required this.publicGqlApi,
    required this.publicWebGqlApi,
    required this.playbackApi,
    required this.playerRuntime,
    required this.chatStartupApi,
    required this.recentMessagesApi,
    required this.thirdPartyEmotes,
    required this.officialEmotes,
    required this.channelPointsApi,
    required this.relationshipApi,
    required this.subscribeApi,
    required this.channelPointsRuntimeService,
    required this.pinnedChatApi,
    required this.publicPredictionApi,
    required this.dropsPredictionApi,
    required this.playerSession,
    required this.core,
    required this.auth,
    required this.player,
    required this.chat,
    required this.emotes,
    required this.engagement,
    required this.relationship,
  });

  factory TwitchWatchServices.create({
    String playerTitle = 'Twitch Raw Proxy',
  }) {
    final apiClient = TwitchApiClient();
    final authService = TwitchAuthService(apiClient: apiClient);
    final dropsAuthService = TwitchDropsAuthService(apiClient: apiClient);
    final webGqlAuthService = TwitchWebGqlAuthService(apiClient: apiClient);

    final authApi = TwitchAuthApiService(
      client: apiClient,
      clientId: TwitchApiConstants.twitchWebClientId,
    );
    final publicGqlApi = TwitchGqlApiService(
      client: apiClient,
      clientId: TwitchApiConstants.twitchWebClientId,
      accessTokenProvider: null,
    );
    final publicWebGqlApi = TwitchWebGqlPersistedApiService(
      client: apiClient,
      clientId: TwitchApiConstants.twitchWebClientId,
      accessTokenProvider: webGqlAuthService.getToken,
    );
    final playbackApi = TwitchPlaybackApiService(gql: publicGqlApi);
    final playerRuntime = TwitchPlaylistPlayerRuntime(playbackApi: playbackApi);
    final chatStartupApi = TwitchChatStartupApiService(gql: publicWebGqlApi);
    final recentMessagesApi = TwitchRecentMessagesApiService(client: apiClient);
    final thirdPartyEmotes = TwitchThirdPartyEmoteCacheService(
      api: TwitchThirdPartyEmoteApiService(client: apiClient),
    );
    final officialEmotes = TwitchOfficialEmoteCacheService(
      api: TwitchOfficialEmoteApiService(client: apiClient),
      accessTokenProvider: authService.getValidAccessToken,
      clientIdProvider: () async {
        final stored = authService.clientId?.trim();
        if (stored != null && stored.isNotEmpty) return stored;
        return TwitchApiConstants.twitchWebClientId;
      },
    );
    final channelPointsApi = TwitchChannelPointsApiService(
      gql: publicWebGqlApi,
      client: apiClient,
      tokenProvider: () async {
        final dropsToken = await dropsAuthService.getToken();
        if (dropsToken != null && dropsToken.trim().isNotEmpty) {
          return dropsToken.trim();
        }
        return webGqlAuthService.getToken();
      },
      actionClientIdProvider: () {
        final dropsClientId = dropsAuthService.dropsClientId.trim();
        if (dropsClientId.isNotEmpty) return dropsClientId;
        return TwitchApiConstants.twitchDefaultDropsClientId;
      },
    );
    final relationshipApi = TwitchPrivateGqlRelationshipApiServiceV1(
      client: apiClient,
      oauthTokenProvider: authService.getValidAccessToken,
      oauthClientIdProvider: () async {
        final stored = authService.clientId?.trim();
        if (stored != null && stored.isNotEmpty) return stored;
        return TwitchApiConstants.twitchWebClientId;
      },
      dropsTokenProvider: dropsAuthService.getToken,
      dropsClientIdProvider: () async => dropsAuthService.dropsClientId,
    );
    final subscribeApi = const TwitchSubscribeApiServiceV1();
    final channelPointsRuntimeService = TwitchChannelPointsRuntimeService(
      channelPointsApi: channelPointsApi,
    );
    final pinnedChatApi = TwitchPinnedChatApiService(
      client: apiClient,
      clientId: TwitchApiConstants.twitchWebClientId,
      accessTokenProvider: null,
    );
    final publicPredictionApi = TwitchPredictionApiService(gql: publicWebGqlApi);
    final dropsPredictionApi = TwitchDropsPredictionApiService(
      client: apiClient,
      tokenProvider: dropsAuthService.getToken,
    );
    final playerSession = TwitchMediaKitPlayerHost.acquire(title: playerTitle);

    final core = TwitchWatchCoreServices(
      apiClient: apiClient,
      publicGqlApi: publicGqlApi,
      publicWebGqlApi: publicWebGqlApi,
    );
    final auth = TwitchWatchAuthServices(
      authService: authService,
      dropsAuthService: dropsAuthService,
      webGqlAuthService: webGqlAuthService,
      authApi: authApi,
    );
    final player = TwitchWatchPlayerServices(
      playbackApi: playbackApi,
      playerRuntime: playerRuntime,
      playerSession: playerSession,
    );
    final chat = TwitchWatchChatServices(
      chatStartupApi: chatStartupApi,
      recentMessagesApi: recentMessagesApi,
    );
    final emotes = TwitchWatchEmoteServices(
      thirdPartyEmotes: thirdPartyEmotes,
      officialEmotes: officialEmotes,
    );
    final engagement = TwitchWatchEngagementServices(
      channelPointsApi: channelPointsApi,
      channelPointsRuntimeService: channelPointsRuntimeService,
      pinnedChatApi: pinnedChatApi,
      publicPredictionApi: publicPredictionApi,
      dropsPredictionApi: dropsPredictionApi,
    );
    final relationship = TwitchWatchRelationshipServices(
      relationshipApi: relationshipApi,
      subscribeApi: subscribeApi,
    );

    return TwitchWatchServices(
      apiClient: apiClient,
      authService: authService,
      dropsAuthService: dropsAuthService,
      webGqlAuthService: webGqlAuthService,
      authApi: authApi,
      publicGqlApi: publicGqlApi,
      publicWebGqlApi: publicWebGqlApi,
      playbackApi: playbackApi,
      playerRuntime: playerRuntime,
      chatStartupApi: chatStartupApi,
      recentMessagesApi: recentMessagesApi,
      thirdPartyEmotes: thirdPartyEmotes,
      officialEmotes: officialEmotes,
      channelPointsApi: channelPointsApi,
      relationshipApi: relationshipApi,
      subscribeApi: subscribeApi,
      channelPointsRuntimeService: channelPointsRuntimeService,
      pinnedChatApi: pinnedChatApi,
      publicPredictionApi: publicPredictionApi,
      dropsPredictionApi: dropsPredictionApi,
      playerSession: playerSession,
      core: core,
      auth: auth,
      player: player,
      chat: chat,
      emotes: emotes,
      engagement: engagement,
      relationship: relationship,
    );
  }
}