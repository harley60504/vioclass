import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/emotes/twitch_official_emote_api_service.dart';
import '../../models/emotes/twitch_official_emote.dart';

typedef TwitchAccessTokenProvider = Future<String?> Function();
typedef TwitchClientIdProvider = Future<String?> Function();

class TwitchOfficialEmoteCacheService extends ChangeNotifier {
  final TwitchOfficialEmoteApiService api;
  final TwitchAccessTokenProvider accessTokenProvider;
  final TwitchClientIdProvider clientIdProvider;

  TwitchOfficialEmoteCacheService({
    required this.api,
    required this.accessTokenProvider,
    required this.clientIdProvider,
  }) {
    loadFavoriteEmotes();
    loadRecentEmotes();
  }

  // Stage debug: disable channel memory cache and persistent Recent cache.
  // This is intentionally left as a constant switch so the cache path can be
  // restored later without changing call sites.
  static const bool disableRuntimeEmoteCache = true;
  static const bool disablePersistentRecentCache = true;

  static const String favoriteStorageKey = 'twitch_official_favorite_emotes_v1';
  static const String recentStorageKey = 'twitch_official_recent_emotes_v1';
  static const int maxRecentEmotes = 80;

  List<TwitchOfficialEmote> _globalEmotes = const <TwitchOfficialEmote>[];
  List<TwitchOfficialEmote> _channelEmotes = const <TwitchOfficialEmote>[];
  List<TwitchOfficialEmote> _userEmotes = const <TwitchOfficialEmote>[];
  List<TwitchOfficialEmote> _lockedChannelEmotes = const <TwitchOfficialEmote>[];
  final Map<String, TwitchOfficialEmote> _favorites = <String, TwitchOfficialEmote>{};
  final Map<String, TwitchOfficialEmote> _recent = <String, TwitchOfficialEmote>{};
  bool _favoritesLoaded = false;
  bool _recentLoaded = false;

  bool _loading = false;
  Object? _error;
  String _channelId = '';
  String _viewerId = '';
  bool _userEmotesUnavailable = false;

  bool get loading => _loading;
  Object? get error => _error;
  String get channelId => _channelId;
  String get viewerId => _viewerId;
  bool get userEmotesUnavailable => _userEmotesUnavailable;
  bool get favoritesLoaded => _favoritesLoaded;
  bool get recentLoaded => _recentLoaded;

  List<TwitchOfficialEmote> get globalEmotes => _globalEmotes;
  List<TwitchOfficialEmote> get channelEmotes => _channelEmotes;
  List<TwitchOfficialEmote> get userEmotes => _userEmotes;
  List<TwitchOfficialEmote> get lockedChannelEmotes => _lockedChannelEmotes;

  List<TwitchOfficialEmote> get favoriteEmotes {
    final output = _favorites.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return output;
  }

  int get favoriteCount => _favorites.length;

  List<TwitchOfficialEmote> get recentEmotes {
    return _recent.values.toList(growable: false);
  }

  int get recentCount => _recent.length;

  List<TwitchOfficialEmote> get allKnownEmotes {
    return _uniqueByName(<TwitchOfficialEmote>[
      ..._globalEmotes,
      ..._channelEmotes,
      ..._userEmotes,
      ..._lockedChannelEmotes,
      ..._recent.values,
      ..._favorites.values,
    ]);
  }

  List<TwitchOfficialEmote> get usableEmotes {
    final byKey = <String, TwitchOfficialEmote>{};

    for (final emote in _globalEmotes) {
      byKey[_key(emote)] = emote;
    }

    for (final emote in _channelEmotes.where((emote) => emote.unlocked)) {
      byKey[_key(emote)] = emote;
    }

    for (final emote in _userEmotes) {
      byKey[_key(emote)] = emote;
    }

    final output = byKey.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return output;
  }

  List<TwitchOfficialEmote> get renderableEmotes {
    return allKnownEmotes;
  }

  List<TwitchOfficialEmote> get nonGlobalUsableEmotes {
    final globalKeys = _globalEmotes.map(_key).toSet();
    final byKey = <String, TwitchOfficialEmote>{};

    for (final emote in _channelEmotes.where((emote) => emote.unlocked)) {
      final key = _key(emote);
      if (globalKeys.contains(key)) continue;
      byKey[key] = emote;
    }

    for (final emote in _userEmotes) {
      final key = _key(emote);
      if (globalKeys.contains(key)) continue;
      byKey[key] = emote;
    }

    final output = byKey.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return output;
  }

  int get visibleCount {
    return allKnownEmotes.length;
  }

  TwitchOfficialEmote? lookupUsableByName(String name) {
    return _lookupByName(name, usableEmotes);
  }

  TwitchOfficialEmote? lookupRenderableByName(String name) {
    return _lookupByName(name, renderableEmotes);
  }

  TwitchOfficialEmote? _lookupByName(
    String name,
    List<TwitchOfficialEmote> source,
  ) {
    final clean = name.trim();
    if (clean.isEmpty) return null;

    TwitchOfficialEmote? caseInsensitiveMatch;
    final lower = clean.toLowerCase();

    for (final emote in source) {
      final emoteName = emote.name.trim();
      if (emoteName.isEmpty || _imageUrlFor(emote).isEmpty) continue;
      if (emoteName == clean) return emote.copyWith(imageUrl: _imageUrlFor(emote));
      if (caseInsensitiveMatch == null && emoteName.toLowerCase() == lower) {
        caseInsensitiveMatch = emote.copyWith(imageUrl: _imageUrlFor(emote));
      }
    }

    return caseInsensitiveMatch;
  }

  bool isUsable(TwitchOfficialEmote emote) {
    if (emote.unlocked) return true;

    final key = _key(emote);
    return _globalEmotes.any((item) => _key(item) == key) ||
        _userEmotes.any((item) => _key(item) == key) ||
        _channelEmotes.any((item) => item.unlocked && _key(item) == key);
  }

  void toggleFavorite(TwitchOfficialEmote emote) {
    final key = _favoriteKey(emote);

    if (_favorites.containsKey(key)) {
      _favorites.remove(key);
    } else {
      _favorites[key] = emote.copyWith(imageUrl: _imageUrlFor(emote));
    }

    notifyListeners();
    _saveFavoriteEmotes();
  }

  bool isFavorite(TwitchOfficialEmote emote) {
    return _favorites.containsKey(_favoriteKey(emote));
  }

  void markRecentEmote(TwitchOfficialEmote emote) {
    final safeImageUrl = _imageUrlFor(emote);
    if (emote.name.trim().isEmpty || safeImageUrl.isEmpty) {
      return;
    }

    final safeEmote = emote.copyWith(imageUrl: safeImageUrl);
    final key = _favoriteKey(safeEmote);
    final next = <String, TwitchOfficialEmote>{key: safeEmote};

    for (final entry in _recent.entries) {
      if (entry.key == key) continue;
      if (next.length >= maxRecentEmotes) break;
      if (_imageUrlFor(entry.value).isEmpty) continue;
      next[entry.key] = entry.value.copyWith(imageUrl: _imageUrlFor(entry.value));
    }

    _recent
      ..clear()
      ..addAll(next);

    notifyListeners();
    _saveRecentEmotes();
  }

  Future<void> loadFavoriteEmotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(favoriteStorageKey);

      if (raw == null || raw.trim().isEmpty) {
        _favoritesLoaded = true;
        notifyListeners();
        return;
      }

      final decoded = jsonDecode(raw);
      final next = <String, TwitchOfficialEmote>{};

      if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map) continue;
          final emote = _favoriteFromJson(Map<String, dynamic>.from(item));
          if (emote == null) continue;
          next[_favoriteKey(emote)] = emote.copyWith(imageUrl: _imageUrlFor(emote));
        }
      }

      _favorites
        ..clear()
        ..addAll(next);
      _refreshFavoriteEmoteSnapshotsFromLoadedEmotes();
    } catch (e) {
      debugPrint('Load official favorite emotes failed: $e');
    } finally {
      _favoritesLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveFavoriteEmotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = favoriteEmotes.map((emote) => emote.toJson()).toList(growable: false);
      await prefs.setString(favoriteStorageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Save official favorite emotes failed: $e');
    }
  }

  Future<void> loadRecentEmotes() async {
    if (disablePersistentRecentCache) {
      _recent.clear();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(recentStorageKey);
      } catch (e) {
        debugPrint('Clear disabled official recent emote cache failed: $e');
      } finally {
        _recentLoaded = true;
        notifyListeners();
      }
      return;
    }
  }

  Future<void> _saveRecentEmotes() async {
    if (disablePersistentRecentCache) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(recentStorageKey);
      } catch (e) {
        debugPrint('Skip official recent emote cache save failed: $e');
      }
      return;
    }
  }

  Future<void> clearRecentEmotes() async {
    _recent.clear();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(recentStorageKey);
    } catch (e) {
      debugPrint('Clear official recent emotes failed: $e');
    }
  }

  Future<void> clearFavoriteEmotes() async {
    _favorites.clear();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(favoriteStorageKey);
    } catch (e) {
      debugPrint('Clear official favorite emotes failed: $e');
    }
  }

  Future<void> loadForChannel({
    required String channelId,
    required String viewerId,
    bool forceRefresh = false,
  }) async {
    final cleanChannelId = channelId.trim();
    final cleanViewerId = viewerId.trim();

    if (cleanChannelId.isEmpty) return;

    _loading = true;
    _error = null;
    _userEmotesUnavailable = false;
    _channelId = cleanChannelId;
    _viewerId = cleanViewerId;
    notifyListeners();

    try {
      final accessToken = await accessTokenProvider();
      final clientId = await clientIdProvider();

      if (accessToken == null ||
          accessToken.trim().isEmpty ||
          clientId == null ||
          clientId.trim().isEmpty) {
        _globalEmotes = const <TwitchOfficialEmote>[];
        _channelEmotes = const <TwitchOfficialEmote>[];
        _userEmotes = const <TwitchOfficialEmote>[];
        _lockedChannelEmotes = const <TwitchOfficialEmote>[];
        return;
      }

      final results = await Future.wait<List<TwitchOfficialEmote>>(
        <Future<List<TwitchOfficialEmote>>>[
          api.fetchGlobalEmotes(
            accessToken: accessToken,
            clientId: clientId,
          ).catchError((_) => <TwitchOfficialEmote>[]),
          api.fetchChannelEmotes(
            broadcasterId: cleanChannelId,
            accessToken: accessToken,
            clientId: clientId,
          ).catchError((_) => <TwitchOfficialEmote>[]),
          _fetchUserEmotesSafe(
            userId: cleanViewerId,
            accessToken: accessToken,
            clientId: clientId,
          ),
        ],
      );

      final global = _unique(results[0], unlocked: true);
      final rawUser = _unique(results[2], unlocked: true);
      final ownerNames = await _fetchOwnerDisplayNamesSafe(
        userEmotes: rawUser,
        accessToken: accessToken,
        clientId: clientId,
      );
      final user = _applyOwnerDisplayNames(rawUser, ownerNames);
      final userKeys = user.map(_key).toSet();
      final globalKeys = global.map(_key).toSet();

      final channel = <TwitchOfficialEmote>[];
      final locked = <TwitchOfficialEmote>[];

      for (final emote in _unique(results[1], unlocked: false)) {
        final key = _key(emote);
        final unlocked = globalKeys.contains(key) || userKeys.contains(key);

        final normalized = emote.copyWith(
          source: TwitchOfficialEmoteSource.channel,
          unlocked: unlocked,
          imageUrl: _imageUrlFor(emote),
        );

        channel.add(normalized);
        if (!unlocked) {
          locked.add(normalized);
        }
      }

      channel.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      locked.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      _globalEmotes = _unique(global, unlocked: true);
      _channelEmotes = channel;
      _userEmotes = _unique(user, unlocked: true);
      _lockedChannelEmotes = locked;
      _refreshFavoriteEmoteSnapshotsFromLoadedEmotes();
      _refreshRecentEmoteSnapshotsFromLoadedEmotes();
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<List<TwitchOfficialEmote>> _fetchUserEmotesSafe({
    required String userId,
    required String accessToken,
    required String clientId,
  }) async {
    if (userId.trim().isEmpty) return const <TwitchOfficialEmote>[];

    try {
      return await api.fetchUserEmotes(
        userId: userId,
        accessToken: accessToken,
        clientId: clientId,
      );
    } catch (_) {
      _userEmotesUnavailable = true;
      return const <TwitchOfficialEmote>[];
    }
  }

  Future<Map<String, String>> _fetchOwnerDisplayNamesSafe({
    required List<TwitchOfficialEmote> userEmotes,
    required String accessToken,
    required String clientId,
  }) async {
    final ownerIds = userEmotes
        .map((emote) => emote.ownerId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (ownerIds.isEmpty) return const <String, String>{};

    try {
      return await api.fetchUserDisplayNamesByIds(
        userIds: ownerIds,
        accessToken: accessToken,
        clientId: clientId,
      );
    } catch (e) {
      debugPrint('Fetch official emote owner display names failed: $e');
      return const <String, String>{};
    }
  }

  List<TwitchOfficialEmote> _applyOwnerDisplayNames(
    List<TwitchOfficialEmote> source,
    Map<String, String> ownerNames,
  ) {
    if (source.isEmpty || ownerNames.isEmpty) return source;

    return source
        .map((emote) {
          final ownerName = ownerNames[emote.ownerId.trim()]?.trim() ?? '';
          final base = emote.copyWith(imageUrl: _imageUrlFor(emote));
          if (ownerName.isEmpty) return base;
          return base.copyWith(ownerDisplayName: ownerName);
        })
        .toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<TwitchOfficialEmote> _unique(
    List<TwitchOfficialEmote> source, {
    required bool unlocked,
  }) {
    final byKey = <String, TwitchOfficialEmote>{};

    for (final emote in source) {
      if (emote.name.trim().isEmpty || _imageUrlFor(emote).isEmpty) continue;

      byKey[_key(emote)] = emote.copyWith(
        imageUrl: _imageUrlFor(emote),
        unlocked: unlocked || emote.unlocked,
      );
    }

    final output = byKey.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return output;
  }

  List<TwitchOfficialEmote> _uniqueByName(
    Iterable<TwitchOfficialEmote> source,
  ) {
    final byName = <String, TwitchOfficialEmote>{};

    for (final emote in source) {
      final name = emote.name.trim();
      final imageUrl = _imageUrlFor(emote);
      if (name.isEmpty || imageUrl.isEmpty) continue;
      byName.putIfAbsent(name, () => emote.copyWith(imageUrl: imageUrl));
    }

    final output = byName.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return output;
  }

  String _imageUrlFor(TwitchOfficialEmote emote) {
    final direct = emote.imageUrl.trim();
    if (direct.isNotEmpty) return direct;

    final id = emote.id.trim();
    if (id.isEmpty) return '';
    return 'https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0';
  }

  String _favoriteKey(TwitchOfficialEmote emote) {
    final id = emote.id.trim();
    if (id.isNotEmpty) return 'id:$id';
    return 'name:${emote.name.trim().toLowerCase()}';
  }

  void _refreshFavoriteEmoteSnapshotsFromLoadedEmotes() {
    if (_favorites.isEmpty) return;

    final available = <String, TwitchOfficialEmote>{};
    for (final emote in allKnownEmotes) {
      available[_favoriteKey(emote)] = emote;
    }

    if (available.isEmpty) return;

    var changed = false;
    final next = <String, TwitchOfficialEmote>{};

    for (final entry in _favorites.entries) {
      final updated = available[entry.key];
      next[entry.key] = updated ?? entry.value;
      changed = changed || updated != null;
    }

    if (!changed) return;

    _favorites
      ..clear()
      ..addAll(next);
    _saveFavoriteEmotes();
  }

  void _refreshRecentEmoteSnapshotsFromLoadedEmotes() {
    if (_recent.isEmpty) return;

    final available = <String, TwitchOfficialEmote>{};
    for (final emote in allKnownEmotes) {
      available[_favoriteKey(emote)] = emote;
    }

    if (available.isEmpty) return;

    var changed = false;
    final next = <String, TwitchOfficialEmote>{};

    for (final entry in _recent.entries) {
      final updated = available[entry.key];
      next[entry.key] = updated ?? entry.value;
      changed = changed || updated != null;
    }

    if (!changed) return;

    _recent
      ..clear()
      ..addAll(next);
  }

  TwitchOfficialEmote? _favoriteFromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    final imageUrl = json['imageUrl']?.toString() ?? '';

    if (name.trim().isEmpty && id.trim().isEmpty) return null;

    final sourceName = json['source']?.toString() ?? TwitchOfficialEmoteSource.global.name;
    final source = TwitchOfficialEmoteSource.values.firstWhere(
      (item) => item.name == sourceName,
      orElse: () => TwitchOfficialEmoteSource.global,
    );

    final emote = TwitchOfficialEmote(
      id: id,
      name: name,
      imageUrl: imageUrl,
      emoteType: json['emoteType']?.toString() ?? '',
      tier: json['tier']?.toString() ?? '',
      emoteSetId: json['emoteSetId']?.toString() ?? '',
      ownerId: json['ownerId']?.toString() ?? '',
      ownerDisplayName: json['ownerDisplayName']?.toString() ?? '',
      source: source,
      unlocked: json['unlocked'] == true,
    );

    if (emote.name.trim().isEmpty || _imageUrlFor(emote).isEmpty) return null;
    return emote.copyWith(imageUrl: _imageUrlFor(emote));
  }

  String _key(TwitchOfficialEmote emote) {
    if (emote.id.trim().isNotEmpty) return 'id:${emote.id.trim()}';
    return 'name:${emote.name.trim().toLowerCase()}';
  }

  void clear() {
    _globalEmotes = const <TwitchOfficialEmote>[];
    _channelEmotes = const <TwitchOfficialEmote>[];
    _userEmotes = const <TwitchOfficialEmote>[];
    _lockedChannelEmotes = const <TwitchOfficialEmote>[];
    _loading = false;
    _error = null;
    _channelId = '';
    _viewerId = '';
    _userEmotesUnavailable = false;
    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelId': channelId,
      'viewerId': viewerId,
      'loading': loading,
      'error': error?.toString(),
      'globalCount': globalEmotes.length,
      'channelCount': channelEmotes.length,
      'userCount': userEmotes.length,
      'lockedCount': lockedChannelEmotes.length,
      'allKnownCount': allKnownEmotes.length,
      'usableCount': usableEmotes.length,
      'renderableCount': renderableEmotes.length,
      'nonGlobalUsableCount': nonGlobalUsableEmotes.length,
      'favoriteCount': favoriteCount,
      'favoritesLoaded': favoritesLoaded,
      'recentCount': recentCount,
      'recentLoaded': recentLoaded,
      'persistentRecentCacheDisabled': disablePersistentRecentCache,
      'runtimeEmoteCacheDisabled': disableRuntimeEmoteCache,
      'userEmotesUnavailable': userEmotesUnavailable,
      'channelSample': channelEmotes
          .take(20)
          .map((emote) => <String, dynamic>{
                'name': emote.name,
                'id': emote.id,
                'imageUrl': emote.imageUrl,
                'locked': emote.locked,
                'emoteType': emote.emoteType,
              })
          .toList(growable: false),
      'userOwnerSample': userEmotes
          .take(20)
          .map((emote) => <String, dynamic>{
                'name': emote.name,
                'ownerId': emote.ownerId,
                'ownerDisplayName': emote.ownerDisplayName,
                'emoteType': emote.emoteType,
              })
          .toList(growable: false),
    };
  }
}
