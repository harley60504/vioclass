import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../api/core/twitch_api_exception.dart';
import '../../models/discovery/twitch_live_stream.dart';
import '../auth/twitch_auth_service.dart';

class TwitchViewerAuthSnapshot {
  final String accessToken;
  final String clientId;
  final String viewerId;
  final String viewerLogin;
  final List<String> scopes;

  const TwitchViewerAuthSnapshot({
    required this.accessToken,
    required this.clientId,
    required this.viewerId,
    required this.viewerLogin,
    required this.scopes,
  });

  bool get canReadFollows => scopes.contains('user:read:follows');
}

class TwitchDiscoveryService {
  final TwitchApiClient client;
  final TwitchAuthService authService;
  final TwitchAuthApiService authApi;

  TwitchViewerAuthSnapshot? _cachedAuth;

  TwitchDiscoveryService({
    required this.client,
    required this.authService,
    required this.authApi,
  });

  TwitchViewerAuthSnapshot? get cachedAuth => _cachedAuth;

  Future<TwitchViewerAuthSnapshot> resolveViewerAuth({
    bool forceValidate = false,
  }) async {
    final cached = _cachedAuth;
    if (!forceValidate &&
        cached != null &&
        cached.accessToken.trim().isNotEmpty) {
      return cached;
    }

    await authService.loadStoredSession();

    final token = await authService.getValidAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw const TwitchApiException('沒有可用 OAuth，請先登入 Twitch。');
    }

    final validation = await authApi.validateToken(token);
    final storedClientId = authService.clientId?.trim();

    final snapshot = TwitchViewerAuthSnapshot(
      accessToken: token,
      clientId: validation.clientId.trim().isNotEmpty
          ? validation.clientId.trim()
          : (storedClientId != null && storedClientId.isNotEmpty
                ? storedClientId
                : TwitchApiConstants.twitchWebClientId),
      viewerId: validation.userId,
      viewerLogin: validation.login,
      scopes: validation.scopes,
    );

    _cachedAuth = snapshot;
    return snapshot;
  }

  Future<TwitchStreamPageResult> fetchFollowedStreams({
    String? after,
    int first = 100,
  }) async {
    final auth = await resolveViewerAuth();

    if (!auth.canReadFollows) {
      throw const TwitchApiException(
        '追隨直播需要 user:read:follows scope，請重新 OAuth 授權。',
      );
    }

    final raw = await client.getJson<Map<String, dynamic>>(
      '${TwitchApiConstants.helixBaseUrl}/streams/followed',
      queryParameters: <String, dynamic>{
        'user_id': auth.viewerId,
        'first': first.clamp(1, 100),
        if (after != null && after.trim().isNotEmpty) 'after': after.trim(),
      },
      headers: _helixHeaders(auth),
    );

    return _parseStreamPage(raw);
  }

  Future<TwitchFollowedChannelPageResult> fetchFollowedChannels({
    String? after,
    int first = 100,
    bool attachProfiles = true,
  }) async {
    final auth = await resolveViewerAuth();

    if (!auth.canReadFollows) {
      throw const TwitchApiException(
        '追隨頻道需要 user:read:follows scope，請重新 OAuth 授權。',
      );
    }

    final raw = await client.getJson<Map<String, dynamic>>(
      '${TwitchApiConstants.helixBaseUrl}/channels/followed',
      queryParameters: <String, dynamic>{
        'user_id': auth.viewerId,
        'first': first.clamp(1, 100),
        if (after != null && after.trim().isNotEmpty) 'after': after.trim(),
      },
      headers: _helixHeaders(auth),
    );

    final page = _parseFollowedChannelPage(raw);
    if (!attachProfiles || page.channels.isEmpty) return page;

    final channels = await _attachFollowedChannelProfiles(
      auth: auth,
      channels: page.channels,
    );
    return TwitchFollowedChannelPageResult(
      channels: channels,
      cursor: page.cursor,
    );
  }

  Future<TwitchStreamPageResult> fetchBrowseStreams({
    String? after,
    String? gameId,
    String? language,
    int first = 100,
  }) async {
    final auth = await resolveViewerAuth();

    final raw = await client.getJson<Map<String, dynamic>>(
      '${TwitchApiConstants.helixBaseUrl}/streams',
      queryParameters: <String, dynamic>{
        'first': first.clamp(1, 100),
        if (after != null && after.trim().isNotEmpty) 'after': after.trim(),
        if (gameId != null && gameId.trim().isNotEmpty)
          'game_id': gameId.trim(),
        if (language != null && language.trim().isNotEmpty)
          'language': language.trim(),
      },
      headers: _helixHeaders(auth),
    );

    return _parseStreamPage(raw);
  }

  Future<TwitchGamePageResult> fetchTopGames({
    String? after,
    int first = 50,
  }) async {
    final auth = await resolveViewerAuth();

    final raw = await client.getJson<Map<String, dynamic>>(
      '${TwitchApiConstants.helixBaseUrl}/games/top',
      queryParameters: <String, dynamic>{
        'first': first.clamp(1, 100),
        if (after != null && after.trim().isNotEmpty) 'after': after.trim(),
      },
      headers: _helixHeaders(auth),
    );

    return _parseGamePage(raw);
  }

  Future<TwitchChannelVideoPageResult> fetchChannelVideos({
    required String userId,
    String? after,
    int first = 20,
    String type = 'archive',
  }) async {
    final auth = await resolveViewerAuth();
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      throw const TwitchApiException('缺少頻道 user id，無法讀取 VOD。');
    }

    final raw = await client.getJson<Map<String, dynamic>>(
      '${TwitchApiConstants.helixBaseUrl}/videos',
      queryParameters: <String, dynamic>{
        'user_id': cleanUserId,
        'first': first.clamp(1, 100),
        'type': type,
        if (after != null && after.trim().isNotEmpty) 'after': after.trim(),
      },
      headers: _helixHeaders(auth),
    );

    return _parseChannelVideoPage(raw);
  }

  Future<TwitchChannelClipPageResult> fetchChannelClips({
    required String broadcasterId,
    String? after,
    int first = 30,
  }) async {
    final auth = await resolveViewerAuth();
    final cleanBroadcasterId = broadcasterId.trim();
    if (cleanBroadcasterId.isEmpty) {
      throw const TwitchApiException('缺少頻道 user id，無法讀取 Clips。');
    }

    final raw = await client.getJson<Map<String, dynamic>>(
      '${TwitchApiConstants.helixBaseUrl}/clips',
      queryParameters: <String, dynamic>{
        'broadcaster_id': cleanBroadcasterId,
        'first': first.clamp(1, 100),
        if (after != null && after.trim().isNotEmpty) 'after': after.trim(),
      },
      headers: _helixHeaders(auth),
    );

    return _parseChannelClipPage(raw);
  }

  Future<TwitchChannelAboutResult> fetchChannelAbout({
    required String login,
  }) async {
    final cleanLogin = login.trim().toLowerCase();
    if (cleanLogin.isEmpty) {
      return const TwitchChannelAboutResult(
        panels: <TwitchChannelPanel>[],
        socialLinks: <TwitchChannelSocialLink>[],
      );
    }

    final raw = await client.postJson<Map<String, dynamic>>(
      TwitchApiConstants.gqlEndpoint,
      data: <String, dynamic>{
        'operationName': 'ChannelPanels',
        'query': '''
query ChannelPanels(\$login: String!) {
  user(login: \$login) {
    panels {
      __typename
      id
      type
      ... on DefaultPanel {
        title
        description
        imageURL
        linkURL
      }
    }
    channel {
      socialMedias {
        name
        title
        url
      }
    }
  }
}
''',
        'variables': <String, dynamic>{'login': cleanLogin},
      },
      headers: <String, String>{
        ...TwitchApiConstants.twitchWebHeaders,
        'Client-ID': TwitchApiConstants.twitchWebClientId,
        'Content-Type': 'application/json',
      },
    );

    final errors = raw['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw TwitchApiException('Twitch panels GQL returned errors.');
    }

    return _parseChannelAbout(raw);
  }

  Future<List<TwitchFollowedChannel>> _attachFollowedChannelProfiles({
    required TwitchViewerAuthSnapshot auth,
    required List<TwitchFollowedChannel> channels,
  }) async {
    final ids = channels
        .map((channel) => channel.broadcasterId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (ids.isEmpty) return channels;

    final profiles = <String, Map<String, String>>{};

    for (var start = 0; start < ids.length; start += 100) {
      final end = (start + 100) > ids.length ? ids.length : start + 100;
      final chunk = ids.sublist(start, end);

      final raw = await client.getJson<Map<String, dynamic>>(
        '${TwitchApiConstants.helixBaseUrl}/users',
        queryParameters: <String, dynamic>{'id': chunk},
        headers: _helixHeaders(auth),
      );

      final data = raw['data'];
      if (data is! List) continue;

      for (final user in data.whereType<Map<String, dynamic>>()) {
        final id = user['id']?.toString().trim() ?? '';
        if (id.isEmpty) continue;
        profiles[id] = <String, String>{
          'profileImageUrl': user['profile_image_url']?.toString().trim() ?? '',
          'offlineImageUrl': user['offline_image_url']?.toString().trim() ?? '',
          'description': user['description']?.toString().trim() ?? '',
        };
      }
    }

    if (profiles.isEmpty) return channels;

    return channels
        .map((channel) {
          final profile = profiles[channel.broadcasterId];
          if (profile == null) return channel;
          return channel.copyWith(
            profileImageUrl: profile['profileImageUrl'],
            offlineImageUrl: profile['offlineImageUrl'],
            description: profile['description'],
          );
        })
        .toList(growable: false);
  }

  Future<Map<String, String>> fetchProfileImagesForLogins(
    Iterable<String> logins,
  ) async {
    final auth = await resolveViewerAuth();
    final cleanLogins = logins
        .map((login) => login.trim().toLowerCase())
        .where((login) => login.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (cleanLogins.isEmpty) return const <String, String>{};

    final output = <String, String>{};

    for (var start = 0; start < cleanLogins.length; start += 100) {
      final end = (start + 100) > cleanLogins.length
          ? cleanLogins.length
          : start + 100;
      final chunk = cleanLogins.sublist(start, end);

      final raw = await client.getJson<Map<String, dynamic>>(
        '${TwitchApiConstants.helixBaseUrl}/users',
        queryParameters: <String, dynamic>{'login': chunk},
        headers: _helixHeaders(auth),
      );

      final data = raw['data'];
      if (data is! List) continue;

      for (final user in data.whereType<Map<String, dynamic>>()) {
        final login = user['login']?.toString().trim().toLowerCase() ?? '';
        final image = user['profile_image_url']?.toString().trim() ?? '';

        if (login.isNotEmpty && image.isNotEmpty) {
          output[login] = image;
        }
      }
    }

    return output;
  }

  TwitchGamePageResult _parseGamePage(Map<String, dynamic> raw) {
    final data = raw['data'];
    final pagination = raw['pagination'];

    final cursor = pagination is Map ? pagination['cursor']?.toString() : null;
    final games = data is List
        ? data
              .whereType<Map<String, dynamic>>()
              .map(TwitchGameCategory.fromHelixJson)
              .where((game) => game.id.isNotEmpty)
              .toList(growable: false)
        : const <TwitchGameCategory>[];

    return TwitchGamePageResult(
      games: games,
      cursor: cursor == null || cursor.trim().isEmpty ? null : cursor,
    );
  }

  TwitchFollowedChannelPageResult _parseFollowedChannelPage(
    Map<String, dynamic> raw,
  ) {
    final data = raw['data'];
    final pagination = raw['pagination'];

    final cursor = pagination is Map ? pagination['cursor']?.toString() : null;
    final channels = data is List
        ? data
              .whereType<Map<String, dynamic>>()
              .map(TwitchFollowedChannel.fromHelixJson)
              .where((channel) => channel.channelLogin.isNotEmpty)
              .toList(growable: false)
        : const <TwitchFollowedChannel>[];

    return TwitchFollowedChannelPageResult(
      channels: channels,
      cursor: cursor == null || cursor.trim().isEmpty ? null : cursor,
    );
  }

  TwitchChannelVideoPageResult _parseChannelVideoPage(
    Map<String, dynamic> raw,
  ) {
    final data = raw['data'];
    final pagination = raw['pagination'];

    final cursor = pagination is Map ? pagination['cursor']?.toString() : null;
    final videos = data is List
        ? data
              .whereType<Map<String, dynamic>>()
              .map(TwitchChannelVideo.fromHelixJson)
              .where((video) => video.id.trim().isNotEmpty)
              .toList(growable: false)
        : const <TwitchChannelVideo>[];

    return TwitchChannelVideoPageResult(
      videos: videos,
      cursor: cursor == null || cursor.trim().isEmpty ? null : cursor,
    );
  }

  TwitchChannelClipPageResult _parseChannelClipPage(
    Map<String, dynamic> raw,
  ) {
    final data = raw['data'];
    final pagination = raw['pagination'];

    final cursor = pagination is Map ? pagination['cursor']?.toString() : null;
    final clips = data is List
        ? data
              .whereType<Map<String, dynamic>>()
              .map(TwitchChannelClip.fromHelixJson)
              .where((clip) => clip.id.trim().isNotEmpty)
              .toList(growable: false)
        : const <TwitchChannelClip>[];

    return TwitchChannelClipPageResult(
      clips: clips,
      cursor: cursor == null || cursor.trim().isEmpty ? null : cursor,
    );
  }

  TwitchChannelAboutResult _parseChannelAbout(Map<String, dynamic> raw) {
    final data = raw['data'];
    final user = data is Map ? data['user'] : null;
    final panels = user is Map ? user['panels'] : null;
    final channel = user is Map ? user['channel'] : null;
    final socialMedias = channel is Map ? channel['socialMedias'] : null;

    final parsedPanels = panels is List
        ? panels
              .whereType<Map<String, dynamic>>()
              .map(TwitchChannelPanel.fromGqlJson)
              .where((panel) => panel.hasContent)
              .toList(growable: false)
        : const <TwitchChannelPanel>[];

    final parsedSocialLinks = socialMedias is List
        ? socialMedias
              .whereType<Map<String, dynamic>>()
              .map(TwitchChannelSocialLink.fromGqlJson)
              .where((link) => link.hasContent)
              .toList(growable: false)
        : const <TwitchChannelSocialLink>[];

    return TwitchChannelAboutResult(
      panels: parsedPanels,
      socialLinks: parsedSocialLinks,
    );
  }

  TwitchStreamPageResult _parseStreamPage(Map<String, dynamic> raw) {
    final data = raw['data'];
    final pagination = raw['pagination'];

    final cursor = pagination is Map ? pagination['cursor']?.toString() : null;
    final streams = data is List
        ? data
              .whereType<Map<String, dynamic>>()
              .map(TwitchLiveStream.fromHelixJson)
              .where((stream) => stream.channelLogin.isNotEmpty)
              .toList(growable: false)
        : const <TwitchLiveStream>[];

    return TwitchStreamPageResult(
      streams: streams,
      cursor: cursor == null || cursor.trim().isEmpty ? null : cursor,
    );
  }

  Map<String, String> _helixHeaders(TwitchViewerAuthSnapshot auth) {
    return <String, String>{
      'Client-ID': auth.clientId,
      'Authorization': 'Bearer ${auth.accessToken}',
    };
  }
}
