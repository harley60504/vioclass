// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import '../lib/features/twitch/services/chat/twitch_moderation_log_eventsub_service.dart';
import '../lib/features/twitch/models/chat/twitch_moderation_log_entry.dart';

class _Api extends TwitchModerationApiService {
  final sessions = <String>[];
  Completer<void>? pending;
  bool terminal = false;
  _Api(bool Function() allowed)
    : super(
        client: TwitchApiClient(),
        tokenProviders: const [],
        broadcasterId: '20',
        moderatorId: '10',
        canModerate: allowed,
      );
  @override
  Future<TwitchModerationSession> moderationLogSession() async {
    if (terminal) {
      throw const TwitchModerationException('缺少紀錄授權', terminal: true);
    }
    return TwitchModerationSession(
      'fake',
      TwitchTokenValidation(
        clientId: 'fake-client',
        userId: '10',
        login: 'mod',
        expiresIn: 1000,
        scopes: const [],
      ),
    );
  }

  @override
  Future<void> subscribeModerationLog(
    TwitchModerationSession auth,
    String sessionId,
  ) async {
    sessions.add(sessionId);
    await pending?.future;
  }
}

Map<String, dynamic> _subscription({
  String owner = '10',
  String version = '2',
}) => {
  'type': 'channel.moderate',
  'version': version,
  'condition': {'moderator_user_id': owner, 'broadcaster_user_id': '20'},
};

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
  void emit(
    String type,
    Map<String, dynamic> payload, {
    String id = 'event-1',
  }) => events.add(
    jsonEncode({
      'metadata': {
        'message_type': type,
        'message_id': id,
        'message_timestamp': '2026-10-03T12:00:00Z',
      },
      'payload': payload,
    }),
  );
  void welcome([String id = 'session-1']) => emit('session_welcome', {
    'session': {'id': id, 'keepalive_timeout_seconds': 10},
  });
  void event({
    String id = 'event-1',
    String owner = '10',
    String version = '2',
    String broadcaster = '20',
  }) => emit('notification', {
    'subscription': _subscription(owner: owner, version: version),
    'event': {
      'broadcaster_user_id': broadcaster,
      'moderator_user_id': 'other-mod',
      'action': 'clear',
    },
  }, id: id);
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

class _Harness {
  bool allowed = true;
  late final api = _Api(() => allowed);
  final sockets = <_Socket>[];
  final uris = <Uri>[];
  final events = <(String, Map<String, dynamic>, DateTime)>[];
  final statuses = <String>[];
  final entries = <TwitchModerationLogEntry>[];
  late final service = TwitchModerationLogEventSubService(
    api: api,
    onEvent: (id, event, time) => events.add((id, event, time)),
    onStatus: statuses.add,
    onEntry: entries.add,
    connector: (uri) {
      uris.add(uri);
      final socket = _Socket();
      sockets.add(socket);
      return socket;
    },
  );
  _Harness() {
    addTearDown(() {
      service.stop();
      api.client.close();
    });
  }
  Future<void> start(WidgetTester tester, {bool welcome = true}) async {
    service.start();
    await tester.pump();
    if (welcome && sockets.isNotEmpty) {
      sockets.last.welcome();
      await tester.pump();
      await tester.pump();
    }
  }
}

void main() {
  testWidgets(
    'Typed entries use filtered official events and deduplicate IDs',
    (tester) async {
      final h = _Harness();
      await h.start(tester);
      final socket = h.sockets.single;
      socket.event(id: 'valid');
      socket.event(id: 'valid');
      socket.event(id: 'wrong-channel', broadcaster: '30');
      socket.event(id: 'wrong-owner', owner: '30');
      socket.emit('notification', {
        'subscription': _subscription(),
        'event': {'broadcaster_user_id': '20', 'action': 'ban'},
      }, id: 'missing-actor');
      await tester.pump();
      expect(h.entries, hasLength(1));
      expect(h.entries.single.id, 'valid');
      expect(h.entries.single.moderatorId, 'other-mod');
      expect(h.entries.single.category, TwitchModerationLogCategory.room);
      h.service.stop();
    },
  );

  testWidgets(
    'failed handoff keeps old connection; loss during handoff resumes on new welcome',
    (tester) async {
      final h = _Harness();
      await h.start(tester);
      final old = h.sockets.single;
      void redirect() => old.emit('session_reconnect', {
        'session': {
          'reconnect_url': 'wss://eventsub.wss.twitch.tv/ws?handoff=1',
        },
      });
      redirect();
      await tester.pump();
      h.sockets.last.events.addError(StateError('fixture handoff failure'));
      await tester.pump();
      expect(old.closed, false);
      expect(h.service.connected, true);
      old.event(id: 'still-active');
      await tester.pump();
      expect(h.events.single.$1, 'still-active');
      redirect();
      await tester.pump();
      expect(h.sockets.length, 3);
      old.events.addError(StateError('fixture old connection lost'));
      await tester.pump();
      expect(h.service.connected, false);
      h.sockets.last.welcome('handoff');
      await tester.pump();
      expect(h.service.connected, true);
      expect(h.api.sessions, ['session-1']);
      h.service.stop();
    },
  );

  testWidgets(
    'consecutive unused sockets back off rather than rapid reconnect',
    (tester) async {
      final h = _Harness();
      await h.start(tester, welcome: false);
      h.sockets.last.events.addError(StateError('first failure'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(h.sockets.length, 2);
      h.sockets.last.events.addError(StateError('second failure'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(h.sockets.length, 2);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(h.sockets.length, 3);
      h.service.stop();
      await tester.pump(const Duration(seconds: 60));
      expect(h.sockets.length, 3);
    },
  );

  testWidgets(
    'v2 context filter, official actor, duplicate IDs and malformed frames',
    (tester) async {
      final h = _Harness();
      await h.start(tester);
      expect(h.service.connected, true);
      final s = h.sockets.single;
      s.events.add('not json');
      s.event(owner: '99');
      s.event(version: '1');
      s.event(broadcaster: '99');
      s.event();
      s.event();
      await tester.pump();
      expect(h.events.length, 1);
      expect(h.events.single.$1, 'event-1');
      expect(h.events.single.$2['moderator_user_id'], 'other-mod');
      expect(h.api.sessions, ['session-1']);
      h.service.stop();
    },
  );

  testWidgets(
    'welcome and subscription deadlines close stalled sockets then retry',
    (tester) async {
      final h = _Harness();
      await h.start(tester, welcome: false);
      await tester.pump(const Duration(seconds: 10));
      expect(h.sockets.first.closed, true);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(h.sockets.length, 2);
      h.api.pending = Completer<void>();
      h.sockets.last.welcome('pending');
      await tester.pump();
      expect(h.service.connected, false);
      await tester.pump(const Duration(seconds: 10));
      expect(h.sockets.last.closed, true);
      h.api.pending!.complete();
      await tester.pump();
      expect(h.service.connected, false);
      expect(h.statuses.last, contains('斷線期間'));
      h.service.stop();
    },
  );

  testWidgets(
    'keepalive resets watchdog; lost connection resubscribes without replay',
    (tester) async {
      final h = _Harness();
      await h.start(tester);
      await tester.pump(const Duration(seconds: 9));
      h.sockets.single.emit('session_keepalive', {});
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      expect(h.service.connected, true);
      await tester.pump(const Duration(seconds: 3));
      expect(h.service.connected, false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      h.sockets.last.welcome('session-2');
      await tester.pump();
      await tester.pump();
      expect(h.api.sessions, ['session-1', 'session-2']);
      expect(h.events, isEmpty);
      h.service.stop();
    },
  );

  testWidgets(
    'official handoff keeps old socket until welcome and deduplicates overlap',
    (tester) async {
      final h = _Harness();
      await h.start(tester);
      final old = h.sockets.single;
      old.event();
      old.emit('session_reconnect', {
        'session': {
          'reconnect_url': 'wss://eventsub.wss.twitch.tv/ws?token=fixture',
        },
      });
      await tester.pump();
      expect(h.sockets.length, 2);
      expect(old.closed, false);
      expect(
        h.uris.last.toString(),
        'wss://eventsub.wss.twitch.tv/ws?token=fixture',
      );
      old.event(id: 'during-handoff');
      await tester.pump();
      h.sockets.last.welcome('handoff');
      await tester.pump();
      expect(old.closed, true);
      h.sockets.last.event(id: 'during-handoff');
      await tester.pump();
      expect(h.events.map((event) => event.$1), ['event-1', 'during-handoff']);
      expect(h.api.sessions, ['session-1']);
      expect(h.service.connected, true);
      h.service.stop();
    },
  );

  testWidgets(
    'untrusted redirect is ignored; matching revocation is terminal',
    (tester) async {
      final h = _Harness();
      await h.start(tester);
      final s = h.sockets.single;
      for (final url in [
        'wss://evil.test/ws',
        'wss://user@eventsub.wss.twitch.tv/ws',
        'wss://eventsub.wss.twitch.tv:444/ws',
      ]) {
        s.emit('session_reconnect', {
          'session': {'reconnect_url': url},
        });
      }
      s.emit('revocation', {'subscription': _subscription(owner: '99')});
      await tester.pump();
      expect(h.sockets.length, 1);
      expect(h.service.connected, true);
      s.emit('revocation', {'subscription': _subscription()});
      await tester.pump();
      expect(h.service.connected, false);
      expect(s.closed, true);
      await tester.pump(const Duration(seconds: 60));
      expect(h.sockets.length, 1);
      expect(h.statuses.last, contains('已撤銷'));
    },
  );

  testWidgets(
    'permission loss and stop reject callbacks and pending subscription completion',
    (tester) async {
      final h = _Harness();
      await h.start(tester);
      h.allowed = false;
      h.sockets.single.event();
      await tester.pump();
      expect(h.events, isEmpty);
      expect(h.sockets.single.closed, true);
      h.allowed = true;
      h.api.pending = Completer<void>();
      await h.start(tester);
      h.service.stop();
      h.api.pending!.complete();
      await tester.pump();
      expect(h.service.connected, false);
      expect(h.sockets.last.closed, true);
    },
  );

  testWidgets('terminal missing scope does not open or retry sockets', (
    tester,
  ) async {
    final h = _Harness();
    h.api.terminal = true;
    await h.start(tester, welcome: false);
    await tester.pump(const Duration(seconds: 60));
    expect(h.sockets, isEmpty);
    expect(h.statuses.last, '缺少紀錄授權');
  });
}
