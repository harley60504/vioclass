import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/emotes/twitch_third_party_emote_api_service.dart';
import '../../models/emotes/twitch_third_party_emote.dart';

class TwitchThirdPartyEmoteCacheService extends ChangeNotifier {
  final TwitchThirdPartyEmoteApiService api;

  TwitchThirdPartyEmoteCacheService({
    required this.api,
  }) {
    loadFavoriteEmotes();
    loadRecentEmotes();
  }

  // Stage debug: disable channel memory cache and persistent Recent cache.
  static const bool disableRuntimeEmoteCache = true;
  static const bool disablePersistentRecentCache = true;

  static const String favoriteStorageKey = 'twitch_third_party_favorite_emotes_v1';
  static const String recentStorageKey = 'twitch_third_party_recent_emotes_v1';
  static const int maxRecentEmotes = 80;

  final Map<String, TwitchThirdPartyEmote> _byName = <String, TwitchThirdPartyEmote>{};
  final Map<String, TwitchThirdPartyEmote> _favorites = <String, TwitchThirdPartyEmote>{};
  final Map<String, TwitchThirdPartyEmote> _recent = <String, TwitchThirdPartyEmote>{};

  bool _favoritesLoaded = false;
  bool _recentLoaded = false;
  bool _loading = false;
  Object? _error;
  String _channelId = '';
  String _channelLogin = '';

  bool get loading => _loading;
  Object? get error => _error;
  String get channelId => _channelId;
  String get channelLogin => _channelLogin;
  bool get favoritesLoaded => _favoritesLoaded;
  bool get recentLoaded => _recentLoaded;

  List<TwitchThirdPartyEmote> get emotes {
    final output = _byName.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return output;
  }

  int get count => _byName.length;

  List<TwitchThirdPartyEmote> get favoriteEmotes {
    final output = _favorites.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return output;
  }

  int get favoriteCount => _favorites.length;

  List<TwitchThirdPartyEmote> get recentEmotes {
    return _recent.values.toList(growable: false);
  }

  int get recentCount => _recent.length;

  List<TwitchThirdPartyEmote> emotesForProvider(
    TwitchThirdPartyEmoteProvider provider,
  ) {
    final output = _byName.values
        .where((emote) => emote.provider == provider)
        .toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return output;
  }

  int countForProvider(TwitchThirdPartyEmoteProvider provider) {
    return _byName.values.where((emote) => emote.provider == provider).length;
  }

  bool isFavorite(TwitchThirdPartyEmote emote) {
    return _favorites.containsKey(_favoriteKey(emote));
  }

  void toggleFavorite(TwitchThirdPartyEmote emote) {
    final key = _favoriteKey(emote);

    if (_favorites.containsKey(key)) {
      _favorites.remove(key);
    } else {
      _favorites[key] = emote;
    }

    notifyListeners();
    _saveFavoriteEmotes();
  }

  void markRecentEmote(TwitchThirdPartyEmote emote) {
    if (emote.name.trim().isEmpty || emote.imageUrl.trim().isEmpty) {
      return;
    }

    final key = _favoriteKey(emote);
    final next = <String, TwitchThirdPartyEmote>{key: emote};

    for (final entry in _recent.entries) {
      if (entry.key == key) continue;
      if (next.length >= maxRecentEmotes) break;
      if (entry.value.imageUrl.trim().isEmpty) continue;
      next[entry.key] = entry.value;
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
      final next = <String, TwitchThirdPartyEmote>{};

      if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map) continue;
          final emote = _favoriteFromJson(Map<String, dynamic>.from(item));
          if (emote == null) continue;
          next[_favoriteKey(emote)] = emote;
        }
      }

      _favorites
        ..clear()
        ..addAll(next);
      _refreshFavoriteEmoteSnapshotsFromLoadedEmotes();
    } catch (e) {
      debugPrint('Load third party favorite emotes failed: $e');
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
      debugPrint('Save third party favorite emotes failed: $e');
    }
  }

  Future<void> loadRecentEmotes() async {
    if (disablePersistentRecentCache) {
      _recent.clear();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(recentStorageKey);
      } catch (e) {
        debugPrint('Clear disabled third party recent emote cache failed: $e');
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
        debugPrint('Skip third party recent emote cache save failed: $e');
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
      debugPrint('Clear third party recent emotes failed: $e');
    }
  }

  Future<void> clearFavoriteEmotes() async {
    _favorites.clear();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(favoriteStorageKey);
    } catch (e) {
      debugPrint('Clear third party favorite emotes failed: $e');
    }
  }

  TwitchThirdPartyEmote? lookup(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return null;
    return _byName[clean] ?? _byName[clean.toLowerCase()];
  }

  String _favoriteKey(TwitchThirdPartyEmote emote) {
    return '${emote.provider.name}:${emote.id.isEmpty ? emote.name : emote.id}';
  }

  void _refreshFavoriteEmoteSnapshotsFromLoadedEmotes() {
    if (_favorites.isEmpty || _byName.isEmpty) return;

    final byFavoriteKey = <String, TwitchThirdPartyEmote>{};
    for (final emote in _byName.values) {
      byFavoriteKey[_favoriteKey(emote)] = emote;
    }

    var changed = false;
    final next = <String, TwitchThirdPartyEmote>{};

    for (final entry in _favorites.entries) {
      final updated = byFavoriteKey[entry.key];
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
    if (_recent.isEmpty || _byName.isEmpty) return;

    final byRecentKey = <String, TwitchThirdPartyEmote>{};
    for (final emote in _byName.values) {
      byRecentKey[_favoriteKey(emote)] = emote;
    }

    var changed = false;
    final next = <String, TwitchThirdPartyEmote>{};

    for (final entry in _recent.entries) {
      final updated = byRecentKey[entry.key];
      next[entry.key] = updated ?? entry.value;
      changed = changed || updated != null;
    }

    if (!changed) return;

    _recent
      ..clear()
      ..addAll(next);
  }

  TwitchThirdPartyEmote? _favoriteFromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    final imageUrl = json['imageUrl']?.toString() ?? '';

    if (name.trim().isEmpty || imageUrl.trim().isEmpty) return null;

    final providerName = json['provider']?.toString() ?? '';
    final provider = TwitchThirdPartyEmoteProvider.values.firstWhere(
      (item) => item.name == providerName,
      orElse: () => TwitchThirdPartyEmoteProvider.sevenTv,
    );

    final scopeName = json['scope']?.toString() ?? '';
    final scope = TwitchThirdPartyEmoteScope.values.firstWhere(
      (item) => item.name == scopeName,
      orElse: () => TwitchThirdPartyEmoteScope.other,
    );

    return TwitchThirdPartyEmote(
      id: id,
      name: name,
      imageUrl: imageUrl,
      provider: provider,
      scope: scope,
      isZeroWidth: json['isZeroWidth'] == true,
      width: _readInt(json['width']),
      height: _readInt(json['height']),
    );
  }

  int? _readInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString());
  }

  Future<void> loadForChannel({
    required String channelId,
    required String channelLogin,
  }) async {
    final cid = channelId.trim();
    final login = channelLogin.trim().toLowerCase();

    if (cid.isEmpty) return;

    _loading = true;
    _error = null;
    _channelId = cid;
    _channelLogin = login;
    notifyListeners();

    try {
      final emotes = await api.fetchAll(
        channelId: cid,
        channelLogin: login,
      );

      final next = <String, TwitchThirdPartyEmote>{};
      void put(String key, TwitchThirdPartyEmote emote) {
        final clean = key.trim();
        if (clean.isEmpty) return;
        next[clean] = emote;
      }

      for (final emote in emotes) {
        final name = emote.name.trim();
        if (name.isEmpty || emote.imageUrl.trim().isEmpty) continue;
        put(name, emote);
        put(name.toLowerCase(), emote);
      }

      _byName
        ..clear()
        ..addAll(next);
      _refreshFavoriteEmoteSnapshotsFromLoadedEmotes();
      _refreshRecentEmoteSnapshotsFromLoadedEmotes();
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _byName.clear();
    _loading = false;
    _error = null;
    _channelId = '';
    _channelLogin = '';
    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelId': channelId,
      'channelLogin': channelLogin,
      'count': count,
      'loading': loading,
      'error': error?.toString(),
      'favoriteCount': favoriteCount,
      'favoritesLoaded': favoritesLoaded,
      'recentCount': recentCount,
      'recentLoaded': recentLoaded,
      'persistentRecentCacheDisabled': disablePersistentRecentCache,
      'runtimeEmoteCacheDisabled': disableRuntimeEmoteCache,
      'bttvCount': countForProvider(TwitchThirdPartyEmoteProvider.bttv),
      'sevenTvCount': countForProvider(TwitchThirdPartyEmoteProvider.sevenTv),
      'ffzCount': countForProvider(TwitchThirdPartyEmoteProvider.ffz),
      'scopeSample': emotes.take(40).map((emote) => emote.toJson()).toList(),
    };
  }
}
