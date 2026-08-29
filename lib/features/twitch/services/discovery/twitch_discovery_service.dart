import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../api/core/twitch_api_exception.dart';
import '../../models/discovery/twitch_live_stream.dart';
import '../auth/twitch_auth_service.dart';

typedef TwitchWebTokenProvider = Future<String?> Function();

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
  final TwitchWebTokenProvider? webTokenProvider;

  TwitchViewerAuthSnapshot? _cachedAuth;

  TwitchDiscoveryService({
    required this.client,
    required this.authService,
    required this.authApi,
    this.webTokenProvider,
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

  Future<TwitchChannelSearchResult> searchChannels({
    required String query,
    int first = 40,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return const TwitchChannelSearchResult(
        liveStreams: <TwitchLiveStream>[],
        offlineChannels: <TwitchFollowedChannel>[],
        cursor: null,
      );
    }

    final auth = await resolveViewerAuth();
    final raw = await client.getJson<Map<String, dynamic>>(
      '${TwitchApiConstants.helixBaseUrl}/search/channels',
      queryParameters: <String, dynamic>{
        'query': cleanQuery,
        'first': first.clamp(1, 100),
        'live_only': false,
      },
      headers: _helixHeaders(auth),
    );

    final parsed = _parseChannelSearch(raw);
    final refreshedLiveStreams = parsed.liveStreams.isEmpty
        ? parsed.liveStreams
        : await _fetchLiveStreamsForSearchResult(
            auth: auth,
            fallbackStreams: parsed.liveStreams,
          );
    final liveStreams = refreshedLiveStreams.isEmpty
        ? refreshedLiveStreams
        : await _attachLiveStreamProfiles(
            auth: auth,
            streams: refreshedLiveStreams,
          );
    if (parsed.offlineChannels.isEmpty) {
      return TwitchChannelSearchResult(
        liveStreams: liveStreams,
        offlineChannels: parsed.offlineChannels,
        cursor: parsed.cursor,
      );
    }

    final offlineWithProfiles = await _attachFollowedChannelProfiles(
      auth: auth,
      channels: parsed.offlineChannels,
    );
    return TwitchChannelSearchResult(
      liveStreams: liveStreams,
      offlineChannels: offlineWithProfiles,
      cursor: parsed.cursor,
    );
  }

  Future<List<TwitchTagSuggestion>> searchFreeformTagSuggestions({
    required String query,
    int limit = 20,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const <TwitchTagSuggestion>[];

    final token = (await webTokenProvider?.call())?.trim();
    final raw = await client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': 'SearchFreeformTags',
        'variables': <String, dynamic>{
          'userQuery': cleanQuery,
          'first': limit.clamp(1, 50),
        },
        'query': r'''
query SearchFreeformTags(
  $userQuery: String!
  $first: Int
) {
  searchFreeformTags(
    userQuery: $userQuery
    first: $first
  ) {
    edges {
      node {
        tagName
        __typename
      }
      __typename
    }
    __typename
  }
}
''',
      },
      headers: <String, String>{
        ...TwitchApiConstants.twitchWebHeaders,
        'Accept-Language': 'zh-TW',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        'Client-ID': TwitchApiConstants.twitchWebClientId,
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'OAuth $token',
      },
    );

    if (raw is! Map<String, dynamic>) return const <TwitchTagSuggestion>[];
    final errors = raw['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw TwitchApiException(
        'Twitch tag GQL returned errors.',
        details: errors,
      );
    }

    final data = raw['data'];
    if (data is! Map<String, dynamic>) {
      return const <TwitchTagSuggestion>[];
    }

    final connection = data['searchFreeformTags'];
    if (connection is! Map) return const <TwitchTagSuggestion>[];

    final edges = connection['edges'];
    if (edges is! List) return const <TwitchTagSuggestion>[];

    final seen = <String>{};
    final suggestions = <TwitchTagSuggestion>[];
    for (final edge in edges) {
      if (edge is! Map) continue;
      final node = edge['node'];
      if (node is! Map) continue;
      final tagName = node['tagName']?.toString().trim() ?? '';
      final label = tagName;
      final value = tagName;
      final normalized = value.trim().toLowerCase();
      if (label.isEmpty || normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      suggestions.add(
        TwitchTagSuggestion(id: normalized, label: label, value: normalized),
      );
    }

    return suggestions;
  }

  Future<List<TwitchLiveStream>> _fetchLiveStreamsForSearchResult({
    required TwitchViewerAuthSnapshot auth,
    required List<TwitchLiveStream> fallbackStreams,
  }) async {
    final userIds = fallbackStreams
        .map((stream) => stream.userId.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (userIds.isEmpty) return fallbackStreams;

    try {
      final raw = await client.getJson<Map<String, dynamic>>(
        '${TwitchApiConstants.helixBaseUrl}/streams',
        queryParameters: <String, dynamic>{
          'first': userIds.length.clamp(1, 100),
          'user_id': userIds,
        },
        headers: _helixHeaders(auth),
      );
      final liveByUserId = <String, TwitchLiveStream>{
        for (final stream in _parseStreamPage(raw).streams)
          if (stream.userId.trim().isNotEmpty) stream.userId.trim(): stream,
      };

      return fallbackStreams
          .map((stream) => liveByUserId[stream.userId.trim()] ?? stream)
          .toList(growable: false);
    } catch (_) {
      return fallbackStreams;
    }
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

    final profiles = await _fetchChannelProfilesByIds(auth: auth, ids: ids);

    if (profiles.isEmpty) return channels;

    return channels
        .map((channel) {
          final profile = profiles[channel.broadcasterId];
          if (profile == null) return channel;
          return channel.copyWith(
            profileImageUrl: profile.profileImageUrl,
            offlineImageUrl: profile.offlineImageUrl,
            description: profile.description,
          );
        })
        .toList(growable: false);
  }

  Future<List<TwitchLiveStream>> _attachLiveStreamProfiles({
    required TwitchViewerAuthSnapshot auth,
    required List<TwitchLiveStream> streams,
  }) async {
    final ids = streams
        .where((stream) => stream.profileImageUrl.trim().isEmpty)
        .map((stream) => stream.userId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (ids.isEmpty) return streams;

    final profiles = await _fetchChannelProfilesByIds(auth: auth, ids: ids);

    if (profiles.isEmpty) return streams;

    return streams
        .map(
          (stream) => stream.copyWith(
            profileImageUrl: stream.profileImageUrl.trim().isNotEmpty
                ? stream.profileImageUrl
                : profiles[stream.userId.trim()]?.profileImageUrl ?? '',
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, _TwitchChannelProfile>> _fetchChannelProfilesByIds({
    required TwitchViewerAuthSnapshot auth,
    required List<String> ids,
  }) async {
    final cleanIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (cleanIds.isEmpty) return const <String, _TwitchChannelProfile>{};

    final profiles = <String, _TwitchChannelProfile>{};

    for (var start = 0; start < cleanIds.length; start += 100) {
      final end = (start + 100) > cleanIds.length
          ? cleanIds.length
          : start + 100;
      final chunk = cleanIds.sublist(start, end);

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
        profiles[id] = _TwitchChannelProfile(
          profileImageUrl: user['profile_image_url']?.toString().trim() ?? '',
          offlineImageUrl: user['offline_image_url']?.toString().trim() ?? '',
          description: user['description']?.toString().trim() ?? '',
        );
      }
    }

    return profiles;
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

  TwitchChannelClipPageResult _parseChannelClipPage(Map<String, dynamic> raw) {
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

  TwitchChannelSearchResult _parseChannelSearch(Map<String, dynamic> raw) {
    final data = raw['data'];
    final pagination = raw['pagination'];
    final cursor = pagination is Map ? pagination['cursor']?.toString() : null;
    if (data is! List) {
      return TwitchChannelSearchResult(
        liveStreams: const <TwitchLiveStream>[],
        offlineChannels: const <TwitchFollowedChannel>[],
        cursor: cursor == null || cursor.trim().isEmpty ? null : cursor,
      );
    }

    final liveStreams = <TwitchLiveStream>[];
    final offlineChannels = <TwitchFollowedChannel>[];

    for (final channel in data.whereType<Map<String, dynamic>>()) {
      if (channel['is_live'] == true) {
        final stream = TwitchLiveStream.fromHelixSearchChannelJson(channel);
        if (stream.channelLogin.isNotEmpty) liveStreams.add(stream);
      } else {
        final offline = TwitchFollowedChannel.fromHelixSearchChannelJson(
          channel,
        );
        if (offline.channelLogin.isNotEmpty) offlineChannels.add(offline);
      }
    }

    return TwitchChannelSearchResult(
      liveStreams: liveStreams,
      offlineChannels: offlineChannels,
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

class TwitchTagSuggestion {
  final String id;
  final String label;
  final String value;

  const TwitchTagSuggestion({
    required this.id,
    required this.label,
    required this.value,
  });
}

class _TwitchChannelProfile {
  final String profileImageUrl;
  final String offlineImageUrl;
  final String description;

  const _TwitchChannelProfile({
    required this.profileImageUrl,
    required this.offlineImageUrl,
    required this.description,
  });
}
