// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/services/auth/twitch_auth_service.dart';
import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/services/discovery/twitch_discovery_service.dart';
import '../lib/features/twitch/services/discovery/twitch_guest_discovery_service.dart';

class _GuestSession extends TwitchAuthService {
  _GuestSession(TwitchApiClient client) : super(apiClient: client);
  @override
  String? get accessToken => null;
  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async =>
      null;
}

void main() {
  test(
    'real guest browse and search work without an account token',
    () async {
      final client = TwitchApiClient();
      addTearDown(() => client.close(force: true));
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(
              request.headers.keys.map((key) => key.toLowerCase()),
              isNot(anyOf(contains('authorization'), contains('cookie'))),
            );
            handler.next(request);
          },
        ),
      );
      final service = TwitchGuestDiscoveryService(client: client);
      final browse = await service.fetchBrowseStreams(first: 3);
      expect(browse.streams, isNotEmpty);
      expect(browse.streams.first.channelLogin, isNotEmpty);
      if (browse.cursor != null) {
        final next = await service.fetchBrowseStreams(
          first: 3,
          after: browse.cursor,
        );
        expect(next.streams, isNotEmpty);
      }
      final search = await service.searchChannels(query: 'papaplatte');
      final logins = [
        ...search.liveStreams.map((stream) => stream.channelLogin),
        ...search.offlineChannels.map((channel) => channel.channelLogin),
      ];
      expect(logins, contains('papaplatte'));
      final live = await service.fetchLiveStream(
        login: browse.streams.first.channelLogin,
      );
      // A channel may go offline between the two public requests.
      if (live != null) {
        expect(live.channelLogin, browse.streams.first.channelLogin);
      }
      final games = await service.fetchTopGames(first: 3);
      expect(games.games, isNotEmpty);
    },
    skip: !const bool.fromEnvironment('TWITCH_GUEST_LIVE_TEST'),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('guest DVR preserves archive start, length and pagination', () async {
    final client = TwitchApiClient();
    addTearDown(() => client.close(force: true));
    final start = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    final guest = TwitchGuestDiscoveryService(
      client: client,
      requestOverride:
          ({required operationName, required query, required variables}) async {
            expect(operationName, 'VioClassGuestChannelVideos');
            expect(variables, {
              'id': '42',
              'first': 30,
              'after': 'previous',
              'type': 'ARCHIVE',
            });
            return {
              'data': {
                'user': {
                  'id': '42',
                  'displayName': 'Viewer',
                  'videos': {
                    'edges': [
                      {
                        'cursor': 'next',
                        'node': {
                          'id': '123',
                          'createdAt': start.toIso8601String(),
                          'publishedAt': start.toIso8601String(),
                          'lengthSeconds': 3600,
                          'broadcastType': 'ARCHIVE',
                          'language': 'ZH',
                          'title': 'Live archive',
                          'viewCount': 10,
                          'previewThumbnailURL':
                              'https://example.com/thumb.jpg',
                        },
                      },
                    ],
                    'pageInfo': {'hasNextPage': true},
                  },
                },
              },
            };
          },
    );
    final service = TwitchDiscoveryService(
      client: client,
      authService: _GuestSession(client),
      authApi: TwitchAuthApiService(client: client),
      guestDiscoveryService: guest,
    );
    final page = await service.fetchChannelVideos(
      userId: '42',
      first: 100,
      after: 'previous',
    );
    expect(page.cursor, 'next');
    expect(page.videos.single.parsedDuration, const Duration(hours: 1));
    expect(page.videos.single.isLikelyGrowingArchive, isTrue);
    expect(page.videos.single.url, 'https://www.twitch.tv/videos/123');
    expect(page.videos.single.language, 'zh');
  });

  test('guest clips use playback slug and tolerate missing VOD', () async {
    final client = TwitchApiClient();
    addTearDown(() => client.close(force: true));
    final guest = TwitchGuestDiscoveryService(
      client: client,
      requestOverride:
          ({required operationName, required query, required variables}) async {
            expect(operationName, 'VioClassGuestChannelClips');
            expect(variables['after'], 'previous');
            return {
              'data': {
                'user': {
                  'clips': {
                    'edges': [
                      {
                        'cursor': 'next',
                        'node': {
                          'id': 'numeric-not-playable',
                          'slug': 'PublicClip',
                          'durationSeconds': 12.5,
                          'video': null,
                          'videoOffsetSeconds': null,
                          'broadcaster': {'id': '42', 'displayName': 'Viewer'},
                        },
                      },
                    ],
                    'pageInfo': {'hasNextPage': false},
                  },
                },
              },
            };
          },
    );
    final service = TwitchDiscoveryService(
      client: client,
      authService: _GuestSession(client),
      authApi: TwitchAuthApiService(client: client),
      guestDiscoveryService: guest,
    );
    final page = await service.fetchChannelClips(
      broadcasterId: '42',
      after: 'previous',
    );
    expect(page.clips.single.id, 'PublicClip');
    expect(page.clips.single.duration, 12.5);
    expect(page.clips.single.videoId, isEmpty);
    expect(page.clips.single.vodOffset, -1);
    expect(page.cursor, isNull);
  });

  test('guest unavailable archive is empty, not an OAuth error', () async {
    final client = TwitchApiClient();
    addTearDown(() => client.close(force: true));
    final guest = TwitchGuestDiscoveryService(
      client: client,
      requestOverride:
          ({
            required operationName,
            required query,
            required variables,
          }) async => {
            'data': {
              'user': {
                'videos': {
                  'edges': [],
                  'pageInfo': {'hasNextPage': false},
                },
              },
            },
          },
    );
    expect((await guest.fetchChannelVideos(userId: '42')).videos, isEmpty);
  });

  test(
    'real public media queries never send an account token',
    () async {
      final client = TwitchApiClient();
      addTearDown(() => client.close(force: true));
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(
              request.headers.keys.map((key) => key.toLowerCase()),
              isNot(anyOf(contains('authorization'), contains('cookie'))),
            );
            handler.next(request);
          },
        ),
      );
      final service = TwitchGuestDiscoveryService(client: client);
      for (final id in ['233741947', '50985620', '31239503', '43683025']) {
        final page = await service.fetchChannelVideos(userId: id, first: 1);
        expect(page.videos, isNotEmpty);
        expect(page.videos.single.parsedDuration!.inSeconds, greaterThan(0));
      }
      final clips = await service.fetchChannelClips(
        broadcasterId: '50985620',
        first: 1,
      );
      expect(clips.clips, isNotEmpty);
      final images = await service.fetchProfileImagesForLogins([
        'papaplatte',
        'eslcs',
      ]);
      expect(images.keys, containsAll(['papaplatte', 'eslcs']));
    },
    skip: !const bool.fromEnvironment('TWITCH_GUEST_LIVE_TEST'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
