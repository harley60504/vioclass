import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../../../services/playback/twitch_local_dvr_media_timing_probe.dart';
import '../twitch_watch_feature_ports.dart';
import 'twitch_dvr_transition_mask_controller.dart';

const bool _enableDvrTimingProbe = bool.fromEnvironment(
  'TWITCH_ENABLE_DVR_TIMING_PROBE',
  defaultValue: false,
);

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

    try {
      final session = playerPort.services.playerSession;
      await session.useLowLatencyHlsProfile();
      session.player.setProperty('demuxer-lavf-o', 'live_start_index=-3');
      await playerPort.openLive(
        channelLogin: channelLogin,
        forceOpen: forceOpen,
      );
      await applyPlayerVolume();
      await waitForInitialPlaybackSettle();
    } catch (error) {
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
      final isLoopback = nextUri.startsWith('http://127.0.0.1:');
      final isLocalDvrSnapshot =
          startPosition != null &&
          isLoopback &&
          nextUri.contains('/playlist.m3u8?v=');
      final isLocalDvrStream =
          startPosition != null &&
          isLoopback &&
          nextUri.contains('/stream.ts?v=');
      final isLocalDvr = isLocalDvrSnapshot || isLocalDvrStream;

      // A raw sequential DVR stream must not be reopened by the old deferred
      // HLS seek/retry path. Media.start handles the intra-segment offset while
      // the bridge keeps one continuous upstream segment pump.
      final shouldDeferInitialSeek =
          startPosition != null &&
          !isLocalDvrStream &&
          (deferInitialSeek || isLocalDvrSnapshot);

      if (isLocalDvrStream) {
        // Stop any near-live stable-router pump before the independent DVR TS
        // source opens. This prevents an old replay request from continuing to
        // consume Twitch bandwidth beside the new sequential downloader.
        await playerPort.runtime.proxy?.interruptPlaybackStream();
      }

      // Keep the shared mpv player on the low-latency/no-cache profile. The DVR
      // bridge now owns buffering and upstream ordering itself.
      await session.useLowLatencyHlsProfile();
      await session.ensureReady();
      session.player.setProperty(
        'demuxer-lavf-o',
        isLocalDvrSnapshot ? 'live_start_index=0' : 'live_start_index=-3',
      );
      if (isLocalDvr) {
        dvrTransitionGeneration =
            TwitchDvrTransitionMaskController.instance.begin();
      }

      final hrSeekDemuxerOffset = isLocalDvrStream
          ? Duration.zero
          : isLocalDvrSnapshot
          ? TwitchLocalDvrMediaTimingProbe.cachedSuggestedDemuxerOffset
          : const Duration(seconds: 2);

      if (startPosition != null) {
        session.player.setProperty(
          'hr-seek',
          isLocalDvrStream
              ? 'no'
              : shouldDeferInitialSeek && isLocalDvrSnapshot
              ? 'no'
              : 'yes',
        );
        session.player.setProperty(
          'hr-seek-demuxer-offset',
          _seconds(hrSeekDemuxerOffset),
        );
      }

      if (isLocalDvrStream) {
        debugPrint(
          '[TwitchPlayer] sequential DVR start '
          'target=${_seconds(startPosition!)}s '
          'strategy=media-start-single-stream',
        );
      } else if (isLocalDvrSnapshot) {
        debugPrint(
          '[TwitchPlayer] rolling DVR precise start '
          'target=${_seconds(startPosition!)}s '
          'hrBackoff=${_seconds(hrSeekDemuxerOffset)}s '
          'liveStartIndex=0 '
          'strategy=open-then-seek-no-wait '
          'probe=${_enableDvrTimingProbe ? "async" : "disabled"}',
        );
      }

      final openStopwatch = Stopwatch()..start();
      if (shouldDeferInitialSeek) {
        final seekTarget = startPosition!;
        final sourceOpenStopwatch = Stopwatch()..start();
        await session.openOrResume(
          uri: nextUri,
          play: false,
          forceOpen: forceOpen,
        );
        sourceOpenStopwatch.stop();

        var seekWaitMs = 0;
        if (!isLocalDvrSnapshot) {
          final seekWaitStopwatch = Stopwatch()..start();
          await _waitForSeekableMedia(session.player, seekTarget);
          seekWaitStopwatch.stop();
          seekWaitMs = seekWaitStopwatch.elapsedMilliseconds;
        }

        if (isLocalDvrSnapshot) {
          session.player.setProperty('hr-seek', 'yes');
          session.player.setProperty(
            'hr-seek-demuxer-offset',
            _seconds(hrSeekDemuxerOffset),
          );
          debugPrint(
            '[PlaybackLatency] '
            'dvrSourceOpen=${sourceOpenStopwatch.elapsedMilliseconds}ms '
            'dvrSeekWait=${seekWaitMs}ms '
            'target=${_seconds(seekTarget)}s '
            'duration=${_seconds(session.player.state.duration)}s',
          );
        } else {
          debugPrint(
            '[TwitchPlayer] deferred precise seek '
            'target=${_seconds(seekTarget)}s '
            'duration=${_seconds(session.player.state.duration)}s',
          );
        }

        final preciseSeekStopwatch = Stopwatch()..start();
        await session.player.seek(seekTarget);
        preciseSeekStopwatch.stop();
        if (play) {
          await session.player.play();
        }
        if (isLocalDvrSnapshot) {
          debugPrint(
            '[PlaybackLatency] '
            'dvrPreciseSeek=${preciseSeekStopwatch.elapsedMilliseconds}ms '
            'target=${_seconds(seekTarget)}s',
          );
          if (play) {
            await _ensureDvrSeekLanded(
              player: session.player,
              target: seekTarget,
            );
          }
          final transitionGeneration = dvrTransitionGeneration;
          if (transitionGeneration != null) {
            if (play) {
              unawaited(
                TwitchDvrTransitionMaskController.instance.revealWhenReady(
                  player: session.player,
                  target: seekTarget,
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
      } else {
        await session.openOrResume(
          uri: nextUri,
          play: play,
          forceOpen: forceOpen,
          startPosition: startPosition,
        );

        if (isLocalDvrStream) {
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
      }
      openStopwatch.stop();

      if (isLocalDvrStream) {
        debugPrint(
          '[PlaybackLatency] dvrSequentialStartup=${openStopwatch.elapsedMilliseconds}ms '
          'target=${_seconds(startPosition!)}s',
        );
      } else if (isLocalDvrSnapshot) {
        debugPrint(
          '[PlaybackLatency] dvrStartupTotal=${openStopwatch.elapsedMilliseconds}ms '
          'target=${_seconds(startPosition!)}s',
        );
        if (_enableDvrTimingProbe) {
          unawaited(
            _probeDvrTimingAfterOpen(
              playlistUrl: nextUri,
              startPosition: startPosition!,
            ),
          );
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

  Future<void> _ensureDvrSeekLanded({
    required Player player,
    required Duration target,
  }) async {
    const tolerance = Duration(milliseconds: 650);
    const clockStartThreshold = Duration(milliseconds: 80);
    const firstRetryAfter = Duration(milliseconds: 140);
    const retrySpacing = Duration(milliseconds: 180);
    const timeout = Duration(milliseconds: 900);
    const maxRetries = 2;

    final stopwatch = Stopwatch()..start();
    var retries = 0;
    var nextRetryAt = firstRetryAfter;

    bool landed() {
      final deltaUs =
          player.state.position.inMicroseconds - target.inMicroseconds;
      final distanceUs = deltaUs < 0 ? -deltaUs : deltaUs;
      return distanceUs <= tolerance.inMicroseconds;
    }

    while (stopwatch.elapsed < timeout) {
      if (landed()) {
        debugPrint(
          '[PlaybackLatency] dvrSeekLanding=${stopwatch.elapsedMilliseconds}ms '
          'result=landed retries=$retries '
          'target=${_seconds(target)}s '
          'position=${_seconds(player.state.position)}s',
        );
        return;
      }

      final position = player.state.position;
      final demuxerIsMoving =
          position >= clockStartThreshold && !player.state.buffering;
      if (retries < maxRetries &&
          stopwatch.elapsed >= nextRetryAt &&
          (demuxerIsMoving ||
              stopwatch.elapsed >= const Duration(milliseconds: 260))) {
        retries++;
        final before = player.state.position;
        final retryStopwatch = Stopwatch()..start();
        await player.seek(target);
        retryStopwatch.stop();
        debugPrint(
          '[PlaybackLatency] dvrSeekRetry=$retries '
          'call=${retryStopwatch.elapsedMilliseconds}ms '
          'elapsed=${stopwatch.elapsedMilliseconds}ms '
          'target=${_seconds(target)}s '
          'before=${_seconds(before)}s '
          'after=${_seconds(player.state.position)}s '
          'buffering=${player.state.buffering}',
        );
        nextRetryAt = stopwatch.elapsed + retrySpacing;
      }

      await Future<void>.delayed(const Duration(milliseconds: 25));
    }

    debugPrint(
      '[PlaybackLatency] dvrSeekLanding=${stopwatch.elapsedMilliseconds}ms '
      'result=timeout retries=$retries '
      'target=${_seconds(target)}s '
      'position=${_seconds(player.state.position)}s '
      'buffering=${player.state.buffering}',
    );
  }

  Future<void> _probeDvrTimingAfterOpen({
    required String playlistUrl,
    required Duration startPosition,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final stopwatch = Stopwatch()..start();
    final probe = await TwitchLocalDvrMediaTimingProbe.probe(
      playlistUrl: playlistUrl,
      startPosition: startPosition,
    );
    stopwatch.stop();
    if (probe == null) {
      debugPrint(
        '[TsSeekIndex] unavailable probeMs=${stopwatch.elapsedMilliseconds} '
        'learnedBackoff=${_seconds(TwitchLocalDvrMediaTimingProbe.cachedSuggestedDemuxerOffset)}s',
      );
      return;
    }

    final timing = probe.timing;
    debugPrint(
      '[TsSeekIndex] segment=${probe.segmentIndex} '
      'targetOffset=${_seconds(probe.targetOffset)}s '
      'firstPts=${timing.firstPts90k ?? -1} '
      'lastPts=${timing.lastPts90k ?? -1} '
      'firstPcr=${timing.firstPcr27m ?? -1} '
      'lastPcr=${timing.lastPcr27m ?? -1} '
      'keyframes=${timing.keyframePts90k.length} '
      'keyframeOffset=${probe.keyframeOffset == null ? '-' : '${_seconds(probe.keyframeOffset!)}s'} '
      'decodeLead=${probe.decodeLead == null ? '-' : '${_seconds(probe.decodeLead!)}s'} '
      'seekBackoff=${_seconds(probe.suggestedDemuxerOffset)}s '
      'learnedBackoff=${_seconds(TwitchLocalDvrMediaTimingProbe.cachedSuggestedDemuxerOffset)}s '
      'probeMs=${stopwatch.elapsedMilliseconds}',
    );
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
