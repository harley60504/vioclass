// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/api/chat/twitch_whisper_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_history_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_threads_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/core/twitch_api_constants.dart';

void main() {
  for (final threads in [false, true]) {
    for (final failure in ['missing', 'foreign', 'gql', 'http401', 'http403']) {
      test(
        '${threads ? "Inbox" : "History"}: $failure never uses Web',
        () async {
          final dio = Dio();
          var gqlCalls = 0;
          dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.uri.path.endsWith('/validate')) {
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      statusCode: 200,
                      data: {
                        'user_id': failure == 'foreign' ? '9' : '1',
                        'login': 'fixture',
                        'expires_in': 1000,
                        'client_id':
                            TwitchApiConstants.twitchAndroidPublicClientId,
                        'scopes': <String>[],
                      },
                    ),
                  );
                  return;
                }
                gqlCalls++;
                expect(options.headers['Authorization'], 'OAuth android');
                expect(
                  options.headers.containsKey('Client-Integrity'),
                  isFalse,
                );
                if (failure.startsWith('http')) {
                  handler.reject(
                    DioException(
                      requestOptions: options,
                      type: DioExceptionType.badResponse,
                      response: Response(
                        requestOptions: options,
                        statusCode: failure == 'http401' ? 401 : 403,
                      ),
                    ),
                  );
                } else {
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      statusCode: 200,
                      data: [
                        {
                          'errors': [
                            {'message': 'failed integrity check'},
                          ],
                        },
                      ],
                    ),
                  );
                }
              },
            ),
          );
          final client = TwitchApiClient(dio: dio);
          addTearDown(client.close);
          final history = TwitchWhisperHistoryApiService(
            client: client,
            androidOnlyReads: true,
            androidTokenProviders: [
              () async => failure == 'missing' ? null : 'android',
            ],
            webTokenProviders: [
              () async {
                fail('Web token must not be requested');
              },
            ],
            integrityHeadersProvider: (_) async {
              fail('Web integrity must not be requested');
            },
          );
          final Future<Object> result = threads
              ? TwitchWhisperThreadsApiService(
                  history: history,
                  integrityProvider: (_) async {
                    fail('Web verification must not be requested');
                  },
                ).page(ownerId: '1')
              : history.page(ownerId: '1', peerId: '2');
          await expectLater(result, throwsA(isA<TwitchWhisperException>()));
          expect(
            gqlCalls,
            failure == 'missing' || failure == 'foreign' ? 0 : 1,
          );
        },
      );
    }
  }
}
