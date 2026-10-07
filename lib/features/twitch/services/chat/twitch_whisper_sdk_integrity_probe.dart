import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';

import '../../api/chat/twitch_whisper_api_service.dart';
import '../../api/chat/twitch_whisper_threads_api_service.dart';
import 'twitch_whisper_inbox_controller.dart';

/// Bounded debug harness, invoked only from the local Dart VM service.
Future<void> runTwitchWhisperSdkPaginationProbe(
  TwitchWhisperInboxController inbox,
) async {
  if (!kDebugMode ||
      !const bool.fromEnvironment('TWITCH_WHISPER_SDK_PROBE') ||
      inbox.syncingThreads) {
    return;
  }
  for (var page = 0; page < 10 && !inbox.threadsComplete; page++) {
    await inbox.syncThreads(more: true);
    if (inbox.threadsError != null) return;
  }
}

/// Debug-only experiment. Runs Twitch's normal SDK, never observes a whisper
/// response, never opens authorization, and never persists exported credentials.
class TwitchWhisperSdkIntegrityProbe {
  Future<TwitchWhisperIntegrityContext> acquire(
    TwitchWhisperSession session,
  ) async {
    if (!kDebugMode || !Platform.isWindows) {
      throw const TwitchWhisperException('完整性 SDK 測試目前僅支援 Windows Debug。');
    }
    Webview? window;
    var closed = false;
    final watch = Stopwatch()..start();
    void log(String message) {
      debugPrint('[WhisperSDK][${watch.elapsedMilliseconds}ms] $message');
    }

    try {
      window = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: 'Twitch 完整性驗證測試',
          windowWidth: 800,
          windowHeight: 600,
          userDataFolderWindows:
              '${Directory.systemTemp.path}${Platform.pathSeparator}'
              'new_twitch_app_shared_twitch_desktop_webview_v30',
        ),
      );
      await window.setWebviewWindowVisibility(false);
      window.onClose.whenComplete(() => closed = true);
      window.addScriptToExecuteOnDocumentCreated('''
(() => {
  if (location.origin !== 'https://www.twitch.tv') return;
  window.__vioSdkProbe = {ready:false, started:false, result:null};
  document.addEventListener('kpsdk-ready', () => {
    window.__vioSdkProbe.ready = true;
  }, {once:true});
})();
''');
      window.launch('https://www.twitch.tv/');
      log('started existingProfile=true visible=false');
      var readyLogged = false;
      while (watch.elapsed < const Duration(seconds: 40)) {
        if (closed) {
          throw const TwitchWhisperException('SDK 測試環境已關閉，未修改既有對話。');
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
        dynamic value;
        try {
          value = await window.evaluateJavaScript('''
(() => {
  if (location.origin !== 'https://www.twitch.tv') return null;
  const state = window.__vioSdkProbe;
  if (!state) return null;
  if (state.ready && !state.started) {
    state.started = true;
    (async () => {
      try {
        // Use the existing official page device identity, never invent one.
        const cookie = document.cookie.split('; ').find(v => v.startsWith('unique_id='));
        const device = cookie ? decodeURIComponent(cookie.slice('unique_id='.length)) : '';
        if (device.length < 16 || device.length > 128 || /[^a-zA-Z0-9_-]/.test(device)) {
          state.result = {error:'device-unavailable'}; return;
        }
        const response = await window.fetch('https://gql.twitch.tv/integrity', {
          method:'POST', body:null, mode:'cors', credentials:'omit',
          headers:{'Client-ID':${jsonEncode(session.validation.clientId)},
            'Authorization':${jsonEncode('OAuth ${session.token}')},
            'x-device-id':device}
        });
        if (!response.ok) { state.result = {error:'integrity-http', status:response.status}; return; }
        const data = await response.json();
        state.result = {token:data.token, expiration:data.expiration,
          deviceId:device, userAgent:navigator.userAgent};
      } catch (_) { state.result = {error:'integrity-request'}; }
    })();
  }
  return JSON.stringify({ready:state.ready, started:state.started, result:state.result});
})();
''');
          for (var i = 0; i < 2 && value is String; i++) {
            value = jsonDecode(value);
          }
        } catch (_) {
          continue; // Navigation can invalidate the JS execution context.
        }
        if (value is! Map) continue;
        if (value['ready'] == true && !readyLogged) {
          readyLogged = true;
          log('officialSDK ready');
        }
        final result = value['result'];
        if (result is! Map) continue;
        if (result['error'] != null) {
          final category = result['error'];
          log('failed category=$category');
          throw const TwitchWhisperException('官方 SDK 未取得可用的完整性資料，原對話保持不變。');
        }
        final token = result['token'];
        final device = result['deviceId'];
        final ua = result['userAgent'];
        final expiry = result['expiration'];
        if (token is! String ||
            device is! String ||
            ua is! String ||
            expiry is! num) {
          throw const TwitchWhisperException('SDK 完整性回應格式無效，未發送列表請求。');
        }
        final context = TwitchWhisperIntegrityContext(
          ownerId: session.validation.userId,
          clientId: session.validation.clientId,
          token: token,
          deviceId: device,
          userAgent: ua,
          expiresAt: DateTime.fromMillisecondsSinceEpoch(
            expiry.toInt(),
            isUtc: true,
          ),
        );
        context.headersFor(session);
        log(
          'acquired tokenPresent=true devicePresent=true expirationFuture=true',
        );
        return context;
      }
      log('timeout sdkReady=$readyLogged');
      throw const TwitchWhisperException('官方完整性 SDK 測試逾時，未要求重新登入。');
    } finally {
      window?.close();
      log('closed temporary environment; next request uses directHTTP');
    }
  }
}
