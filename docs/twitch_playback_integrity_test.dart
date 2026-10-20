// ignore_for_file: avoid_relative_lib_imports

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/core/twitch_api_exception.dart';
import '../lib/features/twitch/api/core/twitch_gql_api_service.dart';
import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/api/playback/twitch_playback_api_service.dart';
import '../lib/features/twitch/api/playback/twitch_playback_viewer_auth.dart';
import '../lib/features/twitch/services/playback/twitch_playback_integrity_manager.dart';
import '../lib/features/twitch/services/playback/twitch_playback_viewer_auth.dart';
import '../lib/features/twitch/services/playback/twitch_playlist_player_runtime.dart';
import '../lib/features/twitch/services/watch/twitch_watch_services.dart';

TwitchPlaybackIntegrityContext context({
  required String clientId,
  required String token,
  required DateTime expiresAt,
  String identityKey = 'anonymous',
}) => TwitchPlaybackIntegrityContext(
  clientId: clientId,
  token: token,
  deviceId: 'fixture-device-1234567890',
  userAgent: 'fixture-browser',
  expiresAt: expiresAt,
  identityKey: identityKey,
);

Map<String, dynamic> successBody({String value = 'fixture-playback-token'}) =>
    <String, dynamic>{
      'data': <String, dynamic>{
        'streamPlaybackAccessToken': <String, dynamic>{
          'value': value,
          'signature': 'fixture-signature',
        },
      },
    };

Map<String, dynamic> rejectedBody() => <String, dynamic>{
  'errors': <Map<String, dynamic>>[
    <String, dynamic>{'message': 'failed integrity check'},
  ],
};

Map<String, dynamic> vodSuccessBody() => <String, dynamic>{
  'data': <String, dynamic>{
    'videoPlaybackAccessToken': <String, dynamic>{
      'value': 'fixture-vod-token',
      'signature': 'fixture-vod-signature',
    },
  },
};

Map<String, dynamic> clipSuccessBody() => <String, dynamic>{
  'data': <String, dynamic>{
    'clip': <String, dynamic>{
      'playbackAccessToken': <String, dynamic>{
        'value': 'fixture-clip-token',
        'signature': 'fixture-clip-signature',
      },
      'videoQualities': <Map<String, dynamic>>[
        <String, dynamic>{
          'frameRate': 60,
          'quality': '720',
          'sourceURL': 'https://example.com/clip.mp4',
        },
      ],
    },
  },
};

TwitchPlaybackApiService apiWithResponses({
  required List<Map<String, dynamic>> responses,
  required List<Map<String, dynamic>> sentHeaders,
  Map<String, String>? Function({
    required String clientId,
    required TwitchPlaybackViewerAuth? viewerAuth,
  })?
  cached,
  Future<Map<String, String>> Function({
    required String clientId,
    required String channelLogin,
    required TwitchPlaybackViewerAuth? viewerAuth,
  })?
  refresh,
  void Function({
    required String clientId,
    required TwitchPlaybackViewerAuth? viewerAuth,
    required String rejectedIntegrity,
  })?
  invalidate,
  Future<TwitchPlaybackViewerAuthResolution> Function()? viewerAuthProvider,
  List<int>? statusCodes,
}) {
  var index = 0;
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        sentHeaders.add(Map<String, dynamic>.from(options.headers));
        final current = index++;
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: statusCodes?[current] ?? 200,
            data: responses[current],
          ),
        );
      },
    ),
  );
  final client = TwitchApiClient(dio: dio, closeDioOnDispose: false);
  return TwitchPlaybackApiService(
    gql: TwitchGqlApiService(client: client, clientId: 'web-client'),
    cachedIntegrityHeaders: cached,
    integrityHeadersProvider: refresh,
    integrityInvalidator: invalidate,
    viewerAuthProvider: viewerAuthProvider,
  );
}

void main() {
  test(
    'Watch service playback wiring compiles without native player startup',
    () {
      TwitchWatchServices? services;
      expect(services, isNull);
    },
  );

  test('Happy path never starts integrity acquisition', () async {
    var refreshes = 0;
    final sent = <Map<String, dynamic>>[];
    final api = apiWithResponses(
      responses: <Map<String, dynamic>>[successBody()],
      sentHeaders: sent,
      refresh:
          ({
            required clientId,
            required channelLogin,
            required viewerAuth,
          }) async {
            refreshes++;
            return <String, String>{'Client-Integrity': 'unused'};
          },
    );

    final token = await api.getLivePlaybackAccessToken(channelLogin: 'Alpha');
    expect(token.isValid, true);
    expect(refreshes, 0);
    expect(sent, hasLength(1));
    expect(sent.single.containsKey('Client-Integrity'), false);
  });

  test('Explicit rejection acquires proof and retries exactly once', () async {
    var refreshes = 0;
    final sent = <Map<String, dynamic>>[];
    final api = apiWithResponses(
      responses: <Map<String, dynamic>>[rejectedBody(), successBody()],
      sentHeaders: sent,
      refresh:
          ({
            required clientId,
            required channelLogin,
            required viewerAuth,
          }) async {
            refreshes++;
            expect(clientId, 'web-client');
            expect(channelLogin, 'alpha');
            return <String, String>{
              'Client-Integrity': 'fresh-proof',
              'X-Device-ID': 'fixture-device-1234567890',
              'User-Agent': 'fixture-browser',
            };
          },
    );

    expect(
      (await api.getLivePlaybackAccessToken(channelLogin: 'Alpha')).isValid,
      true,
    );
    expect(refreshes, 1);
    expect(sent, hasLength(2));
    expect(sent.first.containsKey('Client-Integrity'), false);
    expect(sent.last['Client-Integrity'], 'fresh-proof');
  });

  test(
    'A second integrity rejection stops and invalidates the proof',
    () async {
      var refreshes = 0;
      final invalidated = <String>[];
      final api = apiWithResponses(
        responses: <Map<String, dynamic>>[rejectedBody(), rejectedBody()],
        sentHeaders: <Map<String, dynamic>>[],
        refresh:
            ({
              required clientId,
              required channelLogin,
              required viewerAuth,
            }) async {
              refreshes++;
              return <String, String>{'Client-Integrity': 'rejected-proof'};
            },
        invalidate:
            ({
              required clientId,
              required viewerAuth,
              required rejectedIntegrity,
            }) {
              invalidated.add(rejectedIntegrity);
            },
      );

      await expectLater(
        api.getLivePlaybackAccessToken(channelLogin: 'alpha'),
        throwsA(isA<TwitchApiException>()),
      );
      expect(refreshes, 1);
      expect(invalidated, <String>['rejected-proof']);
    },
  );

  test('Rejected cached proof is replaced before the one retry', () async {
    final invalidated = <String>[];
    final sent = <Map<String, dynamic>>[];
    final api = apiWithResponses(
      responses: <Map<String, dynamic>>[rejectedBody(), successBody()],
      sentHeaders: sent,
      cached: ({required clientId, required viewerAuth}) => <String, String>{
        'Client-Integrity': 'cached-proof',
      },
      refresh:
          ({
            required clientId,
            required channelLogin,
            required viewerAuth,
          }) async => <String, String>{'Client-Integrity': 'fresh-proof'},
      invalidate:
          ({
            required clientId,
            required viewerAuth,
            required rejectedIntegrity,
          }) {
            invalidated.add(rejectedIntegrity);
          },
    );

    expect(
      (await api.getLivePlaybackAccessToken(channelLogin: 'alpha')).isValid,
      true,
    );
    expect(sent.first['Client-Integrity'], 'cached-proof');
    expect(sent.last['Client-Integrity'], 'fresh-proof');
    expect(invalidated, <String>['cached-proof']);
  });

  test('Generic HTTP refusal never starts integrity acquisition', () async {
    var refreshes = 0;
    final api = apiWithResponses(
      responses: <Map<String, dynamic>>[
        <String, dynamic>{'message': 'Forbidden'},
      ],
      statusCodes: <int>[403],
      sentHeaders: <Map<String, dynamic>>[],
      refresh:
          ({
            required clientId,
            required channelLogin,
            required viewerAuth,
          }) async {
            refreshes++;
            return <String, String>{'Client-Integrity': 'unused'};
          },
    );

    await expectLater(
      api.getLivePlaybackAccessToken(channelLogin: 'alpha'),
      throwsA(isA<TwitchApiException>()),
    );
    expect(refreshes, 0);
  });

  test('Validated Web viewer token is attached to playback only', () async {
    final sent = <Map<String, dynamic>>[];
    const viewer = TwitchPlaybackViewerAuth(
      clientId: 'web-client',
      accessToken: 'viewer-token',
      userId: 'viewer-1',
    );
    final api = apiWithResponses(
      responses: <Map<String, dynamic>>[successBody()],
      sentHeaders: sent,
      viewerAuthProvider: () async =>
          TwitchPlaybackViewerAuthResolution.authenticated(viewer),
    );

    expect(
      (await api.getLivePlaybackAccessToken(channelLogin: 'alpha')).isValid,
      true,
    );
    expect(sent.single['Authorization'], 'OAuth viewer-token');
    expect(
      api.lastViewerAuthState,
      TwitchPlaybackViewerAuthState.authenticated,
    );
  });

  test('Validated Web viewer token also covers VOD and clip grants', () async {
    const viewer = TwitchPlaybackViewerAuth(
      clientId: 'web-client',
      accessToken: 'viewer-token',
      userId: 'viewer-1',
    );
    final vodHeaders = <Map<String, dynamic>>[];
    final vodApi = apiWithResponses(
      responses: <Map<String, dynamic>>[vodSuccessBody()],
      sentHeaders: vodHeaders,
      viewerAuthProvider: () async =>
          TwitchPlaybackViewerAuthResolution.authenticated(viewer),
    );
    final clipHeaders = <Map<String, dynamic>>[];
    final clipApi = apiWithResponses(
      responses: <Map<String, dynamic>>[clipSuccessBody()],
      sentHeaders: clipHeaders,
      viewerAuthProvider: () async =>
          TwitchPlaybackViewerAuthResolution.authenticated(viewer),
    );

    expect(
      (await vodApi.getVodPlaybackAccessToken(videoId: '123')).isValid,
      true,
    );
    expect(
      (await clipApi.resolveClipPlayback(clipSlug: 'fixture')).variants,
      hasLength(1),
    );
    expect(vodHeaders.single['Authorization'], 'OAuth viewer-token');
    expect(clipHeaders.single['Authorization'], 'OAuth viewer-token');
  });

  test(
    'Invalid stored login falls back anonymously for ordinary stream',
    () async {
      final sent = <Map<String, dynamic>>[];
      final api = apiWithResponses(
        responses: <Map<String, dynamic>>[successBody()],
        sentHeaders: sent,
        viewerAuthProvider: () async =>
            const TwitchPlaybackViewerAuthResolution.failed(
              TwitchPlaybackViewerAuthState.storedTokenInvalid,
            ),
      );

      expect(
        (await api.getLivePlaybackAccessToken(channelLogin: 'alpha')).isValid,
        true,
      );
      expect(sent.single.containsKey('Authorization'), false);
      expect(
        api.lastViewerAuthState,
        TwitchPlaybackViewerAuthState.storedTokenInvalid,
      );
    },
  );

  test(
    'Invalid stored login does not hide restricted anonymous playback',
    () async {
      final restricted = jsonEncode(<String, dynamic>{
        'chansub': <String, dynamic>{
          'restricted_bitrates': <String>['720p'],
        },
      });
      final api = apiWithResponses(
        responses: <Map<String, dynamic>>[successBody(value: restricted)],
        sentHeaders: <Map<String, dynamic>>[],
        viewerAuthProvider: () async =>
            const TwitchPlaybackViewerAuthResolution.failed(
              TwitchPlaybackViewerAuthState.storedTokenInvalid,
            ),
      );

      await expectLater(
        api.getLivePlaybackAccessToken(channelLogin: 'restricted'),
        throwsA(isA<TwitchPlaybackAuthorizationException>()),
      );
    },
  );

  test('Runtime preserves restricted-login authorization failure', () async {
    // This Flutter test lives in docs rather than the standard test directory.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final restricted = jsonEncode(<String, dynamic>{
      'chansub': <String, dynamic>{
        'restricted_bitrates': <String>['720p'],
      },
    });
    final api = apiWithResponses(
      responses: List<Map<String, dynamic>>.generate(
        3,
        (_) => successBody(value: restricted),
      ),
      sentHeaders: <Map<String, dynamic>>[],
      viewerAuthProvider: () async =>
          const TwitchPlaybackViewerAuthResolution.failed(
            TwitchPlaybackViewerAuthState.storedTokenInvalid,
          ),
    );
    final runtime = TwitchPlaylistPlayerRuntime(playbackApi: api);
    addTearDown(runtime.dispose);

    expect(await runtime.loadLivePlaylist(channelLogin: 'restricted'), isNull);
    expect(runtime.error, isA<TwitchPlaybackAuthorizationException>());
  });

  test('Viewer auth validation is cached and singleflight', () async {
    var token = 'viewer-token';
    var authClock = DateTime.utc(2026, 10, 10, 12);
    var validations = 0;
    final gate = Completer<void>();
    final resolver = TwitchPlaybackViewerAuthResolver(
      expectedClientId: 'web-client',
      tokenProvider: () async => token,
      ownerTokenProvider: () async => 'owner-token',
      clientIdProvider: () => 'web-client',
      now: () => authClock,
      validate: (value) async {
        validations++;
        if (validations == 1) await gate.future;
        return const TwitchTokenValidation(
          clientId: 'web-client',
          login: 'viewer',
          userId: 'viewer-1',
          scopes: <String>[],
          expiresIn: 60,
        );
      },
      validateOwner: (_) async => const TwitchTokenValidation(
        clientId: 'owner-client',
        login: 'viewer',
        userId: 'viewer-1',
        scopes: <String>[],
        expiresIn: 3600,
      ),
    );

    final first = resolver.resolve();
    final joined = resolver.resolve();
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    expect((await first).state, TwitchPlaybackViewerAuthState.authenticated);
    expect((await joined).state, TwitchPlaybackViewerAuthState.authenticated);
    expect(validations, 1);
    expect(
      (await resolver.resolve()).state,
      TwitchPlaybackViewerAuthState.authenticated,
    );
    expect(validations, 1);

    authClock = authClock.add(const Duration(seconds: 31));
    await resolver.resolve();
    expect(validations, 2);

    token = 'viewer-token-2';
    await resolver.resolve();
    expect(validations, 3);
  });

  test('Mismatched stored Client-ID is never validated or sent', () async {
    var validations = 0;
    final resolver = TwitchPlaybackViewerAuthResolver(
      expectedClientId: 'web-client',
      tokenProvider: () async => 'wrong-client-token',
      ownerTokenProvider: () async => 'owner-token',
      clientIdProvider: () => 'android-client',
      validate: (_) async {
        validations++;
        throw StateError('must not validate mismatched client');
      },
      validateOwner: (_) async {
        throw StateError('must not validate owner for mismatched client');
      },
    );
    final result = await resolver.resolve();
    expect(result.state, TwitchPlaybackViewerAuthState.clientMismatch);
    expect(result.auth, isNull);
    expect(validations, 0);
  });

  test('Web viewer token from another owner is never returned', () async {
    final resolver = TwitchPlaybackViewerAuthResolver(
      expectedClientId: 'web-client',
      tokenProvider: () async => 'web-token',
      ownerTokenProvider: () async => 'owner-token',
      clientIdProvider: () => 'web-client',
      validate: (_) async => const TwitchTokenValidation(
        clientId: 'web-client',
        login: 'other',
        userId: 'viewer-2',
        scopes: <String>[],
        expiresIn: 3600,
      ),
      validateOwner: (_) async => const TwitchTokenValidation(
        clientId: 'owner-client',
        login: 'viewer',
        userId: 'viewer-1',
        scopes: <String>[],
        expiresIn: 3600,
      ),
    );

    final result = await resolver.resolve();
    expect(result.state, TwitchPlaybackViewerAuthState.ownerMismatch);
    expect(result.auth, isNull);
  });

  test('Integrity proof cache is isolated between viewer accounts', () async {
    final clock = DateTime.utc(2026, 10, 10, 12);
    var acquisitions = 0;
    final manager = TwitchPlaybackIntegrityManager(
      now: () => clock,
      acquire:
          ({
            required clientId,
            required channelLogin,
            required viewerAuth,
          }) async {
            acquisitions++;
            return context(
              clientId: clientId,
              token: 'proof-$acquisitions',
              expiresAt: clock.add(const Duration(minutes: 5)),
              identityKey: viewerAuth?.identityKey ?? 'anonymous',
            );
          },
    );
    const firstViewer = TwitchPlaybackViewerAuth(
      clientId: 'web-client',
      accessToken: 'token-a',
      userId: 'viewer-a',
    );
    const secondViewer = TwitchPlaybackViewerAuth(
      clientId: 'web-client',
      accessToken: 'token-b',
      userId: 'viewer-b',
    );

    final first = await manager.headersFor(
      clientId: 'web-client',
      channelLogin: 'alpha',
      viewerAuth: firstViewer,
    );
    final second = await manager.headersFor(
      clientId: 'web-client',
      channelLogin: 'alpha',
      viewerAuth: secondViewer,
    );
    expect(acquisitions, 2);
    expect(first['Client-Integrity'], isNot(second['Client-Integrity']));
    expect(
      manager.cachedHeadersFor(clientId: 'web-client', viewerAuth: firstViewer),
      first,
    );
  });

  test(
    'Manager isolates clients, honors expiry, and joins concurrency',
    () async {
      var clock = DateTime.utc(2026, 10, 10, 12);
      var acquisitions = 0;
      final gate = Completer<void>();
      final manager = TwitchPlaybackIntegrityManager(
        now: () => clock,
        acquire:
            ({
              required clientId,
              required channelLogin,
              required viewerAuth,
            }) async {
              acquisitions++;
              if (clientId == 'client-a' && acquisitions == 1) {
                await gate.future;
              }
              return context(
                clientId: clientId,
                token: '$clientId-$acquisitions',
                expiresAt: clock.add(const Duration(minutes: 5)),
                identityKey: viewerAuth?.identityKey ?? 'anonymous',
              );
            },
      );

      final first = manager.headersFor(
        clientId: 'client-a',
        channelLogin: 'alpha',
        viewerAuth: null,
      );
      final joined = manager.headersFor(
        clientId: 'client-a',
        channelLogin: 'beta',
        viewerAuth: null,
      );
      await Future<void>.delayed(Duration.zero);
      expect(acquisitions, 1);
      gate.complete();
      expect(
        (await first)['Client-Integrity'],
        (await joined)['Client-Integrity'],
      );
      expect(acquisitions, 1);

      await manager.headersFor(
        clientId: 'client-b',
        channelLogin: 'alpha',
        viewerAuth: null,
      );
      expect(acquisitions, 2);
      expect(
        manager.cachedHeadersFor(clientId: 'client-a', viewerAuth: null),
        isNotNull,
      );
      expect(
        manager.cachedHeadersFor(clientId: 'client-b', viewerAuth: null),
        isNotNull,
      );

      clock = clock.add(const Duration(minutes: 6));
      expect(
        manager.cachedHeadersFor(clientId: 'client-a', viewerAuth: null),
        isNull,
      );
      await manager.headersFor(
        clientId: 'client-a',
        channelLogin: 'alpha',
        viewerAuth: null,
      );
      expect(acquisitions, 3);
    },
  );

  for (final clearWhilePending in <bool>[false, true]) {
    test(
      clearWhilePending
          ? 'Clear rejects every waiter of a pending acquisition'
          : 'Expired acquisition is rejected by every waiter',
      () async {
        final clock = DateTime.utc(2026, 10, 11);
        final gate = Completer<TwitchPlaybackIntegrityContext>();
        final manager = TwitchPlaybackIntegrityManager(
          now: () => clock,
          acquire:
              ({
                required clientId,
                required channelLogin,
                required viewerAuth,
              }) => gate.future,
        );
        final first = manager.headersFor(
          clientId: 'web-client',
          channelLogin: 'alpha',
          viewerAuth: null,
        );
        final joined = manager.headersFor(
          clientId: 'web-client',
          channelLogin: 'beta',
          viewerAuth: null,
        );
        final assertions = Future.wait<void>([
          expectLater(first, throwsStateError),
          expectLater(joined, throwsStateError),
        ]);
        if (clearWhilePending) manager.clear();
        gate.complete(
          context(
            clientId: 'web-client',
            token: 'fixture-proof',
            expiresAt: clock.add(
              Duration(seconds: clearWhilePending ? 300 : 10),
            ),
          ),
        );
        await assertions;
        expect(
          manager.cachedHeadersFor(clientId: 'web-client', viewerAuth: null),
          isNull,
        );
      },
    );
  }

  test('Late rejection cannot invalidate a newer proof', () async {
    final clock = DateTime.utc(2026, 10, 10, 12);
    var acquisitions = 0;
    final manager = TwitchPlaybackIntegrityManager(
      now: () => clock,
      acquire:
          ({
            required clientId,
            required channelLogin,
            required viewerAuth,
          }) async => context(
            clientId: clientId,
            token: 'proof-${++acquisitions}',
            expiresAt: clock.add(const Duration(minutes: 5)),
            identityKey: viewerAuth?.identityKey ?? 'anonymous',
          ),
    );
    final first = await manager.headersFor(
      clientId: 'client-a',
      channelLogin: 'alpha',
      viewerAuth: null,
    );
    manager.invalidateRejected(
      clientId: 'client-a',
      viewerAuth: null,
      rejectedIntegrity: first['Client-Integrity']!,
    );
    final second = await manager.headersFor(
      clientId: 'client-a',
      channelLogin: 'alpha',
      viewerAuth: null,
    );
    manager.invalidateRejected(
      clientId: 'client-a',
      viewerAuth: null,
      rejectedIntegrity: first['Client-Integrity']!,
    );
    expect(
      manager.cachedHeadersFor(clientId: 'client-a', viewerAuth: null),
      second,
    );
  });
}
