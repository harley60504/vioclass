import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../api/moderation/twitch_moderation_api_service.dart';
import '../../models/chat/twitch_moderation_log_entry.dart';

/// Receives official actions, not this app's submitted-action history.
class TwitchModerationLogEventSubService {
  final TwitchModerationApiService api;
  final WebSocketChannel Function(Uri) connect;
  final void Function(String id, Map<String, dynamic> event, DateTime time)
  onEvent;
  final void Function(String) onStatus;
  final void Function(TwitchModerationLogEntry)? onEntry;
  final _sockets = <WebSocketChannel>{};
  final _deadlines = <WebSocketChannel, Timer>{};
  final _seen = <String>{};
  WebSocketChannel? _active;
  WebSocketChannel? _handoff;
  Timer? _heartbeat;
  Timer? _retry;
  int _generation = 0;
  int _attempt = 0;
  int _keepalive = 30;
  bool _running = false;
  bool connected = false;

  TwitchModerationLogEventSubService({
    required this.api,
    required this.onEvent,
    required this.onStatus,
    this.onEntry,
    WebSocketChannel Function(Uri)? connector,
  }) : connect = connector ?? WebSocketChannel.connect;

  void start() {
    stop();
    _running = true;
    _attempt = 0;
    _seen.clear();
    unawaited(_open(_generation));
  }

  bool _current(int generation) => _running && generation == _generation;

  bool _allowed(int generation) {
    if (!_current(generation)) return false;
    if (api.canModerate?.call() == false) {
      _terminal(generation, '管理身分或頻道已變更，管理紀錄收件已停止。');
      return false;
    }
    return true;
  }

  Future<void> _open(int generation, {Uri? redirect}) async {
    if (!_allowed(generation)) return;
    if (redirect == null) onStatus('正在連接管理紀錄收件…');
    WebSocketChannel? socket;
    try {
      final auth = redirect == null ? await api.moderationLogSession() : null;
      if (!_allowed(generation)) return;
      final channel = connect(
        redirect ?? Uri.parse('wss://eventsub.wss.twitch.tv/ws'),
      );
      socket = channel;
      _sockets.add(channel);
      if (redirect == null) {
        _active = channel;
      } else {
        _handoff = channel;
      }
      var welcomed = false;
      _deadlines[channel] = Timer(
        const Duration(seconds: 10),
        () => _lost(channel, generation),
      );
      channel.stream.listen(
        (raw) async {
          if (!_sockets.contains(channel) || !_allowed(generation)) return;
          var type = '';
          try {
            final envelope = jsonDecode(raw as String) as Map;
            final metadata = envelope['metadata'] as Map;
            final payload = envelope['payload'] as Map;
            type = metadata['message_type']?.toString() ?? '';
            if (type == 'session_welcome') {
              if (welcomed) return;
              final session = payload['session'] as Map;
              final id = session['id'] as String;
              if (id.isEmpty) throw const FormatException('Empty session');
              final timeout = session['keepalive_timeout_seconds'];
              if (timeout != null &&
                  (timeout is! int || timeout < 10 || timeout > 600)) {
                throw const FormatException('Invalid keepalive');
              }
              welcomed = true;
              if (redirect == null) {
                // Keep the deadline armed while the subscription HTTP call is pending.
                await api.subscribeModerationLog(auth!, id);
                if (!_sockets.contains(channel) || !_allowed(generation)) {
                  return;
                }
              } else {
                final old = _active;
                _active = channel;
                _handoff = null;
                if (old != null && old != channel) _close(old);
              }
              _deadlines.remove(channel)?.cancel();
              _keepalive = timeout as int? ?? _keepalive;
              _attempt = 0;
              connected = true;
              _armHeartbeat(channel, generation);
              onStatus('管理紀錄收件已連線；僅包含連線後收到的事件。');
              return;
            }
            if (!welcomed) return;
            if (channel == _active && connected) {
              _armHeartbeat(channel, generation);
            }
            switch (type) {
              case 'notification':
                if (!_matches(payload['subscription'])) return;
                final event = Map<String, dynamic>.from(
                  payload['event'] as Map,
                );
                if (event['broadcaster_user_id'] != api.broadcasterId) return;
                final id = metadata['message_id'];
                final time = DateTime.tryParse(
                  metadata['message_timestamp']?.toString() ?? '',
                );
                if (id is! String ||
                    id.isEmpty ||
                    time == null ||
                    !_seen.add(id)) {
                  return;
                }
                if (_seen.length > 2000) _seen.remove(_seen.first);
                final entry = TwitchModerationLogEntry.parse(
                  id: id,
                  time: time,
                  expectedBroadcasterId: api.broadcasterId,
                  event: event,
                );
                if (entry != null) onEntry?.call(entry);
                onEvent(id, event, time);
              case 'session_reconnect':
                if (channel != _active || _handoff != null) return;
                final uri = Uri.parse(
                  (payload['session'] as Map)['reconnect_url'] as String,
                );
                if (uri.scheme != 'wss' ||
                    uri.host != 'eventsub.wss.twitch.tv' ||
                    uri.userInfo.isNotEmpty ||
                    (uri.hasPort && uri.port != 443) ||
                    uri.fragment.isNotEmpty) {
                  return;
                }
                unawaited(_open(generation, redirect: uri));
              case 'revocation':
                if (_matches(payload['subscription'])) {
                  _terminal(generation, '管理紀錄授權已撤銷，請確認授權後重新連線。');
                }
            }
          } on TwitchModerationException catch (error) {
            if (!_current(generation) || !_sockets.contains(channel)) return;
            if (error.terminal) {
              _terminal(generation, error.message);
            } else {
              _lost(channel, generation);
            }
          } catch (_) {
            // Invalid notification data is never manufactured into a log entry.
            if (type == 'session_welcome') _lost(channel, generation);
          }
        },
        onError: (Object _) => _lost(channel, generation),
        onDone: () => _lost(channel, generation),
      );
      await channel.ready;
    } on TwitchModerationException catch (error) {
      if (error.terminal) {
        _terminal(generation, error.message);
      } else if (socket != null) {
        _lost(socket, generation);
      } else {
        _scheduleRetry(generation);
      }
    } catch (_) {
      if (socket != null) {
        _lost(socket, generation);
      } else {
        _scheduleRetry(generation);
      }
    }
  }

  bool _matches(dynamic subscription) {
    if (subscription is! Map ||
        subscription['type'] != 'channel.moderate' ||
        subscription['version'] != '2') {
      return false;
    }
    final condition = subscription['condition'];
    return condition is Map &&
        condition['broadcaster_user_id'] == api.broadcasterId &&
        condition['moderator_user_id'] == api.moderatorId;
  }

  void _armHeartbeat(WebSocketChannel socket, int generation) {
    _heartbeat?.cancel();
    _heartbeat = Timer(
      Duration(seconds: _keepalive + 2),
      () => _lost(socket, generation),
    );
  }

  void _lost(WebSocketChannel socket, int generation) {
    if (!_current(generation) || !_sockets.contains(socket)) return;
    final active = socket == _active;
    _close(socket);
    if (active) {
      connected = false;
      _heartbeat?.cancel();
    }
    if (_active == null && _handoff == null) _scheduleRetry(generation);
  }

  void _scheduleRetry(int generation) {
    if (!_allowed(generation) || _retry?.isActive == true) return;
    connected = false;
    onStatus('管理紀錄已斷線，正在重試；斷線期間事件不會自動補回。');
    _retry = Timer(
      Duration(seconds: 1 << (_attempt++).clamp(0, 5)),
      () => unawaited(_open(generation)),
    );
  }

  void _close(WebSocketChannel socket) {
    _deadlines.remove(socket)?.cancel();
    _sockets.remove(socket);
    if (_active == socket) _active = null;
    if (_handoff == socket) _handoff = null;
    unawaited(socket.sink.close().catchError((Object _) {}));
  }

  void _terminal(int generation, String status) {
    if (!_current(generation)) return;
    stop();
    onStatus(status);
  }

  void stop() {
    ++_generation;
    _running = false;
    connected = false;
    _heartbeat?.cancel();
    _retry?.cancel();
    for (final socket in _sockets.toList()) {
      _close(socket);
    }
  }
}
