import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/chat/twitch_hermes_event.dart';

class TwitchHermesApiService {
  final String clientId;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final Map<String, String> _subscriptionTopicById = <String, String>{};
  final Map<String, String> _requestTopicById = <String, String>{};

  final StreamController<TwitchHermesEvent> _eventsController =
      StreamController<TwitchHermesEvent>.broadcast();
  final StreamController<String> _rawController =
      StreamController<String>.broadcast();

  TwitchHermesApiService({
    required this.clientId,
  });

  Stream<TwitchHermesEvent> get events => _eventsController.stream;
  Stream<String> get rawEvents => _rawController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect() async {
    await disconnect();

    final uri = Uri.parse(
      'wss://hermes.twitch.tv/v1?clientId=${Uri.encodeQueryComponent(clientId)}',
    );

    final ws = WebSocketChannel.connect(uri);
    _channel = ws;

    _subscription = ws.stream.listen(
      handleSocketMessage,
      onError: (Object error, StackTrace stackTrace) {
        _rawController.add('ERROR $error');
      },
      onDone: () {
        _rawController.add('DISCONNECTED');
      },
      cancelOnError: false,
    );
  }

  Future<void> subscribePubsubTopic(String topic) async {
    if (_channel == null) {
      await connect();
    }

    final requestId = _randomId();
    final subscriptionId = _randomId();

    _requestTopicById[requestId] = topic;
    _subscriptionTopicById[subscriptionId] = topic;

    final payload = <String, dynamic>{
      'type': 'subscribe',
      'id': requestId,
      'subscribe': <String, dynamic>{
        'id': subscriptionId,
        'type': 'pubsub',
        'pubsub': <String, dynamic>{
          'topic': topic,
        },
      },
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    _channel?.sink.add(jsonEncode(payload));
  }

  Future<void> subscribePubsubTopics(Iterable<String> topics) async {
    for (final topic in topics) {
      final clean = topic.trim();
      if (clean.isEmpty) continue;
      await subscribePubsubTopic(clean);
    }
  }

  void handleSocketMessage(dynamic event) {
    final raw = event is List<int> ? utf8.decode(event) : event.toString();
    if (raw.trim().isEmpty) return;

    _rawController.add(raw);

    try {
      final parsed = TwitchHermesEvent.fromRaw(
        raw,
        subscriptionTopicById: _subscriptionTopicById,
        requestTopicById: _requestTopicById,
      );
      _eventsController.add(parsed);
    } catch (_) {
      _eventsController.add(
        TwitchHermesEvent(
          type: 'parse_error',
          raw: raw,
          data: <String, dynamic>{'raw': raw},
        ),
      );
    }
  }

  Future<List<TwitchHermesEvent>> collectEvents({
    required Iterable<String> topics,
    Duration duration = const Duration(seconds: 25),
    int maxEvents = 30,
    bool includeKeepalive = true,
  }) async {
    final collected = <TwitchHermesEvent>[];
    final completer = Completer<List<TwitchHermesEvent>>();

    late final StreamSubscription<TwitchHermesEvent> sub;
    Timer? timer;

    sub = events.listen((event) {
      if (!includeKeepalive && event.isKeepalive) return;

      collected.add(event);

      if (collected.length >= maxEvents && !completer.isCompleted) {
        completer.complete(List<TwitchHermesEvent>.unmodifiable(collected));
      }
    });

    timer = Timer(duration, () {
      if (!completer.isCompleted) {
        completer.complete(List<TwitchHermesEvent>.unmodifiable(collected));
      }
    });

    try {
      await connect();
      await subscribePubsubTopics(topics);
      return await completer.future;
    } finally {
      timer.cancel();
      await sub.cancel();
      await disconnect();
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    final channel = _channel;
    _channel = null;

    _requestTopicById.clear();
    _subscriptionTopicById.clear();

    await channel?.sink.close();
  }

  Future<void> dispose() async {
    await disconnect();
    await _eventsController.close();
    await _rawController.close();
  }

  String _randomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';
    final random = Random.secure();
    return List<String>.generate(
      21,
      (_) => chars[random.nextInt(chars.length)],
      growable: false,
    ).join();
  }
}
