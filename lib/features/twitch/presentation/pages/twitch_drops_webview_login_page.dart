import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, Platform;
import 'dart:math';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../api/core/twitch_api_constants.dart';
import '../../api/auth/twitch_drops_browser_auth.dart';
import '../../models/auth/twitch_auth_token.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../theme/twitch_ui_tokens.dart';
import '../widgets/shared/twitch_notice.dart';
import '../widgets/shared/twitch_text_field.dart';
import '../widgets/shared/twitch_login_webview_host.dart';

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

  static const String defaultRedirectUri =
      TwitchDropsBrowserAuth.defaultRedirectUri;

  @override
  State<TwitchDropsWebViewLoginPage> createState() =>
      _TwitchDropsWebViewLoginPageState();
}

class _TwitchDropsWebViewLoginPageState
    extends State<TwitchDropsWebViewLoginPage> {
  InAppWebViewController? _controller;
  Webview? _desktopWindow;
  Timer? _desktopUrlTimer;
  bool _probingDesktopUrl = false;
  bool _desktopWindowOpen = false;

  bool get _useDesktopWindow => Platform.isLinux || Platform.isMacOS;

  late final TextEditingController _clientIdController;
  late final TextEditingController _redirectUriController;
  late final TextEditingController _manualTextController;

  String _state = '';
  String _statusText = '準備開啟 Drops / Android 授權頁...';
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
    return text.isNotEmpty
        ? text
        : TwitchDropsWebViewLoginPage.defaultRedirectUri;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_useDesktopWindow) unawaited(_openDesktopWindow());
    });
  }

  @override
  void dispose() {
    _closeDesktopWindow();
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
    return TwitchDropsBrowserAuth.authorizationUri(
      clientId: _clientId,
      state: _state,
      redirectUri: _redirectUri,
    );
  }

  bool _isRedirectUri(Uri uri) {
    return TwitchDropsBrowserAuth.isRedirectResponse(
      uri,
      redirectUri: _redirectUri,
    );
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
        _statusText = 'Drops / Android 授權失敗。';
        _isLoading = false;
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
        _statusText = 'Drops / Android 授權驗證失敗。';
        _isLoading = false;
      });
      return;
    }

    final accessToken = params['access_token'];
    if (accessToken == null || accessToken.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorText = 'OAuth 回傳沒有可用授權。';
        _statusText = '尚未取得 Drops / Android 授權。';
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
        _statusText = '已取得授權，正在驗證 Drops / Android app...';
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
          '取得的授權屬於 client_id=$validatedClientId，'
          '不是 Drops / Android app：$expectedClientId。',
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
        throw StateError('Drops 授權已儲存，但驗證未通過。');
      }

      if (!mounted) return;
      _closeDesktopWindow();
      Navigator.of(context).pop(true);
    } catch (e) {
      _isCompleting = false;
      if (!mounted) return;
      setState(() {
        _errorText = 'Drops / Android 授權驗證或儲存失敗，請重新授權後再試。';
        _statusText = '請確認這次 OAuth 使用的是 Android/Drops Client-ID。';
      });
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
        _statusText = '正在重新載入 Drops / Android 授權頁...';
        _isLoading = true;
        _progress = 0.0;
        _currentUrlText = uri.toString();
      });
    }
    if (_useDesktopWindow) {
      if (_desktopWindow != null) {
        _desktopWindow!.launch(uri.toString());
      } else {
        await _openDesktopWindow();
      }
      return;
    }
    await _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(uri.toString())),
    );
  }

  Future<void> _copyAuthorizationUrl() async {
    final uri = _buildAuthorizationUri();
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!mounted) return;
    showTwitchNotice(
      context,
      '已複製 Drops OAuth 連結',
      tone: TwitchNoticeTone.success,
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
    final parsed = uri == null ? null : Uri.tryParse(uri.toString());
    if (parsed != null && _isRedirectUri(parsed)) {
      unawaited(_tryHandleOAuthRedirect(parsed));
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  Future<void> _handleUrlMaybe(WebUri? url) async {
    final uri = url == null ? null : Uri.tryParse(url.toString());
    if (uri == null) return;
    if (mounted) {
      setState(() {
        _currentUrlText = TwitchDropsBrowserAuth.displayUrl(uri);
      });
    }
    await _tryHandleOAuthRedirect(uri);
  }

  void _closeDesktopWindow() {
    _desktopUrlTimer?.cancel();
    _desktopUrlTimer = null;
    final window = _desktopWindow;
    _desktopWindow = null;
    if (window != null) {
      try {
        window.close();
      } catch (_) {}
    }
  }

  Future<void> _openDesktopWindow() async {
    if (!mounted || _desktopWindow != null) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
      _statusText = '正在開啟獨立 Drops 授權視窗…';
    });
    try {
      final folder =
          '${Directory.systemTemp.path}${Platform.pathSeparator}'
          'new_twitch_app_shared_twitch_desktop_webview_v30';
      final window = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: 'Twitch Drops 授權',
          windowWidth: 1080,
          windowHeight: 760,
          userDataFolderWindows: folder,
        ),
      );
      if (!mounted) {
        window.close();
        return;
      }
      _desktopWindow = window;
      window.addOnUrlRequestCallback((String url) {
        if (!mounted || _desktopWindow != window) return;
        unawaited(_handleUrlMaybe(WebUri(url)));
      });
      window.onClose.whenComplete(() {
        if (!mounted || _desktopWindow != window) return;
        _desktopWindow = null;
        _desktopUrlTimer?.cancel();
        setState(() {
          _desktopWindowOpen = false;
          _statusText = '授權視窗已關閉，可按重新載入再試。';
        });
      });
      window.launch(_buildAuthorizationUri().toString());
      _desktopUrlTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(_probeDesktopUrl(window));
      });
      setState(() {
        _desktopWindowOpen = true;
        _isLoading = false;
        _progress = 1;
        _statusText = '請在獨立視窗完成 Twitch Drops 授權。';
      });
    } catch (_) {
      _closeDesktopWindow();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = '無法開啟 Drops 授權視窗，請重新載入再試。';
      });
    }
  }

  Future<void> _probeDesktopUrl(Webview window) async {
    if (_probingDesktopUrl || _isCompleting || _desktopWindow != window) return;
    _probingDesktopUrl = true;
    try {
      final raw = await window.evaluateJavaScript('window.location.href');
      if (!mounted || _desktopWindow != window || raw is! String) return;
      var url = raw;
      if (raw.startsWith('"')) {
        final decoded = jsonDecode(raw);
        if (decoded is! String) return;
        url = decoded;
      }
      await _handleUrlMaybe(WebUri(url));
    } catch (_) {
      // Navigation can temporarily make the WebView unavailable.
    } finally {
      _probingDesktopUrl = false;
    }
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
                color: TwitchUiColors.primary,
                backgroundColor: const Color(0xFF2A2A2E),
              ),
            if (_showAdvanced) _buildAdvancedPanel(),
            Expanded(
              child: _useDesktopWindow
                  ? Center(
                      child: Text(
                        _desktopWindowOpen
                            ? '請在獨立視窗完成 Drops 授權'
                            : '按重新載入開啟 Drops 授權視窗',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : ClipRect(
                      child: TwitchLoginWebViewHost(
                        builder: (environment) => InAppWebView(
                          webViewEnvironment: environment,
                          initialUrlRequest: URLRequest(
                            url: WebUri(initialUri.toString()),
                          ),
                          initialSettings: InAppWebViewSettings(
                            javaScriptEnabled: true,
                            domStorageEnabled: true,
                            databaseEnabled: true,
                            supportZoom: false,
                            transparentBackground: false,
                            useShouldOverrideUrlLoading: true,
                            userAgent: Platform.isWindows
                                ? null
                                : TwitchApiConstants.browserUserAgent,
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
                              _statusText = '正在載入 Drops / Android 授權頁...';
                            });
                          },
                          onLoadStop: (controller, url) async {
                            await _handleUrlMaybe(url);
                            if (!mounted) return;
                            setState(() {
                              _isLoading = false;
                              _progress = 1.0;
                              _statusText = _isCompleting
                                  ? '正在儲存 Drops / Android 授權...'
                                  : '請在 WebView 完成 Drops / Android 授權。';
                            });
                          },
                          onUpdateVisitedHistory:
                              (controller, url, androidIsReload) {
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
                              _statusText = 'Drops / Android 授權頁暫時載入失敗，請稍後重試。';
                            });
                          },
                        ),
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
          const Icon(
            Icons.vpn_key_rounded,
            color: TwitchUiColors.primary,
            size: 20,
          ),
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
                child: TwitchTextField(
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
                child: TwitchTextField(
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
                child: TwitchTextField(
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: TwitchUiColors.primarySoft,
                  ),
                ),
                const SizedBox(width: 8),
              ] else ...[
                const Icon(
                  Icons.info_outline,
                  color: TwitchUiColors.primarySoft,
                  size: 16,
                ),
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
                child: const Text('複製 OAuth 連結'),
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
            '這頁會用 WebView OAuth 回傳的授權驗證 Android/Drops Client-ID。',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
