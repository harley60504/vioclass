// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_archive_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_history_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_threads_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/core/twitch_api_constants.dart';

Object reply(String id, {bool archived = true}) => [
  {
    'data': {
      'updateWhisperThread': {
        'thread': {'id': id, 'isArchived': archived},
      },
    },
  },
];

void main() {
  for (final scenario in [
    'success',
    'foreign-id',
    'not-archived',
    'errors',
    'malformed',
    'timeout',
    'integrity-once',
    'integrity-twice',
    'partial-integrity',
    'account-change',
  ]) {
    test('Official archive request and acknowledgement: $scenario', () async {
      var writes = 0;
      var invalidations = 0;
      var current = true;
      var proof = 'fixture-proof';
      final sent = <String>[];
      final dio = Dio();
      final client = TwitchApiClient(dio: dio);
      addTearDown(client.close);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.uri.path.endsWith('/validate')) {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {
                    'client_id': TwitchApiConstants.twitchWebClientId,
                    'user_id': '130591488',
                    'login': 'fixture',
                    'scopes': [],
                    'expires_in': 1000,
                  },
                ),
              );
              return;
            }
            writes++;
            final payload = (request.data as List).single as Map;
            expect(payload['operationName'], 'Thread_ArchiveThread');
            expect(payload['variables'], {
              'input': {'threadID': '130591488_177661922', 'isArchived': true},
            });
            expect(payload['extensions'], {
              'persistedQuery': {
                'version': 1,
                'sha256Hash':
                    '4b4ef44b3b0a51ead216b83cfb340051ba49e4af12cf5eda580f6c5d609396c5',
              },
            });
            expect(request.headers['Authorization'], 'OAuth fixture-web');
            expect(request.headers['X-Device-ID'], 'fixture-device');
            sent.add(request.headers['Client-Integrity'] as String);
            if (scenario == 'timeout') {
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.receiveTimeout,
                ),
              );
              return;
            }
            final rejected =
                (scenario.startsWith('integrity') && writes == 1) ||
                scenario == 'integrity-twice';
            final data = rejected
                ? [
                    {
                      'errors': [
                        {'message': 'failed integrity check'},
                      ],
                    },
                  ]
                : scenario == 'foreign-id'
                ? reply('wrong-thread')
                : scenario == 'not-archived'
                ? reply('130591488_177661922', archived: false)
                : scenario == 'errors' || scenario == 'partial-integrity'
                ? [
                    {
                      'errors': [
                        {
                          'message': scenario == 'partial-integrity'
                              ? 'failed integrity check'
                              : 'denied',
                        },
                      ],
                      'data':
                          (reply('130591488_177661922') as List).single['data'],
                    },
                  ]
                : scenario == 'malformed'
                ? [
                    {'data': {}},
                  ]
                : reply('130591488_177661922');
            handler.resolve(
              Response(requestOptions: request, statusCode: 200, data: data),
            );
          },
        ),
      );
      final history = TwitchWhisperHistoryApiService(
        client: client,
        webTokenProviders: [() async => 'fixture-web'],
        integrityHeadersProvider: (_) async {
          if (scenario == 'account-change') current = false;
          return {
            'Client-Integrity': proof,
            'X-Device-ID': 'fixture-device',
            'User-Agent': 'fixture-UA',
          };
        },
        integrityInvalidator: (_, rejected) async {
          expect(rejected, 'fixture-proof');
          invalidations++;
          proof = 'refreshed-proof';
        },
      );
      final pending = TwitchWhisperArchiveApiService(history: history).archive(
        ownerId: '130591488',
        peerId: '177661922',
        canApply: () => current,
      );
      if (scenario == 'success' || scenario == 'integrity-once') {
        await pending;
      } else {
        await expectLater(pending, throwsA(isA<TwitchWhisperException>()));
      }
      expect(
        writes,
        scenario == 'account-change'
            ? 0
            : scenario.startsWith('integrity')
            ? 2
            : 1,
      );
      expect(invalidations, scenario.startsWith('integrity') ? 1 : 0);
      if (scenario.startsWith('integrity')) {
        expect(sent, ['fixture-proof', 'refreshed-proof']);
      }
    });
  }

  test('Archived thread is omitted without losing pagination cursor', () {
    final parsed = TwitchWhisperThreadsApiService.parse([
      {
        'data': {
          'currentUser': {
            'id': '1',
            'whisperThreads': {
              'edges': [
                {
                  'cursor': 'archived-cursor',
                  'node': {
                    'id': '1_2',
                    'isArchived': true,
                    'participants': [
                      {'id': '1'},
                      {'id': '2'},
                    ],
                  },
                },
              ],
              'pageInfo': {'hasNextPage': true},
            },
          },
        },
      },
    ], ownerId: '1');
    expect(parsed.conversations, isEmpty);
    expect(parsed.nextCursor, 'archived-cursor');
  });
}
