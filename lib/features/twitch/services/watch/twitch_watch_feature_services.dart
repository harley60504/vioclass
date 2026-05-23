// PATCH VERSION: twitch_watch_feature_services_stage251b_special_message_debug
//
// Feature-facing service groups for Watch composition.
//
// The goal is to let Player / Chat / Emote / Engagement / Relationship UI
// receive their own small dependency object instead of routing every API call
// through TwitchWatchPage.

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/channel/twitch_private_gql_relationship_api_service_v1.dart';
import '../../api/chat/twitch_chat_startup_api_service.dart';
import '../../api/chat/twitch_recent_messages_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_gql_api_service.dart';
import '../../api/core/twitch_web_gql_persisted_api_service.dart';
import '../../api/engagement/twitch_channel_points_api_service.dart';
import '../../api/engagement/twitch_drops_prediction_api_service.dart';
import '../../api/engagement/twitch_pinned_chat_api_service.dart';
import '../../api/engagement/twitch_prediction_api_service.dart';
import '../../api/engagement/twitch_subscribe_api_service_v1.dart';
import '../../api/playback/twitch_playback_api_service.dart';
import '../../api/special_actions/twitch_viewer_special_message_api_service_stage251.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../../services/chat/twitch_official_emote_cache_service.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../services/playback/twitch_media_kit_player_host.dart';
import '../../services/playback/twitch_playlist_player_runtime.dart';
import '../../services/special_actions/twitch_viewer_special_message_debug_probe_stage251.dart';
import '../../services/special_actions/twitch_viewer_special_message_runtime_stage251.dart';

class TwitchWatchCoreServices {
  final TwitchApiClient apiClient;
  final TwitchGqlApiService publicGqlApi;
  final TwitchWebGqlPersistedApiService publicWebGqlApi;

  const TwitchWatchCoreServices({
    required this.apiClient,
    required this.publicGqlApi,
    required this.publicWebGqlApi,
  });
}

class TwitchWatchAuthServices {
  final TwitchAuthService authService;
  final TwitchDropsAuthService dropsAuthService;
  final TwitchWebGqlAuthService webGqlAuthService;
  final TwitchAuthApiService authApi;

  const TwitchWatchAuthServices({
    required this.authService,
    required this.dropsAuthService,
    required this.webGqlAuthService,
    required this.authApi,
  });
}

class TwitchWatchPlayerServices {
  final TwitchPlaybackApiService playbackApi;
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final TwitchMediaKitPlayerSession playerSession;

  const TwitchWatchPlayerServices({
    required this.playbackApi,
    required this.playerRuntime,
    required this.playerSession,
  });
}

class TwitchWatchChatServices {
  final TwitchChatStartupApiService chatStartupApi;
  final TwitchRecentMessagesApiService recentMessagesApi;

  const TwitchWatchChatServices({
    required this.chatStartupApi,
    required this.recentMessagesApi,
  });
}

class TwitchWatchEmoteServices {
  final TwitchThirdPartyEmoteCacheService thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService officialEmotes;

  const TwitchWatchEmoteServices({
    required this.thirdPartyEmotes,
    required this.officialEmotes,
  });
}

class TwitchWatchEngagementServices {
  final TwitchChannelPointsApiService channelPointsApi;
  final TwitchChannelPointsRuntimeService channelPointsRuntimeService;
  final TwitchPinnedChatApiService pinnedChatApi;
  final TwitchPredictionApiService publicPredictionApi;
  final TwitchDropsPredictionApiService dropsPredictionApi;

  const TwitchWatchEngagementServices({
    required this.channelPointsApi,
    required this.channelPointsRuntimeService,
    required this.pinnedChatApi,
    required this.publicPredictionApi,
    required this.dropsPredictionApi,
  });
}

class TwitchWatchSpecialMessageServicesStage251 {
  final TwitchViewerSpecialMessageApiServiceStage251 api;
  final TwitchViewerSpecialMessageRuntimeStage251 runtime;
  final TwitchViewerSpecialMessageDebugProbeStage251 debugProbe;

  const TwitchWatchSpecialMessageServicesStage251({
    required this.api,
    required this.runtime,
    required this.debugProbe,
  });
}

class TwitchWatchRelationshipServices {
  final TwitchPrivateGqlRelationshipApiServiceV1 relationshipApi;
  final TwitchSubscribeApiServiceV1 subscribeApi;

  const TwitchWatchRelationshipServices({
    required this.relationshipApi,
    required this.subscribeApi,
  });
}
