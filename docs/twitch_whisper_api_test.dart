// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_whisper_emote_catalog.dart';
import '../lib/features/twitch/services/chat/twitch_whisper_archive_store.dart';
import '../lib/features/twitch/services/chat/twitch_whisper_inbox_controller.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final validations = <String>[];
  final accounts = <String, Map<String, dynamic>>{
    'main': {
      'user_id': '1',
      'client_id': 'main-client',
      'scopes': ['user:read:whispers', 'user:manage:whispers'],
    },
    'other': {
      'user_id': '9',
      'client_id': 'other-client',
      'scopes': ['user:manage:whispers'],
    },
    'read-only': {
      'user_id': '1',
      'client_id': 'read-client',
      'scopes': ['user:read:whispers'],
    },
  };
  Object users = [
    {
      'id': '2',
      'login': 'peer',
      'display_name': 'Peer',
      'profile_image_url': 'https://example.test/avatar.png',
    },
  ];
  int status = 204;
  bool networkFailure = false;
  Completer<void>? validationGate;
  bool repeatedEmoteCursor = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path.endsWith('/validate')) {
      final token = options.headers['Authorization'].toString().split(' ').last;
      validations.add(token);
      await validationGate?.future;
      return _response({
        'login': 'owner',
        'expires_in': 1000,
        ...?accounts[token],
      }, accounts.containsKey(token) ? 200 : 401);
    }
    requests.add(options);
    if (options.uri.path.endsWith('/emotes/global')) {
      return _response({
        'data': [
          {
            'id': '25',
            'name': 'Kappa',
            'format': ['static'],
          },
        ],
      }, 200);
    }
    if (options.uri.path.endsWith('/emotes/user')) {
      final first = !options.queryParameters.containsKey('after');
      return _response({
        'data': [
          {
            'id': first ? '88' : '89',
            'name': first ? 'UserEmote' : 'SecondEmote',
            'format': ['animated'],
          },
        ],
        'pagination': first || repeatedEmoteCursor ? {'cursor': 'next'} : {},
      }, 200);
    }
    if (networkFailure) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    if (options.uri.path.endsWith('/users')) {
      return _response({'data': users}, 200);
    }
    if (options.uri.path.endsWith('/subscriptions')) {
      return _response({'data': []}, 202);
    }
    return _response({'message': 'fake rejection'}, status);
  }

  ResponseBody _response(Object value, int code) => ResponseBody.fromString(
    code == 204 ? '' : jsonEncode(value),
    code,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  late _Adapter adapter;
  late TwitchApiClient client;
  late TwitchWhisperApiService api;
  setUp(() {
    adapter = _Adapter();
    client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
    api = TwitchWhisperApiService(
      client: client,
      tokenProviders: [() async => ' main '],
    );
  });
  tearDown(() => client.close());
  test(
    'ambiguous names stay literal; inferred fragments preserve original whitespace',
    () async {
      final global = await api.fetchWhisperEmotes(
        ownerId: '1',
        canRead: () => true,
      );
      final original = global.emotes.single;
      final ambiguous = TwitchWhisperEmoteCatalog([
        original,
        original.copyWith(id: 'different'),
      ]);
      expect(ambiguous.parse('Kappa').single.emote, isNull);
      expect(
        global.parse('😀\tKappa\nunknown').map((part) => part.text).join(),
        '😀\tKappa\nunknown',
      );
      expect(
        global
            .parse('Kappa https://example/Kappa kappa')
            .where((part) => part.emote != null)
            .length,
        1,
      );
    },
  );
  test(
    'official emote catalog uses selected account, exact pagination and no channel-only filter',
    () async {
      adapter.accounts['main']!['scopes'] = ['user:read:emotes'];
      final catalog = await api.fetchWhisperEmotes(
        ownerId: '1',
        canRead: () => true,
      );
      expect(catalog.userError, isNull);
      expect(catalog.emotes.map((emote) => emote.name), [
        'Kappa',
        'UserEmote',
        'SecondEmote',
      ]);
      expect(adapter.requests[1].queryParameters, {'user_id': '1'});
      expect(adapter.requests[2].queryParameters, {
        'user_id': '1',
        'after': 'next',
      });
      expect(
        adapter.requests.every(
          (request) => request.headers['Client-ID'] == 'main-client',
        ),
        true,
      );
      expect(
        catalog
            .parse('Kappa kappa Kappa!\nUserEmote')
            .where((part) => part.emote != null)
            .length,
        2,
      );
      expect(
        catalog
            .parse('Kappa kappa Kappa!\nUserEmote')
            .map((part) => part.text)
            .join(),
        'Kappa kappa Kappa!\nUserEmote',
      );
    },
  );
  test(
    'missing emote scope keeps globals; repeated pagination discards partial personal catalog',
    () async {
      final globals = await api.fetchWhisperEmotes(
        ownerId: '1',
        canRead: () => true,
      );
      expect(globals.emotes.single.name, 'Kappa');
      expect(globals.userError, contains('user:read:emotes'));
      expect(adapter.requests.length, 1);
      adapter.accounts['main']!['scopes'] = ['user:read:emotes'];
      adapter.repeatedEmoteCursor = true;
      final partial = await api.fetchWhisperEmotes(
        ownerId: '1',
        canRead: () => true,
      );
      expect(partial.emotes.single.name, 'Kappa');
      expect(partial.userError, contains('分頁重複'));
    },
  );
  test(
    'profile reads exact stable ID with selected account and validated header',
    () async {
      final profile = await api.getUserById(ownerId: '1', peerId: '2');
      expect(profile.avatarUrl, 'https://example.test/avatar.png');
      expect(adapter.requests.single.queryParameters, {'id': '2'});
      expect(adapter.requests.single.headers['Client-ID'], 'main-client');
      expect(adapter.requests.single.headers['Authorization'], 'Bearer main');
    },
  );
  test(
    'profile rejects changed context, wrong ID, malformed data and unsafe avatar',
    () async {
      await expectLater(
        api.getUserById(ownerId: '1', peerId: '2', canRead: () => false),
        throwsA(isA<TwitchWhisperException>()),
      );
      expect(adapter.requests, isEmpty);
      for (final users in [
        [],
        [
          {
            'id': '9',
            'login': 'peer',
            'display_name': 'Peer',
            'profile_image_url': '',
          },
        ],
        [
          {
            'id': '2',
            'login': 'bad login',
            'display_name': 'Peer',
            'profile_image_url': '',
          },
        ],
        [
          {
            'id': '2',
            'login': 'peer',
            'display_name': 'Peer',
            'profile_image_url': 'file:///private',
          },
        ],
      ]) {
        adapter.users = users;
        await expectLater(
          api.getUserById(ownerId: '1', peerId: '2'),
          throwsA(isA<TwitchWhisperException>()),
        );
      }
      adapter.users = [
        {
          'id': '2',
          'login': 'peer',
          'display_name': 'Peer',
          'profile_image_url': '',
        },
      ];
      expect(
        (await api.getUserById(ownerId: '1', peerId: '2')).avatarUrl,
        isNull,
      );
    },
  );
  test(
    '204 only means submitted; exact selected owner, peer, body and validated client',
    () async {
      await api.send(ownerId: '1', peerId: '2', text: '中文 😀 hello');
      final r = adapter.requests.single;
      expect(r.method, 'POST');
      expect(r.uri.path, '/helix/whispers');
      expect(r.queryParameters, {'from_user_id': '1', 'to_user_id': '2'});
      expect(r.data, {'message': '中文 😀 hello'});
      expect(r.headers['Client-ID'], 'main-client');
      expect(r.headers['Authorization'], 'Bearer main');
    },
  );
  test(
    'invalid IDs, self, empty text and unknown-relationship oversized text never request',
    () async {
      for (final (owner, peer, text) in [
        ('1', '1', 'hello'),
        ('', '2', 'hello'),
        ('bad', '2', 'hello'),
        ('1', 'bad', 'hello'),
        ('1', '2', '  '),
        ('1', '2', 'x' * 501),
      ]) {
        await expectLater(
          api.send(ownerId: owner, peerId: peer, text: text),
          throwsA(isA<TwitchWhisperException>()),
        );
      }
      expect(adapter.requests, isEmpty);
      expect(adapter.validations, isEmpty);
    },
  );
  test(
    'owner bound before scope lookup never borrows another linked account',
    () async {
      api = TwitchWhisperApiService(
        client: client,
        tokenProviders: [() async => 'read-only', () async => 'other'],
      );
      expect((await api.session()).validation.userId, '1');
      await expectLater(
        api.session(scope: 'user:manage:whispers'),
        throwsA(isA<TwitchWhisperException>()),
      );
      await expectLater(
        api.send(ownerId: '1', peerId: '2', text: 'hello'),
        throwsA(isA<TwitchWhisperException>()),
      );
      expect(adapter.requests, isEmpty);
    },
  );
  for (final failure in ['empty', 'expired', 'throws', 'malformed']) {
    test(
      'Unbound $failure primary cannot select another linked identity',
      () async {
        if (failure == 'malformed') {
          adapter.accounts['broken'] = {
            'user_id': '',
            'client_id': 'broken-client',
            'scopes': ['user:manage:whispers'],
          };
        }
        var secondaryReads = 0;
        api = TwitchWhisperApiService(
          client: client,
          tokenProviders: [
            () async {
              if (failure == 'throws') {
                throw StateError('fake provider unavailable');
              }
              return failure == 'empty'
                  ? null
                  : failure == 'malformed'
                  ? 'broken'
                  : 'expired';
            },
            () async {
              secondaryReads++;
              return 'other';
            },
          ],
        );
        await expectLater(
          api.session(),
          throwsA(isA<TwitchWhisperException>()),
        );
        expect(secondaryReads, 0);
        expect(adapter.requests, isEmpty);
      },
    );
  }
  test(
    'Verified primary identity may obtain missing scope from same-owner token',
    () async {
      api = TwitchWhisperApiService(
        client: client,
        tokenProviders: [
          () async => 'read-only',
          () async => 'other',
          () async => 'main',
        ],
      );
      final auth = await api.session(scope: 'user:manage:whispers');
      expect(auth.validation.userId, '1');
      expect(auth.token, 'main');
      expect(adapter.requests, isEmpty);
    },
  );
  test(
    'Explicit owner can recover through same-owner fallback when primary expired',
    () async {
      api = TwitchWhisperApiService(
        client: client,
        tokenProviders: [
          () async => 'expired',
          () async => 'other',
          () async => 'main',
        ],
      );
      final auth = await api.session(
        ownerId: '1',
        scope: 'user:manage:whispers',
      );
      expect(auth.validation.userId, '1');
      expect(auth.token, 'main');
      expect(adapter.requests, isEmpty);
    },
  );
  test(
    'Changed primary refuses old explicit owner even when old linked token remains',
    () async {
      var secondaryReads = 0;
      api = TwitchWhisperApiService(
        client: client,
        tokenProviders: [
          () async => 'other',
          () async {
            secondaryReads++;
            return 'main';
          },
        ],
      );
      await expectLater(
        api.send(ownerId: '1', peerId: '2', text: 'must not request'),
        throwsA(
          isA<TwitchWhisperException>().having(
            (error) => error.message,
            'reason',
            contains('帳號已變更'),
          ),
        ),
      );
      expect(secondaryReads, 0);
      expect(adapter.requests, isEmpty);
      expect((await api.session()).validation.userId, '9');
    },
  );
  test(
    'known incoming relationship permits 10000 without truncation; default stays 500 with consistent emoji units',
    () async {
      final long = 'x' * 10000;
      await api.send(
        ownerId: '1',
        peerId: '2',
        text: long,
        hasReceivedWhisper: true,
      );
      expect(adapter.requests.single.data, {'message': long});
      await expectLater(
        api.send(
          ownerId: '1',
          peerId: '2',
          text: '${long}x',
          hasReceivedWhisper: true,
        ),
        throwsA(isA<TwitchWhisperException>()),
      );
      await expectLater(
        api.send(ownerId: '1', peerId: '2', text: '😀' * 251),
        throwsA(isA<TwitchWhisperException>()),
      );
      await api.send(ownerId: '1', peerId: '2', text: '😀' * 250);
      expect(adapter.requests.length, 2);
      expect(adapter.requests.last.data['message'], '😀' * 250);
    },
  );
  test(
    'Expired primary clears private session without loading secondary owner or losing old draft',
    () async {
      var secondaryReads = 0;
      final disk = <String, String>{};
      api = TwitchWhisperApiService(
        client: client,
        tokenProviders: [
          () async => 'main',
          () async {
            secondaryReads++;
            return 'other';
          },
        ],
      );
      final store = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async {
          disk[key] = value;
        },
      );
      final inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        receiveInBackground: false,
      );
      addTearDown(inbox.dispose);
      await inbox.refreshSession();
      await inbox.startConversation('peer');
      inbox.updateDraft('2', 'keep primary account draft');
      await inbox.flushDrafts();
      final saved = disk.values.single;
      final requestsBefore = adapter.requests.length;
      adapter.accounts.remove('main');
      await inbox.refreshSession();
      expect(inbox.ownerId, null);
      expect(inbox.conversations, isEmpty);
      expect(inbox.errorText, contains('主登入'));
      expect(secondaryReads, 0);
      expect(adapter.requests.length, requestsBefore);
      expect(disk.values.single, saved);
      expect(
        (await store.load('1')).single.draft,
        'keep primary account draft',
      );
      expect(await store.load('9'), isEmpty);
    },
  );
  test(
    'read-only receives without manage, manage can receive without read',
    () async {
      api = TwitchWhisperApiService(
        client: client,
        tokenProviders: [() async => 'read-only'],
      );
      expect(
        (await api.receiveSession('1')).validation.clientId,
        'read-client',
      );
      adapter.accounts['main']!['scopes'] = ['user:manage:whispers'];
      api = TwitchWhisperApiService(
        client: client,
        tokenProviders: [() async => 'main'],
      );
      final auth = await api.receiveSession('1');
      await api.subscribe(auth, 'socket-session');
      final r = adapter.requests.single;
      expect(r.queryParameters, isEmpty);
      expect(r.data, {
        'type': 'user.whisper.message',
        'version': '1',
        'condition': {'user_id': '1'},
        'transport': {'method': 'websocket', 'session_id': 'socket-session'},
      });
      expect(r.headers['Client-ID'], 'main-client');
      await expectLater(
        api.subscribe(auth, ''),
        throwsA(isA<TwitchWhisperException>()),
      );
      expect(adapter.requests.length, 1);
    },
  );
  test('account context lost while authorization waits cannot send', () async {
    var current = true;
    adapter.validationGate = Completer<void>();
    final sending = api.send(
      ownerId: '1',
      peerId: '2',
      text: 'hello',
      canSend: () => current,
    );
    await Future<void>.delayed(Duration.zero);
    current = false;
    adapter.validationGate!.complete();
    await expectLater(sending, throwsA(isA<TwitchWhisperException>()));
    expect(adapter.requests, isEmpty);
  });
  test(
    'exact normalized recipient data is required, without silently choosing wrong account',
    () async {
      final peer = await api.findUser(' PEER ', '1');
      expect(peer.userId, '2');
      expect(peer.avatarUrl, 'https://example.test/avatar.png');
      expect(adapter.requests.single.queryParameters, {'login': 'peer'});
      for (final rows in <Object>[
        [],
        [
          {'id': '2', 'login': 'wrong'},
        ],
        [
          {'id': 'not-id', 'login': 'peer'},
        ],
        [
          {'id': '1', 'login': 'peer'},
        ],
        ['malformed'],
      ]) {
        adapter.users = rows;
        await expectLater(
          api.findUser('peer', '1'),
          throwsA(isA<TwitchWhisperException>()),
        );
      }
      final count = adapter.requests.length;
      await expectLater(
        api.findUser('https://bad.test', '1'),
        throwsA(isA<TwitchWhisperException>()),
      );
      expect(adapter.requests.length, count);
    },
  );
  test(
    'known rejection statuses have actionable errors and no automatic retry',
    () async {
      for (final code in [400, 401, 403, 404, 429]) {
        adapter.status = code;
        await expectLater(
          api.send(ownerId: '1', peerId: '2', text: 'hello'),
          throwsA(
            isA<TwitchWhisperException>().having(
              (e) => e.outcomeUnknown,
              'known rejection',
              false,
            ),
          ),
        );
      }
      expect(adapter.requests.length, 5);
    },
  );
  test(
    'timeout, server failure and unexpected success remain unknown, not fictional failure/delivery',
    () async {
      for (final code in [500, 200, 202]) {
        adapter.status = code;
        await expectLater(
          api.send(ownerId: '1', peerId: '2', text: 'hello'),
          throwsA(
            isA<TwitchWhisperException>().having(
              (e) => e.outcomeUnknown,
              'unknown outcome',
              true,
            ),
          ),
        );
      }
      adapter.networkFailure = true;
      await expectLater(
        api.send(ownerId: '1', peerId: '2', text: 'hello'),
        throwsA(
          isA<TwitchWhisperException>().having(
            (e) => e.outcomeUnknown,
            'timeout',
            true,
          ),
        ),
      );
      expect(adapter.requests.length, 4);
    },
  );
}
