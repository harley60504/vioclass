// PATCH VERSION: twitch_user_profile_api_service_stage146
//
// Small Helix user profile resolver used by UI lanes that only have a user id
// or login from GQL/IRC. Keep this generic so pinned chat, message context,
// sheets and discovery widgets can share the same avatar enrichment flow.

import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';

class TwitchUserProfileApiService {
  final TwitchApiClient client;
  final Future<String?> Function() accessTokenProvider;
  final Future<String> Function() clientIdProvider;

  const TwitchUserProfileApiService({
    required this.client,
    required this.accessTokenProvider,
    required this.clientIdProvider,
  });

  Future<TwitchUserProfileLookup> fetchUsers({
    Iterable<String> ids = const <String>[],
    Iterable<String> logins = const <String>[],
  }) async {
    final cleanIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final cleanLogins = logins
        .map((login) => login.trim().toLowerCase())
        .where((login) => login.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (cleanIds.isEmpty && cleanLogins.isEmpty) {
      return const TwitchUserProfileLookup.empty();
    }

    final token = await accessTokenProvider();
    final safeToken = token?.trim() ?? '';
    if (safeToken.isEmpty) return const TwitchUserProfileLookup.empty();

    final clientId = (await clientIdProvider()).trim();
    final safeClientId = clientId.isEmpty
        ? TwitchApiConstants.twitchWebClientId
        : clientId;

    final byId = <String, TwitchUserProfile>{};
    final byLogin = <String, TwitchUserProfile>{};

    Future<void> fetchChunk({
      required List<String> idChunk,
      required List<String> loginChunk,
    }) async {
      if (idChunk.isEmpty && loginChunk.isEmpty) return;

      final raw = await client.getJson<Map<String, dynamic>>(
        '${TwitchApiConstants.helixBaseUrl}/users',
        queryParameters: <String, dynamic>{
          if (idChunk.isNotEmpty) 'id': idChunk,
          if (loginChunk.isNotEmpty) 'login': loginChunk,
        },
        headers: <String, String>{
          'Client-ID': safeClientId,
          'Authorization': 'Bearer $safeToken',
        },
      );

      final data = raw['data'];
      if (data is! List) return;

      for (final item in data.whereType<Map<String, dynamic>>()) {
        final profile = TwitchUserProfile.fromHelixJson(item);
        if (profile.id.isNotEmpty) byId[profile.id] = profile;
        if (profile.login.isNotEmpty) byLogin[profile.login] = profile;
      }
    }

    for (var start = 0; start < cleanIds.length; start += 100) {
      final end = (start + 100) > cleanIds.length ? cleanIds.length : start + 100;
      await fetchChunk(idChunk: cleanIds.sublist(start, end), loginChunk: const <String>[]);
    }

    for (var start = 0; start < cleanLogins.length; start += 100) {
      final end = (start + 100) > cleanLogins.length ? cleanLogins.length : start + 100;
      await fetchChunk(idChunk: const <String>[], loginChunk: cleanLogins.sublist(start, end));
    }

    return TwitchUserProfileLookup(
      byId: Map<String, TwitchUserProfile>.unmodifiable(byId),
      byLogin: Map<String, TwitchUserProfile>.unmodifiable(byLogin),
    );
  }
}

class TwitchUserProfileLookup {
  final Map<String, TwitchUserProfile> byId;
  final Map<String, TwitchUserProfile> byLogin;

  const TwitchUserProfileLookup({
    required this.byId,
    required this.byLogin,
  });

  const TwitchUserProfileLookup.empty()
      : byId = const <String, TwitchUserProfile>{},
        byLogin = const <String, TwitchUserProfile>{};

  TwitchUserProfile? find({String? id, String? login}) {
    final cleanId = id?.trim() ?? '';
    if (cleanId.isNotEmpty) {
      final byIdResult = byId[cleanId];
      if (byIdResult != null) return byIdResult;
    }

    final cleanLogin = login?.trim().toLowerCase() ?? '';
    if (cleanLogin.isNotEmpty) {
      final byLoginResult = byLogin[cleanLogin];
      if (byLoginResult != null) return byLoginResult;
    }

    return null;
  }
}

class TwitchUserProfile {
  final String id;
  final String login;
  final String displayName;
  final String profileImageUrl;

  const TwitchUserProfile({
    required this.id,
    required this.login,
    required this.displayName,
    required this.profileImageUrl,
  });

  factory TwitchUserProfile.fromHelixJson(Map<String, dynamic> json) {
    return TwitchUserProfile(
      id: json['id']?.toString().trim() ?? '',
      login: json['login']?.toString().trim().toLowerCase() ?? '',
      displayName: json['display_name']?.toString().trim() ??
          json['displayName']?.toString().trim() ??
          json['login']?.toString().trim() ??
          '',
      profileImageUrl: json['profile_image_url']?.toString().trim() ??
          json['profileImageUrl']?.toString().trim() ??
          '',
    );
  }
}
