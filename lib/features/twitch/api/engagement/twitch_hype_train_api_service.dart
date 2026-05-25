import 'package:flutter/foundation.dart';

import '../../models/engagement/twitch_hype_train.dart';

typedef TwitchHypeTrainCommandExecutor =
    Future<Object?> Function({
      required String operationName,
      required Map<String, dynamic> variables,
    });

class TwitchHypeTrainApiService {
  static const String getStatusOperationName = 'get_hype_train_status';
  static const String getBulkStatusOperationName = 'get_bulk_hype_train_status';

  final Object? client;
  final String? clientId;
  final Future<String?> Function()? accessTokenProvider;
  final TwitchHypeTrainCommandExecutor? commandExecutor;

  const TwitchHypeTrainApiService({
    this.client,
    this.clientId,
    this.accessTokenProvider,
    this.commandExecutor,
  });

  Future<TwitchHypeTrainSnapshot> getHypeTrainSnapshot({
    required String channelLogin,
  }) async {
    return await getHypeTrainStatus(channelLogin: channelLogin) ??
        TwitchHypeTrainSnapshot.empty(channelLogin: channelLogin);
  }

  Future<TwitchHypeTrainSnapshot?> getHypeTrainStatus({
    required String channelLogin,
    String? channelId,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) return null;

    final executor = commandExecutor;
    if (executor == null) {
      debugPrint(
        'TwitchHypeTrainApiService placeholder: '
        '$getStatusOperationName skipped because StreamNook endpoint/request '
        'shape is not documented in the local reference.',
      );
      return null;
    }

    final raw = await executor(
      operationName: getStatusOperationName,
      variables: <String, dynamic>{
        'channelLogin': login,
        'channel_login': login,
        if (channelId != null && channelId.trim().isNotEmpty) ...{
          'channelId': channelId.trim(),
          'channel_id': channelId.trim(),
        },
      },
    );

    return TwitchHypeTrainSnapshot.fromDynamic(
      raw,
      fallbackChannelLogin: login,
    );
  }

  Future<Map<String, TwitchHypeTrainSnapshot?>> getBulkHypeTrainStatus({
    required List<String> channelLogins,
  }) async {
    final uniqueLogins = <String>{
      for (final login in channelLogins)
        if (login.trim().isNotEmpty) login.trim().toLowerCase(),
    }.toList(growable: false);

    if (uniqueLogins.isEmpty) return const <String, TwitchHypeTrainSnapshot?>{};

    final executor = commandExecutor;
    if (executor == null) {
      debugPrint(
        'TwitchHypeTrainApiService placeholder: '
        '$getBulkStatusOperationName skipped because StreamNook endpoint/'
        'request shape is not documented in the local reference.',
      );
      return <String, TwitchHypeTrainSnapshot?>{
        for (final login in uniqueLogins) login: null,
      };
    }

    final raw = await executor(
      operationName: getBulkStatusOperationName,
      variables: <String, dynamic>{
        'channelLogins': uniqueLogins,
        'channel_logins': uniqueLogins,
      },
    );

    final parsed = TwitchHypeTrainSnapshot.mapFromJson(raw);
    return <String, TwitchHypeTrainSnapshot?>{
      for (final login in uniqueLogins) login: parsed[login],
    };
  }
}
