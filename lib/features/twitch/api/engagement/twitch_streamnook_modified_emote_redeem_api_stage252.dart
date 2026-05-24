import 'dart:math' as math;

import '../../models/engagement/twitch_channel_points_models.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';
import '../core/twitch_api_exception.dart';
import 'twitch_channel_points_api_service.dart';

class TwitchStreamNookModifiedEmoteRedeemApiStage252 {
  static const String unlockModifiedEmoteHash =
      '30e8cc29b1d6d96809f5e35f5e7a550ae8bf5d26966a9637d919477ffd0bfc52';

  final TwitchApiClient client;
  final TwitchChannelPointsTokenProvider tokenProvider;
  final TwitchChannelPointsActionClientIdProvider actionClientIdProvider;
  final String deviceId;
  final String sessionId;

  const TwitchStreamNookModifiedEmoteRedeemApiStage252({
    required this.client,
    required this.tokenProvider,
    required this.actionClientIdProvider,
    required this.deviceId,
    required this.sessionId,
  });

  Future<TwitchChannelRewardRedeemResult> unlockModifiedEmote({
    required String channelId,
    required int cost,
    required String emoteId,
    String rewardId = '',
  }) async {
    final cid = channelId.trim();
    final finalModifiedEmoteId = emoteId.trim();
    if (cid.isEmpty) {
      throw ArgumentError.value(channelId, 'channelId', 'cannot be empty');
    }
    if (finalModifiedEmoteId.isEmpty) {
      throw TwitchApiException('Modify Emote requires a final modified emoteID.');
    }
    if (cost <= 0) {
      throw TwitchApiException('Modify Emote requires a positive StreamNook-style cost.');
    }

    final token = await _requireAccessToken();
    final transactionId = _dashlessUuidLike();

    final raw = await client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': 'UnlockModifiedEmote',
        'variables': <String, dynamic>{
          'input': <String, dynamic>{
            'channelID': cid,
            'emoteID': finalModifiedEmoteId,
            'cost': cost,
            'transactionID': transactionId,
          },
        },
        'extensions': <String, dynamic>{
          'persistedQuery': <String, dynamic>{
            'version': 1,
            'sha256Hash': unlockModifiedEmoteHash,
          },
        },
      },
      headers: _headers(token: token),
    );

    _throwGraphQlErrors(raw);

    final payload = _readMap(raw, const <String>[
      'data',
      'unlockChosenModifiedSubscriberEmote',
    ]);
    final error = _readMap(payload, const <String>['error']);
    if (error != null) {
      final code = _readString(error, const <String>['code']) ?? 'UNKNOWN';
      if (code != 'EMOTE_ALREADY_ENTITLED') {
        throw TwitchApiException(
          'UnlockModifiedEmote failed: $code',
          details: raw,
        );
      }
    }

    return TwitchChannelRewardRedeemResult(
      ok: true,
      rewardId: rewardId.trim(),
      transactionId: transactionId,
      raw: raw,
    );
  }

  Future<String> _requireAccessToken() async {
    final token = (await tokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw TwitchApiException('Drops OAuth token is missing for modified emote redeem.');
    }
    return token;
  }

  Map<String, String> _headers({required String token}) {
    return <String, String>{
      ...TwitchApiConstants.twitchWebHeaders,
      'Client-ID': actionClientIdProvider().trim(),
      'Authorization': 'OAuth $token',
      'Content-Type': 'application/json',
      'Accept-Language': 'en-US',
      // StreamNook generates fresh dashless ids for these headers per request.
      'X-Device-Id': _dashlessUuidLike(),
      'Client-Session-Id': _dashlessUuidLike().substring(0, 16),
    };
  }

  String _dashlessUuidLike() {
    final random = math.Random.secure();
    return List<String>.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
      growable: false,
    ).join();
  }

  void _throwGraphQlErrors(Object? raw) {
    if (raw is! Map) return;
    final errors = raw['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is Map && first['message'] != null) {
        throw TwitchApiException(first['message'].toString(), details: raw);
      }
      throw TwitchApiException(errors.toString(), details: raw);
    }
  }

  Map<String, dynamic>? _readMap(Object? root, List<String> path) {
    Object? current = root;
    for (final key in path) {
      final map = _asStringMap(current);
      if (map == null) return null;
      current = map[key];
    }
    return _asStringMap(current);
  }

  String? _readString(Object? root, List<String> path) {
    Object? current = root;
    for (final key in path) {
      final map = _asStringMap(current);
      if (map == null) return null;
      current = map[key];
    }
    final text = current?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Map<String, dynamic>? _asStringMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}
