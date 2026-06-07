class TwitchHypeTrainSnapshot {
  final String id;
  final String channelId;
  final String channelLogin;
  final String channelDisplayName;
  final int level;
  final int total;
  final int progress;
  final int goal;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? endedAt;
  final DateTime? cooldownEndsAt;
  final String type;
  final bool isSharedTrain;
  final List<TwitchHypeTrainContribution> topContributions;
  final List<TwitchHypeTrainParticipant> sharedTrainParticipants;

  const TwitchHypeTrainSnapshot({
    required this.id,
    required this.channelId,
    required this.channelLogin,
    required this.channelDisplayName,
    required this.level,
    required this.total,
    required this.progress,
    required this.goal,
    required this.startedAt,
    required this.expiresAt,
    required this.endedAt,
    required this.cooldownEndsAt,
    required this.type,
    required this.isSharedTrain,
    required this.topContributions,
    required this.sharedTrainParticipants,
  });

  factory TwitchHypeTrainSnapshot.empty({
    String channelLogin = '',
    String channelId = '',
  }) {
    return TwitchHypeTrainSnapshot(
      id: '',
      channelId: channelId,
      channelLogin: channelLogin.trim().toLowerCase(),
      channelDisplayName: '',
      level: 0,
      total: 0,
      progress: 0,
      goal: 0,
      startedAt: null,
      expiresAt: null,
      endedAt: DateTime.fromMillisecondsSinceEpoch(0),
      cooldownEndsAt: null,
      type: '',
      isSharedTrain: false,
      topContributions: const <TwitchHypeTrainContribution>[],
      sharedTrainParticipants: const <TwitchHypeTrainParticipant>[],
    );
  }

  factory TwitchHypeTrainSnapshot.fromJson(Map<String, dynamic> json) {
    final source = _readSnapshotSource(json);
    final channel = _readMap(source['channel'] ?? source['broadcaster']);
    final progress = _progressMap(source);
    final participants = _readList(
      source['sharedTrainParticipants'] ??
          source['shared_train_participants'] ??
          source['participants'] ??
          source['sharedParticipants'] ??
          source['shared_participants'],
    );

    return TwitchHypeTrainSnapshot(
      id: _readString(source['id'] ?? source['hypeTrainId']),
      channelId: _readString(
        source['channelId'] ??
            source['channelID'] ??
            source['channel_id'] ??
            source['broadcasterId'] ??
            source['broadcaster_id'] ??
            channel['id'],
      ),
      channelLogin: _readString(
        source['channelLogin'] ??
            source['channel_login'] ??
            source['channelName'] ??
            source['channel_name'] ??
            source['login'] ??
            channel['login'],
      ).toLowerCase(),
      channelDisplayName: _readString(
        source['channelDisplayName'] ??
            source['channel_display_name'] ??
            source['displayName'] ??
            source['display_name'] ??
            channel['displayName'] ??
            channel['display_name'] ??
            channel['login'],
      ),
      level: _readInt(
        progress['level']?['value'] ??
            source['level'] ??
            source['currentLevel'],
      ),
      total: _readInt(
        progress['total'] ??
            source['total'] ??
            source['totalProgress'] ??
            source['total_progress'] ??
            source['totalContribution'] ??
            source['total_contribution'],
      ),
      progress: _readInt(
        progress['progression'] ??
            source['progress'] ??
            source['currentProgress'] ??
            source['current_progress'],
      ),
      goal: _readInt(
        progress['goal'] ??
            source['goal'] ??
            source['levelGoal'] ??
            source['level_goal'] ??
            source['currentGoal'] ??
            source['current_goal'],
      ),
      startedAt: _readDate(
        source['startedAt'] ?? source['started_at'] ?? source['startTime'],
      ),
      expiresAt: _readDate(
        source['expiresAt'] ??
            source['expires_at'] ??
            source['expirationTime'] ??
            source['endsAt'] ??
            source['ends_at'],
      ),
      endedAt: _readDate(
        source['endedAt'] ?? source['ended_at'] ?? source['endTime'],
      ),
      cooldownEndsAt: _readDate(
        source['cooldownEndsAt'] ??
            source['cooldown_ends_at'] ??
            source['cooldownEndTime'],
      ),
      type: _readString(source['type'] ?? source['trainType']),
      isSharedTrain:
          _readBool(
            source['isSharedTrain'] ??
                source['is_shared_train'] ??
                source['sharedTrain'] ??
                source['shared_train'],
          ) ||
          participants.isNotEmpty,
      topContributions: _readList(
        source['topContributions'] ??
            source['top_contributions'] ??
            source['contributors'] ??
            source['contributions'],
      ).map(TwitchHypeTrainContribution.fromJson).toList(growable: false),
      sharedTrainParticipants: participants
          .map(TwitchHypeTrainParticipant.fromJson)
          .toList(growable: false),
    );
  }

  static Map<String, TwitchHypeTrainSnapshot?> mapFromJson(Object? raw) {
    final source = _readBulkSource(raw);
    final result = <String, TwitchHypeTrainSnapshot?>{};

    if (source is Map) {
      for (final entry in source.entries) {
        final login = entry.key.toString().trim().toLowerCase();
        result[login] = fromDynamic(entry.value, fallbackChannelLogin: login);
      }
      return result;
    }

    if (source is List) {
      for (final item in source) {
        final snapshot = fromDynamic(item);
        final login = snapshot?.channelLogin.trim().toLowerCase() ?? '';
        if (login.isNotEmpty) result[login] = snapshot;
      }
    }

    return result;
  }

  static TwitchHypeTrainSnapshot? fromDynamic(
    Object? raw, {
    String? fallbackChannelLogin,
  }) {
    if (raw == null) return null;
    final map = _readMap(raw);
    if (map.isEmpty) return null;
    final snapshot = TwitchHypeTrainSnapshot.fromJson(map);
    final login = snapshot.channelLogin.isNotEmpty
        ? snapshot.channelLogin
        : fallbackChannelLogin?.trim().toLowerCase() ?? '';
    if (login == snapshot.channelLogin) return snapshot;
    return snapshot.copyWith(channelLogin: login);
  }

  TwitchHypeTrainSnapshot copyWith({String? channelLogin, String? channelId}) {
    return TwitchHypeTrainSnapshot(
      id: id,
      channelId: channelId ?? this.channelId,
      channelLogin: channelLogin ?? this.channelLogin,
      channelDisplayName: channelDisplayName,
      level: level,
      total: total,
      progress: progress,
      goal: goal,
      startedAt: startedAt,
      expiresAt: expiresAt,
      endedAt: endedAt,
      cooldownEndsAt: cooldownEndsAt,
      type: type,
      isSharedTrain: isSharedTrain,
      topContributions: topContributions,
      sharedTrainParticipants: sharedTrainParticipants,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'channelId': channelId,
      'channelLogin': channelLogin,
      'channelDisplayName': channelDisplayName,
      'level': level,
      'total': total,
      'progress': progress,
      'goal': goal,
      'startedAt': startedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'cooldownEndsAt': cooldownEndsAt?.toIso8601String(),
      'type': type,
      'isSharedTrain': isSharedTrain,
      'topContributions': topContributions
          .map((item) => item.toJson())
          .toList(growable: false),
      'sharedTrainParticipants': sharedTrainParticipants
          .map((item) => item.toJson())
          .toList(growable: false),
    };
  }

  double get progressRatio {
    if (goal <= 0) return 0;
    return (progress / goal).clamp(0.0, 1.0);
  }

  Duration get remainingDuration {
    final expires = expiresAt;
    if (expires == null) return Duration.zero;
    final remaining = expires.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isActive {
    if (endedAt != null) return false;
    final expires = expiresAt;
    return expires != null && expires.isAfter(DateTime.now());
  }

  String get displayTypeLabel {
    if (isSharedTrain) return '共享列車';
    final normalized = type.trim().toLowerCase();
    if (normalized.contains('golden')) return '黃金列車';
    if (normalized.contains('treasure')) return '寶藏列車';
    if (normalized.contains('hype')) return '發燒列車';
    return '發燒列車';
  }
}

class TwitchHypeTrainContribution {
  final String userId;
  final String userLogin;
  final String displayName;
  final String profileImageUrl;
  final int amount;
  final String type;

  const TwitchHypeTrainContribution({
    required this.userId,
    required this.userLogin,
    required this.displayName,
    required this.profileImageUrl,
    required this.amount,
    required this.type,
  });

  factory TwitchHypeTrainContribution.fromJson(Map<String, dynamic> json) {
    final user = _readMap(
      json['user'] ?? json['viewer'] ?? json['contributor'],
    );
    return TwitchHypeTrainContribution(
      userId: _readString(
        json['userId'] ?? json['userID'] ?? json['user_id'] ?? user['id'],
      ),
      userLogin: _readString(
        json['userLogin'] ?? json['user_login'] ?? user['login'],
      ).toLowerCase(),
      displayName: _readString(
        json['displayName'] ??
            json['display_name'] ??
            user['displayName'] ??
            user['display_name'] ??
            user['login'],
      ),
      profileImageUrl: _readString(
        json['profileImageUrl'] ??
            json['profile_image_url'] ??
            user['profileImageURL'] ??
            user['profile_image_url'],
      ),
      amount: _readInt(json['amount'] ?? json['total'] ?? json['score']),
      type: _readString(
        json['type'] ?? json['contributionType'] ?? json['contribution_type'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'userLogin': userLogin,
      'displayName': displayName,
      'profileImageUrl': profileImageUrl,
      'amount': amount,
      'type': type,
    };
  }
}

class TwitchHypeTrainParticipant {
  final String channelId;
  final String channelLogin;
  final String displayName;
  final String profileImageUrl;
  final int level;
  final int progress;
  final int goal;

  const TwitchHypeTrainParticipant({
    required this.channelId,
    required this.channelLogin,
    required this.displayName,
    required this.profileImageUrl,
    required this.level,
    required this.progress,
    required this.goal,
  });

  factory TwitchHypeTrainParticipant.fromJson(Map<String, dynamic> json) {
    final channel = _readMap(json['channel'] ?? json['user']);
    return TwitchHypeTrainParticipant(
      channelId: _readString(
        json['channelId'] ??
            json['channelID'] ??
            json['channel_id'] ??
            channel['id'],
      ),
      channelLogin: _readString(
        json['channelLogin'] ??
            json['channel_login'] ??
            json['login'] ??
            channel['login'],
      ).toLowerCase(),
      displayName: _readString(
        json['displayName'] ??
            json['display_name'] ??
            channel['displayName'] ??
            channel['display_name'] ??
            channel['login'],
      ),
      profileImageUrl: _readString(
        json['profileImageUrl'] ??
            json['profile_image_url'] ??
            channel['profileImageURL'] ??
            channel['profile_image_url'],
      ),
      level: _readInt(json['level'] ?? json['currentLevel']),
      progress: _readInt(
        json['progress'] ?? json['currentProgress'] ?? json['current_progress'],
      ),
      goal: _readInt(json['goal'] ?? json['levelGoal'] ?? json['level_goal']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelId': channelId,
      'channelLogin': channelLogin,
      'displayName': displayName,
      'profileImageUrl': profileImageUrl,
      'level': level,
      'progress': progress,
      'goal': goal,
    };
  }
}

/// Extracts StreamNook's nested GetHypeTrainExecution progress payload.
Map<String, dynamic> _progressMap(Map<String, dynamic> source) {
  return _readMap(source['progress']);
}

Map<String, dynamic> _readSnapshotSource(Map<String, dynamic> json) {
  final direct = _firstMap(json, const <String>[
    'hypeTrain',
    'hype_train',
    'hypeTrainStatus',
    'hype_train_status',
    'status',
    'result',
  ]);
  if (direct != null) return direct;

  final data = _readMap(json['data']);
  final dataStatus = _firstMap(data, const <String>[
    'hypeTrain',
    'hype_train',
    'hypeTrainStatus',
    'hype_train_status',
    'status',
    'result',
  ]);
  if (dataStatus != null) return dataStatus;

  final user = _readMap(data['user']);
  final channel = _readMap(user['channel']);
  final hypeTrain = _readMap(channel['hypeTrain']);
  final execution = _readMap(hypeTrain['execution']);
  if (execution.isNotEmpty) {
    return _buildExecutionResult(execution, channel, user);
  }

  // 備援：hypeTrain 可能直接在 user 底下（不在 channel 裡）
  final directHypeTrain = _readMap(user['hypeTrain']);
  final directExecution = _readMap(directHypeTrain['execution']);
  if (directExecution.isNotEmpty) {
    return _buildExecutionResult(directExecution, channel, user);
  }
  return data.isNotEmpty && !_looksLikeGraphQlEnvelope(data) ? data : json;
}

Map<String, dynamic> _buildExecutionResult(
  Map<String, dynamic> execution,
  Map<String, dynamic> channel,
  Map<String, dynamic> user,
) {
  return <String, dynamic>{
    ...execution,
    'channelId': channel['id'] ?? user['id'],
    'channelLogin': user['login'],
    'channelDisplayName': user['displayName'],
  };
}

Object? _readBulkSource(Object? raw) {
  final map = _readMap(raw);
  if (map.isEmpty) return raw;
  final source =
      map['statuses'] ??
      map['hypeTrainStatuses'] ??
      map['hype_train_statuses'] ??
      map['hypeTrains'] ??
      map['hype_trains'] ??
      map['results'] ??
      map['data'];
  if (source == null || identical(source, raw)) return raw;

  final nested = _readMap(source);
  if (nested.isEmpty) return source;
  return nested['statuses'] ??
      nested['hypeTrainStatuses'] ??
      nested['hype_train_statuses'] ??
      nested['hypeTrains'] ??
      nested['hype_trains'] ??
      nested['results'] ??
      source;
}

Map<String, dynamic>? _firstMap(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final map = _readMap(json[key]);
    if (map.isNotEmpty) return map;
  }
  return null;
}

bool _looksLikeGraphQlEnvelope(Map<String, dynamic> value) {
  return value.containsKey('user') && value.length == 1;
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _readList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.map(_readMap).where((item) => item.isNotEmpty).toList();
}

String _readString(Object? value) => value?.toString().trim() ?? '';

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _readBool(Object? value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase();
  return text == 'true' || text == '1';
}

DateTime? _readDate(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}
