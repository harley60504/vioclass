class TwitchPredictionSnapshot {
  final String id;
  final String title;
  final String status;
  final int totalPoints;
  final int totalUsers;
  final DateTime? createdAt;
  final DateTime? locksAt;
  final DateTime? endedAt;
  final String? winningOutcomeId;
  final String? viewerOutcomeId;
  final List<TwitchPredictionOutcome> outcomes;
  final Map<String, dynamic>? rawPrediction;

  const TwitchPredictionSnapshot({
    required this.id,
    required this.title,
    required this.status,
    required this.totalPoints,
    required this.totalUsers,
    required this.outcomes,
    this.createdAt,
    this.locksAt,
    this.endedAt,
    this.winningOutcomeId,
    this.viewerOutcomeId,
    this.rawPrediction,
  });

  bool get hasPrediction => id.isNotEmpty || title.isNotEmpty || outcomes.isNotEmpty;

  String get normalizedStatus => status.trim().toUpperCase();

  bool get isResolvedLike {
    final s = normalizedStatus;
    return s.contains('RESOLVED') ||
        s.contains('CANCELED') ||
        s.contains('CANCELLED') ||
        s.contains('REFUNDED') ||
        s.contains('ENDED');
  }

  bool get isCanceledLike {
    final s = normalizedStatus;
    return s.contains('CANCELED') ||
        s.contains('CANCELLED') ||
        s.contains('REFUNDED');
  }

  bool get isLockedLike {
    final s = normalizedStatus;
    return s.contains('LOCKED') || s.contains('RESOLVE_PENDING');
  }

  TwitchPredictionOutcome? get winningOutcome {
    final winnerId = winningOutcomeId?.trim();
    if (winnerId != null && winnerId.isNotEmpty) {
      for (final outcome in outcomes) {
        if (outcome.id == winnerId) return outcome;
      }
    }

    for (final outcome in outcomes) {
      if (outcome.isWinner) return outcome;
    }

    return null;
  }

  factory TwitchPredictionSnapshot.empty() {
    return const TwitchPredictionSnapshot(
      id: '',
      title: '',
      status: '',
      totalPoints: 0,
      totalUsers: 0,
      outcomes: <TwitchPredictionOutcome>[],
    );
  }

  factory TwitchPredictionSnapshot.fromRawResponse(Object? response) {
    final root = response is Map<String, dynamic> ? response : <String, dynamic>{};
    final maps = _collectMaps(root);

    final predictionMap = maps.firstWhere(
      (map) {
        final hasOutcomes = map['outcomes'] is List ||
            map['choices'] is List ||
            map['predictionOptions'] is List;
        final hasPredictionWords = map.containsKey('activePredictionEvent') ||
            map.containsKey('prediction') ||
            map.containsKey('event') ||
            map.containsKey('status') ||
            map.containsKey('title');
        return hasOutcomes && hasPredictionWords;
      },
      orElse: () => const <String, dynamic>{},
    );

    if (predictionMap.isEmpty) {
      return TwitchPredictionSnapshot.empty();
    }

    final rawOutcomes = predictionMap['outcomes'] ??
        predictionMap['choices'] ??
        predictionMap['predictionOptions'];

    final winningOutcomeId = _readWinningOutcomeId(predictionMap);
    final viewerOutcomeId = _readViewerOutcomeId(predictionMap);

    final outcomes = rawOutcomes is List
        ? rawOutcomes
            .whereType<Map<String, dynamic>>()
            .map(
              (json) => TwitchPredictionOutcome.fromFlexibleJson(
                json,
                winningOutcomeId: winningOutcomeId,
                viewerOutcomeId: viewerOutcomeId,
              ),
            )
            .where((outcome) => outcome.id.isNotEmpty || outcome.title.isNotEmpty)
            .toList(growable: false)
        : const <TwitchPredictionOutcome>[];

    return TwitchPredictionSnapshot(
      id: _readString(
            predictionMap['id'] ??
                predictionMap['eventID'] ??
                predictionMap['eventId'] ??
                predictionMap['predictionID'] ??
                predictionMap['predictionId'] ??
                predictionMap['prediction_id'],
          ) ??
          '',
      title: _readString(predictionMap['title'] ?? predictionMap['question']) ?? '',
      status: _readString(predictionMap['status'] ?? predictionMap['state']) ?? '',
      totalPoints: _readInt(
            predictionMap['totalPoints'] ??
                predictionMap['total_points'] ??
                predictionMap['totalChannelPoints'] ??
                predictionMap['points'],
          ) ??
          outcomes.fold<int>(0, (sum, item) => sum + item.points),
      totalUsers: _readInt(
            predictionMap['totalUsers'] ??
                predictionMap['total_users'] ??
                predictionMap['totalParticipants'] ??
                predictionMap['users'],
          ) ??
          outcomes.fold<int>(0, (sum, item) => sum + item.users),
      createdAt: _readDate(predictionMap['createdAt'] ?? predictionMap['created_at']),
      locksAt: _readDate(
        predictionMap['locksAt'] ??
            predictionMap['locks_at'] ??
            predictionMap['lockedAt'] ??
            predictionMap['locked_at'],
      ),
      endedAt: _readDate(predictionMap['endedAt'] ?? predictionMap['ended_at']),
      winningOutcomeId: winningOutcomeId,
      viewerOutcomeId: viewerOutcomeId,
      outcomes: outcomes,
      rawPrediction: predictionMap,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'hasPrediction': hasPrediction,
      'id': id,
      'title': title,
      'status': status,
      'totalPoints': totalPoints,
      'totalUsers': totalUsers,
      'createdAt': createdAt?.toIso8601String(),
      'locksAt': locksAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'winningOutcomeId': winningOutcomeId,
      'viewerOutcomeId': viewerOutcomeId,
      'outcomeCount': outcomes.length,
      'outcomes': outcomes.map((outcome) => outcome.toJson()).toList(),
      'rawPredictionKeys': rawPrediction?.keys.toList(),
    };
  }
}

class TwitchPredictionOutcome {
  final String id;
  final String title;
  final String color;
  final int points;
  final int users;
  final bool isWinner;
  final bool isViewerChoice;
  final int viewerPoints;
  final double? odds;

  const TwitchPredictionOutcome({
    required this.id,
    required this.title,
    required this.color,
    required this.points,
    required this.users,
    required this.isWinner,
    this.isViewerChoice = false,
    this.viewerPoints = 0,
    this.odds,
  });

  factory TwitchPredictionOutcome.fromFlexibleJson(
    Map<String, dynamic> json, {
    String? winningOutcomeId,
    String? viewerOutcomeId,
  }) {
    final id = _readString(json['id'] ?? json['outcomeID'] ?? json['outcomeId']) ?? '';
    final points = _readInt(
          json['points'] ??
              json['totalPoints'] ??
              json['total_points'] ??
              json['channelPoints'] ??
              json['channel_points'] ??
              json['amount'],
        ) ??
        0;

    final users = _readInt(
          json['users'] ??
              json['totalUsers'] ??
              json['total_users'] ??
              json['participants'] ??
              json['predictors'],
        ) ??
        0;

    final viewerPoints = _readInt(
          json['viewerPoints'] ??
              json['viewer_points'] ??
              json['myPoints'] ??
              json['my_points'] ??
              json['selfPoints'] ??
              json['self_points'],
        ) ??
        0;

    final viewerId = viewerOutcomeId?.trim();
    final isViewerChoice = (_readBool(
              json['isViewerChoice'] ??
                  json['viewerChoice'] ??
                  json['isMyChoice'] ??
                  json['isSelfChoice'],
            ) ??
            false) ||
        (viewerId != null && viewerId.isNotEmpty && viewerId == id) ||
        viewerPoints > 0;

    final winnerId = winningOutcomeId?.trim();
    final isWinner = (_readBool(json['winner'] ?? json['isWinner']) ?? false) ||
        (winnerId != null && winnerId.isNotEmpty && winnerId == id);

    return TwitchPredictionOutcome(
      id: id,
      title: _readString(json['title'] ?? json['name']) ?? '',
      color: _readString(json['color']) ?? '',
      points: points,
      users: users,
      isWinner: isWinner,
      isViewerChoice: isViewerChoice,
      viewerPoints: viewerPoints,
      odds: _readDouble(json['odds']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'color': color,
      'points': points,
      'users': users,
      'isWinner': isWinner,
      'isViewerChoice': isViewerChoice,
      'viewerPoints': viewerPoints,
      'odds': odds,
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
    } else if (item is Map) {
      final map = item.map((key, value) => MapEntry(key.toString(), value));
      output.add(map);
      for (final value in map.values) {
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

String? _readWinningOutcomeId(Map<String, dynamic> predictionMap) {
  final direct = _readString(
    predictionMap['winningOutcomeId'] ??
        predictionMap['winningOutcomeID'] ??
        predictionMap['winning_outcome_id'],
  );
  if (direct != null) return direct;

  final winning = predictionMap['winningOutcome'] ?? predictionMap['winning_outcome'];
  if (winning is Map) {
    return _readString(winning['id'] ?? winning['outcomeID'] ?? winning['outcomeId']);
  }

  return null;
}

String? _readViewerOutcomeId(Map<String, dynamic> predictionMap) {
  for (final key in const <String>[
    'viewerOutcomeId',
    'viewerOutcomeID',
    'viewer_outcome_id',
    'selectedOutcomeId',
    'selectedOutcomeID',
    'selected_outcome_id',
    'myOutcomeId',
    'my_outcome_id',
    'selfOutcomeId',
    'self_outcome_id',
  ]) {
    final value = _readString(predictionMap[key]);
    if (value != null) return value;
  }

  for (final key in const <String>[
    'viewerPrediction',
    'viewer_prediction',
    'myPrediction',
    'my_prediction',
    'selfPrediction',
    'self_prediction',
    'prediction',
  ]) {
    final value = predictionMap[key];
    if (value is Map) {
      final id = _readString(
        value['outcomeID'] ??
            value['outcomeId'] ??
            value['outcome_id'] ??
            value['id'],
      );
      if (id != null) return id;
    }
  }

  return null;
}

String? _readString(Object? value) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) return null;
  return text.trim();
}

int? _readInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}

double? _readDouble(Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}

bool? _readBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  final text = value.toString().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return null;
}

DateTime? _readDate(Object? value) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) return null;
  return DateTime.tryParse(text);
}
