// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/chat/twitch_chat_user_public_profile_api_service.dart';
import '../lib/features/twitch/models/channel/twitch_user.dart';
import '../lib/features/twitch/presentation/sheets/twitch_chat_user_profile_sheet.dart';
import 'twitch_chat_user_profile_test.dart' as fixtures;

void main() {
  for (final mode in [
    'complete',
    'hidden',
    'partial',
    'failed',
    'stale',
    'unknown-follow',
  ]) {
    test('IVR anonymous optional data: $mode', () async {
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      var current = true;
      var reads = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            reads++;
            expect(options.uri.host, 'api.ivr.fi');
            expect(options.method, 'GET');
            expect(
              options.headers.keys.map((key) => key.toLowerCase()),
              isNot(contains(anyOf('authorization', 'cookie', 'client-id'))),
            );
            final isUser = options.uri.path.endsWith('/user');
            if (mode == 'failed' || (mode == 'partial' && !isUser)) {
              handler.reject(DioException(requestOptions: options));
              return;
            }
            if (mode == 'stale') current = false;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: isUser
                    ? [
                        {
                          'id': '30',
                          'login': 'peer',
                          'displayName': 'Public peer',
                          'createdAt': '2010-11-12T00:00:00Z',
                          'lastBroadcast': {
                            'startedAt': '2026-01-01T00:00:00Z',
                          },
                        },
                      ]
                    : {
                        'followedAt': mode == 'unknown-follow'
                            ? null
                            : '2020-01-01T00:00:00Z',
                        'statusHidden': mode == 'hidden',
                        'subscriber': false,
                        'cumulative': {'months': 49},
                        'streak': {'months': 6},
                      },
              ),
            );
          },
        ),
      );
      final info = await TwitchChatUserPublicProfileApiService(client: dio)
          .load(
            login: 'peer',
            userId: '30',
            channelLogin: 'test',
            isCurrent: () => current,
          );
      expect(reads, 3);
      if (mode == 'failed' || mode == 'stale') {
        expect(info, isNull);
      } else {
        expect(info!.user!.displayName, 'Public peer');
        expect(info.user!.createdAt, DateTime.utc(2010, 11, 12));
        expect(info.followKnown, mode != 'partial' && mode != 'unknown-follow');
        expect(info.followHidden, mode == 'hidden');
        expect(info.cumulativeMonths, mode == 'partial' ? isNull : 49);
      }
    });
  }

  for (final size in [const Size(320, 640), const Size(1000, 760)]) {
    testWidgets('Profile fills missing facts and hides unknown rows at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchChatUserProfileCard(
              message: fixtures.message('public'),
              messages: const [],
              canWhisper: false,
              loadUser: () async => const TwitchUser(
                id: '30',
                login: 'peer',
                displayName: 'Official peer',
              ),
              loadPublicProfile: () async => TwitchChatUserPublicProfile(
                user: TwitchUser(
                  id: '30',
                  login: 'peer',
                  displayName: 'Public peer',
                  createdAt: DateTime.utc(2010, 11, 12),
                ),
                followKnown: true,
                followedAt: DateTime.utc(2020),
                cumulativeMonths: 49,
                streakMonths: 6,
                subscribed: false,
                lastBroadcastAt: DateTime.utc(2026),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Official peer'), findsOneWidget);
      expect(find.textContaining('2010-11-12'), findsOneWidget);
      expect(find.text('49 個月'), findsOneWidget);
      expect(find.text('6 個月'), findsOneWidget);
      expect(find.text('目前未訂閱'), findsOneWidget);
      expect(find.text('無法取得'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchChatUserProfileCard(
              key: const ValueKey('missing'),
              message: fixtures.message('missing'),
              messages: const [],
              canWhisper: false,
              loadUser: () async => null,
              loadPublicProfile: () async => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('追隨此頻道'), findsNothing);
      expect(find.text('訂閱月數'), findsNothing);
      expect(find.text('未追隨'), findsNothing);
      expect(find.text('無法取得'), findsNothing);
      expect(find.text('聊天紀錄'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
