import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import 'twitch_oauth_webview_login_page.dart';

/// Private messages need main scopes and Web history, never Drops authorization.
/// Uses the existing platform WebView and credential storage unchanged.
TwitchOAuthWebViewLoginPage createTwitchWhisperAuthorizationPage({
  required TwitchAuthService mainAuthService,
  required TwitchWebGqlAuthService webGqlAuthService,
  required TwitchAuthApiService authApi,
  required TwitchApiClient apiClient,
}) => TwitchOAuthWebViewLoginPage(
  mainAuthService: mainAuthService,
  webGqlAuthService: webGqlAuthService,
  authApi: authApi,
  apiClient: apiClient,
  captureWebGqlToken: true,
  mirrorMainTokenToInteraction: false,
);
