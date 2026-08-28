import '../../models/emotes/twitch_third_party_emote.dart';
import '../core/twitch_api_client.dart';

class TwitchThirdPartyEmoteApiService {
  final TwitchApiClient client;

  const TwitchThirdPartyEmoteApiService({required this.client});

  static const int _sevenTvPreferredChatWidth = 64;

  Future<List<TwitchThirdPartyEmote>> fetchAll({
    required String channelId,
    required String channelLogin,
  }) async {
    final results = await Future.wait<List<TwitchThirdPartyEmote>>(
      <Future<List<TwitchThirdPartyEmote>>>[
        fetchBttvGlobal().catchError((_) => <TwitchThirdPartyEmote>[]),
        fetchBttvChannel(
          channelId: channelId,
        ).catchError((_) => <TwitchThirdPartyEmote>[]),
        fetchFfzGlobal().catchError((_) => <TwitchThirdPartyEmote>[]),
        fetchFfzChannel(
          channelId: channelId,
          channelLogin: channelLogin,
        ).catchError((_) => <TwitchThirdPartyEmote>[]),
        fetchSevenTvGlobal().catchError((_) => <TwitchThirdPartyEmote>[]),
        fetchSevenTvChannel(
          channelId: channelId,
        ).catchError((_) => <TwitchThirdPartyEmote>[]),
      ],
    );

    final byName = <String, TwitchThirdPartyEmote>{};

    // Later providers overwrite earlier providers when names collide. This is
    // close enough for a first client-style cache and avoids rendering duplicate
    // emotes for the same token.
    for (final group in results) {
      for (final emote in group) {
        if (emote.name.trim().isEmpty || emote.imageUrl.trim().isEmpty) {
          continue;
        }
        // Twitch-style priority when names collide: 7TV > FFZ > BTTV.
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
        .map(
          (json) =>
              _bttvFromJson(json, scope: TwitchThirdPartyEmoteScope.global),
        )
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
        channelEmotes.whereType<Map<String, dynamic>>().map(
          (json) =>
              _bttvFromJson(json, scope: TwitchThirdPartyEmoteScope.channel),
        ),
      );
    }

    if (sharedEmotes is List) {
      output.addAll(
        sharedEmotes.whereType<Map<String, dynamic>>().map(
          (json) =>
              _bttvFromJson(json, scope: TwitchThirdPartyEmoteScope.shared),
        ),
      );
    }

    return output
        .where((emote) => emote.name.isNotEmpty && emote.imageUrl.isNotEmpty)
        .toList(growable: false);
  }

  TwitchThirdPartyEmote _bttvFromJson(
    Map<String, dynamic> json, {
    required TwitchThirdPartyEmoteScope scope,
  }) {
    final id = json['id']?.toString() ?? '';
    final code = json['code']?.toString() ?? '';
    final animated =
        _readBool(json['animated']) ||
        (json['imageType']?.toString().toLowerCase() == 'gif');
    return TwitchThirdPartyEmote(
      id: id,
      name: code,
      imageUrl: id.isEmpty ? '' : 'https://cdn.betterttv.net/emote/$id/2x',
      staticImageUrl: id.isEmpty
          ? ''
          : 'https://cdn.betterttv.net/emote/$id/1x',
      provider: TwitchThirdPartyEmoteProvider.bttv,
      scope: scope,
      isZeroWidth: json['modifier'] == true,
      isAnimated: animated,
      width: _readInt(json['width']),
      height: _readInt(json['height']),
    );
  }

  Future<List<TwitchThirdPartyEmote>> fetchFfzGlobal() async {
    final raw = await client.getJson<dynamic>(
      'https://api.frankerfacez.com/v1/set/global',
    );

    return _ffzFromRoot(raw, scope: TwitchThirdPartyEmoteScope.global);
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

        final parsed = _ffzFromRoot(
          raw,
          scope: TwitchThirdPartyEmoteScope.channel,
        );
        if (parsed.isNotEmpty) return parsed;
      } catch (_) {
        // Fallback to id endpoint below.
      }
    }

    final raw = await client.getJson<dynamic>(
      'https://api.frankerfacez.com/v1/room/id/$channelId',
    );

    return _ffzFromRoot(raw, scope: TwitchThirdPartyEmoteScope.channel);
  }

  List<TwitchThirdPartyEmote> _ffzFromRoot(
    dynamic raw, {
    required TwitchThirdPartyEmoteScope scope,
  }) {
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
        final width = _readInt(item['width']);
        final height = _readInt(item['height']);
        final urls = item['urls'];

        String imageUrl = '';
        String staticImageUrl = '';
        if (urls is Map) {
          imageUrl = (urls['2'] ?? urls['1'] ?? urls['4'])?.toString() ?? '';
          staticImageUrl =
              (urls['1'] ?? urls['2'] ?? urls['4'])?.toString() ?? '';
          if (imageUrl.startsWith('//')) imageUrl = 'https:$imageUrl';
          if (staticImageUrl.startsWith('//')) {
            staticImageUrl = 'https:$staticImageUrl';
          }
        }

        output.add(
          TwitchThirdPartyEmote(
            id: id,
            name: name,
            imageUrl: imageUrl,
            staticImageUrl: staticImageUrl,
            provider: TwitchThirdPartyEmoteProvider.ffz,
            scope: scope,
            width: width,
            height: height,
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

    return _sevenTvFromEmoteSet(raw, scope: TwitchThirdPartyEmoteScope.global);
  }

  Future<List<TwitchThirdPartyEmote>> fetchSevenTvChannel({
    required String channelId,
  }) async {
    final raw = await client.getJson<dynamic>(
      'https://7tv.io/v3/users/twitch/$channelId',
    );

    if (raw is! Map<String, dynamic>) return const <TwitchThirdPartyEmote>[];

    return _sevenTvFromEmoteSet(
      raw['emote_set'],
      scope: TwitchThirdPartyEmoteScope.channel,
    );
  }

  List<TwitchThirdPartyEmote> _sevenTvFromEmoteSet(
    dynamic raw, {
    required TwitchThirdPartyEmoteScope scope,
  }) {
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
      final dataFlags = _readInt(dataMap['flags']) ?? 0;
      final animated = (dataFlags & 1) != 0;

      final host = dataMap['host'];
      final hostMap = host is Map<String, dynamic> ? host : <String, dynamic>{};

      var imageUrl = '';
      var staticImageUrl = '';
      int? selectedWidth;
      int? selectedHeight;

      final files = hostMap['files'];
      if (files is List && files.isNotEmpty) {
        final candidates = files.whereType<Map<String, dynamic>>().toList();
        final selected = _selectSevenTvChatFile(candidates, animated: animated);
        final staticSelected = _selectSevenTvStaticChatFile(candidates);

        selectedWidth = _readInt(selected['width']);
        selectedHeight = _readInt(selected['height']);

        final fileName = selected['name']?.toString() ?? '';
        final staticFileName = staticSelected['name']?.toString() ?? '';
        final url = hostMap['url']?.toString() ?? '';

        if (url.isNotEmpty && fileName.isNotEmpty) {
          imageUrl = 'https:$url/$fileName';
        }
        if (url.isNotEmpty && staticFileName.isNotEmpty) {
          staticImageUrl = 'https:$url/$staticFileName';
        }
      }

      if (imageUrl.isEmpty && id.isNotEmpty) {
        imageUrl = 'https://cdn.7tv.app/emote/$id/2x.webp';
      }
      if (staticImageUrl.isEmpty && id.isNotEmpty) {
        staticImageUrl = 'https://cdn.7tv.app/emote/$id/1x.webp';
      }

      output.add(
        TwitchThirdPartyEmote(
          id: id,
          name: name,
          imageUrl: imageUrl,
          staticImageUrl: staticImageUrl,
          provider: TwitchThirdPartyEmoteProvider.sevenTv,
          scope: scope,
          isZeroWidth: (flags & 256) != 0,
          isAnimated: animated,
          width: selectedWidth,
          height: selectedHeight,
        ),
      );
    }

    return output
        .where((emote) => emote.name.isNotEmpty && emote.imageUrl.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> _selectSevenTvChatFile(
    List<Map<String, dynamic>> candidates, {
    required bool animated,
  }) {
    if (candidates.isEmpty) return const <String, dynamic>{};

    final formatPool = candidates
        .where((file) {
          final format = file['format']?.toString().toLowerCase() ?? '';
          final name = file['name']?.toString().toLowerCase() ?? '';
          if (animated) return format == 'webp' || name.endsWith('.webp');
          return format == 'webp' ||
              format == 'png' ||
              name.endsWith('.webp') ||
              name.endsWith('.png');
        })
        .toList(growable: false);

    final preferredPool = formatPool.isNotEmpty ? formatPool : candidates;
    return _selectByPreferredWidth(preferredPool);
  }

  Map<String, dynamic> _selectSevenTvStaticChatFile(
    List<Map<String, dynamic>> candidates,
  ) {
    if (candidates.isEmpty) return const <String, dynamic>{};

    final staticPool = candidates
        .where((file) {
          final name = file['name']?.toString().toLowerCase() ?? '';
          final format = file['format']?.toString().toLowerCase() ?? '';
          return name.endsWith('.png') || format == 'png';
        })
        .toList(growable: false);

    if (staticPool.isNotEmpty) return _selectByPreferredWidth(staticPool);

    final fallbackPool = candidates
        .where((file) {
          final name = file['name']?.toString().toLowerCase() ?? '';
          final format = file['format']?.toString().toLowerCase() ?? '';
          return name.endsWith('.webp') || format == 'webp';
        })
        .toList(growable: false);

    return _selectByPreferredWidth(
      fallbackPool.isNotEmpty ? fallbackPool : candidates,
    );
  }

  Map<String, dynamic> _selectByPreferredWidth(
    List<Map<String, dynamic>> candidates,
  ) {
    if (candidates.isEmpty) return const <String, dynamic>{};

    final sorted = candidates.toList(growable: false)
      ..sort((a, b) {
        final aWidth = _readInt(a['width']) ?? 1 << 20;
        final bWidth = _readInt(b['width']) ?? 1 << 20;
        return aWidth.compareTo(bWidth);
      });

    for (final file in sorted) {
      final width = _readInt(file['width']) ?? 0;
      if (width >= _sevenTvPreferredChatWidth) return file;
    }

    return sorted.last;
  }

  bool _readBool(Object? value) {
    if (value is bool) return value;
    if (value == null) return false;
    final text = value.toString().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  int? _readInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString());
  }
}
