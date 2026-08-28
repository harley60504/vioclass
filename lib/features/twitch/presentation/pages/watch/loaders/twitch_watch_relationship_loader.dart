//
// Relationship-only WatchPage background loader.
// Keeps follow-state synchronization separate from blocking startup.

import '../../../../api/channel/twitch_private_gql_relationship_api_service_v1.dart';

class TwitchWatchRelationshipLoader {
  final TwitchPrivateGqlRelationshipApiServiceV1 relationshipApi;

  const TwitchWatchRelationshipLoader({required this.relationshipApi});

  Future<TwitchPrivateGqlRelationshipSnapshot> load({
    required String channelLogin,
    String? channelId,
    String? viewerId,
  }) {
    return relationshipApi.fetchRelationship(
      channelLogin: channelLogin,
      targetUserId: channelId,
      viewerUserId: viewerId,
    );
  }
}
