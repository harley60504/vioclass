// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/services/auth/twitch_auth_service.dart';
import '../lib/features/twitch/services/discovery/twitch_discovery_service.dart';
import '../lib/features/twitch/models/discovery/twitch_live_stream.dart';

TwitchLiveStream item(String id) => TwitchLiveStream(
  id: id,
  userId: id,
  userLogin: id,
  userName: id,
  gameId: '',
  gameName: '',
  title: '',
  viewerCount: 1,
  startedAt: null,
  language: '',
  thumbnailUrl: '',
  tags: const [],
  isMature: false,
  profileImageUrl: 'https://example.test/$id.png',
);

class _Discovery extends TwitchDiscoveryService {
  _Discovery(TwitchApiClient client)
    : super(
        client: client,
        authService: TwitchAuthService(apiClient: client),
        authApi: TwitchAuthApiService(client: client),
      );
  final requests = <String?>[];
  bool repeats = false;
  int validations = 0;
  @override
  Future<TwitchViewerAuthSnapshot> resolveViewerAuth({
    bool forceValidate = false,
  }) async {
    if (forceValidate) validations++;
    return const TwitchViewerAuthSnapshot(
      accessToken: 'fixture',
      clientId: 'fixture',
      viewerId: 'viewer',
      viewerLogin: 'viewer',
      scopes: ['user:read:follows'],
    );
  }

  @override
  Future<TwitchStreamPageResult> fetchFollowedStreams({
    String? after,
    int first = 100,
  }) async {
    requests.add(after);
    return TwitchStreamPageResult(
      streams: after == null ? [item('a'), item('b')] : [item('b'), item('c')],
      cursor: after == null || repeats ? 'next' : null,
    );
  }
}

void main() {
  test(
    'Rail snapshot follows all pages, preserves API order and deduplicates users',
    () async {
      final client = TwitchApiClient();
      addTearDown(client.close);
      final service = _Discovery(client);
      final values = await service.fetchFollowedLiveRailStreams();
      expect(values.map((value) => value.userId), ['a', 'b', 'c']);
      expect(service.requests, [null, 'next']);
      expect(service.validations, 1);
      expect(values.every((value) => value.profileImageUrl.isNotEmpty), true);
    },
  );
  test(
    'Repeated cursor fails instead of displaying a partial live snapshot',
    () async {
      final client = TwitchApiClient();
      addTearDown(client.close);
      final service = _Discovery(client)..repeats = true;
      await expectLater(
        service.fetchFollowedLiveRailStreams(),
        throwsException,
      );
      expect(service.requests, [null, 'next']);
    },
  );
}
