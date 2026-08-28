import 'package:media_kit/media_kit.dart';

import '../../../api/auth/twitch_auth_api_service.dart';
import '../../../api/chat/twitch_recent_messages_api_service.dart';
import '../../../api/core/twitch_api_client.dart';
import '../../../services/auth/twitch_auth_service.dart';
import '../../../services/auth/twitch_drops_auth_service.dart';
import '../../../services/auth/twitch_web_gql_auth_service.dart';
import '../../../services/playback/twitch_media_kit_player_host.dart';
import '../../../services/playback/twitch_playlist_player_runtime.dart';
import '../../../services/watch/twitch_watch_services.dart';
import '../../watch/twitch_watch_feature_ports.dart';

class TwitchWatchSessionHandles {
  final TwitchWatchServices services;
  final TwitchWatchFeaturePorts ports;

  final TwitchApiClient apiClient;
  final TwitchAuthService authService;
  final TwitchDropsAuthService dropsAuthService;
  final TwitchWebGqlAuthService webGqlAuthService;
  final TwitchAuthApiService authApi;
  final TwitchRecentMessagesApiService recentMessagesApi;
  final TwitchMediaKitPlayerSession playerSession;

  TwitchWatchSessionHandles._({
    required this.services,
    required this.ports,
    required this.apiClient,
    required this.authService,
    required this.dropsAuthService,
    required this.webGqlAuthService,
    required this.authApi,
    required this.recentMessagesApi,
    required this.playerSession,
  });

  factory TwitchWatchSessionHandles.create({
    required String playerTitle,
    TwitchPlaylistPlayerRuntime? playerRuntime,
  }) {
    final services = TwitchWatchServices.create(
      playerTitle: playerTitle,
      playerRuntime: playerRuntime,
    );
    final ports = TwitchWatchFeaturePorts.fromServices(services);

    return TwitchWatchSessionHandles._(
      services: services,
      ports: ports,
      apiClient: services.apiClient,
      authService: services.authService,
      dropsAuthService: services.dropsAuthService,
      webGqlAuthService: services.webGqlAuthService,
      authApi: services.authApi,
      recentMessagesApi: services.recentMessagesApi,
      playerSession: services.playerSession,
    );
  }

  Player get player => playerSession.player;

  void closeApiClient() {
    apiClient.close(force: true);
  }
}
