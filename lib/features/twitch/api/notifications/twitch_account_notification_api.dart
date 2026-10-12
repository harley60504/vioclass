import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';

enum TwitchAccountNotificationKind { giftSubscription, earnedBadge }

class TwitchAccountNotification {
  final String id;
  final String ownerId;
  final TwitchAccountNotificationKind kind;
  final String body;
  final String imageUrl;
  final DateTime createdAt;

  const TwitchAccountNotification({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.body,
    required this.imageUrl,
    required this.createdAt,
  });

  String get title => kind == TwitchAccountNotificationKind.giftSubscription
      ? '你收到贈送訂閱'
      : '你獲得了新徽章';
}

/// Read-only Twitch bell feed, matching StreamNook's raw-query approach.
/// No persisted hash, integrity refresh, Cookie access or token writes.
class TwitchAccountNotificationApi {
  final TwitchApiClient client;
  const TwitchAccountNotificationApi(this.client);

  static const query = r'''query VioAccountNotifications($first: Int!) {
    currentUser {
      id
      notifications(first: $first, language: "en", displayType: VIEWER) {
        edges { node { id type category body createdAt thumbnailURL } }
      }
    }
  }''';

  Future<List<TwitchAccountNotification>> fetch({
    required String token,
    required String ownerId,
  }) async {
    final response = await client.postJson<dynamic>(
      TwitchApiConstants.gqlEndpoint,
      headers: {
        'Client-ID': TwitchApiConstants.twitchWebClientId,
        'Authorization': 'OAuth ${token.trim()}',
      },
      data: {
        'operationName': 'VioAccountNotifications',
        'query': query,
        'variables': {'first': 25},
      },
    );
    return parse(response, ownerId: ownerId);
  }

  static List<TwitchAccountNotification> parse(
    dynamic response, {
    required String ownerId,
  }) {
    if (response is! Map ||
        (response['errors'] != null &&
            (response['errors'] is! List || response['errors'].isNotEmpty))) {
      throw const FormatException('Account notification GQL rejected');
    }
    final data = response['data'];
    final user = data is Map ? data['currentUser'] : null;
    if (ownerId.isEmpty || user is! Map || user['id'] != ownerId) {
      throw const FormatException('Account notification owner mismatch');
    }
    final feed = user['notifications'];
    final edges = feed is Map ? feed['edges'] : null;
    if (edges is! List) {
      throw const FormatException('Account notification feed missing');
    }
    final result = <TwitchAccountNotification>[];
    for (final edge in edges) {
      final node = edge is Map ? edge['node'] : null;
      if (node is! Map) {
        throw const FormatException('Account notification node missing');
      }
      final category = node['category'];
      final type = node['type'];
      if (category == 'promotions' ||
          type is! String ||
          type.contains('lifecycle')) {
        continue;
      }
      final TwitchAccountNotificationKind kind;
      if (category == 'gift_subscriptions') {
        kind = TwitchAccountNotificationKind.giftSubscription;
      } else if (type.contains('earned_badge')) {
        kind = TwitchAccountNotificationKind.earnedBadge;
      } else {
        continue; // No Drops, ads, streaks or other users' chat events.
      }
      final id = node['id'];
      final body = node['body'];
      final date = node['createdAt'];
      final createdAt = date is String ? DateTime.tryParse(date) : null;
      if (id is! String ||
          id.isEmpty ||
          body is! String ||
          body.trim().isEmpty ||
          createdAt == null) {
        throw const FormatException('Account notification incomplete');
      }
      final image = node['thumbnailURL'];
      final uri = image is String ? Uri.tryParse(image) : null;
      result.add(
        TwitchAccountNotification(
          id: id,
          ownerId: ownerId,
          kind: kind,
          body: body
              .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m[1]!)
              .trim(),
          imageUrl: uri?.scheme == 'https' && uri!.host.isNotEmpty ? image : '',
          createdAt: createdAt,
        ),
      );
    }
    return result;
  }
}
