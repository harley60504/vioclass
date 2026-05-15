import 'dart:math' as math;

import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';
import '../core/twitch_api_exception.dart';

typedef TwitchDropsPredictionTokenProvider = Future<String?> Function();

class TwitchDropsPredictionApiService {
  final TwitchApiClient client;
  final TwitchDropsPredictionTokenProvider tokenProvider;
  final String clientId;

  const TwitchDropsPredictionApiService({
    required this.client,
    required this.tokenProvider,
    this.clientId = TwitchApiConstants.twitchAndroidClientId,
  });

  Future<Map<String, dynamic>> makePrediction({
    required Object prediction,
    required Object outcome,
    required int points,
  }) async {
    if (points <= 0) {
      throw ArgumentError.value(points, 'points', 'must be greater than 0');
    }

    final token = await _requireToken();
    final eventId = _extractId(
      prediction,
      const <String>[
        'predictionId',
        'eventId',
        'eventID',
        'id',
      ],
    );
    final outcomeId = _extractId(
      outcome,
      const <String>[
        'outcomeId',
        'outcomeID',
        'id',
      ],
    );

    if (eventId.isEmpty) {
      throw TwitchApiException(
        'Prediction event id is empty. Cannot place prediction.',
        details: _toJson(prediction),
      );
    }

    if (outcomeId.isEmpty) {
      throw TwitchApiException(
        'Prediction outcome id is empty. Cannot place prediction.',
        details: _toJson(outcome),
      );
    }

    final mutation = r'''
mutation MakePrediction($input: MakePredictionInput!) {
  makePrediction(input: $input) {
    prediction {
      id
      points
    }
    error {
      code
    }
  }
}
''';

    final raw = await client.postJson<dynamic>(
      '${TwitchApiConstants.gqlEndpoint}#origin=twilight',
      data: <String, dynamic>{
        'operationName': 'MakePrediction',
        'query': mutation,
        'variables': <String, dynamic>{
          'input': <String, dynamic>{
            'eventID': eventId,
            'outcomeID': outcomeId,
            'points': points,
            'transactionID': _transactionId(),
          },
        },
      },
      headers: <String, String>{
        ...TwitchApiConstants.twitchWebHeaders,
        'Client-ID': clientId,
        'Authorization': 'OAuth $token',
        'Content-Type': 'application/json',
        'Accept-Language': 'en-US',
        'X-Device-Id': _transactionId().replaceAll('-', ''),
        'Client-Session-Id': _transactionId().replaceAll('-', ''),
      },
    );

    if (raw is! Map<String, dynamic>) {
      throw TwitchApiException(
        'Unexpected MakePrediction response type: ${raw.runtimeType}.',
        details: raw,
      );
    }

    final errors = raw['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw TwitchApiException(
        errors.toString(),
        details: raw,
      );
    }

    final makePrediction = _readMap(raw, const <String>[
      'data',
      'makePrediction',
    ]);

    final error = _readMap(makePrediction, const <String>['error']);
    if (error != null) {
      final code = error['code']?.toString() ?? 'UNKNOWN';
      throw TwitchApiException(
        'Prediction failed: $code',
        details: raw,
      );
    }

    return raw;
  }

  Future<String> _requireToken() async {
    final token = await tokenProvider();
    final safeToken = token?.trim();

    if (safeToken == null || safeToken.isEmpty) {
      throw TwitchApiException(
        'Drops token is missing. Open Drops / Channel Points Test Page and finish device flow first.',
      );
    }

    return safeToken;
  }

  String _extractId(Object value, List<String> candidateKeys) {
    final json = _toJson(value);

    if (json is Map) {
      for (final key in candidateKeys) {
        final candidate = json[key]?.toString().trim();
        if (candidate != null && candidate.isNotEmpty) {
          return candidate;
        }
      }
    }

    for (final key in candidateKeys) {
      try {
        final dynamic dynamicValue = value;
        final Object? candidate = switch (key) {
          'predictionId' => dynamicValue.predictionId,
          'eventId' => dynamicValue.eventId,
          'eventID' => dynamicValue.eventID,
          'outcomeId' => dynamicValue.outcomeId,
          'outcomeID' => dynamicValue.outcomeID,
          'id' => dynamicValue.id,
          _ => null,
        };

        final text = candidate?.toString().trim();
        if (text != null && text.isNotEmpty) {
          return text;
        }
      } catch (_) {
        // Try next key.
      }
    }

    return '';
  }

  Object? _toJson(Object value) {
    if (value is Map || value is List || value is String || value is num || value is bool) {
      return value;
    }

    try {
      final dynamic dynamicValue = value;
      return dynamicValue.toJson();
    } catch (_) {
      return value.toString();
    }
  }

  Map<String, dynamic>? _readMap(Object? root, List<String> path) {
    Object? current = root;

    for (final key in path) {
      if (current is Map) {
        current = current[key];
      } else {
        return null;
      }
    }

    if (current is Map<String, dynamic>) return current;
    if (current is Map) {
      return current.map((key, value) => MapEntry(key.toString(), value));
    }

    return null;
  }

  String _transactionId() {
    final random = math.Random.secure();
    String segment(int length) {
      return List<String>.generate(
        length,
        (_) => random.nextInt(16).toRadixString(16),
      ).join();
    }

    return '${segment(8)}-${segment(4)}-${segment(4)}-${segment(4)}-${segment(12)}';
  }
}
