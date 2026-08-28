import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/playback/twitch_media_kit_player_host.dart';
import '../../mini_player/twitch_mini_player_controller.dart';
import '../../settings/twitch_player_settings_controller.dart';
import '../twitch_watch_page.dart';
import 'twitch_watch_playback_state.dart';
import 'twitch_watch_page_startup.dart';

// ignore_for_file: invalid_use_of_protected_member

extension TwitchWatchPageNavigationMethods on TwitchWatchPageState {
  bool get hasRouteRestorePlayback =>
      restorePlaybackOnDispose?.mediaUri.trim().isNotEmpty == true;

  bool get isPushedMediaPlayback =>
      widget.initialVodVideo != null || widget.initialClip != null;

  Future<void> leaveToMiniPlayer() async {
    if (leavingToMiniPlayer) return;
    leavingToMiniPlayer = true;

    if (isPushedMediaPlayback && hasRouteRestorePlayback) {
      handedOffToMiniPlayer = false;
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
    if (!isPushedMediaPlayback && activeGrowingVodVideo == null) {
      await prepareActiveGrowingVod(
        channel: channelLogin,
        generation: watchLoadGeneration,
      );
    }

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
      try {
        await stopCurrentSession(cancelDeferredTasks: true);
        await playerSession.stopCurrent();
      } catch (_) {}
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
