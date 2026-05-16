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

    if (lowerTopic.contains('predictions-channel-v1') ||
        eventType == 'event-updated' ||
        eventType == 'prediction-made') {
      final next = TwitchPredictionSnapshot.fromHermesPayload(
        payload,
        viewerUserId: _viewerUserId,
        previous: _lastPrediction,
      );

      if (next.hasPrediction) {
        _lastPrediction = next;
        TwitchPredictionHermesRealtimeBus.publishPrediction(next);
        _onPrediction?.call(next);
      }
    }
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
