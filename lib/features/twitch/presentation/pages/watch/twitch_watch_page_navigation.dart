import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/playback/twitch_media_kit_player_host.dart';
import '../../mini_player/twitch_mini_player_controller.dart';
import '../../settings/twitch_player_settings_controller.dart';
import '../twitch_watch_page.dart';
import 'twitch_watch_playback_state.dart';

// ignore_for_file: invalid_use_of_protected_member

extension TwitchWatchPageNavigationMethods on TwitchWatchPageState {
  bool get hasRouteRestorePlayback =>
      restorePlaybackOnDispose?.mediaUri.trim().isNotEmpty == true;

  bool get isPushedMediaPlayback =>
      widget.initialVodVideo != null || widget.initialClip != null;

  bool get shouldRestorePreviousPlaybackOnPop =>
      isPushedMediaPlayback && hasRouteRestorePlayback;

  Future<void> leaveToMiniPlayer() async {
    if (leavingToMiniPlayer) return;
    leavingToMiniPlayer = true;

    if (shouldRestorePreviousPlaybackOnPop) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    await leaveWatchPageToHome(respectMiniPreference: true, popToRoot: false);
  }

  Future<void> returnToHome() async {
    if (leavingToMiniPlayer) return;
    leavingToMiniPlayer = true;
    await leaveWatchPageToHome(respectMiniPreference: true, popToRoot: true);
  }

  Future<void> leaveWatchPageToHome({
    required bool respectMiniPreference,
    required bool popToRoot,
  }) async {
    // Do not block route navigation on a network-backed growing-VOD lookup.
    // The currently playing live stream is already enough to hand off to the
    // mini player. DVR metadata can be reacquired when the watch page is opened
    // again, while the visible route transition stays immediate.
    final snapshot = buildPlaybackSnapshot();
    if (snapshot == null) {
      handedOffToMiniPlayer = false;
      TwitchMiniPlayerController.instance.close();
      unawaited(TwitchMediaKitPlayerHost.pauseShared().catchError((_) {}));
      popWatchPage(popToRoot: popToRoot);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final shouldKeepMini =
        !respectMiniPreference ||
        (prefs.getBool(
              TwitchPlayerSettingsController.homeKeepsMiniPlayerPreferenceKey,
            ) ??
            true);

    if (!shouldKeepMini) {
      handedOffToMiniPlayer = false;
      TwitchMiniPlayerController.instance.close();
      // The route's dispose path already releases the runtime and pauses the
      // shared player. Pop first so teardown work cannot hold the transition.
      popWatchPage(popToRoot: popToRoot);
      return;
    }

    handedOffToMiniPlayer = true;
    TwitchMediaKitPlayerHost.keepPlayingWithoutSession(snapshot.mediaUri);
    TwitchMiniPlayerController.instance.showPlayback(
      playback: snapshot,
      playerRuntime: watchPorts.player.runtime,
    );
    popWatchPage(popToRoot: popToRoot);
  }

  void popWatchPage({required bool popToRoot}) {
    if (!mounted) return;
    if (popToRoot) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pop();
    }
  }
}
