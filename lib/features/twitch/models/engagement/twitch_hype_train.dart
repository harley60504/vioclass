class TwitchHypeTrainSnapshot {
  final String id;
  final String channelId;
  final String channelLogin;
  final int level;
  final int total;
  final int progress;
  final int goal;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? endedAt;
  final String type;
  final bool isSharedTrain;
  final List<TwitchHypeTrainContribution> topContributions;
  final List<TwitchHypeTrainParticipant> sharedTrainParticipants;

  const TwitchHypeTrainSnapshot({
    required this.id,
    required this.channelId,
    required this.channelLogin,
    required this.level,
    required this.total,
    required this.progress,
    required this.goal,
    required this.startedAt,
    required this.expiresAt,
    required this.endedAt,
    required this.type,
    required this.isSharedTrain,
    required this.topContributions,
    required this.sharedTrainParticipants,
  });

  factory TwitchHypeTrainSnapshot.fromJson(Map<String, dynamic> json) {
    final source = _readSnapshotSource(json);
    final participants = _readList(
      source['sharedTrainParticipants'] ??
          source['participants'] ??
          source['sharedParticipants'],
    );

    return TwitchHypeTrainSnapshot(
      id: _readString(source['id']),
      channelId: _readString(source['channelId'] ?? source['channelID']),
      channelLogin: _readString(
        source['channelLogin'] ?? source['channelName'] ?? source['login'],
      ).toLowerCase(),
      level: _readInt(source['level'] ?? source['currentLevel']),
      total: _readInt(source['total'] ?? source['totalProgress']),
      progress: _readInt(source['progress'] ?? source['currentProgress']),
      goal: _readInt(source['goal'] ?? source['levelGoal']),
      startedAt: _readDate(source['startedAt'] ?? source['startTime']),
      expiresAt: _readDate(
        source['expiresAt'] ?? source['expirationTime'] ?? source['endsAt'],
      ),
      endedAt: _readDate(source['endedAt'] ?? source['endTime']),
      type: _readString(source['type'] ?? source['__typename']),
      isSharedTrain:
          _readBool(source['isSharedTrain'] ?? source['sharedTrain']) ||
          participants.isNotEmpty,
      topContributions: _readList(
        source['topContributions'] ?? source['contributors'],
      ).map(TwitchHypeTrainContribution.fromJson).toList(growable: false),
      sharedTrainParticipants: participants
          .map(TwitchHypeTrainParticipant.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'channelId': channelId,
      'channelLogin': channelLogin,
      'level': level,
      'total': total,
      'progress': progress,
      'goal': goal,
      'startedAt': startedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
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
    return expires == null || expires.isAfter(DateTime.now());
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
    final user = _readMap(json['user'] ?? json['viewer']);
    return TwitchHypeTrainContribution(
      userId: _readString(json['userId'] ?? json['userID'] ?? user['id']),
      userLogin: _readString(json['userLogin'] ?? user['login']).toLowerCase(),
      displayName: _readString(
        json['displayName'] ?? user['displayName'] ?? user['login'],
      ),
      profileImageUrl: _readString(
        json['profileImageUrl'] ?? user['profileImageURL'],
      ),
      amount: _readInt(json['amount'] ?? json['total'] ?? json['score']),
      type: _readString(json['type'] ?? json['contributionType']),
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
        json['channelId'] ?? json['channelID'] ?? channel['id'],
      ),
      channelLogin: _readString(
        json['channelLogin'] ?? json['login'] ?? channel['login'],
      ).toLowerCase(),
      displayName: _readString(
        json['displayName'] ?? channel['displayName'] ?? channel['login'],
      ),
      profileImageUrl: _readString(
        json['profileImageUrl'] ?? channel['profileImageURL'],
      ),
      level: _readInt(json['level'] ?? json['currentLevel']),
      progress: _readInt(json['progress'] ?? json['currentProgress']),
      goal: _readInt(json['goal'] ?? json['levelGoal']),
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

Map<String, dynamic> _readSnapshotSource(Map<String, dynamic> json) {
  final data = _readMap(json['data']);
  final user = _readMap(data['user']);
  final channel = _readMap(user['channel']);
  final hypeTrain = _readMap(channel['hypeTrain']);
  final execution = _readMap(hypeTrain['execution']);
  if (execution.isNotEmpty) {
    return <String, dynamic>{
      ...execution,
      'channelId': channel['id'] ?? user['id'],
      'channelLogin': user['login'],
    };
  }
  return json;
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
