import '../../api/engagement/twitch_channel_points_api_service.dart';

class TwitchChannelPointsRuntimeService {
  final TwitchChannelPointsApiService channelPointsApi;

  /// Optional dedicated backend for Channel Points emote menus.
  ///
  /// If omitted, [channelPointsApi.emoteApi] is used. This keeps old wiring
  /// compatible while allowing the menu backend to be tested or replaced
  /// without touching reward redemption.
  final TwitchChannelPointsEmoteApiService? channelPointsEmoteApi;

  const TwitchChannelPointsRuntimeService({
    required this.channelPointsApi,
    this.channelPointsEmoteApi,
  });

  Future<TwitchChannelPointsClaimResult> claimBonus({
    required String channelId,
    required String claimId,
  }) async {
    try {
      return await channelPointsApi.claimBonus(
        channelId: channelId,
        claimId: claimId,
      );
    } catch (error) {
      // Twitch's community-points bonus claim is effectively idempotent from a
      // UI perspective: the claim can disappear server-side even when the
      // response path reports an error such as already claimed / not found / no
      // longer available. StreamNook-style handling treats these as a consumed
      // claim and lets the caller refresh the snapshot instead of keeping the
      // gift button around until the user reopens the stream.
      if (_looksLikeConsumedClaimError(error)) {
        return TwitchChannelPointsClaimResult(
          ok: true,
          pointsEarned: 50,
          raw: <String, dynamic>{
            'bestEffort': true,
            'source': 'runtime-consumed-claim-error',
            'error': error.toString(),
          },
        );
      }

      rethrow;
    }
  }

  bool _looksLikeConsumedClaimError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('already_claimed') ||
        text.contains('already claimed') ||
        text.contains('claim_not_found') ||
        text.contains('claim not found') ||
        text.contains('claim_not_available') ||
        text.contains('claim not available') ||
        text.contains('claim_unavailable') ||
        text.contains('claim unavailable') ||
        text.contains('not_found') ||
        text.contains('not found') ||
        text.contains('unavailable');
  }

  Future<TwitchChannelRewardRedeemResult> redeemReward({
    required String channelId,
    required Map<String, dynamic> reward,
    String textInput = '',
  }) {
    final parsedReward = _parseRedeemableReward(reward);

    return channelPointsApi.redeemReward(
      channelId: channelId,
      reward: parsedReward,
      textInput: textInput,
    );
  }

  Future<TwitchChannelRewardRedeemResult> sendHighlightedMessage({
    required String channelId,
    required Map<String, dynamic> reward,
    required String message,
  }) {
    final parsedReward = _parseRedeemableReward(reward);

    return channelPointsApi.sendHighlightedMessage(
      channelId: channelId,
      reward: parsedReward,
      message: message,
    );
  }

  Future<TwitchChannelRewardRedeemResult> unlockRandomSubscriberEmote({
    required String channelId,
    required Map<String, dynamic> reward,
  }) {
    final parsedReward = _parseRedeemableReward(reward);

    return channelPointsApi.unlockRandomSubscriberEmote(
      channelId: channelId,
      reward: parsedReward,
    );
  }

  Future<TwitchChannelRewardRedeemResult> unlockChosenSubscriberEmote({
    required String channelId,
    required Map<String, dynamic> reward,
    required String emoteId,
  }) {
    final parsedReward = _parseRedeemableReward(reward);

    return channelPointsApi.unlockChosenSubscriberEmote(
      channelId: channelId,
      reward: parsedReward,
      emoteId: emoteId,
    );
  }

  Future<TwitchChannelRewardRedeemResult> unlockModifiedSubscriberEmote({
    required String channelId,
    required Map<String, dynamic> reward,
    required String modifiedEmoteId,
    String? modifierId,
  }) {
    final parsedReward = _parseRedeemableReward(reward);

    return channelPointsApi.unlockModifiedSubscriberEmote(
      channelId: channelId,
      reward: parsedReward,
      // StreamNook-style: modifiedEmoteId is already the final id, e.g. 1022569_BW.
      emoteId: modifiedEmoteId,
      emoteModifierId: modifierId,
    );
  }

  TwitchChannelReward _parseRedeemableReward(Map<String, dynamic> reward) {
    final source = reward['source']?.toString() ?? '';
    final isPublicFallback = source == 'publicFallback' ||
        reward['publicFallback'] == true ||
        reward['isRedeemable'] == false;

    if (isPublicFallback) {
      throw StateError(
        'This reward was loaded from the public fallback snapshot and cannot be redeemed safely. Refresh rewards with authenticated ChannelPointsContext first.',
      );
    }

    return TwitchChannelReward.fromJson(
      reward,
      source: source.isEmpty ? 'runtime' : source,
    );
  }

  Future<List<TwitchChannelPointEmoteOption>> getModifiableEmotes({
    required String channelLogin,
    String? channelId,
  }) {
    final emoteApi = channelPointsEmoteApi ?? channelPointsApi.emoteApi;

    return emoteApi.getModifiableEmotes(
      channelLogin: channelLogin,
      channelId: channelId,
      resolveChannelId: ({required String channelLogin}) async {
        final context = await channelPointsApi.getContext(
          channelLogin: channelLogin,
        );
        return context.channelId;
      },
    );
  }

  Future<TwitchChannelPointsRuntimeSnapshot> load({
    required String channelLogin,
  }) async {
    final startedAt = DateTime.now();
    final login = channelLogin.trim().toLowerCase();

    Map<String, dynamic>? publicRead;
    String? publicError;
    TwitchChannelPointsContext? context;
    String? contextError;
    TwitchChannelRewardsResult? rewardsResult;
    String? rewardsError;

    try {
      final publicBundle = await channelPointsApi.fetchChannelPointsBundle(
        channelLogin: login,
      );
      publicRead = publicBundle.toJson();
    } catch (error) {
      publicError = error.toString();
    }

    try {
      context = await channelPointsApi.getContext(
        channelLogin: login,
      );
    } catch (error) {
      contextError = error.toString();
    }

    try {
      rewardsResult = await channelPointsApi.getRewards(
        channelLogin: login,
      );
    } catch (error) {
      rewardsError = error.toString();
    }

    return TwitchChannelPointsRuntimeSnapshot(
      channelLogin: login,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      publicRead: publicRead,
      publicError: publicError,
      context: context,
      contextError: contextError,
      rewardsResult: rewardsResult,
      rewardsError: rewardsError,
    );
  }
}

class TwitchChannelPointsRuntimeSnapshot {
  final String channelLogin;
  final DateTime startedAt;
  final DateTime completedAt;
  final Map<String, dynamic>? publicRead;
  final String? publicError;
  final TwitchChannelPointsContext? context;
  final String? contextError;
  final TwitchChannelRewardsResult? rewardsResult;
  final String? rewardsError;

  const TwitchChannelPointsRuntimeSnapshot({
    required this.channelLogin,
    required this.startedAt,
    required this.completedAt,
    required this.publicRead,
    required this.publicError,
    required this.context,
    required this.contextError,
    required this.rewardsResult,
    required this.rewardsError,
  });

  bool get publicOk => publicError == null;
  bool get contextOk => contextError == null;
  bool get rewardsOk => rewardsError == null;
  bool get usable => publicOk || contextOk || rewardsOk;

  int get elapsedMilliseconds {
    return completedAt.difference(startedAt).inMilliseconds;
  }

  int? get balance => context?.balance;
  String? get availableClaimId => context?.availableClaimId;
  int get availableClaimPoints => context?.availableClaimPoints ?? 0;
  bool get hasAvailableClaim => context?.hasAvailableClaim ?? false;
  String? get pointsName => context?.pointsName ?? rewardsResult?.pointsName;
  String? get pointsIconUrl =>
      context?.pointsIconUrl ?? rewardsResult?.pointsIconUrl;
  String? get channelId => context?.channelId ?? rewardsResult?.channelId;

  List<Map<String, dynamic>> get rewards {
    final channelRewards = rewardsResult;
    if (channelRewards != null && channelRewards.rewards.isNotEmpty) {
      return channelRewards.rewards
          .map((reward) => reward.toJson())
          .toList(growable: false);
    }

    return _publicRewardsFallback();
  }

  List<Map<String, dynamic>> _publicRewardsFallback() {
    final public = publicRead;
    if (public == null) return const <Map<String, dynamic>>[];

    final snapshots = public['snapshots'];
    if (snapshots is! List) return const <Map<String, dynamic>>[];

    final byKey = <String, Map<String, dynamic>>{};

    for (final snapshot in snapshots) {
      if (snapshot is! Map) continue;

      final rawRewards = snapshot['rewards'];
      if (rawRewards is! List) continue;

      for (final reward in rawRewards) {
        if (reward is! Map) continue;

        final mapped = reward.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final resolvedImageUrl = _resolveRewardImageUrl(mapped);
        if (resolvedImageUrl.isNotEmpty) {
          mapped['imageUrl'] = resolvedImageUrl;
          mapped['resolvedImageUrl'] = resolvedImageUrl;
        }

        mapped['isEnabled'] = mapped['isEnabled'] ?? true;
        mapped['isPaused'] = mapped['isPaused'] ?? false;
        mapped['isInStock'] = mapped['isInStock'] ?? true;
        mapped['isBasicallyAvailable'] =
            mapped['isBasicallyAvailable'] ?? true;
        mapped['source'] = 'publicFallback';
        mapped['publicFallback'] = true;
        mapped['isRedeemable'] = false;
        mapped['supportsDirectCustomRewardRedeem'] = false;

        final id = mapped['id']?.toString() ?? '';
        final title = mapped['title']?.toString() ?? '';
        final key = id.isNotEmpty ? id : title;

        if (key.isEmpty) continue;
        byKey[key] = mapped;
      }
    }

    final output = byKey.values.toList(growable: false);
    output.sort((a, b) {
      final aCost = int.tryParse(a['cost']?.toString() ?? '') ?? 0;
      final bCost = int.tryParse(b['cost']?.toString() ?? '') ?? 0;
      if (aCost != bCost) return aCost.compareTo(bCost);
      return (a['title']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['title']?.toString() ?? '').toLowerCase());
    });

    return output;
  }

  String _resolveRewardImageUrl(Map<String, dynamic> reward) {
    final custom = _readNestedString(reward, const <String>['image', 'url4x']) ??
        _readNestedString(reward, const <String>['image', 'url_4x']) ??
        _readNestedString(reward, const <String>['image', 'url2x']) ??
        _readNestedString(reward, const <String>['image', 'url_2x']) ??
        _readNestedString(reward, const <String>['image', 'url']) ??
        _readFlatString(reward, 'customImageUrl') ??
        _readFlatString(reward, 'imageUrl') ??
        _readFlatString(reward, 'image_url');

    if (_looksLikeImageUrl(custom)) return custom!.trim();

    final fallback =
        _readNestedString(reward, const <String>['defaultImage', 'url4x']) ??
            _readNestedString(reward, const <String>['defaultImage', 'url_4x']) ??
            _readNestedString(reward, const <String>['defaultImage', 'url2x']) ??
            _readNestedString(reward, const <String>['defaultImage', 'url_2x']) ??
            _readNestedString(reward, const <String>['defaultImage', 'url']) ??
            _readNestedString(reward, const <String>['default_image', 'url4x']) ??
            _readNestedString(reward, const <String>['default_image', 'url_4x']) ??
            _readNestedString(reward, const <String>['default_image', 'url2x']) ??
            _readNestedString(reward, const <String>['default_image', 'url_2x']) ??
            _readNestedString(reward, const <String>['default_image', 'url']) ??
            _readFlatString(reward, 'defaultImageUrl') ??
            _readFlatString(reward, 'default_image_url');

    if (_looksLikeImageUrl(fallback)) return fallback!.trim();
    return '';
  }

  String? _readFlatString(Map<String, dynamic> map, String key) {
    final text = map[key]?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _readNestedString(Map<String, dynamic> map, List<String> path) {
    Object? current = map;

    for (final key in path) {
      if (current is! Map) return null;
      current = current[key];
    }

    final text = current?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  bool _looksLikeImageUrl(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return false;
    final lower = text.toLowerCase();
    return lower.startsWith('http') &&
        (lower.contains('jtvnw') ||
            lower.contains('static-cdn') ||
            lower.contains('twimg') ||
            lower.contains('.png') ||
            lower.contains('.jpg') ||
            lower.contains('.jpeg') ||
            lower.contains('.webp') ||
            lower.contains('.gif'));
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelLogin': channelLogin,
      'elapsedMilliseconds': elapsedMilliseconds,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt.toIso8601String(),
      'usable': usable,
      'publicOk': publicOk,
      'publicError': publicError,
      'contextOk': contextOk,
      'contextError': contextError,
      'rewardsOk': rewardsOk,
      'rewardsError': rewardsError,
      'summary': <String, dynamic>{
        'channelId': channelId,
        'balance': balance,
        'availableClaimId': availableClaimId,
        'availableClaimPoints': availableClaimPoints,
        'hasAvailableClaim': hasAvailableClaim,
        'pointsName': pointsName,
        'pointsIconUrl': pointsIconUrl,
        'rewardCount': rewards.length,
      },
      'rewards': rewards,
      'context': context?.toJson(),
      'rewardsResult': rewardsResult?.toJson(),
      'publicRead': publicRead,
    };
  }
}
