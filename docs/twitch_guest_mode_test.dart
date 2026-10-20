// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/presentation/pages/twitch_stream_home_models.dart';
import '../lib/features/twitch/presentation/widgets/home/twitch_stream_home_toolbar.dart';
import '../lib/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_input_section.dart';
import '../lib/features/twitch/services/discovery/twitch_guest_discovery_service.dart';

void main() {
  test('guest browse maps public GQL streams and keeps pagination', () async {
    late Map<String, dynamic> capturedVariables;
    final service = TwitchGuestDiscoveryService(
      client: TwitchApiClient(),
      requestOverride:
          ({
            required String operationName,
            required String query,
            required Map<String, dynamic> variables,
          }) async {
            expect(operationName, 'VioClassGuestBrowse');
            expect(query, contains('streams('));
            capturedVariables = variables;
            return <String, dynamic>{
              'data': <String, dynamic>{
                'streams': <String, dynamic>{
                  'edges': <dynamic>[
                    <String, dynamic>{
                      'cursor': 'next-page',
                      'node': _streamFixture(),
                    },
                  ],
                  'pageInfo': <String, dynamic>{'hasNextPage': true},
                },
              },
            };
          },
    );

    final page = await service.fetchBrowseStreams(language: 'zh', first: 100);

    expect(capturedVariables['languages'], <String>['ZH']);
    expect(capturedVariables['first'], 30);
    expect(page.cursor, 'next-page');
    expect(page.streams, hasLength(1));
    expect(page.streams.single.channelLogin, 'guest_channel');
    expect(page.streams.single.viewerCount, 321);
    expect(page.streams.single.tags, <String>['中文', 'DropsEnabled']);
    expect(page.streams.single.profileImageUrl, 'https://img/profile.png');
  });

  test('guest channel search separates live and offline results', () async {
    final service = TwitchGuestDiscoveryService(
      client: TwitchApiClient(),
      requestOverride:
          ({
            required String operationName,
            required String query,
            required Map<String, dynamic> variables,
          }) async {
            expect(operationName, 'VioClassGuestChannelSearch');
            expect(variables['query'], 'guest');
            return <String, dynamic>{
              'data': <String, dynamic>{
                'searchFor': <String, dynamic>{
                  'channels': <String, dynamic>{
                    'edges': <dynamic>[
                      <String, dynamic>{
                        'item': <String, dynamic>{
                          'id': '42',
                          'login': 'guest_channel',
                          'displayName': 'Guest Channel',
                          'profileImageURL': 'https://img/profile.png',
                          'description': 'Live fixture',
                          'stream': _streamFixture(),
                        },
                      },
                      <String, dynamic>{
                        'item': <String, dynamic>{
                          'id': '77',
                          'login': 'offline_guest',
                          'displayName': 'Offline Guest',
                          'profileImageURL': 'https://img/offline.png',
                          'description': 'Offline fixture',
                          'stream': null,
                        },
                      },
                    ],
                  },
                },
              },
            };
          },
    );

    final result = await service.searchChannels(query: 'guest');
    expect(result.liveStreams.single.channelLogin, 'guest_channel');
    expect(result.offlineChannels.single.channelLogin, 'offline_guest');
    expect(result.offlineChannels.single.description, 'Offline fixture');
  });

  testWidgets('guest chat is visibly read-only and login action is explicit', (
    tester,
  ) async {
    var loginPressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchWatchChatInputSection(
            channelPoints: null,
            runtime: null,
            viewerIsFollowing: false,
            viewerFollowedAt: null,
            messageController: TextEditingController(),
            loadingEmotes: false,
            compact: false,
            enabled: false,
            sending: false,
            readOnlyGuest: true,
            onOpenChannelPoints: () {},
            onOpenEmotes: () {},
            onLoginPressed: () => loginPressed = true,
            onSend: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('訪客模式可讀取聊天室'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('登入'));
    expect(loginPressed, isTrue);
  });

  testWidgets('guest home hides the private-message entry on Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchStreamHomeToolbar(
            selectedSection: TwitchHomeSection.browse,
            onSelectSection: (_) {},
            searchController: TextEditingController(),
            onSearchChanged: (_) {},
            onClearSearch: () {},
            onShowGameMenu: () {},
            onShowLanguageMenu: () {},
            onRefresh: () async {},
            onOpenDropsConnector: () async {},
            onOpenSettings: () async {},
            whispersEnabled: false,
            showSectionSwitcher: false,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('mobile-whispers')), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}

Map<String, dynamic> _streamFixture() => <String, dynamic>{
  'id': 'stream-1',
  'title': 'Public live stream',
  'viewersCount': 321,
  'createdAt': '2026-10-10T01:02:03Z',
  'language': 'ZH',
  'previewImageURL': 'https://img/preview.jpg',
  'isMature': false,
  'broadcaster': <String, dynamic>{
    'id': '42',
    'login': 'guest_channel',
    'displayName': 'Guest Channel',
    'profileImageURL': 'https://img/profile.png',
  },
  'game': <String, dynamic>{'id': 'game-1', 'name': 'Test Game'},
  'freeformTags': <dynamic>[
    <String, dynamic>{'name': '中文'},
    <String, dynamic>{'name': 'DropsEnabled'},
  ],
};
