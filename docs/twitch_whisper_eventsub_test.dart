// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/services/chat/twitch_whisper_eventsub_service.dart';

class _Api extends TwitchWhisperApiService {
  final subscriptions = <String>[];
  bool denied = false;
  _Api() : super(client: TwitchApiClient(), tokenProviders: const []);
  @override
  Future<TwitchWhisperSession> receiveSession(String ownerId) async {
    if (denied) throw const TwitchWhisperException('denied');
    return TwitchWhisperSession(
      'fake-token',
      TwitchTokenValidation(
        clientId: 'fake-client',
        login: 'owner',
        userId: ownerId,
        scopes: const ['user:read:whispers'],
        expiresIn: 1000,
      ),
    );
  }

  @override
  Future<void> subscribe(TwitchWhisperSession auth, String sessionId) async {
    subscriptions.add(sessionId);
  }
}

class _Socket implements WebSocketChannel {
  final events = StreamController<String>();
  late final _Sink output = _Sink(this);
  bool closed = false;
  @override
  Stream<String> get stream => events.stream;
  @override
  WebSocketSink get sink => output;
  @override
  Future<void> get ready async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  void emit(String type, Map<String, dynamic> payload) => events.add(
    jsonEncode({
      'metadata': {
        'message_type': type,
        'message_timestamp': '2026-10-03T12:00:00Z',
      },
      'payload': payload,
    }),
  );
  void welcome(String id) => emit('session_welcome', {
    'session': {'id': id, 'keepalive_timeout_seconds': 10},
  });
}

class _Sink implements WebSocketSink {
  final _Socket socket;
  _Sink(this.socket);
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    socket.closed = true;
    await socket.events.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Api api;
  late TwitchWhisperEventSubService service;
  late List<_Socket> sockets;
  late List<Uri> urls;
  late List<String> statuses;
  late List<Map<String, dynamic>> received;
  late List<String> gaps;
  setUp(() {
    api = _Api();
    sockets = [];
    urls = [];
    statuses = [];
    received = [];
    gaps = [];
    service = TwitchWhisperEventSubService(
      api: api,
      connector: (uri) {
        urls.add(uri);
        final socket = _Socket();
        sockets.add(socket);
        return socket;
      },
      onMessage: (event, _) => received.add(event),
      onStatus: statuses.add,
      onReceiveGap: gaps.add,
    );
  });
  tearDown(() async {
    service.stop();
    await _settle();
    api.client.close();
  });
  test('welcome subscribes once and receives only the current owner', () async {
    service.start('1');
    await _settle();
    sockets.single.welcome('session-1');
    await _settle();
    expect(api.subscriptions, ['session-1']);
    final event = {'to_user_id': '1', 'from_user_id': '2'};
    sockets.single.emit('notification', {
      'subscription': {
        'type': 'user.whisper.message',
        'condition': {'user_id': '1'},
      },
      'event': event,
    });
    sockets.single.emit('notification', {
      'subscription': {
        'type': 'user.whisper.message',
        'condition': {'user_id': '9'},
      },
      'event': event,
    });
    await _settle();
    expect(received, [event]);
    expect(gaps, isEmpty);
  });
  test(
    'server reconnect retains old socket until welcome and does not resubscribe',
    () async {
      service.start('1');
      await _settle();
      final old = sockets.single;
      old.welcome('first');
      await _settle();
      old.emit('session_reconnect', {
        'session': {
          'reconnect_url': 'wss://eventsub.wss.twitch.tv/ws?opaque=123',
        },
      });
      await _settle();
      expect(sockets.length, 2);
      expect(old.closed, false);
      expect(urls.last.query, 'opaque=123');
      sockets.last.welcome('second');
      await _settle();
      expect(old.closed, true);
      expect(api.subscriptions, ['first']);
      expect(gaps, isEmpty);
    },
  );
  test('revocation stops connection rather than retrying forever', () async {
    service.start('1');
    await _settle();
    sockets.single.welcome('first');
    await _settle();
    sockets.single.emit('revocation', {
      'subscription': {
        'type': 'user.whisper.message',
        'status': 'authorization_revoked',
      },
    });
    await _settle();
    expect(sockets.single.closed, true);
    expect(statuses.last, contains('撤銷'));
    expect(gaps, ['1']);
  });
  test(
    'missing scope never opens a socket and stop releases account socket',
    () async {
      api.denied = true;
      service.start('1');
      await _settle();
      expect(sockets, isEmpty);
      expect(statuses.last, contains('缺少授權'));
      expect(gaps, ['1']);
      api.denied = false;
      service.start('2');
      await _settle();
      service.stop();
      await _settle();
      expect(sockets.single.closed, true);
    },
  );
  testWidgets(
    'ordinary disconnect reconnects and subscribes to the new session',
    (tester) async {
      service.start('1');
      await tester.pump();
      final old = sockets.single;
      old.welcome('first');
      await tester.pump();
      await old.sink.close();
      await tester.pump(const Duration(seconds: 1));
      expect(sockets.length, 2);
      sockets.last.welcome('replacement');
      await tester.pump();
      expect(api.subscriptions, ['first', 'replacement']);
      expect(gaps, isNotEmpty);
      expect(gaps.every((owner) => owner == '1'), true);
      service.stop();
      await tester.pump();
    },
  );
  testWidgets('keepalive resets watchdog and idle connection is replaced', (
    tester,
  ) async {
    service.start('1');
    await tester.pump();
    final old = sockets.single;
    old.welcome('first');
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    old.emit('session_keepalive', {});
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    expect(old.closed, false);
    await tester.pump(const Duration(seconds: 3));
    expect(old.closed, true);
    await tester.pump(const Duration(seconds: 1));
    expect(sockets.length, 2);
    service.stop();
    await tester.pump();
  });
  testWidgets('failed handoff keeps old connection and later recovers fresh', (
    tester,
  ) async {
    service.start('1');
    await tester.pump();
    final old = sockets.single;
    old.welcome('first');
    await tester.pump();
    old.emit('session_reconnect', {
      'session': {
        'reconnect_url': 'wss://eventsub.wss.twitch.tv/ws?handoff=123',
      },
    });
    await tester.pump();
    final handoff = sockets.last;
    await handoff.sink.close();
    await tester.pump();
    expect(old.closed, false);
    expect(sockets.length, 2);
    await old.sink.close();
    await tester.pump(const Duration(seconds: 1));
    expect(sockets.length, 3);
    expect(urls.last.query, isEmpty);
    sockets.last.welcome('fresh');
    await tester.pump();
    expect(api.subscriptions, ['first', 'fresh']);
    service.stop();
    await tester.pump();
  });
}
