// PATCH VERSION: twitch_watch_port_builders_stage186d
//
// Builder widgets for Watch feature ports.

import 'package:flutter/widgets.dart';

import 'twitch_watch_feature_ports.dart';
import 'twitch_watch_port_scope.dart';

class TwitchWatchPlayerPortBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, TwitchWatchPlayerPort port) builder;

  const TwitchWatchPlayerPortBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, TwitchWatchPortScope.playerOf(context));
  }
}

class TwitchWatchChatPortBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, TwitchWatchChatPort port) builder;

  const TwitchWatchChatPortBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, TwitchWatchPortScope.chatOf(context));
  }
}

class TwitchWatchEmotePortBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, TwitchWatchEmotePort port) builder;

  const TwitchWatchEmotePortBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, TwitchWatchPortScope.emotesOf(context));
  }
}

class TwitchWatchEngagementPortBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, TwitchWatchEngagementPort port) builder;

  const TwitchWatchEngagementPortBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, TwitchWatchPortScope.engagementOf(context));
  }
}

class TwitchWatchRelationshipPortBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, TwitchWatchRelationshipPort port) builder;

  const TwitchWatchRelationshipPortBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, TwitchWatchPortScope.relationshipOf(context));
  }
}
