import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'twitch_whisper_integrity_browser.dart';

import '../../api/chat/twitch_whisper_api_service.dart';
import '../../api/chat/twitch_whisper_threads_api_service.dart';

/// The existing login browser supplies this independently encrypted cache.
/// Missing/expiring verification is refreshed with the existing cookie profile;
/// OAuth/Drops credentials and whisper content are never written by that browser.
class TwitchWhisperLoginIntegrityService {
  static final instance = TwitchWhisperLoginIntegrityService(
    browser: withTwitchWhisperIntegrityBrowser,
  );
  static const storageKey = 'vioclass_whisper_integrity_context_v1';
  final FlutterSecureStorage storage;
  final Future<void> Function({
    required String documentStartScript,
    required Future<void> Function(Future<dynamic> Function(String)) capture,
  })?
  browser;
  Future<TwitchWhisperIntegrityContext>? _pending;
  String? _pendingKey;
  TwitchWhisperLoginIntegrityService({
    this.storage = const FlutterSecureStorage(),
    this.browser,
  });
  Future<void> _storageQueue = Future<void>.value();
  Future<void> _enqueue(Future<void> Function() operation) {
    final pending = _storageQueue.then((_) => operation());
    _storageQueue = pending.catchError((Object _) {});
    return pending;
  }

  TwitchWhisperIntegrityContext? _context;
  String? _sessionToken;
  int _generation = 0;

  bool hasValidContextFor(String? token) =>
      token != null &&
      token == _sessionToken &&
      _context != null &&
      _context!.expiresAt.isAfter(DateTime.now().toUtc());

  static const documentStartScript = r'''
(() => {
  if (location.origin !== 'https://www.twitch.tv') return;
  window.__vioLoginIntegrity = {ready:false, started:false, result:null};
  const ready = () => { window.__vioLoginIntegrity.ready = true; };
  document.addEventListener('kpsdk-ready', ready, true);
  window.addEventListener('kpsdk-ready', ready, true);
})();
''';

  void clear() {
    ++_generation;
    _context = null;
    _sessionToken = null;
    unawaited(
      _enqueue(() => storage.delete(key: storageKey)).catchError((Object _) {}),
    );
  }

  Future<TwitchWhisperIntegrityContext> forSession(
    TwitchWhisperSession session,
  ) {
    final key =
        '${session.validation.userId}:${session.validation.clientId}:${session.token}';
    if (_pending != null && _pendingKey == key) return _pending!;
    if (_pending != null) {
      return Future.error(
        const TwitchWhisperException('私訊驗證工作階段正在變更，未混用其他帳號資料。'),
      );
    }
    _pendingKey = key;
    final pending = _prepareSession(session);
    _pending = pending;
    unawaited(
      pending.then(
        (_) {
          if (identical(_pending, pending)) {
            _pending = null;
            _pendingKey = null;
          }
        },
        onError: (Object _) {
          if (identical(_pending, pending)) {
            _pending = null;
            _pendingKey = null;
          }
        },
      ),
    );
    return pending;
  }

  Future<TwitchWhisperIntegrityContext> _prepareSession(
    TwitchWhisperSession session,
  ) async {
    final generation = _generation;
    if (_context == null || _sessionToken != session.token) {
      try {
        final raw = await _enqueueRead();
        if (generation != _generation) {
          throw const TwitchWhisperException('私訊登入工作階段已變更，未恢復舊驗證。');
        }
        if (raw != null) {
          final data = jsonDecode(raw) as Map;
          if (data['sessionToken'] == session.token) {
            final restored = TwitchWhisperIntegrityContext(
              ownerId: data['ownerId'] as String,
              clientId: data['clientId'] as String,
              token: data['integrity'] as String,
              deviceId: data['deviceId'] as String,
              userAgent: data['userAgent'] as String,
              expiresAt: DateTime.fromMillisecondsSinceEpoch(
                data['expiresAt'] as int,
                isUtc: true,
              ),
            );
            if (restored.expiresAt.isAfter(DateTime.now().toUtc()) &&
                restored.ownerId == session.validation.userId &&
                restored.clientId == session.validation.clientId) {
              restored.headersFor(session);
              _context = restored;
              _sessionToken = session.token;
            }
          }
        }
      } on TwitchWhisperException {
        rethrow;
      } catch (_) {
        if (browser == null) {
          throw const TwitchWhisperException('私訊驗證快取無法讀取或格式無效；登入與聊天紀錄未變更。');
        }
        // A damaged cache is not a damaged OAuth login. Acquire fresh proof.
        if (generation != _generation) {
          throw const TwitchWhisperException('登入已變更，未更新舊的私訊驗證。');
        }
      }
    }
    var context = _context;
    final renew = browser;
    if (renew != null &&
        (context == null ||
            _sessionToken != session.token ||
            !context.expiresAt.isAfter(
              DateTime.now().toUtc().add(const Duration(seconds: 30)),
            ))) {
      final before = _generation;
      try {
        await renew(
          documentStartScript: documentStartScript,
          capture: (evaluate) async {
            if (before != _generation) {
              throw const TwitchWhisperException('登入已變更，未更新舊的私訊驗證。');
            }
            await captureFromLogin(
              session: session,
              evaluate: evaluate,
              stillCurrent: () => _generation == before + 1,
            );
          },
        );
      } on TwitchWhisperException {
        rethrow;
      } catch (_) {
        throw const TwitchWhisperException('背景私訊驗證未完成；登入及既有紀錄保留，稍後可重試。');
      }
      context = _context;
    }
    if (context == null || _sessionToken != session.token) {
      throw const TwitchWhisperException(
        '目前登入尚無可用的私訊驗證資料；需在既有登入視窗完成驗證，重試歷史不會補回驗證。',
      );
    }
    context.headersFor(session);
    return context;
  }

  Future<Map<String, String>> headersFor(TwitchWhisperSession session) async =>
      (await forSession(session)).headersFor(session);

  Future<void> invalidateRejected(
    TwitchWhisperSession session,
    String rejectedIntegrity,
  ) async {
    // A late response must not discard proof already renewed by another request.
    if (_sessionToken != session.token ||
        _context?.token != rejectedIntegrity ||
        _context?.ownerId != session.validation.userId)
      return;
    final generation = ++_generation;
    _context = null;
    _sessionToken = null;
    await _enqueue(() async {
      if (generation == _generation) await storage.delete(key: storageKey);
    });
  }

  Future<String?> _enqueueRead() async {
    String? value;
    await _enqueue(() async {
      value = await storage.read(key: storageKey);
    });
    return value;
  }

  Future<void> captureFromLogin({
    required TwitchWhisperSession session,
    required Future<dynamic> Function(String script) evaluate,
    required bool Function() stillCurrent,
    Duration timeout = const Duration(seconds: 40),
    Duration pollInterval = const Duration(milliseconds: 500),
  }) async {
    final generation = ++_generation;
    final watch = Stopwatch()..start();
    while (watch.elapsed < timeout) {
      if (generation != _generation || !stillCurrent()) {
        throw const TwitchWhisperException('登入工作階段已變更，未保存舊的私訊驗證資料。');
      }
      dynamic value;
      try {
        value = await evaluate('''
(() => {
  if (location.origin !== 'https://www.twitch.tv') return null;
  const state = window.__vioLoginIntegrity;
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
          headers:{'Client-ID':${jsonEncode(session.validation.clientId)},
            'Authorization':${jsonEncode('OAuth ${session.token}')}, 'x-device-id':device}
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
          final category = value['error'];
          final status = value['status'] is num
              ? ' HTTP ${value['status']}'
              : '';
          throw TwitchWhisperException(
            '登入完成，但私訊驗證取得失敗（$category$status）；登入資料仍保留。',
          );
        }
        final token = value['token'];
        final device = value['deviceId'];
        final ua = value['userAgent'];
        final expiry = value['expiration'];
        if (token is! String ||
            device is! String ||
            ua is! String ||
            expiry is! num) {
          throw const TwitchWhisperException('登入視窗的私訊驗證回應格式無效。');
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
        if (generation != _generation || !stillCurrent()) {
          throw const TwitchWhisperException('登入工作階段已變更，未保存舊的私訊驗證資料。');
        }
        _context = context;
        _sessionToken = session.token;
        await _enqueue(() async {
          if (generation != _generation || !stillCurrent()) return;
          await storage.write(
            key: storageKey,
            value: jsonEncode({
              'sessionToken': session.token,
              'ownerId': context.ownerId,
              'clientId': context.clientId,
              'integrity': context.token,
              'deviceId': context.deviceId,
              'userAgent': context.userAgent,
              'expiresAt': context.expiresAt.millisecondsSinceEpoch,
            }),
          );
        });
        if (generation != _generation || !stillCurrent()) {
          throw const TwitchWhisperException('登入工作階段已變更，未使用舊的私訊驗證資料。');
        }
        return;
      }
      await Future<void>.delayed(pollInterval);
    }
    throw const TwitchWhisperException('登入完成，但私訊驗證準備逾時；同步不會另開 WebView。');
  }
}
