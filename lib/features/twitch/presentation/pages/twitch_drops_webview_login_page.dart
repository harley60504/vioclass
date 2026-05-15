// PATCH VERSION: twitch_drops_webview_login_page_v17
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../api/core/twitch_api_constants.dart';
import '../../models/auth/twitch_auth_token.dart';
import '../../services/auth/twitch_drops_auth_service.dart';

/// Drops / Android token login through an embedded WebView OAuth page.
///
/// This intentionally does NOT use Twitch device flow. It follows the same
/// overall UX as the other WebView-based logins:
///
/// ```text
/// WebView opens Twitch OAuth authorize
/// → user is already logged in through Twitch cookies or signs in once
/// → redirect URL contains access_token
/// → app captures the token and stores it in TwitchDropsAuthService
/// ```
///
/// The token is accepted only when Twitch /validate reports the configured
/// Android/Drops Client-ID. This prevents Web/kimne tokens from polluting the
/// Drops slot again.
class TwitchDropsWebViewLoginPage extends StatefulWidget {
  final TwitchDropsAuthService dropsAuthService;

  const TwitchDropsWebViewLoginPage({
    super.key,
    required this.dropsAuthService,
  });

  static const String defaultRedirectUri = 'http://localhost:3000';

  @override
  State<TwitchDropsWebViewLoginPage> createState() =>
      _TwitchDropsWebViewLoginPageState();
}

class _TwitchDropsWebViewLoginPageState extends State<TwitchDropsWebViewLoginPage> {
  InAppWebViewController? _controller;

  late final TextEditingController _clientIdController;
  late final TextEditingController _redirectUriController;
  late final TextEditingController _manualTextController;

  String _state = '';
  String _statusText = '準備開啟 Drops / Android WebView OAuth...';
  String? _errorText;
  String _currentUrlText = '';
  double _progress = 0.0;

  bool _isLoading = true;
  bool _isCompleting = false;
  bool _showAdvanced = false;

  String get _clientId {
    final text = _clientIdController.text.trim();
    if (text.isNotEmpty) return text;
    final serviceClientId = widget.dropsAuthService.dropsClientId.trim();
    if (serviceClientId.isNotEmpty) return serviceClientId;
    return TwitchApiConstants.twitchAndroidPublicClientId;
  }

  String get _redirectUri {
    final text = _redirectUriController.text.trim();
    return text.isNotEmpty ? text : TwitchDropsWebViewLoginPage.defaultRedirectUri;
  }

  @override
  void initState() {
    super.initState();
    _state = _createStateToken();
    _clientIdController = TextEditingController(
      text: widget.dropsAuthService.dropsClientId.trim().isNotEmpty
          ? widget.dropsAuthService.dropsClientId.trim()
          : TwitchApiConstants.twitchAndroidPublicClientId,
    );
    _redirectUriController = TextEditingController(
      text: TwitchDropsWebViewLoginPage.defaultRedirectUri,
    );
    _manualTextController = TextEditingController();
    _currentUrlText = _buildAuthorizationUri().toString();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _redirectUriController.dispose();
    _manualTextController.dispose();
    super.dispose();
  }

  String _createStateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Uri _buildAuthorizationUri() {
    final params = <String, String>{
      'response_type': 'token',
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'scope': '',
      'state': _state,
      'force_verify': 'false',
    };

    return Uri.parse('https://id.twitch.tv/oauth2/authorize').replace(
      queryParameters: params,
    );
  }

  bool _isRedirectUri(Uri uri) {
    final configured = Uri.tryParse(_redirectUri);
    if (configured != null) {
      final schemeMatches = uri.scheme.toLowerCase() == configured.scheme.toLowerCase();
      final hostMatches = uri.host.toLowerCase() == configured.host.toLowerCase();
      final portMatches = uri.hasPort
          ? uri.port == configured.port
          : configured.hasPort
              ? false
              : true;
      if (schemeMatches && hostMatches && portMatches) return true;
    }

    final host = uri.host.toLowerCase();
    if ((host == 'localhost' || host == '127.0.0.1') && uri.scheme == 'http') {
      return true;
    }

    // Some mobile OAuth clients redirect to a custom scheme. We cannot load it,
    // but shouldOverrideUrlLoading can still intercept it before WebView fails.
    if (uri.scheme.toLowerCase() == 'twitch') return true;

    return false;
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
        _statusText = 'Drops WebView OAuth 授權失敗。';
        _isLoading = false;
      });
      return;
    }

    final returnedState = params['state'];
    if (returnedState == null || returnedState.isEmpty || returnedState != _state) {
      if (!mounted) return;
      setState(() {
        _errorText = 'OAuth state 不一致，已阻擋這次回傳。';
        _statusText = 'Drops WebView OAuth 回傳驗證失敗。';
        _isLoading = false;
      });
      return;
    }

    final accessToken = params['access_token'];
    if (accessToken == null || accessToken.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorText = 'OAuth 回傳沒有 access_token。';
        _statusText = '尚未取得 Drops / Android token。';
        _isLoading = false;
      });
      return;
    }

    final expiresIn = int.tryParse(params['expires_in'] ?? '') ?? 0;
    final scopes = _parseScopes(params['scope']);

    _isCompleting = true;
    if (mounted) {
      setState(() {
        _errorText = null;
        _statusText = '已取得 token，正在驗證 Android/Drops Client-ID...';
        _isLoading = false;
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
      await widget.dropsAuthService.setDropsClientId(
        _clientId,
        clearTokenOnChange: true,
      );

      final validation = await widget.dropsAuthService.authApi.validateToken(
        accessToken.trim(),
      );
      final validatedClientId = validation.clientId.trim();
      final expectedClientId = widget.dropsAuthService.dropsClientId.trim();

      if (validatedClientId.isNotEmpty &&
          expectedClientId.isNotEmpty &&
          validatedClientId != expectedClientId) {
        throw StateError(
          '取得的 token client_id=$validatedClientId，'
          '不是 Drops / Android client_id=$expectedClientId。',
        );
      }

      final token = TwitchAuthToken(
        accessToken: accessToken.trim(),
        refreshToken: '',
        tokenType: 'bearer',
        scopes: validation.scopes.isNotEmpty ? validation.scopes : scopes,
        expiresIn: validation.expiresIn <= 0 ? expiresIn : validation.expiresIn,
        obtainedAt: DateTime.now(),
      );

      await widget.dropsAuthService.saveSession(token);
      final valid = await widget.dropsAuthService.validateToken();
      if (!valid) {
        throw StateError('Drops token 已保存，但 validateToken() 未通過。');
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _isCompleting = false;
      if (!mounted) return;
      setState(() {
        _errorText = 'Drops WebView token 驗證或保存失敗：$e';
        _statusText = '請確認這次 OAuth 使用的是 Android/Drops Client-ID。';
      });
    }
  }

  Map<String, String> _parseOAuthResponse(Uri uri) {
    final output = <String, String>{};
    if (uri.query.isNotEmpty) output.addAll(Uri.splitQueryString(uri.query));
    if (uri.fragment.isNotEmpty) output.addAll(Uri.splitQueryString(uri.fragment));
    return output;
  }

  List<String> _parseScopes(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return const <String>[];
    return text
        .split(RegExp(r'[ +]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _reloadOAuth() async {
    _state = _createStateToken();
    final uri = _buildAuthorizationUri();
    if (mounted) {
      setState(() {
        _errorText = null;
        _statusText = '正在重新載入 Drops WebView OAuth...';
        _isLoading = true;
        _progress = 0.0;
        _currentUrlText = uri.toString();
      });
    }
    await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(uri.toString())));
  }

  Future<void> _copyAuthorizationUrl() async {
    final uri = _buildAuthorizationUri();
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已複製 Drops OAuth URL')),
    );
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
      expiresIn: 0,
      scopes: const <String>[],
    );
  }

  Future<void> _pasteAndTry() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _manualTextController.text = text;
    await _tryManualInput();
  }

  Future<NavigationActionPolicy> _handleNavigation(
    InAppWebViewController controller,
    NavigationAction navigationAction,
  ) async {
    final uri = navigationAction.request.url;
    final handled = await _tryHandleOAuthRedirect(
      uri == null ? null : Uri.tryParse(uri.toString()),
    );
    if (handled) return NavigationActionPolicy.CANCEL;
    return NavigationActionPolicy.ALLOW;
  }

  Future<void> _handleUrlMaybe(WebUri? url) async {
    final uri = url == null ? null : Uri.tryParse(url.toString());
    if (uri == null) return;
    if (mounted) {
      setState(() {
        _currentUrlText = uri.toString();
      });
    }
    await _tryHandleOAuthRedirect(uri);
  }

  @override
  Widget build(BuildContext context) {
    final initialUri = _buildAuthorizationUri();

    return Scaffold(
      backgroundColor: const Color(0xFF18181B),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            if (_isLoading || _progress < 1.0)
              LinearProgressIndicator(
                minHeight: 2,
                value: _progress <= 0.0 || _progress >= 1.0 ? null : _progress,
                color: const Color(0xFF9146FF),
                backgroundColor: const Color(0xFF2A2A2E),
              ),
            if (_showAdvanced) _buildAdvancedPanel(),
            Expanded(
              child: ClipRect(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(initialUri.toString())),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    supportZoom: false,
                    transparentBackground: false,
                    useShouldOverrideUrlLoading: true,
                    userAgent: TwitchApiConstants.browserUserAgent,
                  ),
                  onWebViewCreated: (controller) {
                    _controller = controller;
                  },
                  shouldOverrideUrlLoading: _handleNavigation,
                  onLoadStart: (controller, url) async {
                    await _handleUrlMaybe(url);
                    if (!mounted) return;
                    setState(() {
                      _isLoading = true;
                      _statusText = '正在載入 Drops WebView OAuth...';
                    });
                  },
                  onLoadStop: (controller, url) async {
                    await _handleUrlMaybe(url);
                    if (!mounted) return;
                    setState(() {
                      _isLoading = false;
                      _progress = 1.0;
                      _statusText = _isCompleting
                          ? '正在完成 Drops token 保存...'
                          : '請在 WebView 完成 Drops / Android OAuth。';
                    });
                  },
                  onUpdateVisitedHistory: (controller, url, androidIsReload) {
                    unawaited(_handleUrlMaybe(url));
                  },
                  onProgressChanged: (controller, value) {
                    if (!mounted) return;
                    setState(() {
                      _progress = value / 100.0;
                    });
                  },
                  onReceivedError: (controller, request, error) async {
                    final handled = await _tryHandleOAuthRedirect(
                      Uri.tryParse(request.url.toString()),
                    );
                    if (handled) return;
                    if (!mounted) return;
                    setState(() {
                      _statusText =
                          'WebView 載入失敗：${error.description} (${error.type})';
                    });
                  },
                ),
              ),
            ),
            _buildBottomStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E10),
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A2E))),
      ),
      child: Row(
        children: [
          const Icon(Icons.vpn_key_rounded, color: Color(0xFF9146FF), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Drops / Android WebView 登入',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          TextButton(
            onPressed: _isCompleting ? null : _reloadOAuth,
            child: const Text('重新載入'),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: _isCompleting
                ? null
                : () => setState(() => _showAdvanced = !_showAdvanced),
            child: const Text('進階'),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '關閉',
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
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
                    labelText: 'Drops / Android Client-ID',
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_isLoading || _isCompleting) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ] else ...[
                const Icon(Icons.info_outline, color: Color(0xFFBF94FF), size: 16),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  _statusText,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: _copyAuthorizationUrl,
                child: const Text('複製 OAuth URL'),
              ),
            ],
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 4),
            Text(
              _errorText!,
              style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _currentUrlText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 2),
          const Text(
            '這頁不使用 Drops device flow；會用 WebView OAuth 回傳的 token 驗證 Android/Drops Client-ID。',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
