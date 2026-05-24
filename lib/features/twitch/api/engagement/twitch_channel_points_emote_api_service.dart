import '../../parsers/engagement/twitch_channel_points_emote_parser.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';
import '../core/twitch_api_exception.dart';

export '../../parsers/engagement/twitch_channel_points_emote_parser.dart';

typedef TwitchChannelPointsEmoteTokenProvider = Future<String?> Function();
typedef TwitchChannelPointsEmoteActionClientIdProvider = String Function();
typedef TwitchChannelPointsChannelIdResolver = Future<String> Function({
  required String channelLogin,
});

/// Backend-only API for Channel Points emote menus.
///
/// Responsibility boundary:
/// - API service: send Twitch GQL request and handle auth / transport errors.
/// - Parser: normalize Twitch-style subscriptionProducts response and apply
///   the Choose menu whitelist rules.
///
/// This service must not merge normal chat emote caches, global emotes,
/// third-party emotes, or lockedChannelEmotes into the Channel Points menu.
class TwitchChannelPointsEmoteApiService {
  /// Twitch constant: EMOTE_PICKER_USER_SUBSCRIPTION_PRODUCTS_HASH.
  static const String emotePickerUserSubscriptionProductsHash =
      '511bebfb513d0127d24a7fe49aa2b7717306a611e1f4269a93e0cc76e8a65a81';

  final TwitchApiClient client;
  final TwitchChannelPointsEmoteTokenProvider tokenProvider;
  final TwitchChannelPointsEmoteActionClientIdProvider actionClientIdProvider;
  final String deviceId;
  final String sessionId;

  const TwitchChannelPointsEmoteApiService({
    required this.client,
    required this.tokenProvider,
    required this.actionClientIdProvider,
    required this.deviceId,
    required this.sessionId,
  });

  /// Loads Twitch's viewer/channel-specific Channel Points emote whitelist.
  ///
  /// Choose menu whitelist is parsed by [TwitchChannelPointsEmoteParser].
  /// It intentionally does not fall back to locked/global/chat emotes.
  Future<List<TwitchChannelPointEmoteOption>> getModifiableEmotes({
    required String channelLogin,
    String? channelId,
    TwitchChannelPointsChannelIdResolver? resolveChannelId,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    var ownerId = channelId?.trim() ?? '';

    if (login.isEmpty && ownerId.isEmpty) {
      throw ArgumentError.value(
        channelLogin,
        'channelLogin',
        'channelLogin or channelId is required',
      );
    }

    if (ownerId.isEmpty && login.isNotEmpty && resolveChannelId != null) {
      ownerId = (await resolveChannelId(channelLogin: login)).trim();
    }

    if (ownerId.isEmpty) {
      throw TwitchApiException(
        'Cannot resolve channelOwnerID for Channel Points emote menu.',
      );
    }

    final raw = await _postSubscriptionProductsQuery(
      channelOwnerId: ownerId,
    );

    final parsed = TwitchChannelPointsEmoteParser.parseChooseMenu(
      raw,
      channelOwnerId: ownerId,
    );

    if (parsed.approvedEmotes.isEmpty) {
      throw TwitchApiException(
        'Channel Points emote menu returned no approved subscription product emotes. '
        'The response was intentionally not replaced with locked/global/chat emotes.',
        details: raw,
      );
    }

    return parsed.approvedEmotes;
  }

  Future<dynamic> _postSubscriptionProductsQuery({
    required String channelOwnerId,
  }) async {
    // For this captured hash, sending the wrong operationName causes
    // Twitch to return: no operation with name "EmotePicker_UserSubscriptionProducts".
    // Therefore this request intentionally omits operationName and lets Twitch
    // execute the single operation bound to the persisted query hash.
    return _postPersistedQuery(
      operationName: null,
      sha256Hash: emotePickerUserSubscriptionProductsHash,
      variables: <String, dynamic>{
        'channelOwnerID': channelOwnerId,
      },
    );
  }

  Future<dynamic> _postPersistedQuery({
    required String? operationName,
    required String sha256Hash,
    required Map<String, dynamic> variables,
  }) async {
    final token = await _requireAccessToken();
    final payload = <String, dynamic>{
      'variables': variables,
      'extensions': <String, dynamic>{
        'persistedQuery': <String, dynamic>{
          'version': 1,
          'sha256Hash': sha256Hash,
        },
      },
    };

    final op = operationName?.trim();
    if (op != null && op.isNotEmpty) {
      payload['operationName'] = op;
    }

    final raw = await client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: payload,
      headers: _headers(token: token),
    );

    _throwGraphQlErrors(raw);
    return raw;
  }

  Future<String> _requireAccessToken() async {
    final token = (await tokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw TwitchApiException(
        'Twitch OAuth token is missing for Channel Points emote menu.',
      );
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
      'X-Device-Id': deviceId,
      'Client-Session-Id': sessionId,
    };
  }

  void _throwGraphQlErrors(Object? raw) {
    if (raw is! Map) return;

    final errors = raw['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is Map && first['message'] != null) {
        throw TwitchApiException(
          first['message'].toString(),
          details: raw,
        );
      }

      throw TwitchApiException(
        errors.toString(),
        details: raw,
      );
    }
  }
}
