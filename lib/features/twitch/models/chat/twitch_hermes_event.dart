import 'dart:convert';

class TwitchHermesEvent {
  final String type;
  final String? id;
  final String? topic;
  final Map<String, dynamic>? data;
  final String raw;

  const TwitchHermesEvent({
    required this.type,
    required this.raw,
    this.id,
    this.topic,
    this.data,
  });

  bool get isKeepalive => type == 'keepalive';
  bool get isSubscribeResponse => type == 'subscribeResponse';
  bool get isNotification => type == 'notification';

  factory TwitchHermesEvent.fromRaw(
    String raw, {
    Map<String, String> subscriptionTopicById = const <String, String>{},
    Map<String, String> requestTopicById = const <String, String>{},
  }) {
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      return TwitchHermesEvent(
        type: 'unknown',
        raw: raw,
        data: <String, dynamic>{'value': decoded},
      );
    }

    final type = decoded['type']?.toString() ?? 'unknown';
    final id = decoded['id']?.toString();
    String? topic;
    Map<String, dynamic>? payload;

    if (type == 'subscribeResponse') {
      final parentId = decoded['parentId']?.toString();
      topic = parentId == null ? null : requestTopicById[parentId];
      payload = decoded;
    } else if (type == 'notification') {
      final notification = decoded['notification'];
      if (notification is Map) {
        final subscription = notification['subscription'];
        final subscriptionId = subscription is Map ? subscription['id']?.toString() : null;
        topic = subscriptionId == null ? null : subscriptionTopicById[subscriptionId];

        final pubsub = notification['pubsub'];
        if (pubsub is String && pubsub.trim().isNotEmpty) {
          try {
            final parsedPubsub = jsonDecode(pubsub);
            if (parsedPubsub is Map<String, dynamic>) {
              payload = parsedPubsub;
            } else {
              payload = <String, dynamic>{'value': parsedPubsub};
            }
          } catch (_) {
            payload = <String, dynamic>{'rawPubsub': pubsub};
          }
        } else if (pubsub is Map<String, dynamic>) {
          payload = pubsub;
        }
      }
    }

    return TwitchHermesEvent(
      type: type,
      id: id,
      topic: topic,
      data: payload ?? decoded,
      raw: raw,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      if (id != null) 'id': id,
      if (topic != null) 'topic': topic,
      if (data != null) 'data': data,
      'raw': raw,
    };
  }
}
