import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../api/core/twitch_api_exception.dart';
import '../../models/discovery/twitch_live_stream.dart';

typedef TwitchGuestDiscoveryRequest =
    Future<Map<String, dynamic>> Function({
      required String operationName,
      required String query,
      required Map<String, dynamic> variables,
    });

/// Public discovery queries that intentionally do not send an OAuth token.
///
/// Twitch's web client supports browsing public streams and channels with its
/// public Client-ID. Account-scoped data (follows, points, Drops, whispers,
/// moderation) stays on the authenticated APIs.
class TwitchGuestDiscoveryService {
  final TwitchApiClient client;
  final TwitchGuestDiscoveryRequest? requestOverride;
  final String _deviceId;

  TwitchGuestDiscoveryService({required this.client, this.requestOverride})
    : _deviceId = _newGuestDeviceId(client);

  Future<TwitchStreamPageResult> fetchBrowseStreams({
    String? after,
    String? gameId,
    String? language,
    int first = 100,
  }) async {
    final cleanGameId = gameId?.trim() ?? '';
    final cleanLanguage = language?.trim().toUpperCase() ?? '';
    final raw = await _request(
      operationName: cleanGameId.isEmpty
          ? 'VioClassGuestBrowse'
          : 'VioClassGuestGameBrowse',
      query: cleanGameId.isEmpty ? _browseStreamsQuery : _gameStreamsQuery,
      variables: <String, dynamic>{
        // Twitch's anonymous `streams` connection rejects values above 30,
        // even though the equivalent authenticated Helix endpoint allows 100.
        'first': first.clamp(1, 30),
        'after': _cleanCursor(after),
        'languages': cleanLanguage.isEmpty
            ? const <String>[]
            : <String>[cleanLanguage],
        if (cleanGameId.isNotEmpty) 'gameId': cleanGameId,
      },
    );

    final data = _asMap(raw['data']);
    final connection = cleanGameId.isEmpty
        ? _asMap(data['streams'])
        : _asMap(_asMap(data['game'])['streams']);
    return _parseStreamConnection(connection);
  }

  Future<TwitchLiveStream?> fetchLiveStream({required String login}) async {
    final cleanLogin = login.trim().toLowerCase();
    if (cleanLogin.isEmpty) return null;

    final raw = await _request(
      operationName: 'VioClassGuestLiveChannel',
      query: _liveChannelQuery,
      variables: <String, dynamic>{'login': cleanLogin},
    );
    final user = _asMap(_asMap(raw['data'])['user']);
    final stream = _asMap(user['stream']);
    if (stream.isEmpty) return null;
    return _streamFromGql(stream, broadcasterOverride: user);
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

    final raw = await _request(
      operationName: 'VioClassGuestChannelSearch',
      query: _channelSearchQuery,
      variables: <String, dynamic>{'query': cleanQuery},
    );
    final channels = _asMap(_asMap(raw['data'])['searchFor']);
    final edges = _asList(_asMap(channels['channels'])['edges']);
    final liveStreams = <TwitchLiveStream>[];
    final offlineChannels = <TwitchFollowedChannel>[];

    for (final edgeValue in edges.take(first.clamp(1, 100))) {
      final user = _asMap(_asMap(edgeValue)['item']);
      final login = user['login']?.toString().trim().toLowerCase() ?? '';
      if (login.isEmpty) continue;

      final stream = _asMap(user['stream']);
      if (stream.isNotEmpty) {
        liveStreams.add(_streamFromGql(stream, broadcasterOverride: user));
        continue;
      }

      offlineChannels.add(
        TwitchFollowedChannel(
          broadcasterId: user['id']?.toString().trim() ?? '',
          broadcasterLogin: login,
          broadcasterName:
              user['displayName']?.toString().trim().isNotEmpty == true
              ? user['displayName'].toString().trim()
              : login,
          followedAt: null,
          profileImageUrl: user['profileImageURL']?.toString().trim() ?? '',
          description: user['description']?.toString().trim() ?? '',
        ),
      );
    }

    return TwitchChannelSearchResult(
      liveStreams: liveStreams,
      offlineChannels: offlineChannels,
      cursor: null,
    );
  }

  Future<TwitchGamePageResult> fetchTopGames({
    String? after,
    int first = 50,
  }) async {
    final raw = await _request(
      operationName: 'VioClassGuestTopGames',
      query: _topGamesQuery,
      variables: <String, dynamic>{
        'first': first.clamp(1, 100),
        'after': _cleanCursor(after),
      },
    );
    final connection = _asMap(_asMap(raw['data'])['games']);
    final edges = _asList(connection['edges']);
    final games = <TwitchGameCategory>[];

    for (final edgeValue in edges) {
      final node = _asMap(_asMap(edgeValue)['node']);
      final id = node['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      games.add(
        TwitchGameCategory(
          id: id,
          name: node['name']?.toString().trim() ?? '',
          boxArtUrl: node['boxArtURL']?.toString().trim() ?? '',
        ),
      );
    }

    return TwitchGamePageResult(games: games, cursor: _nextCursor(connection));
  }

  Future<TwitchChannelVideoPageResult> fetchChannelVideos({
    required String userId,
    String? after,
    int first = 20,
    String type = 'archive',
  }) async {
    final videoType = switch (type.trim().toLowerCase()) {
      'archive' => 'ARCHIVE',
      'highlight' => 'HIGHLIGHT',
      'upload' => 'UPLOAD',
      'all' => null,
      _ => throw const TwitchApiException('不支援的錄影類型。'),
    };
    final raw = await _request(
      operationName: 'VioClassGuestChannelVideos',
      query: _channelVideosQuery,
      variables: <String, dynamic>{
        'id': userId.trim(),
        'first': first.clamp(1, 30),
        'after': _cleanCursor(after),
        'type': videoType,
      },
    );
    final user = _asMap(_asMap(raw['data'])['user']);
    final connection = _asMap(user['videos']);
    final videos = <TwitchChannelVideo>[];
    for (final edge in _asList(connection['edges'])) {
      final node = _asMap(_asMap(edge)['node']);
      final id = node['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      videos.add(
        TwitchChannelVideo.fromHelixJson(<String, dynamic>{
          'id': id,
          'user_id': user['id'] ?? userId,
          'user_name': user['displayName'],
          'title': node['title'],
          'description': node['description'],
          'created_at': node['createdAt'],
          'published_at': node['publishedAt'],
          'url': 'https://www.twitch.tv/videos/$id',
          'thumbnail_url': node['previewThumbnailURL'],
          'view_count': node['viewCount'],
          'duration': '${_readInt(node['lengthSeconds'])}s',
          'type': node['broadcastType']?.toString().toLowerCase(),
          'language': node['language']?.toString().toLowerCase(),
        }),
      );
    }
    return TwitchChannelVideoPageResult(
      videos: videos,
      cursor: _nextCursor(connection),
    );
  }

  Future<TwitchChannelClipPageResult> fetchChannelClips({
    required String broadcasterId,
    String? after,
    int first = 30,
  }) async {
    final raw = await _request(
      operationName: 'VioClassGuestChannelClips',
      query: _channelClipsQuery,
      variables: <String, dynamic>{
        'id': broadcasterId.trim(),
        'first': first.clamp(1, 30),
        'after': _cleanCursor(after),
      },
    );
    final connection = _asMap(_asMap(_asMap(raw['data'])['user'])['clips']);
    final clips = <TwitchChannelClip>[];
    for (final edge in _asList(connection['edges'])) {
      final node = _asMap(_asMap(edge)['node']);
      // Playback expects the public slug, not GQL's numeric clip id.
      final slug = node['slug']?.toString().trim() ?? '';
      if (slug.isEmpty) continue;
      final broadcaster = _asMap(node['broadcaster']);
      clips.add(
        TwitchChannelClip.fromHelixJson(<String, dynamic>{
          'id': slug,
          'url': node['url'],
          'embed_url': 'https://clips.twitch.tv/embed?clip=$slug',
          'broadcaster_id': broadcaster['id'] ?? broadcasterId,
          'broadcaster_name': broadcaster['displayName'],
          'creator_name': _asMap(node['curator'])['displayName'],
          'video_id': _asMap(node['video'])['id'],
          'game_id': _asMap(node['game'])['id'],
          'language': node['language']?.toString().toLowerCase(),
          'title': node['title'],
          'view_count': node['viewCount'],
          'created_at': node['createdAt'],
          'thumbnail_url': node['thumbnailURL'],
          'duration': node['durationSeconds'],
          'vod_offset': node['videoOffsetSeconds'] ?? -1,
        }),
      );
    }
    return TwitchChannelClipPageResult(
      clips: clips,
      cursor: _nextCursor(connection),
    );
  }

  Future<Map<String, String>> fetchProfileImagesForLogins(
    Iterable<String> logins,
  ) async {
    final names = logins
        .map((name) => name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final images = <String, String>{};
    for (var start = 0; start < names.length; start += 30) {
      final end = (start + 30).clamp(0, names.length);
      final raw = await _request(
        operationName: 'VioClassGuestProfileImages',
        query: r'''query VioClassGuestProfileImages($logins: [String!]) {
          users(logins: $logins) { login profileImageURL(width: 70) }
        }''',
        variables: <String, dynamic>{'logins': names.sublist(start, end)},
      );
      for (final value in _asList(_asMap(raw['data'])['users'])) {
        final user = _asMap(value);
        final login = user['login']?.toString().trim().toLowerCase() ?? '';
        final image = user['profileImageURL']?.toString().trim() ?? '';
        if (login.isNotEmpty && image.isNotEmpty) images[login] = image;
      }
    }
    return images;
  }

  Future<Map<String, dynamic>> _request({
    required String operationName,
    required String query,
    required Map<String, dynamic> variables,
  }) async {
    final override = requestOverride;
    final raw = override != null
        ? await override(
            operationName: operationName,
            query: query,
            variables: variables,
          )
        : await _postGql(
            operationName: operationName,
            query: query,
            variables: variables,
          );
    final errors = raw['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw TwitchApiException('Twitch 公開探索服務暫時無法使用。', details: errors);
    }
    return raw;
  }

  Future<Map<String, dynamic>> _postGql({
    required String operationName,
    required String query,
    required Map<String, dynamic> variables,
  }) {
    return client.postJson<Map<String, dynamic>>(
      TwitchApiConstants.gqlEndpoint,
      data: <String, dynamic>{
        'operationName': operationName,
        'query': query,
        'variables': variables,
      },
      headers: <String, String>{
        ...TwitchApiConstants.twitchWebHeaders,
        'Client-ID': TwitchApiConstants.twitchAndroidPublicClientId,
        'X-Device-ID': _deviceId,
        'Content-Type': 'application/json',
      },
    );
  }

  TwitchStreamPageResult _parseStreamConnection(
    Map<String, dynamic> connection,
  ) {
    final streams = <TwitchLiveStream>[];
    for (final edgeValue in _asList(connection['edges'])) {
      final node = _asMap(_asMap(edgeValue)['node']);
      if (node.isEmpty) continue;
      final stream = _streamFromGql(node);
      if (stream.channelLogin.isNotEmpty) streams.add(stream);
    }
    return TwitchStreamPageResult(
      streams: streams,
      cursor: _nextCursor(connection),
    );
  }

  TwitchLiveStream _streamFromGql(
    Map<String, dynamic> stream, {
    Map<String, dynamic>? broadcasterOverride,
  }) {
    final broadcaster = broadcasterOverride ?? _asMap(stream['broadcaster']);
    final game = _asMap(stream['game']);
    final login = broadcaster['login']?.toString().trim().toLowerCase() ?? '';
    final displayName = broadcaster['displayName']?.toString().trim() ?? '';
    final tags = _asList(stream['freeformTags'])
        .map(_asMap)
        .map((tag) => tag['name']?.toString().trim() ?? '')
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);

    return TwitchLiveStream(
      id: stream['id']?.toString().trim() ?? '',
      userId: broadcaster['id']?.toString().trim() ?? '',
      userLogin: login,
      userName: displayName.isEmpty ? login : displayName,
      gameId: game['id']?.toString().trim() ?? '',
      gameName: game['name']?.toString().trim() ?? '',
      title: stream['title']?.toString().trim() ?? '',
      viewerCount: _readInt(stream['viewersCount']),
      startedAt: DateTime.tryParse(stream['createdAt']?.toString() ?? ''),
      language: stream['language']?.toString().trim().toLowerCase() ?? '',
      thumbnailUrl: stream['previewImageURL']?.toString().trim() ?? '',
      tags: tags,
      isMature: stream['isMature'] == true,
      profileImageUrl: broadcaster['profileImageURL']?.toString().trim() ?? '',
    );
  }

  String? _nextCursor(Map<String, dynamic> connection) {
    if (_asMap(connection['pageInfo'])['hasNextPage'] != true) return null;
    final edges = _asList(connection['edges']);
    if (edges.isEmpty) return null;
    final cursor = _asMap(edges.last)['cursor']?.toString().trim() ?? '';
    return cursor.isEmpty ? null : cursor;
  }

  String? _cleanCursor(String? value) {
    final clean = value?.trim() ?? '';
    return clean.isEmpty ? null : clean;
  }

  int _readInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _asMap(Object? value) {
    return value is Map<String, dynamic> ? value : <String, dynamic>{};
  }

  List<dynamic> _asList(Object? value) {
    return value is List ? value : const <dynamic>[];
  }
}

String _newGuestDeviceId(Object seed) {
  final value =
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}'
      '${identityHashCode(seed).toRadixString(16)}';
  return value.padRight(32, '0').substring(0, 32);
}

const String _streamFields = r'''
id
title
viewersCount
createdAt
language
previewImageURL(width: 440, height: 248)
isMature
broadcaster {
  id
  login
  displayName
  profileImageURL(width: 70)
}
game {
  id
  name
}
freeformTags {
  name
}
''';

const String _channelVideosQuery = r'''
query VioClassGuestChannelVideos($id: ID!, $first: Int!, $after: Cursor, $type: BroadcastType) {
  user(id: $id) {
    id
    displayName
    videos(first: $first, after: $after, type: $type, sort: TIME) {
      edges {
        cursor
        node {
          id title description createdAt publishedAt lengthSeconds
          viewCount language broadcastType
          previewThumbnailURL(width: 440, height: 248)
        }
      }
      pageInfo { hasNextPage }
    }
  }
}
''';

const String _channelClipsQuery = r'''
query VioClassGuestChannelClips($id: ID!, $first: Int!, $after: Cursor) {
  user(id: $id) {
    clips(first: $first, after: $after, criteria: {period: ALL_TIME}) {
      edges {
        cursor
        node {
          slug url title createdAt durationSeconds viewCount language
          thumbnailURL videoOffsetSeconds
          broadcaster { id displayName }
          curator { displayName }
          video { id }
          game { id }
        }
      }
      pageInfo { hasNextPage }
    }
  }
}
''';

final String _browseStreamsQuery =
    '''
query VioClassGuestBrowse(
  \$first: Int!
  \$after: Cursor
  \$languages: [Language!]
) {
  streams(
    first: \$first
    after: \$after
    options: { sort: VIEWER_COUNT, languages: \$languages }
  ) {
    edges {
      cursor
      node { $_streamFields }
    }
    pageInfo { hasNextPage }
  }
}
''';

final String _gameStreamsQuery =
    '''
query VioClassGuestGameBrowse(
  \$first: Int!
  \$after: Cursor
  \$gameId: ID!
  \$languages: [String!]
) {
  game(id: \$gameId) {
    streams(
      first: \$first
      after: \$after
      options: { sort: VIEWER_COUNT, languages: \$languages }
    ) {
      edges {
        cursor
        node { $_streamFields }
      }
      pageInfo { hasNextPage }
    }
  }
}
''';

final String _liveChannelQuery =
    '''
query VioClassGuestLiveChannel(\$login: String!) {
  user(login: \$login) {
    id
    login
    displayName
    profileImageURL(width: 70)
    stream { $_streamFields }
  }
}
''';

final String _channelSearchQuery =
    '''
query VioClassGuestChannelSearch(\$query: String!) {
  searchFor(userQuery: \$query, platform: "web") {
    channels {
      edges {
        item {
          __typename
          ... on User {
            id
            login
            displayName
            profileImageURL(width: 70)
            description
            stream { $_streamFields }
          }
        }
      }
    }
  }
}
''';

const String _topGamesQuery = r'''
query VioClassGuestTopGames($first: Int!, $after: Cursor) {
  games(first: $first, after: $after) {
    edges {
      cursor
      node {
        id
        name
        boxArtURL(width: 188, height: 250)
      }
    }
    pageInfo { hasNextPage }
  }
}
''';
