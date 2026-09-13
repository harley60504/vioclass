import 'dart:async';
import 'dart:io' show Directory, Platform;

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';

import '../../api/auth/twitch_device_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../models/auth/twitch_auth_token.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../theme/twitch_ui_tokens.dart';

class TwitchMainDeviceLoginPage extends StatefulWidget {
  final TwitchAuthService mainAuthService;
  final TwitchWebGqlAuthService webGqlAuthService;
  final TwitchApiClient apiClient;

  const TwitchMainDeviceLoginPage({
    super.key,
    required this.mainAuthService,
    required this.webGqlAuthService,
    required this.apiClient,
  });

  static const String clientId = String.fromEnvironment(
    'TWITCH_MAIN_CLIENT_ID',
    defaultValue: 'euyqoof00efejc6vk5f4gv0nze20ue',
  );

  static const List<String> scopes = <String>[
    'user:read:email',
    'user:read:follows',
    'chat:read',
    'chat:edit',
    'user:read:emotes',
    'clips:edit',
  ];

  @override
  State<TwitchMainDeviceLoginPage> createState() =>
      _TwitchMainDeviceLoginPageState();
}

class _TwitchMainDeviceLoginPageState
    extends State<TwitchMainDeviceLoginPage> {
  dynamic _desktopWindow;
  InAppWebViewController? _mobileController;
  Timer? _pollTimer;
  TwitchDeviceAuthorization? _authorization;

  bool _starting = true;
  bool _polling = false;
  bool _done = false;
  bool _windowOpen = false;
  int _intervalSeconds = 5;
  String _status = '正在準備 Twitch 登入…';
  String? _error;

  bool get _desktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(_closeWindow());
    super.dispose();
  }

  static String _userDataFolder() {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'new_twitch_app_shared_twitch_desktop_webview_v30';
    try {
      Directory(path).createSync(recursive: true);
    } catch (_) {}
    return path;
  }

  Future<void> _start() async {
    _pollTimer?.cancel();
    await _closeWindow();
    if (!mounted) return;
    setState(() {
      _starting = true;
      _polling = false;
      _done = false;
      _authorization = null;
      _status = '正在取得 Twitch 登入代碼…';
      _error = null;
    });

    try {
      final auth = await widget.mainAuthService.deviceAuthApi
          .startDeviceAuthorization(
        clientId: TwitchMainDeviceLoginPage.clientId,
        scopes: TwitchMainDeviceLoginPage.scopes,
      );
      if (!mounted) return;
      setState(() {
        _authorization = auth;
        _intervalSeconds = auth.interval <= 0 ? 5 : auth.interval;
        _starting = false;
        _status = '請在 Twitch 頁面完成登入';
      });
      if (_desktop) await _openDesktopWindow(auth.verificationUri);
      _schedulePoll();
    } catch (e) {
      debugPrint('[TwitchMainDeviceAuth][start] $e');
      if (!mounted) return;
      setState(() {
        _starting = false;
        _status = '登入尚未開始';
        _error = '無法啟動 Twitch Device Code 登入：$e';
      });
    }
  }

  Future<void> _openDesktopWindow(String url) async {
    final window = await WebviewWindow.create(
      configuration: CreateConfiguration(
        title: 'Twitch 登入',
        windowWidth: 1120,
        windowHeight: 820,
        userDataFolderWindows: _userDataFolder(),
      ),
    );
    _desktopWindow = window;
    _windowOpen = true;
    try {
      window.setBrightness(Brightness.dark);
    } catch (_) {}
    try {
      window.addOnUrlRequestCallback((String nextUrl) {
        debugPrint('[TwitchMainDeviceAuth][navigation] $nextUrl');
        unawaited(_poll());
      });
    } catch (_) {}
    try {
      window.onClose.whenComplete(() {
        if (mounted) setState(() => _windowOpen = false);
      });
    } catch (_) {}
    window.launch(url);
  }

  Future<void> _closeWindow() async {
    final window = _desktopWindow;
    _desktopWindow = null;
    if (window == null) return;
    try {
      window.close();
    } catch (_) {}
    if (mounted) setState(() => _windowOpen = false);
  }

  void _schedulePoll() {
    if (_done) return;
    _pollTimer?.cancel();
    _pollTimer = Timer(
      Duration(seconds: _intervalSeconds),
      () => unawaited(_poll()),
    );
  }

  Future<void> _poll() async {
    final auth = _authorization;
    if (auth == null || _polling || _done) return;
    if (mounted) setState(() => _polling = true);

    try {
      final result = await widget.mainAuthService.deviceAuthApi.pollDeviceToken(
        clientId: TwitchMainDeviceLoginPage.clientId,
        deviceCode: auth.deviceCode,
        scopes: TwitchMainDeviceLoginPage.scopes,
        currentIntervalSeconds: _intervalSeconds,
      );
      if (!mounted) return;

      switch (result.status) {
        case TwitchDeviceTokenPollStatus.success:
          final token = result.token;
          if (token == null) throw StateError('Twitch did not return a token');
          final validation = await widget.mainAuthService.authApi
              .validateToken(token.accessToken);
          await widget.mainAuthService.saveSession(
            clientId: validation.clientId.trim().isNotEmpty
                ? validation.clientId.trim()
                : TwitchMainDeviceLoginPage.clientId,
            token: token,
          );
          if (!mounted) return;
          setState(() => _status = 'Twitch 已登入，正在同步網頁登入狀態…');

          final gqlOk = await _captureWebGqlFromSameSession();
          if (!mounted) return;
          if (!gqlOk) {
            setState(() {
              _polling = false;
              _status = 'Twitch 主登入完成';
              _error = '主登入已成功，但 Web/GQL 登入狀態尚未取得。';
            });
            return;
          }

          _done = true;
          _pollTimer?.cancel();
          await _closeWindow();
          if (!mounted) return;
          Navigator.of(context).pop(true);
          return;

        case TwitchDeviceTokenPollStatus.pending:
          setState(() => _polling = false);
          _schedulePoll();
          return;
        case TwitchDeviceTokenPollStatus.slowDown:
          _intervalSeconds =
              result.nextIntervalSeconds ?? (_intervalSeconds + 5);
          setState(() => _polling = false);
          _schedulePoll();
          return;
        case TwitchDeviceTokenPollStatus.expired:
        case TwitchDeviceTokenPollStatus.denied:
        case TwitchDeviceTokenPollStatus.error:
          _pollTimer?.cancel();
          setState(() {
            _polling = false;
            _status = '登入失敗';
            _error = result.message ?? 'Twitch 登入失敗';
          });
          return;
      }
    } catch (e) {
      debugPrint('[TwitchMainDeviceAuth][poll] $e');
      if (!mounted) return;
      setState(() {
        _polling = false;
        _error = '檢查 Twitch 登入結果失敗：$e';
      });
      _schedulePoll();
    }
  }

  Future<bool> _captureWebGqlFromSameSession() async {
    try {
      if (_desktop) {
        final window = _desktopWindow;
        if (window == null) return false;
        window.launch('https://www.twitch.tv/');
      } else {
        await _mobileController?.loadUrl(
          urlRequest: URLRequest(url: WebUri('https://www.twitch.tv/')),
        );
      }

      String? webToken;
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 650));
        webToken = await _readWebToken();
        if (webToken != null && webToken.trim().isNotEmpty) break;
      }
      if (webToken == null || webToken.trim().isEmpty) return false;

      await widget.webGqlAuthService.saveSession(
        TwitchAuthToken(
          accessToken: webToken.trim(),
          refreshToken: '',
          tokenType: 'bearer',
          scopes: const <String>[],
          expiresIn: const Duration(days: 30).inSeconds,
          obtainedAt: DateTime.now(),
        ),
      );
      if (!await widget.webGqlAuthService.validateToken()) return false;
      return _verifyGql(webToken);
    } catch (e) {
      debugPrint('[TwitchMainDeviceAuth][gql] $e');
      return false;
    }
  }

  Future<String?> _readWebToken() async {
    const js = r'''
(function() {
  try {
    const out = [document.cookie || ''];
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (k) out.push(k + '=' + (localStorage.getItem(k) || ''));
    }
    for (let i = 0; i < sessionStorage.length; i++) {
      const k = sessionStorage.key(i);
      if (k) out.push(k + '=' + (sessionStorage.getItem(k) || ''));
    }
    return out.join('\n');
  } catch (e) { return ''; }
})();
''';
    final raw = _desktop
        ? await _desktopWindow?.evaluateJavaScript(js)
        : await _mobileController?.evaluateJavascript(source: js);
    final text = raw?.toString() ?? '';
    final match = RegExp(
      r'''(?:auth-token|authToken)["']?\s*[:=]\s*["']?([^;,\s"'}]+)''',
      caseSensitive: false,
    ).firstMatch(text);
    final value = match?.group(1)?.trim();
    if (value == null || value.length < 20) return null;
    return Uri.decodeComponent(value);
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
      final data = raw['data'];
      return data is Map && data['user'] != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _copyCode() async {
    final code = _authorization?.userCode.trim();
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
  }

  @override
  Widget build(BuildContext context) {
    final auth = _authorization;
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        foregroundColor: Colors.white,
        title: const Text('登入 Twitch'),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.redAccent.withValues(alpha: 0.18),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: const Color(0xFF18181B),
            child: Row(
              children: [
                if (_starting || _polling)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(
                    Icons.login_rounded,
                    color: TwitchUiColors.primarySoft,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (auth != null)
                  TextButton(
                    onPressed: _copyCode,
                    child: Text('代碼 ${auth.userCode}'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _desktop
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 54,
                          color: TwitchUiColors.primarySoft,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _windowOpen
                              ? '請在 Twitch 視窗完成登入'
                              : '登入視窗已關閉',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (auth != null && !_windowOpen) ...[
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: () =>
                                _openDesktopWindow(auth.verificationUri),
                            child: const Text('重新開啟 Twitch'),
                          ),
                        ],
                      ],
                    ),
                  )
                : auth == null
                    ? const Center(child: CircularProgressIndicator())
                    : InAppWebView(
                        initialUrlRequest: URLRequest(
                          url: WebUri(auth.verificationUri),
                        ),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          domStorageEnabled: true,
                          databaseEnabled: true,
                        ),
                        onWebViewCreated: (controller) {
                          _mobileController = controller;
                        },
                        onLoadStop: (_, __) => unawaited(_poll()),
                      ),
          ),
        ],
      ),
    );
  }
}
