// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_history_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_api_service.dart';
import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/core/twitch_api_constants.dart';
import '../lib/features/twitch/models/chat/twitch_whisper_conversation.dart';
import '../lib/features/twitch/models/chat/twitch_whisper_remote_history.dart';
import '../lib/features/twitch/services/chat/twitch_whisper_archive_store.dart';
import '../lib/features/twitch/services/chat/twitch_whisper_inbox_controller.dart';

class _SessionApi extends TwitchWhisperApiService {
  String owner = '1';
  _SessionApi(TwitchApiClient client)
    : super(client: client, tokenProviders: const []);
  @override
  Future<TwitchWhisperSession> session({
    String? ownerId,
    String? scope,
  }) async => TwitchWhisperSession(
    'fake',
    TwitchTokenValidation(
      clientId: 'fake',
      userId: owner,
      login: 'me',
      expiresIn: 1000,
      scopes: const [],
    ),
  );
  @override
  Future<TwitchWhisperConversation> findUser(
    String login,
    String ownerId,
  ) async => TwitchWhisperConversation(
    userId: '2',
    login: 'peer',
    displayName: 'Peer',
  );
}

class _History extends TwitchWhisperHistoryApiService {
  Completer<void>? gate;
  bool fail = false;
  String? next = 'next';
  final cursors = <String?>[];
  _History(TwitchApiClient client)
    : super(client: client, webTokenProviders: const []);
  @override
  Future<TwitchWhisperRemotePage> page({
    required String ownerId,
    required String peerId,
    String? cursor,
  }) async {
    cursors.add(cursor);
    await gate?.future;
    if (fail) throw const TwitchWhisperException('fake history failure');
    return TwitchWhisperRemotePage(
      ownerId: ownerId,
      peerId: peerId,
      requestedCursor: cursor,
      nextCursor: next,
      messages: [
        TwitchWhisperMessage(
          id: 'remote',
          fromUserId: peerId,
          toUserId: ownerId,
          text: 'old message',
          timestamp: DateTime.utc(2025),
          state: TwitchWhisperMessageState.received,
        ),
      ],
    );
  }
}

List<Map<String, dynamic>> response({
  String sender = '2',
  String id = 'a',
  String cursor = 'next',
  bool? hasNext,
  bool empty = false,
}) => [
  {
    'data': {
      'whisperThread': {
        'messages': {
          'edges': empty
              ? []
              : [
                  {
                    'cursor': cursor,
                    'node': {
                      'id': id,
                      'from': {'id': sender},
                      'content': {'content': 'hello'},
                      'sentAt': '2026-10-03T12:00:00Z',
                    },
                  },
                ],
          if (hasNext != null) 'pageInfo': {'hasNextPage': hasNext},
        },
      },
    },
  },
];

void main() {
  test(
    'History diagnostics distinguish missing thread and empty edge cursor',
    () {
      final cases = <String, dynamic>{
        'data/whisperThread': [
          {
            'data': {'whisperThread': null},
          },
        ],
        'messages/edges/cursor': response(cursor: ''),
      };
      for (final entry in cases.entries) {
        final trace = <String>[];
        expect(
          () => TwitchWhisperHistoryApiService.parse(
            entry.value,
            ownerId: '1',
            peerId: '2',
            diagnostic: trace.add,
          ),
          throwsA(isA<TwitchWhisperException>()),
        );
        expect(trace.last, 'formatFailure stage=${entry.key}');
        expect(trace.join(' '), isNot(contains('hello')));
      }
    },
  );

  test('Known thread key follows captured official numeric ordering', () {
    expect(TwitchWhisperHistoryApiService.threadId('10', '2'), '2_10');
    expect(TwitchWhisperHistoryApiService.threadId('2', '10'), '2_10');
    expect(
      () => TwitchWhisperHistoryApiService.threadId('1', '1'),
      throwsA(isA<TwitchWhisperException>()),
    );
  });
  test('Page validates participants and makes no delivery/read claims', () {
    final incoming = TwitchWhisperHistoryApiService.parse(
      response(),
      ownerId: '1',
      peerId: '2',
    );
    expect(incoming.messages.single.toUserId, '1');
    expect(incoming.nextCursor, 'next');
    final outgoing = TwitchWhisperHistoryApiService.parse(
      response(sender: '1', hasNext: false),
      ownerId: '1',
      peerId: '2',
    );
    expect(outgoing.messages.single.state, TwitchWhisperMessageState.submitted);
    expect(outgoing.exhausted, true);
  });
  test(
    'Errors, missing threads, foreign sender and stalled cursor fail atomically',
    () {
      for (final value in [
        [],
        [
          {
            'errors': [
              {'message': 'secret'},
            ],
          },
        ],
        [
          {
            'data': {'whisperThread': null},
          },
        ],
        response(sender: '9'),
      ]) {
        expect(
          () => TwitchWhisperHistoryApiService.parse(
            value,
            ownerId: '1',
            peerId: '2',
          ),
          throwsA(isA<TwitchWhisperException>()),
        );
      }
      expect(
        () => TwitchWhisperHistoryApiService.parse(
          response(cursor: 'same'),
          ownerId: '1',
          peerId: '2',
          cursor: 'same',
        ),
        throwsA(isA<TwitchWhisperException>()),
      );
      expect(
        TwitchWhisperHistoryApiService.parse(
          response(empty: true),
          ownerId: '1',
          peerId: '2',
        ).exhausted,
        true,
      );
    },
  );
  test(
    'Only same-owner Web token is used; request is read-only and hash isolated',
    () async {
      final dio = Dio();
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            final token = options.headers['Authorization']
                .toString()
                .split(' ')
                .last;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: options.uri.path.endsWith('/validate')
                    ? {
                        'user_id': token == 'other' ? '9' : '1',
                        'login': 'me',
                        'expires_in': 1000,
                        'client_id': token == 'main'
                            ? 'main-client'
                            : TwitchApiConstants.twitchWebClientId,
                        'scopes': <String>[],
                      }
                    : response(),
              ),
            );
          },
        ),
      );
      final client = TwitchApiClient(dio: dio);
      addTearDown(client.close);
      final api = TwitchWhisperHistoryApiService(
        client: client,
        webTokenProviders: [
          () async => 'main',
          () async => 'other',
          () async => 'web',
        ],
        integrityHeadersProvider: (session) async {
          expect(session.validation.userId, '1');
          expect(session.token, 'web');
          return {
            'Client-Integrity': 'fixture-integrity',
            'X-Device-ID': 'fixture_device_123456789',
            'User-Agent': 'fixture-native-UA',
          };
        },
      );
      await api.page(ownerId: '1', peerId: '2');
      final gql = requests
          .where((value) => value.uri.host == 'gql.twitch.tv')
          .single;
      expect(gql.headers['Authorization'], 'OAuth web');
      expect(gql.headers['Client-Integrity'], 'fixture-integrity');
      expect(gql.headers['User-Agent'], 'fixture-native-UA');
      expect(
        (gql.data as List).single['operationName'],
        TwitchWhisperHistoryApiService.operation,
      );
      expect(
        (gql.data as List).single['extensions']['persistedQuery']['sha256Hash'],
        TwitchWhisperHistoryApiService.hash,
      );
      expect((gql.data as List).single['variables'], {'id': '1_2'});
      expect(
        requests.any((value) => value.uri.path.contains('whispers')),
        false,
      );
    },
  );

  late Map<String, String> disk;
  late TwitchWhisperArchiveStore store;
  late TwitchWhisperConversation peer;
  var fail = false;
  setUp(() {
    disk = {};
    fail = false;
    store = TwitchWhisperArchiveStore(
      read: (key) async => disk[key],
      write: (key, value) async {
        if (fail) throw StateError('fixture write failure');
        disk[key] = value;
      },
    );
    peer = TwitchWhisperConversation(
      userId: '2',
      login: 'peer',
      displayName: 'Peer',
      draft: 'keep',
      unreadCount: 3,
    );
  });
  TwitchWhisperRemotePage page({
    String owner = '1',
    String? requested,
    String? next = 'next',
  }) {
    final parsed = TwitchWhisperHistoryApiService.parse(
      response(),
      ownerId: owner,
      peerId: '2',
    );
    return TwitchWhisperRemotePage(
      ownerId: owner,
      peerId: '2',
      messages: parsed.messages,
      requestedCursor: requested,
      nextCursor: next,
    );
  }

  test(
    'Atomic merge preserves draft/unread, deduplicates and stores checkpoint',
    () async {
      await store.saveDraft('1', peer, 'saved draft');
      await store.mergeRemotePage('1', peer, page());
      await store.mergeRemotePage('1', peer, page());
      final loaded = (await store.load('1')).single;
      expect(loaded.messages, hasLength(1));
      expect(loaded.draft, 'saved draft');
      expect(loaded.unreadCount, 3);
      expect(loaded.hasReceivedWhisper, false);
      expect(loaded.remoteHistoryCursor, 'next');
      expect(loaded.remoteHistoryComplete, false);
      await store.mergeRemotePage(
        '1',
        peer,
        page(requested: 'next', next: null),
      );
      expect((await store.load('1')).single.remoteHistoryComplete, true);
    },
  );
  test('Wrong account and stale page cannot change existing disk', () async {
    await store.mergeRemotePage('1', peer, page());
    final saved = disk.values.single;
    await expectLater(
      store.mergeRemotePage('1', peer, page(owner: '9')),
      throwsFormatException,
    );
    await expectLater(
      store.mergeRemotePage('1', peer, page(requested: 'wrong')),
      throwsFormatException,
    );
    expect(disk.values.single, saved);
  });
  test(
    'Write failure cannot advance saved pagination or discard drafts',
    () async {
      await store.mergeRemotePage('1', peer, page());
      final saved = disk.values.single;
      fail = true;
      await expectLater(
        store.mergeRemotePage('1', peer, page(requested: 'next', next: null)),
        throwsStateError,
      );
      expect(disk.values.single, saved);
      expect((await store.load('1')).single.remoteHistoryCursor, 'next');
    },
  );
  test(
    'Old archive remains compatible and corrupt archive is not replaced',
    () async {
      final json = peer.toJson()
        ..remove('remoteHistoryCursor')
        ..remove('remoteHistoryComplete');
      expect(
        TwitchWhisperConversation.fromJson(json).remoteHistoryComplete,
        false,
      );
      disk['vioclass_twitch_whispers_v1_1'] = 'corrupt';
      await expectLater(
        store.mergeRemotePage('1', peer, page()),
        throwsA(isA<TwitchWhisperArchiveException>()),
      );
      expect(disk.values.single, 'corrupt');
    },
  );

  Future<(_SessionApi, TwitchWhisperInboxController, _History)> open({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final client = TwitchApiClient();
    addTearDown(client.close);
    final api = _SessionApi(client);
    final history = _History(client);
    final inbox = TwitchWhisperInboxController(
      api: api,
      historyApi: history,
      store: store,
      receiveInBackground: false,
      historySyncTimeout: timeout,
    );
    addTearDown(inbox.dispose);
    await inbox.refreshSession();
    await inbox.startConversation('peer');
    return (api, inbox, history);
  }

  test(
    'History cancel releases wait without checkpoint advance or late overwrite',
    () async {
      final (_, inbox, history) = await open();
      await inbox.syncActiveHistory();
      final saved = disk.values.single;
      final gate = Completer<void>();
      history.gate = gate;
      final pending = inbox.syncActiveHistory(older: true);
      while (!inbox.canCancelHistorySync) {
        await Future<void>.delayed(Duration.zero);
      }
      inbox.cancelHistorySync();
      await pending;
      expect(disk.values.single, saved);
      expect(inbox.syncingHistory, false);
      history.gate = null;
      history.next = null;
      await inbox.syncActiveHistory(older: true);
      final newer = disk.values.single;
      history.fail = true;
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(disk.values.single, newer);
      expect(inbox.historyError, null);
      expect(inbox.activeConversation!.remoteHistoryComplete, true);
    },
  );
  test(
    'History timeout keeps page and retry resumes the same older cursor',
    () async {
      final (_, inbox, history) = await open(
        timeout: const Duration(milliseconds: 20),
      );
      await inbox.syncActiveHistory();
      final saved = disk.values.single;
      final gate = Completer<void>();
      history.gate = gate;
      await inbox.syncActiveHistory(older: true);
      expect(inbox.historyError, contains('逾時'));
      expect(disk.values.single, saved);
      history.gate = null;
      history.next = null;
      await inbox.retryHistorySync();
      expect(history.cursors, [null, 'next', 'next']);
      expect(inbox.historyError, null);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(inbox.activeConversation!.remoteHistoryComplete, true);
    },
  );
  test(
    'Selecting another peer cancels history read and late result cannot attach to either peer',
    () async {
      final (_, inbox, history) = await open();
      final gate = Completer<void>();
      history.gate = gate;
      final pending = inbox.syncActiveHistory();
      while (!inbox.canCancelHistorySync) {
        await Future<void>.delayed(Duration.zero);
      }
      await store.saveDraft(
        '1',
        TwitchWhisperConversation(
          userId: '3',
          login: 'three',
          displayName: 'Three',
        ),
        'third draft',
      );
      inbox.setPanelVisible(true);
      await inbox.selectConversation('3');
      await pending;
      history.gate = null;
      history.next = null;
      await inbox.syncActiveHistory();
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      final saved = await store.load('1');
      expect(saved.singleWhere((peer) => peer.userId == '2').messages, isEmpty);
      expect(
        saved.singleWhere((peer) => peer.userId == '3').messages,
        hasLength(1),
      );
      expect(inbox.historyPeerId, '3');
      expect(inbox.historyError, null);
    },
  );
  test('History disk commit cannot be cancelled after it starts', () async {
    final client = TwitchApiClient();
    addTearDown(client.close);
    final gate = Completer<void>();
    var block = false;
    var writing = false;
    final slowStore = TwitchWhisperArchiveStore(
      read: (key) async => disk[key],
      write: (key, value) async {
        if (block) {
          writing = true;
          await gate.future;
        }
        disk[key] = value;
      },
    );
    final inbox = TwitchWhisperInboxController(
      api: _SessionApi(client),
      historyApi: _History(client),
      store: slowStore,
      receiveInBackground: false,
    );
    addTearDown(inbox.dispose);
    await inbox.refreshSession();
    await inbox.startConversation('peer');
    block = true;
    final pending = inbox.syncActiveHistory();
    while (!writing) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(inbox.canCancelHistorySync, false);
    inbox.cancelHistorySync();
    expect(inbox.syncingHistory, true);
    gate.complete();
    await pending;
    expect(inbox.activeConversation!.messages, hasLength(1));
    expect(inbox.historyStatus, isNot(contains('取消')));
  });

  test(
    'Controller preserves drafts typed during sync and concurrent live receipt',
    () async {
      final (_, inbox, history) = await open();
      history.gate = Completer<void>();
      final syncing = inbox.syncActiveHistory();
      await Future<void>.delayed(Duration.zero);
      inbox.updateDraft('2', 'typed during sync');
      await inbox.receiveEvent({
        'from_user_id': '2',
        'to_user_id': '1',
        'whisper_id': 'live',
        'whisper': {'text': 'live message'},
      }, DateTime.utc(2026));
      history.gate!.complete();
      await syncing;
      expect(inbox.activeConversation!.draft, 'typed during sync');
      expect(inbox.activeConversation!.messages.map((message) => message.id), [
        'remote',
        'live',
      ]);
      expect(inbox.activeConversation!.unreadCount, 1);
      await inbox.flushDrafts();
      expect((await store.load('1')).single.draft, 'typed during sync');
    },
  );
  test('Late remote response cannot merge after account switch', () async {
    final (api, inbox, history) = await open();
    history.gate = Completer<void>();
    final syncing = inbox.syncActiveHistory();
    await Future<void>.delayed(Duration.zero);
    api.owner = '9';
    await inbox.refreshSession();
    history.gate!.complete();
    await syncing;
    expect(inbox.ownerId, '9');
    expect(inbox.conversations, isEmpty);
    expect((await store.load('1')).expand((peer) => peer.messages), isEmpty);
    expect(inbox.syncingHistory, false);
  });
  test(
    'Recent refresh preserves older checkpoint and exhausted state',
    () async {
      final (_, inbox, history) = await open();
      await inbox.syncActiveHistory();
      history.next = 'changed-recent';
      await inbox.syncActiveHistory();
      expect(inbox.activeConversation!.remoteHistoryCursor, 'next');
      history.next = null;
      await inbox.syncActiveHistory(older: true);
      expect(history.cursors.last, 'next');
      expect(inbox.activeConversation!.remoteHistoryComplete, true);
      final count = history.cursors.length;
      await inbox.syncActiveHistory(older: true);
      expect(history.cursors.length, count);
      history.next = 'latest';
      await inbox.syncActiveHistory();
      expect(inbox.activeConversation!.remoteHistoryComplete, true);
    },
  );
  test('API failure and duplicate sync do not lose local data', () async {
    final (_, inbox, history) = await open();
    history.fail = true;
    history.gate = Completer<void>();
    final syncing = inbox.syncActiveHistory();
    await Future<void>.delayed(Duration.zero);
    await inbox.syncActiveHistory();
    expect(history.cursors, hasLength(1));
    await inbox.removeConversation('2');
    expect(inbox.activeConversation, isNotNull);
    history.gate!.complete();
    await syncing;
    expect(inbox.historyError, 'fake history failure');
    expect(inbox.syncingHistory, false);
    expect(inbox.activeConversation!.messages, isEmpty);
  });
}
