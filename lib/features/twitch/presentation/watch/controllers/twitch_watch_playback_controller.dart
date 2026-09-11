import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../../../services/playback/twitch_local_dvr_media_timing_probe.dart';
import '../twitch_watch_feature_ports.dart';

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

    try {
      final nextUri = uri.trim();
      final session = playerPort.services.playerSession;
      final isLocalDvrSnapshot =
          startPosition != null &&
          nextUri.startsWith('http://127.0.0.1:') &&
          nextUri.contains('/playlist.m3u8?v=');
      final shouldDeferInitialSeek =
          startPosition != null && (deferInitialSeek || isLocalDvrSnapshot);

      // Do not block Player.open on a remote TS download just to discover GOP
      // geometry. The previous successful probes teach a safe backoff for later
      // seeks; Twitch normally keeps that GOP cadence stable for a rendition.
      final hrSeekDemuxerOffset = isLocalDvrSnapshot
          ? TwitchLocalDvrMediaTimingProbe.cachedSuggestedDemuxerOffset
          : const Duration(seconds: 2);

      if (startPosition != null) {
        await session.ensureReady();
        // A local frozen DVR snapshot is already trimmed to the target segment
        // (or one preroll segment). Do not combine source open + Media(start:)
        // + high-resolution seek: on Android that can cause the H.264 decoder
        // to be created, flushed and recreated before the first useful frame.
        // Open the source at zero first, then enable precise seeking once the
        // demuxer has described the finite VOD snapshot.
        session.player.setProperty(
          'hr-seek',
          shouldDeferInitialSeek && isLocalDvrSnapshot ? 'no' : 'yes',
        );
        session.player.setProperty(
          'hr-seek-demuxer-offset',
          _seconds(hrSeekDemuxerOffset),
        );
      }

      if (isLocalDvrSnapshot) {
        debugPrint(
          '[TwitchPlayer] VOD snapshot precise start '
          'target=${_seconds(startPosition!)}s '
          'hrBackoff=${_seconds(hrSeekDemuxerOffset)}s '
          'strategy=open-then-seek '
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

        final seekWaitStopwatch = Stopwatch()..start();
        await _waitForSeekableMedia(session.player, seekTarget);
        seekWaitStopwatch.stop();

        if (isLocalDvrSnapshot) {
          session.player.setProperty('hr-seek', 'yes');
          session.player.setProperty(
            'hr-seek-demuxer-offset',
            _seconds(hrSeekDemuxerOffset),
          );
          debugPrint(
            '[PlaybackLatency] '
            'dvrSourceOpen=${sourceOpenStopwatch.elapsedMilliseconds}ms '
            'dvrSeekWait=${seekWaitStopwatch.elapsedMilliseconds}ms '
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
        }
      } else {
        await session.openOrResume(
          uri: nextUri,
          play: play,
          forceOpen: forceOpen,
          startPosition: startPosition,
        );
      }
      openStopwatch.stop();

      if (isLocalDvrSnapshot) {
        debugPrint(
          '[PlaybackLatency] dvrStartupTotal=${openStopwatch.elapsedMilliseconds}ms '
          'target=${_seconds(startPosition!)}s',
        );
        // The TS timing probe downloads the target segment again. Keep it off
        // during normal playback so it cannot compete with mpv for startup I/O.
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

  Future<void> _probeDvrTimingAfterOpen({
    required String playlistUrl,
    required Duration startPosition,
  }) async {
    // A short delay gives mpv first access to the snapshot instead of making
    // the timing probe compete for the first segment request on the critical
    // Live -> DVR transition.
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
