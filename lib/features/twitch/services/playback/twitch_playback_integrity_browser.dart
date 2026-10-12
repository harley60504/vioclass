import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../auth/twitch_desktop_webview_settings.dart';
import '../auth/twitch_webview_environment_disposal.dart';
import '../../api/playback/twitch_playback_viewer_auth.dart';
import 'twitch_playback_integrity_manager.dart';

class TwitchPlaybackIntegrityBrowserAcquirer {
  const TwitchPlaybackIntegrityBrowserAcquirer();

  static const String _documentStartScript = r'''
(() => {
  if (location.origin !== 'https://www.twitch.tv') return;
  window.__vioPlaybackIntegrity = {ready:false, started:false, result:null};
  const ready = () => { window.__vioPlaybackIntegrity.ready = true; };
  document.addEventListener('kpsdk-ready', ready, true);
  window.addEventListener('kpsdk-ready', ready, true);
})();
''';

  Future<TwitchPlaybackIntegrityContext> acquire({
    required String clientId,
    required String channelLogin,
    required TwitchPlaybackViewerAuth? viewerAuth,
  }) async {
    if (!Platform.isWindows && !Platform.isAndroid) {
      throw UnsupportedError(
        'Playback integrity browser supports Windows/Android only.',
      );
    }
    await prepareTwitchDesktopWebViewSettings();
    final environment = Platform.isWindows
        ? await WebViewEnvironment.create(
            settings: WebViewEnvironmentSettings(
              userDataFolder:
                  '${Directory.systemTemp.path}${Platform.pathSeparator}'
                  'new_twitch_app_shared_twitch_desktop_webview_v30',
            ),
          )
        : null;
    try {
      final controller = Completer<InAppWebViewController>();
      final browser = HeadlessInAppWebView(
        webViewEnvironment: environment,
        initialUrlRequest: URLRequest(
          url: WebUri('https://www.twitch.tv/$channelLogin'),
        ),
        initialUserScripts: UnmodifiableListView<UserScript>([
          UserScript(
            source: _documentStartScript,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
        ]),
        initialSettings: twitchDesktopWebViewSettings(
          InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
          ),
        ),
        onWebViewCreated: (value) => controller.complete(value),
      );
      try {
        await browser.run();
        final value = await controller.future.timeout(
          const Duration(seconds: 10),
        );
        return await _capture(
          clientId: clientId,
          viewerAuth: viewerAuth,
          evaluate: (script) => value.evaluateJavascript(source: script),
        );
      } finally {
        await browser.dispose();
      }
    } finally {
      if (environment != null) {
        await disposeTwitchWebViewEnvironment(environment);
      }
    }
  }

  Future<TwitchPlaybackIntegrityContext> _capture({
    required String clientId,
    required TwitchPlaybackViewerAuth? viewerAuth,
    required Future<dynamic> Function(String) evaluate,
    Duration timeout = const Duration(seconds: 40),
    Duration pollInterval = const Duration(milliseconds: 500),
  }) async {
    final watch = Stopwatch()..start();
    while (watch.elapsed < timeout) {
      dynamic value;
      try {
        value = await evaluate('''
(() => {
  if (location.origin !== 'https://www.twitch.tv') return null;
  const state = window.__vioPlaybackIntegrity;
  if (!state) return null;
  if (state.ready && !state.started) {
    state.started = true;
    (async () => {
      try {
        const cookie = document.cookie.split('; ').find(v => v.startsWith('unique_id='));
        const device = cookie ? decodeURIComponent(cookie.slice('unique_id='.length)) : '';
        if (device.length < 16 || device.length > 128 || /[^a-zA-Z0-9_-]/.test(device)) {
          state.result = {error:'device-unavailable'}; return;
        }
        const response = await window.fetch('https://gql.twitch.tv/integrity', {
          method:'POST', body:null, mode:'cors', credentials:'omit',
          headers:{'Client-ID':${jsonEncode(clientId)}, 'x-device-id':device,
            ...${viewerAuth == null ? '{}' : jsonEncode(<String, String>{'Authorization': 'OAuth ${viewerAuth.accessToken}'})}}
        });
        if (!response.ok) { state.result = {error:'integrity-http', status:response.status}; return; }
        const data = await response.json();
        state.result = {token:data.token, expiration:data.expiration,
          deviceId:device, userAgent:navigator.userAgent};
      } catch (_) { state.result = {error:'integrity-request'}; }
    })();
  }
  return JSON.stringify(state.result);
})();
''').timeout(timeout - watch.elapsed);
        for (var index = 0; index < 2 && value is String; index++) {
          value = jsonDecode(value);
        }
      } catch (_) {
        await Future<void>.delayed(pollInterval);
        continue;
      }
      if (value is Map) {
        if (value['error'] != null) {
          final status = value['status'] is num
              ? ' HTTP ${value['status']}'
              : '';
          throw StateError(
            'Playback integrity acquisition failed (${value['error']}$status).',
          );
        }
        final token = value['token'];
        final deviceId = value['deviceId'];
        final userAgent = value['userAgent'];
        final expiration = value['expiration'];
        if (token is! String ||
            deviceId is! String ||
            userAgent is! String ||
            expiration is! num) {
          throw StateError('Playback integrity response is invalid.');
        }
        final context = TwitchPlaybackIntegrityContext(
          clientId: clientId,
          token: token,
          deviceId: deviceId,
          userAgent: userAgent,
          expiresAt: DateTime.fromMillisecondsSinceEpoch(
            expiration.toInt(),
            isUtc: true,
          ),
          identityKey: viewerAuth?.identityKey ?? 'anonymous',
        );
        context.headersFor(
          expectedClientId: clientId,
          expectedIdentityKey: viewerAuth?.identityKey ?? 'anonymous',
        );
        return context;
      }
      await Future<void>.delayed(pollInterval);
    }
    throw TimeoutException(
      'Playback integrity acquisition timed out.',
      timeout,
    );
  }
}
