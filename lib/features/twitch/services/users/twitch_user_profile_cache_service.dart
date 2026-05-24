// PATCH VERSION: twitch_user_profile_cache_service_stage146
//
// Small in-memory profile cache for avatar/name enrichment. This mirrors the
// Twitch direction: pinned/chat UI should not assume the pinned author is
// the broadcaster; resolve arbitrary users by id/login when avatar is missing.

import '../../api/users/twitch_user_profile_api_service.dart';

class TwitchUserProfileCacheService {
  final TwitchUserProfileApiService api;
  final Duration ttl;

  TwitchUserProfileCacheService({
    required this.api,
    this.ttl = const Duration(minutes: 15),
  });

  final Map<String, _CachedProfile> _byId = <String, _CachedProfile>{};
  final Map<String, _CachedProfile> _byLogin = <String, _CachedProfile>{};

  TwitchUserProfile? lookup({String? id, String? login}) {
    final now = DateTime.now();
    final cleanId = id?.trim() ?? '';
    if (cleanId.isNotEmpty) {
      final cached = _byId[cleanId];
      if (cached != null && !cached.isExpired(now, ttl)) return cached.profile;
    }

    final cleanLogin = login?.trim().toLowerCase() ?? '';
    if (cleanLogin.isNotEmpty) {
      final cached = _byLogin[cleanLogin];
      if (cached != null && !cached.isExpired(now, ttl)) return cached.profile;
    }

    return null;
  }

  Future<TwitchUserProfileLookup> resolveUsers({
    Iterable<String> ids = const <String>[],
    Iterable<String> logins = const <String>[],
  }) async {
    final now = DateTime.now();
    final missingIds = <String>[];
    final missingLogins = <String>[];
    final byId = <String, TwitchUserProfile>{};
    final byLogin = <String, TwitchUserProfile>{};

    for (final id in ids.map((value) => value.trim()).where((value) => value.isNotEmpty).toSet()) {
      final cached = _byId[id];
      if (cached != null && !cached.isExpired(now, ttl)) {
        byId[id] = cached.profile;
      } else {
        missingIds.add(id);
      }
    }

    for (final login in logins
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()) {
      final cached = _byLogin[login];
      if (cached != null && !cached.isExpired(now, ttl)) {
        byLogin[login] = cached.profile;
      } else {
        missingLogins.add(login);
      }
    }

    if (missingIds.isNotEmpty || missingLogins.isNotEmpty) {
      final fetched = await api.fetchUsers(ids: missingIds, logins: missingLogins);
      _storeLookup(fetched);
      byId.addAll(fetched.byId);
      byLogin.addAll(fetched.byLogin);
    }

    return TwitchUserProfileLookup(
      byId: Map<String, TwitchUserProfile>.unmodifiable(byId),
      byLogin: Map<String, TwitchUserProfile>.unmodifiable(byLogin),
    );
  }

  void _storeLookup(TwitchUserProfileLookup lookup) {
    final now = DateTime.now();
    for (final profile in lookup.byId.values) {
      _storeProfile(profile, now);
    }
    for (final profile in lookup.byLogin.values) {
      _storeProfile(profile, now);
    }
  }

  void _storeProfile(TwitchUserProfile profile, DateTime now) {
    final cached = _CachedProfile(profile: profile, fetchedAt: now);
    if (profile.id.isNotEmpty) _byId[profile.id] = cached;
    if (profile.login.isNotEmpty) _byLogin[profile.login] = cached;
  }

  void clear() {
    _byId.clear();
    _byLogin.clear();
  }
}

class _CachedProfile {
  final TwitchUserProfile profile;
  final DateTime fetchedAt;

  const _CachedProfile({
    required this.profile,
    required this.fetchedAt,
  });

  bool isExpired(DateTime now, Duration ttl) {
    return now.difference(fetchedAt) > ttl;
  }
}
