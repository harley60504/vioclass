import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../api/chat/twitch_whisper_api_service.dart';

/// Observe only the official page's whisper-list response. Twitch itself owns
/// the login, integrity SDK, request headers and request execution.
class TwitchWhisperBrowserSyncPage extends StatefulWidget {
  final String? cursor;
  const TwitchWhisperBrowserSyncPage({super.key, this.cursor});

  @override
  State<TwitchWhisperBrowserSyncPage> createState() =>
      _TwitchWhisperBrowserSyncPageState();
}

class _TwitchWhisperBrowserSyncPageState
    extends State<TwitchWhisperBrowserSyncPage> {
  Webview? _window;
  InAppWebViewController? _embedded;
  Timer? _poll;
  Timer? _deadline;
  bool _reading = false;
  bool _finished = false;
  String? _error;

  String get _script =>
      '''
(() => {
  if (location.origin !== 'https://www.twitch.tv' || window.__vioWhisperObserver) return;
  window.__vioWhisperObserver = true;
  const cursor = ${jsonEncode(widget.cursor ?? '')};
  const select = body => {
    try {
      const batch = JSON.parse(body);
      if (!Array.isArray(batch)) return -1;
      return batch.findIndex(q => q.operationName === 'Whispers_Whispers_UserWhisperThreads'
        && (q.variables?.cursor ?? '') === cursor);
    } catch (_) { return -1; }
  };
  const keep = (index, data) => {
    if (index < 0 || !Array.isArray(data) || !data[index]) return;
    const text = JSON.stringify(data[index]);
    if (text.length <= 5 * 1024 * 1024) window.__vioWhisperResponse = text;
  };
  const original = window.fetch;
  window.fetch = function(input, init) {
    const url = typeof input === 'string' ? input : input?.url;
    let index = -1;
    try {
      if (new URL(url, location.href).origin === 'https://gql.twitch.tv'
        && new URL(url, location.href).pathname === '/gql') index = select(init?.body);
    } catch (_) {}
    const result = original.apply(this, arguments);
    if (index >= 0) result.then(r => r.clone().json()).then(d => keep(index, d)).catch(() => {});
    return result;
  };
})();
''';

  @override
  void initState() {
    super.initState();
    _deadline = Timer(const Duration(seconds: 110), () {
      if (mounted && !_finished) {
        _finish(null);
      }
    });
    _poll = Timer.periodic(const Duration(milliseconds: 750), (_) => _read());
    if (Platform.isWindows) unawaited(_openDesktop());
  }

  Future<void> _openDesktop() async {
    try {
      final window = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: 'Twitch 私訊列表同步：請登入並開啟悄悄話',
          windowWidth: 1120,
          windowHeight: 820,
          userDataFolderWindows:
              '${Directory.systemTemp.path}${Platform.pathSeparator}'
              'new_twitch_app_shared_twitch_desktop_webview_v30',
        ),
      );
      if (!mounted || _finished) {
        window.close();
        return;
      }
      _window = window;
      window.addScriptToExecuteOnDocumentCreated(_script);
      window.onClose.whenComplete(() {
        if (mounted && !_finished) _finish(null);
      });
      window.launch('https://www.twitch.tv/');
    } catch (_) {
      if (mounted) setState(() => _error = '無法開啟 Twitch 同步視窗。');
    }
  }

  Future<void> _read() async {
    if (_reading || _finished || !mounted) return;
    _reading = true;
    try {
      const read =
          "location.origin === 'https://www.twitch.tv' ? window.__vioWhisperResponse || null : null";
      dynamic value = _window != null
          ? await _window!.evaluateJavaScript(read)
          : await _embedded?.evaluateJavascript(source: read);
      // WebView2 serializes JavaScript string results; Android can return the
      // string directly. Decode at most twice, accepting only a response map.
      for (var i = 0; i < 2 && value is String; i++) {
        value = jsonDecode(value);
      }
      if (value is Map && mounted && !_finished) _finish(value);
    } catch (_) {
      // Normal during navigation. Never log response content or credentials.
    } finally {
      _reading = false;
    }
  }

  void _finish(Object? response) {
    _finished = true;
    _poll?.cancel();
    _deadline?.cancel();
    Navigator.of(context).pop(response);
  }

  @override
  void dispose() {
    _finished = true;
    _poll?.cancel();
    _deadline?.cancel();
    _window?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('同步 Twitch 私訊列表')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error ??
                '請在 Twitch 頁面登入同一帳號，並點右上角「悄悄話」。取得列表後會自動返回。'
                    '${widget.cursor != null ? '同步下一頁時，請在悄悄話列表往下捲動。' : ''}',
          ),
        ),
        if (!Platform.isWindows)
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('https://www.twitch.tv/'),
              ),
              initialUserScripts: UnmodifiableListView([
                UserScript(
                  source: _script,
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ]),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
              ),
              onWebViewCreated: (controller) => _embedded = controller,
            ),
          ),
      ],
    ),
  );
}

Future<Object> readTwitchWhisperBrowserResponse(
  BuildContext context,
  String? cursor,
) async {
  final response = await Navigator.of(context).push<Object>(
    MaterialPageRoute(
      builder: (_) => TwitchWhisperBrowserSyncPage(cursor: cursor),
    ),
  );
  if (response == null) {
    throw const TwitchWhisperException('Twitch 瀏覽器同步已關閉或逾時，原對話保持不變。');
  }
  return response;
}
