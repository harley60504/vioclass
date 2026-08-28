import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, Platform;
import 'dart:math';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';
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

/// Main Twitch OAuth login.
///
/// v30:
/// - Desktop uses desktop_webview_window.
/// - Android / iOS uses an embedded InAppWebView.
/// - The same auth container captures official Twitch Web / kimne GQL token
///   after the main OAuth token is saved, so one-click login does not open
///   a separate Web/GQL step.
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

  late final TextEditingController _clientIdController;
  late final TextEditingController _redirectUriController;
  late final TextEditingController _manualTextController;

  String _state = '';
  String _statusText = '準備開啟 Twitch OAuth 視窗...';
  String? _errorText;
  String _currentUrlText = '';

  bool _openingWindow = false;
  bool _windowOpen = false;
  bool _embeddedWebViewReady = false;
  bool _isCompleting = false;
  bool _showAdvanced = false;
  bool _capturingGql = false;
  bool _mainTokenSaved = false;
  bool _webGqlCaptured = false;

  bool get _isMain => widget.target == TwitchOAuthWebViewTokenTarget.main;

  bool get _isDesktopAuthWindowPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool get _useEmbeddedMobileWebView => !_isDesktopAuthWindowPlatform;

  String get _clientId {
    final text = _clientIdController.text.trim();
    return text.isNotEmpty ? text : TwitchOAuthWebViewLoginPage.legacyClientId;
  }

  String get _redirectUri {
    final text = _redirectUriController.text.trim();
    return text.isNotEmpty
        ? text
        : TwitchOAuthWebViewLoginPage.legacyRedirectUri;
  }

  List<String> get _scopes {
    return widget.scopes.isEmpty
        ? TwitchOAuthWebViewLoginPage.legacyScopes
        : widget.scopes;
  }

  bool get _shouldCaptureGql {
    return widget.captureWebGqlToken &&
        widget.webGqlAuthService != null &&
        widget.apiClient != null;
  }

  @override
  void initState() {
    super.initState();
    _state = _createStateToken();
    _clientIdController = TextEditingController(
      text: widget.initialClientId.trim().isEmpty
          ? TwitchOAuthWebViewLoginPage.legacyClientId
          : widget.initialClientId.trim(),
    );
    _redirectUriController = TextEditingController(
      text: widget.initialRedirectUri.trim().isEmpty
          ? TwitchOAuthWebViewLoginPage.legacyRedirectUri
          : widget.initialRedirectUri.trim(),
    );
    _manualTextController = TextEditingController();
    _currentUrlText = _buildAuthorizationUri().toString();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDesktopAuthWindowPlatform) {
        unawaited(_openDesktopWindow(_currentUrlText));
      } else {
        setState(() {
          _statusText = _shouldCaptureGql
              ? '請在 App 內 WebView 完成主 OAuth；完成後會切到 Twitch 官方頁擷取 Web/GQL 資訊。'
              : '請在 App 內 WebView 完成主 OAuth。';
        });
      }
    });
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _redirectUriController.dispose();
    _manualTextController.dispose();
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
    final isHttpLocalhost3000 = uri.scheme == 'http' && uri.port == 3000;
    final isHttpsLocalhostDefault =
        uri.scheme == 'https' && (!uri.hasPort || uri.port == 443);
    return isHttpLocalhost3000 || isHttpsLocalhostDefault;
  }

  Future<bool> _tryHandleOAuthRedirect(Uri? uri) async {
    if (uri == null) return false;
    if (!_isRedirectUri(uri)) return false;
    await _handleOAuthRedirect(uri);
    return true;
  }

  Future<void> _handleOAuthRedirect(Uri uri) async {
    if (_isCompleting) return;

    final params = _parseOAuthResponse(uri);
    final error = params['error'];
    final errorDescription = params['error_description'];

    if (error != null && error.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _errorText = errorDescription?.isNotEmpty == true
            ? '$error：$errorDescription'
            : error;
        _statusText = 'Twitch OAuth 授權失敗。';
      });
      return;
    }

    final returnedState = params['state'];
    if (returnedState == null ||
        returnedState.isEmpty ||
        returnedState != _state) {
      if (!mounted) return;
      setState(() {
        _errorText = 'OAuth 回傳狀態不一致，已阻擋這次授權。';
        _statusText = 'Twitch OAuth 回傳驗證失敗。';
      });
      return;
    }

    final accessToken = params['access_token'];
    if (accessToken == null || accessToken.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorText = 'OAuth 回傳沒有可用授權。';
        _statusText = '尚未取得 Twitch 授權。';
      });
      return;
    }

    final expiresIn = int.tryParse(params['expires_in'] ?? '') ?? 14400;
    final scopes = _parseScopes(params['scope']);

    _isCompleting = true;
    if (mounted) {
      setState(() {
        _errorText = null;
        _statusText = '已取得 Twitch 授權，正在驗證並儲存...';
      });
    }

    await _saveAccessToken(
      accessToken: accessToken,
      expiresIn: expiresIn,
      scopes: scopes,
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

      _mainTokenSaved = true;

      if (_shouldCaptureGql) {
        await _captureWebGqlTokenFromSameWindow();
      }

      await _closeWindow();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _isCompleting = false;
      if (!mounted) return;
      setState(() {
        _errorText = '登入流程未完成，請重新授權後再試。';
        _statusText = 'OAuth 已回傳，但授權驗證、儲存或 Web/GQL 擷取失敗。';
      });
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

    if (!mounted) return;
    setState(() {
      _capturingGql = true;
      _statusText = '主 OAuth 已完成，正在同一個視窗擷取官方 Web/GQL 資訊...';
      _currentUrlText = _homeUrl;
    });

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
      if (!mounted) return;
      setState(() {
        _capturingGql = false;
        _statusText = '主 OAuth 已完成，但未從同一視窗讀到 Web/GQL 資訊。';
      });
      return;
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

    if (!mounted) return;
    setState(() {
      _capturingGql = false;
      _webGqlCaptured = true;
      _statusText = '主 OAuth 與官方 Web/GQL 都已完成。';
    });
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
  } catch (e) { output.localStorageError = String(e && (e.stack || e.message || e)); }
  try {
    for (let i = 0; i < window.sessionStorage.length; i++) {
      const key = window.sessionStorage.key(i);
      if (key) output.sessionStorage[key] = window.sessionStorage.getItem(key);
    }
  } catch (e) { output.sessionStorageError = String(e && (e.stack || e.message || e)); }
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
  } catch (e) { output.localStorageError = String(e && (e.stack || e.message || e)); }
  try {
    for (let i = 0; i < window.sessionStorage.length; i++) {
      const key = window.sessionStorage.key(i);
      if (key) output.sessionStorage[key] = window.sessionStorage.getItem(key);
    }
  } catch (e) { output.sessionStorageError = String(e && (e.stack || e.message || e)); }
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
      final parsed = jsonDecode(text);
      return _findTokenInJson(parsed);
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

    if (raw is! Map) throw StateError('GQL 回傳格式不是 Map：${raw.runtimeType}');
    final errors = raw['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw StateError('GQL errors: $errors');
    }
    final data = raw['data'];
    if (data is! Map || data['user'] == null) {
      throw StateError('GQL 沒有回傳 data.user。');
    }
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

  Future<void> _openDesktopWindow(String url) async {
    if (!_isDesktopAuthWindowPlatform) {
      if (!mounted) return;
      setState(() {
        _currentUrlText = url;
        _statusText = '目前平台使用 App 內 WebView，不開桌面授權視窗。';
      });
      try {
        await _embeddedController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(url)),
        );
      } catch (_) {}
      return;
    }

    if (_openingWindow) return;
    setState(() {
      _openingWindow = true;
      _errorText = null;
      _statusText = '正在建立 Twitch OAuth 授權視窗...';
      _currentUrlText = url;
    });

    await _closeWindow();

    try {
      final folder = sharedDesktopWebViewUserDataFolder();
      final window = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: 'Twitch 主 OAuth 登入',
          windowWidth: 1120,
          windowHeight: 820,
          userDataFolderWindows: folder,
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
          if (mounted) {
            setState(() {
              _currentUrlText = nextUrl;
            });
          }
          final uri = Uri.tryParse(nextUrl);
          unawaited(_tryHandleOAuthRedirect(uri));
        });
      } catch (_) {}

      try {
        window.onClose.whenComplete(() {
          if (!mounted) return;
          setState(() {
            _windowOpen = false;
            if (!_isCompleting) _statusText = 'OAuth 授權視窗已關閉。';
          });
        });
      } catch (_) {}

      window.launch(url);

      if (!mounted) return;
      setState(() {
        _openingWindow = false;
        _windowOpen = true;
        _statusText = _shouldCaptureGql
            ? '請在彈出的 Twitch OAuth 視窗完成授權；完成後會在同一視窗擷取官方 Web/GQL 資訊。'
            : '請在彈出的 Twitch OAuth 視窗完成授權。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _openingWindow = false;
        _windowOpen = false;
        _errorText = '建立 Twitch OAuth 視窗失敗，請稍後再試。';
        _statusText = '無法開啟桌面授權視窗。';
      });
    }
  }

  Future<void> _closeWindow() async {
    if (!_isDesktopAuthWindowPlatform) {
      return;
    }
    final window = _webWindow;
    _webWindow = null;
    if (window == null) return;
    try {
      window.close();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _windowOpen = false;
    });
  }

  Future<void> _reloadOAuth() async {
    _state = _createStateToken();
    final uri = _buildAuthorizationUri();
    setState(() {
      _errorText = null;
      _statusText = '正在重新載入 Twitch OAuth...';
      _currentUrlText = uri.toString();
      _mainTokenSaved = false;
      _webGqlCaptured = false;
    });
    await _openDesktopWindow(uri.toString());
  }

  Future<void> _copyAuthorizationUrl() async {
    final uri = _buildAuthorizationUri();
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已複製 Twitch OAuth 連結')));
  }

  Future<void> _tryManualInput() async {
    final text = _manualTextController.text.trim();
    if (text.isEmpty) return;

    final uri = Uri.tryParse(text);
    if (uri != null) {
      final handled = await _tryHandleOAuthRedirect(uri);
      if (handled) return;
    }

    await _saveAccessToken(
      accessToken: text,
      expiresIn: 14400,
      scopes: _scopes,
    );
  }

  Future<void> _pasteAndTry() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _manualTextController.text = text;
    await _tryManualInput();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _openingWindow || _isCompleting || _capturingGql;
    return Scaffold(
      backgroundColor: const Color(0xFF18181B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0E10),
        foregroundColor: Colors.white,
        title: const Text('Twitch 主 OAuth 登入'),
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
          _buildStatusBar(),
          if (_errorText != null) _buildErrorBanner(),
          if (_showAdvanced) _buildAdvancedPanel(),
          if (!_useEmbeddedMobileWebView) _buildActionBar(busy),
          Expanded(
            child: _useEmbeddedMobileWebView
                ? _buildEmbeddedOAuthWebView()
                : _buildMainPanel(busy),
          ),
          _buildBottomStatus(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      color: const Color(0xFF111116),
      child: Row(
        children: [
          Icon(
            _windowOpen
                ? Icons.open_in_new_rounded
                : Icons.web_asset_off_rounded,
            color: _windowOpen ? const Color(0xFF5CFFB1) : Colors.white54,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_openingWindow || _isCompleting || _capturingGql)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: TwitchUiColors.primarySoft,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.redAccent.withValues(alpha: 0.18),
      child: Text(
        _errorText!,
        style: const TextStyle(
          color: Colors.orangeAccent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildActionBar(bool busy) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E10),
        border: Border(bottom: BorderSide(color: Color(0xFF2D2D35))),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: busy ? null : _reloadOAuth,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重新開 OAuth'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () => setState(() => _showAdvanced = !_showAdvanced),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('進階'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _copyAuthorizationUrl,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('複製 OAuth 連結'),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              _useEmbeddedMobileWebView
                  ? (_embeddedWebViewReady
                        ? 'App 內 OAuth 頁已載入'
                        : '等待 App 內 OAuth 頁...')
                  : (_windowOpen ? '桌面授權視窗已開啟' : '等待授權視窗...'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedOAuthWebView() {
    final url = _currentUrlText.trim().isEmpty
        ? _buildAuthorizationUri().toString()
        : _currentUrlText.trim();

    return Column(
      children: [
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(url)),
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
              final nextUrl = action.request.url?.toString();
              if (nextUrl != null) {
                final uri = Uri.tryParse(nextUrl);
                if (await _tryHandleOAuthRedirect(uri)) {
                  return NavigationActionPolicy.CANCEL;
                }
                if (mounted) {
                  setState(() => _currentUrlText = nextUrl);
                }
              }
              return NavigationActionPolicy.ALLOW;
            },
            onLoadStart: (controller, webUri) {
              final nextUrl = webUri?.toString();
              if (nextUrl != null) {
                final uri = Uri.tryParse(nextUrl);
                unawaited(_tryHandleOAuthRedirect(uri));
              }
              if (!mounted) return;
              setState(() {
                _embeddedWebViewReady = false;
                if (nextUrl != null) _currentUrlText = nextUrl;
                _statusText = 'App 內 WebView 正在載入 Twitch OAuth...';
              });
            },
            onLoadStop: (controller, webUri) {
              final nextUrl = webUri?.toString();
              if (!mounted) return;
              setState(() {
                _embeddedWebViewReady = true;
                if (nextUrl != null) _currentUrlText = nextUrl;
                if (!_isCompleting && !_capturingGql) {
                  _statusText = _shouldCaptureGql
                      ? '請完成 OAuth；完成後會在同一個 App 內 WebView 擷取 Web/GQL 資訊。'
                      : '請完成 Twitch OAuth。';
                }
              });
            },
            onUpdateVisitedHistory: (controller, webUri, androidIsReload) {
              final nextUrl = webUri?.toString();
              if (nextUrl != null) {
                final uri = Uri.tryParse(nextUrl);
                unawaited(_tryHandleOAuthRedirect(uri));
              }
              if (mounted && nextUrl != null) {
                setState(() => _currentUrlText = nextUrl);
              }
            },
            onReceivedError: (controller, request, error) {
              if (!mounted || request.isForMainFrame != true) return;
              setState(() {
                _errorText = 'App 內 Twitch 登入頁暫時載入失敗，請稍後重試。';
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMainPanel(bool busy) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111116),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _windowOpen ? Icons.login_rounded : Icons.login_outlined,
              color: _windowOpen ? const Color(0xFF5CFFB1) : Colors.white38,
              size: 58,
            ),
            const SizedBox(height: 14),
            const Text(
              '主 OAuth 授權',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _shouldCaptureGql
                  ? '這一步會在同一個授權容器內完成主 OAuth，接著切回 Twitch 官方頁讀取 Web/GQL 資訊，不再另外跳一次 Web/GQL。'
                  : '這一步會完成你的 App OAuth，OAuth redirect 到 localhost 時會直接攔截授權回傳。',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _StatusChip(done: _mainTokenSaved, label: '主 OAuth'),
                if (_shouldCaptureGql)
                  _StatusChip(done: _webGqlCaptured, label: '官方 Web/GQL'),
              ],
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: busy ? null : _reloadOAuth,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(_windowOpen ? '重開 OAuth 視窗' : '開啟 OAuth 視窗'),
              style: ElevatedButton.styleFrom(
                backgroundColor: TwitchUiColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            SelectableText(
              _currentUrlText,
              maxLines: 3,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white30,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedPanel() {
    return Container(
      color: const Color(0xFF111116),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _clientIdController,
                  enabled: !_isCompleting,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Client-ID',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _redirectUriController,
                  enabled: !_isCompleting,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Redirect URI',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isCompleting ? null : _reloadOAuth,
                child: const Text('套用'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualTextController,
                  enabled: !_isCompleting,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'redirect URL 或 access token',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _isCompleting ? null : _pasteAndTry,
                icon: const Icon(Icons.content_paste),
                label: const Text('貼上'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isCompleting ? null : _tryManualInput,
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E10),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2E))),
      ),
      child: Text(
        _currentUrlText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool done;
  final String label;

  const _StatusChip({required this.done, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done
            ? Colors.greenAccent.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: done
              ? Colors.greenAccent.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 15,
            color: done ? Colors.greenAccent : Colors.white54,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: done ? Colors.greenAccent : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
