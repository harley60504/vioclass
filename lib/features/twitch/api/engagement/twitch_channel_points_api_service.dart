import 'dart:convert';
import 'dart:math' as math;

import '../../models/engagement/twitch_channel_points.dart' as legacy;
import '../../models/engagement/twitch_channel_points_models.dart';
import '../../parsers/engagement/twitch_channel_points_reward_parser.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';
import '../core/twitch_api_exception.dart';
import '../core/twitch_web_gql_persisted_api_service.dart';
import 'twitch_channel_points_emote_api_service.dart';

export '../../models/engagement/twitch_channel_points_models.dart';
export '../../parsers/engagement/twitch_channel_points_reward_parser.dart';
export 'twitch_channel_points_emote_api_service.dart';

/// Unified Twitch channel-points API.
///
/// This file intentionally owns all channel-points reads and actions:
/// - persisted Web GQL snapshot fallback
/// - balance / bonus claim context
/// - reward list parsing
/// - bonus claim
/// - custom reward redeem
///
/// Keep redeem actions here instead of creating a second redeem-only API file;
/// otherwise reward image parsing, token choice, and action behavior will drift.
typedef TwitchChannelPointsTokenProvider = Future<String?> Function();
typedef TwitchChannelPointsActionClientIdProvider = String Function();

class TwitchChannelPointsApiService {
  static const String channelPointsContextHash =
      '374314de591e69925fce3ddc2bcf085796f56ebb8cad67a0daa3165c03adc345';

  // Built-in reward mutation used by Highlight My Message and
  // Send a Message in Sub-Only Mode.
  static const String _sendHighlightedChatMessageHash =
      'bb187d763156dc5c25c6457e1b32da6c5033cb7504854e6d33a8b876d10444b6';
  static const String _unlockRandomSubscriberEmoteHash =
      'f548e89966b21d0094f3dc35233232eb6ec76d63e02594c8a494407712a85350';
  static const String _unlockModifiedEmoteHash =
      '30e8cc29b1d6d96809f5e35f5e7a550ae8bf5d26966a9637d919477ffd0bfc52';

  final TwitchWebGqlPersistedApiService? gql;
  final TwitchApiClient? client;
  final TwitchChannelPointsTokenProvider? tokenProvider;
  final String webClientId;
  final String androidClientId;
  final TwitchChannelPointsActionClientIdProvider? actionClientIdProvider;
  final String deviceId;
  final String sessionId;

  TwitchChannelPointsApiService({
    this.gql,
    this.client,
    this.tokenProvider,
    this.webClientId = TwitchApiConstants.twitchWebClientId,
    String? androidClientId,
    this.actionClientIdProvider,
    String? deviceId,
    String? sessionId,
  })  : androidClientId =
            androidClientId ?? TwitchApiConstants.twitchAndroidClientId,
        deviceId = deviceId ?? _randomCompactId(),
        sessionId = sessionId ?? _randomCompactId();

  String get effectiveActionClientId {
    final provided = actionClientIdProvider?.call().trim();
    if (provided != null && provided.isNotEmpty) return provided;
    return androidClientId.trim();
  }

  static String _randomCompactId() {
    final random = math.Random.secure();
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final suffix = List<String>.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '$now$suffix';
  }



  TwitchApiClient get _client {
    final effective = client ?? gql?.client;
    if (effective == null) {
      throw TwitchApiException(
        'TwitchApiClient is missing. Provide client or gql when creating TwitchChannelPointsApiService.',
      );
    }
    return effective;
  }

  TwitchWebGqlPersistedApiService get _persistedGql {
    final effective = gql;
    if (effective == null) {
      throw TwitchApiException(
        'TwitchWebGqlPersistedApiService is missing. Provide gql to use persisted channel-points snapshots.',
      );
    }
    return effective;
  }

  Future<legacy.TwitchChannelPointsBundle> fetchChannelPointsBundle({
    required String channelLogin,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      throw ArgumentError.value(
        channelLogin,
        'channelLogin',
        'channelLogin cannot be empty',
      );
    }

    final operations = <TwitchWebGqlPersistedOperation>[
      TwitchWebGqlPersistedOperation(
        operationName: 'CommunityPointsRewardRedemptionContext',
        variables: <String, dynamic>{'channelLogin': login},
        sha256Hash:
            'f585e0d07bee16fa1355238b1762c095cc10470edc263d38c4e3a1b8a7e53f65',
      ),
      TwitchWebGqlPersistedOperation(
        operationName: 'ChannelPointsContext',
        variables: <String, dynamic>{
          'channelLogin': login,
          'includeGoalTypes': <String>['CREATOR', 'BOOST'],
        },
        sha256Hash:
            '7fe050e3761eb2cf258d70ee1a21cbd76fa8cf3d7e7b12fc437e7029d446b5e3',
      ),
      TwitchWebGqlPersistedOperation(
        operationName: 'ChannelPointsGlobalContext',
        variables: const <String, dynamic>{},
        sha256Hash:
            'd3fa3a96e78a3e62bdd3ef3c4effafeda52442906cec41a9440e609a388679e2',
      ),
    ];

    final results = await _persistedGql.batch(operations);

    return legacy.TwitchChannelPointsBundle(
      channelLogin: login,
      snapshots: results
          .map(
            (result) => legacy.TwitchChannelPointsContextSnapshot.fromRaw(
              operationName: result.operationName,
              response: result.response,
            ),
          )
          .toList(growable: false),
    );
  }

  /// Backward-compatible alias for the old public API method.
  Future<dynamic> claimCommunityPoints({
    required String channelId,
    required String claimId,
  }) {
    return _postGraphQlMutation(
      operationName: 'ClaimCommunityPoints',
      query: r'''
mutation ClaimCommunityPoints($input: ClaimCommunityPointsInput!) {
  claimCommunityPoints(input: $input) {
    __typename
  }
}
''',
      variables: <String, dynamic>{
        'input': <String, dynamic>{
          'channelID': channelId,
          'claimID': claimId,
        },
      },
    );
  }

  /// Backward-compatible alias for old UI/runtime code.
  Future<dynamic> redeemCustomReward({
    required String channelId,
    required legacy.TwitchChannelPointReward reward,
    String textInput = '',
  }) {
    return _postGraphQlMutation(
      operationName: 'RedeemCommunityPointsCustomReward',
      query: r'''
mutation RedeemCommunityPointsCustomReward($input: RedeemCommunityPointsCustomRewardInput!) {
  redeemCommunityPointsCustomReward(input: $input) {
    __typename
    error {
      code
    }
  }
}
''',
      variables: <String, dynamic>{
        'input': <String, dynamic>{
          'channelID': channelId,
          'cost': reward.cost,
          'prompt': reward.prompt,
          'rewardID': reward.id,
          'textInput': textInput.trim(),
          'title': reward.title,
          'transactionID': _transactionId(),
        },
      },
    );
  }

  Future<dynamic> _postGraphQlMutation({
    required String operationName,
    required String query,
    required Map<String, dynamic> variables,
  }) async {
    final token = await _requireAccessToken();

    final raw = await _client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': operationName,
        'query': query,
        'variables': variables,
      },
      headers: _headers(
        clientId: gql?.clientId ?? effectiveActionClientId,
        token: token,
        authorizationPrefix: 'OAuth',
      ),
    );

    _throwGraphQlErrors(raw);
    return raw;
  }

  Future<TwitchChannelPointsContext> getContext({
    required String channelLogin,
  }) async {
    final token = await _requireAccessToken();

    return getContextWithAuth(
      channelLogin: channelLogin,
      clientId: webClientId,
      accessToken: token,
      label: 'webClientId + webToken',
    );
  }

  Future<TwitchChannelPointsContext> getContextWithAuth({
    required String channelLogin,
    required String clientId,
    required String accessToken,
    String label = 'custom',
  }) async {
    final login = channelLogin.trim().toLowerCase();
    final safeClientId = clientId.trim();
    final safeToken = accessToken.trim();

    if (login.isEmpty) {
      throw ArgumentError.value(channelLogin, 'channelLogin', 'cannot be empty');
    }

    if (safeClientId.isEmpty) {
      throw TwitchApiException('Client-ID is empty for $label.');
    }

    if (safeToken.isEmpty) {
      throw TwitchApiException('OAuth token is empty for $label.');
    }

    final query = r'''
query ChannelPointsContext($channelLogin: String!) {
  user(login: $channelLogin) {
    id
    login
    displayName
    channel {
      id
      communityPointsSettings {
        name
        image {
          url
        }
      }
      self {
        communityPoints {
          balance
          availableClaim {
            id
          }
        }
      }
    }
  }
}
''';

    final raw = await _client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': 'ChannelPointsContext',
        'query': query,
        'variables': <String, dynamic>{
          'channelLogin': login,
        },
      },
      headers: _headers(
        clientId: safeClientId,
        token: safeToken,
        authorizationPrefix: 'OAuth',
      ),
    );

    _throwGraphQlErrors(raw);

    if (raw is! Map) {
      throw TwitchApiException(
        'Unexpected ChannelPointsContext response type: ${raw.runtimeType}.',
        details: raw,
      );
    }

    final user = _readMap(raw, const <String>['data', 'user']);
    if (user == null) {
      throw TwitchApiException(
        'ChannelPointsContext response did not contain data.user.',
        details: raw,
      );
    }

    final channel = _readMap(user, const <String>['channel']);
    final channelId = _readString(channel, const <String>['id']) ??
        _readString(user, const <String>['id']) ??
        '';

    final settings =
        _readMap(channel, const <String>['communityPointsSettings']);
    final self = _readMap(channel, const <String>['self']);
    final points = _readMap(self, const <String>['communityPoints']);
    final availableClaim = _readMap(points, const <String>['availableClaim']);

    return TwitchChannelPointsContext(
      channelId: channelId,
      channelLogin: login,
      balance: _readInt(points, const <String>['balance']) ?? 0,
      availableClaimId: _readString(availableClaim, const <String>['id']),
      availableClaimPoints: 50,
      pointsName: _readString(settings, const <String>['name']),
      pointsIconUrl: _readString(settings, const <String>['image', 'url']),
      raw: <String, dynamic>{
        'label': label,
        'clientId': safeClientId,
        'response': raw,
      },
    );
  }

  /// Fetches channel-points reward list using the persisted ChannelPointsContext
  /// operation observed from Twitch Web / StreamNook style clients.
  Future<TwitchChannelRewardsResult> getRewards({
    required String channelLogin,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      throw ArgumentError.value(channelLogin, 'channelLogin', 'cannot be empty');
    }

    final token = await _requireAccessToken();
    _ensureActionClientId();

    final raw = await _client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': 'ChannelPointsContext',
        'variables': <String, dynamic>{
          'channelLogin': login,
          'includeGoalTypes': <String>['CREATOR', 'BOOST'],
        },
        'extensions': <String, dynamic>{
          'persistedQuery': <String, dynamic>{
            'version': 1,
            'sha256Hash': channelPointsContextHash,
          },
        },
      },
      headers: _headers(
        clientId: effectiveActionClientId,
        token: token,
        authorizationPrefix: 'OAuth',
      ),
    );

    _throwGraphQlErrors(raw);

    if (raw is! Map) {
      throw TwitchApiException(
        'Unexpected ChannelPointsContext rewards response type: ${raw.runtimeType}.',
        details: raw,
      );
    }

    try {
      return TwitchChannelPointsRewardParser.parseRewardsResponse(
        raw: raw,
        channelLogin: login,
      );
    } catch (error) {
      throw TwitchApiException(
        'Failed to parse ChannelPointsContext rewards response: $error',
        details: raw,
      );
    }
  }


  /// StreamNook-style Channel Points emote menu source.
  ///
  /// Kept here as a compatibility wrapper. The actual GQL/menu backend lives in
  /// [TwitchChannelPointsEmoteApiService] so Channel Points reward redemption
  /// and emote-menu discovery do not drift together.
  Future<List<TwitchChannelPointEmoteOption>> getModifiableEmotes({
    required String channelLogin,
    String? channelId,
  }) {
    return emoteApi.getModifiableEmotes(
      channelLogin: channelLogin,
      channelId: channelId,
      resolveChannelId: ({required String channelLogin}) async {
        final context = await getContext(channelLogin: channelLogin);
        return context.channelId;
      },
    );
  }

  TwitchChannelPointsEmoteApiService get emoteApi {
    return TwitchChannelPointsEmoteApiService(
      client: _client,
      tokenProvider: () async => _requireAccessToken(),
      actionClientIdProvider: () => effectiveActionClientId,
      deviceId: deviceId,
      sessionId: sessionId,
    );
  }

  Future<TwitchChannelPointsClaimResult> claimBonus({
    required String channelId,
    required String claimId,
  }) async {
    final cid = channelId.trim();
    final claim = claimId.trim();

    if (cid.isEmpty) {
      throw ArgumentError.value(channelId, 'channelId', 'cannot be empty');
    }
    if (claim.isEmpty) {
      throw ArgumentError.value(claimId, 'claimId', 'cannot be empty');
    }

    final token = await _requireAccessToken();
    _ensureActionClientId();

    final raw = await _client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': 'ClaimCommunityPoints',
        'variables': <String, dynamic>{
          'input': <String, dynamic>{
            'claimID': claim,
            'channelID': cid,
          },
        },
        'extensions': <String, dynamic>{
          'persistedQuery': <String, dynamic>{
            'version': 1,
            'sha256Hash':
                '46aaeebe02c99afdf4fc97c7c0cba964124bf6b0af229395f1f6d1feed05b3d0',
          },
        },
      },
      headers: _headers(
        clientId: effectiveActionClientId,
        token: token,
        authorizationPrefix: 'OAuth',
      ),
    );

    _throwGraphQlErrors(raw);

    final claimData = _readMap(raw, const <String>[
      'data',
      'claimCommunityPoints',
    ]);

    final error = _readMap(claimData, const <String>['error']);
    if (error != null) {
      final code = _readString(error, const <String>['code']) ?? 'UNKNOWN';
      throw TwitchApiException(
        'ClaimCommunityPoints failed: $code',
        details: raw,
      );
    }

    return TwitchChannelPointsClaimResult(
      ok: true,
      pointsEarned: _readInt(claimData, const <String>['currentPoints']) ??
          _readInt(claimData, const <String>['pointsEarned']) ??
          _readInt(claimData, const <String>['pointGain']) ??
          50,
      raw: raw,
    );
  }

  Future<TwitchChannelRewardRedeemResult> redeemReward({
    required String channelId,
    required TwitchChannelReward reward,
    String textInput = '',
  }) async {
    final cid = channelId.trim();
    final rewardId = reward.id.trim();

    if (cid.isEmpty) {
      throw ArgumentError.value(channelId, 'channelId', 'cannot be empty');
    }
    if (rewardId.isEmpty) {
      throw ArgumentError.value(reward.id, 'reward.id', 'cannot be empty');
    }
    if (!reward.isBasicallyAvailable) {
      final status = reward.statusText() ?? 'unavailable';
      throw TwitchApiException('Reward is not redeemable: $status');
    }

    if (reward.isAutomaticReward) {
      if (!reward.supportsAutomaticRewardRedeem) {
        throw TwitchApiException(
          'This built-in reward is not supported yet: ${reward.normalizedRewardType}',
        );
      }

      final parsedInput = _AutomaticRewardInput.parse(textInput);
      return _redeemAutomaticReward(
        channelId: cid,
        reward: reward,
        textInput: textInput,
        emoteId: parsedInput.emoteId,
        emoteModifierId: parsedInput.emoteModifierId,
      );
    }

    if (!reward.supportsDirectCustomRewardRedeem) {
      throw TwitchApiException(
        'This reward cannot be redeemed with the custom reward mutation: ${reward.rewardType ?? reward.title}',
      );
    }

    final token = await _requireAccessToken();
    _ensureActionClientId();
    final transactionId = _transactionId();

    final raw = await _client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': 'RedeemCommunityPointsCustomReward',
        'query': r"""
mutation RedeemCommunityPointsCustomReward($input: RedeemCommunityPointsCustomRewardInput!) {
  redeemCommunityPointsCustomReward(input: $input) {
    __typename
    error {
      code
    }
  }
}
""",
        'variables': <String, dynamic>{
          'input': <String, dynamic>{
            'channelID': cid,
            'cost': reward.redeemCost,
            'prompt': reward.prompt,
            'rewardID': rewardId,
            'textInput': textInput.trim(),
            'title': reward.title,
            'transactionID': transactionId,
          },
        },
      },
      headers: _headers(
        clientId: effectiveActionClientId,
        token: token,
        authorizationPrefix: 'OAuth',
      ),
    );

    _throwGraphQlErrors(raw);
    _throwOperationError(
      raw,
      operationField: 'redeemCommunityPointsCustomReward',
      operationName: 'RedeemCommunityPointsCustomReward',
    );

    return TwitchChannelRewardRedeemResult(
      ok: true,
      rewardId: rewardId,
      transactionId: transactionId,
      raw: raw,
    );
  }

  Future<TwitchChannelRewardRedeemResult> sendHighlightedMessage({
    required String channelId,
    required TwitchChannelReward reward,
    required String message,
  }) async {
    final cid = channelId.trim();
    final rewardId = reward.id.trim();
    final cleanMessage = message.trim();

    if (cid.isEmpty) {
      throw ArgumentError.value(channelId, 'channelId', 'cannot be empty');
    }
    if (rewardId.isEmpty) {
      throw ArgumentError.value(reward.id, 'reward.id', 'cannot be empty');
    }
    if (cleanMessage.isEmpty) {
      throw TwitchApiException('Message cannot be empty.');
    }

    final transactionId = _transactionId();
    final raw = await _postPersistedChannelPointMutation(
      operationName: 'SendHighlightedChatMessage',
      sha256Hash: _sendHighlightedChatMessageHash,
      input: <String, dynamic>{
        'channelID': cid,
        'cost': reward.redeemCost,
        'message': cleanMessage,
        'rewardID': rewardId,
        'transactionID': transactionId,
      },
    );

    _throwOperationError(
      raw,
      operationField: 'sendHighlightedChatMessage',
      operationName: 'SendHighlightedChatMessage',
    );

    return TwitchChannelRewardRedeemResult(
      ok: true,
      rewardId: rewardId,
      transactionId: transactionId,
      raw: raw,
    );
  }


  Future<TwitchChannelRewardRedeemResult> _redeemAutomaticReward({
    required String channelId,
    required TwitchChannelReward reward,
    required String textInput,
    String? emoteId,
    String? emoteModifierId,
  }) async {
    switch (reward.normalizedRewardType) {
      case 'SEND_HIGHLIGHTED_MESSAGE':
      case 'SINGLE_MESSAGE_BYPASS_SUB_MODE':
        return sendHighlightedMessage(
          channelId: channelId,
          reward: reward,
          message: textInput,
        );
      case 'RANDOM_SUB_EMOTE_UNLOCK':
        return unlockRandomSubscriberEmote(
          channelId: channelId,
          reward: reward,
        );
      case 'CHOSEN_SUB_EMOTE_UNLOCK':
        return unlockChosenSubscriberEmote(
          channelId: channelId,
          reward: reward,
          emoteId: emoteId,
        );
      case 'CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK':
        return unlockModifiedSubscriberEmote(
          channelId: channelId,
          reward: reward,
          emoteId: emoteId,
          emoteModifierId: emoteModifierId,
        );
      case 'SEND_GIGANTIFIED_EMOTE':
        return sendGigantifiedEmote(
          channelId: channelId,
          reward: reward,
          emoteId: emoteId,
          message: textInput,
        );
    }

    throw TwitchApiException(
      'Unsupported automatic reward type: ${reward.normalizedRewardType}',
    );
  }

  Future<TwitchChannelRewardRedeemResult> unlockRandomSubscriberEmote({
    required String channelId,
    required TwitchChannelReward reward,
  }) async {
    final transactionId = _transactionId();
    final raw = await _postPersistedChannelPointMutation(
      operationName: 'UnlockRandomSubscriberEmote',
      sha256Hash: _unlockRandomSubscriberEmoteHash,
      input: <String, dynamic>{
        'channelID': channelId,
        'cost': reward.redeemCost,
        'rewardID': reward.id.trim(),
        'transactionID': transactionId,
      },
    );

    _throwOperationError(
      raw,
      operationField: 'unlockRandomSubscriberEmote',
      operationName: 'UnlockRandomSubscriberEmote',
    );

    return TwitchChannelRewardRedeemResult(
      ok: true,
      rewardId: reward.id.trim(),
      transactionId: transactionId,
      raw: raw,
    );
  }

  Future<TwitchChannelRewardRedeemResult> unlockChosenSubscriberEmote({
    required String channelId,
    required TwitchChannelReward reward,
    required String? emoteId,
  }) async {
    final cleanEmoteId = emoteId?.trim();
    if (cleanEmoteId == null || cleanEmoteId.isEmpty) {
      throw TwitchApiException('Choose Emote requires an emoteId.');
    }

    final token = await _requireAccessToken();
    _ensureActionClientId();
    final transactionId = _transactionId();

    final raw = await _client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': 'UnlockChosenSubscriberEmote',
        'query': r'''
mutation UnlockChosenSubscriberEmote($input: UnlockChosenSubscriberEmoteInput!) {
  unlockChosenSubscriberEmote(input: $input) {
    __typename
    error {
      code
    }
  }
}
''',
        'variables': <String, dynamic>{
          'input': <String, dynamic>{
            'channelID': channelId,
            'cost': reward.redeemCost,
            'emoteID': cleanEmoteId,
            'rewardID': reward.id.trim(),
            'transactionID': transactionId,
          },
        },
      },
      headers: _headers(
        clientId: effectiveActionClientId,
        token: token,
        authorizationPrefix: 'OAuth',
      ),
    );

    _throwGraphQlErrors(raw);
    _throwOperationError(
      raw,
      operationField: 'unlockChosenSubscriberEmote',
      operationName: 'UnlockChosenSubscriberEmote',
    );

    return TwitchChannelRewardRedeemResult(
      ok: true,
      rewardId: reward.id.trim(),
      transactionId: transactionId,
      raw: raw,
    );
  }

  Future<TwitchChannelRewardRedeemResult> unlockModifiedSubscriberEmote({
    required String channelId,
    required TwitchChannelReward reward,
    required String? emoteId,
    required String? emoteModifierId,
  }) async {
    final cleanEmoteId = emoteId?.trim();
    final cleanModifierId = emoteModifierId?.trim();

    if (cleanEmoteId == null || cleanEmoteId.isEmpty) {
      throw TwitchApiException('Modify Emote requires an emoteId.');
    }
    // StreamNook sends the final modified emote id, for example `1022569_BW`,
    // as emoteID. The modifier id is UI-only metadata and is not sent separately.
    final finalModifiedEmoteId = cleanEmoteId;

    final transactionId = _transactionId();
    final raw = await _postPersistedChannelPointMutation(
      operationName: 'UnlockModifiedSubscriberEmote',
      sha256Hash: _unlockModifiedEmoteHash,
      input: <String, dynamic>{
        'channelID': channelId,
        'cost': reward.redeemCost,
        'emoteID': finalModifiedEmoteId,
        'rewardID': reward.id.trim(),
        'transactionID': transactionId,
      },
    );

    _throwOperationError(
      raw,
      operationField: 'unlockModifiedSubscriberEmote',
      operationName: 'UnlockModifiedSubscriberEmote',
    );

    return TwitchChannelRewardRedeemResult(
      ok: true,
      rewardId: reward.id.trim(),
      transactionId: transactionId,
      raw: raw,
    );
  }

  Future<TwitchChannelRewardRedeemResult> sendGigantifiedEmote({
    required String channelId,
    required TwitchChannelReward reward,
    String? emoteId,
    String message = '',
  }) async {
    final cleanEmoteId = emoteId?.trim();
    final cleanMessage = message.trim();

    if ((cleanEmoteId == null || cleanEmoteId.isEmpty) && cleanMessage.isEmpty) {
      throw TwitchApiException('Gigantify Emote requires an emoteId or message.');
    }

    final transactionId = _transactionId();
    final raw = await _postInlineChannelPointMutation(
      operationName: 'SendGigantifiedEmote',
      operationField: 'sendGigantifiedEmote',
      input: <String, dynamic>{
        'channelID': channelId,
        'cost': reward.redeemCost,
        if (cleanEmoteId != null && cleanEmoteId.isNotEmpty)
          'emoteID': cleanEmoteId,
        if (cleanMessage.isNotEmpty) 'message': cleanMessage,
        'rewardID': reward.id.trim(),
        'transactionID': transactionId,
      },
    );

    _throwOperationError(
      raw,
      operationField: 'sendGigantifiedEmote',
      operationName: 'SendGigantifiedEmote',
    );

    return TwitchChannelRewardRedeemResult(
      ok: true,
      rewardId: reward.id.trim(),
      transactionId: transactionId,
      raw: raw,
    );
  }

  Future<dynamic> _postPersistedChannelPointMutation({
    required String operationName,
    required String sha256Hash,
    required Map<String, dynamic> input,
  }) async {
    final token = await _requireAccessToken();
    _ensureActionClientId();

    final raw = await _client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': operationName,
        'variables': <String, dynamic>{
          'input': input,
        },
        'extensions': <String, dynamic>{
          'persistedQuery': <String, dynamic>{
            'version': 1,
            'sha256Hash': sha256Hash,
          },
        },
      },
      headers: _headers(
        clientId: effectiveActionClientId,
        token: token,
        authorizationPrefix: 'OAuth',
      ),
    );

    _throwGraphQlErrors(raw);
    return raw;
  }


  Future<dynamic> _postInlineChannelPointMutation({
    required String operationName,
    required String operationField,
    required Map<String, dynamic> input,
  }) async {
    final token = await _requireAccessToken();
    _ensureActionClientId();

    final raw = await _client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': operationName,
        'query': '''
mutation $operationName(\$input: ${operationName}Input!) {
  $operationField(input: \$input) {
    __typename
    error {
      code
    }
  }
}
''',
        'variables': <String, dynamic>{
          'input': input,
        },
      },
      headers: _headers(
        clientId: effectiveActionClientId,
        token: token,
        authorizationPrefix: 'OAuth',
      ),
    );

    _throwGraphQlErrors(raw);
    return raw;
  }

  Future<String> _requireAccessToken() async {
    final token = await tokenProvider?.call() ??
        await gql?.accessTokenProvider?.call();
    final safeToken = token?.trim();

    if (safeToken == null || safeToken.isEmpty) {
      throw TwitchApiException(
        'Twitch Web OAuth token is missing. Complete WebView login first.',
      );
    }

    return safeToken;
  }

  void _ensureActionClientId() {
    if (effectiveActionClientId.trim().isEmpty) {
      throw TwitchApiException(
        'Channel-points action Client-ID is empty.',
      );
    }
  }

  String _transactionId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'ntapp-$now-${_randomCompactId()}';
  }

  Map<String, String> _headers({
    required String clientId,
    required String token,
    required String authorizationPrefix,
  }) {
    return <String, String>{
      ...TwitchApiConstants.twitchWebHeaders,
      'Client-ID': clientId,
      'Authorization': '$authorizationPrefix $token',
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

  void _throwOperationError(
    Object? raw, {
    required String operationField,
    required String operationName,
  }) {
    final data = _readMap(raw, <String>['data', operationField]);
    final error = _readMap(data, const <String>['error']);

    if (error == null) return;

    final code = _readString(error, const <String>['code']) ?? 'UNKNOWN';
    throw TwitchApiException(
      '$operationName failed: $code',
      details: raw,
    );
  }
}


class _AutomaticRewardInput {
  final String? emoteId;
  final String? emoteModifierId;

  const _AutomaticRewardInput({
    required this.emoteId,
    required this.emoteModifierId,
  });

  static _AutomaticRewardInput parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const _AutomaticRewardInput(
        emoteId: null,
        emoteModifierId: null,
      );
    }

    if (text.startsWith('{')) {
      try {
        final decoded = jsonDecode(text);
        final map = _asStringMap(decoded);
        if (map != null) {
          final emoteId = map['emoteId']?.toString().trim();
          final modifierId = map['modifierId']?.toString().trim();
          return _AutomaticRewardInput(
            emoteId: emoteId == null || emoteId.isEmpty ? null : emoteId,
            emoteModifierId:
                modifierId == null || modifierId.isEmpty ? null : modifierId,
          );
        }
      } catch (_) {
        // Fall through to loose parser below.
      }
    }

    final named = <String, String>{};
    for (final match in RegExp(r'([a-zA-Z_]+)\s*[:=]\s*([^,\s]+)').allMatches(text)) {
      named[match.group(1)!.toLowerCase()] = match.group(2)!.trim();
    }

    final emoteId = named['emoteid'] ?? named['emote_id'] ?? named['emote'];
    final modifierId = named['modifierid'] ??
        named['modifier_id'] ??
        named['emotemodifierid'] ??
        named['emote_modifier_id'] ??
        named['modificationid'] ??
        named['modification_id'] ??
        named['modifier'];

    if (emoteId != null || modifierId != null) {
      return _AutomaticRewardInput(
        emoteId: emoteId,
        emoteModifierId: modifierId,
      );
    }

    final parts = text
        .split(RegExp(r'[,\s]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    return _AutomaticRewardInput(
      emoteId: parts.isEmpty ? text : parts[0],
      emoteModifierId: parts.length >= 2 ? parts[1] : null,
    );
  }
}


int _resolveRewardCost(
  Map<String, dynamic> json, {
  required String source,
}) {
  final lowerSource = source.trim().toLowerCase();

  final cost = _readInt(json, const <String>['cost']);
  final minimumCost = _readInt(json, const <String>['minimumCost']) ??
      _readInt(json, const <String>['minimum_cost']) ??
      _readInt(json, const <String>['minCost']) ??
      _readInt(json, const <String>['min_cost']);
  final defaultCost = _readInt(json, const <String>['defaultCost']) ??
      _readInt(json, const <String>['default_cost']) ??
      _readInt(json, const <String>['defaultPrice']) ??
      _readInt(json, const <String>['default_price']);

  if (lowerSource == 'automatic') {
    // Match StreamNook: built-in rewards use the raw reward cost first.
    // minimumCost is only the fallback lower-bound, not the configured price.
    if (cost != null && cost > 0) return cost;
    if (minimumCost != null && minimumCost > 0) return minimumCost;
    if (defaultCost != null && defaultCost > 0) return defaultCost;
    return 0;
  }

  if (cost != null && cost > 0) return cost;
  if (minimumCost != null && minimumCost > 0) return minimumCost;
  if (defaultCost != null && defaultCost > 0) return defaultCost;

  return 0;
}

int _resolveRewardRedeemCost(
  Map<String, dynamic> json, {
  required String source,
  required int displayCost,
}) {
  final lowerSource = source.trim().toLowerCase();

  final cost = _readInt(json, const <String>['cost']);
  final minimumCost = _readInt(json, const <String>['minimumCost']) ??
      _readInt(json, const <String>['minimum_cost']) ??
      _readInt(json, const <String>['minCost']) ??
      _readInt(json, const <String>['min_cost']);
  final defaultCost = _readInt(json, const <String>['defaultCost']) ??
      _readInt(json, const <String>['default_cost']) ??
      _readInt(json, const <String>['defaultPrice']) ??
      _readInt(json, const <String>['default_price']);

  if (lowerSource == 'automatic') {
    // Match StreamNook redemption payloads exactly: cost -> minimumCost -> defaultCost.
    if (cost != null && cost > 0) return cost;
    if (minimumCost != null && minimumCost > 0) return minimumCost;
    if (defaultCost != null && defaultCost > 0) return defaultCost;
    if (displayCost > 0) return displayCost;
    return 0;
  }

  if (cost != null && cost > 0) return cost;
  if (displayCost > 0) return displayCost;
  if (minimumCost != null && minimumCost > 0) return minimumCost;
  if (defaultCost != null && defaultCost > 0) return defaultCost;

  return 0;
}

int? _firstPositiveInt(
  Map<String, dynamic> json,
  List<List<String>> paths,
) {
  for (final path in paths) {
    final value = _readInt(json, path);
    if (value != null && value > 0) return value;
  }

  return null;
}

bool _shouldDisplayReward({
  required Map<String, dynamic> raw,
  required TwitchChannelReward reward,
}) {
  // Match StreamNook: skip disabled rewards only. Do not hide rewards just
  // because Twitch marks them hidden-for-subs/viewer; the tile can still show
  // locked/unavailable state in UI.
  if (!reward.isEnabled) return false;
  if (_readBool(raw, const <String>['isDisabled']) == true) return false;
  if (_readBool(raw, const <String>['disabled']) == true) return false;

  return true;
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

List<Object?> _readList(Object? root, List<String> path) {
  Object? current = root;

  for (final key in path) {
    final map = _asStringMap(current);
    if (map == null) return const <Object?>[];
    current = map[key];
  }

  if (current is List) return current.cast<Object?>();
  return const <Object?>[];
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

int? _readInt(Object? root, List<String> path) {
  Object? current = root;

  for (final key in path) {
    final map = _asStringMap(current);
    if (map == null) return null;
    current = map[key];
  }

  if (current is int) return current;
  if (current is double) return current.round();
  return int.tryParse(current?.toString() ?? '');
}

bool? _readBool(Object? root, List<String> path) {
  Object? current = root;

  for (final key in path) {
    final map = _asStringMap(current);
    if (map == null) return null;
    current = map[key];
  }

  if (current is bool) return current;
  final text = current?.toString().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return null;
}

Map<String, dynamic>? _asStringMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
  return null;
}

Map<String, dynamic>? _findMapContainingKey(Object? value, String key) {
  final map = _asStringMap(value);
  if (map != null) {
    if (map.containsKey(key)) return map;
    for (final child in map.values) {
      final found = _findMapContainingKey(child, key);
      if (found != null) return found;
    }
  } else if (value is List) {
    for (final child in value) {
      final found = _findMapContainingKey(child, key);
      if (found != null) return found;
    }
  }

  return null;
}

Map<String, dynamic>? _findNearestChannelMap(Object? value) {
  final map = _asStringMap(value);
  if (map != null) {
    if (map.containsKey('communityPointsSettings') && map.containsKey('id')) {
      return map;
    }

    for (final child in map.values) {
      final found = _findNearestChannelMap(child);
      if (found != null) return found;
    }
  } else if (value is List) {
    for (final child in value) {
      final found = _findNearestChannelMap(child);
      if (found != null) return found;
    }
  }

  return null;
}

String? _readRewardImageUrl(
  Map<String, dynamic> json, {
  required List<String> rootKeys,
}) {
  for (final rootKey in rootKeys) {
    final direct = _readString(json, <String>[rootKey]);
    if (_looksLikeImageUrl(direct)) return direct;

    final directMap = _readMap(json, <String>[rootKey]);
    final fromMap = _readBestImageFromValue(directMap);
    if (fromMap != null) return fromMap;
  }

  return null;
}

String? _readBestImageFromValue(Object? value) {
  final map = _asStringMap(value);
  if (map != null) {
    for (final key in const <String>[
      'url4x',
      'url_4x',
      'url2x',
      'url_2x',
      'url1x',
      'url_1x',
      'url',
      'large',
      'medium',
      'small',
    ]) {
      final image = _readString(map, <String>[key]);
      if (_looksLikeImageUrl(image)) return image;
    }

    for (final key in const <String>['images', 'image', 'defaultImage']) {
      final nested = _readBestImageFromValue(map[key]);
      if (nested != null) return nested;
    }
  }

  if (value is List) {
    for (final item in value) {
      final image = _readBestImageFromValue(item);
      if (image != null) return image;
    }
  }

  return null;
}

bool _looksLikeImageUrl(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return false;
  final lower = text.toLowerCase();
  if (!lower.startsWith('http')) return false;
  return lower.contains('jtvnw') ||
      lower.contains('static-cdn') ||
      lower.contains('twimg') ||
      lower.contains('image') ||
      lower.contains('.png') ||
      lower.contains('.jpg') ||
      lower.contains('.jpeg') ||
      lower.contains('.webp') ||
      lower.contains('.gif');
}

String? _findImageUrl(Map<String, dynamic> json) {
  for (final value in json.values) {
    if (value is String && value.startsWith('http')) {
      final lower = value.toLowerCase();
      if (lower.contains('image') ||
          lower.contains('static-cdn') ||
          lower.contains('jtvnw')) {
        return value;
      }
    }

    final map = _asStringMap(value);
    if (map != null) {
      final nested = _findImageUrl(map);
      if (nested != null) return nested;
    } else if (value is List) {
      for (final item in value) {
        final itemMap = _asStringMap(item);
        if (itemMap == null) continue;
        final nested = _findImageUrl(itemMap);
        if (nested != null) return nested;
      }
    }
  }

  return null;
}

String? _rewardTypeFromTitle(String? title) {
  final normalized = title
      ?.trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  switch (normalized) {
    case 'highlight my message':
      return 'SEND_HIGHLIGHTED_MESSAGE';
    case 'send a message in sub only mode':
      return 'SINGLE_MESSAGE_BYPASS_SUB_MODE';
    case 'unlock a random sub emote':
      return 'RANDOM_SUB_EMOTE_UNLOCK';
    case 'choose an emote to unlock':
      return 'CHOSEN_SUB_EMOTE_UNLOCK';
    case 'modify a single emote':
      return 'CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK';
    case 'gigantify an emote':
      return 'SEND_GIGANTIFIED_EMOTE';
  }

  return null;
}

String? _titleFromRewardType(String? type) {
  switch (type) {
    case 'SEND_HIGHLIGHTED_MESSAGE':
      return 'Highlight My Message';
    case 'SINGLE_MESSAGE_BYPASS_SUB_MODE':
      return 'Send a Message in Sub-Only Mode';
    case 'RANDOM_SUB_EMOTE_UNLOCK':
      return 'Unlock a Random Sub Emote';
    case 'CHOSEN_SUB_EMOTE_UNLOCK':
      return 'Choose an Emote to Unlock';
    case 'CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK':
      return 'Modify a Single Emote';
    case 'SEND_GIGANTIFIED_EMOTE':
      return 'Gigantify an Emote';
  }

  if (type == null || type.trim().isEmpty) return null;
  return type.replaceAll('_', ' ');
}
