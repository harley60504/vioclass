// PATCH VERSION: twitch_watch_route_guard_stage136_non_blocking_pop
//
// A lightweight route-level guard for WatchPage.
//
// Why this exists:
// - UI back buttons are not enough. Android system back, predictive-back
//   gestures, desktop route pops, and future navigation paths can bypass the
//   player overlay's back button.
// - WatchPage keeps media_kit alive for faster re-entry, so leaving the route
//   must pause audio at the route boundary instead of waiting for player
//   disposal.
//
// Stage 136:
// - Do not block the first pop. Blocking PopScope with canPop=false caused the
//   first Android back gesture to only pause/unlock and the second gesture to
//   actually return.
// - Let Navigator pop normally, and pause the shared player from PopScope,
//   deactivate, dispose, and app lifecycle callbacks.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/discovery/twitch_stream_header_metadata.dart';
import '../../services/playback/twitch_media_kit_player_host.dart';
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
    with WidgetsBindingObserver {
  bool _pauseIssued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pauseSharedPlayerOnce();
    super.dispose();
  }

  @override
  void deactivate() {
    // deactivate catches more route transition cases than dispose, including
    // interactive back gestures where the old route starts leaving before the
    // widget tree is finally torn down.
    _pauseSharedPlayerOnce();
    super.deactivate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _pauseSharedPlayerOnce();
    }
  }

  void _pauseSharedPlayerOnce() {
    if (_pauseIssued) return;
    _pauseIssued = true;
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
        // Let the route leave on the first back action. Audio is paused as soon
        // as Flutter reports the pop attempt; deactivate/dispose are additional
        // route-lifecycle safety nets.
        _pauseSharedPlayerOnce();
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
