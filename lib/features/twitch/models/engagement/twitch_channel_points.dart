class TwitchChannelPointsBundle {
  final String channelLogin;
  final List<TwitchChannelPointsContextSnapshot> snapshots;

  const TwitchChannelPointsBundle({
    required this.channelLogin,
    required this.snapshots,
  });

  int get rewardCount {
    final ids = <String>{};

    for (final snapshot in snapshots) {
      for (final reward in snapshot.rewards) {
        final key = reward.id.isNotEmpty ? reward.id : reward.title;
        if (key.isNotEmpty) ids.add(key);
      }
    }

    return ids.length;
  }

  bool get hasUsefulViewerData {
    return snapshots.any((snapshot) {
      return snapshot.balance != null ||
          (snapshot.availableClaimId != null && snapshot.availableClaimId!.isNotEmpty) ||
          snapshot.availableClaimValue != null ||
          (snapshot.pointsName != null && snapshot.pointsName!.isNotEmpty);
    });
  }

  TwitchChannelPointsBundle mergedWithFallback(
    TwitchChannelPointsBundle fallback,
  ) {
    final merged = <TwitchChannelPointsContextSnapshot>[];

    for (final snapshot in snapshots) {
      final fallbackSnapshot = fallback._snapshotByOperation(snapshot.operationName);
      merged.add(snapshot.mergedWithFallback(fallbackSnapshot));
    }

    for (final fallbackSnapshot in fallback.snapshots) {
      final exists = merged.any(
        (snapshot) => snapshot.operationName == fallbackSnapshot.operationName,
      );
      if (!exists) {
        merged.add(fallbackSnapshot);
      }
    }

    return TwitchChannelPointsBundle(
      channelLogin: channelLogin.isNotEmpty ? channelLogin : fallback.channelLogin,
      snapshots: merged,
    );
  }

  TwitchChannelPointsContextSnapshot? _snapshotByOperation(String operationName) {
    for (final snapshot in snapshots) {
      if (snapshot.operationName == operationName) return snapshot;
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelLogin': channelLogin,
      'count': snapshots.length,
      'rewardCount': rewardCount,
      'hasUsefulViewerData': hasUsefulViewerData,
      'snapshots': snapshots.map((snapshot) => snapshot.toJson()).toList(),
    };
  }
}

class TwitchChannelPointsContextSnapshot {
  final String operationName;
  final int? balance;
  final String? availableClaimId;
  final int? availableClaimValue;
  final String? pointsName;
  final List<TwitchChannelPointReward> rewards;
  final Map<String, dynamic>? rawResponse;

  const TwitchChannelPointsContextSnapshot({
    required this.operationName,
    this.balance,
    this.availableClaimId,
    this.availableClaimValue,
    this.pointsName,
    this.rewards = const <TwitchChannelPointReward>[],
    this.rawResponse,
  });

  factory TwitchChannelPointsContextSnapshot.fromRaw({
    required String operationName,
    required Object? response,
  }) {
    final root = response is Map<String, dynamic> ? response : <String, dynamic>{};
    final maps = _collectMaps(root);

    final balanceMap = maps.firstWhere(
      (map) => map.containsKey('balance') || map.containsKey('pointsBalance'),
      orElse: () => const <String, dynamic>{},
    );

    final claimMap = maps.firstWhere(
      (map) =>
          map.containsKey('claimID') ||
          map.containsKey('claimId') ||
          map.containsKey('availableClaimID') ||
          map.containsKey('availableClaimId'),
      orElse: () => const <String, dynamic>{},
    );

    final pointsNameMap = maps.firstWhere(
      (map) =>
          map.containsKey('pointsName') ||
          map.containsKey('customRewardName') ||
          map.containsKey('name'),
      orElse: () => const <String, dynamic>{},
    );

    final rewards = maps
        .where((map) {
          final hasCost = map.containsKey('cost') || map.containsKey('price');
          final hasTitle = map.containsKey('title') || map.containsKey('name');
          final hasRewardType = map['__typename']?.toString().toLowerCase().contains('reward') == true;
          return hasTitle && (hasCost || hasRewardType);
        })
        .map(TwitchChannelPointReward.fromFlexibleJson)
        .where((reward) => reward.id.isNotEmpty || reward.title.isNotEmpty)
        .toList(growable: false);

    return TwitchChannelPointsContextSnapshot(
      operationName: operationName,
      balance: _readInt(balanceMap['balance'] ?? balanceMap['pointsBalance']),
      availableClaimId: _readString(
        claimMap['claimID'] ??
            claimMap['claimId'] ??
            claimMap['availableClaimID'] ??
            claimMap['availableClaimId'],
      ),
      availableClaimValue: _readInt(
        claimMap['claimValue'] ??
            claimMap['value'] ??
            claimMap['amount'] ??
            claimMap['availableClaimValue'],
      ),
      pointsName: _readString(
        pointsNameMap['pointsName'] ??
            pointsNameMap['customRewardName'] ??
            pointsNameMap['name'],
      ),
      rewards: rewards,
      rawResponse: root,
    );
  }

  TwitchChannelPointsContextSnapshot mergedWithFallback(
    TwitchChannelPointsContextSnapshot? fallback,
  ) {
    if (fallback == null) return this;

    return TwitchChannelPointsContextSnapshot(
      operationName: operationName,
      balance: balance ?? fallback.balance,
      availableClaimId: (availableClaimId != null && availableClaimId!.isNotEmpty)
          ? availableClaimId
          : fallback.availableClaimId,
      availableClaimValue: availableClaimValue ?? fallback.availableClaimValue,
      pointsName: (pointsName != null && pointsName!.isNotEmpty)
          ? pointsName
          : fallback.pointsName,
      rewards: rewards.isNotEmpty ? rewards : fallback.rewards,
      rawResponse: rawResponse ?? fallback.rawResponse,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'operationName': operationName,
      'balance': balance,
      'availableClaimId': availableClaimId,
      'availableClaimValue': availableClaimValue,
      'pointsName': pointsName,
      'rewardCount': rewards.length,
      'rewards': rewards.map((reward) => reward.toJson()).toList(),
      'rawTopLevelKeys': rawResponse?.keys.toList(),
    };
  }
}

class TwitchChannelPointReward {
  final String id;
  final String title;
  final String prompt;
  final int cost;
  final bool isEnabled;
  final bool isPaused;
  final bool isInStock;
  final bool isUserInputRequired;
  final String backgroundColor;
  final String imageUrl;

  const TwitchChannelPointReward({
    required this.id,
    required this.title,
    required this.prompt,
    required this.cost,
    required this.isEnabled,
    required this.isPaused,
    required this.isInStock,
    required this.isUserInputRequired,
    required this.backgroundColor,
    required this.imageUrl,
  });

  factory TwitchChannelPointReward.fromFlexibleJson(Map<String, dynamic> json) {
    final image = _findImageUrl(json);

    return TwitchChannelPointReward(
      id: _readString(json['id']) ?? '',
      title: _readString(json['title'] ?? json['name']) ?? '',
      prompt: _readString(json['prompt'] ?? json['description']) ?? '',
      cost: _readInt(json['cost'] ?? json['price']) ?? 0,
      isEnabled: _readBool(json['isEnabled'] ?? json['enabled']) ?? true,
      isPaused: _readBool(json['isPaused'] ?? json['paused']) ?? false,
      isInStock: _readBool(json['isInStock'] ?? json['inStock']) ?? true,
      isUserInputRequired:
          _readBool(json['isUserInputRequired'] ?? json['userInputRequired']) ?? false,
      backgroundColor: _readString(json['backgroundColor'] ?? json['color']) ?? '',
      imageUrl: image ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'prompt': prompt,
      'cost': cost,
      'isEnabled': isEnabled,
      'isPaused': isPaused,
      'isInStock': isInStock,
      'isUserInputRequired': isUserInputRequired,
      'backgroundColor': backgroundColor,
      'imageUrl': imageUrl,
    };
  }
}

List<Map<String, dynamic>> _collectMaps(Object? value) {
  final output = <Map<String, dynamic>>[];

  void visit(Object? item) {
    if (item is Map<String, dynamic>) {
      output.add(item);
      for (final value in item.values) {
        visit(value);
      }
    } else if (item is List) {
      for (final value in item) {
        visit(value);
      }
    }
  }

  visit(value);
  return output;
}

String? _readString(Object? value) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) return null;
  return text;
}

int? _readInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}

bool? _readBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  final text = value.toString().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return null;
}

String? _findImageUrl(Map<String, dynamic> json) {
  final direct = _readString(json['imageURL'] ?? json['imageUrl'] ?? json['url']);
  if (direct != null && direct.startsWith('http')) return direct;

  for (final value in json.values) {
    if (value is Map<String, dynamic>) {
      final nested = _findImageUrl(value);
      if (nested != null) return nested;
    } else if (value is List) {
      for (final item in value) {
        if (item is Map<String, dynamic>) {
          final nested = _findImageUrl(item);
          if (nested != null) return nested;
        }
      }
    }
  }

  return null;
}
