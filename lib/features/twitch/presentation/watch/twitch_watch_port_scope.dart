// PATCH VERSION: twitch_watch_port_scope_stage186d
//
// Watch feature port scope.
//
// Use this for UI-facing dependencies. Services remain the composition root;
// ports are the narrow interfaces feature widgets should consume.

import 'package:flutter/widgets.dart';

import 'twitch_watch_feature_ports.dart';

class TwitchWatchPortScope extends InheritedWidget {
  final TwitchWatchFeaturePorts ports;

  const TwitchWatchPortScope({
    super.key,
    required this.ports,
    required super.child,
  });

  static TwitchWatchFeaturePorts of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TwitchWatchPortScope>();
    assert(
      scope != null,
      'TwitchWatchPortScope was not found in the widget tree.',
    );
    return scope!.ports;
  }

  static TwitchWatchFeaturePorts read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<TwitchWatchPortScope>();
    final widget = element?.widget;
    assert(
      widget is TwitchWatchPortScope,
      'TwitchWatchPortScope was not found in the widget tree.',
    );
    return (widget as TwitchWatchPortScope).ports;
  }

  static TwitchWatchPlayerPort playerOf(BuildContext context) =>
      of(context).player;
  static TwitchWatchChatPort chatOf(BuildContext context) => of(context).chat;
  static TwitchWatchEmotePort emotesOf(BuildContext context) =>
      of(context).emotes;
  static TwitchWatchEngagementPort engagementOf(BuildContext context) =>
      of(context).engagement;
  static TwitchWatchRelationshipPort relationshipOf(BuildContext context) =>
      of(context).relationship;

  static TwitchWatchPlayerPort readPlayer(BuildContext context) =>
      read(context).player;
  static TwitchWatchChatPort readChat(BuildContext context) =>
      read(context).chat;
  static TwitchWatchEmotePort readEmotes(BuildContext context) =>
      read(context).emotes;
  static TwitchWatchEngagementPort readEngagement(BuildContext context) =>
      read(context).engagement;
  static TwitchWatchRelationshipPort readRelationship(BuildContext context) =>
      read(context).relationship;

  @override
  bool updateShouldNotify(covariant TwitchWatchPortScope oldWidget) {
    return !identical(ports, oldWidget.ports);
  }
}
