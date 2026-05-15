import '../../models/channel/twitch_user.dart';
import '../core/twitch_gql_api_service.dart';
import '../core/twitch_helix_api_service.dart';

/// User feature API。
///
/// Helix 用於正式 OAuth API。
/// GQL 用於 Twitch Web 欄位，例如 profileImageURL(width)。
class TwitchUserApiService {
  final TwitchHelixApiService helix;
  final TwitchGqlApiService gql;

  const TwitchUserApiService({
    required this.helix,
    required this.gql,
  });

  Future<List<TwitchUser>> getUsersByLogin(List<String> logins) async {
    final clean = logins
        .map((login) => login.trim().toLowerCase())
        .where((login) => login.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (clean.isEmpty) return const <TwitchUser>[];

    final response = await helix.get(
      '/users',
      queryParameters: <String, dynamic>{'login': clean},
    );

    final data = response['data'];
    if (data is! List) return const <TwitchUser>[];

    return data
        .whereType<Map<String, dynamic>>()
        .map(TwitchUser.fromHelixJson)
        .toList(growable: false);
  }

  Future<List<TwitchUser>> getUsersById(List<String> ids) async {
    final clean = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (clean.isEmpty) return const <TwitchUser>[];

    final response = await helix.get(
      '/users',
      queryParameters: <String, dynamic>{'id': clean},
    );

    final data = response['data'];
    if (data is! List) return const <TwitchUser>[];

    return data
        .whereType<Map<String, dynamic>>()
        .map(TwitchUser.fromHelixJson)
        .toList(growable: false);
  }

  Future<TwitchUser?> getUserByLogin(String login) async {
    final users = await getUsersByLogin(<String>[login]);
    return users.isEmpty ? null : users.first;
  }

  Future<TwitchUser?> getUserById(String id) async {
    final users = await getUsersById(<String>[id]);
    return users.isEmpty ? null : users.first;
  }

  Future<TwitchUser?> getChannelProfileByLogin(String login) async {
    final clean = login.trim().toLowerCase();
    if (clean.isEmpty) return null;

    final data = await gql.request(
      operationName: 'ChannelProfileByLogin',
      query: r'''
        query ChannelProfileByLogin($login: String!) {
          user(login: $login) {
            id
            login
            displayName
            description
            profileImageURL(width: 300)
            offlineImageURL
            createdAt
          }
        }
      ''',
      variables: <String, dynamic>{'login': clean},
    );

    final user = data['user'];
    if (user is! Map<String, dynamic>) return null;

    return TwitchUser.fromGqlUserJson(user);
  }
}
