class TwitchHypeTrainSnapshot {
  final String channelId;
  final String channelLogin;
  final String channelDisplayName;
  final TwitchHypeTrainExecution? execution;
  final TwitchHypeTrainApproaching? approaching;
  final Map<String, dynamic> raw;

  const TwitchHypeTrainSnapshot({
    required this.channelId,
    required this.channelLogin,
    required this.channelDisplayName,
    required this.raw,
    this.execution,
    this.approaching,
  });

  bool get hasActiveExecution => execution != null;
  bool get isApproaching => approaching != null;

  factory TwitchHypeTrainSnapshot.fromGqlResponse(Map<String, dynamic> response) {
    final data = _asMap(response['data']);
    final user = _asMap(data['user']);
    final channel = _asMap(user['channel']);
    final hypeTrain = _asMap(channel['hypeTrain']);

    final executionMap = _asNullableMap(hypeTrain['execution']);
    final approachingMap = _asNullableMap(hypeTrain['approaching']);

    return TwitchHypeTrainSnapshot(
      channelId: channel['id']?.toString() ?? user['id']?.toString() ?? '',
      channelLogin: user['login']?.toString() ?? '',
      channelDisplayName: user['displayName']?.toString() ?? '',
      execution: executionMap == null
          ? null
          : TwitchHypeTrainExecution.fromJson(executionMap),
      approaching: approachingMap == null
          ? null
          : TwitchHypeTrainApproaching.fromJson(approachingMap),
      raw: response,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelId': channelId,
      'channelLogin': channelLogin,
      'channelDisplayName': channelDisplayName,
      'hasActiveExecution': hasActiveExecution,
      'isApproaching': isApproaching,
      'execution': execution?.toJson(),
      'approaching': approaching?.toJson(),
    };
  }
}

class TwitchHypeTrainExecution {
  final String id;
  final String status;
  final int level;
  final int progress;
  final int goal;
  final int total;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> raw;

  const TwitchHypeTrainExecution({
    required this.id,
    required this.status,
    required this.level,
    required this.progress,
    required this.goal,
    required this.total,
    required this.raw,
    this.startedAt,
    this.expiresAt,
    this.updatedAt,
  });

  double get progressRatio {
    if (goal <= 0) return 0;
    return (progress / goal).clamp(0.0, 1.0);
  }

  factory TwitchHypeTrainExecution.fromJson(Map<String, dynamic> json) {
    return TwitchHypeTrainExecution(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ??
          json['state']?.toString() ??
          json['__typename']?.toString() ??
          '',
      level: _readInt(
        json['level'] ??
            json['currentLevel'] ??
            _asNullableMap(json['currentLevel'])?['value'],
      ),
      progress: _readInt(
        json['progress'] ??
            json['currentProgress'] ??
            json['amount'] ??
            json['score'],
      ),
      goal: _readInt(
        json['goal'] ??
            json['target'] ??
            json['currentGoal'] ??
            json['levelGoal'],
      ),
      total: _readInt(
        json['total'] ??
            json['totalProgress'] ??
            json['totalContribution'] ??
            json['totalAmount'],
      ),
      startedAt: _readDate(json['startedAt'] ?? json['startTime']),
      expiresAt: _readDate(json['expiresAt'] ?? json['expirationTime'] ?? json['endsAt']),
      updatedAt: _readDate(json['updatedAt']),
      raw: json,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'status': status,
      'level': level,
      'progress': progress,
      'goal': goal,
      'total': total,
      'progressRatio': progressRatio,
      'startedAt': startedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'rawKeys': raw.keys.toList(),
    };
  }
}

class TwitchHypeTrainApproaching {
  final String id;
  final int progress;
  final int goal;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final Map<String, dynamic> raw;

  const TwitchHypeTrainApproaching({
    required this.id,
    required this.progress,
    required this.goal,
    required this.raw,
    this.startedAt,
    this.expiresAt,
  });

  double get progressRatio {
    if (goal <= 0) return 0;
    return (progress / goal).clamp(0.0, 1.0);
  }

  factory TwitchHypeTrainApproaching.fromJson(Map<String, dynamic> json) {
    return TwitchHypeTrainApproaching(
      id: json['id']?.toString() ?? '',
      progress: _readInt(json['progress'] ?? json['currentProgress'] ?? json['amount']),
      goal: _readInt(json['goal'] ?? json['target'] ?? json['levelGoal']),
      startedAt: _readDate(json['startedAt'] ?? json['startTime']),
      expiresAt: _readDate(json['expiresAt'] ?? json['expirationTime'] ?? json['endsAt']),
      raw: json,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'progress': progress,
      'goal': goal,
      'progressRatio': progressRatio,
      'startedAt': startedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'rawKeys': raw.keys.toList(),
    };
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  return <String, dynamic>{};
}

Map<String, dynamic>? _asNullableMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  return null;
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _readDate(Object? value) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) return null;
  return DateTime.tryParse(text);
}
