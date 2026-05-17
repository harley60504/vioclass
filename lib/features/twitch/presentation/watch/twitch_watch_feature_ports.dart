// PATCH VERSION: twitch_watch_feature_ports_stage186b
//
// Feature-facing ports for Watch composition.
//
// A port is intentionally thinner than a controller. It groups the minimum
// service APIs a UI feature needs so each component can depend on its own
// interface instead of depending on TwitchWatchPage callbacks.

import '../../services/watch/twitch_watch_feature_services.dart';
import '../../services/watch/twitch_watch_services.dart';

class TwitchWatchPlayerPort {
  final TwitchWatchPlayerServices services;

  const TwitchWatchPlayerPort({required this.services});
}

class TwitchWatchChatPort {
  final TwitchWatchChatServices services;

  const TwitchWatchChatPort({required this.services});
}

class TwitchWatchEmotePort {
  final TwitchWatchEmoteServices services;

  const TwitchWatchEmotePort({required this.services});
}

class TwitchWatchEngagementPort {
  final TwitchWatchEngagementServices services;

  const TwitchWatchEngagementPort({required this.services});
}

class TwitchWatchRelationshipPort {
  final TwitchWatchRelationshipServices services;

  const TwitchWatchRelationshipPort({required this.services});
}

class TwitchWatchFeaturePorts {
  final TwitchWatchPlayerPort player;
  final TwitchWatchChatPort chat;
  final TwitchWatchEmotePort emotes;
  final TwitchWatchEngagementPort engagement;
  final TwitchWatchRelationshipPort relationship;

  const TwitchWatchFeaturePorts({
    required this.player,
    required this.chat,
    required this.emotes,
    required this.engagement,
    required this.relationship,
  });

  factory TwitchWatchFeaturePorts.fromServices(TwitchWatchServices services) {
    return TwitchWatchFeaturePorts(
      player: TwitchWatchPlayerPort(services: services.player),
      chat: TwitchWatchChatPort(services: services.chat),
      emotes: TwitchWatchEmotePort(services: services.emotes),
      engagement: TwitchWatchEngagementPort(services: services.engagement),
      relationship: TwitchWatchRelationshipPort(services: services.relationship),
    );
  }
}
