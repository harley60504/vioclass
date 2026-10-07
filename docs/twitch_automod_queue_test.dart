// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_automod_queue.dart';
import '../lib/features/twitch/models/emotes/twitch_cheermote_catalog.dart';
import '../lib/features/twitch/presentation/widgets/chat/twitch_automod_queue_strip.dart';
import '../lib/features/twitch/services/chat/twitch_automod_eventsub_service.dart';

Map<String, dynamic> _held([String id = 'held-1']) => {
  'broadcaster_user_id': '20',
  'user_id': '30',
  'user_name': 'Chatter',
  'message_id': id,
  'message': {'text': '待審內容'},
  'held_at': '2026-10-03T12:00:00Z',
  'reason': 'automod',
  'automod': {'category': 'aggressive', 'level': 2},
};

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String owner = '10';
  List<String> scopes = ['moderator:manage:automod'];
  int status = 204;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path.endsWith('/validate')) {
      return ResponseBody.fromString(
        jsonEncode({
          'user_id': owner,
          'client_id': 'validated-client',
          'login': 'mod',
          'expires_in': 1000,
          'scopes': scopes,
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      options.uri.path.endsWith('/subscriptions') ? 202 : status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Api extends TwitchModerationApiService {
  final subscriptions = <String>[];
  final actions = <(String, bool)>[];
  bool denied = false;
  Completer<void>? write;
  Completer<TwitchCheermoteCatalog>? cheerWrite;
  int cheerLoads = 0;
  bool cheerFail = false;
  _Api({
    bool Function()? permission,
    String broadcaster = '20',
    String moderator = '10',
  }) : super(
         client: TwitchApiClient(),
         tokenProviders: const [],
         broadcasterId: broadcaster,
         moderatorId: moderator,
         canModerate: permission,
       );
  @override
  Future<TwitchModerationSession> automodSession() async {
    if (denied) throw const TwitchModerationException('缺少授權');
    return TwitchModerationSession(
      'fake',
      TwitchTokenValidation(
        clientId: 'fake-client',
        userId: moderatorId,
        login: 'mod',
        expiresIn: 1000,
        scopes: const ['moderator:manage:automod'],
      ),
    );
  }

  @override
  Future<void> subscribeAutomod(
    TwitchModerationSession auth,
    String sessionId,
  ) async {
    subscriptions.add(sessionId);
  }

  @override
  Future<TwitchCheermoteCatalog> automodCheermotes() async {
    cheerLoads++;
    if (cheerFail) throw StateError('fixture read failure');
    return await cheerWrite?.future ?? const TwitchCheermoteCatalog.empty();
  }

  @override
  Future<void> resolveAutomod(String messageId, {required bool allow}) async {
    actions.add((messageId, allow));
    await write?.future;
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
  void welcome() => emit('session_welcome', {
    'session': {'id': 'session-1', 'keepalive_timeout_seconds': 30},
  });
  void message(
    String type,
    Map<String, dynamic> event, {
    String owner = '10',
    String broadcaster = '20',
    String version = '2',
  }) => emit('notification', {
    'subscription': {
      'type': type,
      'version': version,
      'condition': {
        'broadcaster_user_id': broadcaster,
        'moderator_user_id': owner,
      },
    },
    'event': event,
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
  test(
    'official resolve body has selected moderator and no unrelated channel query',
    () async {
      final adapter = _Adapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = TwitchApiClient(dio: dio);
      final api = TwitchModerationApiService(
        client: client,
        tokenProviders: [() async => 'fake'],
        broadcasterId: '20',
        moderatorId: '10',
      );
      await api.resolveAutomod('held-1', allow: true);
      await api.resolveAutomod('held-2', allow: false);
      expect(adapter.requests.map((r) => r.method), ['POST', 'POST']);
      expect(
        adapter.requests.first.uri.path,
        '/helix/moderation/automod/message',
      );
      expect(adapter.requests.first.queryParameters, isEmpty);
      expect(adapter.requests.first.data, {
        'user_id': '10',
        'msg_id': 'held-1',
        'action': 'ALLOW',
      });
      expect(adapter.requests.last.data['action'], 'DENY');
      expect(adapter.requests.first.headers['Client-ID'], 'validated-client');
      client.close();
    },
  );
  test(
    'missing scope, wrong owner and lost permission never manage messages',
    () async {
      final adapter = _Adapter();
      final client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
      var permitted = true;
      final api = TwitchModerationApiService(
        client: client,
        tokenProviders: [() async => 'fake'],
        broadcasterId: '20',
        moderatorId: '10',
        canModerate: () => permitted,
      );
      adapter.owner = '99';
      await expectLater(
        api.resolveAutomod('held', allow: true),
        throwsA(isA<TwitchModerationException>()),
      );
      adapter.owner = '10';
      adapter.scopes = [];
      await expectLater(
        api.automodSession(),
        throwsA(isA<TwitchModerationException>()),
      );
      permitted = false;
      await expectLater(
        api.resolveAutomod('held', allow: true),
        throwsA(isA<TwitchModerationException>()),
      );
      await expectLater(
        api.resolveAutomod(' ', allow: false),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests, isEmpty);
      client.close();
    },
  );
  test(
    'both v2 subscriptions use prevalidated token and exact channel/owner conditions',
    () async {
      final adapter = _Adapter();
      final client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
      final api = TwitchModerationApiService(
        client: client,
        tokenProviders: [() async => 'fake'],
        broadcasterId: '20',
        moderatorId: '10',
      );
      final auth = await api.automodSession();
      await api.subscribeAutomod(auth, 'session-1');
      expect(adapter.requests.map((r) => r.data['type']), [
        'automod.message.hold',
        'automod.message.update',
      ]);
      for (final r in adapter.requests) {
        expect(r.queryParameters, isEmpty);
        expect(r.data['version'], '2');
        expect(r.data['condition'], {
          'broadcaster_user_id': '20',
          'moderator_user_id': '10',
        });
        expect(r.data['transport'], {
          'method': 'websocket',
          'session_id': 'session-1',
        });
        expect(r.headers['Client-ID'], 'validated-client');
      }
      adapter.status = 404;
      await expectLater(
        api.resolveAutomod('expired', allow: true),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests.length, 3);
      client.close();
    },
  );
  test(
    'queue deduplicates, isolates channel and accepts updates from another MOD',
    () {
      final queue = TwitchAutomodQueue('20');
      expect(queue.apply('automod.message.hold', _held()), true);
      expect(queue.apply('automod.message.hold', _held()), false);
      expect(
        queue.apply('automod.message.hold', {
          ..._held('foreign'),
          'broadcaster_user_id': '99',
        }),
        false,
      );
      expect(queue.messages.single.reason, contains('等級 2'));
      expect(
        queue.apply('automod.message.update', {
          ..._held(),
          'status': 'approved',
          'moderator_user_id': 'another-mod',
        }),
        true,
      );
      expect(queue.messages, isEmpty);
      expect(queue.apply('automod.message.hold', _held()), false);
    },
  );
  test(
    'out-of-order resolution tombstones prevent resurrection; unknown/malformed ignored',
    () {
      final queue = TwitchAutomodQueue('20');
      queue.apply('automod.message.update', {..._held(), 'status': 'expired'});
      expect(queue.apply('automod.message.hold', _held()), false);
      queue.apply('automod.message.update', {
        ..._held('new'),
        'status': 'unrecognized',
      });
      expect(
        queue.apply('automod.message.hold', {
          ..._held('new'),
          'message': 'v1 incompatible',
        }),
        false,
      );
      expect(
        queue.apply('automod.message.hold', {
          ..._held('new'),
          'reason': 'blocked_term',
        }),
        true,
      );
      expect(queue.messages.single.reason, '封鎖詞');
      queue.clear();
      expect(queue.messages, isEmpty);
    },
  );
  test('socket filters type/version/context but not actor of update', () async {
    final api = _Api();
    final socket = _Socket();
    final received = <String>[];
    final service = TwitchAutomodEventSubService(
      api: api,
      connector: (_) => socket,
      onMessage: (type, event, _) => received.add(type),
      onStatus: (_) {},
    );
    service.start();
    await _settle();
    socket.welcome();
    await _settle();
    expect(service.connected, true);
    socket.message('automod.message.hold', _held());
    socket.message('automod.message.hold', _held(), owner: 'other');
    socket.message('automod.message.hold', _held(), version: '1');
    socket.message('automod.message.hold', _held(), broadcaster: '99');
    socket.message('automod.message.update', {
      ..._held(),
      'moderator_user_id': 'other',
      'status': 'denied',
    });
    await _settle();
    expect(received, ['automod.message.hold', 'automod.message.update']);
    service.stop();
    await _settle();
    api.client.close();
  });
  test(
    'socket handoff retains queue connection and avoids duplicate subscriptions',
    () async {
      final api = _Api();
      final sockets = <_Socket>[];
      final service = TwitchAutomodEventSubService(
        api: api,
        connector: (_) {
          final socket = _Socket();
          sockets.add(socket);
          return socket;
        },
        onMessage: (_, event, time) {},
        onStatus: (_) {},
      );
      service.start();
      await _settle();
      final old = sockets.single;
      old.welcome();
      await _settle();
      old.emit('session_reconnect', {
        'session': {
          'reconnect_url': 'wss://eventsub.wss.twitch.tv/ws?opaque=123',
        },
      });
      await _settle();
      expect(old.closed, false);
      sockets.last.welcome();
      await _settle();
      expect(old.closed, true);
      expect(api.subscriptions, ['session-1']);
      expect(service.connected, true);
      service.stop();
      await _settle();
      api.client.close();
    },
  );
  test(
    'role loss and matching revocation stop receiving, foreign revocation ignored',
    () async {
      var permitted = true;
      final api = _Api(permission: () => permitted);
      final sockets = <_Socket>[];
      final statuses = <String>[];
      final service = TwitchAutomodEventSubService(
        api: api,
        connector: (_) {
          final socket = _Socket();
          sockets.add(socket);
          return socket;
        },
        onMessage: (_, event, time) {},
        onStatus: statuses.add,
      );
      service.start();
      await _settle();
      sockets.last.welcome();
      await _settle();
      sockets.last.emit('revocation', {
        'subscription': {
          'type': 'automod.message.hold',
          'condition': {'broadcaster_user_id': '99', 'moderator_user_id': '10'},
        },
      });
      await _settle();
      expect(service.connected, true);
      permitted = false;
      sockets.last.emit('session_keepalive', {});
      await _settle();
      expect(service.connected, false);
      expect(sockets.last.closed, true);
      permitted = true;
      service.start();
      await _settle();
      sockets.last.welcome();
      await _settle();
      sockets.last.emit('revocation', {
        'subscription': {
          'type': 'automod.message.update',
          'condition': {'broadcaster_user_id': '20', 'moderator_user_id': '10'},
        },
      });
      await _settle();
      expect(service.connected, false);
      expect(statuses.last, contains('撤銷'));
      service.stop();
      await _settle();
      api.client.close();
    },
  );
  test('missing scope opens no socket', () async {
    final api = _Api()..denied = true;
    var sockets = 0;
    final service = TwitchAutomodEventSubService(
      api: api,
      connector: (_) {
        sockets++;
        return _Socket();
      },
      onMessage: (_, event, time) {},
      onStatus: (_) {},
    );
    service.start();
    await _settle();
    expect(sockets, 0);
    expect(service.connected, false);
    service.stop();
    api.client.close();
  });

  Future<(_Api, List<_Socket>)> mount(
    WidgetTester tester, {
    Size size = const Size(320, 640),
    double maxHeight = 170,
    String broadcaster = '20',
    String moderator = '10',
  }) async {
    final api = _Api(broadcaster: broadcaster, moderator: moderator);
    final sockets = <_Socket>[];
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      api.client.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: const TextScaler.linear(1.5),
            viewInsets: const EdgeInsets.only(bottom: 250),
          ),
          child: Scaffold(
            body: Column(
              children: [
                TwitchAutomodQueueStrip(
                  api: api,
                  channelName: 'test',
                  maxHeight: maxHeight,
                  receiverFactory: (api, onMessage, onStatus) =>
                      TwitchAutomodEventSubService(
                        api: api,
                        onMessage: onMessage,
                        onStatus: onStatus,
                        connector: (_) {
                          final socket = _Socket();
                          sockets.add(socket);
                          return socket;
                        },
                      ),
                ),
                const Expanded(child: Text('chat')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    sockets.single.welcome();
    await tester.pump();
    await tester.pump();
    sockets.single.message(
      'automod.message.hold',
      {..._held(), 'broadcaster_user_id': broadcaster},
      broadcaster: broadcaster,
      owner: moderator,
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('AutoMod 待審 · 1'));
    await tester.pump();
    return (api, sockets);
  }

  Map<String, dynamic> cheerEvent(String broadcaster) => {
    ..._held('bits'),
    'broadcaster_user_id': broadcaster,
    'message': {
      'text': 'Cheer100',
      'fragments': [
        {
          'type': 'cheermote',
          'text': 'Cheer100',
          'cheermote': {'prefix': 'cheer', 'bits': 100, 'tier': 100},
        },
      ],
    },
  };

  TwitchCheermoteCatalog fixtureCatalog(String url) =>
      TwitchCheermoteCatalog.parse([
        {
          'prefix': 'Cheer',
          'tiers': [
            {
              'id': '100',
              'min_bits': 100,
              'images': {
                'light': {
                  'static': {'2': url},
                },
              },
            },
          ],
        },
      ]);

  testWidgets(
    'Bits catalog response renders a loaded image in the actual queue',
    (tester) async {
      const url = 'https://static-cdn.jtvnw.net/fixture-bits.png';
      const provider = NetworkImage(url);
      final image = Completer<ImageInfo>();
      PaintingBinding.instance.imageCache.putIfAbsent(
        provider,
        () => OneFrameImageStreamCompleter(image.future),
      );
      addTearDown(() => PaintingBinding.instance.imageCache.evict(provider));
      final (api, sockets) = await mount(tester);
      api.cheerWrite = Completer<TwitchCheermoteCatalog>();
      sockets.single.message('automod.message.hold', cheerEvent('20'));
      await tester.pump();
      expect(find.text('Bits 圖片載入中，原文字仍保留。'), findsOneWidget);
      api.cheerWrite!.complete(fixtureCatalog(url));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Cheer100 · 100 Bits'),
        80,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 28, 28),
        ui.Paint()..color = const ui.Color(0xff663399),
      );
      final picture = recorder.endRecording();
      final bitmap = (await tester.runAsync(() => picture.toImage(28, 28)))!;
      picture.dispose();
      image.complete(ImageInfo(image: bitmap));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<Image>(find.byType(Image)).single.image,
        provider,
      );
      expect(
        tester.widgetList<RawImage>(find.byType(RawImage)).single.image,
        isNotNull,
      );
      expect(api.cheerLoads, 1);
      expect(api.actions, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(sockets.single.closed, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing moderator rejects old Bits result on the same channel',
    (tester) async {
      final (old, oldSockets) = await mount(tester);
      old.cheerWrite = Completer<TwitchCheermoteCatalog>();
      oldSockets.single.message('automod.message.hold', cheerEvent('20'));
      await tester.pump();
      final (current, currentSockets) = await mount(tester, moderator: '11');
      current.cheerWrite = Completer<TwitchCheermoteCatalog>();
      currentSockets.single.message(
        'automod.message.hold',
        cheerEvent('20'),
        owner: '11',
      );
      await tester.pump();
      old.cheerWrite!.complete(
        fixtureCatalog('https://static-cdn.jtvnw.net/stale.png'),
      );
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Bits 圖片載入中，原文字仍保留。'), findsOneWidget);
      expect(oldSockets.single.closed, true);
      expect(current.cheerLoads, 1);
      current.cheerWrite!.complete(const TwitchCheermoteCatalog.empty());
      await tester.pump();
      expect(find.text('Bits 圖片載入中，原文字仍保留。'), findsNothing);
      expect(old.actions, isEmpty);
      expect(current.actions, isEmpty);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      'disposed queue ignores late Bits ${fails ? 'error' : 'success'}',
      (tester) async {
        final (api, sockets) = await mount(tester);
        api.cheerWrite = Completer<TwitchCheermoteCatalog>();
        sockets.single.message('automod.message.hold', cheerEvent('20'));
        await tester.pump();
        expect(api.cheerLoads, 1);
        await tester.pumpWidget(const SizedBox());
        if (fails) {
          api.cheerWrite!.completeError(StateError('late fixture failure'));
        } else {
          api.cheerWrite!.complete(
            fixtureCatalog('https://static-cdn.jtvnw.net/stale.png'),
          );
        }
        await tester.pump();
        expect(sockets.single.closed, true);
        expect(find.byType(Image), findsNothing);
        expect(api.actions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Bits read failure preserves text and manual retry does not moderate',
    (tester) async {
      final (api, sockets) = await mount(tester);
      api.cheerFail = true;
      sockets.single.message('automod.message.hold', cheerEvent('20'));
      await tester.pump();
      await tester.pump();
      final retry = find.text('Bits 圖片載入失敗，按此重試；原文字仍保留。');
      await tester.scrollUntilVisible(
        retry,
        -80,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      api.cheerFail = false;
      await tester.tap(retry);
      await tester.pump();
      await tester.pump();
      expect(api.cheerLoads, 2);
      expect(find.text('Bits 圖片載入失敗，按此重試；原文字仍保留。'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Cheer100 · 100 Bits'),
        80,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(api.actions, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('changing channel rejects pending Bits image response', (
    tester,
  ) async {
    final (old, oldSockets) = await mount(tester);
    old.cheerWrite = Completer<TwitchCheermoteCatalog>();
    oldSockets.single.message('automod.message.hold', cheerEvent('20'));
    await tester.pump();
    expect(old.cheerLoads, 1);
    final (current, currentSockets) = await mount(tester, broadcaster: '99');
    current.cheerWrite = Completer<TwitchCheermoteCatalog>();
    currentSockets.single.message(
      'automod.message.hold',
      cheerEvent('99'),
      broadcaster: '99',
    );
    await tester.pump();
    old.cheerWrite!.complete(
      TwitchCheermoteCatalog.parse([
        {
          'prefix': 'Cheer',
          'tiers': [
            {
              'id': '100',
              'min_bits': 100,
              'images': {
                'light': {
                  'static': {'2': 'https://static-cdn.jtvnw.net/stale.png'},
                },
              },
            },
          ],
        },
      ]),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.text('Bits 圖片載入中，原文字仍保留。'), findsOneWidget);
    expect(current.cheerLoads, 1);
    expect(oldSockets.single.closed, true);
    current.cheerWrite!.complete(const TwitchCheermoteCatalog.empty());
    await tester.pump();
    expect(find.text('Bits 圖片載入中，原文字仍保留。'), findsNothing);
    expect(current.actions, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'held events render highlighted terms and ambiguous candidates without sending',
    (tester) async {
      final (api, sockets) = await mount(tester);
      sockets.single.message('automod.message.hold', {
        ..._held('term'),
        'reason': 'blocked_term',
        'message': {'text': 'abc bad xyz'},
        'blocked_term': {
          'terms_found': [
            {
              'boundary': {'start_pos': 4, 'end_pos': 6},
            },
          ],
        },
      });
      sockets.single.message('automod.message.hold', {
        ..._held('ambiguous'),
        'message': {'text': 'é bad tail'},
        'automod': {
          'category': 'aggressive',
          'level': 2,
          'boundaries': [
            {'start_pos': 3, 'end_pos': 5},
          ],
        },
      });
      await tester.pump();
      await tester.pump();
      final termFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.textSpan?.toPlainText() == 'abc bad xyz',
      );
      await tester.scrollUntilVisible(
        termFinder,
        80,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final term = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .singleWhere((text) => text.textSpan?.toPlainText() == 'abc bad xyz');
      final spans = term.textSpan!.children!.cast<TextSpan>();
      expect(
        spans.where((span) => span.style?.backgroundColor != null).single.text,
        'bad',
      );
      await tester.scrollUntilVisible(
        find.text('命中位置有不同解讀，請核對原文。'),
        80,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump();
      expect(find.text('UTF-8：bad'), findsOneWidget);
      expect(api.actions, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(sockets.single.closed, true);
    },
  );
  testWidgets(
    '320px + keyboard + enlarged text stays bounded; allow waits for official update',
    (tester) async {
      final (api, sockets) = await mount(tester);
      await tester.ensureVisible(find.text('允許訊息'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('允許訊息'));
      await tester.pump();
      await tester.pump();
      expect(api.actions, [('held-1', true)]);
      expect(find.text('待審內容'), findsOneWidget);
      expect(find.text('已送出，等待官方審核更新'), findsOneWidget);
      sockets.single.message('automod.message.update', {
        ..._held(),
        'status': 'approved',
        'moderator_user_id': 'another',
      });
      await tester.pump();
      expect(find.text('待審內容'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'pending write locks duplicate actions and disposal ignores late response',
    (tester) async {
      final (api, sockets) = await mount(tester);
      api.write = Completer<void>();
      await tester.ensureVisible(find.text('拒絕訊息'));
      await tester.pump();
      await tester.tap(find.text('拒絕訊息'));
      await tester.pump();
      final buttons = tester
          .widgetList<TextButton>(find.byType(TextButton))
          .toList();
      expect(buttons.where((button) => button.onPressed == null).length, 2);
      expect(api.actions, [('held-1', false)]);
      await tester.pumpWidget(const SizedBox());
      api.write!.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(sockets.single.closed, true);
    },
  );
  testWidgets('short landscape hides expanded rows without layout overflow', (
    tester,
  ) async {
    final (api, sockets) = await mount(
      tester,
      size: const Size(640, 320),
      maxHeight: 50,
    );
    expect(find.text('待審內容'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(sockets.single.closed, true);
    expect(api.actions, isEmpty);
  });
}
