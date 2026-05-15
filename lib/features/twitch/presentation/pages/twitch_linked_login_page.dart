// PATCH VERSION: twitch_linked_login_page_responsive_compact_v33
import 'dart:async';
import 'dart:io' show Directory, Platform;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import 'twitch_drops_device_login_page.dart';
import 'twitch_interaction_web_login_page.dart';
import 'twitch_oauth_webview_login_page.dart';

class TwitchLinkedLoginPage extends StatefulWidget {
  final TwitchAuthService mainAuthService;
  final TwitchWebGqlAuthService webGqlAuthService;
  final TwitchDropsAuthService dropsAuthService;
  final TwitchAuthApiService authApi;
  final TwitchApiClient apiClient;

  /// If true, a successful one-click repair pops this page immediately.
  final bool autoCloseOnComplete;

  const TwitchLinkedLoginPage({
    super.key,
    required this.mainAuthService,
    required this.webGqlAuthService,
    required this.dropsAuthService,
    required this.authApi,
    required this.apiClient,
    this.autoCloseOnComplete = false,
  });

  @override
  State<TwitchLinkedLoginPage> createState() => _TwitchLinkedLoginPageState();
}

class _TwitchLinkedLoginPageState extends State<TwitchLinkedLoginPage> {
  bool _loadingStored = true;
  bool _runningUnifiedLogin = false;
  bool _loggingOut = false;

  bool _webGqlTokenReady = false;
  bool _mainLoggedIn = false;
  bool _dropsTokenReady = false;

  String _statusText = '正在讀取 Twitch 登入狀態...';
  String? _errorText;
  String? _lastActionText;

  bool get _completeLogin =>
      _webGqlTokenReady && _mainLoggedIn && _dropsTokenReady;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadStoredSession());
    });
  }

  Future<void> _loadStoredSession() async {
    setState(() {
      _loadingStored = true;
      _errorText = null;
      _statusText = '正在讀取 Twitch 登入狀態...';
    });

    try {
      final status = await _readUnifiedStatus();
      if (!mounted) return;
      setState(() {
        _webGqlTokenReady = status.webGqlReady;
        _mainLoggedIn = status.mainReady;
        _dropsTokenReady = status.dropsReady;
        _loadingStored = false;
        _statusText = _buildStatusText();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _webGqlTokenReady = false;
        _mainLoggedIn = false;
        _dropsTokenReady = false;
        _loadingStored = false;
        _errorText = '讀取登入狀態失敗：$e';
        _statusText = '請重新登入或使用自動修復。';
      });
    }
  }

  Future<_UnifiedLoginStatus> _readUnifiedStatus() async {
    await widget.webGqlAuthService.loadStoredSession();
    await widget.mainAuthService.loadStoredSession();
    await widget.dropsAuthService.loadStoredSession();

    final webToken = await widget.webGqlAuthService.getToken();
    var webReady = webToken != null && webToken.trim().isNotEmpty;
    if (webReady) {
      webReady = await widget.webGqlAuthService.validateToken();
      if (webReady) webReady = await _verifyWebGqlToken(webToken!);
    }

    final mainToken = await widget.mainAuthService.getValidAccessToken();
    final mainReady = mainToken != null && mainToken.trim().isNotEmpty;

    final dropsToken = await widget.dropsAuthService.getToken();
    var dropsReady = dropsToken != null && dropsToken.trim().isNotEmpty;
    if (dropsReady) dropsReady = await widget.dropsAuthService.validateToken();

    return _UnifiedLoginStatus(
      webGqlReady: webReady,
      mainReady: mainReady,
      dropsReady: dropsReady,
    );
  }

  String _buildStatusText() {
    if (_completeLogin) return '官方 Web/GQL、主 OAuth、Drops / Android 都已完成，可以進入 App。';

    final missing = <String>[];
    if (!_webGqlTokenReady) missing.add('官方 Web / GQL token');
    if (!_mainLoggedIn) missing.add('主 Twitch token');
    if (!_dropsTokenReady) missing.add('Drops / Android token');
    return '尚缺：${missing.join('、')}';
  }

  Future<void> _runUnifiedLoginFlow() async {
    if (_runningUnifiedLogin) return;

    setState(() {
      _runningUnifiedLogin = true;
      _errorText = null;
      _lastActionText = null;
      _statusText = '開始一鍵 Twitch 登入流程...';
    });

    try {
      var status = await _readUnifiedStatus();
      await _applyStatus(status);

      // v29: Web/GQL is merged into the main OAuth desktop window.
      // When both Web/GQL and main OAuth are missing, this opens only one
      // desktop_webview_window: OAuth first, then it switches to twitch.tv in
      // the same window to capture the official Web/GQL token.
      if (!status.webGqlReady || !status.mainReady) {
        await _pushMainLogin(captureWebGqlToken: !status.webGqlReady);
        status = await _readUnifiedStatus();
        await _applyStatus(
          status,
          actionText: '主 OAuth / 官方 Web GQL token 檢查完成。',
        );
      }

      if (!status.dropsReady) {
        await _pushDropsLogin();
        status = await _readUnifiedStatus();
        await _applyStatus(status, actionText: 'Drops / Android token 檢查完成。');
      }

      if (!mounted) return;

      if (status.complete) {
        setState(() {
          _statusText = '完整登入完成，正在進入 App...';
          _lastActionText = '三種 token 都已通過驗證。';
        });

        if (widget.autoCloseOnComplete || Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _errorText = '一鍵登入未完成，請查看缺少哪一項並單獨補登入。';
          _statusText = _buildStatusText();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = '一鍵登入流程失敗：$e';
        _statusText = '登入流程中斷，請單獨補失敗項目。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _runningUnifiedLogin = false;
        });
      }
    }
  }

  Future<void> _applyStatus(
    _UnifiedLoginStatus status, {
    String? actionText,
  }) async {
    if (!mounted) return;
    setState(() {
      _webGqlTokenReady = status.webGqlReady;
      _mainLoggedIn = status.mainReady;
      _dropsTokenReady = status.dropsReady;
      _loadingStored = false;
      _statusText = _buildStatusText();
      if (actionText != null) _lastActionText = actionText;
    });
  }

  Future<void> _pushWebGqlLogin() async {
    if (!mounted) return;
    setState(() {
      _statusText = '正在建立官方 Twitch Web session 並擷取 GQL token...';
    });

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TwitchInteractionWebLoginPage(
          webGqlAuthService: widget.webGqlAuthService,
          apiClient: widget.apiClient,
        ),
      ),
    );
  }

  Future<void> _pushMainLogin({bool captureWebGqlToken = true}) async {
    if (!mounted) return;
    setState(() {
      _statusText = '正在登入主 Twitch token，並嘗試在同一視窗擷取官方 Web/GQL token...';
    });

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TwitchOAuthWebViewLoginPage(
          mainAuthService: widget.mainAuthService,
          authApi: widget.authApi,
          webGqlAuthService: widget.webGqlAuthService,
          apiClient: widget.apiClient,
          captureWebGqlToken: captureWebGqlToken,
          mirrorMainTokenToInteraction: false,
        ),
      ),
    );
  }

  Future<void> _pushDropsLogin() async {
    if (!mounted) return;
    setState(() {
      _statusText = '正在登入 Drops / Android token...';
    });

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TwitchDropsDeviceLoginPage(
          dropsAuthService: widget.dropsAuthService,
        ),
      ),
    );
  }

  Future<void> _openWebGqlLogin() async {
    await _pushWebGqlLogin();
    await _loadStoredSession();
  }

  Future<void> _openMainLogin() async {
    await _pushMainLogin();
    await _loadStoredSession();
  }

  Future<void> _openDropsLogin() async {
    await _pushDropsLogin();
    await _loadStoredSession();
  }

  Future<bool> _verifyWebGqlToken(String token) async {
    try {
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
          'variables': <String, dynamic>{
            'channelLogin': 'twitch',
          },
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
      if (data is! Map || data['user'] == null) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        TwitchInteractionWebLoginPage.interactionGqlVerifiedStorageKey,
        DateTime.now().toIso8601String(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _logoutTwitch() async {
    if (_loggingOut) return;

    final confirm = await showTwitchResponsiveSheet<bool>(
      context: context,
      maxWidth: 440,
      portraitHeightFactor: 0.46,
      landscapeHeightFactor: 0.76,
      builder: (dialogContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '登出 Twitch',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '關閉',
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      '這會登出目前 App 內保存的 Twitch 登入狀態，並依平台清除 WebView cookie/cache。Android / iOS 會清除內嵌 WebView cookie；桌面版會清除 desktop_webview_window 的資料資料夾。登出後需要重新登入。',
                      style: TextStyle(color: Colors.white70, height: 1.35),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('登出'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _loggingOut = true;
      _errorText = null;
      _statusText = '正在登出 Twitch 並清除本機登入狀態...';
    });

    try {
      await widget.mainAuthService.logout();
      await widget.webGqlAuthService.logout();
      await widget.dropsAuthService.logout(clearClientId: false);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(TwitchInteractionWebLoginPage.interactionGqlVerifiedStorageKey);
      await prefs.remove('new_twitch_app_twitch_interaction_token');
      await prefs.remove('new_twitch_app_twitch_interaction_gql_verified_at');
      await prefs.remove('new_twitch_app_twitch_web_gql_token');
      await prefs.remove('new_twitch_app_twitch_web_gql_validated_at');
      await prefs.remove('new_twitch_app_twitch_drops_token');
      await prefs.remove('new_twitch_app_twitch_drops_validated_at');
      await prefs.setString(
        'new_twitch_app_twitch_drops_client_id',
        TwitchApiConstants.twitchAndroidPublicClientId,
      );

      await _clearPlatformWebViewSession();

      if (!mounted) return;
      setState(() {
        _webGqlTokenReady = false;
        _mainLoggedIn = false;
        _dropsTokenReady = false;
        _lastActionText = '已登出並清除全部 Twitch 登入資訊。';
        _statusText = '已登出，可以重新一鍵登入。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = '登出失敗：$e';
        _statusText = '登出失敗。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
        });
      }
    }
  }


  Future<void> _clearPlatformWebViewSession() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await _clearDesktopWebViewUserDataFolder();
      return;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      await _clearEmbeddedMobileWebViewSession();
    }
  }

  Future<void> _clearEmbeddedMobileWebViewSession() async {
    // Android / iOS 使用 InAppWebView。這裡不能只刪 SharedPreferences，
    // 否則 Twitch 的 Web cookie 還留在系統 WebView 裡，下一次登入會直接吃到舊帳號。
    try {
      final cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();

      // deleteAllCookies 在部分 Android WebView 版本可能沒有立刻涵蓋全部網域，
      // 所以再針對 Twitch auth 相關網域補一次。
      for (final url in const <String>[
        'https://www.twitch.tv',
        'https://id.twitch.tv',
        'https://auth.twitch.tv',
        'https://passport.twitch.tv',
        'https://gql.twitch.tv',
      ]) {
        try {
          await cookieManager.deleteCookies(url: WebUri(url));
        } catch (_) {
          // Best-effort cleanup per host.
        }
      }
    } catch (_) {
      // Best-effort cleanup: token storage has already been cleared above.
    }

    try {
      await WebStorageManager.instance().deleteAllData();
    } catch (_) {
      // Best-effort cleanup for localStorage/sessionStorage/IndexedDB.
    }
  }

  Future<void> _clearDesktopWebViewUserDataFolder() async {
    final path = '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'new_twitch_app_shared_twitch_desktop_webview_v30';
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // The WebView runtime may keep files locked while a window is still open.
      // Token/session keys are already cleared above; the folder will be reused
      // or cleaned on the next full restart.
    }
  }

  void _finish() {
    if (_completeLogin) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _errorText = '登入尚未完整：$_statusText';
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loadingStored || _runningUnifiedLogin || _loggingOut;
    final iconColor = _completeLogin
        ? Colors.greenAccent
        : (_webGqlTokenReady ? Colors.orangeAccent : const Color(0xFF9146FF));

    final titleText = _completeLogin ? 'Twitch 完整登入完成' : 'Twitch 統一登入 v32';

    final descriptionText = _completeLogin
        ? '官方 Twitch Web / GQL、主 OAuth token、Drops / Android token 都已通過。'
        : '按一鍵登入後，主 OAuth 容器會順手擷取官方 Web/GQL token，不會再另外跳一次 Web/GQL；桌面使用獨立 WebView 視窗，Android / iOS 使用 App 內 WebView；登出時會依平台清除對應 cookie。';

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF18181B),
                border: Border(bottom: BorderSide(color: Color(0xFF2D2D35))),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '關閉',
                    onPressed: busy ? null : () => Navigator.of(context).maybePop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Twitch 登入驗證',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            if (_errorText != null)
              Container(
                width: double.infinity,
                color: const Color(0xFF2A120F),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: Text(
                  _errorText!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Container(
                  constraints: const BoxConstraints(maxWidth: 820),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: _loadingStored
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (MediaQuery.sizeOf(context).height >= 520)
                            Icon(
                              _completeLogin
                                  ? Icons.verified_rounded
                                  : Icons.login_rounded,
                              color: iconColor,
                              size: 52,
                            ),
                            if (MediaQuery.sizeOf(context).height >= 520)
                              const SizedBox(height: 14),
                            Text(
                              titleText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              descriptionText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white60,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_lastActionText != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _lastActionText!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _completeLogin
                                      ? Colors.greenAccent
                                      : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            _LoginStateChecklist(
                              webGqlTokenReady: _webGqlTokenReady,
                              mainLoggedIn: _mainLoggedIn,
                              dropsTokenReady: _dropsTokenReady,
                            ),
                            const SizedBox(height: 20),
                            _LoginActionButtons(
                              busy: busy,
                              runningUnifiedLogin: _runningUnifiedLogin,
                              loggingOut: _loggingOut,
                              completeLogin: _completeLogin,
                              onUnifiedLogin: _runUnifiedLoginFlow,
                              onReload: _loadStoredSession,
                              onWebGqlLogin: _openWebGqlLogin,
                              onMainLogin: _openMainLogin,
                              onDropsLogin: _openDropsLogin,
                              onLogout: _logoutTwitch,
                              onFinish: _finish,
                            ),
                            /* Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: busy ? null : _runUnifiedLoginFlow,
                                  icon: _runningUnifiedLogin
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.auto_awesome_rounded),
                                  label: const Text('一鍵完成 Twitch 登入'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF9146FF),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy ? null : _loadStoredSession,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('重新檢查'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy ? null : _openWebGqlLogin,
                                  icon: const Icon(Icons.language_rounded),
                                  label: const Text('只補官方 Web/GQL'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy ? null : _openMainLogin,
                                  icon: const Icon(Icons.person_rounded),
                                  label: const Text('只補主 OAuth'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy ? null : _openDropsLogin,
                                  icon: const Icon(Icons.vpn_key_rounded),
                                  label: const Text('只補 Drops / Android'),
                                ),
                                TextButton.icon(
                                  onPressed: busy ? null : _logoutTwitch,
                                  icon: _loggingOut
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.logout_rounded),
                                  label: const Text('登出'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _completeLogin && !busy ? _finish : null,
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text('進入 App'),
                                ),
                              ],
                            ), */
                          ],
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginActionButtons extends StatelessWidget {
  final bool busy;
  final bool runningUnifiedLogin;
  final bool loggingOut;
  final bool completeLogin;
  final VoidCallback onUnifiedLogin;
  final VoidCallback onReload;
  final VoidCallback onWebGqlLogin;
  final VoidCallback onMainLogin;
  final VoidCallback onDropsLogin;
  final VoidCallback onLogout;
  final VoidCallback onFinish;

  const _LoginActionButtons({
    required this.busy,
    required this.runningUnifiedLogin,
    required this.loggingOut,
    required this.completeLogin,
    required this.onUnifiedLogin,
    required this.onReload,
    required this.onWebGqlLogin,
    required this.onMainLogin,
    required this.onDropsLogin,
    required this.onLogout,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 520 ||
        MediaQuery.sizeOf(context).height < 560;

    final primaryButtons = <Widget>[
      ElevatedButton.icon(
        onPressed: busy ? null : onUnifiedLogin,
        icon: runningUnifiedLogin
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: const Text('一鍵完成 Twitch 登入'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9146FF),
          foregroundColor: Colors.white,
        ),
      ),
      ElevatedButton.icon(
        onPressed: completeLogin && !busy ? onFinish : null,
        icon: const Icon(Icons.check_rounded),
        label: const Text('進入 App'),
      ),
    ];

    final secondaryButtons = <Widget>[
      OutlinedButton.icon(
        onPressed: busy ? null : onReload,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('重新檢查'),
      ),
      OutlinedButton.icon(
        onPressed: busy ? null : onWebGqlLogin,
        icon: const Icon(Icons.language_rounded),
        label: const Text('只補官方 Web/GQL'),
      ),
      OutlinedButton.icon(
        onPressed: busy ? null : onMainLogin,
        icon: const Icon(Icons.person_rounded),
        label: const Text('只補主 OAuth'),
      ),
      OutlinedButton.icon(
        onPressed: busy ? null : onDropsLogin,
        icon: const Icon(Icons.vpn_key_rounded),
        label: const Text('只補 Drops / Android'),
      ),
      TextButton.icon(
        onPressed: busy ? null : onLogout,
        icon: loggingOut
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout_rounded),
        label: const Text('登出'),
        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
      ),
    ];

    if (!compact) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [...primaryButtons, ...secondaryButtons],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: primaryButtons,
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 4),
          title: const Text(
            '更多登入選項',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: secondaryButtons,
            ),
          ],
        ),
      ],
    );
  }
}

class _UnifiedLoginStatus {
  final bool webGqlReady;
  final bool mainReady;
  final bool dropsReady;

  const _UnifiedLoginStatus({
    required this.webGqlReady,
    required this.mainReady,
    required this.dropsReady,
  });

  bool get complete => webGqlReady && mainReady && dropsReady;
}

class _LoginStateChecklist extends StatelessWidget {
  final bool webGqlTokenReady;
  final bool mainLoggedIn;
  final bool dropsTokenReady;

  const _LoginStateChecklist({
    required this.webGqlTokenReady,
    required this.mainLoggedIn,
    required this.dropsTokenReady,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111116),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          _LoginStateRow(
            done: webGqlTokenReady,
            title: '1. 官方 Twitch Web / GQL',
            subtitle: '通常由主 OAuth 視窗順手擷取；失敗時才需要單獨補登入',
          ),
          const SizedBox(height: 10),
          _LoginStateRow(
            done: mainLoggedIn,
            title: '2. 主 OAuth token',
            subtitle: '你的 App OAuth；同一視窗會順手讀官方 Web/GQL token',
          ),
          const SizedBox(height: 10),
          _LoginStateRow(
            done: dropsTokenReady,
            title: '3. Drops / Android token',
            subtitle: 'StreamNook-style Follow / Unfollow / Drops APQ',
          ),
        ],
      ),
    );
  }
}

class _LoginStateRow extends StatelessWidget {
  final bool done;
  final String title;
  final String subtitle;

  const _LoginStateRow({
    required this.done,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? Colors.greenAccent : Colors.orangeAccent;

    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
