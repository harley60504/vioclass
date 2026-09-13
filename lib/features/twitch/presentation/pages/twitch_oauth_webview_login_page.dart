import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, Platform;
import 'dart:math';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../models/auth/twitch_auth_token.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../theme/twitch_ui_tokens.dart';
import 'twitch_interaction_web_login_page.dart';

enum TwitchOAuthWebViewTokenTarget { main }

class TwitchOAuthWebViewLoginPage extends StatefulWidget {
  final TwitchOAuthWebViewTokenTarget target;
  final TwitchAuthService mainAuthService;
  final TwitchDropsAuthService? interactionAuthService;
  final TwitchAuthApiService authApi;
  final TwitchWebGqlAuthService? webGqlAuthService;
  final TwitchApiClient? apiClient;
  final bool captureWebGqlToken;
  final String initialClientId;
  final String initialRedirectUri;
  final List<String> scopes;
  final bool mirrorMainTokenToInteraction;

  const TwitchOAuthWebViewLoginPage({
    super.key,
    this.target = TwitchOAuthWebViewTokenTarget.main,
    required this.mainAuthService,
    this.interactionAuthService,
    required this.authApi,
    this.webGqlAuthService,
    this.apiClient,
    this.captureWebGqlToken = false,
    this.initialClientId = legacyClientId,
    this.initialRedirectUri = legacyRedirectUri,
    this.scopes = legacyScopes,
    this.mirrorMainTokenToInteraction = true,
  });

  static const String legacyClientId = 'euyqoof00efejc6vk5f4gv0nze20ue';
  static const String legacyRedirectUri = 'http://localhost:3000';

  static const List<String> legacyScopes = <String>[
    'user:read:email',
    'user:read:follows',
    'chat:read',
    'chat:edit',
    'user:read:emotes',
    'clips:edit',
  ];

  @override
  State<TwitchOAuthWebViewLoginPage> createState() =>
      _TwitchOAuthWebViewLoginPageState();
}

class _TwitchOAuthWebViewLoginPageState
    extends State<TwitchOAuthWebViewLoginPage> {
  static const String _homeUrl = 'https://www.twitch.tv/';

  dynamic _webWindow;
  InAppWebViewController? _embeddedController;

  late String _clientId;
  late String _redirectUri;
  late String _state;

  bool _openingWindow = false;
  bool _windowOpen = false;
  bool _isCompleting = false;
  bool _capturingGql = false;
  String? _errorText;

  bool get _isMain => widget.target == TwitchOAuthWebViewTokenTarget.main;

  bool get _isDesktopAuthWindowPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool get _useEmbeddedMobileWebView => !_isDesktopAuthWindowPlatform;

  List<String> get _scopes => widget.scopes.isEmpty
      ? TwitchOAuthWebViewLoginPage.legacyScopes
      : widget.scopes;

  bool get _shouldCaptureGql =>
      widget.captureWebGqlToken &&
      widget.webGqlAuthService != null &&
      widget.apiClient != null;

  @override
  void initState() {
    super.initState();
    _clientId = widget.initialClientId.trim().isEmpty
        ? TwitchOAuthWebViewLoginPage.legacyClientId
        : widget.initialClientId.trim();
    _redirectUri = widget.initialRedirectUri.trim().isEmpty
        ? TwitchOAuthWebViewLoginPage.legacyRedirectUri
        : widget.initialRedirectUri.trim();
    _state = _createStateToken();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDesktopAuthWindowPlatform) {
        unawaited(_openDesktopWindow());
      }
    });
  }

  @override
  void dispose() {
    _embeddedController = null;
    unawaited(_closeWindow());
    super.dispose();
  }

  static String sharedDesktopWebViewUserDataFolder() {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'new_twitch_app_shared_twitch_desktop_webview_v30';
    try {
      Directory(path).createSync(recursive: true);
    } catch (_) {}
    return path;
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
    final configured = Uri.tryParse(_redirectUri);
    if (configured != null) {
      final sameScheme =
          uri.scheme.toLowerCase() == configured.scheme.toLowerCase();
      final sameHost = uri.host.toLowerCase() == configured.host.toLowerCase();
      final samePort = uri.hasPort
          ? uri.port == configured.port
          : configured.hasPort
              ? false
              : true;
      if (sameScheme && sameHost && samePort) return true;
    }

    final host = uri.host.toLowerCase();
    if (host != 'localhost' && host != '127.0.0.1') return false;
    return (uri.scheme == 'http' && uri.port == 3000) ||
        (uri.scheme == 'https' && (!uri.hasPort || uri.port == 443));
  }

  Map<String, String> _parseOAuthResponse(Uri uri) {
    final output = <String, String>{};
    if (uri.query.isNotEmpty) output.addAll(Uri.splitQueryString(uri.query));
    if (uri.fragment.isNotEmpty) {
      output.addAll(Uri.splitQueryString(uri.fragment));
    }
    return output;
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

  Future<bool> _tryHandleOAuthRedirect(Uri? uri) async {
    if (uri == null || !_isRedirectUri(uri)) return false;
    await _handleOAuthRedirect(uri);
    return true;
  }

  Future<void> _handleOAuthRedirect(Uri uri) async {
    if (_isCompleting) return;

    final params = _parseOAuthResponse(uri);
    final error = params['error'];
    if (error != null && error.isNotEmpty) {
      _showError('Twitch 登入失敗，請再試一次。');
      return;
    }

    final returnedState = params['state'];
    if (returnedState == null || returnedState != _state) {
      _showError('登入驗證失敗，請重新登入。');
      return;
    }

    final accessToken = params['access_token'];
    if (accessToken == null || accessToken.trim().isEmpty) {
      _showError('沒有取得登入授權，請再試一次。');
      return;
    }

    _isCompleting = true;
    if (mounted) setState(() => _errorText = null);

    await _saveAccessToken(
      accessToken: accessToken,
      expiresIn: int.tryParse(params['expires_in'] ?? '') ?? 14400,
      scopes: _parseScopes(params['scope']),
    );
  }

  Future<void> _saveAccessToken({
    required String accessToken,
    required int expiresIn,
    required List<String> scopes,
  }) async {
    try {
      final validation = await widget.authApi.validateToken(accessToken);
      final token = TwitchAuthToken(
        accessToken: accessToken.trim(),
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

      if (_isMain &&
          widget.mirrorMainTokenToInteraction &&
          widget.interactionAuthService != null) {
        await widget.interactionAuthService!.setDropsClientId(
          TwitchApiConstants.twitchWebClientId,
          clearTokenOnChange: false,
        );
        await widget.interactionAuthService!.saveSession(token);
      }

      if (_shouldCaptureGql) {
        await _captureWebGqlTokenFromSameWindow();
      }

      await _closeWindow();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      _isCompleting = false;
      _showError('登入沒有完成，請重新登入。');
    }
  }

  Future<void> _captureWebGqlTokenFromSameWindow() async {
    final webGqlAuthService = widget.webGqlAuthService;
    final apiClient = widget.apiClient;
    if (webGqlAuthService == null || apiClient == null) return;

    final window = _webWindow;
    final embeddedController = _embeddedController;
    if (_isDesktopAuthWindowPlatform && window == null) return;
    if (_useEmbeddedMobileWebView && embeddedController == null) return;

    _capturingGql = true;
    if (mounted) setState(() {});

    try {
      if (_isDesktopAuthWindowPlatform) {
        window.launch(_homeUrl);
      } else {
        await embeddedController!.loadUrl(
          urlRequest: URLRequest(url: WebUri(_homeUrl)),
        );
      }
    } catch (_) {}

    String? webToken;
    for (var i = 0; i < 18; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      try {
        webToken = _isDesktopAuthWindowPlatform
            ? await _readTwitchWebAuthTokenFromWindow(window)
            : await _readTwitchWebAuthTokenFromEmbeddedWebView(
                embeddedController!,
              );
      } catch (_) {
        webToken = null;
      }
      if (webToken != null && webToken.trim().isNotEmpty) break;
    }

    if (webToken == null || webToken.trim().isEmpty) {
      _capturingGql = false;
      if (mounted) setState(() {});
      throw StateError('Web/GQL token not available');
    }

    final token = TwitchAuthToken(
      accessToken: webToken.trim(),
      refreshToken: '',
      tokenType: 'bearer',
      scopes: const <String>[],
      expiresIn: const Duration(days: 30).inSeconds,
      obtainedAt: DateTime.now(),
    );

    await webGqlAuthService.saveSession(token);
    await _verifyKimneGql(apiClient, webToken);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      TwitchInteractionWebLoginPage.interactionGqlVerifiedStorageKey,
      DateTime.now().toIso8601String(),
    );

    _capturingGql = false;
    if (mounted) setState(() {});
  }

  Future<String?> _readTwitchWebAuthTokenFromWindow(dynamic window) async {
    const js = r'''
(function() {
  const output = {
    href: window.location.href,
    cookie: document.cookie || '',
    localStorage: {},
    sessionStorage: {}
  };
  try {
    for (let i = 0; i < window.localStorage.length; i++) {
      const key = window.localStorage.key(i);
      if (key) output.localStorage[key] = window.localStorage.getItem(key);
    }
  } catch (e) {}
  try {
    for (let i = 0; i < window.sessionStorage.length; i++) {
      const key = window.sessionStorage.key(i);
      if (key) output.sessionStorage[key] = window.sessionStorage.getItem(key);
    }
  } catch (e) {}
  return JSON.stringify(output);
})();
''';
    final raw = await window.evaluateJavaScript(js);
    return _tryExtractTokenFromText(raw?.toString() ?? '');
  }

  Future<String?> _readTwitchWebAuthTokenFromEmbeddedWebView(
    InAppWebViewController controller,
  ) async {
    const js = r'''
(function() {
  const output = {
    href: window.location.href,
    cookie: document.cookie || '',
    localStorage: {},
    sessionStorage: {}
  };
  try {
    for (let i = 0; i < window.localStorage.length; i++) {
      const key = window.localStorage.key(i);
      if (key) output.localStorage[key] = window.localStorage.getItem(key);
    }
  } catch (e) {}
  try {
    for (let i = 0; i < window.sessionStorage.length; i++) {
      const key = window.sessionStorage.key(i);
      if (key) output.sessionStorage[key] = window.sessionStorage.getItem(key);
    }
  } catch (e) {}
  return JSON.stringify(output);
})();
''';
    final raw = await controller.evaluateJavascript(source: js);
    return _tryExtractTokenFromText(raw?.toString() ?? '');
  }

  String? _tryExtractTokenFromText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final cookieMatch = RegExp(
      r'(?:^|[;,\s])auth-token=([^;,\s"\}]+)',
      caseSensitive: false,
    ).firstMatch(text);
    final cookieToken = cookieMatch?.group(1)?.trim();
    if (cookieToken != null && cookieToken.isNotEmpty) {
      return Uri.decodeComponent(cookieToken);
    }

    final patterns = <RegExp>[
      RegExp(
        r'''["']auth-token["']\s*[:=]\s*["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''["']authToken["']\s*[:=]\s*["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''["']accessToken["']\s*[:=]\s*["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''["']token["']\s*[:=]\s*["']([^"']{20,})["']''',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      final token = match?.group(1)?.trim();
      if (token != null && token.length >= 20) return token;
    }

    try {
      return _findTokenInJson(jsonDecode(text));
    } catch (_) {
      return null;
    }
  }

  String? _findTokenInJson(dynamic value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        final item = entry.value;
        if ((key == 'auth-token' ||
                key == 'authtoken' ||
                key == 'accesstoken' ||
                key == 'token') &&
            item is String &&
            item.trim().length >= 20) {
          return item.trim();
        }
        final nested = _findTokenInJson(item);
        if (nested != null && nested.isNotEmpty) return nested;
      }
    }
    if (value is List) {
      for (final item in value) {
        final nested = _findTokenInJson(item);
        if (nested != null && nested.isNotEmpty) return nested;
      }
    }
    return null;
  }

  Future<void> _verifyKimneGql(TwitchApiClient apiClient, String token) async {
    final query = r'''
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
          availableClaim {
            id
          }
        }
      }
    }
  }
}
''';

    final raw = await apiClient.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': 'ChannelPointsContext',
        'query': query,
        'variables': <String, dynamic>{'channelLogin': 'twitch'},
      },
      headers: <String, String>{
        'Client-ID': TwitchApiConstants.twitchWebClientId,
        'Authorization': 'OAuth ${token.trim()}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    if (raw is! Map) throw StateError('Invalid GQL response');
    final errors = raw['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw StateError('GQL validation failed');
    }
    final data = raw['data'];
    if (data is! Map || data['user'] == null) {
      throw StateError('GQL validation failed');
    }
  }

  Future<void> _openDesktopWindow() async {
    if (!_isDesktopAuthWindowPlatform || _openingWindow) return;

    setState(() {
      _openingWindow = true;
      _errorText = null;
    });

    await _closeWindow();

    try {
      final window = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: 'Twitch 登入',
          windowWidth: 1120,
          windowHeight: 820,
          userDataFolderWindows: sharedDesktopWebViewUserDataFolder(),
        ),
      );

      _webWindow = window;
      _windowOpen = true;

      try {
        window.setApplicationNameForUserAgent('NewTwitchAppUnifiedAuth/1.0');
      } catch (_) {}
      try {
        window.setBrightness(Brightness.dark);
      } catch (_) {}
      try {
        window.addOnUrlRequestCallback((String nextUrl) {
          unawaited(_tryHandleOAuthRedirect(Uri.tryParse(nextUrl)));
        });
      } catch (_) {}
      try {
        window.onClose.whenComplete(() {
          if (!mounted) return;
          setState(() => _windowOpen = false);
        });
      } catch (_) {}

      window.launch(_buildAuthorizationUri().toString());
      if (!mounted) return;
      setState(() => _openingWindow = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _openingWindow = false;
        _windowOpen = false;
        _errorText = '無法開啟 Twitch 登入視窗，請再試一次。';
      });
    }
  }

  Future<void> _closeWindow() async {
    if (!_isDesktopAuthWindowPlatform) return;
    final window = _webWindow;
    _webWindow = null;
    if (window == null) return;
    try {
      window.close();
    } catch (_) {}
    if (mounted) setState(() => _windowOpen = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _errorText = message);
  }

  Widget _buildEmbeddedOAuthWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(_buildAuthorizationUri().toString()),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        supportZoom: false,
        transparentBackground: false,
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
      ),
      onWebViewCreated: (controller) {
        _embeddedController = controller;
      },
      shouldOverrideUrlLoading: (controller, action) async {
        final uri = action.request.url;
        if (await _tryHandleOAuthRedirect(
          uri == null ? null : Uri.tryParse(uri.toString()),
        )) {
          return NavigationActionPolicy.CANCEL;
        }
        // Twitch 官方頁面的所有登入方式都保持可用，包括它提供的
        // Google 等第三方登入流程，不額外限制網域或登入方式。
        return NavigationActionPolicy.ALLOW;
      },
      onLoadStart: (controller, webUri) {
        final nextUrl = webUri?.toString();
        if (nextUrl != null) {
          unawaited(_tryHandleOAuthRedirect(Uri.tryParse(nextUrl)));
        }
      },
      onLoadStop: (controller, webUri) {
        final nextUrl = webUri?.toString();
        if (nextUrl != null) {
          unawaited(_tryHandleOAuthRedirect(Uri.tryParse(nextUrl)));
        }
      },
      onUpdateVisitedHistory: (controller, webUri, androidIsReload) {
        final nextUrl = webUri?.toString();
        if (nextUrl != null) {
          unawaited(_tryHandleOAuthRedirect(Uri.tryParse(nextUrl)));
        }
      },
      onReceivedError: (controller, request, error) {
        if (!mounted || request.isForMainFrame != true) return;
        _showError('Twitch 登入頁載入失敗，請稍後再試。');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _openingWindow || _isCompleting || _capturingGql;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0E10),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '登入 Twitch',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: '關閉',
            onPressed: _isCompleting
                ? null
                : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_errorText != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.redAccent.withValues(alpha: 0.14),
              child: Text(
                _errorText!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: _useEmbeddedMobileWebView
                ? _buildEmbeddedOAuthWebView()
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (busy)
                            const CircularProgressIndicator(
                              color: TwitchUiColors.primarySoft,
                            )
                          else
                            Icon(
                              _windowOpen
                                  ? Icons.open_in_new_rounded
                                  : Icons.login_rounded,
                              size: 48,
                              color: TwitchUiColors.primarySoft,
                            ),
                          const SizedBox(height: 18),
                          Text(
                            _capturingGql
                                ? '正在完成登入…'
                                : _windowOpen
                                    ? '請在 Twitch 視窗完成登入'
                                    : 'Twitch 登入視窗已關閉',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (!_windowOpen && !busy) ...[
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: _openDesktopWindow,
                              icon: const Icon(Icons.login_rounded),
                              label: const Text('重新開啟登入'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TwitchUiColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
