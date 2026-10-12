import 'package:flutter/foundation.dart';

import '../../models/engagement/twitch_hype_train.dart';
import '../core/twitch_web_gql_persisted_api_service.dart';

typedef TwitchHypeTrainCommandExecutor =
    Future<Object?> Function({
      required String operationName,
      required Map<String, dynamic> variables,
    });

class TwitchHypeTrainApiService {
  static const String getStatusOperationName = 'get_hype_train_status';
  static const String getBulkStatusOperationName = 'get_bulk_hype_train_status';
  static const String _twitchOperationName = 'GetHypeTrainExecution';
  static const String _twitchSha256Hash =
      '8a39e843c94c5109a4cfb9badc641733e2205c60f5ee30e9b55edf0ad9db870a';
  // Separate official status operation; the execution query stays unchanged.
  static const String _statusHash =
      '88e62c2cbd13b7bdce93cc8934727003a5cadd821938538f74848199fbfe84a0';
  static final Map<String, bool> _goldenByTrain = <String, bool>{};

  final Object? client;
  final String? clientId;
  final Future<String?> Function()? accessTokenProvider;
  final TwitchHypeTrainCommandExecutor? commandExecutor;
  final TwitchWebGqlPersistedApiService? gql;

  const TwitchHypeTrainApiService({
    this.client,
    this.clientId,
    this.accessTokenProvider,
    this.commandExecutor,
    this.gql,
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

    final gql = this.gql;
    if (gql != null) {
      final raw = await gql.single(
        TwitchWebGqlPersistedOperation(
          operationName: _twitchOperationName,
          variables: <String, dynamic>{'userLogin': login},
          sha256Hash: _twitchSha256Hash,
        ),
      );
      if (raw.hasErrors) {
        debugPrint(
          '[$_twitchOperationName] GQL errors for $login: ${raw.response}',
        );
        throw StateError('Hype train execution unavailable');
      }
      var snapshot = TwitchHypeTrainSnapshot.fromDynamic(
        raw.response,
        fallbackChannelLogin: login,
      );
      final id = channelId?.trim().isNotEmpty == true
          ? channelId!.trim()
          : snapshot?.channelId ?? '';
      if (snapshot != null && snapshot.isActive && id.isNotEmpty) {
        final cacheKey = '$id/${snapshot.id}';
        final cached = _goldenByTrain[cacheKey];
        if (cached != null) return snapshot.copyWith(isGoldenKappa: cached);
        // Failure of optional decoration must not hide a valid progress bar.
        try {
          final status = await gql.single(
            TwitchWebGqlPersistedOperation(
              operationName: 'BulkAllActiveHypeTrainStatusesQuery',
              variables: <String, dynamic>{
                'channelIDs': <String>[id],
              },
              sha256Hash: _statusHash,
            ),
          );
          final data = status.data;
          final nodes = data is Map ? data['allActiveHypeTrainStatuses'] : null;
          if (!status.hasErrors && nodes is List) {
            for (final node in nodes) {
              if (node is Map &&
                  node['channel'] is Map &&
                  node['channel']['id']?.toString() == id &&
                  node['isGoldenKappaTrain'] is bool &&
                  node['id']?.toString() == snapshot!.id) {
                snapshot = snapshot.copyWith(
                  isGoldenKappa: node['isGoldenKappaTrain'] == true,
                );
                if (_goldenByTrain.length >= 64) {
                  _goldenByTrain.remove(_goldenByTrain.keys.first);
                }
                _goldenByTrain[cacheKey] = snapshot.isGoldenKappa;
                break;
              }
            }
          }
        } catch (_) {
          // Preserve the execution result on temporary status-query failures.
        }
      }
      debugPrint(
        '[$_twitchOperationName] $login -> '
        'active=${snapshot?.isActive ?? false} '
        'level=${snapshot?.level ?? 0} '
        'id=${snapshot?.id ?? "(none)"}',
      );
      return snapshot;
    }
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

    final gql = this.gql;
    if (gql != null) {
      final results = await gql.batch(
        uniqueLogins
            .map(
              (login) => TwitchWebGqlPersistedOperation(
                operationName: _twitchOperationName,
                variables: <String, dynamic>{'userLogin': login},
                sha256Hash: _twitchSha256Hash,
              ),
            )
            .toList(growable: false),
      );

      return <String, TwitchHypeTrainSnapshot?>{
        for (var i = 0; i < uniqueLogins.length; i++)
          uniqueLogins[i]: i < results.length && !results[i].hasErrors
              ? TwitchHypeTrainSnapshot.fromDynamic(
                  results[i].response,
                  fallbackChannelLogin: uniqueLogins[i],
                )
              : null,
      };
    }

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
