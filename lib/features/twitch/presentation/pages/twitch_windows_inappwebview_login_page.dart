import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, Platform;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../models/auth/twitch_auth_token.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';

class TwitchWindowsInAppWebViewLoginPage extends StatefulWidget {
  final TwitchAuthService mainAuthService;
  final TwitchAuthApiService authApi;
  final TwitchWebGqlAuthService webGqlAuthService;
  final TwitchApiClient apiClient;

  const TwitchWindowsInAppWebViewLoginPage({
    super.key,
    required this.mainAuthService,
    required this.authApi,
    required this.webGqlAuthService,
    required this.apiClient,
  });

  @override
  State<TwitchWindowsInAppWebViewLoginPage> createState() =>
      _TwitchWindowsInAppWebViewLoginPageState();
}

class _TwitchWindowsInAppWebViewLoginPageState
    extends State<TwitchWindowsInAppWebViewLoginPage> {
  static const String _clientId = 'euyqoof00efejc6vk5f4gv0nze20ue';
  static const String _redirectUri = 'http://localhost:3000';
  static const List<String> _scopes = <String>[
    'user:read:email',
    'user:read:follows',
    'chat:read',
    'chat:edit',
    'user:read:emotes',
    'clips:edit',
  ];

  WebViewEnvironment? _environment;
  InAppWebViewController? _controller;
  late final String _state;
  bool _initializing = true;
  bool _completing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _state = _createStateToken();
    unawaited(_initEnvironment());
  }

  String _createStateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Uri _authorizationUri() {
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

  Future<void> _initEnvironment() async {
    try {
      if (!Platform.isWindows) {
        throw StateError('Windows InAppWebView test is Windows-only.');
      }
      final version = await WebViewEnvironment.getAvailableVersion();
      if (version == null) {
        throw StateError('WebView2 Runtime is not installed.');
      }
      final folder =
          '${Directory.systemTemp.path}${Platform.pathSeparator}'
          'vioclass_inappwebview_twitch_windows';
      Directory(folder).createSync(recursive: true);
      final environment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: folder),
      );
      debugPrint('[TwitchInAppWebView][windows] WebView2=$version');
      if (!mounted) return;
      setState(() {
        _environment = environment;
        _initializing = false;
      });
    } catch (e) {
      debugPrint('[TwitchInAppWebView][windows] init failed: $e');
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Windows WebView 初始化失敗：$e';
      });
    }
  }

  bool _isOAuthRedirect(Uri uri) {
    final host = uri.host.toLowerCase();
    return uri.scheme == 'http' &&
        (host == 'localhost' || host == '127.0.0.1') &&
        uri.port == 3000;
  }

  Map<String, String> _oauthParams(Uri uri) {
    final result = <String, String>{};
    if (uri.query.isNotEmpty) result.addAll(Uri.splitQueryString(uri.query));
    if (uri.fragment.isNotEmpty) {
      result.addAll(Uri.splitQueryString(uri.fragment));
    }
    return result;
  }

  Future<bool> _handlePossibleRedirect(Uri? uri) async {
    if (uri == null || !_isOAuthRedirect(uri)) return false;
    if (_completing) return true;

    final params = _oauthParams(uri);
    if (params['state'] != _state) {
      setState(() => _error = '登入驗證失敗，請重新登入。');
      return true;
    }
    final accessToken = params['access_token']?.trim();
    if (accessToken == null || accessToken.isEmpty) {
      setState(() => _error = '沒有取得 Twitch access token。');
      return true;
    }

    _completing = true;
    if (mounted) setState(() {});
    try {
      final validation = await widget.authApi.validateToken(accessToken);
      final token = TwitchAuthToken(
        accessToken: accessToken,
        refreshToken: '',
        tokenType: 'bearer',
        scopes: validation.scopes.isNotEmpty ? validation.scopes : _scopes,
        expiresIn: validation.expiresIn > 0
            ? validation.expiresIn
            : int.tryParse(params['expires_in'] ?? '') ?? 14400,
        obtainedAt: DateTime.now(),
      );
      await widget.mainAuthService.saveSession(
        clientId: validation.clientId.trim().isNotEmpty
            ? validation.clientId.trim()
            : _clientId,
        token: token,
      );

      final gqlOk = await _captureWebGqlToken();
      if (!gqlOk) {
        throw StateError('Web/GQL token not available');
      }

      if (!mounted) return true;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[TwitchInAppWebView][windows] complete failed: $e');
      if (!mounted) return true;
      setState(() {
        _completing = false;
        _error = 'Twitch 主登入完成，但後續登入狀態同步失敗：$e';
      });
    }
    return true;
  }

  Future<bool> _captureWebGqlToken() async {
    final controller = _controller;
    if (controller == null) return false;
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri('https://www.twitch.tv/')),
    );

    String? webToken;
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      try {
        final raw = await controller.evaluateJavascript(source: r'''
(function() {
  try {
    return JSON.stringify({
      cookie: document.cookie || '',
      localStorage: Object.assign({}, window.localStorage),
      sessionStorage: Object.assign({}, window.sessionStorage)
    });
  } catch (e) { return ''; }
})();
''');
        webToken = _extractWebToken(raw?.toString() ?? '');
      } catch (_) {
        webToken = null;
      }
      if (webToken != null && webToken!.isNotEmpty) break;
    }
    if (webToken == null || webToken!.isEmpty) return false;

    final token = TwitchAuthToken(
      accessToken: webToken!,
      refreshToken: '',
      tokenType: 'bearer',
      scopes: const <String>[],
      expiresIn: const Duration(days: 30).inSeconds,
      obtainedAt: DateTime.now(),
    );
    await widget.webGqlAuthService.saveSession(token);
    if (!await widget.webGqlAuthService.validateToken()) return false;
    return _verifyGql(webToken!);
  }

  String? _extractWebToken(String raw) {
    final cookieMatch = RegExp(
      r'(?:^|[;,\s])auth-token=([^;,\s"\}]+)',
      caseSensitive: false,
    ).firstMatch(raw);
    final cookieToken = cookieMatch?.group(1)?.trim();
    if (cookieToken != null && cookieToken.length >= 20) {
      return Uri.decodeComponent(cookieToken);
    }
    for (final pattern in <RegExp>[
      RegExp(r'''["']auth-token["']\s*[:=]\s*["']([^"']+)["']''', caseSensitive: false),
      RegExp(r'''["']authToken["']\s*[:=]\s*["']([^"']+)["']''', caseSensitive: false),
    ]) {
      final value = pattern.firstMatch(raw)?.group(1)?.trim();
      if (value != null && value.length >= 20) return value;
    }
    return null;
  }

  Future<bool> _verifyGql(String token) async {
    try {
      final raw = await widget.apiClient.postJson<dynamic>(
        '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
        data: <String, dynamic>{
          'operationName': 'ChannelPointsContext',
          'query': r'''
query ChannelPointsContext($channelLogin: String!) {
  user(login: $channelLogin) { id login displayName }
}
''',
          'variables': <String, dynamic>{'channelLogin': 'twitch'},
        },
        headers: <String, String>{
          'Client-ID': TwitchApiConstants.twitchWebClientId,
          'Authorization': 'OAuth ${token.trim()}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (raw is! Map) return false;
      final errors = raw['errors'];
      if (errors is List && errors.isNotEmpty) return false;
      return raw['data'] is Map && (raw['data'] as Map)['user'] != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _openPopup(CreateWindowAction action) async {
    final environment = _environment;
    if (environment == null || !mounted) return false;
    debugPrint('[TwitchInAppWebView][popup] windowId=${action.windowId}');

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(28),
          child: SizedBox(
            width: 560,
            height: 780,
            child: InAppWebView(
              windowId: action.windowId,
              webViewEnvironment: environment,
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                supportMultipleWindows: true,
                javaScriptCanOpenWindowsAutomatically: true,
              ),
              onLoadStart: (_, url) {
                debugPrint('[TwitchInAppWebView][popup][start] $url');
              },
              onLoadStop: (_, url) {
                debugPrint('[TwitchInAppWebView][popup][stop] $url');
              },
              onCloseWindow: (_) {
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ),
        );
      },
    ));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        foregroundColor: Colors.white,
        title: const Text('登入 Twitch · InAppWebView 測試'),
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _environment == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        color: Colors.redAccent.withValues(alpha: 0.16),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                      ),
                    if (_completing)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: InAppWebView(
                        webViewEnvironment: _environment,
                        initialUrlRequest: URLRequest(
                          url: WebUri(_authorizationUri().toString()),
                        ),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          domStorageEnabled: true,
                          databaseEnabled: true,
                          useShouldOverrideUrlLoading: true,
                          supportMultipleWindows: true,
                          javaScriptCanOpenWindowsAutomatically: true,
                          supportZoom: false,
                        ),
                        onWebViewCreated: (controller) {
                          _controller = controller;
                          debugPrint('[TwitchInAppWebView][windows] created');
                        },
                        onCreateWindow: (_, action) => _openPopup(action),
                        shouldOverrideUrlLoading: (_, action) async {
                          final uri = action.request.url;
                          if (await _handlePossibleRedirect(
                            uri == null ? null : Uri.tryParse(uri.toString()),
                          )) {
                            return NavigationActionPolicy.CANCEL;
                          }
                          return NavigationActionPolicy.ALLOW;
                        },
                        onLoadStart: (_, url) {
                          debugPrint('[TwitchInAppWebView][start] $url');
                          unawaited(_handlePossibleRedirect(
                            url == null ? null : Uri.tryParse(url.toString()),
                          ));
                        },
                        onLoadStop: (_, url) {
                          debugPrint('[TwitchInAppWebView][stop] $url');
                          unawaited(_handlePossibleRedirect(
                            url == null ? null : Uri.tryParse(url.toString()),
                          ));
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
