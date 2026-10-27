// Fixture subclasses deliberately replace complete dependency fields.
// Tests live in docs under this repository's workflow.
// ignore_for_file: overridden_fields, invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:vioclass/features/twitch/api/engagement/twitch_subscribe_api_service_v1.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/watch/twitch_watch_page_chat.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_route_guard.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_linked_login_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/watch/twitch_watch_page_startup.dart';
import 'package:vioclass/features/twitch/services/special_actions/twitch_viewer_special_message_runtime.dart';
import 'package:vioclass/features/twitch/services/chat/twitch_official_emote_cache_service.dart';
import 'package:vioclass/features/twitch/services/chat/twitch_third_party_emote_cache_service.dart';
import 'package:vioclass/features/twitch/api/emotes/twitch_official_emote_api_service.dart';
import 'package:vioclass/features/twitch/api/emotes/twitch_third_party_emote_api_service.dart';
import 'package:vioclass/features/twitch/api/playback/twitch_playback_api_service.dart';
import 'package:vioclass/features/twitch/api/engagement/twitch_hype_train_api_service.dart';
import 'package:vioclass/features/twitch/api/chat/twitch_chat_startup_api_service.dart';
import 'package:vioclass/features/twitch/models/chat/twitch_chat_startup.dart';
import 'package:vioclass/features/twitch/models/chat/twitch_chat_badge.dart';
import 'package:vioclass/features/twitch/models/special_actions/twitch_pending_special_message.dart';
import 'package:vioclass/features/twitch/models/special_actions/twitch_viewer_special_message_models.dart';
import 'package:vioclass/features/twitch/models/chat/twitch_chat_runtime_message.dart';
import 'package:vioclass/features/twitch/models/chat/twitch_chat_message.dart';
import 'package:vioclass/features/twitch/models/chat/twitch_chat_message_metadata.dart';
import 'package:vioclass/features/twitch/presentation/sheets/twitch_chat_user_profile_sheet.dart';
import 'package:vioclass/features/twitch/models/discovery/twitch_live_stream.dart';
import 'package:vioclass/features/twitch/models/playback/twitch_m3u8_variant.dart';
import 'package:vioclass/features/twitch/services/chat/twitch_chat_runtime.dart';
import 'package:vioclass/features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart';

import 'package:vioclass/features/twitch/api/auth/twitch_auth_api_service.dart';
import 'package:vioclass/features/twitch/api/chat/twitch_recent_messages_api_service.dart';
import 'package:vioclass/features/twitch/api/core/twitch_api_client.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_auth_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_viewer_session.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_drops_auth_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_web_gql_auth_service.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_media_kit_player_host.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_playlist_player_runtime.dart';
import 'package:vioclass/features/twitch/services/watch/twitch_watch_services.dart';
import 'package:vioclass/features/twitch/services/watch/twitch_watch_feature_services.dart';
import 'package:vioclass/features/twitch/presentation/pages/watch/twitch_watch_page_session.dart';
import 'package:vioclass/features/twitch/presentation/pages/watch/twitch_watch_page_navigation.dart';
import 'package:vioclass/features/twitch/presentation/pages/watch/twitch_watch_playback_state.dart';
import 'package:vioclass/features/twitch/presentation/mini_player/twitch_mini_player_controller.dart';
import 'package:vioclass/features/twitch/presentation/watch/twitch_playback_session_controller.dart';
import 'package:vioclass/features/twitch/presentation/watch/twitch_watch_playback_kind.dart';
import 'package:vioclass/features/twitch/presentation/settings/twitch_player_settings_controller.dart';
import 'package:vioclass/features/twitch/models/discovery/twitch_stream_header_metadata.dart';
import 'package:vioclass/features/twitch/api/channel/twitch_private_gql_relationship_api_service_v1.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/player/twitch_watch_top_buttons.dart';
import 'package:vioclass/features/twitch/presentation/watch/adapters/twitch_watch_player_area_port_adapter.dart';
import 'package:vioclass/features/twitch/presentation/watch/twitch_watch_feature_ports.dart';
import 'package:vioclass/features/twitch/api/engagement/twitch_channel_points_api_service.dart';
import 'package:vioclass/features/twitch/services/engagement/twitch_channel_points_runtime_service.dart';
import 'package:vioclass/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_widgets.dart';
import 'package:vioclass/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import 'package:vioclass/features/twitch/services/discovery/twitch_discovery_service.dart';
import 'package:vioclass/features/twitch/models/engagement/twitch_prediction.dart';
import 'package:vioclass/features/twitch/services/engagement/twitch_prediction_hermes_runtime_service.dart';
import 'package:vioclass/features/twitch/presentation/widgets/chat/cards/twitch_prediction_banner.dart';
import 'package:vioclass/features/twitch/presentation/sheets/twitch_prediction_bet_sheet.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_utility_bar.dart';
import 'package:vioclass/features/twitch/api/chat/twitch_irc_api_service.dart';

class _IdentityOnlyIrc implements TwitchIrcApiService {
  @override
  String get currentUserColor => '';
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected identity fixture IRC operation');
}

class _RailDiscovery extends TwitchDiscoveryService {
  _RailDiscovery(_SendMountServices services)
    : super(
        client: services.apiClient,
        authService: services.authService,
        authApi: services.authApi,
      );
  final streams = [
    const TwitchLiveStream(
      id: 'fixture-rail-stream',
      userId: '8',
      userLogin: 'fixture_rail_peer',
      userName: 'Fixture rail peer',
      gameId: '',
      gameName: 'Fixture game',
      title: 'Fixture rail title',
      viewerCount: 1,
      startedAt: null,
      language: 'zh',
      thumbnailUrl: '',
      tags: [],
      isMature: false,
    ),
  ];
  @override
  List<TwitchLiveStream> get cachedFollowedLiveRailStreams => streams;
  @override
  Future<List<TwitchLiveStream>> fetchFollowedLiveRailStreams() async =>
      streams;
}

class _RailRouteProbe extends NavigatorObserver {
  Route<dynamic>? replacement;
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacement = newRoute;
    // Prevent the destination from creating its real client/player/storage.
    if (newRoute != null) {
      scheduleMicrotask(() => navigator!.removeRoute(newRoute));
    }
  }
}

class _PagePointsRuntime implements TwitchChannelPointsRuntimeService {
  _PagePointsRuntime(this.signed, this.login);
  final bool Function() signed;
  final String login;
  int redeems = 0;
  TwitchChannelPointsRuntimeSnapshot get snapshot =>
      TwitchChannelPointsRuntimeSnapshot(
        channelLogin: login,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        publicRead: null,
        publicError: null,
        contextError: null,
        rewardsError: null,
        context: signed()
            ? TwitchChannelPointsContext(
                channelId: '7',
                channelLogin: login,
                balance: 10,
                availableClaimId: null,
                availableClaimPoints: 0,
                pointsName: null,
                pointsIconUrl: null,
                raw: null,
              )
            : null,
        rewardsResult: TwitchChannelRewardsResult(
          channelLogin: login,
          channelId: '7',
          pointsName: null,
          pointsIconUrl: null,
          rewards: [
            TwitchChannelReward.fromJson({
              'id': 'fixture-points',
              'title': 'fixture points reward',
              'cost': 10,
              'isEnabled': true,
              'isInStock': true,
            }, source: 'custom'),
          ],
          raw: null,
        ),
      );
  @override
  Future<TwitchChannelRewardRedeemResult> redeemReward({
    required String channelId,
    required Map<String, dynamic> reward,
    String textInput = '',
  }) async {
    expectSync(channelId, '7');
    expectSync(reward['id'], 'fixture-points');
    redeems++;
    return const TwitchChannelRewardRedeemResult(
      ok: true,
      rewardId: 'fixture-points',
      transactionId: 'fixture-transaction',
      raw: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #load) {
      return Future<TwitchChannelPointsRuntimeSnapshot>.value(snapshot);
    }
    return super.noSuchMethod(invocation);
  }
}

class _PagePointsServices extends _EngagementServices {
  _PagePointsServices(this.channelPointsRuntimeService);
  @override
  final TwitchChannelPointsRuntimeService channelPointsRuntimeService;
}

class _FollowApi implements TwitchPrivateGqlRelationshipApiServiceV1 {
  _FollowApi(this.following, {this.channelId = '7'});
  final bool following;
  final String channelId;
  final result = Completer<TwitchPrivateGqlRelationshipSnapshot>();
  final calls = <String>[];
  TwitchPrivateGqlRelationshipSnapshot snapshot(String login, bool followed) =>
      TwitchPrivateGqlRelationshipSnapshot(
        userId: channelId,
        login: login,
        displayName: 'Fixture',
        isFollowing: followed,
      );
  @override
  Future<TwitchPrivateGqlRelationshipSnapshot> fetchRelationship({
    required String channelLogin,
    String? targetUserId,
    String? viewerUserId,
  }) async => snapshot(channelLogin, following);
  Future<TwitchPrivateGqlRelationshipSnapshot> write(
    String action,
    String login,
    String? target,
    String? viewer,
  ) {
    expectSync(target, channelId);
    expectSync(viewer, '42');
    calls.add(action);
    return result.future;
  }

  @override
  Future<TwitchPrivateGqlRelationshipSnapshot> followChannel({
    required String channelLogin,
    String? targetUserId,
    String? viewerUserId,
  }) => write('follow', channelLogin, targetUserId, viewerUserId);
  @override
  Future<TwitchPrivateGqlRelationshipSnapshot> unfollowChannel({
    required String channelLogin,
    String? targetUserId,
    String? viewerUserId,
  }) => write('unfollow', channelLogin, targetUserId, viewerUserId);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FollowServices implements TwitchWatchRelationshipServices {
  _FollowServices(this.relationshipApi);
  @override
  final _FollowApi relationshipApi;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FollowMountServices extends _SendMountServices {
  _FollowMountServices(_FollowApi api) : relationship = _FollowServices(api);
  @override
  final _FollowServices relationship;
}

class _UnusedPlayback implements TwitchPlaybackApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Fail closed: no fixture creates a native player, connects IRC, or loads storage.
class _Runtime implements TwitchPlaylistPlayerRuntime {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #busy) return false;
    if (invocation.memberName == #usingLiveTimelineReplay) return false;
    if (invocation.memberName == #usingExternalVodPlayback) return false;
    if (invocation.memberName == #usingLiveDvrBridge) return false;
    if (invocation.memberName == #error) return null;
    if (invocation.memberName == #dispose) return null;
    return super.noSuchMethod(invocation);
  }
}

class _PlayerSession implements TwitchMediaKitPlayerSession {
  int profileRequests = 0;
  Completer<void>? profileGate;
  Player? exposedPlayer;
  @override
  Future<void> useLowLatencyHlsProfile() async {
    profileRequests++;
    final gate = profileGate;
    if (gate != null) await gate.future;
    throw StateError('fixture playback initialization unavailable');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #playerOrNull) return exposedPlayer;
    if (invocation.memberName == #videoControllerOrNull) {
      return null;
    }
    if (invocation.memberName == #release) return null;
    if (invocation.memberName == #pauseCurrent) return Future<void>.value();
    return super.noSuchMethod(invocation);
  }
}

class _EndedPlayer implements Player {
  _EndedPlayer({required this.completed});
  final bool completed;
  @override
  PlayerState get state => PlayerState(completed: completed, playing: false);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NavigationPlayer implements Player {
  int opens = 0;
  int pauses = 0;
  @override
  PlayerState get state => PlayerState(playing: true);
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #open) {
      opens++;
      return Future<void>.value();
    }
    if (invocation.memberName == #pause) {
      pauses++;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _RecordedQualityPlayer extends _NavigationPlayer {
  bool playing = true;
  Duration position = Duration.zero;
  @override
  PlayerState get state => PlayerState(
    playing: playing,
    position: position,
    duration: const Duration(seconds: 30),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #setProperty) return null;
    if (invocation.memberName == #setVolume) return Future<void>.value();
    if (invocation.memberName == #seek) {
      position = invocation.positionalArguments.first as Duration;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _RecordedQualitySession extends _PlayerSession {
  @override
  final _RecordedQualityPlayer player = _RecordedQualityPlayer();
  int opens = 0;
  bool? lastPlay;
  Duration? lastPosition;
  @override
  Future<void> ensureReady() async {}
  @override
  Future<void> useLowLatencyHlsProfile() async {}
  @override
  Future<void> openOrResume({
    required String uri,
    bool play = true,
    bool forceOpen = false,
    Duration? startPosition,
  }) async {
    expectSync(uri.startsWith('https://fixture.invalid/'), true);
    opens++;
    lastPlay = play;
    lastPosition = startPosition;
    player.playing = play;
    player.position = startPosition ?? Duration.zero;
  }
}

class _RecordedQualityApi implements TwitchPlaybackApiService {
  final choices = const [
    TwitchM3u8Variant(
      name: '360p',
      resolution: '640x360',
      url: 'https://fixture.invalid/high',
    ),
    TwitchM3u8Variant(
      name: '180p',
      resolution: '320x180',
      url: 'https://fixture.invalid/low',
    ),
  ];
  int resolves = 0;
  @override
  Future<TwitchClipPlaybackResult> resolveClipPlayback({
    required String clipSlug,
    String preferredQuality = 'source',
  }) async {
    resolves++;
    return TwitchClipPlaybackResult(
      playbackUri: Uri.parse(choices.first.url),
      variants: choices,
      selectedVariant: choices.first,
      durationSeconds: 30,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected recorded quality API');
}

class _PortQualityRuntime extends TwitchPlaylistPlayerRuntime {
  _PortQualityRuntime() : super(playbackApi: _RecordedQualityApi());
  @override
  Future<Uri?> startProxyForVariant(TwitchM3u8Variant variant) async =>
      Uri.parse(variant.url);
}

class _GateAuth extends TwitchAuthService {
  final gate = Completer<void>();
  int loads = 0;
  bool failInitialRead = false;
  bool persistentFailure = false;
  _GateAuth(TwitchApiClient client) : super(apiClient: client);
  @override
  String? get accessToken => null;
  @override
  Future<void> loadStoredSession({bool refreshIfNeeded = true}) {
    loads++;
    if (failInitialRead && loads > 1 && !persistentFailure) {
      return Future<void>.value();
    }
    return gate.future;
  }

  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async =>
      null;
}

class _NoStorageDrops extends TwitchDropsAuthService {
  int loads = 0;
  _NoStorageDrops(TwitchApiClient client) : super(apiClient: client);
  @override
  Future<void> loadStoredSession() async {
    loads++;
  }

  @override
  Future<String?> getToken() async => null;
}

class _NoStorageWeb extends TwitchWebGqlAuthService {
  int loads = 0;
  _NoStorageWeb(TwitchApiClient client) : super(apiClient: client);
  @override
  Future<void> loadStoredSession({
    bool migrateLegacyDropsWebToken = true,
  }) async {
    loads++;
  }

  @override
  Future<String?> getToken() async => null;
}

class _SpecialRuntime implements TwitchViewerSpecialMessageRuntimeStage251 {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpecialServices implements TwitchWatchSpecialMessageServicesStage251 {
  _SpecialServices({TwitchViewerSpecialMessageRuntimeStage251? suppliedRuntime})
    : runtime = suppliedRuntime ?? _SpecialRuntime();
  @override
  final TwitchViewerSpecialMessageRuntimeStage251 runtime;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MountServices extends _Services {
  _MountServices({_GateAuth? sharedAuth}) : _suppliedAuth = sharedAuth;
  final _GateAuth? _suppliedAuth;
  @override
  final chat = TwitchWatchChatServices(
    chatStartupApi: _StartupApi(),
    recentMessagesApi: _UnusedRecent(),
  );
  @override
  final TwitchPlaylistPlayerRuntime playerRuntime = TwitchPlaylistPlayerRuntime(
    playbackApi: _UnusedPlayback(),
  );
  @override
  late final _GateAuth authService = _suppliedAuth ?? _GateAuth(apiClient);
  @override
  late final _NoStorageDrops dropsAuthService = _NoStorageDrops(apiClient);
  @override
  late final _NoStorageWeb webGqlAuthService = _NoStorageWeb(apiClient);
  @override
  late final player = TwitchWatchPlayerServices(
    playbackApi: _UnusedPlayback(),
    playerRuntime: playerRuntime,
    playerSession: playerSession,
  );
  @override
  late final emotes = TwitchWatchEmoteServices(
    thirdPartyEmotes: TwitchThirdPartyEmoteCacheService(
      api: TwitchThirdPartyEmoteApiService(client: apiClient),
    ),
    officialEmotes: TwitchOfficialEmoteCacheService(
      api: TwitchOfficialEmoteApiService(client: apiClient),
      accessTokenProvider: () async => null,
      clientIdProvider: () async => 'fixture-client',
    ),
  );
  @override
  final specialMessagesStage251 = _SpecialServices();
}

class _UnusedRecent implements TwitchRecentMessagesApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedAuth extends _GateAuth {
  _SignedAuth(super.client);
  String? currentToken = 'fixture-token';
  @override
  String? get accessToken => currentToken;
  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async =>
      currentToken;
  void logoutFixture() {
    currentToken = null;
    notifyListeners();
  }

  void switchFixture() {
    currentToken = 'fixture-replacement-token';
    notifyListeners();
  }
}

class _SignedValidation extends TwitchAuthApiService {
  final List<String> scopes;
  Completer<void>? validationGate;
  String viewerUserId = '42';
  String viewerLogin = 'fixture-viewer';
  _SignedValidation(TwitchApiClient client, this.scopes)
    : super(client: client);
  @override
  Future<TwitchTokenValidation> validateToken(String accessToken) async {
    await validationGate?.future;
    return TwitchTokenValidation(
      clientId: 'fixture-client',
      login: viewerLogin,
      userId: viewerUserId,
      scopes: scopes,
      expiresIn: 3600,
    );
  }
}

class _SendMountServices extends _MountServices {
  @override
  TwitchThirdPartyEmoteCacheService get thirdPartyEmotes =>
      emotes.thirdPartyEmotes;
  @override
  TwitchOfficialEmoteCacheService get officialEmotes => emotes.officialEmotes;
  final List<String> scopes;
  _SendMountServices({
    this.scopes = const ['chat:read', 'chat:edit'],
    TwitchViewerSpecialMessageRuntimeStage251? specialRuntime,
    TwitchChannelPointsRuntimeService? pointsRuntime,
  }) : specialMessagesStage251 = _SpecialServices(
         suppliedRuntime: specialRuntime,
       ),
       engagement = pointsRuntime == null
           ? _EngagementServices()
           : _PagePointsServices(pointsRuntime);
  @override
  final TwitchWatchEngagementServices engagement;
  @override
  final _SpecialServices specialMessagesStage251;
  @override
  late final _SignedAuth authService = _SignedAuth(apiClient)..gate.complete();
  @override
  late final _SignedValidation authApi = _SignedValidation(apiClient, scopes);
}

class _SignedRouteServices extends _SendMountServices {
  _SignedRouteServices(this.authService, this.authApi);
  @override
  final _SignedAuth authService;
  @override
  final _SignedValidation authApi;
}

// Test-only identity and complete route dependencies; no stored credentials.
class IsolatedSignedRouteFixture {
  IsolatedSignedRouteFixture() {
    _identityClient.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method != 'GET') writes++;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'client_id': 'fixture-client',
                'user_id': '42',
                'login': 'fixture-viewer',
                'scopes': ['user:read:follows', 'chat:read', 'chat:edit'],
                'expires_in': 3600,
              },
            ),
          );
        },
      ),
    );
  }
  final _identityClient = TwitchApiClient();
  late final _SignedAuth _identity = _SignedAuth(_identityClient)
    ..gate.complete();
  late final _SignedValidation _validation = _SignedValidation(
    _identityClient,
    ['user:read:follows', 'chat:read', 'chat:edit'],
  );
  final _services = <_SignedRouteServices>[];
  final _chats = <_SendableChat>[];
  TwitchAuthService get authService => _identity;
  TwitchAuthApiService get authApi => _validation;
  int get createdCount => _services.length;
  int get chatConnects =>
      _chats.fold(0, (count, chat) => count + chat.connects);
  int get chatDisposals =>
      _chats.fold(0, (count, chat) => count + chat.runtimeDisposals);
  int get sends => _chats.fold(0, (count, chat) => count + chat.sends);
  int writes = 0;
  TwitchChatRuntime createChat({required bool authenticated}) {
    expectSync(authenticated, true);
    final chat = _SendableChat();
    _chats.add(chat);
    return chat;
  }

  TwitchWatchServices createServices() {
    final services = _SignedRouteServices(_identity, _validation);
    services.apiClient.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method != 'GET' && !options.path.contains('gql')) {
            writes++;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: options.path.contains('gql')
                  ? {
                      'data': {
                        'user': {
                          'id': '7',
                          'login': 'fixture_follow',
                          'stream': null,
                        },
                      },
                    }
                  : {'data': []},
            ),
          );
        },
      ),
    );
    _services.add(services);
    return services;
  }

  void close() {
    for (final services in _services) {
      services.apiClient.close(force: true);
    }
    for (final chat in _chats) {
      chat.dispose();
    }
    _identityClient.close(force: true);
  }
}

class _SendableSpecial extends _SpecialRuntime {
  int sends = 0;
  final gate = Completer<TwitchViewerSpecialMessageSendResultStage251>();
  @override
  Future<TwitchViewerSpecialMessageSendResultStage251> shareWatchStreak({
    required String channelLogin,
    String? channelId,
    String? viewerId,
    required TwitchWatchStreakStatusStage251 status,
    String message = '',
  }) {
    sends++;
    expectSync(message, 'fixture submitted draft');
    expectSync(status.streakCount, 3);
    return gate.future;
  }
}

class _SendableChat extends _OfflineChat {
  @override
  final TwitchIrcApiService ircApi = _IdentityOnlyIrc();
  String? expectedToken = 'fixture-token';
  bool isModerator = false;
  @override
  bool get viewerIsModerator => isModerator;
  int sends = 0;
  String? submitted;
  final gate = Completer<void>();
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #connect) {
      expectSync(invocation.namedArguments[#accessToken], expectedToken);
      _channelLogin = invocation.namedArguments[#channelLogin] as String;
      connects++;
      return Future<void>.value();
    }
    if (invocation.memberName == #sendMessage) {
      sends++;
      submitted = invocation.positionalArguments.single as String;
      return gate.future;
    }
    return super.noSuchMethod(invocation);
  }
}

class _ProfileEntryChat extends _SendableChat {
  final bool guest;
  _ProfileEntryChat(this.guest);
  @override
  final messages = [
    for (final id in ['profile-first', 'profile-second'])
      _profileEntryMessage(id),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (guest && invocation.memberName == #connect) {
      expectSync(invocation.namedArguments[#accessToken], isNull);
      _channelLogin = invocation.namedArguments[#channelLogin] as String;
      connects++;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

TwitchChatRuntimeMessage _profileEntryMessage(String id) {
  final raw = TwitchChatMessage(
    raw: '',
    command: 'PRIVMSG',
    channel: 'fixture',
    userLogin: 'profilepeer',
    displayName: 'profilepeer',
    message: 'fixture profile body',
    tags: {'id': id, 'user-id': '30', 'room-id': '7'},
  );
  return TwitchChatRuntimeMessage(
    source: raw,
    resolvedBadges: const [],
    receivedAt: DateTime.utc(2026),
    fragments: const [],
    segments: const [],
    metadata: TwitchChatMessageMetadata.fromMessage(raw),
  );
}

class _RecoverableChat extends _SendableChat {
  bool ready = true;
  bool failRecovery = false;
  bool throwsRecovery = false;
  Object? recoveryError;
  int reconnects = 0;
  final recoveryGate = Completer<void>();
  @override
  bool get connected => ready;
  @override
  Object? get error => recoveryError;
  @override
  Future<void> reconnect() async {
    reconnects++;
    await recoveryGate.future;
    recoveryError = failRecovery
        ? StateError('fixture recovery failure')
        : null;
    if (recoveryError != null) {
      if (throwsRecovery) throw recoveryError!;
      notifyListeners();
      return;
    }
    ready = true;
    notifyListeners();
  }
}

class _StartupApi implements TwitchChatStartupApiService {
  @override
  Future<TwitchChatStartupSnapshot> fetchParsedStartupSnapshot({
    required String channelLogin,
    bool includeMessageHistory = true,
  }) async => TwitchChatStartupSnapshot(
    channelLogin: channelLogin,
    channelId: '7',
    badgeCatalog: const TwitchBadgeCatalog(),
    operations: const [],
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OfflineChat extends ChangeNotifier implements TwitchChatRuntime {
  int connects = 0;
  int disconnects = 0;
  int runtimeDisposals = 0;
  String? _channelLogin;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #sendRejections) {
      return const Stream<TwitchChatSendRejection>.empty();
    }
    if (invocation.memberName == #connected) return connects > 0;
    if (invocation.memberName == #channelLogin) return _channelLogin;
    if (invocation.memberName == #connecting) return false;
    if (invocation.memberName == #error) return null;
    if (invocation.memberName == #messages) return <TwitchChatRuntimeMessage>[];
    if (invocation.memberName == #roomState) {
      return TwitchChatRoomState.fromTags({});
    }
    if (invocation.memberName == #viewerIsModerator ||
        invocation.memberName == #viewerIsVip ||
        invocation.memberName == #viewerIsSubscriber) {
      return false;
    }
    if (invocation.memberName == #connect) {
      expectSync(invocation.namedArguments[#accessToken], isNull);
      _channelLogin = invocation.namedArguments[#channelLogin] as String;
      connects++;
      return Future<void>.value();
    }
    if (invocation.memberName == #disconnect ||
        invocation.memberName == #disposeRuntime) {
      if (invocation.memberName == #disconnect) disconnects++;
      if (invocation.memberName == #disposeRuntime) runtimeDisposals++;
      return Future<void>.value();
    }
    if (invocation.memberName == #applyStartupSupplement) return null;
    return super.noSuchMethod(invocation);
  }
}

class _PlayerServices implements TwitchWatchPlayerServices {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChatServices implements TwitchWatchChatServices {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmoteServices implements TwitchWatchEmoteServices {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EngagementServices implements TwitchWatchEngagementServices {
  @override
  final hypeTrainApi = _UnusedHypeTrain();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedHypeTrain implements TwitchHypeTrainApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RelationshipServices implements TwitchWatchRelationshipServices {
  @override
  final subscribeApi = const TwitchSubscribeApiServiceV1();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Services implements TwitchWatchServices {
  @override
  final TwitchApiClient apiClient = TwitchApiClient();
  @override
  late final authService = TwitchAuthService(apiClient: apiClient);
  @override
  late final dropsAuthService = TwitchDropsAuthService(apiClient: apiClient);
  @override
  late final webGqlAuthService = TwitchWebGqlAuthService(apiClient: apiClient);
  @override
  late final authApi = TwitchAuthApiService(client: apiClient);
  @override
  late final recentMessagesApi = TwitchRecentMessagesApiService(
    client: apiClient,
  );
  @override
  final TwitchMediaKitPlayerSession playerSession = _PlayerSession();
  @override
  final playerRuntime = _Runtime();
  @override
  final player = _PlayerServices();
  @override
  final chat = _ChatServices();
  @override
  final emotes = _EmoteServices();
  @override
  final engagement = _EngagementServices();
  @override
  final relationship = _RelationshipServices();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PlaybackMountServices extends _MountServices {
  final _reportedIncompleteMembers = <Symbol>{};
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (_reportedIncompleteMembers.add(invocation.memberName)) {
      // Only dependency member names, never arguments, tokens or error text.
      debugPrint(
        '[LocalAV] incomplete fixture dependency member=${invocation.memberName}',
      );
    }
    return super.noSuchMethod(invocation);
  }

  @override
  TwitchThirdPartyEmoteCacheService get thirdPartyEmotes =>
      emotes.thirdPartyEmotes;
  @override
  TwitchOfficialEmoteCacheService get officialEmotes => emotes.officialEmotes;
  _PlaybackMountServices(
    this.playerSession,
    this.playerRuntime, {
    TwitchPlaybackApiService? api,
    super.sharedAuth,
  }) : playbackApi = api ?? _UnusedPlayback();
  @override
  final TwitchPlaybackApiService playbackApi;
  @override
  late final player = TwitchWatchPlayerServices(
    playbackApi: playbackApi,
    playerRuntime: playerRuntime,
    playerSession: playerSession,
  );
  @override
  final TwitchMediaKitPlayerSession playerSession;
  @override
  final TwitchPlaylistPlayerRuntime playerRuntime;
}

class _RecordedPlayback implements TwitchPlaybackApiService {
  _RecordedPlayback({this.vodId = 'fixture-vod', this.clipId = 'fixture-clip'});
  final String vodId;
  final String clipId;
  Completer<void> gate = Completer<void>();
  int vodRequests = 0;
  int clipRequests = 0;
  bool denied = false;

  Future<Never> _fail() async {
    await gate.future;
    if (denied) {
      throw const TwitchPlaybackAuthorizationException(
        'fixture restricted media',
      );
    }
    throw StateError('fixture media temporarily unavailable');
  }

  @override
  Future<TwitchVodPlaybackResult> resolveVodPlaylist({
    required String videoId,
    String preferredQuality = 'source',
  }) {
    expectSync(videoId, vodId);
    vodRequests++;
    return _fail();
  }

  @override
  Future<TwitchClipPlaybackResult> resolveClipPlayback({
    required String clipSlug,
    String preferredQuality = 'source',
  }) {
    expectSync(clipSlug, clipId);
    clipRequests++;
    return _fail();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordedServices extends _MountServices {
  _RecordedServices({super.sharedAuth, _RecordedPlayback? api})
    : playbackApi = api ?? _RecordedPlayback();
  @override
  final _RecordedPlayback playbackApi;
  @override
  late final player = TwitchWatchPlayerServices(
    playbackApi: playbackApi,
    playerRuntime: playerRuntime,
    playerSession: playerSession,
  );
}

// Shared only by controlled tests; all discovery requests and chat are fake.
TwitchWatchServices isolatedWatchPlaybackServices({
  required TwitchMediaKitPlayerSession session,
  required TwitchPlaylistPlayerRuntime runtime,
  TwitchPlaybackApiService? playbackApi,
  TwitchLiveStream? liveStream,
}) {
  final services = _PlaybackMountServices(session, runtime, api: playbackApi);
  services.authService.gate.complete();
  services.apiClient.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        expectSync(
          options.headers.keys.any(
            (key) => key.toLowerCase() == 'authorization',
          ),
          isFalse,
        );
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {
                'user': {
                  'id': liveStream?.userId ?? '7',
                  'login': liveStream?.userLogin ?? 'fixture',
                  'displayName': liveStream?.userName ?? 'Fixture',
                  'stream': {
                    'id': liveStream?.id ?? 'fixture-live-stream',
                    'createdAt':
                        liveStream?.startedAt?.toUtc().toIso8601String() ??
                        '2026-10-12T00:00:00Z',
                    'title': liveStream?.title ?? 'Fixture live',
                  },
                },
              },
            },
          ),
        );
      },
    ),
  );
  return services;
}

// Complete mock services for real home-card routes; each call owns a fresh
// client while sharing only a no-storage guest identity with the home.
class IsolatedRecordedRouteFixture {
  final _identityClient = TwitchApiClient();
  late final _GateAuth _identity = _GateAuth(_identityClient)..gate.complete();
  final List<_RecordedServices> _created = [];
  final List<_PlaybackMountServices> _playbackCreated = [];
  TwitchAuthService get authService => _identity;
  int get createdCount => _created.length;
  int get vodRequests => _created.fold(
    0,
    (sum, services) => sum + services.playbackApi.vodRequests,
  );
  int get clipRequests => _created.fold(
    0,
    (sum, services) => sum + services.playbackApi.clipRequests,
  );

  TwitchWatchServices createServices() {
    final api = _RecordedPlayback(
      vodId: 'selected-vod',
      clipId: 'selected-clip',
    )..gate.complete();
    final services = _RecordedServices(sharedAuth: _identity, api: api);
    services.apiClient.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expectSync(
            options.headers.keys.any(
              (key) => key.toLowerCase() == 'authorization',
            ),
            isFalse,
          );
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'user': {
                    'id': '7',
                    'login': 'public_fixture',
                    'displayName': 'Fixture',
                    'stream': null,
                  },
                },
              },
            ),
          );
        },
      ),
    );
    _created.add(services);
    return services;
  }

  // Explicit opt-in: supplied playback may be real, while identity, discovery
  // supplements, chat and account services remain no-storage mocks.
  TwitchWatchServices createPlaybackServices({
    required TwitchMediaKitPlayerSession session,
    required TwitchPlaylistPlayerRuntime runtime,
    required TwitchPlaybackApiService playbackApi,
    required String channelLogin,
  }) {
    final services = _PlaybackMountServices(
      session,
      runtime,
      api: playbackApi,
      sharedAuth: _identity,
    );
    services.apiClient.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expectSync(
            options.headers.keys.any(
              (key) => key.toLowerCase() == 'authorization',
            ),
            isFalse,
          );
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'user': {
                    'id': '7',
                    'login': channelLogin,
                    'displayName': 'Fixture',
                    'stream': null,
                  },
                },
              },
            ),
          );
        },
      ),
    );
    _playbackCreated.add(services);
    return services;
  }

  void close() {
    for (final services in _playbackCreated) {
      services.apiClient.close(force: true);
    }
    for (final services in _created) {
      services.apiClient.close(force: true);
    }
    _identityClient.close(force: true);
  }
}

TwitchChatRuntime isolatedWatchChatRuntime({required bool authenticated}) {
  expectSync(authenticated, isFalse);
  return _OfflineChat();
}

void main() {
  test('Isolated native playback services expose complete emote handles', () {
    SharedPreferences.setMockInitialValues({});
    final services = isolatedWatchPlaybackServices(
      session: _PlayerSession(),
      runtime: _Runtime(),
    );
    addTearDown(() => services.apiClient.close(force: true));
    expect(services.thirdPartyEmotes, same(services.emotes.thirdPartyEmotes));
    expect(services.officialEmotes, same(services.emotes.officialEmotes));
    expect(
      () => TwitchWatchFeaturePorts.fromServices(services).emotes.clear(),
      returnsNormally,
    );
  });
  for (final mode in ['playing', 'paused', 'absent-play', 'absent-pause']) {
    test(
      'Live quality port preserves existing state or absent-player fallback mode=$mode',
      () async {
        final session = _RecordedQualitySession();
        final runtime = _PortQualityRuntime();
        addTearDown(runtime.dispose);
        if (!mode.startsWith('absent')) {
          session.exposedPlayer = session.player;
          session.player.playing = mode == 'playing';
        }
        final port = TwitchWatchPlayerPort(
          services: TwitchWatchPlayerServices(
            playbackApi: _RecordedQualityApi(),
            playerRuntime: runtime,
            playerSession: session,
          ),
        );
        await port.switchQuality(
          _RecordedQualityApi().choices.last,
          play: mode != 'absent-pause',
        );
        expect(session.opens, 1);
        expect(session.lastPlay, mode == 'playing' || mode == 'absent-play');
      },
    );
  }
  for (final vod in [false, true]) {
    for (final paused in [false, true]) {
      testWidgets(
        '${vod ? 'Ordinary VOD' : 'Recorded clip'} quality preserves playback state paused=$paused',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          debugDefaultTargetPlatformOverride = TargetPlatform.windows;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/connectivity'),
            (_) async => ['none'],
          );
          messenger.setMockMethodCallHandler(
            const MethodChannel(
              'dev.fluttercommunity.plus/connectivity_status',
            ),
            (_) async => null,
          );
          final api = _RecordedQualityApi();
          final player = _RecordedQualitySession();
          final services = isolatedWatchPlaybackServices(
            session: player,
            runtime: TwitchPlaylistPlayerRuntime(playbackApi: api),
            playbackApi: api,
          );
          addTearDown(() => services.apiClient.close(force: true));
          await tester.pumpWidget(
            MaterialApp(
              home: TwitchWatchPage(
                initialChannelLogin: 'fixture',
                initialServices: services,
                initialClip: TwitchChannelClip.fromHelixJson({
                  'id': 'fixture-quality',
                  'broadcaster_id': '7',
                  'broadcaster_name': 'Fixture',
                  'duration': 30,
                  'vod_offset': -1,
                }),
                initialChatRuntimeFactory: isolatedWatchChatRuntime,
              ),
            ),
          );
          for (var i = 0; i < 25; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final state = tester.state<TwitchWatchPageState>(
            find.byType(TwitchWatchPage),
          );
          expect(api.resolves, 1);
          expect(player.opens, 1);
          expect(state.currentClipQualityClip?.id, 'fixture-quality');
          if (vod) {
            // Seed the ordinary VOD method's current-media contract, without
            // claiming a VOD startup/replay-chat or native-player verification.
            state.currentClipQualityClip = null;
            state.currentVodQualityVideo = TwitchChannelVideo.fromHelixJson({
              'id': 'fixture-quality-vod',
              'user_id': '7',
              'user_name': 'Fixture',
              'duration': '30s',
              'type': 'highlight',
            });
          }
          player.player.position = const Duration(seconds: 7);
          player.player.playing = !paused;
          await state.switchVodQuality(api.choices.last);
          expect(player.opens, 2);
          expect(player.lastPosition, const Duration(seconds: 7));
          expect(player.lastPlay, !paused);
          expect(player.player.state.playing, !paused);
          expect(state.currentVodQualityVariant, api.choices.last);
          expect(state.playerError, isNull);
          expect(api.resolves, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 200));
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }
  }
  testWidgets(
    'Isolated AV composition reaches clip loader without native player',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (_) async => ['none'],
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
        (_) async => null,
      );
      final api = _RecordedPlayback(clipId: 'fixture-local-av');
      final runtime = TwitchPlaylistPlayerRuntime(playbackApi: api);
      final services = isolatedWatchPlaybackServices(
        session: _PlayerSession(),
        runtime: runtime,
        playbackApi: api,
      );
      addTearDown(() => services.apiClient.close(force: true));
      await tester.pumpWidget(
        MaterialApp(
          home: TwitchWatchRouteGuard(
            initialChannelLogin: 'fixture',
            initialServices: services,
            initialClip: TwitchChannelClip.fromHelixJson({
              'id': 'fixture-local-av',
              'broadcaster_id': '7',
              'broadcaster_name': 'Fixture',
              'title': 'Local AV fixture',
              'duration': 30,
              'vod_offset': -1,
            }),
            initialChatRuntimeFactory: isolatedWatchChatRuntime,
          ),
        ),
      );
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final state = tester.state<TwitchWatchPageState>(
        find.byType(TwitchWatchPage),
      );
      // Unlike loadWatch's fallback, this explicit preflight preserves the exact
      // exception/stack if session reset fails before the media API is reached.
      await tester.runAsync(
        () => state
            .stopCurrentSession(clearStatus: false, cancelDeferredTasks: false)
            .timeout(const Duration(seconds: 2)),
      );
      expect(state.viewerId, isNull);
      expect(api.clipRequests, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.gate.complete();
      await tester.pump(const Duration(milliseconds: 200));
      debugDefaultTargetPlatformOverride = null;
    },
  );
  for (final size in [const Size(1000, 760), const Size(390, 844)]) {
    for (final scenario in ['guest', 'signed', 'retry']) {
      testWidgets(
        'Watch profile actual name entry scenario=$scenario size=$size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          debugDefaultTargetPlatformOverride = TargetPlatform.windows;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          SharedPreferences.setMockInitialValues({});
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/connectivity'),
            (_) async => ['none'],
          );
          messenger.setMockMethodCallHandler(
            const MethodChannel(
              'dev.fluttercommunity.plus/connectivity_status',
            ),
            (_) async => null,
          );
          final services = _SendMountServices();
          final guest = scenario == 'guest';
          if (guest) services.authService.currentToken = null;
          final chat = _ProfileEntryChat(guest);
          addTearDown(() => services.apiClient.close(force: true));
          addTearDown(chat.dispose);
          var profileReads = 0;
          var validations = 0;
          var writes = 0;
          var failProfile = scenario == 'retry';
          services.apiClient.dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.method != 'GET' && !options.path.contains('gql')) {
                  writes++;
                }
                Object data = {'data': []};
                if (options.path.endsWith('/validate')) {
                  validations++;
                  data = {
                    'client_id': 'fixture-client',
                    'user_id': '42',
                    'login': 'fixture-viewer',
                    'scopes': [],
                    'expires_in': 3600,
                  };
                } else if (options.path.endsWith('/users')) {
                  profileReads++;
                  expectSync(options.queryParameters['id'], '30');
                  if (failProfile) {
                    handler.reject(
                      DioException(
                        requestOptions: options,
                        response: Response<dynamic>(
                          requestOptions: options,
                          statusCode: 503,
                        ),
                        type: DioExceptionType.badResponse,
                      ),
                    );
                    return;
                  }
                  data = {
                    'data': [
                      {
                        'id': '30',
                        'login': 'profilepeer',
                        'display_name': 'Profile official',
                        'description': 'Fixture official bio',
                      },
                    ],
                  };
                } else if (options.path.contains('gql')) {
                  data = {
                    'data': {
                      'user': {'id': '7', 'login': 'fixture', 'stream': null},
                    },
                  };
                }
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: data,
                  ),
                );
              },
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: TwitchWatchPage(
                initialChannelLogin: 'fixture',
                initialServices: services,
                initialChatRuntimeFactory: ({required authenticated}) => chat,
              ),
            ),
          );
          for (var i = 0; i < 25; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final state = tester.state<TwitchWatchPageState>(
            find.byType(TwitchWatchPage),
          );
          expect(state.viewerId, guest ? isNull : '42');
          final author = find
              .byType(RichText)
              .evaluate()
              .where(
                (element) => (element.widget as RichText).text
                    .toPlainText()
                    .startsWith('profilepeer:'),
              )
              .first;
          final paragraph = author.renderObject! as RenderParagraph;
          final nameBox = paragraph
              .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 11),
              )
              .first;
          await tester.tapAt(paragraph.localToGlobal(nameBox.toRect().center));
          await tester.pumpAndSettle();
          final card = find.byType(TwitchChatUserProfileCard);
          expect(card, findsOneWidget);
          expect(find.text('@profilepeer'), findsOneWidget);
          if (guest) {
            expect(find.text('請先登入 Twitch 載入官方使用者資料。'), findsOneWidget);
            expect(profileReads, 0);
            expect(validations, 0);
          } else {
            if (failProfile) {
              expect(find.textContaining('官方使用者資料暫時'), findsOneWidget);
              failProfile = false;
              await tester.tap(find.text('重試'));
              await tester.pumpAndSettle();
            }
            expect(find.text('Profile official'), findsOneWidget);
            expect(find.text('Fixture official bio'), findsOneWidget);
            expect(profileReads, scenario == 'retry' ? 2 : 1);
            expect(validations, scenario == 'retry' ? 3 : 2);
          }
          final profileScrollable = find.descendant(
            of: card,
            matching: find.byType(Scrollable),
          );
          await tester.scrollUntilVisible(
            find.descendant(of: card, matching: find.text('悄悄話')),
            120,
            scrollable: profileScrollable,
          );
          final whisper = tester.widget<OutlinedButton>(
            find.descendant(of: card, matching: find.byType(OutlinedButton)),
          );
          expect(whisper.onPressed == null, guest);
          await tester.scrollUntilVisible(
            find.text('聊天紀錄'),
            120,
            scrollable: profileScrollable,
          );
          await tester.tap(find.text('聊天紀錄'));
          await tester.pumpAndSettle();
          expect(find.textContaining('本機聊天紀錄'), findsNothing);
          await tester.scrollUntilVisible(
            find.descendant(of: card, matching: find.byTooltip('關閉')),
            -120,
            scrollable: profileScrollable,
          );
          await tester.tap(
            find.descendant(of: card, matching: find.byTooltip('關閉')),
          );
          await tester.pumpAndSettle();
          expect(card, findsNothing);
          expect(
            tester.state<TwitchWatchPageState>(find.byType(TwitchWatchPage)),
            same(state),
          );
          expect(state.channelLogin, 'fixture');
          expect(chat.connects, 1);
          expect(chat.sends, 0);
          expect(writes, 0);
          expect(find.byType(TwitchLinkedLoginPage), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 3));
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }
  }
  for (final size in [const Size(1000, 760), const Size(390, 844)]) {
    for (final scopes in [
      const <String>[],
      const ['chat:edit'],
      const ['chat:read'],
    ]) {
      testWidgets(
        'Signed missing chat scopes reauthorization entry scopes=$scopes size=$size',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          debugDefaultTargetPlatformOverride = TargetPlatform.windows;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/connectivity'),
            (_) async => ['none'],
          );
          messenger.setMockMethodCallHandler(
            const MethodChannel(
              'dev.fluttercommunity.plus/connectivity_status',
            ),
            (_) async => null,
          );
          final services = _SendMountServices(scopes: scopes);
          addTearDown(() => services.apiClient.close(force: true));
          final chat = _SendableChat()
            ..expectedToken = scopes.contains('chat:read')
                ? 'fixture-token'
                : null;
          var writes = 0;
          services.apiClient.dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.method != 'GET' &&
                    (!options.path.contains('gql') ||
                        options.data.toString().contains('mutation'))) {
                  writes++;
                }
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: options.path.contains('gql')
                        ? {
                            'data': {
                              'user': {
                                'id': '7',
                                'login': 'fixture',
                                'displayName': 'Fixture',
                                'stream': null,
                              },
                            },
                          }
                        : {'data': []},
                  ),
                );
              },
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: TwitchWatchPage(
                initialChannelLogin: 'fixture',
                initialServices: services,
                initialChatRuntimeFactory: ({required authenticated}) {
                  expectSync(authenticated, scopes.contains('chat:read'));
                  return chat;
                },
              ),
            ),
          );
          for (var i = 0; i < 25; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final state = tester.state<TwitchWatchPageState>(
            find.byType(TwitchWatchPage),
          );
          expect(state.viewerId, '42');
          expect(state.loadingAuth, false);
          expect(state.chatController.isReadOnlyGuest, false);
          expect(state.chatController.canSendForCurrentViewer, false);
          expect(chat.connects, 1);
          expect(find.text('已登入，但缺少聊天室發言權限。請重新授權後再發言。'), findsOneWidget);
          expect(find.byIcon(Icons.send_rounded), findsNothing);
          expect(find.text('訪客模式可讀取聊天室；登入後才能發言與使用點數。'), findsNothing);
          state.messageController.text = 'fixture scope draft';
          await tester.tap(find.text('重新授權').hitTestable());
          await tester.pumpAndSettle();
          expect(find.byType(TwitchLinkedLoginPage), findsOneWidget);
          final login = tester.widget<TwitchLinkedLoginPage>(
            find.byType(TwitchLinkedLoginPage),
          );
          expect(login.mainAuthService, same(services.authService));
          expect(login.webGqlAuthService, same(services.webGqlAuthService));
          expect(login.dropsAuthService, same(services.dropsAuthService));
          Navigator.of(
            tester.element(find.byType(TwitchLinkedLoginPage)),
          ).pop();
          await tester.pumpAndSettle();
          expect(
            tester.state<TwitchWatchPageState>(find.byType(TwitchWatchPage)),
            same(state),
          );
          expect(state.viewerId, '42');
          expect(state.channelLogin, 'fixture');
          expect(state.messageController.text, 'fixture scope draft');
          expect(state.chatController.isReadOnlyGuest, false);
          expect(state.chatController.canSendForCurrentViewer, false);
          expect(chat.sends, 0);
          expect(writes, 0);
          expect(find.byType(TwitchLinkedLoginPage), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 3));
          chat.dispose();
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }
  }
  for (final size in [const Size(1000, 760), const Size(390, 844)]) {
    for (final change in ['logout', 'switch']) {
      testWidgets(
        'Watch subscribe entry rejects changed identity change=$change size=$size',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          debugDefaultTargetPlatformOverride = TargetPlatform.windows;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/connectivity'),
            (_) async => ['none'],
          );
          messenger.setMockMethodCallHandler(
            const MethodChannel(
              'dev.fluttercommunity.plus/connectivity_status',
            ),
            (_) async => null,
          );
          final services = _SendMountServices();
          addTearDown(() => services.apiClient.close(force: true));
          final chats = <_OfflineChat>[];
          var writes = 0;
          services.apiClient.dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.method != 'GET' &&
                    (!options.path.contains('gql') ||
                        options.data.toString().contains('mutation'))) {
                  writes++;
                }
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: options.path.contains('gql')
                        ? {
                            'data': {
                              'user': {
                                'id': '7',
                                'login': 'fixture',
                                'displayName': 'Fixture',
                                'stream': null,
                              },
                            },
                          }
                        : {'data': []},
                  ),
                );
              },
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: TwitchWatchPage(
                initialChannelLogin: 'fixture',
                initialServices: services,
                initialChatRuntimeFactory: ({required authenticated}) {
                  final chat = authenticated
                      ? (_SendableChat()
                          ..expectedToken = services.authService.accessToken)
                      : _OfflineChat();
                  chats.add(chat);
                  return chat;
                },
              ),
            ),
          );
          for (var i = 0; i < 25; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final state = tester.state<TwitchWatchPageState>(
            find.byType(TwitchWatchPage),
          );
          expect(state.viewerId, '42');
          await tester.tap(find.byType(SubscribeButton).first);
          if (change == 'logout') {
            services.authService.logoutFixture();
          } else {
            services.authApi.viewerUserId = '84';
            services.authService.switchFixture();
          }
          await tester.pumpAndSettle();
          expect(find.text('登入狀態已變更，請關閉後重新開啟訂閱頁。'), findsOneWidget);
          expect(find.byType(InAppWebView), findsNothing);
          expect(writes, 0);
          await tester.tap(find.byIcon(Icons.close).hitTestable().first);
          await tester.pumpAndSettle();
          expect(
            tester.state<TwitchWatchPageState>(find.byType(TwitchWatchPage)),
            same(state),
          );
          expect(state.channelLogin, 'fixture');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 3));
          for (final chat in chats) {
            chat.dispose();
          }
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }
  }
  // Live-guest clip entry is covered by TWITCH_READONLY_GUEST_CLIP_ENTRY in the
  // independent native test. These no-surface fixtures expose offline controls,
  // where clip creation is intentionally disabled. Do not count an offline tap
  // or a directly invoked callback as live UI entry validation.
  for (final scenario in [
    'follow',
    'unfollow',
    'failure',
    'logout',
    'guest',
    'guest-subscribe',
    'guest-offline-clip',
    'guest-chat',
    'guest-chat-narrow',
    'checking',
    'replace-success',
    'replace-failure',
    'points',
    'points-logout',
    'points-switch',
    'rail',
    'prediction',
  ]) {
    testWidgets('Watch follow button uses isolated API scenario=$scenario', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      if (scenario == 'guest-chat-narrow') {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (_) async => ['none'],
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
        (_) async => null,
      );
      final guestEntry = scenario.startsWith('guest');
      final api = _FollowApi(
        !guestEntry && !['follow', 'checking'].contains(scenario),
      );
      late final _SendMountServices services;
      final points = _PagePointsRuntime(
        () => services.authService.accessToken != null,
        'follow-page-$scenario',
      );
      services = scenario.startsWith('points')
          ? _SendMountServices(pointsRuntime: points)
          : _FollowMountServices(api);
      if (guestEntry) services.authService.currentToken = null;
      if (scenario == 'checking') {
        services.authApi.validationGate = Completer<void>();
      }
      final chat = _SendableChat();
      addTearDown(() => services.apiClient.close(force: true));
      final login = 'follow-page-$scenario';
      final railDiscovery = scenario == 'rail'
          ? _RailDiscovery(services)
          : null;
      final railProbe = _RailRouteProbe();
      var guestWrites = 0;
      services.apiClient.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (guestEntry &&
                options.method != 'GET' &&
                (!options.path.contains('gql') ||
                    options.data.toString().contains('mutation'))) {
              guestWrites++;
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: options.path.contains('gql')
                    ? {
                        'data': {
                          'user': {
                            'id': '7',
                            'login': login,
                            'displayName': 'Fixture',
                            'stream': null,
                          },
                        },
                      }
                    : {'data': []},
              ),
            );
          },
        ),
      );
      final watch = TwitchWatchPage(
        initialChannelLogin: login,
        initialServices: services,
        initialChatRuntimeFactory: ({required authenticated}) => chat,
        initialDiscoveryService: railDiscovery,
      );
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: scenario == 'rail' ? [railProbe] : [],
          home: scenario == 'rail'
              ? Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute<void>(builder: (_) => watch)),
                      child: const Text('fixture watch open'),
                    ),
                  ),
                )
              : watch,
        ),
      );
      if (scenario == 'rail') {
        await tester.tap(find.text('fixture watch open'));
        await tester.pump();
      }
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final state = tester.state<TwitchWatchPageState>(
        find.byType(TwitchWatchPage),
      );
      if (scenario == 'prediction') {
        final prediction = TwitchPredictionSnapshot(
          id: 'fixture-watch-prediction',
          title: 'Fixture watch prediction',
          status: 'ACTIVE',
          locksAt: DateTime.now().add(const Duration(minutes: 5)),
          totalPoints: 0,
          totalUsers: 0,
          outcomes: const [
            TwitchPredictionOutcome(
              id: 'fixture-choice',
              title: 'Fixture choice',
              color: 'BLUE',
              points: 0,
              users: 0,
              isWinner: false,
            ),
          ],
        );
        TwitchPredictionHermesRealtimeBus.publishPrediction(prediction);
        await tester.pump();
        await tester.pump();
        expect(find.byType(TwitchPredictionBanner), findsOneWidget);
        await tester.tap(find.byType(TwitchPredictionBanner));
        await tester.pumpAndSettle();
        expect(find.byType(TwitchPredictionBetSheet), findsOneWidget);
        expect(
          tester
              .widget<TwitchPredictionBetSheet>(
                find.byType(TwitchPredictionBetSheet),
              )
              .prediction
              .id,
          'fixture-watch-prediction',
        );
        expect(api.calls, isEmpty);
        expect(chat.sends, 0);
        // The prediction sheet closes through the modal barrier, not a header button.
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
        expect(find.byType(TwitchPredictionBetSheet), findsNothing);
        expect(state.channelLogin, login);
        expect(state.chatController.runtime, same(chat));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
        chat.dispose();
        debugDefaultTargetPlatformOverride = null;
        return;
      }
      if (scenario == 'rail') {
        expect(chat.connects, 1);
        await tester.tap(find.byKey(const ValueKey('live-rail-8')));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(railProbe.replacement, isNotNull);
        final route = railProbe.replacement! as PageRouteBuilder<void>;
        final target =
            route.pageBuilder(
                  tester.element(find.text('fixture watch open')),
                  const AlwaysStoppedAnimation<double>(1),
                  const AlwaysStoppedAnimation<double>(0),
                )
                as TwitchWatchRouteGuard;
        expect(target.initialMetadata.channelLogin, 'fixture_rail_peer');
        expect(target.initialMetadata.streamId, 'fixture-rail-stream');
        expect(target.initialMetadata.streamTitle, 'Fixture rail title');
        expect(target.initialDiscoveryService, same(railDiscovery));
        expect(target.initialKnownFollowing, true);
        expect(chat.disconnects, 1);
        expect(find.byType(TwitchWatchPage), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        // The fixture's real Hermes dial has a finite 15-second handshake
        // deadline. Let that cancelled route's deadline settle in fake time.
        await tester.pump(const Duration(seconds: 16));
        chat.dispose();
        debugDefaultTargetPlatformOverride = null;
        return;
      }
      if (scenario.startsWith('points')) {
        expect(state.channelPointsSnapshot?.balance, 10);
        await tester.tap(find.byTooltip('忠誠點數 10'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ChannelPointsRewardTile));
        await tester.pumpAndSettle();
        if (scenario == 'points-logout') {
          services.authService.logoutFixture();
          for (var i = 0; i < 25; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(state.chatController.isReadOnlyGuest, true);
        }
        if (scenario == 'points-switch') {
          services.authApi.viewerUserId = '84';
          services.authApi.viewerLogin = 'fixture-replacement';
          services.authService.switchFixture();
          await TwitchViewerSession.forAuth(
            services.authService,
          ).resolve(services.authApi);
          for (var i = 0; i < 25; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(state.viewerId, '84');
          expect(state.channelPointsSnapshot?.balance, 10);
          expect(state.channelPointsSnapshot?.channelId, '7');
          expect(state.chatController.isReadOnlyGuest, false);
        }
        await tester.tap(find.widgetWithText(ElevatedButton, '立即兌換'));
        await tester.pumpAndSettle();
        expect(points.redeems, scenario == 'points' ? 1 : 0);
        expect(
          find.text('兌換完成'),
          scenario == 'points' ? findsOneWidget : findsNothing,
        );
        if (scenario == 'points-switch') {
          Navigator.of(
            tester.element(find.byType(ChannelPointsRewardDetailPane)),
          ).pop();
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('忠誠點數 10'));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(ChannelPointsRewardTile));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ElevatedButton, '立即兌換'));
          await tester.pumpAndSettle();
          expect(points.redeems, 1);
          expect(find.text('兌換完成'), findsOneWidget);
          expect(state.viewerId, '84');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
        chat.dispose();
        debugDefaultTargetPlatformOverride = null;
        return;
      }
      if (scenario == 'checking') {
        expect(state.loadingAuth, true);
        final area = tester.widget<TwitchWatchPlayerAreaPortAdapter>(
          find.byType(TwitchWatchPlayerAreaPortAdapter),
        );
        expect(area.onToggleFollow, isNull);
        expect(area.onSubscribe, isNull);
        expect(area.onCreateClip, isNull);
        expect(api.calls, isEmpty);
        expect(find.byType(TwitchLinkedLoginPage), findsNothing);
        services.authApi.validationGate!.complete();
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(state.loadingAuth, false);
        expect(state.viewerId, '42');
      }
      final button = find.byType(FollowButton).first;
      final chatEntry = scenario.startsWith('guest-chat');
      if (chatEntry) {
        state.messageController.text = 'fixture retained guest draft';
        expect(state.chatController.isReadOnlyGuest, true);
        expect(state.chatController.canSendForCurrentViewer, false);
        expect(find.byIcon(Icons.send_rounded), findsNothing);
      } else {
        expect(tester.widget<FollowButton>(button).followed, api.following);
        expect(tester.widget<FollowButton>(button).busy, false);
      }
      if (scenario == 'guest-offline-clip') {
        expect(state.showOfflineChannelPlaceholder, true);
        final clip = find.byType(CreateClipButton).first;
        expect(tester.widget<CreateClipButton>(clip).onPressed, isNull);
        await tester.tap(clip);
        await tester.pumpAndSettle();
        expect(find.byType(TwitchLinkedLoginPage), findsNothing);
        expect(state.viewerId, isNull);
        expect(state.channelLogin, login);
        expect(guestWrites, 0);
        expect(api.calls, isEmpty);
        expect(chat.sends, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 200));
        chat.dispose();
        debugDefaultTargetPlatformOverride = null;
        return;
      }
      final entry = scenario == 'guest-subscribe'
          ? find.byType(SubscribeButton).first
          : chatEntry
          ? find.byIcon(Icons.login_rounded).hitTestable().first
          : button;
      await tester.tap(entry);
      await tester.pump();
      if (guestEntry) {
        await tester.pumpAndSettle();
        expect(guestWrites, 0);
        expect(chat.sends, 0);
        expect(api.calls, isEmpty);
        expect(find.byType(TwitchLinkedLoginPage), findsOneWidget);
        final loginPage = tester.widget<TwitchLinkedLoginPage>(
          find.byType(TwitchLinkedLoginPage),
        );
        expect(loginPage.mainAuthService, same(services.authService));
        expect(loginPage.webGqlAuthService, same(services.webGqlAuthService));
        expect(loginPage.dropsAuthService, same(services.dropsAuthService));
        Navigator.of(tester.element(find.byType(TwitchLinkedLoginPage))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(TwitchLinkedLoginPage), findsNothing);
        expect(find.byType(TwitchWatchPage), findsOneWidget);
        expect(state.channelLogin, login);
        expect(state.viewerId, isNull);
        expect(state.chatController.isReadOnlyGuest, true);
        if (chatEntry) {
          expect(state.messageController.text, 'fixture retained guest draft');
          expect(state.chatController.canSendForCurrentViewer, false);
          expect(find.byIcon(Icons.send_rounded), findsNothing);
          expect(chat.sends, 0);
        }
        expect(api.calls, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 200));
        chat.dispose();
        debugDefaultTargetPlatformOverride = null;
        return;
      }
      expect(api.calls, [api.following ? 'unfollow' : 'follow']);
      expect(tester.widget<FollowButton>(button).busy, true);
      await tester.tap(button);
      expect(api.calls, hasLength(1));
      if (scenario.startsWith('replace-')) {
        final nextApi = _FollowApi(true, channelId: '8');
        final nextServices = _FollowMountServices(nextApi);
        final nextChat = _SendableChat();
        final nextLogin = 'replacement-$scenario';
        addTearDown(() => nextServices.apiClient.close(force: true));
        nextServices.apiClient.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: options.path.contains('gql')
                    ? {
                        'data': {
                          'user': {
                            'id': '8',
                            'login': nextLogin,
                            'displayName': 'Replacement',
                            'stream': null,
                          },
                        },
                      }
                    : {'data': []},
              ),
            ),
          ),
        );
        expect(state.mounted, true);
        if (!state.mounted) return;
        unawaited(
          Navigator.of(state.context).pushReplacement<void, void>(
            MaterialPageRoute<void>(
              builder: (_) => TwitchWatchPage(
                initialChannelLogin: nextLogin,
                initialServices: nextServices,
                initialChatRuntimeFactory: ({required authenticated}) =>
                    nextChat,
              ),
            ),
          ),
        );
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(state.mounted, false);
        final nextState = tester.state<TwitchWatchPageState>(
          find.byType(TwitchWatchPage),
        );
        expect(nextState.channelLogin, nextLogin);
        expect(tester.widget<FollowButton>(button).followed, true);
        if (scenario == 'replace-failure') {
          api.result.completeError(
            StateError('fixture obsolete unfollow failure'),
          );
        } else {
          api.result.complete(api.snapshot(login, false));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<FollowButton>(button).followed, true);
        expect(tester.widget<FollowButton>(button).busy, false);
        expect(nextApi.calls, isEmpty);
        expect(find.text('已取消追隨 $login'), findsNothing);
        expect(find.text('追隨狀態更新失敗，請稍後再試。'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
        chat.dispose();
        nextChat.dispose();
        debugDefaultTargetPlatformOverride = null;
        return;
      }
      if (scenario == 'logout') {
        services.authService.logoutFixture();
        await tester.pump();
      }
      if (scenario == 'failure') {
        api.result.completeError(StateError('fixture follow rejection'));
      } else {
        api.result.complete(api.snapshot(login, !api.following));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      if (scenario == 'logout') {
        expect(state.chatController.isReadOnlyGuest, true);
        expect(find.text('已取消追隨 $login'), findsNothing);
      } else {
        expect(
          tester.widget<FollowButton>(button).followed,
          scenario == 'failure' ? api.following : !api.following,
        );
        expect(tester.widget<FollowButton>(button).busy, false);
        expect(
          find.text(
            scenario == 'failure'
                ? '追隨狀態更新失敗，請稍後再試。'
                : !api.following
                ? '已追隨 $login'
                : '已取消追隨 $login',
          ),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      chat.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  }
  for (final popToRoot in [false, true]) {
    testWidgets(
      'Disabled mini preference returns home without handoff root=$popToRoot',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          TwitchPlayerSettingsController.homeKeepsMiniPlayerPreferenceKey:
              false,
        });
        final services = _SendMountServices();
        final chat = _SendableChat();
        final player = _NavigationPlayer();
        addTearDown(() => services.apiClient.close(force: true));
        addTearDown(() async {
          TwitchMiniPlayerController.instance.close(pausePlayback: false);
          TwitchPlaybackSessionController.instance.clear();
          await TwitchMediaKitPlayerHost.disposeNow();
          chat.dispose();
        });
        services.apiClient.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: options.path.contains('gql')
                      ? {
                          'data': {
                            'user': {
                              'id': '7',
                              'login': 'fixture',
                              'stream': null,
                            },
                          },
                        }
                      : {'data': []},
                ),
              );
            },
          ),
        );
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (_) async => ['none'],
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
          (_) async => null,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('fixture home'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TwitchWatchPage(
                        initialChannelLogin: 'fixture',
                        initialServices: services,
                        initialChatRuntimeFactory: ({required authenticated}) =>
                            chat,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('fixture home'));
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final state = tester.state<TwitchWatchPageState>(
          find.byType(TwitchWatchPage),
        );
        TwitchMediaKitPlayerHost.installIsolatedPlayerForTesting(player);
        await TwitchMediaKitPlayerHost.restoreSharedMedia(
          uri: 'https://fixture.invalid/navigation',
        );
        TwitchPlaybackSessionController.instance.restorePlayback(
          const TwitchPlaybackSessionState(
            revision: 1,
            kind: TwitchWatchPlaybackKind.live,
            mediaUri: 'https://fixture.invalid/navigation',
            metadata: TwitchStreamHeaderMetadata(channelLogin: 'fixture'),
          ),
        );
        expect(state.buildPlaybackSnapshot(), isNotNull);
        await state.leaveWatchPageToHome(
          respectMiniPreference: true,
          popToRoot: popToRoot,
        );
        await tester.pumpAndSettle();
        expect(find.byType(TwitchWatchPage), findsNothing);
        expect(find.text('fixture home'), findsOneWidget);
        expect(TwitchMiniPlayerController.instance.isActive, isFalse);
        expect(state.handedOffToMiniPlayer, isFalse);
        expect(TwitchMediaKitPlayerHost.hasKeepAlivePlayback, isFalse);
        expect(player.opens, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final scenario in [
    'ime-success',
    'ime-failure',
    'ime-logout',
    'success',
    'failure',
    'new-draft',
    'logout',
    'unmount',
    'no-permission',
    'moderator-no-chat-edit',
    'moderator-switch',
    'moderator-panel-switch',
    'moderator-panel-channel',
    'recovery-repeat',
    'recovery-checking',
    'recovery-switch',
    'recovery-logout',
    'recovery-failure-return',
    'recovery-failure-throw',
    'recovery-failure-switch',
    'recovery-failure-unmount',
    'special-success',
    'special-failure',
    'special-new-draft',
    'special-logout',
    'special-unmount',
    'special-cancel',
  ]) {
    testWidgets(
      'Signed watch UI sends through production page change=$scenario',
      (tester) async {
        final special = scenario.startsWith('special-');
        final ime = scenario.startsWith('ime-');
        final change = special
            ? scenario.substring('special-'.length)
            : ime
            ? scenario.substring('ime-'.length)
            : scenario;
        final moderator = change.startsWith('moderator-');
        final specialRuntime = _SendableSpecial();
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        SharedPreferences.setMockInitialValues({});
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (_) async => ['none'],
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
          (_) async => null,
        );
        final services = _SendMountServices(
          specialRuntime: special ? specialRuntime : null,
          scopes:
              change == 'no-permission' ||
                  (moderator && !change.startsWith('moderator-panel-'))
              ? const ['chat:read']
              : const ['chat:read', 'chat:edit'],
        );
        final recoveryCase = change.startsWith('recovery-');
        final chat = recoveryCase ? _RecoverableChat() : _SendableChat();
        final nextChat = change == 'recovery-logout'
            ? _OfflineChat()
            : (_SendableChat()..expectedToken = 'fixture-replacement-token');
        var runtimeCreations = 0;
        chat.isModerator = moderator;
        var managementWrites = 0;
        addTearDown(() => services.apiClient.close(force: true));
        services.apiClient.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'DELETE') managementWrites++;
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: options.path.contains('/validate')
                      ? {
                          'client_id': 'fixture-client',
                          'login': services.authApi.viewerLogin,
                          'user_id': services.authApi.viewerUserId,
                          'scopes': services.scopes,
                          'expires_in': 3600,
                        }
                      : options.path.endsWith('/chat/settings')
                      ? {
                          'data': [
                            {
                              'emote_mode': false,
                              'subscriber_mode': false,
                              'follower_mode': false,
                              'slow_mode': false,
                              'unique_chat_mode': false,
                            },
                          ],
                        }
                      : options.path.contains('gql')
                      ? {
                          'data': {
                            'user': {
                              'id': '7',
                              'login': 'fixture',
                              'displayName': 'Fixture',
                              'stream': null,
                            },
                          },
                        }
                      : {'data': []},
                ),
              );
            },
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: TwitchWatchPage(
              initialChannelLogin: 'fixture',
              initialServices: services,
              initialChatRuntimeFactory: ({required authenticated}) {
                expectSync(
                  authenticated,
                  runtimeCreations == 0 || change != 'recovery-logout',
                );
                runtimeCreations++;
                return recoveryCase && runtimeCreations > 1 ? nextChat : chat;
              },
            ),
          ),
        );
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final state = tester.state<TwitchWatchPageState>(
          find.byType(TwitchWatchPage),
        );
        expect(state.viewerId, '42');
        if (recoveryCase) {
          final recovering = chat as _RecoverableChat;
          recovering.ready = false;
          try {
            if (change.startsWith('recovery-failure')) {
              recovering.failRecovery = true;
              recovering.throwsRecovery = change != 'recovery-failure-return';
              final first = state.chatController
                  .reconnectAfterNetworkRestored();
              await tester.pump();
              if (change == 'recovery-failure-switch') {
                services.authApi.viewerUserId = '84';
                services.authApi.viewerLogin = 'fixture-replacement';
                services.authService.switchFixture();
                await TwitchViewerSession.forAuth(
                  services.authService,
                ).resolve(services.authApi);
                await tester.pump();
              } else if (change == 'recovery-failure-unmount') {
                await tester.pumpWidget(const SizedBox());
              }
              recovering.recoveryGate.complete();
              await first;
              await tester.pump();
              final obsolete =
                  change == 'recovery-failure-switch' ||
                  change == 'recovery-failure-unmount';
              expect(
                find.text('聊天室暫時連線失敗，稍後再試。'),
                obsolete ? findsNothing : findsOneWidget,
              );
              if (!obsolete) {
                expect(state.chatController.connectingChat, false);
                expect(recovering.reconnects, 1);
                recovering.failRecovery = false;
                await state.chatController.reconnectAfterNetworkRestored();
                await tester.pump();
                expect(recovering.reconnects, 2);
                expect(state.chatController.connectingChat, false);
                expect(recovering.ready, true);
                await tester.pump(const Duration(seconds: 3));
                await tester.pump(const Duration(milliseconds: 300));
                expect(find.text('聊天室暫時連線失敗，稍後再試。'), findsNothing);
              } else if (change == 'recovery-failure-switch') {
                expect(state.viewerId, '84');
                expect(state.chatController.hasCurrentViewer, false);
              }
            } else if (change == 'recovery-repeat') {
              final first = state.chatController
                  .reconnectAfterNetworkRestored();
              await tester.pump();
              final second = state.chatController
                  .reconnectAfterNetworkRestored();
              expect(recovering.reconnects, 1);
              recovering.recoveryGate.complete();
              await Future.wait([first, second]);
              expect(state.chatController.connectingChat, false);
              expect(state.chatController.hasCurrentViewer, true);
            } else if (change == 'recovery-checking') {
              services.authApi.validationGate = Completer<void>();
              services.authService.switchFixture();
              await tester.pump();
              await state.chatController.reconnectAfterNetworkRestored();
              expect(state.loadingAuth, true);
              expect(recovering.reconnects, 0);
              expect(runtimeCreations, 1);
              expect(state.chatController.canSendForCurrentViewer, false);
              services.authApi.validationGate!.complete();
            } else {
              if (change == 'recovery-logout') {
                services.authService.logoutFixture();
              } else {
                services.authApi.viewerUserId = '84';
                services.authApi.viewerLogin = 'fixture-replacement';
                services.authService.switchFixture();
                await TwitchViewerSession.forAuth(
                  services.authService,
                ).resolve(services.authApi);
              }
              await tester.pump();
              recovering.recoveryGate.complete();
              await tester.runAsync(
                () => state.chatController
                    .reconnectAfterNetworkRestored()
                    .timeout(const Duration(seconds: 2)),
              );
              await tester.pump();
              expect(recovering.reconnects, 0);
              expect(state.chatRuntime, same(nextChat));
              expect(nextChat.connects, 1);
              expect(
                state.chatController.isReadOnlyGuest,
                change == 'recovery-logout',
              );
              expect(
                state.chatController.canSendForCurrentViewer,
                change != 'recovery-logout',
              );
              expect(state.viewerId, change == 'recovery-logout' ? null : '84');
            }
            expect(chat.sends, 0);
            expect(managementWrites, 0);
            expect(tester.takeException(), isNull);
          } finally {
            if (!recovering.recoveryGate.isCompleted) {
              recovering.recoveryGate.complete();
            }
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(milliseconds: 200));
            chat.dispose();
            nextChat.dispose();
            debugDefaultTargetPlatformOverride = null;
          }
          return;
        }
        if (change == 'no-permission' || moderator) {
          try {
            expect(state.chatController.isReadOnlyGuest, isFalse);
            final panelSwitch = change.startsWith('moderator-panel-');
            expect(state.chatController.canSendForCurrentViewer, panelSwitch);
            expect(state.canManageChat, moderator);
            if (!panelSwitch) {
              expect(find.text('已登入，但缺少聊天室發言權限。請重新授權後再發言。'), findsOneWidget);
              expect(find.text('重新授權'), findsOneWidget);
              expect(find.byIcon(Icons.send_rounded), findsNothing);
            }
            expect(chat.sends, 0);
            if (moderator) {
              final moderation = state.createChatModerationApi();
              expect(moderation, isNotNull);
              expect(moderation!.canModerate!(), isTrue);
              if (panelSwitch) {
                await tester.tap(find.byType(TwitchWatchChatIdentityButton));
                await tester.pump(const Duration(milliseconds: 500));
                await tester.pump(const Duration(milliseconds: 400));
                expect(find.text('聊天身分與互動'), findsWidgets);
                await tester.scrollUntilVisible(
                  find.text('管理員與台主工具'),
                  250,
                  scrollable: find
                      .descendant(
                        of: find.byType(ListView).last,
                        matching: find.byType(Scrollable),
                      )
                      .first,
                  maxScrolls: 6,
                );
                await tester.ensureVisible(find.text('管理員與台主工具'));
                await tester.tap(find.text('管理員與台主工具'));
                await tester.pump(const Duration(milliseconds: 500));
                await tester.pump(const Duration(milliseconds: 400));
                final clear = find.text('清除聊天室');
                await tester.ensureVisible(clear);
                await tester.tap(clear);
                await tester.pump(const Duration(milliseconds: 300));
                expect(find.text('確認管理操作'), findsOneWidget);
                TwitchWatchPageState? replacementState;
                if (change == 'moderator-panel-channel') {
                  final nextServices = _FollowMountServices(
                    _FollowApi(true, channelId: '8'),
                  );
                  final nextChat = _SendableChat();
                  addTearDown(() => nextServices.apiClient.close(force: true));
                  addTearDown(nextChat.dispose);
                  nextServices.apiClient.dio.interceptors.add(
                    InterceptorsWrapper(
                      onRequest: (options, handler) {
                        if (options.method == 'DELETE') managementWrites++;
                        handler.resolve(
                          Response<dynamic>(
                            requestOptions: options,
                            statusCode: 200,
                            data: options.path.contains('gql')
                                ? {
                                    'data': {
                                      'user': {
                                        'id': '8',
                                        'login': 'fixture_next',
                                        'displayName': 'Next fixture',
                                        'stream': null,
                                      },
                                    },
                                  }
                                : {'data': []},
                          ),
                        );
                      },
                    ),
                  );
                  // Replace the underlying watch route, leaving its existing
                  // confirmation dialog open. No destination dependency is real.
                  if (!state.mounted) {
                    throw StateError(
                      'Original watch must still be mounted before replacement',
                    );
                  }
                  Navigator.of(state.context).replace(
                    oldRoute: ModalRoute.of(state.context)!,
                    newRoute: MaterialPageRoute<void>(
                      builder: (_) => TwitchWatchPage(
                        initialChannelLogin: 'fixture_next',
                        initialServices: nextServices,
                        initialChatRuntimeFactory: ({required authenticated}) =>
                            nextChat,
                      ),
                    ),
                  );
                  for (var i = 0; i < 25; i++) {
                    await tester.pump(const Duration(milliseconds: 100));
                  }
                  expect(state.mounted, false);
                  replacementState = tester.state<TwitchWatchPageState>(
                    find.byType(TwitchWatchPage),
                  );
                  expect(replacementState.channelLogin, 'fixture_next');
                  expect(replacementState.viewerId, '42');
                  expect(replacementState.chatRuntime, same(nextChat));
                  expect(nextChat.sends, 0);
                  await tester.runAsync(() async {
                    final deadline = DateTime.now().add(
                      const Duration(seconds: 2),
                    );
                    while (chat.runtimeDisposals == 0 &&
                        DateTime.now().isBefore(deadline)) {
                      await Future<void>.delayed(
                        const Duration(milliseconds: 10),
                      );
                    }
                  });
                  expect(chat.runtimeDisposals, 1);
                  expect(state.chatController.runtime, isNull);
                } else {
                  services.authApi.viewerUserId = '84';
                  services.authApi.viewerLogin = 'fixture-replacement';
                  services.authService.switchFixture();
                  await TwitchViewerSession.forAuth(
                    services.authService,
                  ).resolve(services.authApi);
                }
                await tester.pump();
                await tester.tap(find.text('確認'));
                await tester.pump(const Duration(milliseconds: 400));
                expect(managementWrites, 0);
                await tester.scrollUntilVisible(
                  find.text('你沒有這個頻道的管理權限。'),
                  -250,
                  scrollable: find
                      .descendant(
                        of: find.byType(ListView).last,
                        matching: find.byType(Scrollable),
                      )
                      .first,
                  maxScrolls: 6,
                );
                expect(find.text('你沒有這個頻道的管理權限。'), findsOneWidget);
                if (replacementState == null) {
                  expect(state.channelLogin, 'fixture');
                  expect(state.viewerId, '84');
                  expect(state.canManageChat, false);
                }
                expect(moderation.canModerate!(), false);
                Navigator.of(tester.element(clear)).pop();
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 400));
                expect(find.text('清除聊天室'), findsNothing);
                expect((replacementState ?? state).mounted, true);
                expect(
                  (replacementState ?? state).channelLogin,
                  replacementState == null ? 'fixture' : 'fixture_next',
                );
                expect(chat.sends, 0);
                expect(tester.takeException(), isNull);
              } else if (change == 'moderator-switch') {
                services.authApi.viewerUserId = '84';
                services.authApi.viewerLogin = 'fixture-replacement';
                services.authService.switchFixture();
                await TwitchViewerSession.forAuth(
                  services.authService,
                ).resolve(services.authApi);
                await tester.pump();
                expect(state.viewerId, '84');
                expect(chat.isModerator, true);
                expect(state.canManageChat, false);
                expect(state.createChatModerationApi(), isNull);
                expect(moderation.canModerate!(), false);
                await expectLater(
                  moderation.deleteMessages(messageId: 'fixture-message'),
                  throwsA(isA<TwitchModerationException>()),
                );
                expect(managementWrites, 0);
                chat.expectedToken = 'fixture-replacement-token';
                await tester.runAsync(
                  () => state
                      .connectChat(state.channelLogin)
                      .timeout(const Duration(seconds: 2)),
                );
                await tester.pump();
                expect(chat.connects, 2);
                expect(state.chatController.connectingChat, false);
                expect(state.canManageChat, true);
                expect(
                  state.createChatModerationApi()?.canModerate?.call(),
                  true,
                );
                expect(moderation.canModerate!(), false);
                expect(managementWrites, 0);
              } else {
                services.authService.logoutFixture();
                await tester.pump();
                expect(state.canManageChat, isFalse);
                expect(moderation.canModerate!(), isFalse);
              }
            }
          } finally {
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(milliseconds: 200));
            chat.dispose();
            debugDefaultTargetPlatformOverride = null;
          }
          return;
        }
        expect(state.chatController.canSendForCurrentViewer, isTrue);
        expect(find.byType(TwitchChatInputBar), findsOneWidget);
        if (special) {
          state.chatController.setPendingSpecialMessage(
            const TwitchPendingSpecialMessage(
              kind: TwitchPendingSpecialMessageKind.watchStreak,
              channelLogin: 'fixture',
              channelId: '7',
              title: 'fixture',
              subtitle: '',
              payload: {
                'watchStreak': TwitchWatchStreakStatusStage251(
                  channelLogin: 'fixture',
                  streakCount: 3,
                  canShare: true,
                ),
              },
            ),
          );
          if (change == 'cancel') {
            var cancelled = false;
            state.chatController.addListener(() {
              if (!cancelled && state.chatController.sending) {
                cancelled = true;
                state.chatController.clearPendingSpecialMessage();
              }
            });
          }
        }
        state.messageController.text = 'fixture submitted draft';
        await tester.pump();
        if (ime) {
          await tester.tap(
            find
                .descendant(
                  of: find.byType(TwitchChatInputBar),
                  matching: find.byType(ExtendedTextField),
                )
                .first,
          );
          await tester.pump();
          tester.testTextInput.enterText('fixture submitted draft');
          await tester.testTextInput.receiveAction(TextInputAction.send);
        } else {
          await tester.tap(find.byIcon(Icons.send_rounded));
        }
        await tester.pump();
        expect(chat.sends, special ? 0 : 1);
        if (ime) {
          await tester.testTextInput.receiveAction(TextInputAction.send);
          await tester.pump();
          expect(chat.sends, 1);
        }
        if (special) {
          expect(specialRuntime.sends, change == 'cancel' ? 0 : 1);
        } else {
          expect(chat.submitted, 'fixture submitted draft');
        }
        expect(state.sending, change != 'cancel');
        if (change == 'new-draft') {
          state.messageController.text = 'fixture newer draft';
        }
        if (change == 'logout') services.authService.logoutFixture();
        if (change == 'unmount') await tester.pumpWidget(const SizedBox());
        if (special && change != 'cancel') {
          specialRuntime.gate.complete(
            TwitchViewerSpecialMessageSendResultStage251(
              ok: change != 'failure',
              operation: 'shareWatchStreak',
              error: change == 'failure' ? 'fixture special rejection' : null,
            ),
          );
        } else if (!special && change == 'failure') {
          chat.gate.completeError(StateError('fixture send failed'));
        } else if (!special) {
          chat.gate.complete();
        }
        await tester.pump(const Duration(milliseconds: 250));
        if (change != 'unmount') {
          expect(state.sending, isFalse);
          expect(
            state.messageController.text,
            change == 'success'
                ? ''
                : change == 'new-draft'
                ? 'fixture newer draft'
                : 'fixture submitted draft',
          );
        }
        expect(
          find.text('聊天室訊息送出失敗，請稍後再試。'),
          !special && change == 'failure' ? findsOneWidget : findsNothing,
        );
        expect(find.text('fixture send failed'), findsNothing);
        expect(
          find.text('特殊訊息送出失敗，請稍後再試。'),
          special && change == 'failure' ? findsOneWidget : findsNothing,
        );
        expect(find.text('fixture special rejection'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 200));
        chat.dispose();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
  for (final clip in [false, true]) {
    for (final denied in [false, true]) {
      for (final leaveWhilePending in [false, true]) {
        testWidgets(
          'Guest recorded clip=$clip denied=$denied leavePending=$leaveWhilePending',
          (tester) async {
            debugDefaultTargetPlatformOverride = TargetPlatform.windows;
            addTearDown(() => debugDefaultTargetPlatformOverride = null);
            SharedPreferences.setMockInitialValues({});
            final messenger = TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger;
            messenger.setMockMethodCallHandler(
              const MethodChannel('dev.fluttercommunity.plus/connectivity'),
              (_) async => ['none'],
            );
            messenger.setMockMethodCallHandler(
              const MethodChannel(
                'dev.fluttercommunity.plus/connectivity_status',
              ),
              (_) async => null,
            );
            final services = _RecordedServices();
            final api = services.playbackApi..denied = denied;
            final chat = _OfflineChat();
            var requests = 0;
            services.apiClient.dio.interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  requests++;
                  expectSync(
                    options.headers.keys.any(
                      (key) => key.toLowerCase() == 'authorization',
                    ),
                    isFalse,
                  );
                  handler.resolve(
                    Response<dynamic>(
                      requestOptions: options,
                      statusCode: 200,
                      data: {
                        'data': {
                          'user': {
                            'id': '7',
                            'login': 'fixture',
                            'displayName': 'Fixture',
                            'stream': null,
                          },
                        },
                      },
                    ),
                  );
                },
              ),
            );
            addTearDown(() => services.apiClient.close(force: true));
            await tester.pumpWidget(
              MaterialApp(
                home: TwitchWatchRouteGuard(
                  initialChannelLogin: 'fixture',
                  initialServices: services,
                  initialChatRuntimeFactory: ({required authenticated}) {
                    expectSync(authenticated, isFalse);
                    return chat;
                  },
                  initialVodVideo: clip
                      ? null
                      : TwitchChannelVideo.fromHelixJson({
                          'id': 'fixture-vod',
                          'user_id': '7',
                          'user_name': 'Fixture',
                          'duration': '10m',
                          'type': 'highlight',
                        }),
                  initialClip: clip
                      ? TwitchChannelClip.fromHelixJson({
                          'id': 'fixture-clip',
                          'broadcaster_id': '7',
                          'broadcaster_name': 'Fixture',
                          'duration': 20,
                        })
                      : null,
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 500));
            final state = tester.state<TwitchWatchPageState>(
              find.byType(TwitchWatchPage),
            );
            expect(state.loadingAuth, isTrue);
            expect(api.vodRequests + api.clipRequests, 0);
            services.authService.gate.complete();
            for (var i = 0; i < 20; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(state.loadingAuth, isFalse);
            expect(state.viewerId, isNull);
            expect(api.vodRequests, clip ? 0 : 1);
            expect(api.clipRequests, clip ? 1 : 0);
            expect(
              (services.playerSession as _PlayerSession).profileRequests,
              0,
            );
            expect(find.byType(TwitchLinkedLoginPage), findsNothing);
            if (leaveWhilePending) {
              await tester.pumpWidget(const SizedBox.shrink());
            }
            api.gate.complete();
            for (var i = 0; i < 20; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            if (!leaveWhilePending) {
              expect(find.byType(TwitchWatchPage), findsOneWidget);
              expect(state.loadingWatch, isFalse);
              expect(state.chatBootstrapping, isFalse);
              expect(state.relationshipBootstrapping, isFalse);
              expect(state.engagementBootstrapping, isFalse);
              expect(state.emoteBootstrapping, isFalse);
              expect(state.showOfflineChannelPlaceholder, isFalse);
              expect(find.byType(TwitchLinkedLoginPage), findsNothing);
              final beforePoll = api.vodRequests + api.clipRequests;
              await tester.pump(const Duration(seconds: 20));
              expect(
                api.vodRequests + api.clipRequests,
                beforePoll,
                reason: 'Recorded failures must not retry as live playback.',
              );
              api.gate = Completer<void>()..complete();
              await state.loadWatch();
              for (var i = 0; i < 20; i++) {
                await tester.pump(const Duration(milliseconds: 100));
              }
              expect(api.vodRequests, clip ? 0 : 2);
              expect(api.clipRequests, clip ? 2 : 0);
              expect(state.loadingAuth, isFalse);
              expect(state.loadingWatch, isFalse);
              expect(services.authService.loads, 1);
              await tester.pumpWidget(const SizedBox.shrink());
            }
            final beforeDispose = requests;
            await tester.pump(const Duration(seconds: 20));
            expect(requests, beforeDispose);
            expect(
              api.vodRequests,
              clip
                  ? 0
                  : leaveWhilePending
                  ? 1
                  : 2,
            );
            expect(
              api.clipRequests,
              clip
                  ? leaveWhilePending
                        ? 1
                        : 2
                  : 0,
            );
            expect(
              (services.playerSession as _PlayerSession).profileRequests,
              0,
            );
            expect(TwitchMediaKitPlayerHost.playerOrNull, isNull);
            expect(tester.takeException(), isNull);
            debugDefaultTargetPlatformOverride = null;
          },
        );
      }
    }
  }
  for (final mode in [
    (200, false, false, false, false, 0),
    (503, false, false, false, false, 0),
    (200, true, false, false, false, 0),
    (503, true, false, false, false, 0),
    (200, true, true, false, false, 0),
    (200, true, false, true, false, 0),
    (200, true, false, true, true, 0),
    (200, true, false, false, false, 1),
    (200, true, false, false, false, 2),
  ]) {
    final status = mode.$1;
    final completeWhileMounted = mode.$2;
    final liveAvailable = mode.$3;
    final recoverLive = mode.$4;
    final staleOffline = mode.$5;
    final storageFailure = mode.$6 != 0;
    final persistentFailure = mode.$6 == 2;
    testWidgets(
      'Official guest watch lifecycle HTTP=$status startup=$completeWhileMounted live=$liveAvailable recovery=$recoverLive staleOffline=$staleOffline storageFailure=$storageFailure persistent=$persistentFailure',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        SharedPreferences.setMockInitialValues({});
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (_) async => ['none'],
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
          (_) async => null,
        );
        final services = _MountServices();
        services.authService.failInitialRead = storageFailure;
        services.authService.persistentFailure = persistentFailure;
        final chat = _OfflineChat();
        var requests = 0;
        var responseStatus = status;
        var responseLive = liveAvailable;
        var responseStreamId = 'fixture-live-stream';
        var responseStartedAt = '2026-10-12T00:00:00Z';
        Completer<void>? nextLiveResponseGate;
        var liveResponsePaused = false;
        services.apiClient.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              requests++;
              expectSync(
                options.headers.keys.any(
                  (key) => key.toLowerCase() == 'authorization',
                ),
                isFalse,
              );
              final response = Response<dynamic>(
                requestOptions: options,
                statusCode: responseStatus,
                data: {
                  'data': {
                    'user': {
                      'id': '7',
                      'login': 'fixture',
                      'displayName': 'Fixture',
                      'stream': responseLive
                          ? {
                              'id': responseStreamId,
                              'createdAt': responseStartedAt,
                              'title': 'Fixture live',
                            }
                          : null,
                    },
                  },
                },
              );
              final gate = nextLiveResponseGate;
              if (gate != null &&
                  options.data is Map &&
                  (options.data as Map)['operationName'] ==
                      'VioClassGuestLiveChannel') {
                nextLiveResponseGate = null;
                liveResponsePaused = true;
                await gate.future;
              }
              if (responseStatus >= 400) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: response,
                    type: DioExceptionType.badResponse,
                  ),
                );
              } else {
                handler.resolve(response);
              }
            },
          ),
        );
        addTearDown(() => services.apiClient.close(force: true));
        await tester.pumpWidget(
          MaterialApp(
            home: TwitchWatchPage(
              initialChannelLogin: 'fixture',
              initialServices: services,
              initialChatRuntimeFactory: ({required authenticated}) =>
                  completeWhileMounted
                  ? chat
                  : throw StateError(
                      'Unexpected chat before storage completes',
                    ),
            ),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
        expect(find.byType(TwitchWatchPage), findsOneWidget);
        final state = tester.state<TwitchWatchPageState>(
          find.byType(TwitchWatchPage),
        );
        expect(services.authService.loads, 1);
        expect(state.viewerId, isNull);
        expect(state.loadingAuth, isTrue);
        expect(
          (services.playerSession as _PlayerSession).profileRequests,
          0,
          reason:
              'Recovery must not start playback before auth startup completes.',
        );
        if (completeWhileMounted) {
          if (storageFailure) {
            services.authService.gate.completeError(
              StateError('fixture initial storage read failed'),
            );
          } else {
            services.authService.gate.complete();
          }
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(tester.takeException(), isNull);
          expect(state.loadingAuth, isFalse);
          expect(state.loadingWatch, isFalse);
          expect(state.showOfflineChannelPlaceholder, isTrue);
          expect(chat.connects, 1);
          expect(state.chatController.canSendForCurrentViewer, isFalse);
          expect(state.chatController.isReadOnlyGuest, isTrue);
          expect(state.chatController.connectingChat, isFalse);
          expect(state.chatBootstrapping, isFalse);
          expect(state.relationshipBootstrapping, isFalse);
          expect(state.engagementBootstrapping, isFalse);
          expect(state.emoteBootstrapping, isFalse);
          expect(state.channelId, '7');
          expect(
            (services.playerSession as _PlayerSession).profileRequests,
            status == 503 || liveAvailable ? 1 : 0,
          );
          if (liveAvailable) {
            expect(state.liveTimelineStreamId, 'fixture-live-stream');
            expect(state.liveTimelineStartedAt, DateTime.utc(2026, 10, 12));
            expect(state.playbackController.loadingPlayer, isFalse);
          }
          expect(find.byType(TwitchLinkedLoginPage), findsNothing);
          if (status == 200 &&
              !liveAvailable &&
              !recoverLive &&
              !storageFailure) {
            state.messageController.text = 'fixture guest draft';
            await state.sendMessage();
            expect(state.messageController.text, 'fixture guest draft');
            final foregroundGeneration = state.watchLoadGeneration;
            final foregroundChat = state.chatController.runtime;
            final foregroundProfiles =
                (services.playerSession as _PlayerSession).profileRequests;
            for (var cycle = 0; cycle < 3; cycle++) {
              state.didChangeAppLifecycleState(AppLifecycleState.hidden);
              state.didChangeAppLifecycleState(AppLifecycleState.resumed);
              final recovery = state.foregroundRecoveryInFlight;
              for (var i = 0; i < 25; i++) {
                await tester.pump(const Duration(milliseconds: 100));
              }
              await recovery;
              final networkRecovery = state.recoverWatchAfterNetworkRestored();
              for (var i = 0; i < 25; i++) {
                await tester.pump(const Duration(milliseconds: 100));
              }
              await networkRecovery;
              expect(
                state.watchLoadGeneration,
                foregroundGeneration,
                reason:
                    'An unchanged offline page must not restart on foreground cycle $cycle',
              );
              expect(state.chatController.runtime, same(foregroundChat));
              expect(
                (services.playerSession as _PlayerSession).profileRequests,
                foregroundProfiles,
              );
              expect(state.showOfflineChannelPlaceholder, isTrue);
            }
          }
          expect(
            find.text('OAuth 暫時載入失敗，請稍後再試。'),
            storageFailure ? findsOneWidget : findsNothing,
          );
          if (status == 503) {
            final requestsBeforeRetry = requests;
            final generationBeforeRetry = state.watchLoadGeneration;
            responseStatus = 200;
            await state.loadWatch();
            for (var i = 0; i < 20; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(tester.takeException(), isNull);
            expect(requests, greaterThan(requestsBeforeRetry));
            expect(state.watchLoadGeneration, generationBeforeRetry + 1);
            expect(state.loadingAuth, isFalse);
            expect(state.loadingWatch, isFalse);
            expect(state.playbackController.loadingPlayer, isFalse);
            expect(state.showOfflineChannelPlaceholder, isTrue);
            expect(
              (services.playerSession as _PlayerSession).profileRequests,
              1,
            );
            expect(services.authService.loads, 1);
            expect(state.viewerId, isNull);
            expect(chat.connects, 1);
            expect(state.chatController.runtime, same(chat));
            expect(chat.channelLogin, 'fixture');
            expect(find.text('聊天室暫時連線失敗，稍後再試。'), findsNothing);
            expect(state.chatController.isReadOnlyGuest, isTrue);
            expect(state.chatController.canSendForCurrentViewer, isFalse);
            expect(state.chatBootstrapping, isFalse);
            expect(state.relationshipBootstrapping, isFalse);
            expect(state.engagementBootstrapping, isFalse);
            expect(state.emoteBootstrapping, isFalse);
            expect(find.byType(TwitchLinkedLoginPage), findsNothing);
          }
          if (recoverLive) {
            final initialGeneration = state.watchLoadGeneration;
            responseLive = true;
            for (var i = 0; i < 80; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(tester.takeException(), isNull);
            expect(state.liveTimelineStreamId, responseStreamId);
            expect(state.watchLoadGeneration, initialGeneration + 1);
            expect(
              (services.playerSession as _PlayerSession).profileRequests,
              1,
            );
            final retrySession = services.playerSession as _PlayerSession;
            final retryGate = Completer<void>();
            addTearDown(() {
              if (!retryGate.isCompleted) retryGate.complete();
            });
            retrySession.profileGate = retryGate;
            for (var i = 0; i < 80; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(state.watchLoadGeneration, initialGeneration + 2);
            expect(
              (services.playerSession as _PlayerSession).profileRequests,
              2,
              reason:
                  'A failed offline-to-live startup must retry the same stream.',
            );
            expect(state.loadingPlayer, isTrue);
            expect(state.showOfflineChannelPlaceholder, isTrue);
            for (var i = 0; i < 80; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(retrySession.profileRequests, 2);
            expect(state.watchLoadGeneration, initialGeneration + 2);
            retrySession.profileGate = null;
            retryGate.complete();
            for (var i = 0; i < 5; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            responseStreamId = 'fixture-live-stream-2';
            for (var i = 0; i < 80; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(tester.takeException(), isNull);
            expect(state.liveTimelineStreamId, responseStreamId);
            expect(state.watchLoadGeneration, initialGeneration + 3);
            expect(
              (services.playerSession as _PlayerSession).profileRequests,
              3,
            );
            expect(services.authService.loads, 1);
            expect(state.loadingAuth, isFalse);
            expect(state.loadingWatch, isFalse);
            expect(state.playbackController.loadingPlayer, isFalse);
            expect(state.chatController.runtime, same(chat));
            expect(chat.connects, 1);
            expect(state.chatBootstrapping, isFalse);
            expect(state.relationshipBootstrapping, isFalse);
            expect(state.engagementBootstrapping, isFalse);
            expect(state.emoteBootstrapping, isFalse);
            expect(state.chatController.isReadOnlyGuest, isTrue);
            expect(state.chatController.canSendForCurrentViewer, isFalse);
            expect(find.text('聊天室暫時連線失敗，稍後再試。'), findsNothing);
            final oldPollGate = Completer<void>();
            addTearDown(() {
              if (!oldPollGate.isCompleted) oldPollGate.complete();
            });
            nextLiveResponseGate = oldPollGate;
            if (staleOffline) {
              responseLive = false;
            }
            for (var i = 0; i < 80; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(liveResponsePaused, isTrue);
            responseLive = true;
            responseStreamId = 'fixture-live-stream-3';
            responseStartedAt = '2026-10-12T01:00:00Z';
            await state.loadWatch();
            for (var i = 0; i < 20; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(state.liveTimelineStreamId, responseStreamId);
            expect(state.liveTimelineStartedAt, DateTime.utc(2026, 10, 12, 1));
            final newGeneration = state.watchLoadGeneration;
            final newProfileRequests =
                (services.playerSession as _PlayerSession).profileRequests;
            oldPollGate.complete();
            for (var i = 0; i < 20; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(tester.takeException(), isNull);
            expect(state.watchLoadGeneration, newGeneration);
            expect(state.liveTimelineStreamId, responseStreamId);
            expect(state.liveTimelineStartedAt, DateTime.utc(2026, 10, 12, 1));
            expect(
              (services.playerSession as _PlayerSession).profileRequests,
              newProfileRequests,
            );
          }
          expect(find.text('訪客模式可讀取聊天室；登入後才能發言與使用點數。'), findsOneWidget);
          if (liveAvailable) {
            final playerSession = services.playerSession as _PlayerSession;
            final before = playerSession.profileRequests;
            // Model an established paused stream, not the failed-open fixture.
            state.showOfflineChannelPlaceholder = false;
            playerSession.exposedPlayer = _EndedPlayer(completed: false);
            for (var i = 0; i < 80; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(
              playerSession.profileRequests,
              before,
              reason: 'Paused live playback must not be force-restarted.',
            );
            playerSession.exposedPlayer = _EndedPlayer(completed: true);
            state.preferVodReplayChat = true;
            for (var i = 0; i < 80; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(
              playerSession.profileRequests,
              before,
              reason: 'Recorded playback completion must not restart live.',
            );
            state.preferVodReplayChat = false;
            for (var i = 0; i < 80; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            playerSession.exposedPlayer = null;
            expect(
              playerSession.profileRequests,
              before + 1,
              reason:
                  'Ended live playback must recover even with unchanged stream ID.',
            );
            final routeGate = Completer<void>();
            addTearDown(() {
              if (!routeGate.isCompleted) routeGate.complete();
            });
            playerSession.exposedPlayer = _EndedPlayer(completed: true);
            nextLiveResponseGate = routeGate;
            liveResponsePaused = false;
            for (var i = 0; i < 80; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(liveResponsePaused, isTrue);
            final oldGeneration = state.watchLoadGeneration;
            final oldProfiles = playerSession.profileRequests;
            final nextSession = _PlayerSession();
            final nextServices = isolatedWatchPlaybackServices(
              session: nextSession,
              runtime: TwitchPlaylistPlayerRuntime(
                playbackApi: _UnusedPlayback(),
              ),
            );
            final navigator = Navigator.of(
              tester.element(find.byType(TwitchWatchPage)),
            );
            unawaited(
              navigator.push<void>(
                MaterialPageRoute(
                  builder: (_) => TwitchWatchPage(
                    initialChannelLogin: 'fixture',
                    initialServices: nextServices,
                    initialChatRuntimeFactory: isolatedWatchChatRuntime,
                  ),
                ),
              ),
            );
            for (var i = 0; i < 20; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            final nextState = tester.state<TwitchWatchPageState>(
              find.byType(TwitchWatchPage),
            );
            expect(nextState, isNot(same(state)));
            expect(nextSession.profileRequests, 1);
            final nextGeneration = nextState.watchLoadGeneration;
            expect(state.mounted, isTrue);
            expect(playerSession.exposedPlayer!.state.completed, isTrue);
            routeGate.complete();
            for (var i = 0; i < 20; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(tester.takeException(), isNull);
            expect(state.watchLoadGeneration, oldGeneration);
            expect(playerSession.profileRequests, oldProfiles);
            expect(nextState.watchLoadGeneration, nextGeneration);
            expect(nextSession.profileRequests, 1);
            playerSession.exposedPlayer = null;
            navigator.pop();
            await tester.pumpAndSettle();
            expect(
              tester.state<TwitchWatchPageState>(find.byType(TwitchWatchPage)),
              same(state),
            );
          }
          await tester.tap(find.widgetWithText(FilledButton, '登入'));
          await tester.pumpAndSettle();
          expect(find.byType(TwitchLinkedLoginPage), findsOneWidget);
          final login = tester.widget<TwitchLinkedLoginPage>(
            find.byType(TwitchLinkedLoginPage),
          );
          expect(login.mainAuthService, same(services.authService));
          expect(login.webGqlAuthService, same(services.webGqlAuthService));
          expect(login.dropsAuthService, same(services.dropsAuthService));
          expect(login.apiClient, same(services.apiClient));
          expect(login.autoCloseOnComplete, isTrue);
          expect(
            find.text('尚未登入'),
            persistentFailure ? findsNothing : findsOneWidget,
          );
          if (persistentFailure) {
            expect(find.text('無法確認登入狀態'), findsOneWidget);
            expect(find.text('無法確認登入狀態，請稍後再試。'), findsOneWidget);
          }
          Navigator.of(
            tester.element(find.byType(TwitchLinkedLoginPage)),
          ).pop();
          await tester.pumpAndSettle();
          expect(find.byType(TwitchLinkedLoginPage), findsNothing);
          expect(services.authService.loads, 3);
          expect(
            services.webGqlAuthService.loads,
            persistentFailure
                ? 1
                : storageFailure
                ? 2
                : 3,
          );
          expect(
            services.dropsAuthService.loads,
            persistentFailure
                ? 0
                : storageFailure
                ? 2
                : 3,
          );
          expect(state.viewerId, isNull);
          expect(state.loadingAuth, isFalse);
          expect(chat.connects, 1);
          expect(state.chatController.canSendForCurrentViewer, isFalse);
          expect(find.text('訪客模式可讀取聊天室；登入後才能發言與使用點數。'), findsOneWidget);
        }
        if (completeWhileMounted) {
          expect(requests, greaterThan(0));
        } else {
          expect(requests, 0);
        }
        final beforeDispose = requests;
        await tester.pumpWidget(const SizedBox.shrink());
        if (!services.authService.gate.isCompleted) {
          services.authService.gate.complete();
        }
        await tester.pump();
        ensureWatchModeRuntime(state);
        await tester.pump(const Duration(seconds: 20));
        expect(tester.takeException(), isNull);
        expect(TwitchMediaKitPlayerHost.playerOrNull, isNull);
        expect(requests, beforeDispose);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
  test(
    'Supplied watch services retain all handles and feature port groups',
    () {
      final supplied = _Services();
      addTearDown(() => supplied.apiClient.close(force: true));
      final handles = TwitchWatchSessionHandles.create(
        playerTitle: 'fixture-unused',
        suppliedServices: supplied,
        sharedAuthService: supplied.authService,
        playerRuntime: supplied.playerRuntime,
      );
      expect(handles.services, same(supplied));
      expect(handles.apiClient, same(supplied.apiClient));
      expect(handles.authService, same(supplied.authService));
      expect(handles.dropsAuthService, same(supplied.dropsAuthService));
      expect(handles.webGqlAuthService, same(supplied.webGqlAuthService));
      expect(handles.authApi, same(supplied.authApi));
      expect(handles.recentMessagesApi, same(supplied.recentMessagesApi));
      expect(handles.playerSession, same(supplied.playerSession));
      expect(handles.ports.player.services, same(supplied.player));
      expect(handles.ports.chat.services, same(supplied.chat));
      expect(handles.ports.emotes.services, same(supplied.emotes));
      expect(handles.ports.engagement.services, same(supplied.engagement));
      expect(handles.ports.relationship.services, same(supplied.relationship));
      expect(TwitchMediaKitPlayerHost.playerOrNull, isNull);
    },
  );
  for (final wrongAuth in [false, true]) {
    test(
      'Supplied watch services reject mismatched dependency auth=$wrongAuth',
      () {
        final supplied = _Services();
        addTearDown(() => supplied.apiClient.close(force: true));
        expect(
          () => TwitchWatchSessionHandles.create(
            playerTitle: 'fixture-unused',
            suppliedServices: supplied,
            sharedAuthService: wrongAuth
                ? TwitchAuthService(apiClient: supplied.apiClient)
                : supplied.authService,
            playerRuntime: wrongAuth ? supplied.playerRuntime : _Runtime(),
          ),
          throwsArgumentError,
        );
        expect(TwitchMediaKitPlayerHost.playerOrNull, isNull);
      },
    );
  }
}
