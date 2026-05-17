// PATCH VERSION: twitch_watch_route_guard_stage135
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
  bool _allowPop = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_pauseSharedPlayer());
    super.dispose();
  }

  @override
  void deactivate() {
    // deactivate catches more route transition cases than dispose, including
    // interactive back gestures where the old route starts leaving before the
    // widget tree is finally torn down.
    unawaited(_pauseSharedPlayer());
    super.deactivate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_pauseSharedPlayer());
    }
  }

  Future<void> _pauseSharedPlayer() async {
    try {
      await TwitchMediaKitPlayerHost.pauseShared();
    } catch (_) {}
  }

  Future<void> _leaveAndPop<T>([T? result]) async {
    if (_leaving) return;
    _leaving = true;

    await _pauseSharedPlayer();

    if (!mounted) return;
    setState(() => _allowPop = true);

    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    Navigator.of(context).maybePop<T>(result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          unawaited(_pauseSharedPlayer());
          return;
        }
        unawaited(_leaveAndPop<Object?>(result));
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
