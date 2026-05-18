import '../../models/emotes/twitch_official_emote.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';

class TwitchOfficialEmoteApiService {
  final TwitchApiClient client;

  const TwitchOfficialEmoteApiService({
    required this.client,
  });

  Future<List<TwitchOfficialEmote>> fetchGlobalEmotes({
    required String accessToken,
    required String clientId,
  }) async {
    final raw = await client.getJson<Map<String, dynamic>>(
      '${TwitchApiConstants.helixBaseUrl}/chat/emotes/global',
      headers: _headers(
        accessToken: accessToken,
        clientId: clientId,
      ),
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
      queryParameters: <String, dynamic>{
        'broadcaster_id': cleanBroadcasterId,
      },
      headers: _headers(
        accessToken: accessToken,
        clientId: clientId,
      ),
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
          if (after != null && after!.isNotEmpty) 'after': after,
        },
        headers: _headers(
          accessToken: accessToken,
          clientId: clientId,
        ),
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
    } while (after != null && after!.trim().isNotEmpty);

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

    output.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
}