import '../../models/engagement/twitch_channel_points_models.dart';

/// Parser for Channel Points reward-list responses.
///
/// Boundary:
/// - API service fetches GQL and handles auth/network/GraphQL errors.
/// - This parser finds communityPointsSettings, parses custom/automatic rewards,
///   filters disabled/Bits rewards, and returns normalized models.
class TwitchChannelPointsRewardParser {
  const TwitchChannelPointsRewardParser._();

  static TwitchChannelRewardsResult parseRewardsResponse({
    required Map<dynamic, dynamic> raw,
    required String channelLogin,
  }) {
    final normalizedRaw = _asStringMap(raw) ?? <String, dynamic>{};
    final settings =
        _findMapContainingKey(normalizedRaw, 'customRewards') ??
        _findMapContainingKey(normalizedRaw, 'automaticRewards') ??
        _findMapContainingKey(normalizedRaw, 'communityPointsSettings');

    if (settings == null) {
      throw StateError(
        'ChannelPointsContext did not contain communityPointsSettings/customRewards.',
      );
    }

    final channel = _findNearestChannelMap(normalizedRaw);
    final channelId = _readString(channel, const <String>['id']) ?? '';
    final pointsName = _readString(settings, const <String>['name']);
    final pointsIconUrl = _readString(settings, const <String>['image', 'url']);

    final rewardsByKey = <String, TwitchChannelReward>{};

    for (final rawReward in _readList(settings, const <String>[
      'customRewards',
    ])) {
      final map = _asStringMap(rawReward);
      if (map == null) continue;

      final reward = TwitchChannelReward.fromJson(map, source: 'custom');

      if (!_shouldDisplayReward(raw: map, reward: reward)) continue;
      if (reward.id.isEmpty && reward.title.isEmpty) continue;
      rewardsByKey[reward.id.isNotEmpty ? reward.id : reward.title] = reward;
    }

    for (final rawReward in _readList(settings, const <String>[
      'automaticRewards',
    ])) {
      final map = _asStringMap(rawReward);
      if (map == null) continue;

      final pricingType =
          _readString(map, const <String>['pricingType']) ?? 'CHANNEL_POINTS';
      if (pricingType == 'BITS') continue;

      final reward = TwitchChannelReward.fromJson(map, source: 'automatic');
      if (reward.cost <= 0) continue;
      if (!_shouldDisplayReward(raw: map, reward: reward)) continue;
      if (reward.id.isEmpty && reward.title.isEmpty) continue;

      rewardsByKey[reward.id.isNotEmpty ? reward.id : reward.title] = reward;
    }

    final rewards = rewardsByKey.values.toList(growable: false);
    rewards.sort((a, b) {
      final aAvailable = a.isBasicallyAvailable;
      final bAvailable = b.isBasicallyAvailable;
      if (aAvailable != bAvailable) return aAvailable ? -1 : 1;

      final costCompare = a.cost.compareTo(b.cost);
      if (costCompare != 0) return costCompare;

      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return TwitchChannelRewardsResult(
      channelLogin: channelLogin,
      channelId: channelId,
      pointsName: pointsName,
      pointsIconUrl: pointsIconUrl,
      rewards: rewards,
      raw: normalizedRaw,
    );
  }

  static bool _shouldDisplayReward({
    required Map<String, dynamic> raw,
    required TwitchChannelReward reward,
  }) {
    // Match Twitch: skip disabled rewards only. Do not hide rewards just
    // because Twitch marks them hidden-for-subs/viewer; UI can show locked state.
    if (!reward.isEnabled) return false;
    if (_readBool(raw, const <String>['isDisabled']) == true) return false;
    if (_readBool(raw, const <String>['disabled']) == true) return false;
    return true;
  }
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
    return value.map((key, value) => MapEntry(key.toString(), value));
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
