import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../theme/twitch_ui_tokens.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

Future<void> showTwitchSubscribeWebViewDialogV1({
  required BuildContext context,
  required Uri initialUri,
  required String channelLogin,
}) async {
  await showTwitchResponsiveSheet<void>(
    context: context,
    maxWidth: 1080,
    portraitHeightFactor: 0.92,
    landscapeHeightFactor: 0.94,
    enableDrag: false,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: _TwitchSubscribeWebViewDialogBody(
        initialUri: initialUri,
        channelLogin: channelLogin,
      ),
    ),
  );
}

class _TwitchSubscribeWebViewDialogBody extends StatefulWidget {
  final Uri initialUri;
  final String channelLogin;

  const _TwitchSubscribeWebViewDialogBody({
    required this.initialUri,
    required this.channelLogin,
  });

  @override
  State<_TwitchSubscribeWebViewDialogBody> createState() =>
      _TwitchSubscribeWebViewDialogBodyState();
}

class _TwitchSubscribeWebViewDialogBodyState
    extends State<_TwitchSubscribeWebViewDialogBody> {
  InAppWebViewController? _controller;
  double _progress = 0;
  String _currentUrl = '';
  String? _errorText;
  bool _cookiesPrimed = false;
  late final Future<void> _cookiePrimeFuture;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUri.toString();
    _cookiePrimeFuture = _primeTwitchAuthCookie();
  }

  Future<void> _primeTwitchAuthCookie() async {
    if (_cookiesPrimed) return;
    _cookiesPrimed = true;

    final token = await _readStoredWebGqlToken();
    if (token == null || token.isEmpty) return;

    final cookieManager = CookieManager.instance();
    for (final url in const <String>[
      'https://www.twitch.tv',
      'https://twitch.tv',
    ]) {
      try {
        await cookieManager.setCookie(
          url: WebUri(url),
          name: 'auth-token',
          value: token,
          domain: '.twitch.tv',
          path: '/',
          isSecure: true,
        );
      } catch (_) {}
    }
  }

  Future<String?> _readStoredWebGqlToken() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(TwitchWebGqlAuthService.tokenStorageKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final token = decoded['accessToken']?.toString().trim();
      return token == null || token.isEmpty ? null : token;
    } catch (_) {
      return null;
    }
  }

  Future<void> _reload() async {
    await _controller?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final titleLogin = widget.channelLogin.trim().isEmpty
        ? 'Twitch'
        : widget.channelLogin.trim();

    return Column(
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: const BoxDecoration(
            color: Color(0xFF0E0E10),
            border: Border(bottom: BorderSide(color: Color(0xFF2D2D35))),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: null,
                onPressed: _reload,
                icon: const Icon(Icons.refresh, color: Colors.white70),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.star_rate_rounded,
                color: TwitchUiColors.primarySoft,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '訂閱 $titleLogin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      _currentUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: null,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
        ),
        if (_progress > 0 && _progress < 1)
          LinearProgressIndicator(
            value: _progress,
            minHeight: 2,
            color: TwitchUiColors.primary,
            backgroundColor: const Color(0xFF2D2D35),
          ),
        if (_errorText != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: Colors.redAccent.withValues(alpha: 0.14),
            child: Text(
              _errorText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Expanded(
          child: ColoredBox(
            color: Colors.black,
            child: FutureBuilder<void>(
              future: _cookiePrimeFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: TwitchUiColors.primary,
                    ),
                  );
                }

                return InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(widget.initialUri.toString()),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    supportMultipleWindows: true,
                    thirdPartyCookiesEnabled: true,
                    sharedCookiesEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    transparentBackground: false,
                    useShouldOverrideUrlLoading: true,
                  ),
                  onWebViewCreated: (controller) {
                    _controller = controller;
                  },
                  onLoadStart: (controller, url) {
                    if (!mounted) return;
                    setState(() {
                      _currentUrl = url?.toString() ?? _currentUrl;
                      _errorText = null;
                    });
                  },
                  onLoadStop: (controller, url) {
                    if (!mounted) return;
                    setState(() {
                      _currentUrl = url?.toString() ?? _currentUrl;
                      _progress = 1;
                    });
                  },
                  onProgressChanged: (controller, progress) {
                    if (!mounted) return;
                    setState(() {
                      _progress = (progress / 100.0).clamp(0.0, 1.0);
                    });
                  },
                  onReceivedError: (controller, request, error) {
                    if (!mounted) return;
                    setState(() {
                      _errorText = '訂閱頁暫時載入失敗，請稍後重試。';
                    });
                  },
                  onCreateWindow: (controller, createWindowAction) async {
                    final url = createWindowAction.request.url;
                    if (url != null) {
                      await controller.loadUrl(
                        urlRequest: URLRequest(url: url),
                      );
                    }
                    return true;
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                        final url = navigationAction.request.url;
                        if (url == null) return NavigationActionPolicy.ALLOW;

                        final scheme = url.scheme.toLowerCase();
                        if (scheme == 'http' || scheme == 'https') {
                          return NavigationActionPolicy.ALLOW;
                        }

                        // Prevent non-web schemes from crashing desktop WebView.
                        return NavigationActionPolicy.CANCEL;
                      },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
