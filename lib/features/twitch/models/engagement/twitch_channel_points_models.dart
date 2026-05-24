/// Channel Points data models and reward-normalization helpers.
///
/// Keep Twitch response parsing that belongs to an individual reward here.
/// API services should only fetch data and call parsers; UI should consume
/// these normalized models through toJson().
class TwitchChannelPointsContext {
  final String channelId;
  final String channelLogin;
  final int balance;
  final String? availableClaimId;
  final int availableClaimPoints;
  final String? pointsName;
  final String? pointsIconUrl;
  final dynamic raw;

  const TwitchChannelPointsContext({
    required this.channelId,
    required this.channelLogin,
    required this.balance,
    required this.availableClaimId,
    required this.availableClaimPoints,
    required this.pointsName,
    required this.pointsIconUrl,
    required this.raw,
  });

  bool get hasAvailableClaim {
    return availableClaimId != null && availableClaimId!.trim().isNotEmpty;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelId': channelId,
      'channelLogin': channelLogin,
      'balance': balance,
      'availableClaimId': availableClaimId,
      'availableClaimPoints': availableClaimPoints,
      'pointsName': pointsName,
      'pointsIconUrl': pointsIconUrl,
      'hasAvailableClaim': hasAvailableClaim,
      'raw': raw,
    };
  }
}

class TwitchChannelPointsClaimResult {
  final bool ok;
  final int pointsEarned;
  final dynamic raw;

  const TwitchChannelPointsClaimResult({
    required this.ok,
    required this.pointsEarned,
    required this.raw,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ok': ok,
      'pointsEarned': pointsEarned,
      'raw': raw,
    };
  }
}

class TwitchChannelRewardsResult {
  final String channelLogin;
  final String channelId;
  final String? pointsName;
  final String? pointsIconUrl;
  final List<TwitchChannelReward> rewards;
  final dynamic raw;

  const TwitchChannelRewardsResult({
    required this.channelLogin,
    required this.channelId,
    required this.pointsName,
    required this.pointsIconUrl,
    required this.rewards,
    required this.raw,
  });

  int get availableCount {
    return rewards.where((reward) => reward.isBasicallyAvailable).length;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelLogin': channelLogin,
      'channelId': channelId,
      'pointsName': pointsName,
      'pointsIconUrl': pointsIconUrl,
      'rewardCount': rewards.length,
      'availableCount': availableCount,
      'rewards': rewards.map((reward) => reward.toJson()).toList(),
      'raw': raw,
    };
  }
}

class TwitchChannelReward {
  final String id;
  final String title;
  final String prompt;
  /// UI display cost. This is what the Twitch rewards panel shows.
  final int cost;

  /// Cost sent to Twitch redemption mutations.
  ///
  /// Built-in rewards can expose multiple cost-like fields. Twitch expects the
  /// streamer override `cost` when present, otherwise the current tiered
  /// `defaultCost`. `minimumCost` is only a lower bound; sending it can produce
  /// REWARD_COST_MISMATCH.
  final int redeemCost;

  final String imageUrl;
  final String customImageUrl;
  final String defaultImageUrl;
  final String backgroundColor;
  final bool isEnabled;
  final bool isPaused;
  final bool isInStock;
  final bool isUserInputRequired;
  final String? cooldownExpiresAt;
  final int? maxPerStream;
  final int? maxPerUserPerStream;
  final int? globalCooldownSeconds;
  final String source;
  final String? rewardType;
  final String? pricingType;

  const TwitchChannelReward({
    required this.id,
    required this.title,
    required this.prompt,
    required this.cost,
    required this.redeemCost,
    required this.imageUrl,
    this.customImageUrl = '',
    this.defaultImageUrl = '',
    required this.backgroundColor,
    required this.isEnabled,
    required this.isPaused,
    required this.isInStock,
    required this.isUserInputRequired,
    required this.cooldownExpiresAt,
    required this.maxPerStream,
    required this.maxPerUserPerStream,
    required this.globalCooldownSeconds,
    required this.source,
    required this.rewardType,
    required this.pricingType,
  });

  bool get isBasicallyAvailable {
    return isEnabled && !isPaused && isInStock && !isCoolingDown;
  }

  bool get isCoolingDown {
    final raw = cooldownExpiresAt?.trim();
    if (raw == null || raw.isEmpty) return false;

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return false;

    return parsed.toUtc().isAfter(DateTime.now().toUtc());
  }

  bool isRedeemableWithBalance(int? balance) {
    if (!isBasicallyAvailable) return false;
    if (balance == null) return true;
    return balance >= cost;
  }

  String get resolvedImageUrl {
    final custom = customImageUrl.trim();
    if (custom.isNotEmpty) return custom;

    final fallback = defaultImageUrl.trim();
    if (fallback.isNotEmpty) return fallback;

    return imageUrl.trim();
  }

  String get normalizedRewardType {
    final type = rewardType?.trim().toUpperCase();
    if (type != null && type.isNotEmpty) return type;

    final titleType = _rewardTypeFromTitle(title);
    if (titleType != null) return titleType;

    final idText = id.trim().toUpperCase();
    if (idText.isNotEmpty) return idText;

    return title.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '_');
  }

  bool get isAutomaticReward {
    return source.trim().toLowerCase() == 'automatic';
  }

  bool get supportsAutomaticRewardRedeem {
    switch (normalizedRewardType) {
      case 'SEND_HIGHLIGHTED_MESSAGE':
      case 'SINGLE_MESSAGE_BYPASS_SUB_MODE':
      case 'RANDOM_SUB_EMOTE_UNLOCK':
      case 'CHOSEN_SUB_EMOTE_UNLOCK':
      case 'CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK':
      case 'SEND_GIGANTIFIED_EMOTE':
        return true;
    }

    return false;
  }

  String get automaticInputMode {
    if (!isAutomaticReward) {
      return isUserInputRequired ? 'text' : 'none';
    }

    switch (normalizedRewardType) {
      case 'SEND_HIGHLIGHTED_MESSAGE':
      case 'SINGLE_MESSAGE_BYPASS_SUB_MODE':
        return 'message';
      case 'RANDOM_SUB_EMOTE_UNLOCK':
        return 'none';
      case 'CHOSEN_SUB_EMOTE_UNLOCK':
        return 'emote';
      case 'CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK':
        return 'modified_emote';
      case 'SEND_GIGANTIFIED_EMOTE':
        return 'gigantify_emote';
    }

    return 'unsupported';
  }

  bool get supportsDirectCustomRewardRedeem {
    if (isAutomaticReward) return supportsAutomaticRewardRedeem;
    final type = rewardType?.trim().toUpperCase();
    return type == null || type.isEmpty || type == 'CUSTOM';
  }

  String? statusText({
    int? balance,
  }) {
    if (!isEnabled) return 'Disabled';
    if (isPaused) return 'Paused';
    if (!isInStock) return 'Out of stock';

    final rawCooldown = cooldownExpiresAt?.trim();
    if (rawCooldown != null && rawCooldown.isNotEmpty) {
      final parsed = DateTime.tryParse(rawCooldown);
      if (parsed != null) {
        final remaining = parsed.toUtc().difference(DateTime.now().toUtc());
        if (!remaining.isNegative) {
          final seconds = remaining.inSeconds;
          if (seconds >= 3600) {
            return '${(seconds / 3600).ceil()}h cooldown';
          }
          if (seconds >= 60) {
            return '${(seconds / 60).ceil()}m cooldown';
          }
          return '${seconds.clamp(1, 59)}s cooldown';
        }
      }
    }

    if (balance != null && balance < cost) return 'Insufficient points';
    if (isUserInputRequired) return 'Requires input';

    return null;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'prompt': prompt,
      'cost': cost,
      'redeemCost': redeemCost,
      'imageUrl': imageUrl,
      'resolvedImageUrl': resolvedImageUrl,
      'customImageUrl': customImageUrl,
      'defaultImageUrl': defaultImageUrl,
      'backgroundColor': backgroundColor,
      'isEnabled': isEnabled,
      'isPaused': isPaused,
      'isInStock': isInStock,
      'isUserInputRequired': isUserInputRequired,
      'cooldownExpiresAt': cooldownExpiresAt,
      'maxPerStream': maxPerStream,
      'maxPerUserPerStream': maxPerUserPerStream,
      'globalCooldownSeconds': globalCooldownSeconds,
      'source': source,
      'rewardType': rewardType,
      'pricingType': pricingType,
      'normalizedRewardType': normalizedRewardType,
      'automaticInputMode': automaticInputMode,
      'supportsAutomaticRewardRedeem': supportsAutomaticRewardRedeem,
      'supportsDirectCustomRewardRedeem': supportsDirectCustomRewardRedeem,
      'isBasicallyAvailable': isBasicallyAvailable,
    };
  }

  factory TwitchChannelReward.fromJson(
    Map<String, dynamic> json, {
    required String source,
  }) {
    final rewardType = _readString(json, const <String>['type']) ??
        _readString(json, const <String>['rewardType']);
    final pricingType =
        _readString(json, const <String>['pricingType']) ?? 'CHANNEL_POINTS';

    final title = _readString(json, const <String>['title']) ??
        _readString(json, const <String>['name']) ??
        _titleFromRewardType(rewardType) ??
        'Reward';

    final cost = _resolveRewardCost(
      json,
      source: source,
    );

    final serializedRedeemCost = _readInt(json, const <String>['redeemCost']) ??
        _readInt(json, const <String>['redeem_cost']);
    final redeemCost = serializedRedeemCost != null && serializedRedeemCost > 0
        ? serializedRedeemCost
        : _resolveRewardRedeemCost(
            json,
            source: source,
            displayCost: cost,
          );

    final customImageUrl = _readRewardImageUrl(
          json,
          rootKeys: const <String>['image', 'customImage', 'custom_image'],
        ) ??
        '';
    final defaultImageUrl = _readRewardImageUrl(
          json,
          rootKeys: const <String>[
            'defaultImage',
            'default_image',
            'defaultImageUrl',
            'default_image_url',
          ],
        ) ??
        '';
    final imageUrl = customImageUrl.isNotEmpty
        ? customImageUrl
        : defaultImageUrl.isNotEmpty
            ? defaultImageUrl
            : (_readString(json, const <String>['imageUrl']) ??
                    _readString(json, const <String>['image_url']) ??
                    _findImageUrl(json) ??
                    '');

    final backgroundColor =
        _readString(json, const <String>['backgroundColor']) ??
            _readString(json, const <String>['defaultBackgroundColor']) ??
            '#9147FF';

    final maxPerStreamSetting =
        _readMap(json, const <String>['maxPerStreamSetting']);
    final maxPerUserPerStreamSetting =
        _readMap(json, const <String>['maxPerUserPerStreamSetting']);
    final globalCooldownSetting =
        _readMap(json, const <String>['globalCooldownSetting']);

    return TwitchChannelReward(
      id: _readString(json, const <String>['id']) ?? '',
      title: title,
      prompt: _readString(json, const <String>['prompt']) ??
          _readString(json, const <String>['description']) ??
          '',
      cost: cost,
      redeemCost: redeemCost,
      imageUrl: imageUrl,
      customImageUrl: customImageUrl,
      defaultImageUrl: defaultImageUrl,
      backgroundColor: backgroundColor,
      isEnabled: _readBool(json, const <String>['isEnabled']) ?? true,
      isPaused: _readBool(json, const <String>['isPaused']) ?? false,
      isInStock: _readBool(json, const <String>['isInStock']) ?? true,
      isUserInputRequired:
          (_readBool(json, const <String>['isUserInputRequired']) ?? false) ||
              rewardType == 'SEND_HIGHLIGHTED_MESSAGE' ||
              rewardType == 'SINGLE_MESSAGE_BYPASS_SUB_MODE',
      cooldownExpiresAt:
          _readString(json, const <String>['cooldownExpiresAt']),
      maxPerStream:
          _readBool(maxPerStreamSetting, const <String>['isEnabled']) == true
              ? _readInt(maxPerStreamSetting, const <String>['maxPerStream'])
              : null,
      maxPerUserPerStream: _readBool(
                maxPerUserPerStreamSetting,
                const <String>['isEnabled'],
              ) ==
              true
          ? _readInt(
              maxPerUserPerStreamSetting,
              const <String>['maxPerUserPerStream'],
            )
          : null,
      globalCooldownSeconds:
          _readBool(globalCooldownSetting, const <String>['isEnabled']) == true
              ? _readInt(
                  globalCooldownSetting,
                  const <String>['globalCooldownSeconds'],
                )
              : _readInt(json, const <String>['globalCooldownSeconds']),
      source: source,
      rewardType: rewardType,
      pricingType: pricingType,
    );
  }
}

class TwitchChannelRewardRedeemResult {
  final bool ok;
  final String rewardId;
  final String transactionId;
  final dynamic raw;

  const TwitchChannelRewardRedeemResult({
    required this.ok,
    required this.rewardId,
    required this.transactionId,
    required this.raw,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ok': ok,
      'rewardId': rewardId,
      'transactionId': transactionId,
      'raw': raw,
    };
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
    // StreamNook parity: cost -> defaultCost -> minimumCost.
    // minimumCost is only Twitch's floor, not the mutation price.
    if (cost != null && cost > 0) return cost;
    if (defaultCost != null && defaultCost > 0) return defaultCost;
    if (minimumCost != null && minimumCost > 0) return minimumCost;
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
    // StreamNook parity: cost -> defaultCost -> minimumCost.
    // Sending minimumCost before defaultCost causes REWARD_COST_MISMATCH.
    if (cost != null && cost > 0) return cost;
    if (defaultCost != null && defaultCost > 0) return defaultCost;
    if (minimumCost != null && minimumCost > 0) return minimumCost;
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
  // Match Twitch: skip disabled rewards only. Do not hide rewards just
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
