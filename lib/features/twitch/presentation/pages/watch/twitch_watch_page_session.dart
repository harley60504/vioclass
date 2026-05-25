part of '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

class _TwitchWatchSessionHandles {
  final TwitchWatchServices services;
  final TwitchWatchFeaturePorts ports;

  final TwitchApiClient apiClient;
  final TwitchAuthService authService;
  final TwitchDropsAuthService dropsAuthService;
  final TwitchWebGqlAuthService webGqlAuthService;
  final TwitchAuthApiService authApi;
  final TwitchRecentMessagesApiService recentMessagesApi;
  final TwitchMediaKitPlayerSession playerSession;

  _TwitchWatchSessionHandles._({
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

  factory _TwitchWatchSessionHandles.create({required String playerTitle}) {
    final services = TwitchWatchServices.create(playerTitle: playerTitle);
    final ports = TwitchWatchFeaturePorts.fromServices(services);

    return _TwitchWatchSessionHandles._(
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
