import 'dart:async';
import 'dart:io' show Directory, Platform;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../api/auth/twitch_device_auth_api_service.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../services/auth/twitch_drops_auth_service.dart';

class TwitchWindowsInAppWebViewDropsLoginPage extends StatefulWidget {
  final TwitchDropsAuthService dropsAuthService;

  const TwitchWindowsInAppWebViewDropsLoginPage({
    super.key,
    required this.dropsAuthService,
  });

  @override
  State<TwitchWindowsInAppWebViewDropsLoginPage> createState() =>
      _TwitchWindowsInAppWebViewDropsLoginPageState();
}

class _TwitchWindowsInAppWebViewDropsLoginPageState
    extends State<TwitchWindowsInAppWebViewDropsLoginPage> {
  WebViewEnvironment? _environment;
  InAppWebViewController? _controller;
  TwitchDeviceAuthorization? _authorization;
  Timer? _pollTimer;

  bool _initializing = true;
  bool _polling = false;
  bool _done = false;
  int _intervalSeconds = 5;
  String _status = '正在準備 Drops 授權…';
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      if (!Platform.isWindows) {
        throw StateError('Windows InAppWebView Drops test is Windows-only.');
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

      await widget.dropsAuthService.setDropsClientId(
        TwitchApiConstants.twitchAndroidPublicClientId,
        clearTokenOnChange: true,
      );
      await widget.dropsAuthService.logout(clearClientId: false);
      final auth = await widget.dropsAuthService.startDeviceFlow();

      debugPrint('[TwitchDropsInAppWebView][windows] WebView2=$version');
      if (!mounted) return;
      setState(() {
        _environment = environment;
        _authorization = auth;
        _intervalSeconds = auth.interval <= 0 ? 5 : auth.interval;
        _initializing = false;
        _status = '請在 Twitch 頁面完成 Drops 授權';
      });
      _schedulePoll();
    } catch (e) {
      debugPrint('[TwitchDropsInAppWebView][windows] init failed: $e');
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Drops WebView 初始化失敗：$e';
      });
    }
  }

  void _schedulePoll() {
    if (_done) return;
    _pollTimer?.cancel();
    debugPrint(
      '[TwitchDropsInAppWebView][poll] next in ${_intervalSeconds}s',
    );
    _pollTimer = Timer(
      Duration(seconds: _intervalSeconds),
      () => unawaited(_poll()),
    );
  }

  Future<void> _poll() async {
    final auth = _authorization;
    if (auth == null || _polling || _done) return;

    _pollTimer?.cancel();
    _pollTimer = null;
    if (mounted) setState(() => _polling = true);

    try {
      final result = await widget.dropsAuthService.pollForToken(
        deviceCode: auth.deviceCode,
        currentIntervalSeconds: _intervalSeconds,
      );
      if (!mounted) return;

      debugPrint(
        '[TwitchDropsInAppWebView][poll] result=${result.status.name} '
        'interval=${_intervalSeconds}s',
      );

      switch (result.status) {
        case TwitchDeviceTokenPollStatus.success:
          final valid = await widget.dropsAuthService.validateToken();
          if (!mounted) return;
          if (!valid) {
            setState(() {
              _polling = false;
              _error = '已取得授權，但 Drops token 驗證失敗。';
            });
            _schedulePoll();
            return;
          }
          _done = true;
          _pollTimer?.cancel();
          setState(() {
            _polling = false;
            _status = 'Drops 登入完成';
          });
          await Future<void>.delayed(const Duration(milliseconds: 300));
          if (mounted) Navigator.of(context).pop(true);
          return;

        case TwitchDeviceTokenPollStatus.pending:
          setState(() {
            _polling = false;
            _status = '等待 Twitch 完成 Drops 授權…';
          });
          _schedulePoll();
          return;

        case TwitchDeviceTokenPollStatus.slowDown:
          _intervalSeconds =
              result.nextIntervalSeconds ?? (_intervalSeconds + 5);
          setState(() {
            _polling = false;
            _status = 'Twitch 要求降低檢查頻率，等待 ${_intervalSeconds} 秒…';
          });
          _schedulePoll();
          return;

        case TwitchDeviceTokenPollStatus.expired:
        case TwitchDeviceTokenPollStatus.denied:
        case TwitchDeviceTokenPollStatus.error:
          _pollTimer?.cancel();
          setState(() {
            _polling = false;
            _error = result.message ?? 'Drops 登入失敗。';
          });
          return;
      }
    } catch (e) {
      debugPrint('[TwitchDropsInAppWebView][poll] $e');
      if (!mounted) return;
      setState(() {
        _polling = false;
        _error = '檢查 Drops 授權失敗：$e';
      });
      _schedulePoll();
    }
  }

  Future<bool> _openPopup(CreateWindowAction action) async {
    final environment = _environment;
    if (environment == null || !mounted) return false;
    debugPrint('[TwitchDropsInAppWebView][popup] windowId=${action.windowId}');

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
                debugPrint('[TwitchDropsInAppWebView][popup][start] $url');
              },
              onLoadStop: (_, url) {
                debugPrint('[TwitchDropsInAppWebView][popup][stop] $url');
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
    final auth = _authorization;
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        foregroundColor: Colors.white,
        title: const Text('Drops · InAppWebView 測試'),
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      color: const Color(0xFF18181B),
                      child: Row(
                        children: [
                          if (_polling)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(Icons.devices_rounded),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _status,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          if (auth != null)
                            Text(
                              auth.userCode,
                              style: const TextStyle(
                                color: Color(0xFF5CFFB1),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: auth == null
                          ? const Center(child: CircularProgressIndicator())
                          : InAppWebView(
                              webViewEnvironment: _environment,
                              initialUrlRequest: URLRequest(
                                url: WebUri(auth.verificationUri),
                              ),
                              initialSettings: InAppWebViewSettings(
                                javaScriptEnabled: true,
                                domStorageEnabled: true,
                                databaseEnabled: true,
                                supportMultipleWindows: true,
                                javaScriptCanOpenWindowsAutomatically: true,
                                supportZoom: false,
                              ),
                              onWebViewCreated: (controller) {
                                _controller = controller;
                                debugPrint(
                                  '[TwitchDropsInAppWebView][windows] created',
                                );
                              },
                              onCreateWindow: (_, action) => _openPopup(action),
                              onLoadStart: (_, url) {
                                debugPrint(
                                  '[TwitchDropsInAppWebView][start] $url',
                                );
                              },
                              onLoadStop: (_, url) {
                                debugPrint(
                                  '[TwitchDropsInAppWebView][stop] $url',
                                );
                              },
                              onUpdateVisitedHistory: (_, url, __) {
                                debugPrint(
                                  '[TwitchDropsInAppWebView][history] $url',
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
