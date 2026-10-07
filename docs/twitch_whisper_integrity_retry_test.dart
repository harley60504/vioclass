// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/core/twitch_api_constants.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_history_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_threads_api_service.dart';

void main() {
  for (final threads in [false, true]) {
    for (final rejectAgain in [false, true]) {
      test(
        '${threads ? "Threads" : "History"} integrity rejection refreshes once; repeat=$rejectAgain',
        () async {
          var attempts = 0;
          var invalidations = 0;
          var proof = 'old-proof';
          final sentProofs = <String>[];
          final dio = Dio();
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
                        'user_id': '1',
                        'login': 'me',
                        'scopes': [],
                        'expires_in': 1000,
                      },
                    ),
                  );
                  return;
                }
                attempts++;
                sentProofs.add(request.headers['Client-Integrity'] as String);
                handler.resolve(
                  Response(
                    requestOptions: request,
                    statusCode: 200,
                    data: [
                      if (attempts == 1 || rejectAgain)
                        {
                          'errors': [
                            {'message': 'failed integrity check'},
                          ],
                        }
                      else if (threads)
                        {
                          'data': {
                            'currentUser': {
                              'id': '1',
                              'whisperThreads': {
                                'edges': [],
                                'pageInfo': {'hasNextPage': false},
                              },
                            },
                          },
                        }
                      else
                        {
                          'data': {
                            'whisperThread': {
                              'messages': {
                                'edges': [],
                                'pageInfo': {'hasNextPage': false},
                              },
                            },
                          },
                        },
                    ],
                  ),
                );
              },
            ),
          );
          final client = TwitchApiClient(dio: dio);
          addTearDown(client.close);
          Future<TwitchWhisperIntegrityContext> context(
            TwitchWhisperSession session,
          ) async => TwitchWhisperIntegrityContext(
            ownerId: '1',
            clientId: session.validation.clientId,
            token: proof,
            deviceId: 'fixture_device_123456',
            userAgent: 'fixture-UA',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          );
          Future<void> invalidate(
            TwitchWhisperSession session,
            String rejected,
          ) async {
            expect(rejected, 'old-proof');
            invalidations++;
            proof = 'new-proof';
          }

          final history = TwitchWhisperHistoryApiService(
            client: client,
            webTokenProviders: [() async => 'fixture-web'],
            integrityHeadersProvider: (session) async =>
                (await context(session)).headersFor(session),
            integrityInvalidator: invalidate,
          );
          final pending = threads
              ? TwitchWhisperThreadsApiService(
                  history: history,
                  integrityProvider: context,
                  integrityInvalidator: invalidate,
                ).page(ownerId: '1')
              : history.page(ownerId: '1', peerId: '2');
          if (rejectAgain) {
            await expectLater(pending, throwsA(isA<TwitchWhisperException>()));
          } else {
            await pending;
          }
          expect(attempts, 2);
          expect(invalidations, 1);
          expect(sentProofs, ['old-proof', 'new-proof']);
        },
      );
    }
  }
}
