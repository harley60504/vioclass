// Explicit opt-in only. Never log credentials or mutate the saved session.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vioclass/app.dart';
import 'package:vioclass/features/twitch/api/auth/twitch_auth_api_service.dart';
import 'package:vioclass/features/twitch/api/core/twitch_api_client.dart';
import 'package:vioclass/features/twitch/models/auth/twitch_auth_token.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_stream_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_following_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_browse_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_stream_home_models.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_linked_login_page.dart';
import 'package:vioclass/features/twitch/presentation/widgets/home/twitch_stream_home_toolbar.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_auth_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_drops_auth_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_web_gql_auth_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_viewer_session.dart';
import 'package:vioclass/features/twitch/services/discovery/twitch_discovery_service.dart';
import 'package:vioclass/features/twitch/services/discovery/twitch_guest_discovery_service.dart';

class _ReadOnlyValidation extends TwitchAuthApiService {
  _ReadOnlyValidation(TwitchApiClient client) : super(client: client);
  @override
  Future<TwitchTokenValidation> validateToken(String accessToken) async {
    final actual = await super.validateToken(accessToken);
    // Limit this test to homepage reads; do not start whisper/chat consumers.
    return TwitchTokenValidation(
      clientId: actual.clientId,
      login: actual.login,
      userId: actual.userId,
      expiresIn: actual.expiresIn,
      scopes: actual.scopes
          .where((scope) => scope == 'user:read:follows')
          .toList(),
    );
  }
}

class _ReadOnlyAuth extends TwitchAuthService {
  _ReadOnlyAuth(TwitchApiClient client, this.savedToken, this.savedClientId)
    : super(apiClient: client);
  late final TwitchAuthApiService _readOnlyApi = _ReadOnlyValidation(apiClient);
  @override
  TwitchAuthApiService get authApi => _readOnlyApi;
  final TwitchAuthToken? savedToken;
  final String? savedClientId;
  int loads = 0;
  @override
  TwitchAuthToken? get token => savedToken;
  @override
  String? get clientId => savedClientId;
  @override
  bool get hasStoredToken => savedToken != null;
  @override
  bool get isLoggedIn => accessToken != null;
  @override
  String? get accessToken =>
      savedToken?.isExpired == false ? savedToken!.accessToken : null;
  @override
  Future<void> loadStoredSession({bool refreshIfNeeded = true}) async {
    loads++;
  }

  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async =>
      accessToken;
}

class _NoStoredDrops extends TwitchDropsAuthService {
  _NoStoredDrops(TwitchApiClient client) : super(apiClient: client);
  @override
  Future<void> loadStoredSession() async {}
  @override
  Future<String?> getToken() async => null;
}

class _NoStoredWeb extends TwitchWebGqlAuthService {
  _NoStoredWeb(TwitchApiClient client) : super(apiClient: client);
  @override
  Future<void> loadStoredSession({
    bool migrateLegacyDropsWebToken = true,
  }) async {}
  @override
  Future<String?> getToken() async => null;
}

void main() {
  TwitchAuthToken? storedSnapshot;
  String? storedClientId;
  var capturedStorage = false;
  const optIn = bool.fromEnvironment('VIOCLASS_READONLY_STORED_SESSION');
  if (!optIn) {
    throw StateError('Explicit read-only stored-session opt-in required');
  }
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Native read-only stored homepage identity and root remount', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(TwitchAuthService.tokenStorageKey);
    final savedClientId = prefs.getString(TwitchAuthService.clientIdStorageKey);
    TwitchAuthToken? saved;
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final parsed = TwitchAuthToken.fromJson(decoded);
          if (parsed.accessToken.trim().isNotEmpty) {
            saved = TwitchAuthToken(
              accessToken: parsed.accessToken,
              refreshToken: '',
              tokenType: parsed.tokenType,
              expiresIn: parsed.expiresIn,
              obtainedAt: parsed.obtainedAt,
              scopes: parsed.scopes
                  .where((scope) => scope == 'user:read:follows')
                  .toList(),
            );
          }
        }
      } catch (_) {
        // Do not repair or remove malformed real storage.
      }
    }
    // All subsequent preference writes stay in the test process, not on disk.
    storedSnapshot = saved;
    storedClientId = savedClientId;
    capturedStorage = true;
    SharedPreferences.setMockInitialValues({
      'vioclass_auto_check_updates_v1': false,
    });
    var followedReads = 0;
    var allowedGets = 0;
    var blockedNonReads = 0;
    var watchCreations = 0;
    TwitchHomeSection? firstSection;
    final clients = <TwitchApiClient>[];
    try {
      for (var phase = 0; phase < 2; phase++) {
        final client = TwitchApiClient();
        clients.add(client);
        client.dio.options.connectTimeout = const Duration(seconds: 5);
        client.dio.options.receiveTimeout = const Duration(seconds: 5);
        client.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final uri = options.uri;
              final allowed =
                  options.method == 'GET' &&
                  ((uri.host == 'id.twitch.tv' &&
                          uri.path == '/oauth2/validate') ||
                      (uri.host == 'api.twitch.tv' &&
                          const [
                            '/helix/streams/followed',
                            '/helix/users',
                            '/helix/channels/followed',
                          ].contains(uri.path)));
              if (!allowed) {
                blockedNonReads++;
                handler.reject(
                  DioException(
                    requestOptions: options,
                    error: StateError(
                      'Read-only test blocked non-whitelisted request',
                    ),
                  ),
                );
                return;
              }
              allowedGets++;
              if (uri.path == '/helix/streams/followed') followedReads++;
              handler.next(options);
            },
          ),
        );
        final auth = _ReadOnlyAuth(client, saved, savedClientId);
        final validation = _ReadOnlyValidation(client);
        final discovery = TwitchDiscoveryService(
          client: client,
          authService: auth,
          authApi: validation,
          guestDiscoveryService: TwitchGuestDiscoveryService(
            client: client,
            requestOverride:
                ({
                  required operationName,
                  required variables,
                  required query,
                }) async => {
                  'data': {
                    'streams': {
                      'edges': [],
                      'pageInfo': {'hasNextPage': false},
                    },
                  },
                },
          ),
        );
        await tester.pumpWidget(
          VioClassApp(
            homeServices: TwitchStreamPageServices(
              apiClient: client,
              authService: auth,
              authApi: validation,
              dropsAuthService: _NoStoredDrops(client),
              webGqlAuthService: _NoStoredWeb(client),
              discoveryService: discovery,
              watchServicesFactory: () {
                watchCreations++;
                throw StateError('Playback is excluded');
              },
            ),
          ),
        );
        final deadline = DateTime.now().add(const Duration(seconds: 40));
        while ((find.byType(TwitchStreamPage).evaluate().isEmpty ||
                auth.loads == 0 ||
                discovery.viewerSession.status ==
                    TwitchViewerStatus.checking) &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(TwitchStreamPage), findsOneWidget);
        expect(auth.loads, 1);
        expect(
          discovery.viewerSession.status,
          isNot(TwitchViewerStatus.checking),
        );
        final canFollow =
            discovery.viewerSession.snapshot?.canReadFollows ?? false;
        final dynamic home = tester.state(find.byType(TwitchStreamPage));
        expect(
          home.selectedSection,
          canFollow ? TwitchHomeSection.following : TwitchHomeSection.browse,
        );
        if (phase == 0) {
          firstSection = home.selectedSection as TwitchHomeSection;
        }
        expect(home.selectedSection, firstSection);
        expect(find.byType(TwitchLinkedLoginPage), findsNothing);
        expect(watchCreations, 0);
        expect(tester.takeException(), isNull);
        debugPrint(
          '[ReadOnlyHome] phase=$phase saved=${saved != null} unexpired=${auth.accessToken != null} '
          'authenticated=${discovery.viewerSession.status == TwitchViewerStatus.authenticated} follows=$canFollow '
          'section=${home.selectedSection} allowedGets=$allowedGets followedReads=$followedReads blocked=$blockedNonReads playback=0',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 400));
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      for (final client in clients) {
        client.close(force: true);
      }
    }
  });
  testWidgets('Native read-only completed followed feed and section navigation', (
    tester,
  ) async {
    expect(
      capturedStorage,
      true,
      reason: 'Run the complete opt-in native suite to read storage once',
    );
    final client = TwitchApiClient();
    var responses = 0;
    var blocked = 0;
    var watchCreations = 0;
    client.dio.options.connectTimeout = const Duration(seconds: 5);
    client.dio.options.receiveTimeout = const Duration(seconds: 5);
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final uri = options.uri;
          final allowed =
              options.method == 'GET' &&
              ((uri.host == 'id.twitch.tv' && uri.path == '/oauth2/validate') ||
                  (uri.host == 'api.twitch.tv' &&
                      const [
                        '/helix/streams/followed',
                        '/helix/users',
                        '/helix/channels/followed',
                        '/helix/streams',
                        '/helix/games',
                        '/helix/games/top',
                      ].contains(uri.path)));
          if (!allowed) {
            blocked++;
            handler.reject(
              DioException(
                requestOptions: options,
                error: StateError(
                  'Read-only test blocked non-whitelisted request',
                ),
              ),
            );
          } else {
            handler.next(options);
          }
        },
        onResponse: (response, handler) {
          if (response.requestOptions.uri.path == '/helix/streams/followed') {
            responses++;
          }
          handler.next(response);
        },
      ),
    );
    final auth = _ReadOnlyAuth(client, storedSnapshot, storedClientId);
    final validation = _ReadOnlyValidation(client);
    final discovery = TwitchDiscoveryService(
      client: client,
      authService: auth,
      authApi: validation,
    );
    Future<void> waitFor(bool Function() ready, String reason) async {
      final deadline = DateTime.now().add(const Duration(seconds: 40));
      while (!ready() && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(ready(), true, reason: reason);
    }

    try {
      await tester.pumpWidget(
        VioClassApp(
          homeServices: TwitchStreamPageServices(
            apiClient: client,
            authService: auth,
            authApi: validation,
            discoveryService: discovery,
            dropsAuthService: _NoStoredDrops(client),
            webGqlAuthService: _NoStoredWeb(client),
            watchServicesFactory: () {
              watchCreations++;
              throw StateError('Playback is excluded');
            },
          ),
        ),
      );
      await waitFor(
        () => find.byType(TwitchFollowingPage).evaluate().isNotEmpty,
        'real validated followed scope selects the following page',
      );
      await waitFor(() {
        final dynamic page = tester.state(find.byType(TwitchFollowingPage));
        return !page.loadingFirstPage;
      }, 'followed feed finishes its initial read');
      final dynamic followed = tester.state(find.byType(TwitchFollowingPage));
      expect(
        followed.errorText == null,
        true,
        reason: 'followed API read must succeed',
      );
      expect(responses, greaterThan(0));
      final dynamic home = tester.state(find.byType(TwitchStreamPage));
      final identity = discovery.viewerSession.snapshot;
      expect(identity != null, true);
      await tester.tap(
        find
            .descendant(
              of: find.byType(TwitchStreamHomeToolbar),
              matching: find.byIcon(TwitchHomeSection.browse.icon),
            )
            .hitTestable()
            .first,
      );
      await waitFor(
        () => find.byType(TwitchBrowsePage).evaluate().isNotEmpty,
        'browse section opens',
      );
      await waitFor(() {
        final dynamic page = tester.state(find.byType(TwitchBrowsePage));
        return !page.loadingFirstPage;
      }, 'public browse feed completes');
      final dynamic browse = tester.state(find.byType(TwitchBrowsePage));
      expect(
        browse.errorText == null,
        true,
        reason: 'browse API read must succeed',
      );
      expect(home.selectedSection, TwitchHomeSection.browse);
      expect(tester.state(find.byType(TwitchStreamPage)), same(home));
      await tester.tap(
        find
            .descendant(
              of: find.byType(TwitchStreamHomeToolbar),
              matching: find.byIcon(TwitchHomeSection.following.icon),
            )
            .hitTestable()
            .first,
      );
      await waitFor(
        () => find.byType(TwitchFollowingPage).evaluate().isNotEmpty,
        'following section returns',
      );
      await waitFor(() {
        final dynamic page = tester.state(find.byType(TwitchFollowingPage));
        return !page.loadingFirstPage;
      }, 'return to following finishes its read');
      expect(home.selectedSection, TwitchHomeSection.following);
      expect(
        discovery.viewerSession.snapshot?.viewerId == identity?.viewerId,
        true,
      );
      expect(find.byType(TwitchLinkedLoginPage), findsNothing);
      expect(watchCreations, 0);
      expect(tester.takeException(), isNull);
      debugPrint(
        '[ReadOnlyHomeNavigation] followResponses=$responses blocked=$blocked '
        'sameHome=true sameViewer=true browseCompleted=true returnedFollowing=true playback=0',
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 400));
      client.close(force: true);
    }
  });
}
