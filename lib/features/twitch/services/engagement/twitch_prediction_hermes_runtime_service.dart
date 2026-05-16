import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../api/core/twitch_api_constants.dart';
import '../../models/engagement/twitch_prediction.dart';

typedef TwitchHermesPredictionHandler = void Function(
  TwitchPredictionSnapshot prediction,
);

typedef TwitchHermesBalanceHandler = void Function(int balance);
typedef TwitchHermesStatusHandler = void Function(String status);

class TwitchPredictionHermesRealtimeBus {
  TwitchPredictionHermesRealtimeBus._();

  static final StreamController<TwitchPredictionSnapshot?> _predictionController =
      StreamController<TwitchPredictionSnapshot?>.broadcast();

  static TwitchPredictionSnapshot? _latestPrediction;

  static TwitchPredictionSnapshot? get latestPrediction => _latestPrediction;

  static Stream<TwitchPredictionSnapshot?> get predictionStream {
    return _predictionController.stream;
  }

  static void publishPrediction(TwitchPredictionSnapshot? prediction) {
    _latestPrediction = prediction;
    if (!_predictionController.isClosed) {
      _predictionController.add(prediction);
    }
  }
}

class TwitchPredictionHermesGlobalRuntime {
  static final TwitchPredictionHermesRuntimeService _runtime =
      TwitchPredictionHermesRuntimeService();

  static String? _channelId;
  static String? _viewerUserId;

  TwitchPredictionHermesGlobalRuntime._();

  static Future<void> ensureConnected({
    required String? channelId,
    String? viewerUserId,
    TwitchPredictionSnapshot? previousPrediction,
  }) async {
    final safeChannelId = channelId?.trim() ?? '';
    final incomingViewerUserId = viewerUserId?.trim();

    if (safeChannelId.isEmpty) return;

    final sameChannel = _channelId == safeChannelId;
    final effectiveViewerUserId = incomingViewerUserId != null &&
            incomingViewerUserId.isNotEmpty
        ? incomingViewerUserId
        : sameChannel
            ? _viewerUserId
            : null;
    final sameViewer = (_viewerUserId ?? '') == (effectiveViewerUserId ?? '');

    if (sameChannel && sameViewer && _runtime.connected) {
      if (previousPrediction != null && previousPrediction.hasPrediction) {
        TwitchPredictionHermesRealtimeBus.publishPrediction(previousPrediction);
      }
      return;
    }

    _channelId = safeChannelId;
    _viewerUserId = effectiveViewerUserId == null || effectiveViewerUserId.isEmpty
        ? null
        : effectiveViewerUserId;

    await _runtime.connect(
      channelId: safeChannelId,
      viewerUserId: _viewerUserId,
      previousPrediction: previousPrediction,
      onPrediction: TwitchPredictionHermesRealtimeBus.publishPrediction,
      onStatus: (status) {},
    );
  }

  static Future<void> disconnect() async {
    _channelId = null;
    _viewerUserId = null;
    await _runtime.disconnect();
  }
}

class TwitchPredictionHermesRuntimeService {
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _subscription;
  final Map<String, String> _subscriptionTopics = <String, String>{};

  int _generation = 0;
  bool _connected = false;
  String? _viewerUserId;
  TwitchPredictionSnapshot? _lastPrediction;
  TwitchHermesPredictionHandler? _onPrediction;
  TwitchHermesBalanceHandler? _onBalance;
  TwitchHermesStatusHandler? _onStatus;

  bool get connected => _connected;

  Future<void> connect({
    required String? channelId,
    required String? viewerUserId,
    TwitchPredictionSnapshot? previousPrediction,
    TwitchHermesPredictionHandler? onPrediction,
    TwitchHermesBalanceHandler? onBalance,
    TwitchHermesStatusHandler? onStatus,
    String clientId = TwitchApiConstants.twitchWebClientId,
  }) async {
    final safeChannelId = channelId?.trim() ?? '';
    final safeViewerId = viewerUserId?.trim();

    await disconnect();

    if (safeChannelId.isEmpty) {
      onStatus?.call('Hermes prediction skipped: missing channelId');
      return;
    }

    final generation = ++_generation;
    _viewerUserId = safeViewerId == null || safeViewerId.isEmpty ? null : safeViewerId;
    _lastPrediction = previousPrediction;
    if (_lastPrediction != null && _lastPrediction!.hasPrediction) {
      TwitchPredictionHermesRealtimeBus.publishPrediction(_lastPrediction);
    }
    _onPrediction = onPrediction;
    _onBalance = onBalance;
    _onStatus = onStatus;

    try {
      final safeClientId = clientId.trim().isEmpty
          ? TwitchApiConstants.twitchWebClientId
          : clientId.trim();
      final uri = Uri.parse(
        '${TwitchApiConstants.hermesWebSocketUrl}?clientId=${Uri.encodeComponent(safeClientId)}',
      );
      final socket = IOWebSocketChannel.connect(uri);
      _socket = socket;
      _connected = true;
      _emitStatus('Hermes prediction connecting...');

      _subscription = socket.stream.listen(
        (event) => _handleSocketEvent(event, generation),
        onError: (Object error) {
          if (generation != _generation) return;
          _connected = false;
          _emitStatus('Hermes prediction error: $error');
        },
        onDone: () {
          if (generation != _generation) return;
          _connected = false;
          _emitStatus('Hermes prediction disconnected');
        },
        cancelOnError: false,
      );

      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (generation != _generation) return;

      _subscribe('predictions-channel-v1.$safeChannelId');
      if (_viewerUserId != null) {
        _subscribe('predictions-user-v1.$_viewerUserId');
        _subscribe('community-points-user-v1.$_viewerUserId');
      }

      _emitStatus('Hermes prediction subscribed');
    } catch (error) {
      if (generation != _generation) return;
      _connected = false;
      _emitStatus('Hermes prediction failed: $error');
    }
  }

  Future<void> disconnect() async {
    _generation++;
    _connected = false;
    _subscriptionTopics.clear();

    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();

    final socket = _socket;
    _socket = null;
    await socket?.sink.close();
  }

  Future<void> dispose() => disconnect();

  void _subscribe(String topic) {
    final socket = _socket;
    if (socket == null) return;

    final subscriptionId = _randomId();
    _subscriptionTopics[subscriptionId] = topic;

    final payload = <String, dynamic>{
      'type': 'subscribe',
      'id': _randomId(),
      'subscribe': <String, dynamic>{
        'id': subscriptionId,
        'type': 'pubsub',
        'pubsub': <String, dynamic>{'topic': topic},
      },
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    socket.sink.add(jsonEncode(payload));
  }

  void _handleSocketEvent(Object? event, int generation) {
    if (generation != _generation) return;

    final text = event?.toString() ?? '';
    if (text.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return;

      final type = decoded['type']?.toString();
      switch (type) {
        case 'welcome':
          _connected = true;
          _emitStatus('Hermes prediction welcome');
          return;
        case 'keepalive':
          return;
        case 'subscribeResponse':
          _handleSubscribeResponse(decoded);
          return;
        case 'notification':
          _handleNotification(decoded);
          return;
      }
    } catch (error) {
      _emitStatus('Hermes prediction parse error: $error');
    }
  }

  void _handleSubscribeResponse(Map<dynamic, dynamic> decoded) {
    final response = decoded['subscribeResponse'];
    final subscription = response is Map ? response['subscription'] : null;
    final subscriptionId = subscription is Map ? subscription['id']?.toString() : null;
    final topic = subscriptionId == null ? null : _subscriptionTopics[subscriptionId];
    final error = response is Map ? response['error']?.toString() : null;

    if (error != null && error.trim().isNotEmpty) {
      _emitStatus('Hermes topic failed: ${topic ?? subscriptionId ?? '--'} · $error');
      return;
    }

    _emitStatus('Hermes topic OK: ${topic ?? subscriptionId ?? '--'}');
  }

  void _handleNotification(Map<dynamic, dynamic> decoded) {
    final notification = decoded['notification'];
    if (notification is! Map) return;

    final subscription = notification['subscription'];
    final subscriptionId = subscription is Map ? subscription['id']?.toString() : null;
    final topic = subscriptionId == null ? null : _subscriptionTopics[subscriptionId];

    final pubsubText = notification['pubsub']?.toString();
    if (pubsubText == null || pubsubText.trim().isEmpty) return;

    Object? payload;
    try {
      payload = jsonDecode(pubsubText);
    } catch (_) {
      return;
    }

    if (payload is! Map) return;

    final eventType = payload['type']?.toString();
    final lowerTopic = topic?.toLowerCase() ?? '';

    if (lowerTopic.contains('community-points-user-v1') ||
        eventType == 'points-spent' ||
        eventType == 'balance-updated') {
      final balance = _readBalance(payload);
      if (balance != null) {
        _onBalance?.call(balance);
      }
    }

    final isChannelPredictionTopic =
        lowerTopic.contains('predictions-channel-v1');
    final isUserPredictionTopic = lowerTopic.contains('predictions-user-v1');
    if (isChannelPredictionTopic ||
        isUserPredictionTopic ||
        _isPredictionEventType(eventType)) {
      _handlePredictionPayload(
        payload,
        eventType: eventType,
        scopedToViewer: isUserPredictionTopic,
      );
    }
  }

  void _handlePredictionPayload(
    Map<dynamic, dynamic> payload, {
    required String? eventType,
    bool scopedToViewer = false,
  }) {
    final type = eventType?.trim().toLowerCase() ?? '';

    if (scopedToViewer || type == 'prediction-made') {
      final viewerPrediction = _readViewerPredictionMade(
        payload,
        scopedToViewer: scopedToViewer,
      );
      final base = _lastPrediction;
      if (viewerPrediction != null && base != null && base.hasPrediction) {
        final sameEvent = viewerPrediction.eventId == null ||
            viewerPrediction.eventId!.trim().isEmpty ||
            base.id.trim().isEmpty ||
            viewerPrediction.eventId!.trim() == base.id.trim();
        if (sameEvent) {
          final next = base.withViewerPrediction(
            outcomeId: viewerPrediction.outcomeId,
            points: viewerPrediction.points,
            addToExisting: viewerPrediction.addToExisting,
          );
          _publishPrediction(next);
          return;
        }
      }
      if (type == 'prediction-made') return;
    }

    final normalizedPayload = _normalizePredictionPayload(payload);
    if (normalizedPayload == null) return;

    var next = TwitchPredictionSnapshot.fromHermesPayload(
      normalizedPayload,
      viewerUserId: _viewerUserId,
      previous: _lastPrediction,
    );

    final viewerFromTopPredictors = _readViewerFromTopPredictors(payload);
    if (viewerFromTopPredictors != null) {
      next = next.withViewerPrediction(
        outcomeId: viewerFromTopPredictors.outcomeId,
        points: viewerFromTopPredictors.points,
        addToExisting: false,
      );
    }

    if (next.hasPrediction) {
      _publishPrediction(next);
    }
  }

  void _publishPrediction(TwitchPredictionSnapshot prediction) {
    _lastPrediction = prediction;
    TwitchPredictionHermesRealtimeBus.publishPrediction(prediction);
    _onPrediction?.call(prediction);
  }

  bool _isPredictionEventType(String? eventType) {
    final type = eventType?.trim().toLowerCase() ?? '';
    return type == 'event-updated' ||
        type == 'event-created' ||
        type == 'event-locked' ||
        type == 'event-ended' ||
        type == 'event-resolved' ||
        type == 'event-canceled' ||
        type == 'event-cancelled' ||
        type == 'prediction-made' ||
        type == 'prediction-created' ||
        type == 'prediction-updated' ||
        type == 'prediction-locked' ||
        type == 'prediction-ended' ||
        type == 'prediction-resolved' ||
        type == 'prediction-canceled' ||
        type == 'prediction-cancelled' ||
        type == 'user-prediction-made' ||
        type == 'user-prediction-updated' ||
        type == 'prediction-result';
  }

  Map<String, dynamic>? _normalizePredictionPayload(Map<dynamic, dynamic> payload) {
    final root = payload.map((key, value) => MapEntry(key.toString(), value));
    final type = root['type']?.toString().trim().toLowerCase() ?? '';
    if (type == 'event-updated') return root;

    final event = _readEventMap(payload);
    if (event == null) return root;

    return <String, dynamic>{
      'type': 'event-updated',
      'data': <String, dynamic>{'event': event},
    };
  }

  _HermesViewerPrediction? _readViewerPredictionMade(
    Map<dynamic, dynamic> payload, {
    bool scopedToViewer = false,
  }) {
    final viewerId = _viewerUserId?.trim();
    if (!scopedToViewer && (viewerId == null || viewerId.isEmpty)) return null;

    final candidates = <Object?>[
      payload,
      payload['data'],
      payload['prediction'],
      payload['user_prediction'],
      payload['userPrediction'],
      payload['prediction_result'],
      payload['predictionResult'],
    ];

    final data = payload['data'];
    if (data is Map) {
      candidates.addAll(<Object?>[
        data['prediction'],
        data['user_prediction'],
        data['userPrediction'],
        data['prediction_result'],
        data['predictionResult'],
        data['event'],
      ]);
    }

    for (final candidate in candidates) {
      final result = _readViewerPredictionFromObject(
        candidate,
        scopedToViewer: scopedToViewer,
        viewerId: viewerId,
      );
      if (result != null) return result;
    }

    return null;
  }

  _HermesViewerPrediction? _readViewerPredictionFromObject(
    Object? value, {
    required bool scopedToViewer,
    required String? viewerId,
  }) {
    if (value is List) {
      for (final item in value) {
        final result = _readViewerPredictionFromObject(
          item,
          scopedToViewer: scopedToViewer,
          viewerId: viewerId,
        );
        if (result != null) return result;
      }
      return null;
    }

    if (value is! Map) return null;

    final map = value.map((key, value) => MapEntry(key.toString(), value));
    final userId = _readString(
      map['user_id'] ??
          map['userId'] ??
          map['viewer_id'] ??
          map['viewerId'] ??
          _readNested(map['user'], 'id') ??
          _readNested(map['viewer'], 'id'),
    );
    if (!scopedToViewer &&
        viewerId != null &&
        viewerId.isNotEmpty &&
        userId != null &&
        userId != viewerId) {
      return null;
    }

    final eventId = _readString(
      map['event_id'] ??
          map['eventID'] ??
          map['eventId'] ??
          map['prediction_event_id'] ??
          map['predictionEventId'] ??
          map['predictionEventID'] ??
          _readNested(map['event'], 'id') ??
          _readNested(map['predictionEvent'], 'id') ??
          _readNested(map['prediction_event'], 'id'),
    );
    final outcomeId = _readString(
      map['outcome_id'] ??
          map['outcomeID'] ??
          map['outcomeId'] ??
          map['choice_id'] ??
          map['choiceId'] ??
          map['prediction_option_id'] ??
          map['predictionOptionId'] ??
          _readNested(map['outcome'], 'id') ??
          _readNested(map['choice'], 'id') ??
          _readNested(map['predictionOption'], 'id') ??
          _readNested(map['prediction_option'], 'id'),
    );
    final points = _readInt(
          map['points'] ??
              map['channel_points_used'] ??
              map['channelPointsUsed'] ??
              map['channel_points'] ??
              map['channelPoints'] ??
              map['amount'] ??
              map['value'],
        ) ??
        0;

    if (outcomeId != null && outcomeId.isNotEmpty && points > 0) {
      return _HermesViewerPrediction(
        eventId: eventId,
        outcomeId: outcomeId,
        points: points,
        addToExisting: !scopedToViewer,
      );
    }

    for (final key in const <String>[
      'prediction',
      'user_prediction',
      'userPrediction',
      'prediction_result',
      'predictionResult',
      'result',
    ]) {
      final nested = _readViewerPredictionFromObject(
        map[key],
        scopedToViewer: scopedToViewer,
        viewerId: viewerId,
      );
      if (nested != null) return nested;
    }

    return null;
  }

  _HermesViewerPrediction? _readViewerFromTopPredictors(Map<dynamic, dynamic> payload) {
    final viewerId = _viewerUserId?.trim();
    if (viewerId == null || viewerId.isEmpty) return null;

    final event = _readEventMap(payload);
    if (event == null) return null;

    final outcomes = event['outcomes'];
    if (outcomes is! List) return null;

    for (final outcome in outcomes) {
      if (outcome is! Map) continue;
      final outcomeId = _readString(
        outcome['id'] ?? outcome['outcome_id'] ?? outcome['outcomeId'],
      );
      if (outcomeId == null || outcomeId.isEmpty) continue;

      final predictors = outcome['top_predictors'] ?? outcome['topPredictors'];
      if (predictors is! List) continue;

      for (final predictor in predictors) {
        if (predictor is! Map) continue;
        final userId = _readString(
          predictor['user_id'] ??
              predictor['userId'] ??
              _readNested(predictor['user'], 'id'),
        );
        if (userId != viewerId) continue;

        final points = _readInt(
              predictor['points'] ??
                  predictor['channel_points_used'] ??
                  predictor['channelPointsUsed'] ??
                  predictor['amount'] ??
                  predictor['value'],
            ) ??
            0;
        if (points <= 0) continue;

        return _HermesViewerPrediction(outcomeId: outcomeId, points: points);
      }
    }

    return null;
  }

  Map<dynamic, dynamic>? _readEventMap(Map<dynamic, dynamic> payload) {
    final data = payload['data'];
    if (data is Map) {
      final event = data['event'] ??
          data['prediction'] ??
          data['predictionEvent'] ??
          data['prediction_event'];
      if (event is Map) return event;
    }

    final event = payload['event'] ??
        payload['prediction'] ??
        payload['predictionEvent'] ??
        payload['prediction_event'];
    return event is Map ? event : null;
  }

  Object? _readNested(Object? value, String key) {
    if (value is! Map) return null;
    return value[key];
  }

  int? _readBalance(Map<dynamic, dynamic> payload) {
    final data = payload['data'];
    if (data is Map) {
      final balance = data['balance'];
      if (balance is Map) {
        return _readInt(balance['balance'] ?? balance['value'] ?? balance['amount']);
      }

      final direct = _readInt(data['balance'] ?? data['points'] ?? data['value']);
      if (direct != null) return direct;
    }

    return _readInt(payload['balance'] ?? payload['points'] ?? payload['value']);
  }

  String? _readString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int? _readInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().replaceAll(',', '').trim());
  }

  void _emitStatus(String status) {
    _onStatus?.call(status);
  }

  String _randomId() {
    final random = math.Random.secure();
    return List<String>.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }
}

class _HermesViewerPrediction {
  final String? eventId;
  final String outcomeId;
  final int points;
  final bool addToExisting;

  const _HermesViewerPrediction({
    this.eventId,
    required this.outcomeId,
    required this.points,
    this.addToExisting = false,
  });
}