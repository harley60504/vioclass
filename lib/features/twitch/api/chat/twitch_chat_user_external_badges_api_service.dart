import 'dart:convert';
import 'package:dio/dio.dart';
import '../../models/chat/twitch_chat_badge.dart';

class TwitchChatUserExternalBadgesApiService {
  static final _cache = <String, ({DateTime expires, Object data})>{};
  static final _pending = <String, Future<Object?>>{};
  static final _retryAfter = <String, DateTime>{};
  static const _feeds = {
    'FFZ': 'https://api.frankerfacez.com/v1/badges/ids',
    'BTTV': 'https://api.betterttv.net/3/cached/badges',
    'Chatterino': 'https://api.chatterino.com/badges',
    'Homies': 'https://itzalex.github.io/badges',
    'Homies staff': 'https://itzalex.github.io/badges2',
    'Chatsen': 'https://api.chatsen.app/account/badges',
    'Chatty': 'https://tduva.com/res/badges',
    'DankChat': 'https://flxrs.com/api/badges',
    'Moltorino': 'https://api.moltorino.com/badges',
  };

  static Future<Map<String, List<TwitchChatBadge>>> load(
    String userId,
    Dio http, {
    bool cache = true,
  }) async {
    final output = <String, List<TwitchChatBadge>>{};
    final feeds = {
      ..._feeds,
      'Homies custom': 'https://chatterinohomies.com/api/v2/badges/$userId',
    };
    await Future.wait(
      feeds.entries.map((entry) async {
        final badges = parse(
          entry.key,
          await _read(entry.value, http, cache),
          userId,
        );
        if (badges.isNotEmpty) output[entry.key] = badges;
      }),
    );
    return {
      for (final source in feeds.keys)
        if (output[source] != null) source: output[source]!,
    };
  }

  static Future<Object?> _read(String url, Dio http, bool cache) async {
    final now = DateTime.now();
    final saved = _cache[url];
    if (cache && saved != null && saved.expires.isAfter(now)) return saved.data;
    if (cache && _retryAfter[url]?.isAfter(now) == true) return saved?.data;
    if (cache && _pending[url] != null) return _pending[url]!;
    Future<Object?> request() async {
      try {
        final response = await http
            .get<dynamic>(
              url,
              options: Options(
                headers: {
                  'User-Agent': 'VioClass public profile badges',
                  'Accept': 'application/json',
                },
              ),
            )
            .timeout(const Duration(seconds: 2));
        final data = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        if (data is! Map && data is! List) return saved?.data;
        if (cache) {
          _cache[url] = (
            expires: now.add(const Duration(minutes: 10)),
            data: data as Object,
          );
          while (_cache.length > 128) {
            _cache.remove(_cache.keys.first);
          }
          _retryAfter.remove(url);
        }
        return data as Object;
      } catch (_) {
        if (cache) _retryAfter[url] = now.add(const Duration(minutes: 1));
        return saved?.data;
      }
    }

    final future = request();
    if (cache) _pending[url] = future;
    try {
      return await future;
    } finally {
      if (cache) _pending.remove(url);
    }
  }

  static List<TwitchChatBadge> parse(
    String provider,
    dynamic data,
    String userId,
  ) {
    if (data is! Map && data is! List) return const [];
    final list = data is List
        ? data
        : data['badges'] is List
        ? data['badges'] as List
        : [data];
    final result = <TwitchChatBadge>[];
    final seen = <String>{};
    for (final row in list.whereType<Map>()) {
      final members = row['users'] ?? row['userids'];
      var mine =
          members is List &&
          members.any(
            (value) =>
                (value is Map ? value['id'] : value)?.toString() == userId,
          );
      if (provider == 'FFZ' && data is Map && data['users'] is Map) {
        final holders = data['users'][row['id']?.toString()];
        mine = holders is List && holders.any((id) => id.toString() == userId);
      }
      if (provider == 'BTTV') mine = row['providerId']?.toString() == userId;
      if (provider == 'Homies custom') {
        mine = row['userId']?.toString() == userId;
      }
      if (!mine) continue;
      final badge = row['badge'] is Map ? row['badge'] as Map : row;
      final urls = badge['urls'] is Map
          ? badge['urls'] as Map
          : badge['images'] is Map
          ? badge['images'] as Map
          : const {};
      final mipmap = badge['mipmap'];
      var url =
          (urls['4'] ??
                  urls['3x'] ??
                  urls['2'] ??
                  urls['2x'] ??
                  urls['1'] ??
                  urls['1x'] ??
                  badge['svg'] ??
                  badge['image_url_4'] ??
                  badge['image_url'] ??
                  badge['image3'] ??
                  badge['image1'] ??
                  badge['url'] ??
                  (mipmap is List && mipmap.isNotEmpty ? mipmap.first : null))
              ?.toString() ??
          '';
      if (url.startsWith('//')) url = 'https:$url';
      final uri = Uri.tryParse(url);
      if (uri?.scheme != 'https' || uri!.host.isEmpty) continue;
      final title =
          (badge['title'] ??
                  badge['tooltip'] ??
                  badge['meta_title'] ??
                  badge['description'] ??
                  badge['name'] ??
                  badge['type'] ??
                  badge['id'] ??
                  provider)
              .toString();
      if (!seen.add('$title/$url')) continue;
      result.add(
        TwitchChatBadge(
          id: '$provider-${result.length}',
          setId: provider,
          version: '1',
          title: title,
          image1x: url,
          image2x: url,
          image4x: url,
          clickAction: '',
          clickUrl: '',
        ),
      );
      if (provider == 'Moltorino') break;
    }
    return result;
  }
}
