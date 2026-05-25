import '../../models/engagement/twitch_pinned_chat.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';

typedef TwitchPinnedChatTokenProvider = Future<String?> Function();

class TwitchPinnedChatApiService {
  final TwitchApiClient client;
  final String clientId;
  final TwitchPinnedChatTokenProvider? accessTokenProvider;

  const TwitchPinnedChatApiService({
    required this.client,
    this.clientId = TwitchApiConstants.twitchWebClientId,
    this.accessTokenProvider,
  });

  Future<List<TwitchPinnedChatMessage>> getPinnedChatMessages({
    required String channelId,
    int count = 10,
  }) async {
    final raw = await getPinnedChatRaw(channelId: channelId, count: count);

    final messages = TwitchPinnedChatMessage.listFromGqlResponse(raw);
    return _enrichMissingUserAvatars(messages);
  }

  Future<dynamic> getPinnedChatRaw({
    required String channelId,
    int count = 10,
  }) async {
    final cid = channelId.trim();
    if (cid.isEmpty) {
      throw ArgumentError.value(
        channelId,
        'channelId',
        'channelId cannot be empty',
      );
    }

    final headers = await _headers();

    return client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': 'GetPinnedChat',
        'variables': <String, dynamic>{
          'channelID': cid,
          'count': count.clamp(1, 25),
        },
        'extensions': <String, dynamic>{
          'persistedQuery': <String, dynamic>{
            'version': 1,
            'sha256Hash':
                '2d099d4c9b6af80a07d8440140c4f3dbb04d516b35c401aab7ce8f60765308d5',
          },
        },
      },
      headers: headers,
    );
  }

  Future<List<TwitchPinnedChatMessage>> _enrichMissingUserAvatars(
    List<TwitchPinnedChatMessage> messages,
  ) async {
    if (messages.isEmpty) return messages;

    final users = <TwitchPinnedChatUser>[];
    for (final message in messages) {
      final sender = message.sender;
      final pinnedBy = message.pinnedBy;
      if (sender != null && sender.profileImageUrl.trim().isEmpty) {
        users.add(sender);
      }
      if (pinnedBy != null && pinnedBy.profileImageUrl.trim().isEmpty) {
        users.add(pinnedBy);
      }
    }

    if (users.isEmpty) return messages;

    final profiles = <String, _PinnedUserProfile>{};
    for (final user in users) {
      final id = user.id.trim();
      final login = user.login.trim().toLowerCase();
      final key = id.isNotEmpty ? 'id:$id' : 'login:$login';
      if (profiles.containsKey(key)) continue;

      try {
        final profile = await _fetchUserProfile(id: id, login: login);
        if (profile == null) continue;
        if (profile.id.isNotEmpty) profiles['id:${profile.id}'] = profile;
        if (profile.login.isNotEmpty) {
          profiles['login:${profile.login}'] = profile;
        }
      } catch (_) {}
    }

    TwitchPinnedChatUser? enrich(TwitchPinnedChatUser? user) {
      if (user == null || user.profileImageUrl.trim().isNotEmpty) return user;
      final profile =
          profiles['id:${user.id.trim()}'] ??
          profiles['login:${user.login.trim().toLowerCase()}'];
      if (profile == null || profile.profileImageUrl.isEmpty) return user;
      return user.copyWith(
        login: user.login.trim().isNotEmpty ? user.login : profile.login,
        displayName: user.displayName.trim().isNotEmpty
            ? user.displayName
            : profile.displayName,
        profileImageUrl: profile.profileImageUrl,
      );
    }

    return messages
        .map(
          (message) => message.copyWith(
            sender: enrich(message.sender),
            pinnedBy: enrich(message.pinnedBy),
          ),
        )
        .toList(growable: false);
  }

  Future<_PinnedUserProfile?> _fetchUserProfile({
    required String id,
    required String login,
  }) async {
    final safeId = id.trim();
    final safeLogin = login.trim().toLowerCase();
    if (safeId.isEmpty && safeLogin.isEmpty) return null;

    final byId = safeId.isNotEmpty;
    final raw = await client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': byId ? 'UserProfileById' : 'UserProfileByLogin',
        'variables': <String, dynamic>{
          if (byId) 'id': safeId,
          if (!byId) 'login': safeLogin,
        },
        'query': byId
            ? 'query UserProfileById(\$id: ID!) { user(id: \$id) { id login displayName profileImageURL(width: 70) } }'
            : 'query UserProfileByLogin(\$login: String!) { user(login: \$login) { id login displayName profileImageURL(width: 70) } }',
      },
      headers: await _headers(),
    );

    if (raw is! Map<String, dynamic>) return null;
    final data = raw['data'];
    if (data is! Map<String, dynamic>) return null;
    final user = data['user'];
    if (user is! Map<String, dynamic>) return null;
    return _PinnedUserProfile.fromGqlJson(user);
  }

  Future<Map<String, String>> _headers() async {
    final token = await accessTokenProvider?.call();
    final safeToken = token?.trim();

    return <String, String>{
      ...TwitchApiConstants.twitchWebHeaders,
      'Client-ID': clientId,
      'Content-Type': 'application/json',
      if (safeToken != null && safeToken.isNotEmpty)
        'Authorization': 'OAuth $safeToken',
    };
  }
}

class _PinnedUserProfile {
  final String id;
  final String login;
  final String displayName;
  final String profileImageUrl;

  const _PinnedUserProfile({
    required this.id,
    required this.login,
    required this.displayName,
    required this.profileImageUrl,
  });

  factory _PinnedUserProfile.fromGqlJson(Map<String, dynamic> json) {
    return _PinnedUserProfile(
      id: json['id']?.toString().trim() ?? '',
      login: json['login']?.toString().trim().toLowerCase() ?? '',
      displayName: json['displayName']?.toString().trim() ?? '',
      profileImageUrl:
          json['profileImageURL']?.toString().trim() ??
          json['profileImageUrl']?.toString().trim() ??
          '',
    );
  }
}
