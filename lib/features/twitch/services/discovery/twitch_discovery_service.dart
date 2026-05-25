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
