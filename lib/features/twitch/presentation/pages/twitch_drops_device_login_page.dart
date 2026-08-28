import 'dart:async';
import 'dart:io' show Directory, Platform;

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';

import '../../api/auth/twitch_device_auth_api_service.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../theme/twitch_ui_tokens.dart';

/// Drops / Android token login using Twitch Device Flow.
///
/// v30:
/// - Desktop uses desktop_webview_window.
/// - Android / iOS uses an embedded InAppWebView in this route.
/// - Device flow / polling logic is shared, only the auth container is split.
class TwitchDropsDeviceLoginPage extends StatefulWidget {
  final TwitchDropsAuthService dropsAuthService;

  const TwitchDropsDeviceLoginPage({super.key, required this.dropsAuthService});

  @override
  State<TwitchDropsDeviceLoginPage> createState() =>
      _TwitchDropsDeviceLoginPageState();
}

class _TwitchDropsDeviceLoginPageState
    extends State<TwitchDropsDeviceLoginPage> {
  dynamic _authWindow;
  InAppWebViewController? _embeddedController;
  Timer? _pollTimer;

  TwitchDeviceAuthorization? _authorization;

  bool _starting = true;
  bool _openingWindow = false;
  bool _polling = false;
  bool _done = false;
  bool _authWindowOpen = false;
  bool _embeddedWebViewReady = false;

  bool get _isDesktopAuthWindowPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool get _useEmbeddedMobileWebView => !_isDesktopAuthWindowPlatform;

  int _intervalSeconds = 5;

  String _statusText = '正在準備 Drops / Android 授權...';
  String? _errorText;
  String? _lastPollText;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _embeddedController = null;
    unawaited(_closeAuthWindow());
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

  Future<void> _start() async {
    _pollTimer?.cancel();
    await _closeAuthWindow();

    setState(() {
      _starting = true;
      _openingWindow = false;
      _polling = false;
      _done = false;
      _authWindowOpen = false;
      _errorText = null;
      _lastPollText = null;
      _currentUrl = null;
      _statusText = '正在清理舊授權並啟動 Drops / Android 登入...';
    });

    try {
      await widget.dropsAuthService.setDropsClientId(
        TwitchApiConstants.twitchAndroidPublicClientId,
        clearTokenOnChange: true,
      );
      await widget.dropsAuthService.logout(clearClientId: false);

      final auth = await widget.dropsAuthService.startDeviceFlow();

      if (!mounted) return;
      setState(() {
        _authorization = auth;
        _intervalSeconds = auth.interval <= 0 ? 5 : auth.interval;
        _starting = false;
        _statusText = _isDesktopAuthWindowPlatform
            ? '正在開啟獨立 Drops 授權視窗...'
            : '正在載入 App 內 Drops 授權頁...';
        _currentUrl = auth.verificationUri;
      });

      if (_isDesktopAuthWindowPlatform) {
        await _openAuthWindow(auth.verificationUri);
      } else {
        setState(() {
          _statusText = '請在 App 內 WebView 完成 Drops / Android 授權。';
        });
      }
      _schedulePoll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _openingWindow = false;
        _authWindowOpen = false;
        _embeddedWebViewReady = false;
        _errorText = '啟動 Drops / Android 授權失敗，請稍後再試。';
        _statusText = 'Drops / Android 尚未登入。';
      });
    }
  }

  Future<void> _openAuthWindow(String url) async {
    if (!_isDesktopAuthWindowPlatform) {
      if (!mounted) return;
      setState(() {
        _openingWindow = false;
        _authWindowOpen = false;
        _currentUrl = url;
        _statusText = '目前平台使用 App 內 WebView 授權，不開桌面視窗。';
      });
      if (_embeddedController != null) {
        try {
          await _embeddedController!.loadUrl(
            urlRequest: URLRequest(url: WebUri(url)),
          );
        } catch (_) {}
      }
      return;
    }

    setState(() {
      _openingWindow = true;
      _statusText = '正在建立獨立 Drops 授權視窗...';
    });

    await _closeAuthWindow();

    try {
      final userDataFolder = sharedDesktopWebViewUserDataFolder();

      final window = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: 'Twitch Drops / Android 授權',
          windowWidth: 1080,
          windowHeight: 760,
          userDataFolderWindows: userDataFolder,
        ),
      );

      _authWindow = window;
      _authWindowOpen = true;

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
            _currentUrl = nextUrl;
          });
          unawaited(_poll());
        });
      } catch (_) {}

      try {
        window.onClose.whenComplete(() {
          if (!mounted) return;
          setState(() {
            _authWindowOpen = false;
            _embeddedWebViewReady = false;
            if (!_done) _statusText = '授權視窗已關閉，仍會繼續輪詢一段時間。';
          });
        });
      } catch (_) {}

      window.launch(url);

      if (!mounted) return;
      setState(() {
        _openingWindow = false;
        _authWindowOpen = true;
        _statusText = '請在彈出的 Twitch 授權視窗中完成 Drops / Android 授權。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _openingWindow = false;
        _authWindowOpen = false;
        _embeddedWebViewReady = false;
        _errorText = 'Drops 授權視窗建立失敗，請稍後再試。';
        _statusText = '無法建立 Drops 授權視窗。';
      });
    }
  }

  Future<void> _closeAuthWindow() async {
    final window = _authWindow;
    _authWindow = null;
    if (window == null) return;
    try {
      window.close();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _authWindowOpen = false;
    });
  }

  Future<void> _reopenAuthWindow() async {
    final auth = _authorization;
    if (auth == null) return;
    if (_useEmbeddedMobileWebView) {
      setState(() {
        _currentUrl = auth.verificationUri;
        _embeddedWebViewReady = false;
        _statusText = '正在重新載入 App 內 Drops 授權頁...';
      });
      try {
        await _embeddedController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(auth.verificationUri)),
        );
      } catch (_) {}
      return;
    }
    await _openAuthWindow(auth.verificationUri);
  }

  void _schedulePoll() {
    if (_done) return;
    _pollTimer?.cancel();
    _pollTimer = Timer(Duration(seconds: _intervalSeconds), () {
      unawaited(_poll());
    });
  }

  Future<void> _poll() async {
    final auth = _authorization;
    if (auth == null || _polling || _done) return;

    setState(() {
      _polling = true;
      _lastPollText = '正在檢查 Twitch 授權結果...';
    });

    try {
      final result = await widget.dropsAuthService.pollForToken(
        deviceCode: auth.deviceCode,
        currentIntervalSeconds: _intervalSeconds,
      );

      if (!mounted) return;

      switch (result.status) {
        case TwitchDeviceTokenPollStatus.success:
          final valid = await widget.dropsAuthService.validateToken();
          if (!mounted) return;

          if (!valid) {
            setState(() {
              _polling = false;
              _errorText = '已取得授權，但不是 Drops / Android app。請重新授權。';
              _lastPollText = 'Drops 授權驗證失敗。';
            });
            _schedulePoll();
            return;
          }

          _done = true;
          _pollTimer?.cancel();
          await _closeAuthWindow();
          setState(() {
            _polling = false;
            _statusText = 'Drops / Android 登入完成。';
            _lastPollText = '授權成功，正在返回登入檢查頁...';
          });
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.of(context).pop(true);
          return;

        case TwitchDeviceTokenPollStatus.pending:
          setState(() {
            _polling = false;
            _lastPollText = result.message ?? '等待使用者完成授權...';
          });
          _schedulePoll();
          return;

        case TwitchDeviceTokenPollStatus.slowDown:
          _intervalSeconds =
              result.nextIntervalSeconds ?? (_intervalSeconds + 5);
          setState(() {
            _polling = false;
            _lastPollText = result.message ?? 'Twitch 要求降低輪詢頻率。';
          });
          _schedulePoll();
          return;

        case TwitchDeviceTokenPollStatus.expired:
        case TwitchDeviceTokenPollStatus.denied:
        case TwitchDeviceTokenPollStatus.error:
          _pollTimer?.cancel();
          setState(() {
            _polling = false;
            _errorText = result.message ?? 'Drops / Android 登入失敗。';
            _lastPollText = '請重新產生代碼。';
          });
          return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _polling = false;
        _errorText = '檢查 Drops 授權失敗，稍後會自動重試。';
        _lastPollText = '稍後會自動重試。';
      });
      _schedulePoll();
    }
  }

  Future<void> _copyCode() async {
    final code = _authorization?.userCode.trim();
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已複製 Drops 授權代碼')));
  }

  Future<void> _copyUrl() async {
    final url = _authorization?.verificationUri.trim();
    if (url == null || url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已複製 Drops 授權網址')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = _authorization;
    final busy = _starting || _openingWindow || _polling;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        foregroundColor: Colors.white,
        title: const Text('Drops / Android 授權登入'),
        actions: [
          IconButton(
            tooltip: '重新產生',
            onPressed: busy ? null : _start,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          IconButton(
            tooltip: '關閉',
            onPressed: busy ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusHeader(),
          if (_errorText != null) _buildErrorBanner(),
          _buildActionBar(auth),
          Expanded(child: _buildMainPanel(auth)),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF18181B),
        border: Border(bottom: BorderSide(color: Color(0xFF2D2D35))),
      ),
      child: Row(
        children: [
          const Icon(Icons.devices_rounded, color: TwitchUiColors.primarySoft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Drops / Android 授權',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (_polling)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
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
      color: Colors.redAccent.withValues(alpha: 0.20),
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

  Widget _buildActionBar(TwitchDeviceAuthorization? auth) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF111116),
        border: Border(bottom: BorderSide(color: Color(0xFF2D2D35))),
      ),
      child: Row(
        children: [
          const Text(
            '代碼',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          SelectableText(
            auth?.userCode ?? '--------',
            style: const TextStyle(
              color: Color(0xFF5CFFB1),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: auth == null ? null : _copyCode,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('複製代碼'),
            style: _buttonStyle(),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: auth == null ? null : _copyUrl,
            icon: const Icon(Icons.link_rounded, size: 18),
            label: const Text('複製網址'),
            style: _buttonStyle(),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: auth == null || _openingWindow
                ? null
                : _reopenAuthWindow,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(_authWindowOpen ? '重開授權窗' : '開授權窗'),
            style: _buttonStyle(),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _polling ? null : _poll,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text('立即檢查'),
            style: _buttonStyle(),
          ),
          const Spacer(),
          Text(
            _lastPollText ?? (_authWindowOpen ? '授權視窗已開啟' : '等待授權視窗...'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _buttonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFD7B6FF),
      side: const BorderSide(color: Color(0xFF6E4D9A)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }

  Widget _buildMainPanel(TwitchDeviceAuthorization? auth) {
    if (_useEmbeddedMobileWebView && auth != null) {
      final url = _currentUrl ?? auth.verificationUri;
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
                    'Android / iOS：App 內 WebView 授權頁',
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
                  onPressed: _reopenAuthWindow,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('重載'),
                ),
                TextButton.icon(
                  onPressed: _polling ? null : _poll,
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
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
                if (mounted) {
                  setState(() {
                    _currentUrl = nextUrl;
                  });
                }
                unawaited(_poll());
                return NavigationActionPolicy.ALLOW;
              },
              onLoadStart: (controller, webUri) {
                final nextUrl = webUri?.toString();
                if (!mounted) return;
                setState(() {
                  _embeddedWebViewReady = false;
                  _currentUrl = nextUrl;
                  _statusText = 'App 內 WebView 正在載入 Twitch 授權頁...';
                });
              },
              onLoadStop: (controller, webUri) {
                final nextUrl = webUri?.toString();
                if (!mounted) return;
                setState(() {
                  _embeddedWebViewReady = true;
                  _currentUrl = nextUrl;
                  _statusText = '請在 App 內 WebView 完成 Drops / Android 授權。';
                });
                unawaited(_poll());
              },
              onUpdateVisitedHistory: (controller, webUri, androidIsReload) {
                final nextUrl = webUri?.toString();
                if (mounted) {
                  setState(() {
                    _currentUrl = nextUrl;
                  });
                }
                unawaited(_poll());
              },
              onReceivedError: (controller, request, error) {
                if (!mounted || request.isForMainFrame != true) return;
                setState(() {
                  _errorText = 'App 內 Drops 授權頁暫時載入失敗，請稍後重試。';
                });
              },
            ),
          ),
        ],
      );
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: Container(
          width: 620,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _authWindowOpen
                    ? Icons.open_in_new_rounded
                    : Icons.web_asset_off_rounded,
                color: _authWindowOpen
                    ? const Color(0xFF5CFFB1)
                    : Colors.white38,
                size: 64,
              ),
              const SizedBox(height: 14),
              Text(
                _authWindowOpen ? '獨立授權視窗已開啟' : '尚未開啟授權視窗',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                auth == null
                    ? '正在產生 Drops device code...'
                    : '請在彈出的 Twitch 視窗完成 Android App 授權。這個視窗與官方 Web/GQL、主 OAuth 共用同一個 desktop WebView cookie storage。',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: auth == null || _openingWindow
                        ? null
                        : _reopenAuthWindow,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(_authWindowOpen ? '重開授權視窗' : '開啟授權視窗'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TwitchUiColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _polling ? null : _poll,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('立即檢查'),
                    style: _buttonStyle(),
                  ),
                ],
              ),
              if (_currentUrl != null) ...[
                const SizedBox(height: 18),
                SelectableText(
                  _currentUrl!,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
