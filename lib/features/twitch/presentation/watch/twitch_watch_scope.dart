// PATCH VERSION: twitch_watch_scope_stage186b
//
// Watch composition scope.
//
// This is the bridge from the old WatchPage-as-API-gateway style to the new
// component-owned interface style. Player / Chat / Emote / Engagement /
// Relationship UI can read their own service group from this scope instead of
// receiving every API operation as a WatchPage callback.

import 'package:flutter/widgets.dart';

import '../../services/watch/twitch_watch_feature_services.dart';
import '../../services/watch/twitch_watch_services.dart';

class TwitchWatchScope extends InheritedWidget {
  final TwitchWatchServices services;

  const TwitchWatchScope({
    super.key,
    required this.services,
    required super.child,
  });

  static TwitchWatchServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TwitchWatchScope>();
    assert(scope != null, 'TwitchWatchScope was not found in the widget tree.');
    return scope!.services;
  }

  static TwitchWatchServices read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<TwitchWatchScope>();
    final widget = element?.widget;
    assert(widget is TwitchWatchScope, 'TwitchWatchScope was not found in the widget tree.');
    return (widget as TwitchWatchScope).services;
  }

  static TwitchWatchCoreServices coreOf(BuildContext context) => of(context).core;
  static TwitchWatchAuthServices authOf(BuildContext context) => of(context).auth;
  static TwitchWatchPlayerServices playerOf(BuildContext context) => of(context).player;
  static TwitchWatchChatServices chatOf(BuildContext context) => of(context).chat;
  static TwitchWatchEmoteServices emotesOf(BuildContext context) => of(context).emotes;
  static TwitchWatchEngagementServices engagementOf(BuildContext context) => of(context).engagement;
  static TwitchWatchRelationshipServices relationshipOf(BuildContext context) => of(context).relationship;

  static TwitchWatchCoreServices readCore(BuildContext context) => read(context).core;
  static TwitchWatchAuthServices readAuth(BuildContext context) => read(context).auth;
  static TwitchWatchPlayerServices readPlayer(BuildContext context) => read(context).player;
  static TwitchWatchChatServices readChat(BuildContext context) => read(context).chat;
  static TwitchWatchEmoteServices readEmotes(BuildContext context) => read(context).emotes;
  static TwitchWatchEngagementServices readEngagement(BuildContext context) => read(context).engagement;
  static TwitchWatchRelationshipServices readRelationship(BuildContext context) => read(context).relationship;

  @override
  bool updateShouldNotify(covariant TwitchWatchScope oldWidget) {
    return !identical(services, oldWidget.services);
  }
}
