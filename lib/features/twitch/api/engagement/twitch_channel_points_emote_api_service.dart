import '../../parsers/engagement/twitch_channel_points_emote_parser.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';
import '../core/twitch_api_exception.dart';

export '../../parsers/engagement/twitch_channel_points_emote_parser.dart';

typedef TwitchChannelPointsEmoteTokenProvider = Future<String?> Function();
typedef TwitchChannelPointsEmoteActionClientIdProvider = String Function();
typedef TwitchChannelPointsChannelIdResolver =
    Future<String> Function({required String channelLogin});

/// Backend-only API for Channel Points emote menus.
///
/// Responsibility boundary:
/// - API service: send Twitch GQL request and handle auth / transport errors.
/// - Parser: normalize Twitch-style response shapes.
///
/// Choose-an-emote still uses Twitch's subscriptionProducts whitelist.
/// Modify-a-single-emote now follows StreamNook and uses ChannelPointsContext
/// communityPointsSettings.emoteVariants, because that source carries the final
/// modified emote IDs Twitch expects for redemption.
class TwitchChannelPointsEmoteApiService {
  static const String channelPointsContextHash =
      '374314de591e69925fce3ddc2bcf085796f56ebb8cad67a0daa3165c03adc345';

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

  /// Backward-compatible menu loader.
  ///
  /// Historically this was used by both Choose and Modify. For safer behavior,
  /// it now returns the StreamNook-style Modify source. Choose-specific callers
  /// should use [getChooseEmotes].
  Future<List<TwitchChannelPointEmoteOption>> getModifiableEmotes({
    required String channelLogin,
    String? channelId,
    TwitchChannelPointsChannelIdResolver? resolveChannelId,
  }) {
    return getModifyEmotes(
      channelLogin: channelLogin,
      channelId: channelId,
      resolveChannelId: resolveChannelId,
    );
  }

  Future<List<TwitchChannelPointEmoteOption>> getModifyEmotes({
    required String channelLogin,
    String? channelId,
    TwitchChannelPointsChannelIdResolver? resolveChannelId,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    final ownerId = await _resolveOwnerId(
      channelLogin: login,
      channelId: channelId,
      resolveChannelId: resolveChannelId,
    );

    final raw = await _postChannelPointsContextQuery(channelLogin: login);
    final parsed = TwitchChannelPointsEmoteParser.parseModifiableEmoteVariants(
      raw,
      channelLogin: login.isNotEmpty ? login : ownerId,
    );

    if (parsed.isEmpty) {
      throw TwitchApiException(
        'Channel Points modify emote menu returned no unlockable emoteVariants.',
        details: raw,
      );
    }

    return parsed;
  }

  /// Loads Twitch's viewer/channel-specific Channel Points Choose whitelist.
  ///
  /// This remains intentionally based on subscriptionProducts and should not be
  /// replaced by normal chat emotes or locked/global fallback lists.
  Future<List<TwitchChannelPointEmoteOption>> getChooseEmotes({
    required String channelLogin,
    String? channelId,
    TwitchChannelPointsChannelIdResolver? resolveChannelId,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    final ownerId = await _resolveOwnerId(
      channelLogin: login,
      channelId: channelId,
      resolveChannelId: resolveChannelId,
    );

    final raw = await _postSubscriptionProductsQuery(channelOwnerId: ownerId);
    final parsed = TwitchChannelPointsEmoteParser.parseChooseMenu(
      raw,
      channelOwnerId: ownerId,
    );

    if (parsed.approvedEmotes.isEmpty) {
      throw TwitchApiException(
        'Channel Points choose emote menu returned no approved subscription product emotes. '
        'The response was intentionally not replaced with locked/global/chat emotes.',
        details: raw,
      );
    }

    return parsed.approvedEmotes;
  }

  Future<String> _resolveOwnerId({
    required String channelLogin,
    required String? channelId,
    required TwitchChannelPointsChannelIdResolver? resolveChannelId,
  }) async {
    var ownerId = channelId?.trim() ?? '';
    if (channelLogin.isEmpty && ownerId.isEmpty) {
      throw ArgumentError.value(
        channelLogin,
        'channelLogin',
        'channelLogin or channelId is required',
      );
    }

    if (ownerId.isEmpty &&
        channelLogin.isNotEmpty &&
        resolveChannelId != null) {
      ownerId = (await resolveChannelId(channelLogin: channelLogin)).trim();
    }

    if (ownerId.isEmpty) {
      throw TwitchApiException(
        'Cannot resolve channelOwnerID for Channel Points emote menu.',
      );
    }
    return ownerId;
  }

  Future<dynamic> _postChannelPointsContextQuery({
    required String channelLogin,
  }) {
    return _postPersistedQuery(
      operationName: 'ChannelPointsContext',
      sha256Hash: channelPointsContextHash,
      variables: <String, dynamic>{'channelLogin': channelLogin},
    );
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
      variables: <String, dynamic>{'channelOwnerID': channelOwnerId},
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
        throw TwitchApiException(first['message'].toString(), details: raw);
      }

      throw TwitchApiException(errors.toString(), details: raw);
    }
  }
}
