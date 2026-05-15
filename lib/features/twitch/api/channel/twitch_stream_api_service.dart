import '../../models/channel/twitch_stream.dart';
import '../core/twitch_helix_api_service.dart';

class TwitchStreamPage {
  final List<TwitchStream> streams;
  final String? cursor;

  const TwitchStreamPage({
    required this.streams,
    required this.cursor,
  });
}

/// Stream feature API。
class TwitchStreamApiService {
  final TwitchHelixApiService helix;

  const TwitchStreamApiService({
    required this.helix,
  });

  Future<TwitchStreamPage> getStreams({
    List<String> userLogins = const <String>[],
    List<String> userIds = const <String>[],
    List<String> gameIds = const <String>[],
    String? language,
    String? after,
    int first = 50,
  }) async {
    final query = <String, dynamic>{
      'first': first.clamp(1, 100),
      if (after != null && after.trim().isNotEmpty) 'after': after.trim(),
      if (language != null && language.trim().isNotEmpty)
        'language': language.trim(),
      if (userLogins.isNotEmpty)
        'user_login': userLogins
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
      if (userIds.isNotEmpty)
        'user_id': userIds
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
      if (gameIds.isNotEmpty)
        'game_id': gameIds
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
    };

    final response = await helix.get('/streams', queryParameters: query);
    return _parseStreamPage(response);
  }

  Future<TwitchStreamPage> getFollowedStreams({
    required String userId,
    String? after,
    int first = 100,
  }) async {
    final response = await helix.get(
      '/streams/followed',
      queryParameters: <String, dynamic>{
        'user_id': userId,
        'first': first.clamp(1, 100),
        if (after != null && after.trim().isNotEmpty) 'after': after.trim(),
      },
    );

    return _parseStreamPage(response);
  }

  Future<TwitchStream?> getLiveStreamByLogin(String login) async {
    final page = await getStreams(userLogins: <String>[login], first: 1);
    return page.streams.isEmpty ? null : page.streams.first;
  }

  TwitchStreamPage _parseStreamPage(Map<String, dynamic> response) {
    final data = response['data'];
    final pagination = response['pagination'];

    final streams = data is List
        ? data
            .whereType<Map<String, dynamic>>()
            .map(TwitchStream.fromHelixJson)
            .toList(growable: false)
        : const <TwitchStream>[];

    String? cursor;
    if (pagination is Map<String, dynamic>) {
      final rawCursor = pagination['cursor']?.toString().trim();
      if (rawCursor != null && rawCursor.isNotEmpty) {
        cursor = rawCursor;
      }
    }

    return TwitchStreamPage(
      streams: streams,
      cursor: cursor,
    );
  }
}
