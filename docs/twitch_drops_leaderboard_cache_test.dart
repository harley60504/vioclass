import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/api/auth/twitch_auth_api_service.dart';
import 'package:vioclass/features/twitch/api/core/twitch_api_client.dart';
import 'package:vioclass/features/twitch/models/discovery/twitch_live_stream.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_auth_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_drops_auth_service.dart';
import 'package:vioclass/features/twitch/services/discovery/twitch_discovery_service.dart';
import 'package:vioclass/features/twitch/services/drops/twitch_drops_channel_points_leaderboard_service.dart';

class _Auth extends TwitchAuthService {
  _Auth(TwitchApiClient client) : super(apiClient: client);
  String? fixtureToken = 'fixture-viewer';
  @override
  String? get accessToken => fixtureToken;
}

class _Drops extends TwitchDropsAuthService {
  _Drops(TwitchApiClient client) : super(apiClient: client);
  String? fixtureToken = 'fixture-drops';
  int reads = 0;
  int? gatedRead;
  Completer<void>? gate;
  Completer<void>? entered;
  @override
  String get dropsClientId => 'fixture-client';
  @override
  Future<void> loadStoredSession() async {}
  @override
  Future<String?> getToken() async {
    reads++;
    final token = fixtureToken;
    if (reads == gatedRead) {
      entered?.complete();
      await gate?.future;
    }
    return token;
  }
}

class _Discovery extends TwitchDiscoveryService {
  _Discovery(TwitchApiClient client, _Auth auth)
    : super(
        client: client,
        authService: auth,
        authApi: TwitchAuthApiService(client: client),
      );
  String login = 'fixture-a';
  int calls = 0;
  @override
  Future<TwitchFollowedChannelPageResult> fetchFollowedChannels({
    String? after,
    int first = 100,
    bool attachProfiles = true,
  }) async {
    calls++;
    return TwitchFollowedChannelPageResult(
      channels: [
        TwitchFollowedChannel(
          broadcasterId: login,
          broadcasterLogin: login,
          broadcasterName: login,
          followedAt: null,
        ),
      ],
      cursor: null,
    );
  }
}

void main() {
  test(
    'Leaderboard final credential await cannot admit an obsolete main account',
    () async {
      final client = TwitchApiClient();
      addTearDown(() => client.close(force: true));
      final auth = _Auth(client);
      final drops = _Drops(client)
        ..gatedRead = 2
        ..gate = Completer<void>()
        ..entered = Completer<void>();
      addTearDown(() {
        if (!drops.gate!.isCompleted) drops.gate!.complete();
      });
      final discovery = _Discovery(client, auth);
      var requests = 0;
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: [
                  {
                    'data': {
                      'user': {
                        'channel': {
                          'self': {
                            'communityPoints': {'balance': 123},
                          },
                        },
                      },
                    },
                  },
                ],
              ),
            );
          },
        ),
      );
      final service = TwitchDropsChannelPointsLeaderboardService(
        discoveryService: discovery,
        apiClient: client,
        dropsAuthService: drops,
      );
      final pending = service.load();
      await drops.entered!.future.timeout(const Duration(seconds: 2));
      auth.fixtureToken = 'fixture-viewer-replacement';
      discovery.login = 'fixture-replacement';
      drops.gate!.complete();
      expect(await pending.timeout(const Duration(seconds: 2)), isEmpty);
      expect((await service.load()).single.channelLogin, 'fixture-replacement');
      expect(requests, 2);
      expect((await service.load()).single.channelLogin, 'fixture-replacement');
      expect(requests, 2);
    },
  );
  test(
    'Leaderboard cache isolates service owners and credential changes',
    () async {
      final client = TwitchApiClient();
      addTearDown(() => client.close(force: true));
      var requests = 0;
      Completer<void>? gate;
      Completer<void>? entered;
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            requests++;
            expect(options.data.toString(), contains('ChannelPointsContext'));
            entered?.complete();
            await gate?.future;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: [
                  {
                    'data': {
                      'user': {
                        'channel': {
                          'self': {
                            'communityPoints': {'balance': 123},
                          },
                        },
                      },
                    },
                  },
                ],
              ),
            );
          },
        ),
      );
      final authA = _Auth(client);
      final dropsA = _Drops(client);
      final discoveryA = _Discovery(client, authA);
      final a = TwitchDropsChannelPointsLeaderboardService(
        discoveryService: discoveryA,
        apiClient: client,
        dropsAuthService: dropsA,
      );
      expect((await a.load(force: true)).single.channelLogin, 'fixture-a');
      expect((await a.load()).single.channelLogin, 'fixture-a');
      expect(requests, 1);
      final authB = _Auth(client)..fixtureToken = 'fixture-viewer-b';
      final dropsB = _Drops(client)..fixtureToken = 'fixture-drops-b';
      final discoveryB = _Discovery(client, authB)..login = 'fixture-b';
      final b = TwitchDropsChannelPointsLeaderboardService(
        discoveryService: discoveryB,
        apiClient: client,
        dropsAuthService: dropsB,
      );
      expect((await b.load()).single.channelLogin, 'fixture-b');
      expect(requests, 2);
      authA.fixtureToken = 'fixture-viewer-c';
      dropsA.fixtureToken = 'fixture-drops-c';
      discoveryA.login = 'fixture-c';
      expect((await a.load()).single.channelLogin, 'fixture-c');
      expect(requests, 3);
      gate = Completer<void>();
      entered = Completer<void>();
      final pending = a.load(force: true);
      await entered.future.timeout(const Duration(seconds: 2));
      authA.fixtureToken = 'fixture-viewer-d';
      dropsA.fixtureToken = 'fixture-drops-d';
      discoveryA.login = 'fixture-d';
      gate.complete();
      expect(await pending.timeout(const Duration(seconds: 2)), isEmpty);
      gate = null;
      entered = null;
      expect((await a.load()).single.channelLogin, 'fixture-d');
      expect(requests, 5);
      expect((await a.load()).single.channelLogin, 'fixture-d');
      expect(requests, 5);
      dropsA.fixtureToken = null;
      expect(await a.load(), isEmpty);
      expect(requests, 5);
    },
  );
}
