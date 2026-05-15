import '../../models/emotes/twitch_third_party_emote.dart';
import '../core/twitch_api_client.dart';

class TwitchThirdPartyEmoteApiService {
  final TwitchApiClient client;

  const TwitchThirdPartyEmoteApiService({
    required this.client,
  });

  Future<List<TwitchThirdPartyEmote>> fetchAll({
    required String channelId,
    required String channelLogin,
  }) async {
    final results = await Future.wait<List<TwitchThirdPartyEmote>>(
      <Future<List<TwitchThirdPartyEmote>>>[
        fetchBttvGlobal().catchError((_) => <TwitchThirdPartyEmote>[]),
        fetchBttvChannel(channelId: channelId).catchError((_) => <TwitchThirdPartyEmote>[]),
        fetchFfzGlobal().catchError((_) => <TwitchThirdPartyEmote>[]),
        fetchFfzChannel(channelId: channelId, channelLogin: channelLogin).catchError((_) => <TwitchThirdPartyEmote>[]),
        fetchSevenTvGlobal().catchError((_) => <TwitchThirdPartyEmote>[]),
        fetchSevenTvChannel(channelId: channelId).catchError((_) => <TwitchThirdPartyEmote>[]),
      ],
    );

    final byName = <String, TwitchThirdPartyEmote>{};

    // Later providers overwrite earlier providers when names collide. This is
    // close enough for a first client-style cache and avoids rendering duplicate
    // emotes for the same token.
    for (final group in results) {
      for (final emote in group) {
        if (emote.name.trim().isEmpty || emote.imageUrl.trim().isEmpty) continue;
        // StreamNook-style priority when names collide: 7TV > FFZ > BTTV.
        byName[emote.name] = emote;
      }
    }

    final output = byName.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return output;
  }

  Future<List<TwitchThirdPartyEmote>> fetchBttvGlobal() async {
    final raw = await client.getJson<dynamic>(
      'https://api.betterttv.net/3/cached/emotes/global',
    );

    if (raw is! List) return const <TwitchThirdPartyEmote>[];

    return raw
        .whereType<Map<String, dynamic>>()
        .map(_bttvFromJson)
        .where((emote) => emote.name.isNotEmpty && emote.imageUrl.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<TwitchThirdPartyEmote>> fetchBttvChannel({
    required String channelId,
  }) async {
    final raw = await client.getJson<dynamic>(
      'https://api.betterttv.net/3/cached/users/twitch/$channelId',
    );

    if (raw is! Map<String, dynamic>) return const <TwitchThirdPartyEmote>[];

    final output = <TwitchThirdPartyEmote>[];
    final channelEmotes = raw['channelEmotes'];
    final sharedEmotes = raw['sharedEmotes'];

    if (channelEmotes is List) {
      output.addAll(
        channelEmotes.whereType<Map<String, dynamic>>().map(_bttvFromJson),
      );
    }

    if (sharedEmotes is List) {
      output.addAll(
        sharedEmotes.whereType<Map<String, dynamic>>().map(_bttvFromJson),
      );
    }

    return output
        .where((emote) => emote.name.isNotEmpty && emote.imageUrl.isNotEmpty)
        .toList(growable: false);
  }

  TwitchThirdPartyEmote _bttvFromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final code = json['code']?.toString() ?? '';
    return TwitchThirdPartyEmote(
      id: id,
      name: code,
      imageUrl: id.isEmpty
          ? ''
          : 'https://cdn.betterttv.net/emote/$id/2x',
      provider: TwitchThirdPartyEmoteProvider.bttv,
      isZeroWidth: json['modifier'] == true,
    );
  }

  Future<List<TwitchThirdPartyEmote>> fetchFfzGlobal() async {
    final raw = await client.getJson<dynamic>(
      'https://api.frankerfacez.com/v1/set/global',
    );

    return _ffzFromRoot(raw);
  }

  Future<List<TwitchThirdPartyEmote>> fetchFfzChannel({
    required String channelId,
    required String channelLogin,
  }) async {
    final login = channelLogin.trim().toLowerCase();

    if (login.isNotEmpty) {
      try {
        final raw = await client.getJson<dynamic>(
          'https://api.frankerfacez.com/v1/room/$login',
        );

        final parsed = _ffzFromRoot(raw);
        if (parsed.isNotEmpty) return parsed;
      } catch (_) {
        // Fallback to id endpoint below.
      }
    }

    final raw = await client.getJson<dynamic>(
      'https://api.frankerfacez.com/v1/room/id/$channelId',
    );

    return _ffzFromRoot(raw);
  }

  List<TwitchThirdPartyEmote> _ffzFromRoot(dynamic raw) {
    if (raw is! Map<String, dynamic>) return const <TwitchThirdPartyEmote>[];

    final sets = raw['sets'];
    if (sets is! Map) return const <TwitchThirdPartyEmote>[];

    final output = <TwitchThirdPartyEmote>[];

    for (final value in sets.values) {
      if (value is! Map<String, dynamic>) continue;

      final emoticons = value['emoticons'];
      if (emoticons is! List) continue;

      for (final item in emoticons.whereType<Map<String, dynamic>>()) {
        final id = item['id']?.toString() ?? '';
        final name = item['name']?.toString() ?? '';
        final urls = item['urls'];

        String imageUrl = '';
        if (urls is Map) {
          imageUrl = (urls['2'] ?? urls['1'] ?? urls['4'])?.toString() ?? '';
          if (imageUrl.startsWith('//')) {
            imageUrl = 'https:$imageUrl';
          }
        }

        output.add(
          TwitchThirdPartyEmote(
            id: id,
            name: name,
            imageUrl: imageUrl,
            provider: TwitchThirdPartyEmoteProvider.ffz,
          ),
        );
      }
    }

    return output
        .where((emote) => emote.name.isNotEmpty && emote.imageUrl.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<TwitchThirdPartyEmote>> fetchSevenTvGlobal() async {
    final raw = await client.getJson<dynamic>(
      'https://7tv.io/v3/emote-sets/global',
    );

    return _sevenTvFromEmoteSet(raw);
  }

  Future<List<TwitchThirdPartyEmote>> fetchSevenTvChannel({
    required String channelId,
  }) async {
    final raw = await client.getJson<dynamic>(
      'https://7tv.io/v3/users/twitch/$channelId',
    );

    if (raw is! Map<String, dynamic>) return const <TwitchThirdPartyEmote>[];

    return _sevenTvFromEmoteSet(raw['emote_set']);
  }

  List<TwitchThirdPartyEmote> _sevenTvFromEmoteSet(dynamic raw) {
    if (raw is! Map<String, dynamic>) return const <TwitchThirdPartyEmote>[];

    final emotes = raw['emotes'];
    if (emotes is! List) return const <TwitchThirdPartyEmote>[];

    final output = <TwitchThirdPartyEmote>[];

    for (final item in emotes.whereType<Map<String, dynamic>>()) {
      final id = item['id']?.toString() ?? '';
      final name = item['name']?.toString() ?? '';
      final flags = _readInt(item['flags']) ?? 0;
      final data = item['data'];
      final dataMap = data is Map<String, dynamic> ? data : <String, dynamic>{};

      final host = dataMap['host'];
      final hostMap = host is Map<String, dynamic> ? host : <String, dynamic>{};

      var imageUrl = '';

      final files = hostMap['files'];
      if (files is List && files.isNotEmpty) {
        final candidates = files.whereType<Map<String, dynamic>>().toList();
        candidates.sort((a, b) {
          final aWidth = _readInt(a['width']) ?? 0;
          final bWidth = _readInt(b['width']) ?? 0;
          return bWidth.compareTo(aWidth);
        });

        final selected = candidates.firstWhere(
          (file) => (file['format']?.toString().toLowerCase() ?? '') == 'webp',
          orElse: () => candidates.first,
        );

        final fileName = selected['name']?.toString() ?? '';
        final url = hostMap['url']?.toString() ?? '';

        if (url.isNotEmpty && fileName.isNotEmpty) {
          imageUrl = 'https:$url/$fileName';
        }
      }

      if (imageUrl.isEmpty && id.isNotEmpty) {
        imageUrl = 'https://cdn.7tv.app/emote/$id/2x.avif';
      }

      output.add(
        TwitchThirdPartyEmote(
          id: id,
          name: name,
          imageUrl: imageUrl,
          provider: TwitchThirdPartyEmoteProvider.sevenTv,
          isZeroWidth: (flags & 256) != 0,
        ),
      );
    }

    return output
        .where((emote) => emote.name.isNotEmpty && emote.imageUrl.isNotEmpty)
        .toList(growable: false);
  }

  int? _readInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString());
  }
}
