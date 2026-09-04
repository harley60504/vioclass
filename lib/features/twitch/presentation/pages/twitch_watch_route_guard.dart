//
// A lightweight route-level guard for WatchPage.
//
// - Use Flutter's internal route visibility via RouteObserver / RouteAware.
// - Pause only when the WatchPage route itself is popped.
// - Do not pause on desktop window focus changes.
// - Avoid deactivate-based guessing because deactivate can be too broad.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/discovery/twitch_stream_header_metadata.dart';
import '../../models/discovery/twitch_live_stream.dart';
import '../../services/discovery/twitch_discovery_service.dart';
import '../../services/playback/twitch_media_kit_player_host.dart';
import '../../services/playback/twitch_playlist_player_runtime.dart';
import '../navigation/twitch_route_observer.dart';
import '../mini_player/twitch_mini_player_controller.dart';
import 'twitch_watch_page.dart';
import 'watch/twitch_watch_playback_state.dart';

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
  final TwitchFollowedChannel? initialOfflineChannel;
  final TwitchDiscoveryService? initialDiscoveryService;
  final bool initialOfflineFallbackAllowed;
  final TwitchChannelVideo? initialActiveDvrVideo;
  final TwitchChannelVideo? initialVodVideo;
  final TwitchChannelClip? initialClip;
  final double? initialVodReplayRatio;
  final bool initialVodPlaybackOnly;
  final bool initialPreferVodReplayChat;
  final bool initialReuseCurrentPlayback;
  final TwitchPlaylistPlayerRuntime? initialPlayerRuntime;
  final bool? initialKnownFollowing;

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
    this.initialOfflineChannel,
    this.initialDiscoveryService,
    this.initialOfflineFallbackAllowed = false,
    this.initialActiveDvrVideo,
    this.initialVodVideo,
    this.initialClip,
    this.initialVodReplayRatio,
    this.initialVodPlaybackOnly = false,
    this.initialPreferVodReplayChat = false,
    this.initialReuseCurrentPlayback = false,
    this.initialPlayerRuntime,
    this.initialKnownFollowing,
  });

  @override
  State<TwitchWatchRouteGuard> createState() => _TwitchWatchRouteGuardState();
}

class _TwitchWatchRouteGuardState extends State<TwitchWatchRouteGuard>
    with RouteAware {
  final GlobalKey<TwitchWatchPageState> _watchKey =
      GlobalKey<TwitchWatchPageState>();
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
    _pauseIssuedForCurrentLeave = false;
    final watchState = _watchKey.currentState;
    if (watchState != null) {
      unawaited(watchState.reconcileVisibleRoutePlayback());
    }
  }

  @override
  void didPushNext() {
    // Another PageRoute can be a VOD/Clip WatchPage using the same shared
    // player. Keep the player alive and let the top route decide playback.
    _pauseIssuedForCurrentLeave = false;
  }

  @override
  void didPop() {
    // WatchPage itself is being popped.
    _pauseBecausePlayerRouteHidden();
  }

  void _pauseBecausePlayerRouteHidden() {
    if (_pauseIssuedForCurrentLeave) return;
    if (TwitchMiniPlayerController.instance.isActiveMediaUri(
      TwitchMediaKitPlayerHost.currentMediaUri,
    )) {
      return;
    }
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
        key: _watchKey,
        initialMetadata: widget.initialMetadata,
        initialChannelLogin: widget.initialChannelLogin,
        initialStreamTitle: widget.initialStreamTitle,
        initialGameName: widget.initialGameName,
        initialLanguage: widget.initialLanguage,
        initialTags: widget.initialTags,
        initialIsMature: widget.initialIsMature,
        initialViewerCount: widget.initialViewerCount,
        initialProfileImageUrl: widget.initialProfileImageUrl,
        initialOfflineChannel: widget.initialOfflineChannel,
        initialDiscoveryService: widget.initialDiscoveryService,
        initialOfflineFallbackAllowed: widget.initialOfflineFallbackAllowed,
        initialActiveDvrVideo: widget.initialActiveDvrVideo,
        initialVodVideo: widget.initialVodVideo,
        initialClip: widget.initialClip,
        initialVodReplayRatio: widget.initialVodReplayRatio,
        initialVodPlaybackOnly: widget.initialVodPlaybackOnly,
        initialPreferVodReplayChat: widget.initialPreferVodReplayChat,
        initialReuseCurrentPlayback: widget.initialReuseCurrentPlayback,
        initialPlayerRuntime: widget.initialPlayerRuntime,
        initialKnownFollowing: widget.initialKnownFollowing,
      ),
    );
  }
}
