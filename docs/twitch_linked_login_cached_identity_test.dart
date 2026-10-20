import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/api/auth/twitch_auth_api_service.dart';
import 'package:vioclass/features/twitch/api/core/twitch_api_client.dart';
import 'package:vioclass/features/twitch/api/core/twitch_api_exception.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_linked_login_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_oauth_webview_login_page.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_auth_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_drops_auth_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_viewer_session.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_web_gql_auth_service.dart';

class _Auth extends TwitchAuthService {
  _Auth(TwitchApiClient client) : super(apiClient: client);
  @override
  String? get accessToken => 'isolated-account';
  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async =>
      accessToken;
  @override
  Future<void> loadStoredSession({bool refreshIfNeeded = true}) async {}
}

class _Web extends TwitchWebGqlAuthService {
  _Web(TwitchApiClient client) : super(apiClient: client);
  Completer<void>? gate;
  bool fail = false;
  int reads = 0;
  @override
  Future<void> loadStoredSession({
    bool migrateLegacyDropsWebToken = true,
  }) async {
    reads++;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('isolated-storage-failure');
  }

  @override
  Future<String?> getToken() async => null;
}

class _Drops extends TwitchDropsAuthService {
  _Drops(TwitchApiClient client) : super(apiClient: client);
  @override
  Future<void> loadStoredSession() async {}
  @override
  Future<String?> getToken() async => null;
}

class _Validation extends TwitchAuthApiService {
  _Validation(TwitchApiClient client) : super(client: client);
  bool fail = false;
  int? rejectedStatus;
  @override
  Future<TwitchTokenValidation> validateToken(String accessToken) async {
    if (rejectedStatus != null) {
      throw TwitchApiException(
        'isolated-validation-status',
        statusCode: rejectedStatus,
      );
    }
    if (fail) throw StateError('isolated-validation-unavailable');
    return const TwitchTokenValidation(
      clientId: 'isolated-client',
      login: 'isolated_viewer',
      userId: '42',
      scopes: ['chat:read'],
      expiresIn: 3600,
    );
  }
}

class _Fixture {
  final client = TwitchApiClient();
  late final auth = _Auth(client);
  late final web = _Web(client);
  late final drops = _Drops(client);
  late final api = _Validation(client);
  late final session = TwitchViewerSession.forAuth(auth);
  int networkRequests = 0;

  Future<void> prepare() async {
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          networkRequests++;
          handler.reject(DioException(requestOptions: options));
        },
      ),
    );
    await session.resolve(api);
  }

  Widget get page => MaterialApp(
    home: TwitchLinkedLoginPage(
      mainAuthService: auth,
      webGqlAuthService: web,
      dropsAuthService: drops,
      authApi: api,
      apiClient: client,
    ),
  );

  void expectIdentity() {
    expect(session.status, TwitchViewerStatus.authenticated);
    expect(session.snapshot?.viewerId, '42');
    expect(session.identityRevision, 0);
    expect(auth.accessToken, 'isolated-account');
    expect(networkRequests, 0);
  }
}

void main() {
  Future<_Fixture> prepare() async {
    final fixture = _Fixture();
    addTearDown(() => fixture.client.close(force: true));
    await fixture.prepare();
    return fixture;
  }

  for (final failure in ['storage', 'validation', '503']) {
    testWidgets('Cached identity survives initial failure=$failure', (
      tester,
    ) async {
      final fixture = await prepare();
      final cached = fixture.session.snapshot;
      fixture.web.fail = failure == 'storage';
      fixture.api.fail = failure == 'validation';
      fixture.api.rejectedStatus = failure == '503' ? 503 : null;
      await tester.pumpWidget(fixture.page);
      await tester.pumpAndSettle();
      expect(find.text('無法確認登入狀態'), findsOneWidget);
      expect(find.text('尚未登入'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(TwitchOAuthWebViewLoginPage), findsNothing);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
      expect(fixture.session.snapshot, same(cached));
      fixture.expectIdentity();
      expect(tester.takeException(), isNull);
    });
  }

  for (final validationFailure in [false, true]) {
    testWidgets(
      'Cached identity survives login reread validation=$validationFailure',
      (tester) async {
        final fixture = await prepare();
        await tester.pumpWidget(fixture.page);
        await tester.pumpAndSettle();
        expect(find.text('已登入 Twitch，請再次授權以啟用私訊收發。'), findsOneWidget);
        final cached = fixture.session.snapshot;
        fixture.web.fail = !validationFailure;
        fixture.api.fail = validationFailure;
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();
        expect(find.text('登入失敗'), findsOneWidget);
        expect(find.text('登出'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(TwitchOAuthWebViewLoginPage), findsNothing);
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNotNull,
        );
        expect(fixture.session.snapshot, same(cached));
        expect(fixture.web.reads, 2);
        fixture.expectIdentity();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final status in [401, 403]) {
    testWidgets(
      'Actual authorization rejection still becomes guest status=$status',
      (tester) async {
        final fixture = await prepare();
        fixture.api.rejectedStatus = status;
        await tester.pumpWidget(fixture.page);
        await tester.pumpAndSettle();
        expect(find.text('尚未登入'), findsOneWidget);
        expect(find.text('無法確認登入狀態'), findsNothing);
        expect(fixture.session.status, TwitchViewerStatus.guest);
        expect(fixture.session.snapshot, isNull);
        expect(fixture.auth.accessToken, 'isolated-account');
        expect(fixture.networkRequests, 0);
        expect(find.byType(TwitchOAuthWebViewLoginPage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final duringLogin in [false, true]) {
    for (final lateFailure in [false, true]) {
      testWidgets(
        'Dispose pending login=$duringLogin lateFailure=$lateFailure',
        (tester) async {
          final fixture = await prepare();
          if (!duringLogin) fixture.web.gate = Completer<void>();
          await tester.pumpWidget(fixture.page);
          await tester.pump();
          if (duringLogin) {
            await tester.pumpAndSettle();
            fixture.web.gate = Completer<void>();
            await tester.tap(find.byType(ElevatedButton));
            await tester.pump();
          }
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(fixture.web.reads, duringLogin ? 2 : 1);
          await tester.pumpWidget(const SizedBox.shrink());
          if (lateFailure) {
            fixture.web.gate!.completeError(
              StateError('isolated-late-failure'),
            );
          } else {
            fixture.web.gate!.complete();
          }
          await tester.pumpAndSettle();
          fixture.expectIdentity();
          expect(find.byType(TwitchOAuthWebViewLoginPage), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
