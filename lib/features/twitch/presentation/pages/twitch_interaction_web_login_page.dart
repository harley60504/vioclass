import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, Platform;

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../models/auth/twitch_auth_token.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../theme/twitch_ui_tokens.dart';

/// Official Twitch Web session + kimne Web GQL token capture.
///
/// v30: kept as the single-repair page only.
/// - Desktop uses desktop_webview_window.
/// - Android / iOS uses an embedded InAppWebView.
/// Unified login normally captures Web/GQL from the main OAuth container, so
/// this page is no longer opened in the normal one-click path.
class TwitchInteractionWebLoginPage extends StatefulWidget {
  final TwitchWebGqlAuthService webGqlAuthService;
  final TwitchApiClient apiClient;

  const TwitchInteractionWebLoginPage({
    super.key,
    required this.webGqlAuthService,
    required this.apiClient,
  });

  static const String interactionGqlVerifiedStorageKey =
      'new_twitch_app_twitch_interaction_gql_verified_at';

  @override
  State<TwitchInteractionWebLoginPage> createState() =>
      _TwitchInteractionWebLoginPageState();
}

class _TwitchInteractionWebLoginPageState
    extends State<TwitchInteractionWebLoginPage> {
  static const String _loginUrl = 'https://www.twitch.tv/login';
  static const String _homeUrl = 'https://www.twitch.tv/';

  dynamic _webWindow;
  InAppWebViewController? _embeddedController;
  Timer? _probeTimer;
  Timer? _debounceTimer;

  bool _openingWindow = false;
  bool _windowOpen = false;
  bool _embeddedWebViewReady = false;
  bool _checking = false;
  bool _saving = false;

  String _statusText = '準備開啟 Twitch 官方 Web 登入視窗...';
  String? _errorText;
  String? _lastUrl;
  String? _lastTokenPreview;
  String? _lastProbeText;

  bool get _isDesktopAuthWindowPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool get _useEmbeddedMobileWebView => !_isDesktopAuthWindowPlatform;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDesktopAuthWindowPlatform) {
        unawaited(_openDesktopWindow(_loginUrl));
      } else {
        setState(() {
          _lastUrl = _loginUrl;
          _statusText = '請在 App 內 WebView 登入 Twitch 官方 Web；完成後會自動擷取 GQL 資訊。';
        });
      }
      _startProbeTimer();
    });
  }

  @override
  void dispose() {
    _probeTimer?.cancel();
    _debounceTimer?.cancel();
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

  Future<void> _copyLastUrl() async {
    final url = _lastUrl?.trim();
    if (url == null || url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已複製目前 URL')));
  }

  void _startProbeTimer() {
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(
      const Duration(milliseconds: 900),
      (_) => unawaited(_probeAndMaybeSave()),
    );
  }

  void _scheduleProbe() {
    if (_saving) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_probeAndMaybeSave()),
    );
  }

  Future<void> _openDesktopWindow(String url) async {
    if (!_isDesktopAuthWindowPlatform) {
      if (!mounted) return;
      setState(() {
        _lastUrl = url;
        _statusText = '目前平台使用 App 內 WebView，不開桌面登入視窗。';
      });
      try {
        await _embeddedController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(url)),
        );
      } catch (_) {}
      _scheduleProbe();
      return;
    }

    if (_openingWindow) return;

    setState(() {
      _openingWindow = true;
      _errorText = null;
      _statusText = '正在建立官方 Twitch Web 登入視窗...';
      _lastUrl = url;
    });

    await _closeWindow();

    try {
      final folder = sharedDesktopWebViewUserDataFolder();
      final window = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: 'Twitch 官方 Web / GQL 登入',
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
          if (!mounted) return;
          setState(() {
            _lastUrl = nextUrl;
          });
          _scheduleProbe();
        });
      } catch (_) {}

      try {
        window.onClose.whenComplete(() {
          if (!mounted) return;
          setState(() {
            _windowOpen = false;
            if (!_saving) {
              _statusText = '官方 Web 登入視窗已關閉；可重新開啟或手動檢查。';
            }
          });
        });
      } catch (_) {}

      window.launch(url);

      if (!mounted) return;
      setState(() {
        _openingWindow = false;
        _windowOpen = true;
        _statusText = '請在彈出的 Twitch 官方 Web 視窗登入；完成後會自動擷取 GQL 資訊。';
      });

      _scheduleProbe();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _openingWindow = false;
        _windowOpen = false;
        _errorText = '建立官方 Web 登入視窗失敗：$e';
        _statusText = '無法開啟桌面登入視窗。';
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

  Future<void> _launchUrl(String url) async {
    if (_useEmbeddedMobileWebView) {
      try {
        await _embeddedController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(url)),
        );
      } catch (_) {}
      if (mounted) {
        setState(() {
          _lastUrl = url;
          _statusText = '正在切換 App 內 Twitch WebView 網址...';
        });
      }
      _scheduleProbe();
      return;
    }

    final window = _webWindow;
    if (window == null || !_windowOpen) {
      await _openDesktopWindow(url);
      return;
    }

    try {
      setState(() {
        _errorText = null;
        _statusText = '正在切換 Twitch Web 視窗網址...';
        _lastUrl = url;
      });
      window.launch(url);
      _scheduleProbe();
    } catch (_) {
      await _openDesktopWindow(url);
    }
  }

  Future<void> _probeAndMaybeSave() async {
    if (_checking || _saving) return;

    final window = _webWindow;
    final embeddedController = _embeddedController;
    if (_isDesktopAuthWindowPlatform && (window == null || !_windowOpen)) {
      setState(() {
        _lastProbeText = '視窗尚未開啟。';
      });
      return;
    }
    if (_useEmbeddedMobileWebView && embeddedController == null) {
      setState(() {
        _lastProbeText = 'App 內 WebView 尚未建立。';
      });
      return;
    }

    _checking = true;
    try {
      final token = _isDesktopAuthWindowPlatform
          ? await _readTwitchWebAuthTokenFromWindow(window)
          : await _readTwitchWebAuthTokenFromEmbeddedWebView(
              embeddedController!,
            );
      if (token == null || token.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _lastProbeText = '尚未讀到 Twitch Web 授權資訊。';
          _statusText = '登入 Twitch 官方 Web 後會自動檢查授權資訊。';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _lastTokenPreview = _previewToken(token);
        _statusText = '已讀到 Twitch Web 授權資訊，正在檢查 GQL...';
      });
      await _saveAndVerifyInteractionToken(token);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = '檢查 Twitch Web 授權資訊失敗：$e';
        _lastProbeText = '檢查失敗：$e';
      });
    } finally {
      _checking = false;
    }
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
      final found = _findTokenInJson(parsed);
      if (found != null && found.isNotEmpty) return found;
    } catch (_) {}

    return null;
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

  Future<void> _saveAndVerifyInteractionToken(String accessToken) async {
    if (_saving) return;
    _saving = true;
    _probeTimer?.cancel();
    _debounceTimer?.cancel();

    setState(() {
      _errorText = null;
      _statusText = '正在儲存 Web/GQL 授權並檢查 GQL...';
    });

    try {
      final token = TwitchAuthToken(
        accessToken: accessToken.trim(),
        refreshToken: '',
        tokenType: 'bearer',
        scopes: const <String>[],
        expiresIn: const Duration(days: 30).inSeconds,
        obtainedAt: DateTime.now(),
      );

      await widget.webGqlAuthService.saveSession(token);
      await _verifyKimneGql(accessToken);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        TwitchInteractionWebLoginPage.interactionGqlVerifiedStorageKey,
        DateTime.now().toIso8601String(),
      );

      await _closeWindow();

      if (!mounted) return;
      setState(() {
        _statusText = '官方 Web/GQL 授權已儲存，GQL 檢查成功。';
        _lastProbeText = '官方 Web / GQL 完成。';
      });
      Navigator.of(context).pop(true);
    } catch (e) {
      _saving = false;
      _startProbeTimer();
      if (!mounted) return;
      setState(() {
        _errorText = 'Web/GQL 授權驗證失敗：$e';
        _statusText = '已讀到授權資訊，但尚未通過 GQL 檢查。';
        _lastProbeText = '失敗：$e';
      });
    }
  }

  Future<void> _verifyKimneGql(String token) async {
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

    final raw = await widget.apiClient.postJson<dynamic>(
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

  String _previewToken(String token) {
    final safe = token.trim();
    if (safe.length <= 12) return safe;
    return '${safe.substring(0, 6)}...${safe.substring(safe.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    final busy = _openingWindow || _checking || _saving;

    return Scaffold(
      backgroundColor: const Color(0xFF18181B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0E10),
        foregroundColor: Colors.white,
        title: const Text('Twitch 官方 Web / GQL 登入'),
        actions: [
          IconButton(
            tooltip: '關閉',
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBar(),
          if (_errorText != null) _buildErrorBanner(),
          _buildActionBar(busy),
          Expanded(
            child: _useEmbeddedMobileWebView
                ? _buildEmbeddedWebGqlWebView()
                : _buildMainPanel(busy),
          ),
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
          if (_checking || _saving || _openingWindow)
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
            onPressed: busy ? null : () => _launchUrl(_loginUrl),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('登入頁'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : () => _launchUrl(_homeUrl),
            icon: const Icon(Icons.home_rounded, size: 18),
            label: const Text('首頁'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : () => _probeAndMaybeSave(),
            icon: const Icon(Icons.key_rounded, size: 18),
            label: const Text('檢查 GQL 授權'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _copyLastUrl,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('複製 URL'),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              _lastProbeText ??
                  (_useEmbeddedMobileWebView
                      ? (_embeddedWebViewReady
                            ? 'App 內 Web/GQL 頁已載入'
                            : '等待 App 內 Web/GQL 頁...')
                      : (_windowOpen ? '桌面登入視窗已開啟' : '等待視窗開啟')),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedWebGqlWebView() {
    final url = _lastUrl?.trim().isNotEmpty == true
        ? _lastUrl!.trim()
        : _loginUrl;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
            color: Color(0xFF0E0E10),
            border: Border(bottom: BorderSide(color: Color(0xFF2D2D35))),
          ),
          child: Row(
            children: [
              Icon(
                _embeddedWebViewReady
                    ? Icons.phone_android_rounded
                    : Icons.hourglass_top_rounded,
                color: _embeddedWebViewReady
                    ? const Color(0xFF5CFFB1)
                    : Colors.white54,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Android / iOS：App 內 Twitch 官方 Web / GQL 登入',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _launchUrl(_homeUrl),
                icon: const Icon(Icons.home_rounded, size: 16),
                label: const Text('首頁'),
              ),
              TextButton.icon(
                onPressed: () => _launchUrl(_loginUrl),
                icon: const Icon(Icons.login_rounded, size: 16),
                label: const Text('登入'),
              ),
              TextButton.icon(
                onPressed: _checking || _saving ? null : _probeAndMaybeSave,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('檢查'),
              ),
            ],
          ),
        ),
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
              if (mounted && nextUrl != null) {
                setState(() => _lastUrl = nextUrl);
              }
              _scheduleProbe();
              return NavigationActionPolicy.ALLOW;
            },
            onLoadStart: (controller, webUri) {
              final nextUrl = webUri?.toString();
              if (!mounted) return;
              setState(() {
                _embeddedWebViewReady = false;
                if (nextUrl != null) _lastUrl = nextUrl;
                _statusText = 'App 內 WebView 正在載入 Twitch 官方頁...';
              });
            },
            onLoadStop: (controller, webUri) {
              final nextUrl = webUri?.toString();
              if (!mounted) return;
              setState(() {
                _embeddedWebViewReady = true;
                if (nextUrl != null) _lastUrl = nextUrl;
                if (!_saving) {
                  _statusText = '登入 Twitch 官方 Web 後會自動檢查 auth-token。';
                }
              });
              _scheduleProbe();
            },
            onUpdateVisitedHistory: (controller, webUri, androidIsReload) {
              final nextUrl = webUri?.toString();
              if (mounted && nextUrl != null) {
                setState(() => _lastUrl = nextUrl);
              }
              _scheduleProbe();
            },
            onReceivedError: (controller, request, error) {
              if (!mounted || request.isForMainFrame != true) return;
              setState(() {
                _errorText = 'App 內 Web/GQL WebView 載入失敗：${error.description}';
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
        constraints: const BoxConstraints(maxWidth: 620),
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
              _windowOpen ? Icons.language_rounded : Icons.language_outlined,
              color: _windowOpen ? const Color(0xFF5CFFB1) : Colors.white38,
              size: 58,
            ),
            const SizedBox(height: 14),
            const Text(
              '官方 Twitch Web / GQL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '這是單獨補 Web/GQL 的頁面。一般一鍵登入會在主 OAuth 視窗裡順手擷取 GQL 資訊，不會再另外開這個視窗。',
              textAlign: TextAlign.center,
              style: TextStyle(
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
                ElevatedButton.icon(
                  onPressed: busy ? null : () => _openDesktopWindow(_loginUrl),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(_windowOpen ? '重開登入視窗' : '開啟登入視窗'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TwitchUiColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _probeAndMaybeSave(),
                  icon: const Icon(Icons.verified_user_rounded),
                  label: const Text('立即檢查'),
                ),
              ],
            ),
            if (_lastTokenPreview != null) ...[
              const SizedBox(height: 14),
              Text(
                '已擷取 Web/GQL 授權：$_lastTokenPreview',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_lastUrl != null) ...[
              const SizedBox(height: 10),
              SelectableText(
                _lastUrl!,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white30, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
