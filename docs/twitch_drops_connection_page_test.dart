// Isolated test files are intentionally kept in docs by this repository.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vioclass/features/twitch/api/auth/twitch_auth_api_service.dart';
import 'package:vioclass/features/twitch/api/core/twitch_api_client.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_auth_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_drops_auth_service.dart';
import 'package:vioclass/features/twitch/services/notifications/twitch_app_notification_service.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_drops_connection_page.dart';

class _GuestAuth extends TwitchAuthService {
  _GuestAuth(TwitchApiClient client) : super(apiClient: client);
  @override
  Future<void> loadStoredSession({bool refreshIfNeeded = true}) async {}
  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async =>
      null;
}

class _SignedLeaderboardAuth extends _GuestAuth {
  _SignedLeaderboardAuth(super.client);
  @override
  String get accessToken => 'fixture-main-token';
  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async =>
      accessToken;
}

class _DropsAuth extends TwitchDropsAuthService {
  _DropsAuth(TwitchApiClient client, this.scenario) : super(apiClient: client);
  final String scenario;
  int loads = 0;
  int validations = 0;
  Completer<void>? gate;
  @override
  String get dropsClientId => 'fixture-drops-client';
  @override
  Future<void> loadStoredSession() async {
    loads++;
    await gate?.future;
  }

  @override
  Future<String?> getToken() async =>
      scenario == 'guest' ? null : 'fixture-drops-token';
  @override
  Future<bool> validateToken() async {
    validations++;
    return scenario != 'invalid';
  }
}

Map<String, Object?> _readyDropsResponse({bool claimed = false}) {
  final campaign = {
    'id': 'fixture-campaign',
    'name': 'Fixture campaign',
    'status': 'ACTIVE',
    'game': {'id': 'fixture-game', 'name': 'Fixture Game'},
    'self': {'isAccountConnected': true},
    'timeBasedDrops': [
      {
        'id': 'fixture-drop',
        'name': 'Fixture reward',
        'requiredMinutesWatched': 60,
        'self': {
          'currentMinutesWatched': 60,
          'isClaimed': claimed,
          'dropInstanceID': 'fixture-instance',
        },
      },
    ],
  };
  return {
    'data': {
      'currentUser': {
        'id': '42',
        'login': 'fixture-viewer',
        'inventory': {
          'dropCampaignsInProgress': [campaign],
        },
        'dropCampaigns': [campaign],
      },
    },
  };
}

void main() {
  for (final size in [const Size(1000, 760), const Size(390, 844)]) {
    for (final scenario in ['success', 'retry', 'close-pending']) {
      testWidgets('Drops actual leaderboard scenario=$scenario size=$size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        SharedPreferences.setMockInitialValues({});
        twitchAppNotificationCenter.clear();
        addTearDown(twitchAppNotificationCenter.clear);
        final client = TwitchApiClient();
        addTearDown(() => client.close(force: true));
        final auth = _SignedLeaderboardAuth(client);
        final drops = _DropsAuth(client, 'connected');
        final gate = Completer<void>();
        var followedReads = 0;
        var balances = 0;
        var fail = scenario == 'retry';
        client.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              Object? data;
              if (options.path.contains('/validate')) {
                data = {
                  'client_id': 'fixture-client',
                  'login': 'fixture-viewer',
                  'user_id': '42',
                  'scopes': ['user:read:follows'],
                  'expires_in': 3600,
                };
              } else if (options.path.contains('/channels/followed')) {
                followedReads++;
                expectSync(options.queryParameters['user_id'], '42');
                await gate.future;
                if (fail) {
                  handler.reject(
                    DioException(
                      requestOptions: options,
                      type: DioExceptionType.badResponse,
                      response: Response<dynamic>(
                        requestOptions: options,
                        statusCode: 503,
                      ),
                    ),
                  );
                  return;
                }
                data = {
                  'data': [
                    for (final login in ['fixture_low', 'fixture_high'])
                      {
                        'broadcaster_id': login,
                        'broadcaster_login': login,
                        'broadcaster_name': login,
                      },
                  ],
                  'pagination': {},
                };
              } else if (options.path.endsWith('/users')) {
                data = {'data': []};
              } else if (options.path.contains('gql')) {
                final body = options.data.toString();
                expectSync(body.contains('ClaimDropRewards'), false);
                if (body.contains('ChannelPointsContext')) {
                  balances++;
                  expectSync(
                    options.headers['Authorization'],
                    'OAuth fixture-drops-token',
                  );
                  data = [
                    for (final points in [200, 500])
                      {
                        'data': {
                          'user': {
                            'channel': {
                              'self': {
                                'communityPoints': {'balance': points},
                              },
                            },
                          },
                        },
                      },
                  ];
                } else {
                  data = _readyDropsResponse();
                }
              } else {
                throw StateError('Unexpected fixture request');
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
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TwitchDropsConnectionPage(
                        apiClient: client,
                        authService: auth,
                        authApi: TwitchAuthApiService(client: client),
                        dropsAuthService: drops,
                      ),
                    ),
                  ),
                  child: const Text('fixture leaderboard open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('fixture leaderboard open'));
        await tester.pumpAndSettle();
        expect(followedReads, 1);
        await tester.tap(find.text('統計'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.ensureVisible(find.byTooltip('更新 Channel Points'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          followedReads,
          1,
          reason: 'entering stats must not duplicate an in-flight read',
        );
        final refreshButton = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == '更新 Channel Points',
        );
        expect(tester.widget<IconButton>(refreshButton).onPressed, isNull);
        if (scenario == 'close-pending') {
          await tester.tap(find.byType(BackButton));
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          twitchAppNotificationCenter.clear();
        }
        gate.complete();
        await tester.pumpAndSettle();
        if (scenario == 'close-pending') {
          expect(find.byType(TwitchDropsConnectionPage), findsNothing);
          expect(twitchAppNotificationCenter.items, isEmpty);
        } else {
          if (fail) {
            expect(find.text('Channel Points 暫時讀取失敗，稍後再試。'), findsOneWidget);
            expect(balances, 0);
            fail = false;
            await tester.tap(find.byTooltip('更新 Channel Points'));
            await tester.pumpAndSettle();
            expect(followedReads, 2);
          }
          expect(balances, 1);
          expect(find.text('fixture_high'), findsOneWidget);
          expect(find.text('fixture_low'), findsOneWidget);
          expect(
            tester.getTopLeft(find.text('fixture_high')).dy,
            lessThan(tester.getTopLeft(find.text('fixture_low')).dy),
          );
          expect(find.text('700'), findsWidgets);
          expect(tester.widget<IconButton>(refreshButton).onPressed, isNotNull);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
        }
        expect(find.text('fixture leaderboard open'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 9));
        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
  for (final entry in ['inventory', 'campaign-dialog']) {
    for (final size in [const Size(1000, 760), const Size(390, 844)]) {
      for (final scenario in [
        'success',
        'failure-retry',
        'close-success',
        'close-failure',
        if (entry == 'campaign-dialog') 'refresh-pending',
      ]) {
        testWidgets('Drops $entry actual claim scenario=$scenario size=$size', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          debugDefaultTargetPlatformOverride = TargetPlatform.windows;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          SharedPreferences.setMockInitialValues({});
          twitchAppNotificationCenter.clear();
          addTearDown(twitchAppNotificationCenter.clear);
          final client = TwitchApiClient();
          addTearDown(() => client.close(force: true));
          final auth = _GuestAuth(client);
          final drops = _DropsAuth(client, 'connected');
          var claims = 0;
          var reads = 0;
          var claimed = false;
          var fail = scenario.contains('failure');
          var gate = Completer<void>();
          final refreshGate = Completer<void>();
          addTearDown(() {
            if (!refreshGate.isCompleted) refreshGate.complete();
          });
          client.dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) async {
                expectSync(options.path.contains('gql'), true);
                expectSync(
                  options.headers['Authorization'],
                  'OAuth fixture-drops-token',
                );
                final isClaim = options.data.toString().contains(
                  'DropsPage_ClaimDropRewards',
                );
                if (isClaim) {
                  claims++;
                  expectSync(
                    options.data.toString().contains('fixture-instance'),
                    true,
                  );
                  await gate.future;
                  if (!fail) claimed = true;
                  handler.resolve(
                    Response<dynamic>(
                      requestOptions: options,
                      statusCode: 200,
                      data: fail
                          ? {
                              'errors': [
                                {'message': 'fixture rejected claim'},
                              ],
                            }
                          : {
                              'data': {
                                'claimDropRewards': {
                                  'status': 'ELIGIBLE_FOR_ALL',
                                },
                              },
                            },
                    ),
                  );
                } else {
                  reads++;
                  if (scenario == 'refresh-pending' && reads > 2) {
                    await refreshGate.future;
                  }
                  handler.resolve(
                    Response<dynamic>(
                      requestOptions: options,
                      statusCode: 200,
                      data: _readyDropsResponse(claimed: claimed),
                    ),
                  );
                }
              },
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TwitchDropsConnectionPage(
                          apiClient: client,
                          authService: auth,
                          authApi: TwitchAuthApiService(client: client),
                          dropsAuthService: drops,
                        ),
                      ),
                    ),
                    child: const Text('fixture claims open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('fixture claims open'));
          await tester.pumpAndSettle();
          expect(reads, 2);
          if (entry == 'inventory') {
            await tester.tap(find.text('庫存'));
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(find.text('Fixture Game'));
          await tester.tap(find.text('Fixture Game'));
          await tester.pumpAndSettle();
          if (entry == 'campaign-dialog') {
            expect(find.byType(Dialog), findsOneWidget);
          }
          await tester.ensureVisible(find.text('領取'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('領取'));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));
          expect(claims, 1);
          expect(find.text('領取中'), findsOneWidget);
          final busy = find.ancestor(
            of: find.text('領取中'),
            matching: find.byWidgetPredicate(
              (widget) => widget is ElevatedButton,
            ),
          );
          expect(tester.widget<ElevatedButton>(busy).onPressed, isNull);
          await tester.tap(busy);
          await tester.pump();
          expect(claims, 1);
          if (scenario.startsWith('close-')) {
            if (entry == 'campaign-dialog') {
              await tester.tap(find.byTooltip('關閉'));
              await tester.pumpAndSettle();
            }
            await tester.tap(find.byType(BackButton));
            await tester.pump();
            for (var i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(find.byType(TwitchDropsConnectionPage), findsNothing);
            twitchAppNotificationCenter.clear();
          }
          gate.complete();
          if (scenario == 'refresh-pending') {
            for (var i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(reads, greaterThan(2));
            final refreshPendingButton = find.descendant(
              of: find.byType(Dialog),
              matching: find.byWidgetPredicate(
                (widget) => widget is ElevatedButton,
              ),
            );
            await tester.tap(refreshPendingButton);
            await tester.pump(const Duration(milliseconds: 100));
            expect(
              claims,
              1,
              reason: 'refreshing must not permit a second claim',
            );
            expect(find.text('領取中'), findsOneWidget);
            expect(
              tester.widget<ElevatedButton>(refreshPendingButton).onPressed,
              isNull,
            );
            refreshGate.complete();
          }
          await tester.pumpAndSettle();
          if (scenario.startsWith('close-')) {
            expect(reads, 2);
            expect(twitchAppNotificationCenter.items, isEmpty);
          } else {
            if (fail) {
              expect(
                twitchAppNotificationCenter.items.any(
                  (item) => item.title == 'Drops 獎勵領取失敗',
                ),
                true,
              );
              expect(reads, 2);
              expect(find.text('領取'), findsOneWidget);
              fail = false;
              gate = Completer<void>()..complete();
              await tester.tap(find.text('領取'));
              await tester.pumpAndSettle();
              expect(claims, 2);
            }
            expect(reads, 4);
            expect(
              twitchAppNotificationCenter.items.any(
                (item) => item.title == 'Drops 獎勵領取成功',
              ),
              true,
            );
            final completed = find.ancestor(
              of: find.text('領取'),
              matching: find.byWidgetPredicate(
                (widget) => widget is ElevatedButton,
              ),
            );
            expect(tester.widget<ElevatedButton>(completed).onPressed, isNull);
            if (entry == 'campaign-dialog') {
              await tester.tap(find.byTooltip('關閉'));
              await tester.pumpAndSettle();
            }
            await tester.tap(find.byType(BackButton));
            await tester.pumpAndSettle();
          }
          expect(find.text('fixture claims open'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(seconds: 9));
          await tester.pumpWidget(const SizedBox());
          debugDefaultTargetPlatformOverride = null;
        });
      }
    }
  }
  for (final size in [const Size(1000, 760), const Size(390, 844)]) {
    for (final scenario in [
      'guest',
      'invalid',
      'connected',
      'retry',
      'close-pending',
    ]) {
      testWidgets(
        'Drops page read refresh return scenario=$scenario size=$size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          twitchAppNotificationCenter.clear();
          addTearDown(twitchAppNotificationCenter.clear);
          final client = TwitchApiClient();
          addTearDown(() => client.close(force: true));
          final auth = _GuestAuth(client);
          final drops = _DropsAuth(client, scenario);
          if (scenario == 'close-pending') drops.gate = Completer<void>();
          var requests = 0;
          var claims = 0;
          var failFirst = scenario == 'retry';
          client.dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                requests++;
                if (options.data.toString().contains(
                  'DropsPage_ClaimDropRewards',
                )) {
                  claims++;
                }
                expectSync(options.path.contains('gql'), true);
                expectSync(
                  options.headers['Authorization'],
                  'OAuth fixture-drops-token',
                );
                if (failFirst) {
                  failFirst = false;
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
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'data': {
                        'currentUser': {
                          'id': '42',
                          'login': 'fixture-viewer',
                          'inventory': {'dropCampaignsInProgress': []},
                          'dropCampaigns': [],
                        },
                      },
                    },
                  ),
                );
              },
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TwitchDropsConnectionPage(
                          apiClient: client,
                          authService: auth,
                          authApi: TwitchAuthApiService(client: client),
                          dropsAuthService: drops,
                        ),
                      ),
                    ),
                    child: const Text('fixture drops open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('fixture drops open'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          if (scenario == 'close-pending') {
            expect(drops.loads, 1);
            expect(
              tester
                  .widget<IconButton>(
                    find.byWidgetPredicate(
                      (widget) =>
                          widget is IconButton &&
                          widget.tooltip == '重新整理 Drops',
                    ),
                  )
                  .onPressed,
              isNull,
            );
            expect(requests, 0);
            await tester.tap(find.byType(BackButton));
            await tester.pump();
            // The indeterminate spinner prevents pumpAndSettle; advance a
            // bounded set of frames for the asynchronous maybePop transition.
            for (var i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(find.byType(TwitchDropsConnectionPage), findsNothing);
            drops.gate!.complete();
            await tester.pumpAndSettle();
            expect(twitchAppNotificationCenter.items, isEmpty);
          } else {
            await tester.pumpAndSettle();
            if (scenario == 'guest' || scenario == 'invalid') {
              expect(
                find.text(
                  scenario == 'guest' ? '尚未取得 Drops token' : 'Drops token 驗證失敗',
                ),
                findsOneWidget,
              );
              expect(requests, 0);
              expect(drops.validations, scenario == 'guest' ? 0 : 1);
            } else {
              if (scenario == 'retry') {
                expect(find.text('Drops inventory 連線失敗'), findsOneWidget);
                expect(requests, 1);
                await tester.tap(find.byTooltip('重新整理 Drops'));
                await tester.pumpAndSettle();
              }
              expect(find.text('活動'), findsWidgets);
              await tester.tap(find.text('庫存'));
              await tester.pumpAndSettle();
              expect(find.text('目前庫存沒有 Drops 活動。'), findsOneWidget);
              await tester.tap(find.text('統計'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('活動').first);
              await tester.pumpAndSettle();
              expect(requests, scenario == 'retry' ? 3 : 2);
            }
            await tester.tap(find.byType(BackButton));
            await tester.pumpAndSettle();
          }
          expect(find.text('fixture drops open'), findsOneWidget);
          expect(find.byType(TwitchDropsConnectionPage), findsNothing);
          expect(claims, 0);
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(seconds: 9));
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
