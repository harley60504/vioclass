import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../api/chat/twitch_whisper_api_service.dart';
import '../../api/core/twitch_api_exception.dart';

/// App-owned receiving connection. Never sends chat traffic over this socket.
class TwitchWhisperEventSubService {
  final TwitchWhisperApiService api;
  final WebSocketChannel Function(Uri uri) connect;
  final void Function(Map<String, dynamic> event, DateTime timestamp) onMessage;
  final void Function(String status) onStatus;
  final void Function(String owner)? onReceiveGap;
  final Set<WebSocketChannel> _channels = {};
  final Map<WebSocketChannel, Timer> _welcomeTimers = {};
  WebSocketChannel? _active;
  WebSocketChannel? _handoff;
  Timer? _watchdog;
  Timer? _retry;
  String? _owner;
  int _generation = 0;
  int _attempt = 0;
  int _keepaliveSeconds = 30;
  bool _revoked = false;

  TwitchWhisperEventSubService({
    required this.api,
    required this.onMessage,
    required this.onStatus,
    this.onReceiveGap,
    WebSocketChannel Function(Uri uri)? connector,
  }) : connect = connector ?? WebSocketChannel.connect;

  void start(String owner) {
    stop();
    _owner = owner;
    _revoked = false;
    _attempt = 0;
    unawaited(_open(_generation));
  }

  bool _current(int generation) =>
      generation == _generation && _owner != null && !_revoked;

  Future<void> _open(int generation, {Uri? redirect}) async {
    if (!_current(generation)) return;
    onStatus('正在連接私訊收件…');
    WebSocketChannel? channel;
    try {
      // Obtain authorization before welcome: Twitch allows only 10 seconds
      // after welcome to create a subscription on a fresh connection.
      final auth = redirect == null ? await api.receiveSession(_owner!) : null;
      if (!_current(generation)) return;
      channel = connect(
        redirect ?? Uri.parse('wss://eventsub.wss.twitch.tv/ws'),
      );
      final socket = channel;
      _channels.add(socket);
      if (redirect != null) {
        _handoff = socket;
      } else {
        _active = socket;
      }
      var welcomed = false;
      final welcomeTimeout = Timer(const Duration(seconds: 10), () {
        if (_current(generation) && !welcomed) _lost(socket, generation);
      });
      _welcomeTimers[socket] = welcomeTimeout;
      socket.stream.listen(
        (raw) async {
          if (!_current(generation) || !_channels.contains(socket)) return;
          var type = '';
          try {
            final json = jsonDecode(raw as String) as Map<String, dynamic>;
            final metadata = json['metadata'] as Map;
            final payload = json['payload'] as Map;
            type = metadata['message_type']?.toString() ?? '';
            switch (type) {
              case 'session_welcome':
                if (welcomed) return;
                welcomed = true;
                welcomeTimeout.cancel();
                _welcomeTimers.remove(socket);
                final session = payload['session'] as Map;
                final id = session['id'] as String;
                _keepaliveSeconds =
                    (session['keepalive_timeout_seconds'] as num?)?.toInt() ??
                    30;
                _armWatchdog(socket, generation);
                if (redirect == null) {
                  await api.subscribe(auth!, id);
                  if (!_current(generation) || !_channels.contains(socket)) {
                    return;
                  }
                } else {
                  final old = _active;
                  _active = socket;
                  _handoff = null;
                  if (old != null && old != socket) _close(old);
                }
                _attempt = 0;
                _armWatchdog(socket, generation);
                onStatus('私訊收件已連線');
              case 'session_keepalive':
                if (socket == _active) _armWatchdog(socket, generation);
              case 'notification':
                if (socket == _active) _armWatchdog(socket, generation);
                final subscription = payload['subscription'] as Map;
                if (subscription['type'] != 'user.whisper.message' ||
                    (subscription['condition'] as Map)['user_id'] != _owner) {
                  return;
                }
                final event = Map<String, dynamic>.from(
                  payload['event'] as Map,
                );
                if (event['to_user_id'] != _owner) return;
                final timestamp = DateTime.tryParse(
                  metadata['message_timestamp']?.toString() ?? '',
                );
                if (timestamp != null) onMessage(event, timestamp);
              case 'session_reconnect':
                if (_handoff != null) return;
                final uri = Uri.parse(
                  (payload['session'] as Map)['reconnect_url'] as String,
                );
                if (uri.scheme != 'wss' ||
                    uri.host != 'eventsub.wss.twitch.tv') {
                  throw const FormatException('Unexpected EventSub host');
                }
                unawaited(_open(generation, redirect: uri));
              case 'revocation':
                final subscription = payload['subscription'] as Map;
                if (subscription['type'] != 'user.whisper.message') return;
                _revoked = true;
                onReceiveGap?.call(_owner!);
                _watchdog?.cancel();
                _retry?.cancel();
                for (final socket in _channels.toList()) {
                  _close(socket);
                }
                onStatus('私訊收件授權已撤銷，請重新登入後再連線。');
            }
          } on TwitchWhisperException {
            _terminal(generation, '私訊收件缺少授權，請重新登入後再連線。');
          } on TwitchApiException catch (error) {
            if (error.statusCode == 401 || error.statusCode == 403) {
              _terminal(generation, '私訊收件缺少授權，請重新登入後再連線。');
            } else {
              _lost(socket, generation);
            }
          } catch (_) {
            // Malformed events are ignored, not turned into fake messages.
            if (!welcomed || type == 'session_welcome') {
              _lost(socket, generation);
            }
          }
        },
        onError: (Object _) {
          welcomeTimeout.cancel();
          _lost(socket, generation);
        },
        onDone: () {
          welcomeTimeout.cancel();
          _lost(socket, generation);
        },
      );
      await socket.ready;
    } on TwitchWhisperException {
      _terminal(generation, '私訊收件缺少授權，請重新登入後再連線。');
    } catch (_) {
      if (channel != null) {
        _lost(channel, generation);
      } else {
        _scheduleRetry(generation);
      }
    }
  }

  void _terminal(int generation, String status) {
    if (!_current(generation)) return;
    _revoked = true;
    onReceiveGap?.call(_owner!);
    _watchdog?.cancel();
    _retry?.cancel();
    for (final socket in _channels.toList()) {
      _close(socket);
    }
    onStatus(status);
  }

  void _armWatchdog(WebSocketChannel socket, int generation) {
    _watchdog?.cancel();
    _watchdog = Timer(Duration(seconds: _keepaliveSeconds + 2), () {
      _lost(socket, generation);
    });
  }

  void _lost(WebSocketChannel socket, int generation) {
    if (!_current(generation) || !_channels.contains(socket)) return;
    final isActive = socket == _active;
    final isHandoff = socket == _handoff;
    _close(socket);
    if (isActive) {
      onReceiveGap?.call(_owner!);
      _watchdog?.cancel();
      if (_handoff == null) _scheduleRetry(generation);
    } else if (isHandoff && _active == null) {
      _scheduleRetry(generation);
    }
  }

  void _scheduleRetry(int generation) {
    if (!_current(generation) || _retry?.isActive == true) return;
    onReceiveGap?.call(_owner!);
    onStatus('私訊收件已斷線，正在重試；斷線期間訊息不會自動補回。');
    final delay = Duration(seconds: 1 << (_attempt++).clamp(0, 5));
    _retry = Timer(delay, () => unawaited(_open(generation)));
  }

  void _close(WebSocketChannel socket) {
    _welcomeTimers.remove(socket)?.cancel();
    _channels.remove(socket);
    if (_active == socket) _active = null;
    if (_handoff == socket) _handoff = null;
    unawaited(socket.sink.close().catchError((Object _) {}));
  }

  void stop() {
    ++_generation;
    _owner = null;
    _watchdog?.cancel();
    _retry?.cancel();
    for (final socket in _channels.toList()) {
      _close(socket);
    }
  }
}
