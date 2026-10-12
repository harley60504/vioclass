// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/chat/twitch_chat_user_appearance_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_chat_user_external_badges_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_chat_badge.dart';
import '../lib/features/twitch/presentation/sheets/twitch_chat_user_profile_sheet.dart';
import 'twitch_chat_user_profile_test.dart' as fixtures;

const ownedBadge = TwitchChatBadge(
  id: 'owned',
  setId: 'special',
  version: '1',
  title: 'Owned extra',
  image1x: '',
  image2x: '',
  image4x: '',
  clickAction: '',
  clickUrl: '',
);

void main() {
  testWidgets(
    'badge collections fill available width and wrap only when full',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final badges = List.generate(
        8,
        (i) => TwitchChatBadge.fromJson({
          'id': 'width-$i',
          'setId': 'width-$i',
          'version': '1',
          'title': 'Width $i',
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchChatUserProfileCard(
              message: fixtures.message('badge-width'),
              messages: [],
              canWhisper: false,
              loadUser: () async => fixtures.profile,
              loadAppearance: () async => TwitchChatUserAppearance(
                earnedBadges: badges,
                sevenTvBadges: [ownedBadge],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getRect(find.byTooltip('Width 0'));
      expect(first.width, 32);
      expect(tester.getRect(find.byTooltip('Width 6')).top, first.top);
      expect(
        tester.getRect(find.byTooltip('Width 7')).top,
        greaterThan(first.top),
      );
      expect(tester.getRect(find.byTooltip('Owned extra')).width, first.width);
      expect(tester.takeException(), isNull);
    },
  );
  final providerFixtures = <String, Object>{
    'FFZ': {
      'badges': [
        {
          'id': 7,
          'title': 'FFZ owned',
          'urls': {'1': '//cdn.example/ffz.png'},
        },
      ],
      'users': {
        '7': [30],
      },
    },
    'BTTV': [
      {
        'providerId': '30',
        'badge': {
          'description': 'BTTV owned',
          'svg': 'https://cdn.example/bttv.svg',
        },
      },
    ],
    'Chatterino': {
      'badges': [
        {
          'tooltip': 'Chatterino owned',
          'image1': 'https://cdn.example/c.png',
          'users': ['30'],
        },
      ],
    },
    'Homies': {
      'badges': [
        {
          'tooltip': 'Homies owned',
          'image1': 'https://cdn.example/h.png',
          'users': ['30'],
        },
      ],
    },
    'Homies staff': {
      'badges': [
        {
          'tooltip': 'Staff owned',
          'image1': 'https://cdn.example/s.png',
          'users': ['30'],
        },
      ],
    },
    'Homies custom': {
      'userId': '30',
      'tooltip': 'Custom owned',
      'image1': 'https://cdn.example/custom.png',
    },
    'Chatsen': [
      {
        'id': 'c',
        'name': 'Chatsen owned',
        'mipmap': ['https://cdn.example/ch.png'],
        'users': ['30'],
      },
    ],
    'Chatty': [
      {
        'id': 'c',
        'meta_title': 'Chatty owned',
        'image_url': 'https://cdn.example/chatty.png',
        'userids': ['30'],
      },
    ],
    'DankChat': [
      {
        'type': 'DankChat owned',
        'url': 'https://cdn.example/dank.png',
        'users': ['30'],
      },
    ],
    'Moltorino': {
      'badges': [
        {
          'id': 'supporter',
          'tooltip': 'Moltorino owned',
          'images': {'1x': 'https://cdn.example/m.webp'},
          'users': [
            {'id': '30'},
          ],
        },
      ],
    },
  };
  for (final fixture in providerFixtures.entries) {
    test('${fixture.key} badge collection is scoped to requested account', () {
      expect(
        TwitchChatUserExternalBadgesApiService.parse(
          fixture.key,
          fixture.value,
          '30',
        ),
        hasLength(1),
      );
      expect(
        TwitchChatUserExternalBadgesApiService.parse(
          fixture.key,
          fixture.value,
          '31',
        ),
        isEmpty,
      );
    });
  }
  test('External feed cache reuses public data across profile opens', () async {
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    var calls = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          calls++;
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: const []),
          );
        },
      ),
    );
    await TwitchChatUserExternalBadgesApiService.load('30', dio);
    await TwitchChatUserExternalBadgesApiService.load('30', dio);
    expect(calls, 10);
  });
  for (final mode in ['complete', '7tv-failure', 'stale']) {
    test(
      'Public profile appearance includes earned collections mode=$mode',
      () async {
        final dio = Dio();
        addTearDown(() => dio.close(force: true));
        var current = true;
        var reads = 0;
        final requests = <RequestOptions>[];
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              reads++;
              requests.add(options);
              if (options.method == 'GET') {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: const [],
                  ),
                );
                return;
              }
              expect(options.method, 'POST');
              expect(
                (options.data as Map)['query'],
                isNot(contains('mutation')),
              );
              expect(
                options.headers.keys.map((key) => key.toLowerCase()),
                isNot(contains(anyOf('authorization', 'cookie'))),
              );
              final twitch = options.uri.host == 'gql.twitch.tv';
              if (mode == '7tv-failure' && !twitch) {
                handler.reject(DioException(requestOptions: options));
                return;
              }
              if (mode == 'stale') current = false;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': twitch
                        ? {
                            'user': {
                              'id': '30',
                              'login': 'peer',
                              'bannerImageURL':
                                  'https://example.test/banner.png',
                              'chatColor': '#ABCDEF',
                              'displayBadges': [
                                {
                                  'setID': 'worn',
                                  'version': '1',
                                  'title': 'Worn',
                                  'imageURL': '',
                                },
                              ],
                            },
                            'own': {
                              'earnedBadges': [
                                {
                                  'setID': 'worn',
                                  'version': '1',
                                  'title': 'Worn',
                                  'imageURL': '',
                                },
                                {
                                  'setID': 'extra',
                                  'version': '1',
                                  'title': 'Extra',
                                  'imageURL': '',
                                },
                              ],
                            },
                            'room': {
                              'earnedBadges': [
                                {
                                  'setID': 'room',
                                  'version': '2',
                                  'title': 'Room',
                                  'imageURL': '',
                                },
                              ],
                            },
                          }
                        : {
                            'users': {
                              'userByConnection': {
                                'style': {
                                  'activePaint': {'id': 'paint'},
                                  'activeProfilePicture': {
                                    'images': [
                                      {
                                        'url': '//cdn.7tv.app/avatar.webp',
                                        'frameCount': 1,
                                      },
                                    ],
                                  },
                                },
                                'inventory': {
                                  'badges': [
                                    {
                                      'to': {
                                        'badge': {
                                          'id': 'badge',
                                          'name': '7TV owned',
                                          'images': [],
                                        },
                                      },
                                    },
                                  ],
                                  'paints': [
                                    {
                                      'to': {
                                        'paint': {
                                          'id': 'paint',
                                          'name': 'Paint',
                                          'data': {
                                            'layers': [
                                              {
                                                'ty': {
                                                  'color': {'hex': '#ABCDEF'},
                                                },
                                              },
                                            ],
                                          },
                                        },
                                      },
                                    },
                                  ],
                                },
                              },
                            },
                          },
                  },
                ),
              );
            },
          ),
        );
        final info = await TwitchChatUserAppearanceApiService(client: dio).load(
          login: 'peer',
          channelLogin: 'room',
          userId: '30',
          isCurrent: () => current,
        );
        expect(reads, 12);
        expect(requests.where((r) => r.method == 'GET'), hasLength(10));
        for (final request in requests) {
          expect(
            request.headers.keys.map((key) => key.toLowerCase()),
            isNot(contains(anyOf('authorization', 'cookie'))),
          );
        }
        if (mode == 'stale') {
          expect(info, isNull);
          return;
        }
        expect(info!.earnedBadges.map((badge) => badge.title), [
          'Worn',
          'Extra',
          'Room',
        ]);
        expect(info.chatColor, '#ABCDEF');
        expect(info.bannerUrl, 'https://example.test/banner.png');
        expect(info.sevenTvBadges.length, mode == 'complete' ? 1 : 0);
        if (mode == 'complete') {
          expect(info.paints.single.active, isTrue);
          expect(info.paints.single.colors, ['#ABCDEF']);
          expect(info.sevenTvAvatar, 'https://cdn.7tv.app/avatar.webp');
        }
      },
    );
  }
  for (final width in [320.0, 1000.0]) {
    testWidgets(
      'Profile shows appearance collection and previews owned badges at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TwitchChatUserProfileCard(
                message: fixtures.message('appearance'),
                messages: const [],
                canWhisper: false,
                loadUser: () async => fixtures.profile,
                loadAppearance: () async => const TwitchChatUserAppearance(
                  chatColor: '#ABCDEF',
                  bannerUrl: 'https://example.test/banner.png',
                  earnedBadges: [ownedBadge],
                  sevenTvBadges: [
                    TwitchChatBadge(
                      id: '7tv',
                      setId: '7tv',
                      version: '1',
                      title: '7TV badge',
                      image1x: '',
                      image2x: '',
                      image4x: '',
                      clickAction: '',
                      clickUrl: '',
                    ),
                  ],
                  paints: [
                    TwitchChatNamePaint(
                      id: 'paint',
                      name: 'Name style',
                      active: true,
                      colors: ['#FF0000', '#0000FF'],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('#ABCDEF'), findsOneWidget);
        expect(find.text('Twitch 徽章收藏'), findsOneWidget);
        expect(find.text('7TV 徽章收藏'), findsOneWidget);
        expect(find.text('Name style'), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('Owned extra'));
        await tester.tap(find.byTooltip('Owned extra'));
        await tester.pumpAndSettle();
        expect(find.text('Owned extra'), findsOneWidget);
        await tester.tap(find.byTooltip('下一個徽章'));
        await tester.pumpAndSettle();
        expect(find.text('7TV badge'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
