import '../../models/emotes/twitch_official_emote.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';
import '../core/twitch_web_gql_persisted_api_service.dart';

class TwitchOfficialEmoteApiService {
  final TwitchApiClient client;

  const TwitchOfficialEmoteApiService({required this.client});

  Future<List<TwitchOfficialEmote>> fetchGlobalEmotes({
    required String accessToken,
    required String clientId,
  }) async {
    final raw = await client.getJson<Map<String, dynamic>>(
      '${TwitchApiConstants.helixBaseUrl}/chat/emotes/global',
      headers: _headers(accessToken: accessToken, clientId: clientId),
    );

    return _parseEmotes(
      raw,
      source: TwitchOfficialEmoteSource.global,
      unlocked: true,
    );
  }

  Future<List<TwitchOfficialEmote>> fetchChannelEmotes({
    required String broadcasterId,
    required String accessToken,
    required String clientId,
  }) async {
    final cleanBroadcasterId = broadcasterId.trim();
    if (cleanBroadcasterId.isEmpty) return const <TwitchOfficialEmote>[];

    final raw = await client.getJson<Map<String, dynamic>>(
      '${TwitchApiConstants.helixBaseUrl}/chat/emotes',
      queryParameters: <String, dynamic>{'broadcaster_id': cleanBroadcasterId},
      headers: _headers(accessToken: accessToken, clientId: clientId),
    );

    return _parseEmotes(
      raw,
      source: TwitchOfficialEmoteSource.channel,
      unlocked: false,
    );
  }

  Future<List<TwitchOfficialEmote>> fetchUserEmotes({
    required String userId,
    String broadcasterId = '',
    required String accessToken,
    required String clientId,
    bool includeBroadcasterFilter = false,
  }) async {
    final cleanUserId = userId.trim();
    final cleanBroadcasterId = broadcasterId.trim();

    if (cleanUserId.isEmpty) return const <TwitchOfficialEmote>[];

    final output = <TwitchOfficialEmote>[];
    String? after;

    do {
      final raw = await client.getJson<Map<String, dynamic>>(
        '${TwitchApiConstants.helixBaseUrl}/chat/emotes/user',
        queryParameters: <String, dynamic>{
          'user_id': cleanUserId,
          if (includeBroadcasterFilter && cleanBroadcasterId.isNotEmpty)
            'broadcaster_id': cleanBroadcasterId,
          if (after != null && after.isNotEmpty) 'after': after,
        },
        headers: _headers(accessToken: accessToken, clientId: clientId),
      );

      output.addAll(
        _parseEmotes(
          raw,
          source: TwitchOfficialEmoteSource.user,
          unlocked: true,
        ),
      );

      final pagination = raw['pagination'];
      after = pagination is Map ? pagination['cursor']?.toString() : null;
    } while (after != null && after.trim().isNotEmpty);

    return output;
  }

  Future<Map<String, String>> fetchUserDisplayNamesByIds({
    required Iterable<String> userIds,
    required String accessToken,
    required String clientId,
  }) async {
    final ids = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (ids.isEmpty) return const <String, String>{};

    final output = <String, String>{};

    for (var index = 0; index < ids.length; index += 100) {
      final chunk = ids.skip(index).take(100).toList(growable: false);
      final raw = await client.getJson<Map<String, dynamic>>(
        '${TwitchApiConstants.helixBaseUrl}/users',
        queryParameters: <String, dynamic>{'id': chunk},
        headers: _headers(accessToken: accessToken, clientId: clientId),
      );

      final data = raw['data'];
      if (data is! List) continue;

      for (final item in data.whereType<Map<String, dynamic>>()) {
        final id = item['id']?.toString() ?? '';
        final displayName = item['display_name']?.toString() ?? '';
        final login = item['login']?.toString() ?? '';
        if (id.trim().isEmpty) continue;
        output[id] = displayName.trim().isNotEmpty ? displayName : login;
      }
    }

    return output;
  }

  Future<List<TwitchOfficialEmote>> fetchAvailableEmotesForChannel({
    required String broadcasterId,
    required TwitchWebGqlPersistedApiService gql,
  }) async {
    final cleanBroadcasterId = broadcasterId.trim();
    if (cleanBroadcasterId.isEmpty) return const <TwitchOfficialEmote>[];

    final output = <TwitchOfficialEmote>[];
    String? cursor;

    do {
      final result = await gql.single(
        TwitchWebGqlPersistedOperation(
          operationName: 'AvailableEmotesForChannelPaginated',
          variables: <String, dynamic>{
            'channelID': cleanBroadcasterId,
            'cursor': cursor,
            'pageLimit': 350,
            'withOwner': true,
          },
          sha256Hash:
              '6c45e0ecaa823cc7db3ecdd1502af2223c775bdcfb0f18a3a0ce9a0b7db8ef6c',
        ),
      );

      if (result.hasErrors) return const <TwitchOfficialEmote>[];

      final data = result.data;
      final channel = data is Map ? data['channel'] : null;
      final self = channel is Map ? channel['self'] : null;
      final sets = self is Map ? self['availableEmoteSetsPaginated'] : null;
      final edges = sets is Map ? sets['edges'] : null;
      if (edges is! List) break;

      for (final edge in edges.whereType<Map>()) {
        final node = edge['node'];
        if (node is! Map) continue;
        final owner = node['owner'];
        final ownerId = owner is Map ? owner['id']?.toString() ?? '' : '';
        final ownerDisplayName = owner is Map
            ? (owner['displayName'] ?? owner['login'])?.toString() ?? ''
            : '';
        final emotes = node['emotes'];
        if (emotes is! List) continue;

        for (final item in emotes.whereType<Map>()) {
          final id = item['id']?.toString() ?? '';
          final name = _normalizeGqlEmoteToken(
            item['token']?.toString() ?? item['name']?.toString() ?? '',
            item['type']?.toString() ?? '',
          );
          if (id.trim().isEmpty || name.trim().isEmpty) continue;

          output.add(
            TwitchOfficialEmote(
              id: id,
              name: name,
              imageUrl:
                  'https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0',
              emoteType: item['type']?.toString() ?? '',
              tier: item['subscriptionTier']?.toString() ?? '',
              emoteSetId: item['setID']?.toString() ?? '',
              ownerId: ownerId,
              ownerDisplayName: ownerDisplayName,
              source: TwitchOfficialEmoteSource.user,
              unlocked: true,
            ),
          );
        }

        final edgeCursor = edge['cursor']?.toString();
        if (edgeCursor != null && edgeCursor.trim().isNotEmpty) {
          cursor = edgeCursor;
        }
      }

      final pageInfo = sets is Map ? sets['pageInfo'] : null;
      final hasNext = pageInfo is Map && pageInfo['hasNextPage'] == true;
      if (!hasNext) cursor = null;
    } while (cursor != null && cursor.trim().isNotEmpty);

    return output;
  }

  List<TwitchOfficialEmote> _parseEmotes(
    Map<String, dynamic> raw, {
    required TwitchOfficialEmoteSource source,
    required bool unlocked,
  }) {
    final data = raw['data'];
    if (data is! List) return const <TwitchOfficialEmote>[];

    final output = <TwitchOfficialEmote>[];

    for (final item in data.whereType<Map<String, dynamic>>()) {
      final emote = TwitchOfficialEmote.fromHelixJson(
        item,
        source: source,
        unlocked: unlocked,
      );

      if (emote.id.isEmpty || emote.name.isEmpty) continue;
      output.add(emote);
    }

    return output;
  }

  Map<String, String> _headers({
    required String accessToken,
    required String clientId,
  }) {
    return <String, String>{
      'Client-ID': clientId.trim(),
      'Authorization': 'Bearer ${accessToken.trim()}',
    };
  }

  String _normalizeGqlEmoteToken(String token, String type) {
    var output = token.trim();
    if (type.toLowerCase() == 'smilies') {
      output = output
          .replaceAll(r'\', '')
          .replaceAll('?', '')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>');
    }
    return output;
  }
}
