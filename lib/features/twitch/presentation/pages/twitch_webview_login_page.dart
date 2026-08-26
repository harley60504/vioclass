import 'package:flutter/material.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../services/auth/twitch_auth_service.dart';
import 'twitch_oauth_webview_login_page.dart';

class TwitchWebViewLoginPage extends StatelessWidget {
  final TwitchAuthService authService;
  final TwitchAuthApiService authApi;
  final String initialClientId;
  final String initialRedirectUri;

  const TwitchWebViewLoginPage({
    super.key,
    required this.authService,
    required this.authApi,
    this.initialClientId = TwitchApiConstants.twitchWebClientId,
    this.initialRedirectUri = 'https://localhost',
  });

  @override
  Widget build(BuildContext context) {
    return TwitchOAuthWebViewLoginPage(
      target: TwitchOAuthWebViewTokenTarget.main,
      mainAuthService: authService,
      authApi: authApi,
      initialClientId: initialClientId,
      initialRedirectUri: initialRedirectUri,
      scopes: const <String>[
        'chat:read',
        'chat:edit',
        'user:read:emotes',
        'user:read:follows',
        'clips:edit',
      ],
    );
  }
}
