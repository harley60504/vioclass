// PATCH VERSION: twitch_prediction_bet_helpers_stage167
//
// Shared non-UI helpers for the prediction bet sheet and its widgets.

import '../../../models/engagement/twitch_prediction.dart';

String twitchPredictionViewerChoiceId(TwitchPredictionSnapshot prediction) {
  final direct = prediction.viewerOutcomeId?.trim();
  if (direct != null && direct.isNotEmpty) return direct;

  for (final outcome in prediction.outcomes) {
    if (outcome.isViewerChoice || outcome.viewerPoints > 0) {
      return twitchPredictionOutcomeIdentity(outcome);
    }
  }

  return '';
}

TwitchPredictionOutcome? twitchPredictionOutcomeByIdentity(
  List<TwitchPredictionOutcome> outcomes,
  String identity,
) {
  final safeIdentity = identity.trim();
  if (safeIdentity.isEmpty) return null;

  for (final outcome in outcomes) {
    if (twitchPredictionOutcomeIdentity(outcome) == safeIdentity) {
      return outcome;
    }
  }

  return null;
}

String twitchPredictionOutcomeIdentity(TwitchPredictionOutcome outcome) {
  final id = outcome.id.trim();
  if (id.isNotEmpty) return id;
  return outcome.title.trim();
}

String? twitchPredictionTimeLabel(TwitchPredictionSnapshot prediction) {
  final status = prediction.normalizedStatus;
  final now = DateTime.now();

  if (status == 'ACTIVE' || status == 'OPEN') {
    final locksAt = twitchPredictionEffectiveLocksAt(prediction);
    if (locksAt == null) return null;
    final remaining = locksAt.difference(now);
    if (remaining.inSeconds > 0) {
      return '鎖盤剩 ${twitchPredictionFormatDuration(remaining)}';
    }
    return '已鎖盤';
  }

  if (prediction.isLockedLike) {
    final endedAt = prediction.endedAt;
    if (endedAt != null) {
      final remaining = endedAt.difference(now);
      if (remaining.inSeconds > 0) {
        return '結算剩 ${twitchPredictionFormatDuration(remaining)}';
      }
    }
    return '等待結算';
  }

  final endedAt = prediction.endedAt;
  if (endedAt != null) {
    return '結算 ${twitchPredictionFormatClock(endedAt)}';
  }

  return null;
}

DateTime? twitchPredictionEffectiveLocksAt(
  TwitchPredictionSnapshot prediction,
) {
  final explicit = prediction.locksAt;
  if (explicit != null) return explicit;

  final createdAt =
      prediction.createdAt ??
      _readDateFromRaw(prediction.rawPrediction, const <String>[
        'createdAt',
        'created_at',
        'startedAt',
        'started_at',
      ]);
  if (createdAt == null) return null;

  final windowSeconds =
      _readIntFromRaw(prediction.rawPrediction, const <String>[
        'predictionWindowSeconds',
        'prediction_window_seconds',
        'predictionWindowDurationSeconds',
        'prediction_window_duration_seconds',
        'durationSeconds',
        'duration_seconds',
        'windowSeconds',
        'window_seconds',
      ]);

  if (windowSeconds == null || windowSeconds <= 0) return null;
  return createdAt.add(Duration(seconds: windowSeconds));
}

String twitchPredictionFormatDuration(Duration value) {
  final totalSeconds = value.inSeconds <= 0 ? 0 : value.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String twitchPredictionFormatClock(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String twitchPredictionFormatCompact(int value) {
  if (value >= 1000000000) {
    final text = (value / 1000000000).toStringAsFixed(
      value >= 10000000000 ? 1 : 2,
    );
    return '${_trimTrailingZero(text)}B';
  }
  if (value >= 1000000) {
    final text = (value / 1000000).toStringAsFixed(value >= 10000000 ? 1 : 2);
    return '${_trimTrailingZero(text)}M';
  }
  if (value >= 1000) {
    final text = (value / 1000).toStringAsFixed(value >= 10000 ? 1 : 2);
    return '${_trimTrailingZero(text)}k';
  }
  return value.toString();
}

DateTime? _readDateFromRaw(Map<String, dynamic>? raw, List<String> keys) {
  if (raw == null) return null;
  for (final key in keys) {
    final value = raw[key];
    final text = value?.toString();
    if (text == null || text.trim().isEmpty) continue;
    final parsed = DateTime.tryParse(text.trim());
    if (parsed != null) return parsed;
  }
  return null;
}

int? _readIntFromRaw(Map<String, dynamic>? raw, List<String> keys) {
  if (raw == null) return null;
  for (final key in keys) {
    final value = raw[key];
    if (value == null) continue;
    if (value is int) return value;
    if (value is num) return value.round();
    final parsed = int.tryParse(value.toString().replaceAll(',', '').trim());
    if (parsed != null) return parsed;
  }
  return null;
}

String _trimTrailingZero(String text) {
  return text
      .replaceFirst(RegExp(r'\.0+$'), '')
      .replaceFirst(RegExp(r'(\.\d*[1-9])0+$'), r'$1');
}
