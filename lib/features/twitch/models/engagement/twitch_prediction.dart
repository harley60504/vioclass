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

  bool get hasPrediction =>
      id.isNotEmpty || title.isNotEmpty || outcomes.isNotEmpty;

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

  TwitchPredictionOutcome? get viewerOutcome {
    final viewerId = viewerOutcomeId?.trim();
    if (viewerId != null && viewerId.isNotEmpty) {
      for (final outcome in outcomes) {
        if (_matchesOutcomeIdentity(outcome, viewerId)) return outcome;
      }
    }

    for (final outcome in outcomes) {
      if (outcome.isViewerChoice || outcome.viewerPoints > 0) return outcome;
    }

    return null;
  }

  TwitchPredictionSnapshot copyWith({
    String? id,
    String? title,
    String? status,
    int? totalPoints,
    int? totalUsers,
    DateTime? createdAt,
    DateTime? locksAt,
    DateTime? endedAt,
    String? winningOutcomeId,
    String? viewerOutcomeId,
    List<TwitchPredictionOutcome>? outcomes,
    Map<String, dynamic>? rawPrediction,
  }) {
    return TwitchPredictionSnapshot(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      totalPoints: totalPoints ?? this.totalPoints,
      totalUsers: totalUsers ?? this.totalUsers,
      createdAt: createdAt ?? this.createdAt,
      locksAt: locksAt ?? this.locksAt,
      endedAt: endedAt ?? this.endedAt,
      winningOutcomeId: winningOutcomeId ?? this.winningOutcomeId,
      viewerOutcomeId: viewerOutcomeId ?? this.viewerOutcomeId,
      outcomes: outcomes ?? this.outcomes,
      rawPrediction: rawPrediction ?? this.rawPrediction,
    );
  }

  TwitchPredictionSnapshot withViewerPrediction({
    required String outcomeId,
    required int points,
    bool addToExisting = true,
  }) {
    final safeOutcomeId = outcomeId.trim();
    if (safeOutcomeId.isEmpty) return this;

    final updatedOutcomes = outcomes
        .map((outcome) {
          final isTarget = _matchesOutcomeIdentity(outcome, safeOutcomeId);
          final nextViewerPoints = isTarget
              ? (addToExisting ? outcome.viewerPoints + points : points)
              : 0;

          return outcome.copyWith(
            isViewerChoice: isTarget,
            viewerPoints: nextViewerPoints,
          );
        })
        .toList(growable: false);

    return copyWith(viewerOutcomeId: safeOutcomeId, outcomes: updatedOutcomes);
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

  factory TwitchPredictionSnapshot.fromHermesPayload(
    Object? payload, {
    String? viewerUserId,
    TwitchPredictionSnapshot? previous,
  }) {
    final root = payload is Map
        ? payload.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final type = root['type']?.toString();
    final data = root['data'];

    if (type == 'event-updated' && data is Map) {
      final event = data['event'];
      if (event is Map) {
        final parsed = TwitchPredictionSnapshot.fromRawResponse(
          event,
        )._withViewerFromHermesEvent(event, viewerUserId: viewerUserId);
        return parsed._preserveViewerPredictionFrom(previous);
      }
    }

    if (type == 'prediction-made' && data is Map) {
      final prediction = data['prediction'];
      if (prediction is Map) {
        final eventId =
            _readString(
              prediction['event_id'] ??
                  prediction['eventID'] ??
                  prediction['eventId'],
            ) ??
            previous?.id ??
            '';
        final outcomeId =
            _readString(
              prediction['outcome_id'] ??
                  prediction['outcomeID'] ??
                  prediction['outcomeId'],
            ) ??
            '';
        final points = _readInt(prediction['points']) ?? 0;
        final userId = _readString(
          prediction['user_id'] ?? prediction['userId'],
        );
        final viewerId = viewerUserId?.trim();
        final isViewer =
            viewerId == null ||
            viewerId.isEmpty ||
            userId == null ||
            userId.isEmpty ||
            userId == viewerId;

        final base =
            previous ??
            TwitchPredictionSnapshot(
              id: eventId,
              title: '',
              status: 'ACTIVE',
              totalPoints: 0,
              totalUsers: 0,
              outcomes: const <TwitchPredictionOutcome>[],
              rawPrediction: prediction.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            );

        if (!isViewer || outcomeId.isEmpty) return base;
        return base.withViewerPrediction(outcomeId: outcomeId, points: points);
      }
    }

    return TwitchPredictionSnapshot.fromRawResponse(
      root,
    )._preserveViewerPredictionFrom(previous);
  }

  factory TwitchPredictionSnapshot.fromRawResponse(Object? response) {
    final root = response is Map<String, dynamic>
        ? response
        : response is Map
        ? response.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final maps = _collectMaps(root);

    final predictionMap = _findPredictionMap(maps);

    if (predictionMap.isEmpty) {
      return TwitchPredictionSnapshot.empty();
    }

    final predictionId = _readPredictionId(predictionMap);
    final rawOutcomes =
        predictionMap['outcomes'] ??
        predictionMap['choices'] ??
        predictionMap['predictionOptions'] ??
        predictionMap['prediction_options'];

    final viewerPrediction = _readViewerPredictionRecord(
      predictionMap,
      maps,
      eventId: predictionId,
    );
    final winningOutcomeId = _readWinningOutcomeId(predictionMap);
    final viewerOutcomeId =
        _readViewerOutcomeId(predictionMap) ?? viewerPrediction?.outcomeId;

    final outcomes = rawOutcomes is List
        ? rawOutcomes
              .whereType<Map>()
              .map(
                (json) =>
                    json.map((key, value) => MapEntry(key.toString(), value)),
              )
              .map((json) {
                final outcomeId = _readOutcomeId(json);
                final title = _readString(json['title'] ?? json['name']) ?? '';
                final isViewerOutcome =
                    viewerOutcomeId != null &&
                    viewerOutcomeId.trim().isNotEmpty &&
                    _matchesIdentity(
                      id: outcomeId,
                      title: title,
                      identity: viewerOutcomeId,
                    );

                return TwitchPredictionOutcome.fromFlexibleJson(
                  json,
                  winningOutcomeId: winningOutcomeId,
                  viewerOutcomeId: viewerOutcomeId,
                  viewerPointsOverride: isViewerOutcome
                      ? viewerPrediction?.points
                      : null,
                );
              })
              .where(
                (outcome) => outcome.id.isNotEmpty || outcome.title.isNotEmpty,
              )
              .toList(growable: false)
        : const <TwitchPredictionOutcome>[];

    return TwitchPredictionSnapshot(
      id: predictionId ?? '',
      title:
          _readString(predictionMap['title'] ?? predictionMap['question']) ??
          '',
      status:
          _readString(predictionMap['status'] ?? predictionMap['state']) ?? '',
      totalPoints:
          _readInt(
            predictionMap['totalPoints'] ??
                predictionMap['total_points'] ??
                predictionMap['totalChannelPoints'] ??
                predictionMap['total_channel_points'] ??
                predictionMap['points'],
          ) ??
          outcomes.fold<int>(0, (sum, item) => sum + item.points),
      totalUsers:
          _readInt(
            predictionMap['totalUsers'] ??
                predictionMap['total_users'] ??
                predictionMap['totalParticipants'] ??
                predictionMap['total_participants'] ??
                predictionMap['users'],
          ) ??
          outcomes.fold<int>(0, (sum, item) => sum + item.users),
      createdAt: _readDate(
        predictionMap['createdAt'] ?? predictionMap['created_at'],
      ),
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

  TwitchPredictionSnapshot _withViewerFromHermesEvent(
    Map event, {
    String? viewerUserId,
  }) {
    final viewerId = viewerUserId?.trim();
    if (viewerId == null || viewerId.isEmpty) return this;

    String? viewerOutcome;
    int viewerPoints = 0;

    final rawOutcomes = event['outcomes'];
    if (rawOutcomes is List) {
      for (final rawOutcome in rawOutcomes) {
        if (rawOutcome is! Map) continue;
        final outcomeId = _readString(
          rawOutcome['id'] ?? rawOutcome['outcome_id'],
        );
        final topPredictors =
            rawOutcome['top_predictors'] ?? rawOutcome['topPredictors'];
        if (topPredictors is! List) continue;

        for (final predictor in topPredictors) {
          if (predictor is! Map) continue;
          final userId = _readString(
            predictor['user_id'] ?? predictor['userId'],
          );
          if (userId != viewerId) continue;
          viewerOutcome = outcomeId;
          viewerPoints = _readInt(predictor['points']) ?? viewerPoints;
          break;
        }
      }
    }

    if (viewerOutcome == null || viewerOutcome.isEmpty) return this;
    return withViewerPrediction(
      outcomeId: viewerOutcome,
      points: viewerPoints,
      addToExisting: false,
    );
  }

  TwitchPredictionSnapshot _preserveViewerPredictionFrom(
    TwitchPredictionSnapshot? previous,
  ) {
    if (previous == null || !previous.hasPrediction) return this;
    if (!_samePredictionFamily(this, previous)) return this;

    final currentViewer = viewerOutcome;
    if (currentViewer != null && currentViewer.viewerPoints > 0) return this;

    final previousViewer = previous.viewerOutcome;
    final previousViewerId = previous.viewerOutcomeId?.trim();
    final outcomeId = previousViewerId != null && previousViewerId.isNotEmpty
        ? previousViewerId
        : previousViewer == null
        ? ''
        : previousViewer.id.isNotEmpty
        ? previousViewer.id
        : previousViewer.title;

    if (outcomeId.isEmpty) return this;

    return withViewerPrediction(
      outcomeId: outcomeId,
      points: previousViewer?.viewerPoints ?? 0,
      addToExisting: false,
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
      'viewerOutcome': viewerOutcome?.toJson(),
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

  TwitchPredictionOutcome copyWith({
    String? id,
    String? title,
    String? color,
    int? points,
    int? users,
    bool? isWinner,
    bool? isViewerChoice,
    int? viewerPoints,
    double? odds,
  }) {
    return TwitchPredictionOutcome(
      id: id ?? this.id,
      title: title ?? this.title,
      color: color ?? this.color,
      points: points ?? this.points,
      users: users ?? this.users,
      isWinner: isWinner ?? this.isWinner,
      isViewerChoice: isViewerChoice ?? this.isViewerChoice,
      viewerPoints: viewerPoints ?? this.viewerPoints,
      odds: odds ?? this.odds,
    );
  }

  factory TwitchPredictionOutcome.fromFlexibleJson(
    Map<String, dynamic> json, {
    String? winningOutcomeId,
    String? viewerOutcomeId,
    int? viewerPointsOverride,
  }) {
    final id = _readOutcomeId(json);
    final title = _readString(json['title'] ?? json['name']) ?? '';
    final points =
        _readInt(
          json['points'] ??
              json['totalPoints'] ??
              json['total_points'] ??
              json['channelPoints'] ??
              json['channel_points'] ??
              json['amount'],
        ) ??
        0;

    final users =
        _readInt(
          json['users'] ??
              json['totalUsers'] ??
              json['total_users'] ??
              json['participants'] ??
              json['predictors'],
        ) ??
        0;

    final viewerPoints =
        viewerPointsOverride ?? _readViewerPointsFromOutcome(json) ?? 0;

    final viewerId = viewerOutcomeId?.trim();
    final isViewerChoice =
        (_readBool(
              json['isViewerChoice'] ??
                  json['viewerChoice'] ??
                  json['isMyChoice'] ??
                  json['isSelfChoice'],
            ) ??
            false) ||
        (viewerId != null &&
            viewerId.isNotEmpty &&
            _matchesIdentity(id: id, title: title, identity: viewerId)) ||
        viewerPoints > 0;

    final winnerId = winningOutcomeId?.trim();
    final isWinner =
        (_readBool(json['winner'] ?? json['isWinner']) ?? false) ||
        (winnerId != null &&
            winnerId.isNotEmpty &&
            _matchesIdentity(id: id, title: title, identity: winnerId));

    return TwitchPredictionOutcome(
      id: id,
      title: title,
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

class _ViewerPredictionRecord {
  final String outcomeId;
  final int points;

  const _ViewerPredictionRecord({
    required this.outcomeId,
    required this.points,
  });
}

Map<String, dynamic> _findPredictionMap(List<Map<String, dynamic>> maps) {
  Map<String, dynamic> best = const <String, dynamic>{};
  var bestScore = -1;

  for (final map in maps) {
    final hasOutcomes =
        map['outcomes'] is List ||
        map['choices'] is List ||
        map['predictionOptions'] is List ||
        map['prediction_options'] is List;
    if (!hasOutcomes) continue;

    var score = 0;
    if (map.containsKey('activePredictionEvent')) score += 3;
    if (map.containsKey('prediction')) score += 1;
    if (map.containsKey('event')) score += 1;
    if (map.containsKey('status') || map.containsKey('state')) score += 3;
    if (map.containsKey('title') || map.containsKey('question')) score += 3;
    final predictionId = _readPredictionId(map);
    if (_readViewerPredictionRecord(map, maps, eventId: predictionId) != null) {
      score += 4;
    }
    if (predictionId != null) score += 2;

    if (score > bestScore) {
      best = map;
      bestScore = score;
    }
  }

  return best;
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

String? _readPredictionId(Map<String, dynamic> predictionMap) {
  return _readString(
    predictionMap['id'] ??
        predictionMap['eventID'] ??
        predictionMap['eventId'] ??
        predictionMap['event_id'] ??
        predictionMap['predictionID'] ??
        predictionMap['predictionId'] ??
        predictionMap['prediction_id'],
  );
}

String? _readPredictionIdFromObject(Object? value) {
  if (value is! Map) return null;
  final map = value.map((key, value) => MapEntry(key.toString(), value));
  return _readPredictionId(map);
}

String? _readWinningOutcomeId(Map<String, dynamic> predictionMap) {
  final direct = _readString(
    predictionMap['winningOutcomeId'] ??
        predictionMap['winningOutcomeID'] ??
        predictionMap['winning_outcome_id'],
  );
  if (direct != null) return direct;

  final winning =
      predictionMap['winningOutcome'] ?? predictionMap['winning_outcome'];
  if (winning is Map) {
    return _readOutcomeIdFromObject(winning);
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
    'currentUserOutcomeId',
    'current_user_outcome_id',
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
    'currentUserPrediction',
    'current_user_prediction',
    'userPrediction',
    'user_prediction',
    'viewerPredictionEvent',
    'viewer_prediction_event',
  ]) {
    final record = _readViewerPredictionRecordFromObject(predictionMap[key]);
    if (record != null) return record.outcomeId;
  }

  return null;
}

_ViewerPredictionRecord? _readViewerPredictionRecord(
  Map<String, dynamic> predictionMap,
  List<Map<String, dynamic>> maps, {
  String? eventId,
}) {
  final directOutcome = _readViewerOutcomeIdWithoutNested(predictionMap);
  if (directOutcome != null) {
    return _ViewerPredictionRecord(
      outcomeId: directOutcome,
      points: _readDirectViewerPoints(predictionMap) ?? 0,
    );
  }

  for (final map in <Map<String, dynamic>>[predictionMap, ...maps]) {
    for (final key in const <String>[
      'viewerPrediction',
      'viewer_prediction',
      'myPrediction',
      'my_prediction',
      'selfPrediction',
      'self_prediction',
      'currentUserPrediction',
      'current_user_prediction',
      'userPrediction',
      'user_prediction',
      'viewerPredictionEvent',
      'viewer_prediction_event',
    ]) {
      final record = _readViewerPredictionRecordFromObject(
        map[key],
        eventId: eventId,
      );
      if (record != null) return record;
    }

    for (final key in const <String>[
      'recentPredictions',
      'recent_predictions',
      'viewerPredictions',
      'viewer_predictions',
      'myPredictions',
      'my_predictions',
      'selfPredictions',
      'self_predictions',
      'currentUserPredictions',
      'current_user_predictions',
    ]) {
      final value = map[key];
      if (value is List) {
        for (final item in value) {
          final record = _readViewerPredictionRecordFromObject(
            item,
            eventId: eventId,
          );
          if (record != null) return record;
        }
      }
    }
  }

  return null;
}

String? _readViewerOutcomeIdWithoutNested(Map<String, dynamic> predictionMap) {
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
    'currentUserOutcomeId',
    'current_user_outcome_id',
  ]) {
    final value = _readString(predictionMap[key]);
    if (value != null) return value;
  }
  return null;
}

_ViewerPredictionRecord? _readViewerPredictionRecordFromObject(
  Object? value, {
  String? eventId,
}) {
  if (value is List) {
    for (final item in value) {
      final record = _readViewerPredictionRecordFromObject(
        item,
        eventId: eventId,
      );
      if (record != null) return record;
    }
    return null;
  }

  if (value is! Map) return null;

  final map = value.map((key, value) => MapEntry(key.toString(), value));
  final expectedEventId = eventId?.trim();
  if (expectedEventId != null && expectedEventId.isNotEmpty) {
    final recordEventId =
        _readString(
          map['eventID'] ??
              map['eventId'] ??
              map['event_id'] ??
              map['predictionEventID'] ??
              map['predictionEventId'] ??
              map['prediction_event_id'],
        ) ??
        _readPredictionIdFromObject(map['event']) ??
        _readPredictionIdFromObject(map['predictionEvent']) ??
        _readPredictionIdFromObject(map['prediction_event']);

    if (recordEventId != null &&
        recordEventId.trim().isNotEmpty &&
        recordEventId.trim() != expectedEventId) {
      return null;
    }
  }

  // A viewer prediction record has its own prediction id in `id`, while the
  // actual selected outcome is nested under `outcome.id`. Do not treat the
  // record id as an outcome id, otherwise viewerOutcomeId becomes the user's
  // Prediction id and cannot match either outcome card.
  final outcomeId =
      _readOutcomeIdFromObject(map['outcome']) ??
      _readOutcomeIdFromObject(map['choice']) ??
      _readOutcomeIdFromObject(map['selectedOutcome']) ??
      _readOutcomeIdFromObject(map['selected_outcome']) ??
      _readOutcomeIdFromObject(map['predictionOption']) ??
      _readOutcomeIdFromObject(map['prediction_option']) ??
      _readDirectOutcomeIdFromRecordMap(map);

  if (outcomeId == null || outcomeId.isEmpty) {
    for (final key in const <String>[
      'prediction',
      'predictionEvent',
      'prediction_event',
      'event',
    ]) {
      final nested = _readViewerPredictionRecordFromObject(
        map[key],
        eventId: eventId,
      );
      if (nested != null) return nested;
    }
    return null;
  }

  return _ViewerPredictionRecord(
    outcomeId: outcomeId,
    points: _readViewerPointsFromPredictionRecord(map) ?? 0,
  );
}

String? _readDirectOutcomeIdFromRecordMap(Map<String, dynamic> map) {
  return _readString(
    map['outcomeID'] ??
        map['outcomeId'] ??
        map['outcome_id'] ??
        map['selectedOutcomeId'] ??
        map['selectedOutcomeID'] ??
        map['selected_outcome_id'] ??
        map['choiceID'] ??
        map['choiceId'] ??
        map['choice_id'] ??
        map['optionID'] ??
        map['optionId'] ??
        map['option_id'] ??
        map['predictionOptionID'] ??
        map['predictionOptionId'] ??
        map['prediction_option_id'],
  );
}

String? _readOutcomeIdFromObject(Object? value) {
  if (value is! Map) return null;
  final map = value.map((key, value) => MapEntry(key.toString(), value));
  final direct = _readDirectOutcomeIdFromRecordMap(map);
  if (direct != null) return direct;
  return _readString(map['id']);
}

String _readOutcomeId(Map<String, dynamic> json) {
  return _readString(
        json['id'] ??
            json['outcomeID'] ??
            json['outcomeId'] ??
            json['outcome_id'] ??
            json['choiceID'] ??
            json['choiceId'] ??
            json['choice_id'],
      ) ??
      '';
}

int? _readDirectViewerPoints(Map<String, dynamic> map) {
  for (final key in const <String>[
    'viewerPoints',
    'viewer_points',
    'viewerChannelPoints',
    'viewer_channel_points',
    'myPoints',
    'my_points',
    'selfPoints',
    'self_points',
    'predictedPoints',
    'predicted_points',
  ]) {
    final value = _readInt(map[key]);
    if (value != null) return value;
  }
  return null;
}

int? _readViewerPointsFromPredictionRecord(Map<String, dynamic> map) {
  return _readDirectViewerPoints(map) ??
      _readInt(
        map['points'] ??
            map['channelPoints'] ??
            map['channel_points'] ??
            map['amount'] ??
            map['value'],
      );
}

int? _readViewerPointsFromOutcome(Map<String, dynamic> json) {
  final direct = _readDirectViewerPoints(json);
  if (direct != null) return direct;

  for (final key in const <String>[
    'viewerPrediction',
    'viewer_prediction',
    'myPrediction',
    'my_prediction',
    'selfPrediction',
    'self_prediction',
    'currentUserPrediction',
    'current_user_prediction',
  ]) {
    final record = _readViewerPredictionRecordFromObject(json[key]);
    if (record != null) return record.points;
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
  if (value is num) return value.round();
  return int.tryParse(value.toString().replaceAll(',', '').trim());
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
  if (value is num) return value != 0;
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

bool _matchesOutcomeIdentity(TwitchPredictionOutcome outcome, String identity) {
  return _matchesIdentity(
    id: outcome.id,
    title: outcome.title,
    identity: identity,
  );
}

bool _matchesIdentity({
  required String id,
  required String title,
  required String identity,
}) {
  final safe = identity.trim();
  if (safe.isEmpty) return false;
  if (id.trim().isNotEmpty && id.trim() == safe) return true;
  if (title.trim().isNotEmpty && title.trim() == safe) return true;
  return false;
}

bool _samePredictionFamily(
  TwitchPredictionSnapshot a,
  TwitchPredictionSnapshot b,
) {
  if (a.id.trim().isNotEmpty && b.id.trim().isNotEmpty) {
    return a.id.trim() == b.id.trim();
  }
  if (a.title.trim().isNotEmpty && b.title.trim().isNotEmpty) {
    return a.title.trim() == b.title.trim();
  }
  return true;
}
