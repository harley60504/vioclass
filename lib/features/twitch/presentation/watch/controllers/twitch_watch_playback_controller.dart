import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../twitch_watch_feature_ports.dart';
import 'twitch_dvr_transition_mask_controller.dart';

class TwitchWatchPlaybackController extends ChangeNotifier {
  final TwitchWatchPlayerPort playerPort;
  final Future<void> Function() applyPlayerVolume;
  final Future<void> Function() waitForInitialPlaybackSettle;

  bool loadingPlayer = false;
  String? playerError;

  TwitchWatchPlaybackController({
    required this.playerPort,
    required this.applyPlayerVolume,
    required this.waitForInitialPlaybackSettle,
  });

  Future<void> loadPlayer({
    required String channelLogin,
    required bool enabled,
    bool forceOpen = true,
  }) async {
    if (!enabled) {
      loadingPlayer = false;
      playerError = null;
      notifyListeners();
      return;
    }

    loadingPlayer = true;
    playerError = null;
    notifyListeners();

    int? liveTransitionGeneration;
    try {
      final session = playerPort.services.playerSession;
      final previousMediaUri = session.currentMediaUri?.trim();
      final isReplacingVisiblePlayback =
          forceOpen && previousMediaUri != null && previousMediaUri.isNotEmpty;
      if (isReplacingVisiblePlayback) {
        liveTransitionGeneration =
            TwitchDvrTransitionMaskController.instance.begin();
      }

      await session.useLowLatencyHlsProfile();
      session.player.setProperty('demuxer-lavf-o', 'live_start_index=-3');
      await playerPort.openLive(
        channelLogin: channelLogin,
        forceOpen: forceOpen,
      );

      final transitionGeneration = liveTransitionGeneration;
      if (transitionGeneration != null) {
        unawaited(
          TwitchDvrTransitionMaskController.instance
              .revealWhenLivePlaybackAdvances(
                player: session.player,
                generation: transitionGeneration,
              ),
        );
      }

      await applyPlayerVolume();
      // Player.open() has already handed the stream to mpv. Do not hold the
      // watch-page loading state for the optional first-frame settle window.
      // The warm player surface can become visible immediately while settle
      // continues in the background.
      unawaited(waitForInitialPlaybackSettle().catchError((_) {}));
    } catch (error) {
      final transitionGeneration = liveTransitionGeneration;
      if (transitionGeneration != null) {
        TwitchDvrTransitionMaskController.instance.cancel(
          transitionGeneration,
          reason: 'live-open-error',
        );
      }
      playerError = error.toString();
      notifyListeners();
      rethrow;
    } finally {
      loadingPlayer = false;
      notifyListeners();
    }
  }

  Future<void> openMedia({
    required String uri,
    bool play = true,
    bool forceOpen = true,
    Duration? startPosition,
    bool deferInitialSeek = false,
    bool waitForSettle = false,
    bool showLoading = false,
  }) async {
    if (showLoading) {
      loadingPlayer = true;
      notifyListeners();
    }
    playerError = null;
    int? dvrTransitionGeneration;

    try {
      final nextUri = uri.trim();
      final session = playerPort.services.playerSession;
      final isSequentialDvr =
          startPosition != null &&
          nextUri.startsWith('http://127.0.0.1:') &&
          nextUri.contains('/stream.ts?v=');
      final shouldDeferInitialSeek =
          startPosition != null && deferInitialSeek && !isSequentialDvr;

      if (isSequentialDvr) {
        // The archive DVR owns an independent sequential TS pump. Disconnect
        // the stable LIVE/near-live response first so only one media flow keeps
        // consuming Twitch bandwidth.
        await playerPort.runtime.proxy?.interruptPlaybackStream();
      }

      // Keep archive DVR on its readahead/cache profile. Previously the caller
      // selected liveDvr and openMedia immediately overwrote it with the
      // low-latency LIVE profile, adding property churn and using the wrong
      // buffering policy for timeline seeks.
      if (isSequentialDvr) {
        await session.useLiveDvrHlsCacheProfile();
      } else {
        await session.useLowLatencyHlsProfile();
      }

      if (!isSequentialDvr) {
        session.player.setProperty('demuxer-lavf-o', 'live_start_index=-3');
      }

      if (isSequentialDvr) {
        dvrTransitionGeneration =
            TwitchDvrTransitionMaskController.instance.begin();
      }

      if (startPosition != null) {
        session.player.setProperty('hr-seek', isSequentialDvr ? 'no' : 'yes');
        session.player.setProperty(
          'hr-seek-demuxer-offset',
          isSequentialDvr ? '0.000' : '2.000',
        );
      }

      if (isSequentialDvr) {
        debugPrint(
          '[TwitchPlayer] sequential DVR start '
          'target=${_seconds(startPosition!)}s '
          'strategy=media-start-single-stream',
        );
      }

      final openStopwatch = Stopwatch()..start();
      if (shouldDeferInitialSeek) {
        final seekTarget = startPosition!;
        await session.openOrResume(
          uri: nextUri,
          play: false,
          forceOpen: forceOpen,
        );
        await _waitForSeekableMedia(session.player, seekTarget);
        await session.player.seek(seekTarget);
        if (play) await session.player.play();
      } else {
        await session.openOrResume(
          uri: nextUri,
          play: play,
          forceOpen: forceOpen,
          startPosition: startPosition,
        );
      }
      openStopwatch.stop();

      if (isSequentialDvr) {
        debugPrint(
          '[PlaybackLatency] '
          'dvrSequentialStartup=${openStopwatch.elapsedMilliseconds}ms '
          'target=${_seconds(startPosition!)}s',
        );

        final transitionGeneration = dvrTransitionGeneration;
        if (transitionGeneration != null) {
          if (play) {
            unawaited(
              TwitchDvrTransitionMaskController.instance.revealWhenReady(
                player: session.player,
                target: startPosition!,
                generation: transitionGeneration,
              ),
            );
          } else {
            TwitchDvrTransitionMaskController.instance.cancel(
              transitionGeneration,
              reason: 'paused',
            );
          }
        }
      }

      await applyPlayerVolume();
      if (waitForSettle) {
        await waitForInitialPlaybackSettle();
      }
    } catch (error) {
      final transitionGeneration = dvrTransitionGeneration;
      if (transitionGeneration != null) {
        TwitchDvrTransitionMaskController.instance.cancel(
          transitionGeneration,
          reason: 'open-error',
        );
      }
      playerError = error.toString();
      notifyListeners();
      rethrow;
    } finally {
      if (showLoading) {
        loadingPlayer = false;
      }
      notifyListeners();
    }
  }

  Future<void> _waitForSeekableMedia(Player player, Duration target) async {
    final deadline = DateTime.now().add(const Duration(milliseconds: 900));
    while (DateTime.now().isBefore(deadline)) {
      final duration = player.state.duration;
      if (duration > Duration.zero &&
          (duration >= target || duration.inMilliseconds > 1000)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }

  bool isCurrentPlaybackSource(String uri) {
    final currentUri = playerPort.services.playerSession.currentMediaUri
        ?.trim();
    final nextUri = uri.trim();
    return currentUri != null && currentUri.isNotEmpty && currentUri == nextUri;
  }

  void setError(String? message) {
    playerError = message;
    notifyListeners();
  }

  void resetError() {
    playerError = null;
    notifyListeners();
  }

  String _seconds(Duration value) =>
      (value.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(3);
}