import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../theme/twitch_ui_tokens.dart';
import 'twitch_drops_device_login_page.dart';
import 'twitch_oauth_webview_login_page.dart';

class TwitchLinkedLoginPage extends StatefulWidget {
  final TwitchAuthService mainAuthService;
  final TwitchWebGqlAuthService webGqlAuthService;
  final TwitchDropsAuthService dropsAuthService;
  final TwitchAuthApiService authApi;
  final TwitchApiClient apiClient;
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
  bool _loading = true;
  bool _loggingIn = false;
  bool _loggingOut = false;

  bool _webGqlReady = false;
  bool _mainReady = false;
  bool _dropsReady = false;

  String _statusText = '正在確認登入狀態…';
  String? _errorText;

  bool get _complete => _webGqlReady && _mainReady && _dropsReady;
  bool get _busy => _loading || _loggingIn || _loggingOut;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadStatus());
    });
  }

  Future<_LinkedLoginStatus> _readStatus() async {
    await widget.webGqlAuthService.loadStoredSession();
    await widget.mainAuthService.loadStoredSession();
    await widget.dropsAuthService.loadStoredSession();

    final webToken = await widget.webGqlAuthService.getToken();
    var webGqlReady = webToken != null && webToken.trim().isNotEmpty;
    if (webGqlReady) {
      webGqlReady = await widget.webGqlAuthService.validateToken();
      if (webGqlReady) {
        webGqlReady = await _verifyWebGqlToken(webToken!);
      }
    }

    final mainToken = await widget.mainAuthService.getValidAccessToken();
    final mainReady = mainToken != null && mainToken.trim().isNotEmpty;

    final dropsToken = await widget.dropsAuthService.getToken();
    var dropsReady = dropsToken != null && dropsToken.trim().isNotEmpty;
    if (dropsReady) {
      dropsReady = await widget.dropsAuthService.validateToken();
    }

    return _LinkedLoginStatus(
      webGqlReady: webGqlReady,
      mainReady: mainReady,
      dropsReady: dropsReady,
    );
  }

  Future<void> _loadStatus() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorText = null;
      _statusText = '正在確認登入狀態…';
    });

    try {
      final status = await _readStatus();
      if (!mounted) return;
      _applyStatus(status);
      setState(() {
        _loading = false;
        _statusText = status.complete ? '已登入' : '尚未登入';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusText = '尚未登入';
        _errorText = '無法確認登入狀態，請重新登入。';
      });
    }
  }

  void _applyStatus(_LinkedLoginStatus status) {
    _webGqlReady = status.webGqlReady;
    _mainReady = status.mainReady;
    _dropsReady = status.dropsReady;
  }

  Future<void> _login() async {
    if (_busy) return;

    setState(() {
      _loggingIn = true;
      _errorText = null;
      _statusText = '正在登入 Twitch…';
    });

    try {
      var status = await _readStatus();
      if (!mounted) return;
      setState(() => _applyStatus(status));

      if (!status.mainReady || !status.webGqlReady) {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => TwitchOAuthWebViewLoginPage(
              mainAuthService: widget.mainAuthService,
              authApi: widget.authApi,
              webGqlAuthService: widget.webGqlAuthService,
              apiClient: widget.apiClient,
              captureWebGqlToken: true,
              mirrorMainTokenToInteraction: false,
            ),
          ),
        );

        status = await _readStatus();
        if (!mounted) return;
        setState(() {
          _applyStatus(status);
          _statusText = status.mainReady && status.webGqlReady
              ? 'Twitch 登入完成，正在完成最後設定…'
              : '登入尚未完成';
        });
      }

      if (status.mainReady && status.webGqlReady && !status.dropsReady) {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => TwitchDropsDeviceLoginPage(
              dropsAuthService: widget.dropsAuthService,
            ),
          ),
        );

        status = await _readStatus();
        if (!mounted) return;
        setState(() => _applyStatus(status));
      }

      if (!mounted) return;
      if (status.complete) {
        setState(() {
          _statusText = '登入完成';
          _errorText = null;
        });
        if (widget.autoCloseOnComplete || Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _statusText = '登入尚未完成';
          _errorText = '登入沒有完成，請再試一次。';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusText = '登入失敗';
        _errorText = '登入過程發生問題，請再試一次。';
      });
    } finally {
      if (mounted) {
        setState(() => _loggingIn = false);
      }
    }
  }

  Future<bool> _verifyWebGqlToken(String token) async {
    try {
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

  Future<void> _logout() async {
    if (_busy) return;
    setState(() {
      _loggingOut = true;
      _errorText = null;
      _statusText = '正在登出…';
    });

    try {
      await widget.mainAuthService.logout();
      await widget.webGqlAuthService.logout();
      await widget.dropsAuthService.logout(clearClientId: false);
      if (!mounted) return;
      setState(() {
        _webGqlReady = false;
        _mainReady = false;
        _dropsReady = false;
        _statusText = '已登出';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusText = '登出失敗';
        _errorText = '無法登出，請稍後再試。';
      });
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
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
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _complete ? Icons.check_circle_rounded : Icons.live_tv_rounded,
                    color: _complete ? Colors.greenAccent : TwitchUiColors.primary,
                    size: 62,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _complete ? '登入完成' : '連結你的 Twitch 帳號',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TwitchUiColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loggingIn || _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _complete ? '重新登入 Twitch' : '使用 Twitch 登入',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                  if (_complete) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy ? null : _logout,
                      child: _loggingOut
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('登出'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkedLoginStatus {
  final bool webGqlReady;
  final bool mainReady;
  final bool dropsReady;

  const _LinkedLoginStatus({
    required this.webGqlReady,
    required this.mainReady,
    required this.dropsReady,
  });

  bool get complete => webGqlReady && mainReady && dropsReady;
}
