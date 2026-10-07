// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/presentation/pages/twitch_whisper_authorization.dart';

import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/presentation/pages/twitch_linked_login_page.dart';
import '../lib/features/twitch/presentation/pages/twitch_oauth_webview_login_page.dart';
import '../lib/features/twitch/services/auth/twitch_auth_service.dart';
import '../lib/features/twitch/services/auth/twitch_drops_auth_service.dart';
import '../lib/features/twitch/services/auth/twitch_web_gql_auth_service.dart';

class _Client extends TwitchApiClient {
  @override
  Future<T> postJson<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      {
            'data': {
              'user': {'id': '1'},
            },
          }
          as T;
}

class _Main extends TwitchAuthService {
  _Main(TwitchApiClient client) : super(apiClient: client);
  @override
  Future<void> loadStoredSession({bool refreshIfNeeded = true}) async {}
  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async =>
      'main';
}

class _Web extends TwitchWebGqlAuthService {
  _Web(TwitchApiClient client) : super(apiClient: client);
  @override
  Future<void> loadStoredSession({
    bool migrateLegacyDropsWebToken = true,
  }) async {}
  @override
  Future<String?> getToken() async => 'web';
  @override
  Future<bool> validateToken() async => true;
}

class _Drops extends TwitchDropsAuthService {
  _Drops(TwitchApiClient client) : super(apiClient: client);
  @override
  Future<void> loadStoredSession() async {}
  @override
  Future<String?> getToken() async => 'drops';
  @override
  Future<bool> validateToken() async => true;
}

class _AuthApi extends TwitchAuthApiService {
  final List<String> scopes;
  _AuthApi(TwitchApiClient client, this.scopes) : super(client: client);
  @override
  Future<TwitchTokenValidation> validateToken(String accessToken) async =>
      TwitchTokenValidation(
        clientId: 'main-client',
        login: 'viewer',
        userId: '1',
        scopes: scopes,
        expiresIn: 3600,
      );
}

void main() {
  test(
    'Private authorization uses existing main/Web page without Drops or token mirroring',
    () {
      final client = _Client();
      final main = _Main(client);
      final web = _Web(client);
      final page = createTwitchWhisperAuthorizationPage(
        mainAuthService: main,
        webGqlAuthService: web,
        authApi: _AuthApi(client, const []),
        apiClient: client,
      );
      expect(page.mainAuthService, same(main));
      expect(page.webGqlAuthService, same(web));
      expect(page.interactionAuthService, isNull);
      expect(page.captureWebGqlToken, true);
      expect(page.mirrorMainTokenToInteraction, false);
      expect(page.target, TwitchOAuthWebViewTokenTarget.main);
      expect(
        page.scopes,
        containsAll(['user:read:whispers', 'user:manage:whispers']),
      );
      client.close();
    },
  );
  late _Client client;
  late _Main main;
  late _Web web;
  late _Drops drops;
  setUp(() {
    client = _Client();
    main = _Main(client);
    web = _Web(client);
    drops = _Drops(client);
  });
  tearDown(() {
    main.dispose();
    web.dispose();
    drops.dispose();
    client.close();
  });

  Future<void> open(WidgetTester tester, List<String> scopes) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TwitchLinkedLoginPage(
          mainAuthService: main,
          webGqlAuthService: web,
          dropsAuthService: drops,
          authApi: _AuthApi(client, scopes),
          apiClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Valid old login still needs whisper consent and can sign out', (
    tester,
  ) async {
    await open(tester, ['chat:read', 'chat:edit']);
    expect(find.text('已登入 Twitch，請再次授權以啟用私訊收發。'), findsOneWidget);
    expect(find.text('登入完成'), findsNothing);
    expect(find.text('登出'), findsOneWidget);
    await tester.tap(find.text('使用 Twitch 登入'));
    // This checks route selection, not the native WebView handshake. The test
    // has no real desktop window, so its loading animation cannot settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final page = tester.widget<TwitchOAuthWebViewLoginPage>(
      find.byType(TwitchOAuthWebViewLoginPage),
    );
    expect(
      page.scopes,
      containsAll(['user:read:whispers', 'user:manage:whispers']),
    );
    expect(page.mirrorMainTokenToInteraction, isFalse);
    expect(page.mainAuthService, same(main));
    expect(page.webGqlAuthService, same(web));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('Read-only consent is not reported as full private messaging', (
    tester,
  ) async {
    await open(tester, ['user:read:whispers']);
    expect(find.text('已登入 Twitch，請再次授權以啟用私訊收發。'), findsOneWidget);
    expect(find.text('登入完成'), findsNothing);
  });

  testWidgets('Verified receive and send scopes complete the linked login', (
    tester,
  ) async {
    await open(tester, ['user:read:whispers', 'user:manage:whispers']);
    expect(find.text('登入完成'), findsOneWidget);
    expect(find.text('已登入'), findsOneWidget);
  });
}
