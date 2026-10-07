import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../api/moderation/twitch_moderation_api_service.dart';
import '../../api/core/twitch_api_exception.dart';

/// Channel-owned moderation receiver. Never sends IRC/chat traffic over this socket.
class TwitchAutomodEventSubService {
  final TwitchModerationApiService api;
  final WebSocketChannel Function(Uri uri) connect;
  final void Function(
    String type,
    Map<String, dynamic> event,
    DateTime timestamp,
  )
  onMessage;
  final void Function(String status) onStatus;
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
  bool connected = false;

  TwitchAutomodEventSubService({
    required this.api,
    required this.onMessage,
    required this.onStatus,
    WebSocketChannel Function(Uri uri)? connector,
  }) : connect = connector ?? WebSocketChannel.connect;

  void start() {
    stop();
    _owner = api.moderatorId;
    _revoked = false;
    _attempt = 0;
    unawaited(_open(_generation));
  }

  bool _current(int generation) =>
      generation == _generation && _owner != null && !_revoked;

  Future<void> _open(int generation, {Uri? redirect}) async {
    if (!_current(generation)) return;
    onStatus('正在連接AutoMod 待審收件…');
    WebSocketChannel? channel;
    try {
      // Obtain authorization before welcome: Twitch allows only 10 seconds
      // after welcome to create a subscription on a fresh connection.
      final auth = redirect == null ? await api.automodSession() : null;
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
          if (api.canModerate?.call() == false) {
            _terminal(generation, '管理身分或頻道已變更，AutoMod 收件已停止。');
            return;
          }
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
                  await api.subscribeAutomod(auth!, id);
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
                connected = true;
                onStatus('AutoMod 待審收件已連線');
              case 'session_keepalive':
                if (socket == _active) _armWatchdog(socket, generation);
              case 'notification':
                if (socket == _active) _armWatchdog(socket, generation);
                final subscription = payload['subscription'] as Map;
                final eventType = subscription['type'];
                final condition = subscription['condition'] as Map;
                if (!const {
                      'automod.message.hold',
                      'automod.message.update',
                    }.contains(eventType) ||
                    subscription['version'] != '2' ||
                    condition['moderator_user_id'] != _owner ||
                    condition['broadcaster_user_id'] != api.broadcasterId) {
                  return;
                }
                final event = Map<String, dynamic>.from(
                  payload['event'] as Map,
                );
                if (event['broadcaster_user_id'] != api.broadcasterId) return;
                final timestamp = DateTime.tryParse(
                  metadata['message_timestamp']?.toString() ?? '',
                );
                if (timestamp != null) {
                  onMessage(eventType as String, event, timestamp);
                }
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
                if (!const {
                  'automod.message.hold',
                  'automod.message.update',
                }.contains(subscription['type'])) {
                  return;
                }
                final condition = subscription['condition'];
                if (condition is! Map ||
                    condition['moderator_user_id'] != _owner ||
                    condition['broadcaster_user_id'] != api.broadcasterId) {
                  return;
                }
                connected = false;
                _revoked = true;
                _watchdog?.cancel();
                _retry?.cancel();
                for (final socket in _channels.toList()) {
                  _close(socket);
                }
                onStatus('AutoMod 待審收件授權已撤銷，請重新登入後再連線。');
            }
          } on TwitchModerationException catch (error) {
            if (error.terminal) {
              _terminal(generation, error.message);
            } else {
              _lost(socket, generation);
            }
          } on TwitchApiException catch (error) {
            if (error.statusCode == 401 || error.statusCode == 403) {
              _terminal(generation, 'AutoMod 待審收件缺少授權，請重新登入後再連線。');
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
    } on TwitchModerationException catch (error) {
      _terminal(generation, error.message);
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
    connected = false;
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
      connected = false;
      _watchdog?.cancel();
      if (_handoff == null) _scheduleRetry(generation);
    } else if (isHandoff) {
      if (_active == null) {
        _scheduleRetry(generation);
      } else {
        _armWatchdog(_active!, generation);
      }
    }
  }

  void _scheduleRetry(int generation) {
    if (!_current(generation) || _retry?.isActive == true) return;
    if (api.canModerate?.call() == false) {
      _terminal(generation, '管理身分或頻道已變更，AutoMod 收件已停止。');
      return;
    }
    connected = false;
    onStatus('AutoMod 待審收件已斷線，正在重試；斷線期間訊息不會自動補回。');
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
    connected = false;
    _owner = null;
    _watchdog?.cancel();
    _retry?.cancel();
    for (final socket in _channels.toList()) {
      _close(socket);
    }
  }
}
