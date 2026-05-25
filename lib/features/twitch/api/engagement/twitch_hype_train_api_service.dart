import 'package:flutter/foundation.dart';

import '../../models/engagement/twitch_hype_train.dart';

class TwitchHypeTrainApiService {
  final Object? client;
  final String? clientId;
  final Future<String?> Function()? accessTokenProvider;

  const TwitchHypeTrainApiService({
    this.client,
    this.clientId,
    this.accessTokenProvider,
  });

  Future<TwitchHypeTrainSnapshot> getHypeTrainSnapshot({
    required String channelLogin,
  }) async {
    await getHypeTrainStatus(channelLogin: channelLogin);
    throw StateError(
      'TwitchHypeTrainApiService placeholder: no verified Twitch GQL '
      'persisted query hash is configured.',
    );
  }

  Future<TwitchHypeTrainSnapshot?> getHypeTrainStatus({
    required String channelLogin,
    String? channelId,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      throw ArgumentError.value(
        channelLogin,
        'channelLogin',
        'channelLogin cannot be empty',
      );
    }

    debugPrint(
      'TwitchHypeTrainApiService placeholder: '
      'getHypeTrainStatus($login, channelId: ${channelId ?? ""}) skipped '
      'because no verified Twitch GQL persisted query hash is configured.',
    );
    return null;
  }

  Future<Map<String, TwitchHypeTrainSnapshot?>> getBulkHypeTrainStatus({
    required List<String> channelLogins,
  }) async {
    final uniqueLogins = <String>{
      for (final login in channelLogins)
        if (login.trim().isNotEmpty) login.trim().toLowerCase(),
    };

    return <String, TwitchHypeTrainSnapshot?>{
      for (final login in uniqueLogins)
        login: await getHypeTrainStatus(channelLogin: login),
    };
  }
}
