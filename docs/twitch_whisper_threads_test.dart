// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_threads_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_history_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_api_service.dart';
import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/core/twitch_api_constants.dart';
import '../lib/features/twitch/models/chat/twitch_whisper_conversation.dart';
import '../lib/features/twitch/services/chat/twitch_whisper_archive_store.dart';
import '../lib/features/twitch/services/chat/twitch_whisper_inbox_controller.dart';
import '../lib/features/twitch/models/chat/twitch_whisper_remote_history.dart';

Map<String, dynamic> inbox({
  String owner = '1',
  String peer = '2',
  bool empty = false,
  bool more = false,
  String cursor = 'next',
}) => {
  'data': {
    'currentUser': {
      'id': owner,
      'whisperThreads': {
        'edges': empty
            ? []
            : [
                {
                  'cursor': cursor,
                  'node': {
                    'id': TwitchWhisperHistoryApiService.threadId(owner, peer),
                    'participants': [
                      {'id': owner},
                      {
                        'id': peer,
                        'login': 'peer$peer',
                        'displayName': 'Peer $peer',
                        'profileImageURL': 'https://example.test/avatar.png',
                      },
                    ],
                    'unreadMessagesCount': 4,
                    'lastMessage': {
                      'id': 'message-$peer',
                      'from': {'id': peer},
                      'content': {'content': 'remote preview'},
                      'sentAt': '2026-10-03T12:00:00Z',
                    },
                  },
                },
              ],
        'pageInfo': {'hasNextPage': more},
      },
    },
  },
};

class _Web extends TwitchWhisperHistoryApiService {
  _Web(TwitchApiClient client)
    : super(client: client, webTokenProviders: const []);
  @override
  Future<TwitchWhisperSession> webSession(String owner) async =>
      TwitchWhisperSession(
        'fake-web',
        TwitchTokenValidation(
          clientId: TwitchApiConstants.twitchWebClientId,
          userId: owner,
          login: 'me',
          expiresIn: 1000,
          scopes: const [],
        ),
      );
}

class _SessionApi extends TwitchWhisperApiService {
  Completer<void>? sessionGate;
  int sessionCalls = 0;
  bool failSession = false;
  String owner = '1';
  _SessionApi(TwitchApiClient client)
    : super(client: client, tokenProviders: const []);
  @override
  Future<TwitchWhisperSession> session({String? ownerId, String? scope}) async {
    sessionCalls++;
    final requestedOwner = owner;
    await sessionGate?.future;
    if (failSession) throw const TwitchWhisperException('fake session failure');
    return TwitchWhisperSession(
      'fake',
      TwitchTokenValidation(
        clientId: 'fake',
        userId: requestedOwner,
        login: 'me',
        expiresIn: 100,
        scopes: const ['user:read:whispers', 'user:manage:whispers'],
      ),
    );
  }
}

class _Threads extends TwitchWhisperThreadsApiService {
  Completer<void>? gate;
  bool fail = false;
  final cursors = <String?>[];
  _Threads(TwitchApiClient client) : super(history: _Web(client));
  @override
  Future<TwitchWhisperThreadsPage> page({
    required String ownerId,
    String? cursor,
  }) async {
    cursors.add(cursor);
    await gate?.future;
    if (fail) throw const TwitchWhisperException('fake remote error');
    return TwitchWhisperThreadsApiService.parse(
      inbox(
        owner: ownerId,
        peer: cursor == null ? '2' : '3',
        more: cursor == null,
      ),
      ownerId: ownerId,
      cursor: cursor,
    );
  }
}

void main() {
  test(
    'SDK context uses paired device and native UA without plain integrity call',
    () async {
      final dio = Dio();
      RequestOptions? request;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: inbox()),
            );
          },
        ),
      );
      final client = TwitchApiClient(dio: dio);
      addTearDown(client.close);
      final service = TwitchWhisperThreadsApiService(
        history: _Web(client),
        integrityProvider: (session) async => TwitchWhisperIntegrityContext(
          ownerId: session.validation.userId,
          clientId: session.validation.clientId,
          token: 'sdk-test',
          deviceId: 'existingdevice0001',
          userAgent: 'native-test-UA',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
        ),
      );
      expect((await service.page(ownerId: '1')).conversations, hasLength(1));
      expect(request!.uri.toString(), TwitchApiConstants.gqlEndpoint);
      expect(request!.headers['Client-Integrity'], 'sdk-test');
      expect(request!.headers['X-Device-ID'], 'existingdevice0001');
      expect(request!.headers['User-Agent'], 'native-test-UA');
    },
  );

  test(
    'SDK context rejects mismatched owner and expired credentials',
    () async {
      for (final wrongOwner in [true, false]) {
        final dio = Dio();
        var calls = 0;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              calls++;
              handler.reject(DioException(requestOptions: options));
            },
          ),
        );
        final client = TwitchApiClient(dio: dio);
        addTearDown(client.close);
        final service = TwitchWhisperThreadsApiService(
          history: _Web(client),
          integrityProvider: (session) async => TwitchWhisperIntegrityContext(
            ownerId: wrongOwner ? '9' : '1',
            clientId: session.validation.clientId,
            token: 'sdk-test',
            deviceId: 'existingdevice0001',
            userAgent: 'native-UA',
            expiresAt: DateTime.now().toUtc().add(
              Duration(minutes: wrongOwner ? 1 : -1),
            ),
          ),
        );
        await expectLater(
          service.page(ownerId: '1'),
          throwsA(isA<TwitchWhisperException>()),
        );
        expect(calls, 0);
      }
    },
  );

  final capturedFixture =
      Platform.environment['TWITCH_WHISPER_RESPONSE_FIXTURE'];
  if (capturedFixture != null) {
    test('User-supplied official response parses completely', () {
      final response = jsonDecode(File(capturedFixture).readAsStringSync());
      final result = response is List ? response.single : response;
      final ownerId = result['data']['currentUser']['id'] as String;
      final edges =
          result['data']['currentUser']['whisperThreads']['edges'] as List;
      final page = TwitchWhisperThreadsApiService.parse(
        response,
        ownerId: ownerId,
      );
      expect(page.conversations.length, edges.length);
      for (var i = 0; i < edges.length; i++) {
        final messages = edges[i]['node']['messages']['edges'] as List;
        expect(page.conversations[i].messages.length, messages.length);
      }
    });
  }

  test('Thread IDs order different-length user IDs numerically', () {
    expect(
      TwitchWhisperHistoryApiService.threadId('900000000', '1000000000'),
      '900000000_1000000000',
    );
    expect(
      TwitchWhisperHistoryApiService.threadId('1000000000', '900000000'),
      '900000000_1000000000',
    );
  });

  test('Inbox accepts official numeric thread order, not lexical order', () {
    final value = inbox(owner: '900000000', peer: '1000000000');
    final node =
        value['data']['currentUser']['whisperThreads']['edges'][0]['node'];
    // Independent server fixture: do not generate the expected ID with the
    // implementation under test.
    node['id'] = '900000000_1000000000';
    expect(
      TwitchWhisperThreadsApiService.parse(
        value,
        ownerId: '900000000',
      ).conversations.single.userId,
      '1000000000',
    );
    node['id'] = '1000000000_900000000';
    expect(
      () => TwitchWhisperThreadsApiService.parse(value, ownerId: '900000000'),
      throwsA(isA<TwitchWhisperException>()),
    );
  });

  test(
    'Official browser response imports without direct integrity requests',
    () async {
      final dio = Dio();
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
      final client = TwitchApiClient(dio: dio);
      addTearDown(client.close);
      final service = TwitchWhisperThreadsApiService(
        history: _Web(client),
        browserResponse: (cursor) async {
          expect(cursor, isNull);
          return [inbox()];
        },
      );
      final page = await service.page(ownerId: '1');
      expect(page.conversations.single.userId, '2');
      expect(requests, 0);
    },
  );

  test(
    'Official browser response rejects a different logged-in owner',
    () async {
      final client = TwitchApiClient(dio: Dio());
      addTearDown(client.close);
      final service = TwitchWhisperThreadsApiService(
        history: _Web(client),
        browserResponse: (_) async => [inbox(owner: '9')],
      );
      await expectLater(
        service.page(ownerId: '1'),
        throwsA(isA<TwitchWhisperException>()),
      );
    },
  );

  test(
    'Remote discovery extracts unknown peer, preview and separate remote unread',
    () {
      final page = TwitchWhisperThreadsApiService.parse(
        inbox(more: true),
        ownerId: '1',
      );
      final peer = page.conversations.single;
      expect(peer.userId, '2');
      expect(peer.login, 'peer2');
      expect(peer.remoteUnreadCount, 4);
      expect(peer.unreadCount, 0);
      expect(peer.hasReceivedWhisper, false);
      expect(peer.messages.single.fromUserId, '2');
      expect(page.nextCursor, 'next');
    },
  );
  test(
    'Unauthenticated and foreign accounts are not mistaken for empty inbox',
    () {
      for (final value in [
        inbox(owner: '9'),
        {
          'data': {'currentUser': null},
        },
        {
          'errors': [
            {'message': 'secret'},
          ],
        },
        <String, dynamic>{},
      ]) {
        expect(
          () => TwitchWhisperThreadsApiService.parse(value, ownerId: '1'),
          throwsA(isA<TwitchWhisperException>()),
        );
      }
      expect(
        TwitchWhisperThreadsApiService.parse(
          inbox(empty: true),
          ownerId: '1',
        ).conversations,
        isEmpty,
      );
    },
  );
  test('Bad participants and stalled pagination reject the whole page', () {
    final value = inbox();
    final node =
        value['data']['currentUser']['whisperThreads']['edges'][0]['node'];
    node['participants'] = [
      {'id': '9'},
      {'id': '2'},
    ];
    expect(
      () => TwitchWhisperThreadsApiService.parse(value, ownerId: '1'),
      throwsA(isA<TwitchWhisperException>()),
    );
    expect(
      () => TwitchWhisperThreadsApiService.parse(
        inbox(more: true),
        ownerId: '1',
        cursor: 'next',
      ),
      throwsA(isA<TwitchWhisperException>()),
    );
    expect(
      () => TwitchWhisperThreadsApiService.parse(
        inbox(empty: true, more: true),
        ownerId: '1',
      ),
      throwsA(isA<TwitchWhisperException>()),
    );
  });
  test(
    'Request is explicitly read-only and does not touch persisted hashes',
    () async {
      final dio = Dio();
      RequestOptions? request;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            if (options.uri.toString() ==
                TwitchApiConstants.gqlIntegrityEndpoint) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'token': 'test-integrity'},
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: inbox(),
                ),
              );
            }
          },
        ),
      );
      final client = TwitchApiClient(dio: dio);
      addTearDown(client.close);
      await TwitchWhisperThreadsApiService(
        history: _Web(client),
      ).page(ownerId: '1', cursor: 'before');
      expect(request!.headers['Authorization'], 'OAuth fake-web');
      final body = request!.data as List;
      expect(body, hasLength(1));
      expect(
        body.single['operationName'],
        'Whispers_Whispers_UserWhisperThreads',
      );
      expect(body.single['variables'], {'cursor': 'before'});
      expect(body.single['extensions'], {
        'persistedQuery': {
          'version': 1,
          'sha256Hash':
              'b9535d107dc5b016645d2ef895c295e8001df6ff89ca26231599e0d11b2a5927',
        },
      });
      expect(request!.headers['Client-Integrity'], 'test-integrity');
    },
  );

  test(
    'Captured Web response accepts empty first cursor and message edges',
    () {
      final value = inbox(cursor: '');
      final node =
          value['data']['currentUser']['whisperThreads']['edges'][0]['node'];
      node.remove('lastMessage');
      node['messages'] = {
        'edges': [
          {
            'cursor': '',
            'node': {
              'id': 'official-message',
              'from': {'id': '2'},
              'content': {'content': 'captured'},
              'sentAt': '2026-10-04T10:00:00Z',
            },
          },
        ],
      };
      final page = TwitchWhisperThreadsApiService.parse(value, ownerId: '1');
      expect(page.conversations.single.messages.single.text, 'captured');
      expect(page.conversations.single.messages.single.historicalOnly, isTrue);
      expect(page.nextCursor, isNull);
    },
  );

  test('Captured browser export wrapper accepts a single response array', () {
    final value = inbox(cursor: '');
    final page = TwitchWhisperThreadsApiService.parse([value], ownerId: '1');

    expect(page.conversations, hasLength(1));
    expect(page.conversations.single.userId, '2');
  });

  test('Captured Web inbox without pageInfo is treated as the final page', () {
    final value = inbox(cursor: '');
    value['data']['currentUser']['whisperThreads'].remove('pageInfo');

    final page = TwitchWhisperThreadsApiService.parse(value, ownerId: '1');

    expect(page.nextCursor, isNull);
  });

  test(
    'Missing pageInfo retains a supplied cursor rather than claiming completion',
    () {
      final value = inbox(cursor: 'server-next');
      value['data']['currentUser']['whisperThreads'].remove('pageInfo');
      final page = TwitchWhisperThreadsApiService.parse(value, ownerId: '1');
      expect(page.nextCursor, 'server-next');
      expect(
        () => TwitchWhisperThreadsApiService.parse(
          value,
          ownerId: '1',
          cursor: 'server-next',
        ),
        throwsA(isA<TwitchWhisperException>()),
      );
    },
  );

  test(
    'Integrity rejection is not reported as missing login or empty inbox',
    () {
      expect(
        () => TwitchWhisperThreadsApiService.parse({
          'errors': [
            {'message': 'failed integrity check'},
          ],
        }, ownerId: '1'),
        throwsA(
          isA<TwitchWhisperException>().having(
            (error) => error.message,
            'message',
            contains('既有登入已驗證'),
          ),
        ),
      );
    },
  );

  test('Captured Web localized sentAt timestamps are accepted', () {
    final value = inbox(cursor: '');
    final node =
        value['data']['currentUser']['whisperThreads']['edges'][0]['node']['lastMessage'];
    node['sentAt'] = '2024/4/12 上午 05:49:17';

    final page = TwitchWhisperThreadsApiService.parse(value, ownerId: '1');

    expect(
      page.conversations.single.messages.single.timestamp,
      DateTime.utc(2024, 4, 12, 5, 49, 17),
    );
  });

  late Map<String, String> disk;
  late TwitchWhisperArchiveStore store;
  var fail = false;
  setUp(() {
    disk = {};
    fail = false;
    store = TwitchWhisperArchiveStore(
      read: (key) async => disk[key],
      write: (key, value) async {
        if (fail) throw StateError('fake failed write');
        disk[key] = value;
      },
    );
  });
  test(
    'Post-authorization refresh validates latest account after older in-flight token',
    () async {
      final client = TwitchApiClient();
      final api = _SessionApi(client)..sessionGate = Completer<void>();
      final controller = TwitchWhisperInboxController(
        api: api,
        store: store,
        receiveInBackground: false,
      );
      final old = controller.refreshSession();
      while (api.sessionCalls < 1) {
        await Future<void>.delayed(Duration.zero);
      }
      api.owner = '9';
      final latest = controller.refreshSession(afterCurrent: true);
      expect(identical(old, latest), false);
      api.sessionGate!.complete();
      await latest;
      expect(controller.ownerId, '9');
      expect(api.sessionCalls, 2);
      controller.dispose();
      client.close();
    },
  );
  test(
    'Controller discovers unknown peers, resumes saved pages and explicitly restarts refresh',
    () async {
      final client = TwitchApiClient();
      final api = _SessionApi(client);
      final threads = _Threads(client);
      var notices = 0;
      var controller = TwitchWhisperInboxController(
        api: api,
        threadsApi: threads,
        store: store,
        receiveInBackground: false,
        onIncomingNotification: (_) => notices++,
      );
      await controller.refreshSession();
      await controller.syncThreads();
      expect(controller.conversations.single.userId, '2');
      expect(controller.isHistoricalMessage('message-2'), true);
      expect(controller.unreadCount, 0);
      expect(notices, 0);
      controller.dispose();
      controller = TwitchWhisperInboxController(
        api: api,
        threadsApi: threads,
        store: store,
        receiveInBackground: false,
      );
      await controller.refreshSession();
      await controller.syncThreads(more: true);
      expect(threads.cursors, [null, 'next']);
      expect(controller.conversations, hasLength(2));
      expect(controller.threadsComplete, true);
      await controller.syncThreads();
      expect(controller.threadsComplete, false);
      expect((await store.threadsCheckpoint('1')).cursor, 'next');
      controller.dispose();
      client.close();
    },
  );
  test(
    'Cancel releases wait and late response cannot overwrite newer retry',
    () async {
      final client = TwitchApiClient();
      final api = _SessionApi(client);
      final remote = _Threads(client);
      final controller = TwitchWhisperInboxController(
        api: api,
        threadsApi: remote,
        store: store,
        receiveInBackground: false,
      );
      await controller.refreshSession();
      await controller.syncThreads();
      final saved = disk.values.single;
      final gate = Completer<void>();
      remote.gate = gate;
      final pending = controller.syncThreads(more: true);
      while (!controller.canCancelThreadsSync) {
        await Future<void>.delayed(Duration.zero);
      }
      controller.cancelThreadsSync();
      await pending;
      expect(controller.syncingThreads, false);
      expect(disk.values.single, saved);
      expect((await store.threadsCheckpoint('1')).cursor, 'next');
      remote.gate = null;
      await controller.syncThreads(more: true);
      final newer = disk.values.single;
      final status = controller.threadsStatus;
      remote.fail = true;
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(disk.values.single, newer);
      expect(controller.threadsStatus, status);
      expect(controller.threadsError, null);
      controller.dispose();
      client.close();
    },
  );
  test(
    'Timeout preserves cursor and explicit retry requests the same page',
    () async {
      final client = TwitchApiClient();
      final remote = _Threads(client);
      final controller = TwitchWhisperInboxController(
        api: _SessionApi(client),
        threadsApi: remote,
        store: store,
        receiveInBackground: false,
        threadsSyncTimeout: const Duration(milliseconds: 20),
      );
      await controller.refreshSession();
      await controller.syncThreads();
      final saved = disk.values.single;
      final gate = Completer<void>();
      remote.gate = gate;
      await controller.syncThreads(more: true);
      expect(controller.threadsError, contains('逾時'));
      expect(controller.syncingThreads, false);
      expect(disk.values.single, saved);
      remote.gate = null;
      await controller.retryThreadsSync();
      expect(remote.cursors, [null, 'next', 'next']);
      expect(controller.threadsComplete, true);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(controller.threadsError, null);
      controller.dispose();
      client.close();
    },
  );
  test(
    'Remote error preserves data and retries failed more page rather than first page',
    () async {
      final client = TwitchApiClient();
      final remote = _Threads(client);
      final controller = TwitchWhisperInboxController(
        api: _SessionApi(client),
        threadsApi: remote,
        store: store,
        receiveInBackground: false,
      );
      await controller.refreshSession();
      await controller.syncThreads();
      final saved = disk.values.single;
      remote.fail = true;
      await controller.syncThreads(more: true);
      expect(controller.threadsError, 'fake remote error');
      expect(disk.values.single, saved);
      remote.fail = false;
      await controller.retryThreadsSync();
      expect(remote.cursors, [null, 'next', 'next']);
      expect(controller.conversations, hasLength(2));
      controller.dispose();
      client.close();
    },
  );
  test(
    'Cancel cannot interrupt a disk commit or advertise unchanged data after save started',
    () async {
      final client = TwitchApiClient();
      final gate = Completer<void>();
      var writing = false;
      var delayCommit = false;
      final slowStore = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async {
          if (delayCommit) {
            writing = true;
            await gate.future;
          }
          disk[key] = value;
        },
      );
      final controller = TwitchWhisperInboxController(
        api: _SessionApi(client),
        threadsApi: _Threads(client),
        store: slowStore,
        receiveInBackground: false,
      );
      await controller.refreshSession();
      delayCommit = true;
      final pending = controller.syncThreads();
      while (!writing) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(controller.canCancelThreadsSync, false);
      controller.cancelThreadsSync();
      expect(controller.syncingThreads, true);
      gate.complete();
      await pending;
      expect(controller.conversations, hasLength(1));
      expect(controller.threadsStatus, isNot(contains('取消')));
      controller.dispose();
      client.close();
    },
  );
  test(
    'Concurrent session refresh shares completion and API request',
    () async {
      final client = TwitchApiClient();
      final api = _SessionApi(client)..sessionGate = Completer<void>();
      final controller = TwitchWhisperInboxController(
        api: api,
        store: store,
        receiveInBackground: false,
      );
      final first = controller.refreshSession();
      final second = controller.refreshSession();
      expect(identical(first, second), true);
      var done = false;
      unawaited(second.then((_) => done = true));
      await Future<void>.delayed(Duration.zero);
      expect(done, false);
      expect(api.sessionCalls, 1);
      api.sessionGate!.complete();
      await Future.wait([first, second]);
      expect(controller.ownerId, '1');
      expect(controller.loading, false);
      expect(done, true);
      controller.dispose();
      client.close();
    },
  );
  test(
    'Session clear detaches old wait and rejects its late account result',
    () async {
      final client = TwitchApiClient();
      final api = _SessionApi(client)..sessionGate = Completer<void>();
      final oldGate = api.sessionGate!;
      final controller = TwitchWhisperInboxController(
        api: api,
        store: store,
        receiveInBackground: false,
      );
      final old = controller.refreshSession();
      while (api.sessionCalls < 1) {
        await Future<void>.delayed(Duration.zero);
      }
      controller.clearSession();
      api.owner = '9';
      api.sessionGate = null;
      final newer = controller.refreshSession();
      expect(identical(old, newer), false);
      await newer;
      oldGate.complete();
      await old;
      expect(controller.ownerId, '9');
      expect(controller.loading, false);
      controller.dispose();
      client.close();
    },
  );
  test('Failed shared refresh releases all callers and allows retry', () async {
    final client = TwitchApiClient();
    final api = _SessionApi(client)
      ..sessionGate = Completer<void>()
      ..failSession = true;
    final controller = TwitchWhisperInboxController(
      api: api,
      store: store,
      receiveInBackground: false,
    );
    final first = controller.refreshSession();
    final second = controller.refreshSession();
    api.sessionGate!.complete();
    await Future.wait([first, second]);
    expect(controller.ownerId, null);
    expect(controller.errorText, 'fake session failure');
    api.failSession = false;
    await controller.refreshSession();
    expect(controller.ownerId, '1');
    expect(api.sessionCalls, 2);
    controller.dispose();
    client.close();
  });
  test(
    'Late remote result after account switch cannot enter either account archive',
    () async {
      final client = TwitchApiClient();
      final api = _SessionApi(client);
      final threads = _Threads(client)..gate = Completer<void>();
      final controller = TwitchWhisperInboxController(
        api: api,
        threadsApi: threads,
        store: store,
        receiveInBackground: false,
      );
      await controller.refreshSession();
      final pending = controller.syncThreads();
      while (threads.cursors.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      api.owner = '9';
      await controller.refreshSession();
      threads.gate!.complete();
      await pending;
      expect(controller.ownerId, '9');
      expect(controller.conversations, isEmpty);
      expect(await store.load('1'), isEmpty);
      expect(await store.load('9'), isEmpty);
      controller.dispose();
      client.close();
    },
  );
  test(
    'Newer observed profile and local draft survive remote inbox response',
    () async {
      final started = DateTime.utc(2026, 10, 3);
      final peer = TwitchWhisperConversation(
        userId: '2',
        login: 'newer',
        displayName: 'Newer',
        avatarUrl: 'https://example.test/new.png',
        profileObservedAt: started.add(const Duration(seconds: 1)),
        draft: 'keep draft',
        unreadCount: 3,
      );
      await store.saveDraft('1', peer, peer.draft);
      await store.mergeThreadsPage(
        '1',
        TwitchWhisperThreadsApiService.parse(inbox(more: true), ownerId: '1'),
        requestedAt: started,
      );
      final saved = (await store.load('1')).single;
      expect(saved.login, 'newer');
      expect(saved.displayName, 'Newer');
      expect(saved.avatarUrl, peer.avatarUrl);
      expect(saved.draft, 'keep draft');
      expect(saved.unreadCount, 3);
      expect(saved.remoteUnreadCount, 4);
    },
  );
  test(
    'History-first live receipt promotes once, persists and survives later refresh',
    () async {
      final client = TwitchApiClient();
      final api = _SessionApi(client);
      final threads = _Threads(client);
      var notices = 0;
      final controller = TwitchWhisperInboxController(
        api: api,
        threadsApi: threads,
        store: store,
        receiveInBackground: false,
        onIncomingNotification: (_) => notices++,
      );
      await controller.refreshSession();
      await controller.syncThreads();
      expect(controller.isHistoricalMessage('message-2'), true);
      final event = <String, dynamic>{
        'from_user_id': '2',
        'to_user_id': '1',
        'whisper_id': 'message-2',
        'from_user_login': 'peer2',
        'from_user_name': 'Live Peer',
        'whisper': {'text': 'remote preview'},
      };
      await controller.receiveEvent(event, DateTime.now().toUtc());
      expect(controller.unreadCount, 1);
      expect(notices, 1);
      expect(controller.isHistoricalMessage('message-2'), false);
      expect(controller.conversations.single.hasReceivedWhisper, true);
      await controller.receiveEvent(event, DateTime.now().toUtc());
      await controller.syncThreads();
      await controller.refreshSession();
      await controller.receiveEvent(event, DateTime.now().toUtc());
      expect(notices, 1);
      expect(controller.unreadCount, 1);
      expect(controller.isHistoricalMessage('message-2'), false);
      expect(controller.conversations.single.messages, hasLength(1));
      controller.dispose();
      client.close();
    },
  );
  test(
    'Live-first receipt followed by history remains live and idempotent',
    () async {
      final peer = TwitchWhisperConversation(
        userId: '2',
        login: 'peer2',
        displayName: 'Peer',
      );
      final remote = TwitchWhisperThreadsApiService.parse(
        inbox(more: true),
        ownerId: '1',
      );
      final message = remote.conversations.single.messages.single;
      await store.append('1', peer, message);
      await store.mergeThreadsPage('1', remote);
      final saved = (await store.load('1')).single;
      expect(saved.unreadCount, 1);
      expect(saved.messages.single.historicalOnly, false);
      expect(saved.hasReceivedWhisper, true);
      expect(await store.append('1', peer, message), false);
    },
  );
  test(
    'Old message JSON defaults to live and rejects invalid receipt provenance',
    () {
      final message = TwitchWhisperThreadsApiService.parse(
        inbox(),
        ownerId: '1',
      ).conversations.single.messages.single;
      final raw = message.toJson()..remove('historicalOnly');
      expect(TwitchWhisperMessage.fromJson(raw).historicalOnly, false);
      raw['historicalOnly'] = 'true';
      expect(
        () => TwitchWhisperMessage.fromJson(raw),
        throwsA(isA<TypeError>()),
      );
    },
  );
  test(
    'Live receive and draft edit during remote request survive merge and restart',
    () async {
      final client = TwitchApiClient();
      final api = _SessionApi(client);
      final threads = _Threads(client);
      var notices = 0;
      final controller = TwitchWhisperInboxController(
        api: api,
        threadsApi: threads,
        store: store,
        receiveInBackground: false,
        onIncomingNotification: (_) => notices++,
      );
      await controller.refreshSession();
      await controller.syncThreads();
      threads.gate = Completer<void>();
      final pending = controller.syncThreads();
      while (threads.cursors.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      controller.updateDraft('2', 'draft during request');
      await controller.receiveEvent({
        'from_user_id': '2',
        'to_user_id': '1',
        'whisper_id': 'live-new',
        'from_user_login': 'renamed',
        'from_user_name': 'Renamed',
        'whisper': {'text': 'new live message'},
      }, DateTime.now().toUtc().add(const Duration(seconds: 1)));
      threads.gate!.complete();
      await pending;
      expect(controller.conversations.single.displayName, 'Renamed');
      expect(controller.conversations.single.draft, 'draft during request');
      expect(controller.conversations.single.messages, hasLength(2));
      expect(controller.unreadCount, 1);
      expect(notices, 1);
      await controller.flushDrafts();
      await controller.refreshSession();
      expect(controller.conversations.single.draft, 'draft during request');
      expect(controller.isHistoricalMessage('message-2'), true);
      expect(controller.isHistoricalMessage('live-new'), false);
      controller.dispose();
      client.close();
    },
  );
  for (final change in ['text', 'participants']) {
    test(
      'Backup $change identity conflict rejects entire multi-peer import',
      () async {
        final remote = TwitchWhisperThreadsApiService.parse(
          inbox(more: true),
          ownerId: '1',
        );
        await store.mergeThreadsPage('1', remote);
        final saved = disk.values.single;
        final peer = remote.conversations.single.toJson();
        final message =
            (peer['messages'] as List).single as Map<String, dynamic>;
        if (change == 'text') {
          message['text'] = 'conflicting text';
        } else {
          message['fromUserId'] = '1';
          message['toUserId'] = '2';
        }
        final unknown = TwitchWhisperConversation(
          userId: '3',
          login: 'three',
          displayName: 'Three',
        );
        await expectLater(
          store.importBackup(
            '1',
            jsonEncode({
              'version': 1,
              'ownerId': '1',
              'conversations': [unknown.toJson(), peer],
            }),
          ),
          throwsFormatException,
        );
        expect(disk.values.single, saved);
        expect((await store.load('1')), hasLength(1));
        expect((await store.threadsCheckpoint('1')).cursor, 'next');
      },
    );
  }
  test(
    'Conflicting repeated ID inside raw backup is not silently deduplicated',
    () async {
      final remote = TwitchWhisperThreadsApiService.parse(
        inbox(),
        ownerId: '1',
      );
      await store.mergeThreadsPage('1', remote);
      final saved = disk.values.single;
      final peer = remote.conversations.single.toJson();
      final messages = peer['messages'] as List;
      messages.add({
        ...messages.single as Map<String, dynamic>,
        'text': 'different',
      });
      await expectLater(
        store.importBackup(
          '1',
          jsonEncode({
            'version': 1,
            'ownerId': '1',
            'conversations': [peer],
          }),
        ),
        throwsFormatException,
      );
      expect(disk.values.single, saved);
    },
  );
  test('Same ID legitimate send state progress remains compatible', () {
    final original = TwitchWhisperMessage(
      id: 'local-one',
      fromUserId: '1',
      toUserId: '2',
      text: 'same text',
      timestamp: DateTime.utc(2026),
      state: TwitchWhisperMessageState.sending,
    );
    final peer = TwitchWhisperConversation(
      userId: '2',
      login: 'two',
      displayName: 'Two',
      messages: [
        original,
        original.copyWith(state: TwitchWhisperMessageState.submitted),
      ],
    );
    expect(peer.messages, hasLength(1));
    expect(peer.messages.single.state, TwitchWhisperMessageState.submitted);
  });
  test(
    'Inbox merge preserves drafts/local unread/checkpoint and adds unknown peer atomically',
    () async {
      final peer = TwitchWhisperConversation(
        userId: '2',
        login: 'old',
        displayName: 'Old',
        draft: 'keep',
        unreadCount: 3,
        remoteHistoryCursor: 'history-before',
      );
      await store.saveDraft('1', peer, 'keep');
      final page = TwitchWhisperThreadsApiService.parse(
        inbox(more: true),
        ownerId: '1',
      );
      await store.mergeThreadsPage('1', page);
      await store.mergeThreadsPage('1', page);
      final saved = (await store.load('1')).single;
      expect(saved.draft, 'keep');
      expect(saved.unreadCount, 3);
      expect(saved.remoteUnreadCount, 4);
      expect(saved.remoteHistoryCursor, 'history-before');
      expect(saved.messages, hasLength(1));
      expect((await store.threadsCheckpoint('1')).cursor, 'next');
      await store.saveDraft('1', saved, 'new draft');
      expect((await store.threadsCheckpoint('1')).cursor, 'next');
      final second = TwitchWhisperThreadsApiService.parse(
        inbox(peer: '3'),
        ownerId: '1',
        cursor: 'next',
      );
      await store.mergeThreadsPage('1', second);
      expect(await store.load('1'), hasLength(2));
      expect((await store.threadsCheckpoint('1')).complete, true);
    },
  );
  test(
    'Empty refresh keeps local conversations; failing write cannot advance cursor',
    () async {
      await store.mergeThreadsPage(
        '1',
        TwitchWhisperThreadsApiService.parse(inbox(more: true), ownerId: '1'),
      );
      final saved = disk.values.single;
      fail = true;
      await expectLater(
        store.mergeThreadsPage(
          '1',
          TwitchWhisperThreadsApiService.parse(
            inbox(peer: '3'),
            ownerId: '1',
            cursor: 'next',
          ),
        ),
        throwsStateError,
      );
      expect(disk.values.single, saved);
      fail = false;
      await store.mergeThreadsPage(
        '1',
        TwitchWhisperThreadsApiService.parse(inbox(empty: true), ownerId: '1'),
        refreshOnly: true,
      );
      expect(await store.load('1'), hasLength(1));
      expect((await store.threadsCheckpoint('1')).cursor, 'next');
    },
  );
  test(
    'Wrong owner, stale cursor and corrupt metadata do not overwrite disk',
    () async {
      await store.mergeThreadsPage(
        '1',
        TwitchWhisperThreadsApiService.parse(inbox(more: true), ownerId: '1'),
      );
      final saved = disk.values.single;
      await expectLater(
        store.mergeThreadsPage(
          '1',
          TwitchWhisperThreadsApiService.parse(inbox(owner: '9'), ownerId: '9'),
        ),
        throwsFormatException,
      );
      await expectLater(
        store.mergeThreadsPage(
          '1',
          TwitchWhisperThreadsApiService.parse(
            inbox(peer: '3'),
            ownerId: '1',
            cursor: 'wrong',
          ),
        ),
        throwsFormatException,
      );
      expect(disk.values.single, saved);
      disk[disk.keys.single] = saved.replaceFirst(
        '"remoteThreadsComplete":false',
        '"remoteThreadsComplete":"bad"',
      );
      final corrupt = disk.values.single;
      await expectLater(
        store.mergeThreadsPage(
          '1',
          TwitchWhisperThreadsApiService.parse(inbox(), ownerId: '1'),
        ),
        throwsA(isA<TwitchWhisperArchiveException>()),
      );
      expect(disk.values.single, corrupt);
    },
  );
}
