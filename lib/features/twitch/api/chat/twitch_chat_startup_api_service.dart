import '../../models/chat/twitch_chat_badge.dart';
import '../../models/chat/twitch_chat_startup.dart';
import '../core/twitch_web_gql_persisted_api_service.dart';

class TwitchChatStartupApiService {
  final TwitchWebGqlPersistedApiService gql;

  const TwitchChatStartupApiService({
    required this.gql,
  });

  Future<TwitchChatStartupSnapshot> fetchParsedStartupSnapshot({
    required String channelLogin,
  }) async {
    final results = await fetchStartupBatch(channelLogin: channelLogin);
    final byName = <String, TwitchWebGqlPersistedResult>{
      for (final result in results) result.operationName: result,
    };

    final getIdData = _dataMap(byName['GetIDFromLogin']?.response);
    final user = _asMap(getIdData['user']);

    final globalBadgesData = _dataMap(byName['GlobalBadges']?.response);
    final chatListBadgesData = _dataMap(byName['ChatList_Badges']?.response);

    final globalBadges = TwitchChatBadge.listFromUnknown(globalBadgesData['badges']);

    final channelBadgeSource =
        _firstListValue(chatListBadgesData) ??
        _firstListValue(_firstMapValue(chatListBadgesData));

    final channelBadges = TwitchChatBadge.listFromUnknown(channelBadgeSource);

    return TwitchChatStartupSnapshot(
      channelLogin: channelLogin.trim().toLowerCase(),
      channelId: user['id']?.toString(),
      badgeCatalog: TwitchBadgeCatalog(
        globalBadges: globalBadges,
        channelBadges: channelBadges,
      ),
      chatRestrictions: _dataMap(byName['ChatRestrictions']?.response),
      chatRoomState: _dataMap(byName['ChatRoomState']?.response),
      chatChannelData: _dataMap(byName['Chat_ChannelData']?.response),
      chatInput: _dataMap(byName['ChatInput']?.response),
      recentMessages: _extractRecentMessages(byName['MessageBuffer_Channel']?.response),
      operations: results
          .map(
            (result) => TwitchStartupOperationSummary.fromResponse(
              operationName: result.operationName,
              hasErrors: result.hasErrors,
              response: result.response,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<List<TwitchWebGqlPersistedResult>> fetchStartupBatch({
    required String channelLogin,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      throw ArgumentError.value(channelLogin, 'channelLogin', 'channelLogin cannot be empty');
    }

    final operations = <TwitchWebGqlPersistedOperation>[
      TwitchWebGqlPersistedOperation(
        operationName: 'GetIDFromLogin',
        variables: <String, dynamic>{'login': login},
        sha256Hash: '94e82a7b1e3c21e186daa73ee2afc4b8f23bade1fbbff6fe8ac133f50a2f58ca',
      ),
      TwitchWebGqlPersistedOperation(
        operationName: 'GlobalBadges',
        variables: const <String, dynamic>{},
        sha256Hash: '9db27e18d61ee393ccfdec8c7d90f14f9a11266298c2e5eb808550b77d7bcdf6',
      ),
      TwitchWebGqlPersistedOperation(
        operationName: 'ChatRestrictions',
        variables: <String, dynamic>{'channelLogin': login},
        sha256Hash: '7514aeb3d2c203087b83e920f8d36eb18a5ca1bfa96a554ed431255ecbbbc089',
      ),
      TwitchWebGqlPersistedOperation(
        operationName: 'MessageBuffer_Channel',
        variables: <String, dynamic>{'channelLogin': login},
        sha256Hash: 'bfc959904f55b5003ae4674d4bea83ebdcd8867ad76e12f38957d433902d2fcc',
      ),
      TwitchWebGqlPersistedOperation(
        operationName: 'UseLive',
        variables: <String, dynamic>{'channelLogin': login},
        sha256Hash: '639d5f11bfb8bf3053b424d9ef650d04c4ebb7d94711d644afb08fe9a0fad5d9',
      ),
      TwitchWebGqlPersistedOperation(
        operationName: 'PollChannelSettings',
        variables: <String, dynamic>{'channelLogin': login},
        sha256Hash: 'e31355d5fd19bf9b3c0907c8302ce9ff5466d06230bec209f78cf04724b7380c',
      ),
      TwitchWebGqlPersistedOperation(
        operationName: 'ChatRoomState',
        variables: <String, dynamic>{'login': login},
        sha256Hash: '9e0f79669e31950c658459564bc4cff236ac9c03e534cc32769ac58bc0cdd708',
      ),
      TwitchWebGqlPersistedOperation(
        operationName: 'Chat_ChannelData',
        variables: <String, dynamic>{'channelLogin': login},
        sha256Hash: '863fda39ddc5ebac7453856eb00af2a587e27f48a2e521e9c01820c3c8c2c18a',
      ),
      TwitchWebGqlPersistedOperation(
        operationName: 'ChatList_Badges',
        variables: <String, dynamic>{'channelLogin': login},
        sha256Hash: '838a7e0b47c09cac05f93ff081a9ff4f876b68f7624f0fc465fe30031e372fc2',
      ),
      TwitchWebGqlPersistedOperation(
        operationName: 'ChatInput',
        variables: <String, dynamic>{
          'channelLogin': login,
          'isEmbedded': false,
        },
        sha256Hash: 'd8ab574eb44e3e82aabc96fc9c59af6eafead3e96262910a6396c007e7a11e05',
      ),
      TwitchWebGqlPersistedOperation(
        operationName: 'PinnedCheersSettings',
        variables: <String, dynamic>{'login': login},
        sha256Hash: 'ca73cb0396fe5bcbe05c906fd472622e4b873eeb07699c2664026a079aeec631',
      ),
    ];

    return gql.batch(operations);
  }
}

Map<String, dynamic> _dataMap(Object? response) {
  if (response is! Map<String, dynamic>) return <String, dynamic>{};
  final data = response['data'];
  return data is Map<String, dynamic> ? data : <String, dynamic>{};
}

Map<String, dynamic> _asMap(Object? value) {
  return value is Map<String, dynamic> ? value : <String, dynamic>{};
}

Map<String, dynamic>? _firstMapValue(Map<String, dynamic> map) {
  for (final value in map.values) {
    if (value is Map<String, dynamic>) return value;
  }
  return null;
}

List<dynamic>? _firstListValue(Object? value) {
  if (value is List) return value;
  if (value is Map<String, dynamic>) {
    for (final item in value.values) {
      final nested = _firstListValue(item);
      if (nested != null) return nested;
    }
  }
  return null;
}

List<Map<String, dynamic>> _extractRecentMessages(Object? response) {
  final data = _dataMap(response);
  final list = _firstListValue(data);
  if (list == null) return const <Map<String, dynamic>>[];

  return list
      .whereType<Map<String, dynamic>>()
      .take(20)
      .toList(growable: false);
}
