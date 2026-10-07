import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Attach the native popup by windowId, rather than navigating the opener to
/// about:blank. The caller retains ownership of the shared cookie environment.
bool openTwitchLoginPopup({
  required BuildContext context,
  required CreateWindowAction action,
  required WebViewEnvironment environment,
  required bool Function(Uri) isOAuthRedirect,
  required void Function(Uri) onOAuthRedirect,
}) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _LoginPopup(
          windowId: action.windowId,
          environment: environment,
          isOAuthRedirect: isOAuthRedirect,
          onOAuthRedirect: onOAuthRedirect,
        ),
      ),
    ),
  );
  // Do not await route dismissal: native creation is waiting for this decision.
  return true;
}

class _LoginPopup extends StatefulWidget {
  final int windowId;
  final WebViewEnvironment environment;
  final bool Function(Uri) isOAuthRedirect;
  final void Function(Uri) onOAuthRedirect;

  const _LoginPopup({
    required this.windowId,
    required this.environment,
    required this.isOAuthRedirect,
    required this.onOAuthRedirect,
  });

  @override
  State<_LoginPopup> createState() => _LoginPopupState();
}

class _LoginPopupState extends State<_LoginPopup> {
  bool _handledRedirect = false;
  String? _error;

  bool _handleRedirect(WebUri? url) {
    final uri = url == null ? null : Uri.tryParse(url.toString());
    if (uri == null || !widget.isOAuthRedirect(uri)) return false;
    if (!_handledRedirect) {
      _handledRedirect = true;
      widget.onOAuthRedirect(uri);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0E0E10),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0E0E10),
      toolbarHeight: 44,
      actions: [
        IconButton(
          tooltip: '關閉',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        if (_error != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
        Expanded(
          child: InAppWebView(
            windowId: widget.windowId,
            webViewEnvironment: widget.environment,
            // No initialUrlRequest: WebView2 must attach the actual opener/popup
            // relationship before the website sends its next navigation.
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              useShouldOverrideUrlLoading: true,
            ),
            shouldOverrideUrlLoading: (_, action) async {
              if (_handleRedirect(action.request.url)) {
                return NavigationActionPolicy.CANCEL;
              }
              final url = action.request.url;
              debugPrint(
                '[TwitchAuth][popup-navigation] '
                'scheme=${url?.scheme ?? '?'} host=${url?.host ?? '?'} policy=allow',
              );
              return NavigationActionPolicy.ALLOW;
            },
            onLoadStart: (_, url) {
              if (_handleRedirect(url)) return;
              if (mounted) setState(() => _error = null);
            },
            onLoadStop: (_, url) => _handleRedirect(url),
            onUpdateVisitedHistory: (_, url, isReload) => _handleRedirect(url),
            onCreateWindow: (_, action) async => openTwitchLoginPopup(
              context: context,
              action: action,
              environment: widget.environment,
              isOAuthRedirect: widget.isOAuthRedirect,
              onOAuthRedirect: widget.onOAuthRedirect,
            ),
            onCloseWindow: (_) {
              if (mounted && ModalRoute.of(context)?.isCurrent == true) {
                Navigator.of(context).pop();
              }
            },
            onReceivedError: (_, request, error) {
              if (!mounted || request.isForMainFrame != true) return;
              if (_handleRedirect(request.url)) return;
              if (error.type == WebResourceErrorType.CANCELLED) return;
              debugPrint(
                '[TwitchAuth][popup-load-error] type=${error.type} '
                'host=${request.url.host}',
              );
              setState(() => _error = '登入頁載入失敗，請返回後再試。');
            },
          ),
        ),
      ],
    ),
  );
}
