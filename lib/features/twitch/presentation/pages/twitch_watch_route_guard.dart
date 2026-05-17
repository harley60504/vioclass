// PATCH VERSION: twitch_watch_route_guard_stage139_route_visible_pause
//
// A lightweight route-level guard for WatchPage.
//
// Stage 139:
// - Use Flutter's internal route visibility via RouteObserver / RouteAware.
// - Pause only when the WatchPage route is no longer the visible route inside
//   the app navigator: route popped or another PageRoute pushed on top.
// - Do not pause on desktop window focus changes.
// - Avoid deactivate-based guessing because deactivate can be too broad.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/discovery/twitch_stream_header_metadata.dart';
import '../../services/playback/twitch_media_kit_player_host.dart';
import '../navigation/twitch_route_observer.dart';
import 'twitch_watch_page.dart';

class TwitchWatchRouteGuard extends StatefulWidget {
  final TwitchStreamHeaderMetadata initialMetadata;
  final String? initialChannelLogin;
  final String? initialStreamTitle;
  final String? initialGameName;
  final String? initialLanguage;
  final List<String>? initialTags;
  final bool? initialIsMature;
  final int? initialViewerCount;
  final String? initialProfileImageUrl;

  const TwitchWatchRouteGuard({
    super.key,
    this.initialMetadata = const TwitchStreamHeaderMetadata.empty(),
    this.initialChannelLogin,
    this.initialStreamTitle,
    this.initialGameName,
    this.initialLanguage,
    this.initialTags,
    this.initialIsMature,
    this.initialViewerCount,
    this.initialProfileImageUrl,
  });

  @override
  State<TwitchWatchRouteGuard> createState() => _TwitchWatchRouteGuardState();
}

class _TwitchWatchRouteGuardState extends State<TwitchWatchRouteGuard>
    with RouteAware {
  PageRoute<dynamic>? _subscribedRoute;
  bool _pauseIssuedForCurrentLeave = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is! PageRoute<dynamic>) return;
    if (identical(route, _subscribedRoute)) return;

    if (_subscribedRoute != null) {
      twitchRouteObserver.unsubscribe(this);
    }

    _subscribedRoute = route;
    twitchRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    twitchRouteObserver.unsubscribe(this);
    _pauseBecausePlayerRouteHidden();
    super.dispose();
  }

  @override
  void didPush() {
    _pauseIssuedForCurrentLeave = false;
  }

  @override
  void didPopNext() {
    // WatchPage became visible again after a route above it was popped.
    // Do not auto-play here; user/player state decides whether to resume.
    _pauseIssuedForCurrentLeave = false;
  }

  @override
  void didPushNext() {
    // Another full PageRoute is now above WatchPage, so the player is no longer
    // visible in the app. Dialogs/sheets are not PageRoutes observed here.
    _pauseBecausePlayerRouteHidden();
  }

  @override
  void didPop() {
    // WatchPage itself is being popped.
    _pauseBecausePlayerRouteHidden();
  }

  void _pauseBecausePlayerRouteHidden() {
    if (_pauseIssuedForCurrentLeave) return;
    _pauseIssuedForCurrentLeave = true;
    unawaited(_pauseSharedPlayer());
  }

  Future<void> _pauseSharedPlayer() async {
    try {
      await TwitchMediaKitPlayerHost.pauseShared();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _pauseBecausePlayerRouteHidden();
        }
      },
      child: TwitchWatchPage(
        initialMetadata: widget.initialMetadata,
        initialChannelLogin: widget.initialChannelLogin,
        initialStreamTitle: widget.initialStreamTitle,
        initialGameName: widget.initialGameName,
        initialLanguage: widget.initialLanguage,
        initialTags: widget.initialTags,
        initialIsMature: widget.initialIsMature,
        initialViewerCount: widget.initialViewerCount,
        initialProfileImageUrl: widget.initialProfileImageUrl,
      ),
    );
  }
}
