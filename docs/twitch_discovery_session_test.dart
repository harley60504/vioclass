// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../lib/features/twitch/presentation/pages/twitch_following_page.dart';
import '../lib/features/twitch/presentation/pages/twitch_browse_page.dart';
import '../lib/features/twitch/presentation/widgets/shared/twitch_login_required_view.dart';
import '../lib/features/twitch/presentation/localization/vioclass_localizations.dart';

import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/core/twitch_api_exception.dart';
import '../lib/features/twitch/services/auth/twitch_auth_service.dart';
import '../lib/features/twitch/services/auth/twitch_viewer_session.dart';
import '../lib/features/twitch/services/discovery/twitch_discovery_service.dart';
import '../lib/features/twitch/services/discovery/twitch_guest_discovery_service.dart';

class _Session extends TwitchAuthService {
  String? currentToken = 'first';
  _Session(TwitchApiClient client) : super(apiClient: client);
  @override
  String? get accessToken => currentToken;
  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async =>
      currentToken;
  void changeToken(String? token) {
    currentToken = token;
    notifyListeners();
  }
}

class _Validation extends TwitchAuthApiService {
  int calls = 0;
  Completer<TwitchTokenValidation>? pending;
  TwitchApiException? failure;
  TwitchTokenValidation? responseOverride;
  final pendingByToken = <String, Completer<TwitchTokenValidation>>{};
  _Validation(TwitchApiClient client) : super(client: client);
  @override
  Future<TwitchTokenValidation> validateToken(String accessToken) async {
    calls++;
    if (failure != null) throw failure!;
    if (pendingByToken.containsKey(accessToken)) {
      return pendingByToken[accessToken]!.future;
    }
    if (pending != null) return pending!.future;
    return responseOverride ??
        const TwitchTokenValidation(
          clientId: 'client',
          login: 'viewer',
          userId: '42',
          scopes: ['user:read:follows'],
          expiresIn: 3600,
        );
  }
}

void main() {
  late TwitchApiClient client;
  late _Session session;
  late _Validation validation;
  late TwitchDiscoveryService service;
  late List<RequestOptions> requests;
  late List<String> guestOperations;
  late List<Map<String, dynamic>> followedRows;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('vio_class/background_receiving'),
          (_) async => null,
        );
    followedRows = [];
    requests = [];
    guestOperations = [];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'data': options.path.endsWith('/streams/followed')
                    ? followedRows
                    : <dynamic>[],
                'pagination': <String, dynamic>{},
              },
            ),
          );
        },
      ),
    );
    client = TwitchApiClient(dio: dio);
    session = _Session(client);
    validation = _Validation(client);
    service = TwitchDiscoveryService(
      client: client,
      authService: session,
      authApi: validation,
      guestDiscoveryService: TwitchGuestDiscoveryService(
        client: client,
        requestOverride:
            ({
              required operationName,
              required query,
              required variables,
            }) async {
              guestOperations.add(operationName);
              return {
                'data': {
                  'streams': {
                    'edges': [
                      {
                        'node': {
                          'id': 'public-stream',
                          'title': 'Public fixture stream',
                          'viewersCount': 12,
                          'broadcaster': {
                            'id': 'public-user',
                            'login': 'public_fixture',
                            'displayName': 'Public Fixture',
                          },
                        },
                      },
                    ],
                    'pageInfo': {'hasNextPage': false},
                  },
                },
              };
            },
      ),
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('vio_class/background_receiving'),
          null,
        );
    client.close(force: true);
  });

  test(
    'Following, rail and notification readers share one fresh transport request',
    () async {
      await Future.wait<Object>([
        service.fetchFollowedStreams(),
        service.fetchFollowedStreams(),
        service.fetchFollowedLiveRailStreams(),
      ]);
      expect(
        requests.where((request) => request.path.endsWith('/streams/followed')),
        hasLength(1),
      );
      await service.fetchFollowedStreams();
      expect(
        requests.where((request) => request.path.endsWith('/streams/followed')),
        hasLength(1),
      );
      service.clearFollowedLiveRailCache();
      await service.fetchFollowedStreams();
      expect(
        requests.where((request) => request.path.endsWith('/streams/followed')),
        hasLength(2),
      );
    },
  );

  for (final checking in [false, true]) {
    testWidgets(
      'Public browse page remains available while checking=$checking',
      (tester) async {
        Future<TwitchViewerAuthSnapshot?>? resolving;
        if (checking) {
          validation.pending = Completer<TwitchTokenValidation>();
          resolving = service.resolveViewerAuthOrNull();
        } else {
          session.currentToken = null;
        }
        var loginCalls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TwitchBrowsePage(
                discoveryService: service,
                searchText: '',
                searchedLiveStreams: const [],
                searchedOfflineChannels: const [],
                loadingChannelSearch: false,
                channelSearchError: null,
                reloadTick: 0,
                onLoginPressed: () async {
                  loginCalls++;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final state = tester.state<TwitchBrowsePageState>(
          find.byType(TwitchBrowsePage),
        );
        await state.refreshStreams(clearExisting: true);
        await tester.pumpAndSettle();
        expect(state.loadingFirstPage, isFalse);
        expect(state.errorText, isNull);
        expect(state.loadedStreams.single.channelLogin, 'public_fixture');
        expect(guestOperations, contains('VioClassGuestBrowse'));
        expect(find.byType(TwitchLoginRequiredView), findsNothing);
        expect(requests, isEmpty);
        expect(loginCalls, 0);
        expect(validation.calls, checking ? 1 : 0);
        if (checking) {
          expect(service.viewerSession.status, TwitchViewerStatus.checking);
          validation.pending!.complete(
            const TwitchTokenValidation(
              clientId: 'client',
              login: 'viewer',
              userId: '42',
              scopes: ['user:read:follows'],
              expiresIn: 3600,
            ),
          );
          await resolving;
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  Future<void> mountFollowing(
    WidgetTester tester,
    VoidCallback onLogin, {
    int reloadTick = 0,
    Locale? locale,
  }) => tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: locale == null ? const [Locale('en')] : [locale],
      localizationsDelegates: locale == null
          ? null
          : const [VioClassLocalizations.delegate],
      home: Scaffold(
        body: TwitchFollowingPage(
          discoveryService: service,
          searchText: '',
          searchedLiveStreams: const [],
          searchedOfflineChannels: const [],
          loadingChannelSearch: false,
          channelSearchError: null,
          reloadTick: reloadTick,
          onLoginPressed: () async => onLogin(),
        ),
      ),
    ),
  );

  for (final guest in [true, false]) {
    for (final reload in [true, false]) {
      testWidgets(
        'Following same service clears private cards after identity loses access guest=$guest reload=$reload',
        (tester) async {
          followedRows = [
            {
              'id': 'private-stream',
              'user_id': 'private-user',
              'user_login': 'private_fixture',
              'user_name': 'Private Fixture',
              'title': 'Private following fixture',
              'type': 'live',
              'viewer_count': 12,
              'language': 'en',
            },
          ];
          var loginCalls = 0;
          await mountFollowing(tester, () => loginCalls++);
          await tester.pumpAndSettle();
          final state = tester.state<TwitchFollowingPageState>(
            find.byType(TwitchFollowingPage),
          );
          expect(state.loadedStreams.single.channelLogin, 'private_fixture');
          requests.clear();
          validation.responseOverride = const TwitchTokenValidation(
            clientId: 'client',
            login: 'other',
            userId: '99',
            scopes: [],
            expiresIn: 3600,
          );
          session.changeToken(guest ? null : 'other-without-follows');
          if (reload) {
            await mountFollowing(tester, () => loginCalls++, reloadTick: 1);
          }
          await tester.pumpAndSettle();
          expect(tester.state(find.byType(TwitchFollowingPage)), same(state));
          expect(state.loadedStreams, isEmpty);
          expect(state.offlineFollowedChannels, isEmpty);
          expect(find.byType(TwitchLoginRequiredView), findsOneWidget);
          expect(
            find.text(guest ? '需要登入 Twitch' : '已登入，但缺少追隨權限'),
            findsOneWidget,
          );
          expect(find.text(guest ? '用 WebView 登入' : '重新授權'), findsOneWidget);
          expect(requests, isEmpty);
          expect(loginCalls, 0);
          expect(
            service.viewerSession.status,
            guest ? TwitchViewerStatus.guest : TwitchViewerStatus.authenticated,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('Following guest to authenticated reads without a home reload', (
    tester,
  ) async {
    session.currentToken = null;
    var loginCalls = 0;
    await mountFollowing(tester, () => loginCalls++);
    await tester.pumpAndSettle();
    final state = tester.state<TwitchFollowingPageState>(
      find.byType(TwitchFollowingPage),
    );
    expect(find.byType(TwitchLoginRequiredView), findsOneWidget);
    session.changeToken('new-fixture');
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(TwitchFollowingPage)), same(state));
    expect(service.viewerSession.status, TwitchViewerStatus.authenticated);
    expect(requests, isNotEmpty);
    expect(find.byType(TwitchLoginRequiredView), findsNothing);
    expect(find.text('目前追隨頻道沒有直播'), findsOneWidget);
    expect(loginCalls, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Following initial pending identity switch reads new account before old completes',
    (tester) async {
      final oldValidation = Completer<TwitchTokenValidation>();
      validation.pendingByToken['first'] = oldValidation;
      validation.responseOverride = const TwitchTokenValidation(
        clientId: 'client',
        login: 'new_viewer',
        userId: '99',
        scopes: ['user:read:follows'],
        expiresIn: 3600,
      );
      var loginCalls = 0;
      await mountFollowing(tester, () => loginCalls++);
      await tester.pump(const Duration(milliseconds: 100));
      expect(validation.calls, 1);
      expect(requests, isEmpty);
      session.changeToken('new-fixture');
      await tester.pumpAndSettle();
      expect(oldValidation.isCompleted, isFalse);
      expect(service.viewerSession.snapshot?.viewerId, '99');
      expect(requests, isNotEmpty);
      expect(
        requests.where((request) => request.path.endsWith('/streams/followed')),
        everyElement(
          predicate<RequestOptions>(
            (request) => request.queryParameters['user_id'] == '99',
          ),
        ),
      );
      oldValidation.complete(
        const TwitchTokenValidation(
          clientId: 'client',
          login: 'old_viewer',
          userId: '42',
          scopes: ['user:read:follows'],
          expiresIn: 3600,
        ),
      );
      await tester.pumpAndSettle();
      expect(service.viewerSession.snapshot?.viewerId, '99');
      expect(find.byType(TwitchLoginRequiredView), findsNothing);
      expect(find.text('目前追隨頻道沒有直播'), findsOneWidget);
      expect(loginCalls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Following initial pending logout becomes guest before old validation completes',
    (tester) async {
      final oldValidation = Completer<TwitchTokenValidation>();
      validation.pendingByToken['first'] = oldValidation;
      var loginCalls = 0;
      await mountFollowing(tester, () => loginCalls++);
      await tester.pump(const Duration(milliseconds: 100));
      expect(service.viewerSession.status, TwitchViewerStatus.checking);
      session.changeToken(null);
      await tester.pumpAndSettle();
      expect(oldValidation.isCompleted, isFalse);
      expect(service.viewerSession.status, TwitchViewerStatus.guest);
      expect(find.byType(TwitchLoginRequiredView), findsOneWidget);
      expect(requests, isEmpty);
      oldValidation.complete(
        const TwitchTokenValidation(
          clientId: 'client',
          login: 'old_viewer',
          userId: '42',
          scopes: ['user:read:follows'],
          expiresIn: 3600,
        ),
      );
      await tester.pumpAndSettle();
      expect(service.viewerSession.status, TwitchViewerStatus.guest);
      expect(find.byType(TwitchLoginRequiredView), findsOneWidget);
      expect(requests, isEmpty);
      expect(loginCalls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'Identity revision distinguishes replacement from validation completion',
    () async {
      final initial = service.viewerSession.identityRevision;
      await service.resolveViewerAuthOrNull();
      expect(service.viewerSession.identityRevision, initial);
      session.changeToken('new-fixture');
      final replaced = service.viewerSession.identityRevision;
      expect(replaced, greaterThan(initial));
      await service.resolveViewerAuthOrNull();
      expect(service.viewerSession.identityRevision, replaced);
      service.clearViewerAuthCache();
      expect(service.viewerSession.identityRevision, greaterThan(replaced));
    },
  );

  testWidgets(
    'Following page waits for real session validation without prompting login',
    (tester) async {
      var loginCalls = 0;
      validation.pending = Completer<TwitchTokenValidation>();
      await mountFollowing(tester, () => loginCalls++);
      await tester.pump(const Duration(milliseconds: 100));
      expect(validation.calls, 1);
      expect(requests, isEmpty);
      expect(service.viewerSession.status, TwitchViewerStatus.checking);
      expect(find.byType(TwitchLoginRequiredView), findsNothing);
      expect(loginCalls, 0);
      validation.pending!.complete(
        const TwitchTokenValidation(
          clientId: 'client',
          login: 'viewer',
          userId: '42',
          scopes: ['user:read:follows'],
          expiresIn: 3600,
        ),
      );
      await tester.pumpAndSettle();
      expect(service.viewerSession.status, TwitchViewerStatus.authenticated);
      expect(requests, isNotEmpty);
      expect(find.byType(TwitchLoginRequiredView), findsNothing);
      expect(find.text('目前追隨頻道沒有直播'), findsOneWidget);
      expect(loginCalls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Guest following page requests login only on an explicit action',
    (tester) async {
      session.currentToken = null;
      var loginCalls = 0;
      await mountFollowing(tester, () => loginCalls++);
      await tester.pumpAndSettle();
      expect(service.viewerSession.status, TwitchViewerStatus.guest);
      expect(validation.calls, 0);
      expect(requests, isEmpty);
      expect(find.byType(TwitchLoginRequiredView), findsOneWidget);
      expect(loginCalls, 0);
      await tester.tap(find.text('用 WebView 登入'));
      await tester.pump();
      expect(loginCalls, 1);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Following missing scope stays authenticated and explicit retry reads after grant',
    (tester) async {
      validation.responseOverride = const TwitchTokenValidation(
        clientId: 'client',
        login: 'viewer',
        userId: '42',
        scopes: [],
        expiresIn: 3600,
      );
      var loginCalls = 0;
      await mountFollowing(tester, () => loginCalls++);
      await tester.pumpAndSettle();
      expect(service.viewerSession.status, TwitchViewerStatus.authenticated);
      expect(requests, isEmpty);
      expect(find.byType(TwitchLoginRequiredView), findsOneWidget);
      expect(find.text('已登入，但缺少追隨權限'), findsOneWidget);
      expect(find.text('需要登入 Twitch'), findsNothing);
      expect(loginCalls, 0);
      await tester.tap(find.text('重新授權'));
      await tester.pump();
      expect(loginCalls, 1);
      expect(requests, isEmpty);
      validation.responseOverride = const TwitchTokenValidation(
        clientId: 'client',
        login: 'viewer',
        userId: '42',
        scopes: ['user:read:follows'],
        expiresIn: 3600,
      );
      session.changeToken('fixture-granted');
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      expect(service.viewerSession.status, TwitchViewerStatus.authenticated);
      expect(requests, isNotEmpty);
      expect(find.byType(TwitchLoginRequiredView), findsNothing);
      expect(find.text('目前追隨頻道沒有直播'), findsOneWidget);
      expect(loginCalls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Following missing scope English prompt does not call it logout',
    (tester) async {
      validation.responseOverride = const TwitchTokenValidation(
        clientId: 'client',
        login: 'viewer',
        userId: '42',
        scopes: [],
        expiresIn: 3600,
      );
      var loginCalls = 0;
      await mountFollowing(
        tester,
        () => loginCalls++,
        locale: const Locale('en'),
      );
      await tester.pumpAndSettle();
      expect(service.viewerSession.status, TwitchViewerStatus.authenticated);
      expect(requests, isEmpty);
      expect(
        find.text('Signed in, but missing follow-read permission'),
        findsOneWidget,
      );
      expect(find.text('Twitch sign-in required'), findsNothing);
      await tester.tap(find.text('Authorize again'));
      await tester.pump();
      expect(loginCalls, 1);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final channels in [false, true]) {
    for (final guest in [false, true]) {
      test(
        'Followed read blocked before transport: channels=$channels guest=$guest',
        () async {
          session.currentToken = guest ? null : 'first';
          validation.responseOverride = const TwitchTokenValidation(
            clientId: 'client',
            login: 'viewer',
            userId: '42',
            scopes: [],
            expiresIn: 3600,
          );
          await expectLater(
            channels
                ? service.fetchFollowedChannels()
                : service.fetchFollowedStreams(),
            throwsA(isA<TwitchApiException>()),
          );
          expect(requests, isEmpty);
          expect(validation.calls, guest ? 0 : 1);
          expect(
            service.viewerSession.status,
            guest ? TwitchViewerStatus.guest : TwitchViewerStatus.authenticated,
          );
          if (!guest) {
            expect(service.cachedAuth?.canReadFollows, isFalse);
            expect(session.currentToken, 'first');
          }
        },
      );
    }

    test(
      'Logout while followed read validates cannot dispatch: channels=$channels',
      () async {
        validation.pending = Completer<TwitchTokenValidation>();
        final read = channels
            ? service.fetchFollowedChannels()
            : service.fetchFollowedStreams();
        final assertion = expectLater(read, throwsA(isA<TwitchApiException>()));
        await Future<void>.delayed(Duration.zero);
        expect(validation.calls, 1);
        session.currentToken = null;
        validation.pending!.complete(
          const TwitchTokenValidation(
            clientId: 'client',
            login: 'viewer',
            userId: '42',
            scopes: ['user:read:follows'],
            expiresIn: 3600,
          ),
        );
        await assertion;
        expect(requests, isEmpty);
        expect(service.cachedAuth, isNull);
        expect(service.viewerSession.status, TwitchViewerStatus.guest);
      },
    );

    test(
      'Account switch during followed validation dispatches only new identity: channels=$channels',
      () async {
        final oldValidation = Completer<TwitchTokenValidation>();
        validation.pendingByToken['first'] = oldValidation;
        final oldRead = channels
            ? service.fetchFollowedChannels()
            : service.fetchFollowedStreams();
        final oldAssertion = expectLater(
          oldRead,
          throwsA(isA<TwitchApiException>()),
        );
        await Future<void>.delayed(Duration.zero);
        session.currentToken = 'second';
        validation.responseOverride = const TwitchTokenValidation(
          clientId: 'client',
          login: 'new-viewer',
          userId: '99',
          scopes: ['user:read:follows'],
          expiresIn: 3600,
        );
        if (channels) {
          await service.fetchFollowedChannels(attachProfiles: false);
        } else {
          await service.fetchFollowedStreams();
        }
        oldValidation.complete(
          const TwitchTokenValidation(
            clientId: 'client',
            login: 'old-viewer',
            userId: '42',
            scopes: ['user:read:follows'],
            expiresIn: 3600,
          ),
        );
        await oldAssertion;
        expect(requests, hasLength(1));
        expect(requests.single.queryParameters['user_id'], '99');
        expect(requests.single.headers['Authorization'], 'Bearer second');
        expect(service.cachedAuth?.viewerId, '99');
        expect(service.cachedAuth?.accessToken, 'second');
        expect(session.currentToken, 'second');
      },
    );

    test(
      'Verified followed read reaches only fake transport: channels=$channels',
      () async {
        if (channels) {
          expect(
            (await service.fetchFollowedChannels(
              attachProfiles: false,
            )).channels,
            isEmpty,
          );
        } else {
          expect((await service.fetchFollowedStreams()).streams, isEmpty);
        }
        expect(requests, hasLength(1));
        expect(requests.single.method, 'GET');
        expect(
          requests.single.uri.path,
          channels ? '/helix/channels/followed' : '/helix/streams/followed',
        );
        expect(requests.single.queryParameters['user_id'], '42');
        expect(requests.single.headers['Authorization'], 'Bearer first');
        expect(service.cachedAuth?.canReadFollows, isTrue);
      },
    );
  }

  test('logout cannot reuse the previous viewer snapshot', () async {
    expect(await service.resolveViewerAuthOrNull(), isNotNull);
    session.currentToken = null;
    expect(await service.resolveViewerAuthOrNull(), isNull);
    expect(service.cachedAuth, isNull);
  });

  test(
    'validation finishing after logout cannot restore the old account',
    () async {
      validation.pending = Completer<TwitchTokenValidation>();
      final request = service.resolveViewerAuthOrNull();
      await Future<void>.delayed(Duration.zero);
      session.currentToken = null;
      validation.pending!.complete(
        const TwitchTokenValidation(
          clientId: 'client',
          login: 'viewer',
          userId: '42',
          scopes: [],
          expiresIn: 3600,
        ),
      );
      expect(await request, isNull);
      expect(service.cachedAuth, isNull);
    },
  );

  test('public browse does not wait for token validation', () async {
    validation.pending = Completer<TwitchTokenValidation>();
    final page = await service.fetchBrowseStreams();
    expect(page.streams.single.channelLogin, 'public_fixture');
    expect(validation.calls, 0);
  });

  test('old rejected validation cannot clear the new account', () async {
    final oldValidation = Completer<TwitchTokenValidation>();
    validation.pendingByToken['first'] = oldValidation;
    final oldRequest = service.resolveViewerAuthOrNull();
    await Future<void>.delayed(Duration.zero);
    session.currentToken = 'second';
    final current = await service.resolveViewerAuthOrNull();
    expect(current?.accessToken, 'second');
    oldValidation.completeError(
      const TwitchApiException('Expired old session', statusCode: 401),
    );
    expect(await oldRequest, isNull);
    expect(service.cachedAuth, same(current));
  });

  test('old successful validation cannot replace the new account', () async {
    final oldValidation = Completer<TwitchTokenValidation>();
    validation.pendingByToken['first'] = oldValidation;
    final oldRequest = service.resolveViewerAuthOrNull();
    await Future<void>.delayed(Duration.zero);
    session.currentToken = 'second';
    final current = await service.resolveViewerAuthOrNull();
    oldValidation.complete(
      const TwitchTokenValidation(
        clientId: 'client',
        login: 'old',
        userId: 'old-id',
        scopes: [],
        expiresIn: 3600,
      ),
    );
    expect(await oldRequest, isNull);
    expect(service.cachedAuth, same(current));
  });

  test('current rejected validation invalidates its cached account', () async {
    expect(await service.resolveViewerAuthOrNull(), isNotNull);
    validation.failure = const TwitchApiException('Expired', statusCode: 401);
    expect(await service.resolveViewerAuthOrNull(forceValidate: true), isNull);
    expect(service.cachedAuth, isNull);
  });

  test('transient validation failure is not treated as logout', () async {
    final current = await service.resolveViewerAuthOrNull();
    validation.failure = const TwitchApiException(
      'Unavailable',
      statusCode: 503,
    );
    await expectLater(
      service.resolveViewerAuthOrNull(forceValidate: true),
      throwsA(isA<TwitchApiException>()),
    );
    expect(service.cachedAuth, same(current));
    expect(session.currentToken, 'first');
  });

  test('routes share one pending validation and verified identity', () async {
    final shared = TwitchViewerSession.forAuth(session);
    expect(shared.status, TwitchViewerStatus.checking);
    validation.pending = Completer<TwitchTokenValidation>();
    final home = shared.resolve(validation);
    final watch = TwitchViewerSession.forAuth(session).resolve(validation);
    await Future<void>.delayed(Duration.zero);
    expect(validation.calls, 1);
    validation.pending!.complete(
      const TwitchTokenValidation(
        clientId: 'client',
        login: 'viewer',
        userId: '42',
        scopes: ['user:read:follows'],
        expiresIn: 3600,
      ),
    );
    expect(await watch, same(await home));
    expect(shared.status, TwitchViewerStatus.authenticated);
    await shared.resolve(validation);
    expect(validation.calls, 1);
    session.currentToken = null;
    expect(shared.status, TwitchViewerStatus.guest);
    expect(shared.snapshot, isNull);
    expect(shared.hasAccount, isFalse);
  });

  test('rejected stored token is guest across every consumer', () async {
    validation.failure = const TwitchApiException('Rejected', statusCode: 403);
    final shared = TwitchViewerSession.forAuth(session);
    expect(await shared.resolve(validation), isNull);
    expect(shared.status, TwitchViewerStatus.guest);
    expect(shared.hasAccount, isFalse);
    expect(session.currentToken, 'first'); // Storage is deliberately untouched.
    session.currentToken = 'second';
    expect(shared.status, TwitchViewerStatus.checking);
    expect(shared.snapshot, isNull);
  });

  for (final rejected in [false, true]) {
    test(
      'logout notification stays guest after late validation: $rejected',
      () async {
        final shared = TwitchViewerSession.forAuth(session);
        final statuses = <TwitchViewerStatus>[];
        void observe() => statuses.add(shared.status);
        shared.addListener(observe);
        addTearDown(() => shared.removeListener(observe));
        final gate = Completer<TwitchTokenValidation>();
        validation.pendingByToken['first'] = gate;
        final pending = shared.resolve(validation);
        await Future<void>.delayed(Duration.zero);
        expect(validation.calls, 1);
        session.changeToken(null);
        expect(statuses, [TwitchViewerStatus.guest]);
        expect(shared.snapshot, isNull);
        if (rejected) {
          gate.completeError(
            const TwitchApiException('old fixture rejected', statusCode: 401),
          );
        } else {
          gate.complete(
            const TwitchTokenValidation(
              clientId: 'fixture',
              login: 'old',
              userId: 'old-id',
              scopes: [],
              expiresIn: 3600,
            ),
          );
        }
        expect(await pending, isNull);
        expect(statuses, [TwitchViewerStatus.guest]);
        expect(shared.status, TwitchViewerStatus.guest);
        expect(shared.snapshot, isNull);
        expect(shared.hasAccount, isFalse);
      },
    );
  }
  test('account notification clears identity before revalidation', () async {
    final shared = TwitchViewerSession.forAuth(session);
    await shared.resolve(validation);
    final snapshots = <TwitchViewerAuthSnapshot?>[];
    final statuses = <TwitchViewerStatus>[];
    void observe() {
      statuses.add(shared.status);
      snapshots.add(shared.snapshot);
    }

    shared.addListener(observe);
    addTearDown(() => shared.removeListener(observe));
    session.changeToken('second');
    expect(statuses, [TwitchViewerStatus.checking]);
    expect(snapshots, [null]);
    final current = await shared.resolve(validation);
    expect(statuses, [
      TwitchViewerStatus.checking,
      TwitchViewerStatus.authenticated,
    ]);
    expect(snapshots.last, same(current));
    expect(current?.accessToken, 'second');
    expect(validation.calls, 2);
    session.changeToken(null);
    expect(statuses.last, TwitchViewerStatus.guest);
    expect(snapshots.last, isNull);
  });
}
