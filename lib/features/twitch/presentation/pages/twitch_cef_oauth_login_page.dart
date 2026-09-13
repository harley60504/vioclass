import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:webview_cef/webview_cef.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../models/auth/twitch_auth_token.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';

/// Windows CEF experiment for the unified Twitch login flow.
///
/// The important part of this page is that OAuth, Twitch web login and GQL
/// token capture all stay inside the same Chromium/CEF browser context.
class TwitchCefOAuthLoginPage extends StatefulWidget {
  final TwitchAuthService mainAuthService;
  final TwitchWebGqlAuthService webGqlAuthService;
  final TwitchAuthApiService authApi;
  final TwitchApiClient apiClient;

  const TwitchCefOAuthLoginPage({
    super.key,
    required this.mainAuthService,
    required this.webGqlAuthService,
    required this.authApi,
    required this.apiClient,
  });

  @override
  State<TwitchCefOAuthLoginPage> createState() =>
      _TwitchCefOAuthLoginPageState();
}

class _TwitchCefOAuthLoginPageState extends State<TwitchCefOAuthLoginPage> {
  static const String _clientId = 'euyqoof00efejc6vk5f4gv0nze20ue';
  static const String _redirectUri = 'http://localhost:3000';
  static const String _homeUrl = 'https://www.twitch.tv/';
  static const List<String> _scopes = <String>[
    'user:read:email',
    'user:read:follows',
    'chat:read',
    'chat:edit',
    'user:read:emotes',
    'clips:edit',
  ];

  static Future<void>? _cefInitialization;

  late final WebViewController _controller;
  late String _state;

  bool _ready = false;
  bool _finishing = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _state = _createStateToken();
    _controller = WebviewManager().createWebView(
      loading: const Center(child: CircularProgressIndicator()),
    );
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    // Do not quit WebviewManager here. Keeping the CEF process alive keeps the
    // Chromium browser context/session available for the rest of the app run.
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      _cefInitialization ??= WebviewManager().initialize();
      await _cefInitialization;

      _controller.setWebviewListener(
        WebviewEventsListener(
          onUrlChanged: (url) {
            unawaited(_handleUrl(url));
          },
          onLoadEnd: (controller, url) {
            if (!mounted) return;
            setState(() => _ready = true);
            unawaited(_handleUrl(url));
          },
        ),
      );

      await _controller.initialize(_buildAuthorizationUri().toString());
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      _showError('無法開啟 Twitch 登入頁。');
    }
  }

  String _createStateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Uri _buildAuthorizationUri() {
    return Uri.parse('https://id.twitch.tv/oauth2/authorize').replace(
      queryParameters: <String, String>{
        'response_type': 'token',
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'scope': _scopes.join(' '),
        'state': _state,
        'force_verify': 'false',
      },
    );
  }

  bool _isRedirectUri(Uri uri) {
    final configured = Uri.parse(_redirectUri);
    if (uri.scheme.toLowerCase() != configured.scheme.toLowerCase()) {
      return false;
    }
    if (uri.host.toLowerCase() != configured.host.toLowerCase()) return false;
    return uri.port == configured.port;
  }

  Map<String, String> _parseOAuthResponse(Uri uri) {
    final output = <String, String>{};
    if (uri.query.isNotEmpty) output.addAll(Uri.splitQueryString(uri.query));
    if (uri.fragment.isNotEmpty) {
      output.addAll(Uri.splitQueryString(uri.fragment));
    }
    return output;
  }

  Future<void> _handleUrl(String rawUrl) async {
    if (_finishing) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !_isRedirectUri(uri)) return;

    final params = _parseOAuthResponse(uri);
    if (params['error']?.isNotEmpty == true) {
      _showError('Twitch 登入失敗，請再試一次。');
      return;
    }

    if (params['state'] != _state) {
      _showError('登入驗證失敗，請重新登入。');
      return;
    }

    final accessToken = params['access_token']?.trim();
    if (accessToken == null || accessToken.isEmpty) {
      _showError('沒有取得 Twitch 登入授權。');
      return;
    }

    _finishing = true;
    if (mounted) {
      setState(() => _errorText = null);
    }

    try {
      await _saveMainOAuth(
        accessToken,
        int.tryParse(params['expires_in'] ?? '') ?? 14400,
        _parseScopes(params['scope']),
      );

      // Keep using the same CEF controller/context after OAuth. This is the
      // key experiment: Google/Twitch cookies should remain available here.
      _controller.loadUrl(_homeUrl);

      final webToken = await _waitForTwitchWebToken();
      if (webToken == null || webToken.isEmpty) {
        throw StateError('Twitch web auth-token not found in CEF session');
      }

      await _saveAndVerifyWebGqlToken(webToken);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      _finishing = false;
      _showError('登入沒有完成，請再試一次。');
    }
  }

  List<String> _parseScopes(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return _scopes;
    return text
        .split(RegExp(r'[ +]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _saveMainOAuth(
    String accessToken,
    int expiresIn,
    List<String> scopes,
  ) async {
    final validation = await widget.authApi.validateToken(accessToken);
    final token = TwitchAuthToken(
      accessToken: accessToken,
      refreshToken: '',
      tokenType: 'bearer',
      scopes: validation.scopes.isNotEmpty ? validation.scopes : scopes,
      expiresIn: validation.expiresIn <= 0 ? expiresIn : validation.expiresIn,
      obtainedAt: DateTime.now(),
    );

    await widget.mainAuthService.saveSession(
      clientId: validation.clientId.trim().isNotEmpty
          ? validation.clientId.trim()
          : _clientId,
      token: token,
    );
  }

  Future<String?> _waitForTwitchWebToken() async {
    for (var attempt = 0; attempt < 24; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));

      try {
        final dynamic cookies = await WebviewManager().visitUrlCookies(
          _homeUrl,
          true,
        );
        final token = _findAuthTokenInCookieData(cookies);
        if (token != null && token.isNotEmpty) return token;
      } catch (_) {}

      // Fallback for non-HttpOnly representations used by some Twitch builds.
      try {
        final dynamic raw = await _controller.evaluateJavascript(r'''
(function() {
  const output = {
    cookie: document.cookie || '',
    localStorage: {},
    sessionStorage: {}
  };
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (key) output.localStorage[key] = localStorage.getItem(key);
    }
  } catch (_) {}
  try {
    for (let i = 0; i < sessionStorage.length; i++) {
      const key = sessionStorage.key(i);
      if (key) output.sessionStorage[key] = sessionStorage.getItem(key);
    }
  } catch (_) {}
  return JSON.stringify(output);
})();
''');
        final token = _findAuthTokenInText(raw?.toString() ?? '');
        if (token != null && token.isNotEmpty) return token;
      } catch (_) {}
    }
    return null;
  }

  String? _findAuthTokenInCookieData(dynamic value) {
    if (value is Map) {
      final name = value['name']?.toString().toLowerCase();
      final key = value['key']?.toString().toLowerCase();
      if (name == 'auth-token' || key == 'auth-token') {
        final token = (value['value'] ?? value['val'])?.toString().trim();
        if (token != null && token.length >= 20) return token;
      }
      for (final nested in value.values) {
        final token = _findAuthTokenInCookieData(nested);
        if (token != null) return token;
      }
    } else if (value is Iterable) {
      for (final nested in value) {
        final token = _findAuthTokenInCookieData(nested);
        if (token != null) return token;
      }
    } else if (value is String) {
      return _findAuthTokenInText(value);
    }
    return null;
  }

  String? _findAuthTokenInText(String raw) {
    final cookieMatch = RegExp(
      r'(?:^|[;,\\s])auth-token=([^;,\\s"\\}]+)',
      caseSensitive: false,
    ).firstMatch(raw);
    final cookieToken = cookieMatch?.group(1)?.trim();
    if (cookieToken != null && cookieToken.length >= 20) {
      return Uri.decodeComponent(cookieToken);
    }

    for (final pattern in <RegExp>[
      RegExp(
        r'''["']auth-token["']\\s*[:=]\\s*["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''["']authToken["']\\s*[:=]\\s*["']([^"']+)["']''',
        caseSensitive: false,
      ),
    ]) {
      final token = pattern.firstMatch(raw)?.group(1)?.trim();
      if (token != null && token.length >= 20) return token;
    }

    try {
      return _findAuthTokenInJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  String? _findAuthTokenInJson(dynamic value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        final nested = entry.value;
        if ((key == 'auth-token' || key == 'authtoken') &&
            nested is String &&
            nested.trim().length >= 20) {
          return nested.trim();
        }
        final token = _findAuthTokenInJson(nested);
        if (token != null) return token;
      }
    } else if (value is Iterable) {
      for (final nested in value) {
        final token = _findAuthTokenInJson(nested);
        if (token != null) return token;
      }
    }
    return null;
  }

  Future<void> _saveAndVerifyWebGqlToken(String webToken) async {
    final token = TwitchAuthToken(
      accessToken: webToken.trim(),
      refreshToken: '',
      tokenType: 'bearer',
      scopes: const <String>[],
      expiresIn: const Duration(days: 30).inSeconds,
      obtainedAt: DateTime.now(),
    );

    await widget.webGqlAuthService.saveSession(token);

    final raw = await widget.apiClient.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': 'ChannelPointsContext',
        'query': r'''
query ChannelPointsContext($channelLogin: String!) {
  user(login: $channelLogin) {
    id
    login
    displayName
    channel {
      id
      self {
        communityPoints {
          balance
          availableClaim { id }
        }
      }
    }
  }
}
''',
        'variables': <String, dynamic>{'channelLogin': 'twitch'},
      },
      headers: <String, String>{
        'Client-ID': TwitchApiConstants.twitchWebClientId,
        'Authorization': 'OAuth ${webToken.trim()}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    if (raw is! Map) throw StateError('Invalid GQL response');
    final errors = raw['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw StateError('GQL authentication failed');
    }
    final data = raw['data'];
    if (data is! Map || data['user'] == null) {
      throw StateError('GQL user unavailable');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _errorText = message);
  }

  Future<void> _restart() async {
    if (_finishing) return;
    _state = _createStateToken();
    setState(() {
      _errorText = null;
      _ready = false;
    });
    _controller.loadUrl(_buildAuthorizationUri().toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          '登入 Twitch',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_errorText != null)
            IconButton(
              tooltip: '重新載入',
              onPressed: _finishing ? null : _restart,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<bool>(
              valueListenable: _controller,
              builder: (context, ready, child) {
                if (!ready) return _controller.loadingWidget;
                return _controller.webviewWidget;
              },
            ),
          ),
          if (!_ready || _finishing)
            const Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (_errorText != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Material(
                color: const Color(0xFF2A120F),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _errorText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
