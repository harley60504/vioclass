// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vioclass/app.dart';
import 'package:vioclass/features/twitch/api/auth/twitch_auth_api_service.dart';
import 'package:vioclass/features/twitch/api/core/twitch_api_client.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_stream_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_stream_home_models.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_browse_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_following_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_route_guard.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_channel_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_drops_connection_page.dart';
import 'package:vioclass/features/twitch/presentation/sheets/twitch_app_settings_sheet.dart';
import 'package:vioclass/features/twitch/presentation/widgets/notifications/twitch_app_notification_overlay.dart';
import 'package:vioclass/features/twitch/presentation/widgets/notifications/twitch_notification_card.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_linked_login_page.dart';
import 'package:vioclass/features/twitch/presentation/widgets/discovery/twitch_offline_channel_card.dart';
import 'twitch_watch_session_injection_test.dart'
    show
        IsolatedRecordedRouteFixture,
        IsolatedSignedRouteFixture,
        isolatedWatchChatRuntime;
import 'package:vioclass/features/twitch/presentation/widgets/discovery/twitch_stream_card.dart';
import 'package:vioclass/features/twitch/presentation/widgets/home/twitch_stream_home_toolbar.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_auth_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_drops_auth_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_web_gql_auth_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_viewer_session.dart';
import 'package:vioclass/features/twitch/services/notifications/twitch_app_notification_service.dart';
import 'package:vioclass/features/twitch/services/discovery/twitch_discovery_service.dart';
import 'package:vioclass/features/twitch/services/discovery/twitch_guest_discovery_service.dart';

class _Auth extends TwitchAuthService {
  String? fixtureToken;
  int loads = 0;
  _Auth(TwitchApiClient client, this.fixtureToken) : super(apiClient: client);
  @override
  String? get accessToken => fixtureToken;
  @override
  Future<void> loadStoredSession({bool refreshIfNeeded = true}) async =>
      loads++;
  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async =>
      fixtureToken;
  void changeIdentity(String? token) {
    fixtureToken = token;
    notifyListeners();
  }
}

class _Drops extends TwitchDropsAuthService {
  _Drops(TwitchApiClient client) : super(apiClient: client);
  @override
  Future<void> loadStoredSession() async {}
  @override
  Future<String?> getToken() async => null;
}

class _Web extends TwitchWebGqlAuthService {
  _Web(TwitchApiClient client) : super(apiClient: client);
  @override
  Future<void> loadStoredSession({
    bool migrateLegacyDropsWebToken = true,
  }) async {}
  @override
  Future<String?> getToken() async => null;
}

class _Validation extends TwitchAuthApiService {
  int calls = 0;
  Completer<TwitchTokenValidation>? pending;
  final bool follows;
  _Validation(TwitchApiClient client, this.follows) : super(client: client);
  @override
  Future<TwitchTokenValidation> validateToken(String accessToken) async {
    calls++;
    return pending != null ? pending!.future : value;
  }

  TwitchTokenValidation get value => TwitchTokenValidation(
    clientId: 'fixture-client',
    login: 'fixture-viewer',
    userId: 'fixture-viewer-id',
    scopes: follows ? ['user:read:follows'] : [],
    expiresIn: 3600,
  );
}

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

Map<String, dynamic> _oldSearchResult({bool multiple = false}) => {
  'data': {
    'searchFor': {
      'channels': {
        'edges': [
          if (multiple)
            {
              'item': {
                'id': 'old-user',
                'login': 'old_fixture',
                'displayName': 'Old fixture',
                'stream': {
                  'id': 'old-stream',
                  'title': 'Old fixture title',
                  'viewersCount': 1,
                  'broadcaster': {
                    'id': 'old-user',
                    'login': 'old_fixture',
                    'displayName': 'Old fixture',
                  },
                },
              },
            },
          {
            'item': {
              'id': multiple ? 'second-old-user' : 'old-user',
              'login': multiple ? 'second_old_fixture' : 'old_fixture',
              'displayName': 'Old fixture',
              'stream': {
                'id': 'old-stream',
                'title': 'Old fixture title',
                'viewersCount': 1,
                'broadcaster': {
                  'id': multiple ? 'second-old-user' : 'old-user',
                  'login': multiple ? 'second_old_fixture' : 'old_fixture',
                  'displayName': 'Old fixture',
                },
              },
            },
          },
        ],
      },
    },
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Offline grid preserves action width near column thresholds', () {
    for (final width in [276.0, 346.0, 456.0, 616.0, 956.0]) {
      final delegate =
          twitchOfflineChannelGridDelegate(width)
              as SliverGridDelegateWithFixedCrossAxisCount;
      final cardWidth =
          (width - 14 * (delegate.crossAxisCount - 1)) /
          delegate.crossAxisCount;
      expect(cardWidth, greaterThanOrEqualTo(width < 300 ? width : 300));
      expect(delegate.mainAxisExtent, 168);
    }
  });
  setUp(() {
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    SharedPreferences.setMockInitialValues({
      'vioclass_auto_check_updates_v1': false,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'getNotificationAppLaunchDetails'
          ? {'notificationLaunchedApp': false}
          : true,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['none'],
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
  });

  for (final size in [const Size(1000, 760), const Size(390, 844)]) {
    for (final mode in [
      'guest',
      'signed',
      'missing-scope',
      'checking',
      'cancel',
    ]) {
      testWidgets(
        'App startup uses isolated home dependencies mode=$mode size=$size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          debugDefaultTargetPlatformOverride = TargetPlatform.windows;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          twitchAppNotificationCenter.clear();
          addTearDown(twitchAppNotificationCenter.clear);
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          const windowChannel = MethodChannel('window_manager');
          messenger.setMockMethodCallHandler(windowChannel, (call) async {
            if (call.method == 'isMaximized' || call.method == 'isFullScreen') {
              return false;
            }
            throw StateError(
              'No native window changes during isolated startup',
            );
          });
          addTearDown(
            () => messenger.setMockMethodCallHandler(windowChannel, null),
          );
          final client = TwitchApiClient();
          addTearDown(() => client.close(force: true));
          final guest = mode == 'guest' || mode == 'cancel';
          final auth = _Auth(client, guest ? null : 'fixture-only');
          final validation = _Validation(client, mode != 'missing-scope');
          if (mode == 'checking') {
            validation.pending = Completer<TwitchTokenValidation>();
          }
          var reads = 0;
          var followedReads = 0;
          var writes = 0;
          client.dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                reads++;
                if (options.method != 'GET' && !options.path.contains('gql')) {
                  writes++;
                }
                if (options.path.endsWith('/streams/followed')) followedReads++;
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'data': options.path.endsWith('/streams/followed')
                          ? [
                              {
                                'id': 'fixture-follow-stream',
                                'user_id': 'fixture-follow-user',
                                'user_login': 'fixture_follow',
                                'user_name': 'Following Fixture',
                                'type': 'live',
                                'title': 'Following fixture title',
                                'viewer_count': 12,
                              },
                            ]
                          : <dynamic>[],
                      'pagination': <String, dynamic>{},
                    },
                  ),
                );
              },
            ),
          );
          final operations = <String>[];
          final discovery = TwitchDiscoveryService(
            client: client,
            authService: auth,
            authApi: validation,
            guestDiscoveryService: TwitchGuestDiscoveryService(
              client: client,
              requestOverride:
                  ({
                    required operationName,
                    required query,
                    required variables,
                  }) async {
                    operations.add(operationName);
                    return {
                      'data': {
                        'streams': {
                          'edges': [],
                          'pageInfo': {'hasNextPage': false},
                        },
                      },
                    };
                  },
            ),
          );
          final services = TwitchStreamPageServices(
            apiClient: client,
            authService: auth,
            authApi: validation,
            dropsAuthService: _Drops(client),
            webGqlAuthService: _Web(client),
            discoveryService: discovery,
          );
          await tester.pumpWidget(VioClassApp(homeServices: services));
          expect(find.byType(TwitchStreamPage), findsNothing);
          await tester.pump(const Duration(milliseconds: 100));
          expect(auth.loads, 0);
          if (mode == 'cancel') {
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 1));
            expect(find.byType(TwitchStreamPage), findsNothing);
            expect(auth.loads + validation.calls + reads, 0);
            expect(tester.takeException(), isNull);
            debugDefaultTargetPlatformOverride = null;
            return;
          }
          await tester.pump(const Duration(milliseconds: 300));
          for (var i = 0; i < 15; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(find.byType(TwitchStreamPage), findsOneWidget);
          expect(find.byType(TwitchAppNotificationOverlay), findsOneWidget);
          final dynamic home = tester.state(find.byType(TwitchStreamPage));
          expect(home.discoveryService, same(discovery));
          expect(find.byType(TwitchLinkedLoginPage), findsNothing);
          if (mode == 'checking') {
            expect(discovery.viewerSession.status, TwitchViewerStatus.checking);
            expect(home.selectedSection, TwitchHomeSection.browse);
            expect(followedReads, 0);
            expect(operations, contains('VioClassGuestBrowse'));
            validation.pending!.complete(validation.value);
            await tester.pumpAndSettle();
          }
          final follows = mode == 'signed' || mode == 'checking';
          expect(
            home.selectedSection,
            follows ? TwitchHomeSection.following : TwitchHomeSection.browse,
          );
          expect(
            discovery.viewerSession.status,
            guest ? TwitchViewerStatus.guest : TwitchViewerStatus.authenticated,
          );
          expect(auth.loads, 1);
          // The account-notification reader may independently validate the same
          // fake identity. It must not trigger another stored-session bootstrap.
          expect(validation.calls, guest ? 0 : inInclusiveRange(1, 2));
          expect(followedReads > 0, follows);
          expect(writes, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }
  }
  for (final size in [const Size(1000, 760), const Size(390, 844)]) {
    testWidgets(
      'Windows home actual settings and Drops entry preserve guest size=$size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        twitchAppNotificationCenter.clear();
        addTearDown(twitchAppNotificationCenter.clear);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const windowChannel = MethodChannel('window_manager');
        var windowWrites = 0;
        messenger.setMockMethodCallHandler(windowChannel, (call) async {
          if (call.method == 'isMaximized' || call.method == 'isFullScreen') {
            return false;
          }
          windowWrites++;
          throw StateError('No native window mutation allowed');
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(windowChannel, null),
        );
        final client = TwitchApiClient();
        addTearDown(() => client.close(force: true));
        final auth = _Auth(client, null);
        final validation = _Validation(client, false);
        var players = 0;
        var writes = 0;
        client.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method != 'GET' && !options.path.contains('gql')) {
                writes++;
              }
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'data': []},
                ),
              );
            },
          ),
        );
        final discovery = TwitchDiscoveryService(
          client: client,
          authService: auth,
          authApi: validation,
          guestDiscoveryService: TwitchGuestDiscoveryService(
            client: client,
            requestOverride:
                ({
                  required operationName,
                  required query,
                  required variables,
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
          MaterialApp(
            builder: (context, child) =>
                TwitchAppNotificationOverlay(child: child!),
            home: TwitchStreamPage(
              services: TwitchStreamPageServices(
                apiClient: client,
                authService: auth,
                authApi: validation,
                dropsAuthService: _Drops(client),
                webGqlAuthService: _Web(client),
                discoveryService: discovery,
                watchServicesFactory: () {
                  players++;
                  throw StateError('Utility routes must not create a player');
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final dynamic home = tester.state(find.byType(TwitchStreamPage));
        expect(home.selectedSection, TwitchHomeSection.browse);
        expect(home.viewerLabel, '未登入');
        // Windows uses the global title-bar settings icon, not the toolbar menu.
        final settings = find.byIcon(Icons.settings_rounded).first;
        await tester.tap(settings.hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(TwitchAppSettingsSheet), findsOneWidget);
        expect(find.text('未登入'), findsOneWidget);
        await tester.tap(settings.hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(TwitchAppSettingsSheet), findsNothing);
        await tester.tap(settings.hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(TwitchAppSettingsSheet), findsOneWidget);
        await tester.tap(find.byTooltip('關閉').hitTestable());
        await tester.pumpAndSettle();
        final drops = find.byTooltip('Drops 連接');
        await tester.ensureVisible(drops);
        await tester.pumpAndSettle();
        await tester.tap(drops.hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(TwitchDropsConnectionPage), findsOneWidget);
        expect(find.text('尚未取得 Drops token'), findsWidgets);
        expect(find.byType(TwitchLinkedLoginPage), findsNothing);
        // The narrow Windows toast overlaps the AppBar. Dismiss it through its
        // actual action before returning; do not bypass the overlay in the test.
        final toast = find.byType(TwitchNotificationCard);
        expect(toast, findsOneWidget);
        await tester.tap(
          find.descendant(of: toast, matching: find.byType(IconButton)).first,
        );
        await tester.pumpAndSettle();
        expect(toast, findsNothing);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(TwitchDropsConnectionPage), findsNothing);
        expect(tester.state(find.byType(TwitchStreamPage)), same(home));
        expect(home.selectedSection, TwitchHomeSection.browse);
        expect(home.viewerLabel, '未登入');
        expect(home.searchText, '');
        expect(validation.calls, 0);
        expect(players + writes + windowWrites, 0);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 9));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
  for (final size in [const Size(1000, 760), const Size(390, 844)]) {
    testWidgets('Guest offline search library and watch return size=$size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = IsolatedRecordedRouteFixture();
      addTearDown(fixture.close);
      final client = TwitchApiClient();
      addTearDown(() => client.close(force: true));
      final validation = _Validation(client, false);
      final operations = <String>[];
      final discovery = TwitchDiscoveryService(
        client: client,
        authService: fixture.authService,
        authApi: validation,
        guestDiscoveryService: TwitchGuestDiscoveryService(
          client: client,
          requestOverride:
              ({
                required operationName,
                required query,
                required variables,
              }) async {
                operations.add(operationName);
                if (operationName == 'VioClassGuestChannelSearch') {
                  return {
                    'data': {
                      'searchFor': {
                        'channels': {
                          'edges': [
                            {
                              'item': {
                                'id': 'old-user',
                                'login': 'old_fixture',
                                'displayName': 'Old fixture',
                                'stream': null,
                              },
                            },
                          ],
                        },
                      },
                    },
                  };
                }
                return {
                  'data': {
                    'streams': {
                      'edges': [],
                      'pageInfo': {'hasNextPage': false},
                    },
                    'user': {
                      'id': 'old-user',
                      'login': 'old_fixture',
                      'displayName': 'Old fixture',
                      'videos': {
                        'edges': [],
                        'pageInfo': {'hasNextPage': false},
                      },
                      'clips': {
                        'edges': [],
                        'pageInfo': {'hasNextPage': false},
                      },
                      'panels': [],
                    },
                  },
                };
              },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TwitchStreamPage(
            services: TwitchStreamPageServices(
              apiClient: client,
              authService: fixture.authService,
              authApi: validation,
              dropsAuthService: _Drops(client),
              webGqlAuthService: _Web(client),
              discoveryService: discovery,
              watchServicesFactory: fixture.createServices,
              watchChatRuntimeFactory: isolatedWatchChatRuntime,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dynamic home = tester.state(find.byType(TwitchStreamPage));
      await tester.enterText(
        find.descendant(
          of: find.byType(TwitchStreamHomeToolbar),
          matching: find.byType(EditableText),
        ),
        'old_fixture',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(home.channelSearchError, isNull);
      expect(home.searchedOfflineChannels.length, 1);
      final card = find.byType(TwitchOfflineChannelCard);
      await tester.scrollUntilVisible(
        card,
        180,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(card, findsOneWidget);
      final library = find.descendant(of: card, matching: find.text('媒體庫'));
      await tester.ensureVisible(library);
      await tester.pumpAndSettle();
      await tester.tap(library.hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(TwitchChannelPage), findsOneWidget);
      expect(
        tester
            .widget<TwitchChannelPage>(find.byType(TwitchChannelPage))
            .channel
            .channelLogin,
        'old_fixture',
      );
      expect(
        fixture.createdCount,
        0,
        reason: 'Library must not create a player.',
      );
      await tester.tap(find.byTooltip('關閉').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(TwitchChannelPage), findsNothing);
      expect(home.searchText, 'old_fixture');
      final watchButton = find.descendant(of: card, matching: find.text('觀看'));
      await tester.ensureVisible(watchButton);
      await tester.pumpAndSettle();
      await tester.tap(watchButton.hitTestable());
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final watch = tester.state<TwitchWatchPageState>(
        find.byType(TwitchWatchPage),
      );
      expect(watch.channelLogin, 'old_fixture');
      expect(watch.viewerId, isNull);
      expect(watch.chatController.isReadOnlyGuest, true);
      expect(watch.showOfflineChannelPlaceholder, true);
      expect(fixture.createdCount, 1);
      expect(watch.watchServices.authService, same(fixture.authService));
      expect(fixture.vodRequests + fixture.clipRequests, 0);
      expect(validation.calls, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('返回').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(TwitchWatchPage), findsNothing);
      expect(tester.state(find.byType(TwitchStreamPage)), same(home));
      expect(home.searchText, 'old_fixture');
      expect(operations, contains('VioClassGuestChannelVideos'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  for (final size in [const Size(1000, 760), const Size(390, 844)]) {
    testWidgets(
      'Signed default following card mounts watch and returns size=$size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = IsolatedSignedRouteFixture();
        addTearDown(fixture.close);
        final client = TwitchApiClient();
        addTearDown(() => client.close(force: true));
        var followedReads = 0;
        var writes = 0;
        client.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method != 'GET' && !options.path.contains('gql')) {
                writes++;
              }
              if (options.path.endsWith('/streams/followed')) followedReads++;
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': options.path.endsWith('/streams/followed')
                        ? [
                            {
                              'id': 'fixture-follow-stream',
                              'user_id': '7',
                              'user_login': 'fixture_follow',
                              'user_name': 'Following Fixture',
                              'type': 'live',
                              'title': 'Following fixture title',
                              'viewer_count': 12,
                            },
                          ]
                        : <dynamic>[],
                    'pagination': <String, dynamic>{},
                  },
                ),
              );
            },
          ),
        );
        final discovery = TwitchDiscoveryService(
          client: client,
          authService: fixture.authService,
          authApi: fixture.authApi,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: TwitchStreamPage(
              services: TwitchStreamPageServices(
                apiClient: client,
                authService: fixture.authService,
                authApi: fixture.authApi,
                dropsAuthService: _Drops(client),
                webGqlAuthService: _Web(client),
                discoveryService: discovery,
                watchServicesFactory: fixture.createServices,
                watchChatRuntimeFactory: fixture.createChat,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final dynamic home = tester.state(find.byType(TwitchStreamPage));
        expect(home.selectedSection, TwitchHomeSection.following);
        expect(find.byType(TwitchFollowingPage), findsOneWidget);
        expect(find.byType(TwitchStreamCard), findsOneWidget);
        await tester.tap(find.byType(TwitchStreamCard).hitTestable());
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(TwitchWatchRouteGuard), findsOneWidget);
        final watch = tester.state<TwitchWatchPageState>(
          find.byType(TwitchWatchPage),
        );
        expect(watch.channelLogin, 'fixture_follow');
        expect(watch.viewerId, '42');
        expect(watch.watchServices.authService, same(fixture.authService));
        expect(watch.loadingAuth, false);
        expect(watch.chatController.isReadOnlyGuest, false);
        expect(watch.chatController.canSendForCurrentViewer, true);
        expect(fixture.createdCount, 1);
        expect(fixture.chatConnects, 1);
        expect(tester.takeException(), isNull);
        final beforeReturn = followedReads;
        await tester.tap(find.byTooltip('返回').hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(TwitchWatchPage), findsNothing);
        expect(tester.state(find.byType(TwitchStreamPage)), same(home));
        expect(home.selectedSection, TwitchHomeSection.following);
        expect(home.searchText, '');
        expect(followedReads, beforeReturn + 1);
        await tester.runAsync(() async {
          final deadline = DateTime.now().add(const Duration(seconds: 2));
          while (fixture.chatDisposals == 0 &&
              DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        expect(fixture.chatDisposals, 1);
        expect(fixture.sends, 0);
        expect(fixture.writes + writes, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
  for (final size in [const Size(1000, 760), const Size(390, 844)]) {
    for (final search in [false, true]) {
      testWidgets(
        'Guest live card mounts watch and UI back preserves home search=$search size=$size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final fixture = IsolatedRecordedRouteFixture();
          addTearDown(fixture.close);
          final client = TwitchApiClient();
          addTearDown(() => client.close(force: true));
          final validation = _Validation(client, false);
          final operations = <String>[];
          final discovery = TwitchDiscoveryService(
            client: client,
            authService: fixture.authService,
            authApi: validation,
            guestDiscoveryService: TwitchGuestDiscoveryService(
              client: client,
              requestOverride:
                  ({
                    required operationName,
                    required variables,
                    required query,
                  }) async {
                    operations.add(operationName);
                    if (operationName == 'VioClassGuestChannelSearch') {
                      return _oldSearchResult();
                    }
                    const stream = {
                      'id': 'fixture-public-stream',
                      'title': 'Public fixture title',
                      'viewersCount': 12,
                      'broadcaster': {
                        'id': 'fixture-public-user',
                        'login': 'public_fixture',
                        'displayName': 'Public Fixture',
                      },
                    };
                    return {
                      'data': {
                        'streams': {
                          'edges': [
                            {'node': stream},
                          ],
                          'pageInfo': {'hasNextPage': false},
                        },
                      },
                    };
                  },
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: TwitchStreamPage(
                services: TwitchStreamPageServices(
                  apiClient: client,
                  authService: fixture.authService,
                  authApi: validation,
                  dropsAuthService: _Drops(client),
                  webGqlAuthService: _Web(client),
                  discoveryService: discovery,
                  watchServicesFactory: fixture.createServices,
                  watchChatRuntimeFactory: isolatedWatchChatRuntime,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final dynamic home = tester.state(find.byType(TwitchStreamPage));
          expect(home.selectedSection, TwitchHomeSection.browse);
          if (search) {
            await tester.enterText(
              find.descendant(
                of: find.byType(TwitchStreamHomeToolbar),
                matching: find.byType(EditableText),
              ),
              'old_fixture',
            );
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pumpAndSettle();
          }
          final card = find.byType(TwitchStreamCard);
          expect(card, findsOneWidget);
          await tester.ensureVisible(card);
          await tester.tap(card.hitTestable());
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(find.byType(TwitchWatchRouteGuard), findsOneWidget);
          final watch = tester.state<TwitchWatchPageState>(
            find.byType(TwitchWatchPage),
          );
          expect(watch.channelLogin, search ? 'old_fixture' : 'public_fixture');
          expect(watch.viewerId, isNull);
          expect(watch.loadingAuth, false);
          expect(watch.chatController.isReadOnlyGuest, true);
          expect(watch.watchServices.authService, same(fixture.authService));
          expect(fixture.createdCount, 1);
          expect(validation.calls, 0);
          expect(tester.takeException(), isNull);
          final refreshOperation = search
              ? 'VioClassGuestChannelSearch'
              : 'VioClassGuestBrowse';
          final beforeReturn = operations
              .where((value) => value == refreshOperation)
              .length;
          await tester.tap(find.byTooltip('返回').hitTestable());
          await tester.pumpAndSettle();
          expect(find.byType(TwitchWatchRouteGuard), findsNothing);
          expect(find.byType(TwitchWatchPage), findsNothing);
          expect(watch.mounted, false);
          expect(tester.state(find.byType(TwitchStreamPage)), same(home));
          expect(home.selectedSection, TwitchHomeSection.browse);
          expect(home.searchText, search ? 'old_fixture' : '');
          expect(
            operations.where((value) => value == refreshOperation).length,
            beforeReturn + 1,
            reason:
                'Existing return callback refreshes once while retaining the home search/section.',
          );
          expect(find.byType(TwitchStreamCard), findsOneWidget);
          expect(fixture.vodRequests, 0);
          expect(fixture.clipRequests, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
  for (final clip in [false, true]) {
    testWidgets('Guest search media card mounts isolated watch clip=$clip', (
      tester,
    ) async {
      final watchFixture = IsolatedRecordedRouteFixture();
      final client = TwitchApiClient();
      final auth = watchFixture.authService;
      final validation = _Validation(client, false);
      final clients = <Object>[];
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
              }) async {
                if (operationName == 'VioClassGuestChannelSearch') {
                  return _oldSearchResult();
                }
                if (operationName == 'VioClassGuestChannelVideos') {
                  return {
                    'data': {
                      'user': {
                        'id': 'old-user',
                        'displayName': 'Old fixture',
                        'videos': {
                          'edges': [
                            {
                              'node': {
                                'id': 'selected-vod',
                                'title': 'old_fixture selected VOD',
                                'broadcastType': 'HIGHLIGHT',
                                'lengthSeconds': 600,
                              },
                            },
                          ],
                        },
                      },
                    },
                  };
                }
                if (operationName == 'VioClassGuestChannelClips') {
                  return {
                    'data': {
                      'user': {
                        'clips': {
                          'edges': [
                            {
                              'node': {
                                'slug': 'selected-clip',
                                'title': 'old_fixture selected clip',
                                'durationSeconds': 20,
                                'broadcaster': {
                                  'id': 'old-user',
                                  'login': 'old_fixture',
                                  'displayName': 'Old fixture',
                                },
                              },
                            },
                          ],
                        },
                      },
                    },
                  };
                }
                return {
                  'data': {
                    'streams': {
                      'edges': [],
                      'pageInfo': {'hasNextPage': false},
                    },
                  },
                };
              },
        ),
      );
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: TwitchStreamPage(
            services: TwitchStreamPageServices(
              apiClient: client,
              authService: auth,
              authApi: validation,
              dropsAuthService: _Drops(client),
              webGqlAuthService: _Web(client),
              discoveryService: discovery,
              watchServicesFactory: () {
                final services = watchFixture.createServices();
                clients.add(services.apiClient);
                return services;
              },
              watchChatRuntimeFactory: isolatedWatchChatRuntime,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(watchFixture.createdCount, 0);
      await tester.enterText(
        find.descendant(
          of: find.byType(TwitchStreamHomeToolbar),
          matching: find.byType(EditableText),
        ),
        'old_fixture',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final title = clip
          ? 'old_fixture selected clip'
          : 'old_fixture selected VOD';
      final dynamic searchedHome = tester.state(find.byType(TwitchStreamPage));
      expect(searchedHome.searchText, 'old_fixture');
      expect(searchedHome.channelSearchError, isNull);
      expect(searchedHome.searchedVideos.length, 1);
      expect(searchedHome.searchedClips.length, 1);
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.scrollUntilVisible(
          find.text(title),
          200,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        await tester.tap(find.text(title).hitTestable());
        for (var tick = 0; tick < 30; tick++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(TwitchWatchRouteGuard), findsOneWidget);
        final state = tester.state<TwitchWatchPageState>(
          find.byType(TwitchWatchPage),
        );
        expect(state.loadingAuth, false);
        expect(state.viewerId, isNull);
        expect(state.chatController.isReadOnlyGuest, true);
        expect(state.watchServices.authService, same(auth));
        expect(state.channelLogin, 'old_fixture');
        expect(watchFixture.createdCount, attempt + 1);
        expect(watchFixture.vodRequests, clip ? 0 : attempt + 1);
        expect(watchFixture.clipRequests, clip ? attempt + 1 : 0);
        expect(tester.takeException(), isNull);
        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.byType(TwitchWatchPage), findsNothing);
      }
      expect(clients[0], isNot(same(clients[1])));
      expect(validation.calls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      watchFixture.close();
      client.close(force: true);
    });
  }

  for (final mode in [
    'guest',
    'following',
    'missing-scope',
    'checking',
    'guest-search',
    'guest-search-empty',
    'guest-search-results-vod-route',
    'guest-search-results-growing-vod-route',
    'guest-search-results-recent-highlight-vod-route',
    'guest-search-results-recent-upload-vod-route',
    'guest-search-results-clip-route',
    'guest-search-results-creator',
    'guest-search-results-author',
    'guest-search-media-clip-cleared-late-success',
    'guest-search-media-clip-cleared-late-error',
    'guest-search-media-clip-superseded-late-success',
    'guest-search-media-clip-superseded-late-error',
    'guest-search-media-clip-disposed-late-success',
    'guest-search-media-clip-disposed-late-error',
    'guest-search-media-cleared-late-success',
    'guest-search-media-cleared-late-error',
    'guest-search-media-superseded-late-success',
    'guest-search-media-superseded-late-error',
    'guest-search-media-disposed-late-success',
    'guest-search-media-disposed-late-error',
    'guest-card-route',
    'guest-search-route',
    'guest-search-retry',
    'guest-search-late-success',
    'guest-search-late-error',
    'guest-search-cleared-late',
    'guest-search-disposed-late-success',
    'guest-search-disposed-late-error',
    'guest-login',
    'following-logout',
    'checking-switch',
    'checking-switch-error',
  ]) {
    testWidgets('Real home bootstrap selects correct section for $mode', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': options.path.endsWith('/streams/followed')
                      ? [
                          {
                            'id': 'fixture-follow-stream',
                            'user_id': 'fixture-follow-user',
                            'user_login': 'fixture_follow',
                            'user_name': 'Following Fixture',
                            'type': 'live',
                            'title': 'Following fixture title',
                            'viewer_count': 12,
                          },
                        ]
                      : <dynamic>[],
                  'pagination': <String, dynamic>{},
                },
              ),
            );
          },
        ),
      );
      final client = TwitchApiClient(dio: dio);
      final initiallyGuest = mode.startsWith('guest');
      final auth = _Auth(client, initiallyGuest ? null : 'fixture-only');
      final validation = _Validation(client, mode != 'missing-scope');
      if (mode.startsWith('checking')) {
        validation.pending = Completer<TwitchTokenValidation>();
      }
      final publicOperations = <String>[];
      final routes = _Routes();
      final oldSearch = Completer<Map<String, dynamic>>();
      final oldVideo = Completer<Map<String, dynamic>>();
      final oldClip = Completer<Map<String, dynamic>>();
      var searchAttempts = 0;
      final discovery = TwitchDiscoveryService(
        client: client,
        authService: auth,
        authApi: validation,
        guestDiscoveryService: TwitchGuestDiscoveryService(
          client: client,
          requestOverride:
              ({
                required operationName,
                required query,
                required variables,
              }) async {
                publicOperations.add(operationName);
                if (mode.contains('search-media-') &&
                    !mode.contains('media-clip-') &&
                    operationName == 'VioClassGuestChannelVideos' &&
                    variables['id'] == 'old-user') {
                  return oldVideo.future;
                }
                if (mode.contains('media-clip-') &&
                    operationName == 'VioClassGuestChannelClips' &&
                    variables['id'] == 'old-user') {
                  return oldClip.future;
                }
                if (mode.contains('search-results-') &&
                    operationName == 'VioClassGuestChannelVideos') {
                  return {
                    'data': {
                      'user': {
                        'id': 'fixture-public-user',
                        'displayName': mode.endsWith('author')
                            ? 'public_fixture'
                            : 'Unrelated user',
                        'videos': {
                          'edges': [
                            {
                              'node': {
                                'id': 'selected-vod',
                                'title': 'PUBLIC_FIXTURE selected VOD',
                                'broadcastType': mode.contains('growing')
                                    ? 'ARCHIVE'
                                    : mode.contains('upload')
                                    ? 'UPLOAD'
                                    : 'HIGHLIGHT',
                                'lengthSeconds': 600,
                                if (mode.contains('growing') ||
                                    mode.contains('recent'))
                                  'createdAt': DateTime.now()
                                      .toUtc()
                                      .subtract(const Duration(minutes: 10))
                                      .toIso8601String(),
                              },
                            },
                            {
                              'node': {
                                'id': 'other-vod',
                                'title': 'Unrelated VOD',
                                'broadcastType': 'HIGHLIGHT',
                                'lengthSeconds': 600,
                              },
                            },
                          ],
                        },
                      },
                    },
                  };
                }
                if (mode.contains('search-results-') &&
                    operationName == 'VioClassGuestChannelClips') {
                  return {
                    'data': {
                      'user': {
                        'clips': {
                          'edges': [
                            {
                              'node': {
                                'slug': 'selected-clip',
                                'title': 'PUBLIC_FIXTURE selected clip',
                                'durationSeconds': 20,
                                'broadcaster': {
                                  'id': 'fixture-public-user',
                                  'displayName': 'Unrelated broadcaster',
                                },
                              },
                            },
                            {
                              'node': {
                                'slug': 'other-clip',
                                'title': 'Unrelated clip',
                                'durationSeconds': 20,
                                'broadcaster': {
                                  'id': 'fixture-public-user',
                                  'displayName': 'Unrelated broadcaster',
                                },
                                'curator': {
                                  'displayName': mode.endsWith('creator')
                                      ? 'public_fixture'
                                      : 'Unrelated creator',
                                },
                              },
                            },
                          ],
                        },
                      },
                    },
                  };
                }
                if (operationName == 'VioClassGuestChannelSearch') {
                  searchAttempts++;
                  if (mode == 'guest-search-empty') {
                    return {
                      'data': {
                        'searchFor': {
                          'channels': {'edges': <dynamic>[]},
                        },
                      },
                    };
                  }
                  if (mode == 'guest-search-retry' && searchAttempts == 1) {
                    throw StateError('fixture-search-unavailable');
                  }
                  if (variables['query'] == 'old_fixture') {
                    return oldSearch.future;
                  }
                }
                const stream = {
                  'id': 'fixture-public-stream',
                  'title': 'Public fixture title',
                  'viewersCount': 12,
                  'broadcaster': {
                    'id': 'fixture-public-user',
                    'login': 'public_fixture',
                    'displayName': 'Public Fixture',
                  },
                };
                return {
                  'data': {
                    'streams': {
                      'edges': [
                        {'node': stream},
                      ],
                      'pageInfo': {'hasNextPage': false},
                    },
                    'searchFor': {
                      'channels': {
                        'edges': [
                          {
                            'item': {
                              'id': 'fixture-public-user',
                              'login': 'public_fixture',
                              'displayName': 'Public Fixture',
                              'stream': stream,
                            },
                          },
                        ],
                      },
                    },
                  },
                };
              },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routes],
          home: TwitchStreamPage(
            services: TwitchStreamPageServices(
              apiClient: client,
              authService: auth,
              dropsAuthService: _Drops(client),
              webGqlAuthService: _Web(client),
              authApi: validation,
              discoveryService: discovery,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      final dynamic home = tester.state(find.byType(TwitchStreamPage));
      if (mode.startsWith('checking')) {
        expect(home.loadingLoginState, isTrue);
        expect(discovery.viewerSession.status, TwitchViewerStatus.checking);
        expect(find.byType(TwitchBrowsePage), findsOneWidget);
        expect(publicOperations, contains('VioClassGuestBrowse'));
        if (mode.startsWith('checking-switch')) {
          final oldValidation = validation.pending!;
          validation.pending = null;
          auth.changeIdentity('next-fixture');
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));
          expect(oldValidation.isCompleted, isFalse);
          expect(home.loadingLoginState, isFalse);
          expect(
            discovery.viewerSession.status,
            TwitchViewerStatus.authenticated,
          );
          if (mode == 'checking-switch-error') {
            oldValidation.completeError(
              StateError('fixture-old-validation-error'),
            );
          } else {
            oldValidation.complete(validation.value);
          }
        } else {
          validation.pending!.complete(validation.value);
        }
      }
      await tester.pumpAndSettle();
      final section = tester
          .widget<TwitchStreamHomeToolbar>(find.byType(TwitchStreamHomeToolbar))
          .selectedSection;
      expect(home.loadingLoginState, isFalse);
      expect(auth.loads, greaterThanOrEqualTo(1));
      final follows =
          mode.startsWith('following') || mode.startsWith('checking');
      expect(
        section,
        follows ? TwitchHomeSection.following : TwitchHomeSection.browse,
      );
      expect(
        find.byType(TwitchFollowingPage),
        follows ? findsOneWidget : findsNothing,
      );
      expect(
        discovery.viewerSession.status,
        initiallyGuest
            ? TwitchViewerStatus.guest
            : TwitchViewerStatus.authenticated,
      );
      expect(identical(home.discoveryService, discovery), isTrue);
      if (!follows) {
        expect(
          requests.where((r) => r.path.endsWith('/streams/followed')),
          isEmpty,
        );
      }
      if (initiallyGuest || mode == 'checking') {
        expect(publicOperations, contains('VioClassGuestBrowse'));
      }
      if (initiallyGuest) {
        expect(find.text('Public fixture title'), findsOneWidget);
        expect(validation.calls, 0);
      }
      if (follows) {
        expect(find.text('Following fixture title'), findsOneWidget);
      }
      if (mode.startsWith('guest-search')) {
        final input = find.descendant(
          of: find.byType(TwitchStreamHomeToolbar),
          matching: find.byType(EditableText),
        );
        if (mode.contains('search-media-')) {
          final clipPending = mode.contains('media-clip-');
          await tester.enterText(input, 'old_fixture');
          await tester.pump(const Duration(milliseconds: 400));
          oldSearch.complete(_oldSearchResult(multiple: clipPending));
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            publicOperations.where((op) => op == 'VioClassGuestChannelVideos'),
            hasLength(1),
          );
          expect(
            publicOperations.where((op) => op == 'VioClassGuestChannelClips'),
            clipPending ? hasLength(1) : isEmpty,
          );
          if (mode.contains('disposed')) {
            await tester.pumpWidget(const SizedBox());
          } else if (mode.contains('cleared')) {
            await tester.tap(find.byTooltip('清除搜尋'));
          } else {
            await tester.enterText(input, 'public_fixture');
          }
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
          final clipsBefore = publicOperations
              .where((op) => op == 'VioClassGuestChannelClips')
              .length;
          final videosBefore = publicOperations
              .where((op) => op == 'VioClassGuestChannelVideos')
              .length;
          final pendingMedia = clipPending ? oldClip : oldVideo;
          if (mode.endsWith('error')) {
            pendingMedia.completeError(
              StateError('fixture-obsolete-video-error'),
            );
          } else {
            pendingMedia.complete({'data': <String, dynamic>{}});
          }
          await tester.pumpAndSettle();
          expect(
            publicOperations
                .where((op) => op == 'VioClassGuestChannelClips')
                .length,
            clipsBefore,
            reason: 'Obsolete video completion must not continue to clips.',
          );
          expect(
            publicOperations
                .where((op) => op == 'VioClassGuestChannelVideos')
                .length,
            videosBefore,
            reason: 'Obsolete clip completion must not query the next channel.',
          );
          expect(validation.calls, 0);
          expect(requests, isEmpty);
          expect(tester.takeException(), isNull);
          if (!mode.contains('disposed')) {
            expect(home.loadingChannelSearch, isFalse);
            expect(home.channelSearchError, isNull);
            expect(find.text('Public fixture title'), findsOneWidget);
            await tester.pumpWidget(const SizedBox());
          }
          return;
        }
        if (mode.contains('search-results-')) {
          await tester.enterText(input, ' PUBLIC_FIXTURE ');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
          expect(home.searchText, 'public_fixture');
          expect(home.channelSearchError, isNull);
          expect(
            home.searchedVideos.map((dynamic entry) => entry.video.id).toList(),
            mode.endsWith('author')
                ? ['selected-vod', 'other-vod']
                : ['selected-vod'],
          );
          expect(
            home.searchedClips.map((dynamic entry) => entry.clip.id).toList(),
            mode.endsWith('creator')
                ? ['selected-clip', 'other-clip']
                : ['selected-clip'],
          );
          expect(validation.calls, 0);
          expect(requests, isEmpty);
          if (mode.endsWith('route')) {
            final vod = mode.contains('vod-route');
            final growing = mode.contains('growing');
            final title = vod
                ? 'PUBLIC_FIXTURE selected VOD'
                : 'PUBLIC_FIXTURE selected clip';
            await tester.scrollUntilVisible(
              find.text(title),
              200,
              scrollable: find
                  .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text(title));
            await tester.pumpAndSettle();
            expect(find.text(title).hitTestable(), findsOneWidget);
            await tester.tap(find.text(title).hitTestable());
            expect(routes.pushed, hasLength(2));
            final route = routes.pushed.last as MaterialPageRoute<void>;
            final target =
                route.builder(tester.element(find.byType(TwitchStreamPage)))
                    as TwitchWatchRouteGuard;
            expect(target.initialMetadata.channelLogin, 'public_fixture');
            expect(target.initialDiscoveryService, same(discovery));
            expect(target.initialKnownFollowing, isNull);
            expect(
              target.initialVodVideo?.id,
              vod && !growing ? 'selected-vod' : null,
            );
            expect(
              target.initialActiveDvrVideo?.id,
              growing ? 'selected-vod' : null,
            );
            expect(target.initialClip?.id, vod ? null : 'selected-clip');
            expect(target.initialVodPlaybackOnly, vod && !growing);
            routes.navigator!.removeRoute(route);
            await tester.pumpAndSettle();
          }
          await tester.pumpWidget(const SizedBox());
          expect(tester.takeException(), isNull);
          return;
        }
        final late = mode.contains('late');
        if (late) {
          await tester.enterText(input, 'old_fixture');
          await tester.pump(const Duration(milliseconds: 400));
          expect(searchAttempts, 1);
          expect(home.loadingChannelSearch, isTrue);
          expect(oldSearch.isCompleted, isFalse);
          if (mode.contains('disposed')) {
            await tester.pumpWidget(const SizedBox());
            final mediaBefore = publicOperations
                .where(
                  (op) =>
                      op == 'VioClassGuestChannelVideos' ||
                      op == 'VioClassGuestChannelClips',
                )
                .length;
            if (mode.endsWith('error')) {
              oldSearch.completeError(
                StateError('fixture-disposed-search-error'),
              );
            } else {
              oldSearch.complete(_oldSearchResult());
            }
            await tester.pumpAndSettle();
            expect(
              publicOperations
                  .where(
                    (op) =>
                        op == 'VioClassGuestChannelVideos' ||
                        op == 'VioClassGuestChannelClips',
                  )
                  .length,
              mediaBefore,
              reason:
                  'Disposed searches must not start follow-up media requests.',
            );
            expect(validation.calls, 0);
            expect(requests, isEmpty);
            expect(find.byType(TwitchStreamPage), findsNothing);
            expect(tester.takeException(), isNull);
            return;
          }
          if (mode == 'guest-search-cleared-late') {
            await tester.tap(find.byTooltip('清除搜尋'));
          } else {
            await tester.enterText(input, 'public_fixture');
          }
        } else {
          await tester.enterText(input, 'public_fixture');
        }
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        if (mode == 'guest-search-retry') {
          expect(
            home.channelSearchError,
            contains('fixture-search-unavailable'),
          );
          expect(find.text('Twitch 頻道搜尋暫時失敗，稍後再試。'), findsOneWidget);
          expect(find.text('Public fixture title'), findsNothing);
          await tester.tap(find.widgetWithText(OutlinedButton, '重新整理'));
          await tester.pumpAndSettle();
          expect(searchAttempts, 2);
        }
        if (late) {
          expect(home.loadingChannelSearch, isFalse);
          expect(oldSearch.isCompleted, isFalse);
          final mediaBefore = publicOperations
              .where(
                (op) =>
                    op == 'VioClassGuestChannelVideos' ||
                    op == 'VioClassGuestChannelClips',
              )
              .length;
          if (mode == 'guest-search-late-error') {
            oldSearch.completeError(StateError('fixture-stale-search-error'));
          } else {
            oldSearch.complete(_oldSearchResult());
          }
          await tester.pumpAndSettle();
          expect(
            publicOperations
                .where(
                  (op) =>
                      op == 'VioClassGuestChannelVideos' ||
                      op == 'VioClassGuestChannelClips',
                )
                .length,
            mediaBefore,
            reason:
                'Cleared or superseded searches must not start old media requests.',
          );
        }
        expect(publicOperations, contains('VioClassGuestChannelSearch'));
        expect(home.loadingChannelSearch, isFalse);
        expect(home.channelSearchError, isNull);
        if (mode == 'guest-search-cleared-late') {
          expect(home.searchedLiveStreams, isEmpty);
          expect(home.searchText, isEmpty);
          expect(find.byType(TwitchBrowsePage), findsOneWidget);
        } else if (mode == 'guest-search-empty') {
          expect(home.searchedLiveStreams, isEmpty);
          expect(home.searchedOfflineChannels, isEmpty);
          expect(find.text('找不到符合條件的頻道'), findsOneWidget);
          expect(find.text('Twitch 頻道搜尋暫時失敗，稍後再試。'), findsNothing);
        } else {
          expect(
            home.searchedLiveStreams.single.channelLogin,
            'public_fixture',
          );
          expect(home.searchText, 'public_fixture');
        }
        expect(
          find.text('Public fixture title'),
          mode == 'guest-search-empty' ? findsNothing : findsOneWidget,
        );
        expect(validation.calls, 0);
        expect(requests, isEmpty);
        if (mode == 'guest-search-route') {
          final card = find.byType(TwitchStreamCard).hitTestable();
          expect(card, findsOneWidget);
          await tester.tap(card);
          expect(routes.pushed, hasLength(2));
          final route = routes.pushed.last as MaterialPageRoute<void>;
          final target =
              route.builder(tester.element(find.byType(TwitchStreamPage)))
                  as TwitchWatchRouteGuard;
          expect(target.initialMetadata.channelLogin, 'public_fixture');
          expect(target.initialDiscoveryService, same(discovery));
          expect(
            target.initialDiscoveryService!.authService.accessToken,
            isNull,
          );
          expect(target.initialKnownFollowing, isNull);
          routes.navigator!.removeRoute(route);
          await tester.pumpAndSettle();
        }
        if (mode != 'guest-search-cleared-late') {
          await tester.tap(find.byTooltip('清除搜尋'));
          await tester.pumpAndSettle();
        }
        expect(home.searchText, isEmpty);
        expect(find.byType(TwitchBrowsePage), findsOneWidget);
        expect(find.text('Public fixture title'), findsOneWidget);
      }
      if (mode == 'guest-card-route') {
        await tester.tap(find.byType(TwitchStreamCard).hitTestable());
        expect(routes.pushed, hasLength(2));
        final route = routes.pushed.last as MaterialPageRoute<void>;
        final target =
            route.builder(tester.element(find.byType(TwitchStreamPage)))
                as TwitchWatchRouteGuard;
        expect(target.initialMetadata.channelLogin, 'public_fixture');
        expect(target.initialMetadata.streamTitle, 'Public fixture title');
        expect(
          target.initialOfflineChannel?.broadcasterId,
          'fixture-public-user',
        );
        expect(target.initialDiscoveryService, same(discovery));
        expect(
          target.initialDiscoveryService!.viewerSession.status,
          TwitchViewerStatus.guest,
        );
        expect(target.initialKnownFollowing, isNull);
        routes.navigator!.removeRoute(route);
        await tester.pumpAndSettle();
        expect(find.text('Public fixture title'), findsOneWidget);
        expect(validation.calls, 0);
        expect(requests, isEmpty);
      }
      if (mode == 'guest-login' || mode == 'following-logout') {
        if (mode == 'following-logout') {
          twitchAppNotificationCenter.clear();
          twitchAppNotificationCenter.show(
            title: 'fixture previous account reward',
            message: 'fixture',
            category: TwitchAppNotificationCategory.giftSubscription,
            accountOwnerId: 'fixture-viewer-id',
          );
          twitchAppNotificationCenter.show(
            title: 'fixture public notice',
            message: 'fixture',
          );
        }
        auth.changeIdentity(mode == 'guest-login' ? 'fixture-only' : null);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(TwitchStreamPage)), same(home));
        final loggedIn = mode == 'guest-login';
        expect(
          discovery.viewerSession.status,
          loggedIn
              ? TwitchViewerStatus.authenticated
              : TwitchViewerStatus.guest,
        );
        expect(
          tester
              .widget<TwitchStreamHomeToolbar>(
                find.byType(TwitchStreamHomeToolbar),
              )
              .selectedSection,
          loggedIn ? TwitchHomeSection.following : TwitchHomeSection.browse,
        );
        expect(
          find.text('Following fixture title'),
          loggedIn ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Public fixture title'),
          loggedIn ? findsNothing : findsOneWidget,
        );
        if (mode == 'following-logout') {
          final titles = twitchAppNotificationCenter.items
              .map((item) => item.title)
              .toList();
          twitchAppNotificationCenter.clear();
          expect(titles, isNot(contains('fixture previous account reward')));
          expect(titles, contains('fixture public notice'));
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
