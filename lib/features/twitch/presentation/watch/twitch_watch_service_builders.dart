// PATCH VERSION: twitch_watch_service_builders_stage186b
//
// Builder widgets that expose one feature service group at a time.
//
// These are intentionally tiny adapters. They let the next migration step wrap
// PlayerArea / ChatPanel / Sheets with local feature dependencies without
// forcing TwitchWatchPage to pass every API callback manually.

import 'package:flutter/widgets.dart';

import '../../services/watch/twitch_watch_feature_services.dart';
import 'twitch_watch_scope.dart';

class TwitchWatchPlayerServicesBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, TwitchWatchPlayerServices services)
      builder;

  const TwitchWatchPlayerServicesBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, TwitchWatchScope.playerOf(context));
  }
}

class TwitchWatchChatServicesBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, TwitchWatchChatServices services)
      builder;

  const TwitchWatchChatServicesBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, TwitchWatchScope.chatOf(context));
  }
}

class TwitchWatchEmoteServicesBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, TwitchWatchEmoteServices services)
      builder;

  const TwitchWatchEmoteServicesBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, TwitchWatchScope.emotesOf(context));
  }
}

class TwitchWatchEngagementServicesBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, TwitchWatchEngagementServices services)
      builder;

  const TwitchWatchEngagementServicesBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, TwitchWatchScope.engagementOf(context));
  }
}

class TwitchWatchRelationshipServicesBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, TwitchWatchRelationshipServices services)
      builder;

  const TwitchWatchRelationshipServicesBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, TwitchWatchScope.relationshipOf(context));
  }
}
