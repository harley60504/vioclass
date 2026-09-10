import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../../../services/playback/twitch_local_dvr_media_timing_probe.dart';
import '../twitch_watch_feature_ports.dart';

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

      var hrSeekDemuxerOffset = const Duration(seconds: 2);
      if (isLocalDvrSnapshot) {
        final probe = await TwitchLocalDvrMediaTimingProbe.probe(
          playlistUrl: nextUri,
          startPosition: startPosition,
        );
        if (probe != null) {
          hrSeekDemuxerOffset = probe.suggestedDemuxerOffset;
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
            'hrBackoff=${_seconds(hrSeekDemuxerOffset)}s',
          );
        } else {
          debugPrint(
            '[TsSeekIndex] unavailable; hrBackoff=${_seconds(hrSeekDemuxerOffset)}s',
          );
        }
      }

      if (startPosition != null) {
        // Frozen DVR snapshots are finite HLS. High-resolution seek can decode
        // forward from the nearest random-access point; the TS timing probe
        // expands the demuxer backoff when the actual GOP requires more than
        // the conservative 2-second fallback.
        await session.ensureReady();
        session.player.setProperty('hr-seek', 'yes');
        session.player.setProperty(
          'hr-seek-demuxer-offset',
          _seconds(hrSeekDemuxerOffset),
        );
      }

      if (isLocalDvrSnapshot) {
        debugPrint(
          '[TwitchPlayer] VOD snapshot precise start '
          'target=${_seconds(startPosition)}s '
          'hrBackoff=${_seconds(hrSeekDemuxerOffset)}s',
        );
      }

      if (startPosition != null && deferInitialSeek) {
        // Retained for callers that explicitly need a post-open seek. Frozen
        // DVR snapshots normally use Media(start:) because they are finite and
        // immutable for the seek generation.
        await session.openOrResume(
          uri: nextUri,
          play: false,
          forceOpen: forceOpen,
        );
        await _waitForSeekableMedia(session.player, startPosition);
        debugPrint(
          '[TwitchPlayer] deferred precise seek '
          'target=${_seconds(startPosition)}s '
          'duration=${_seconds(session.player.state.duration)}s',
        );
        await session.player.seek(startPosition);
        if (play) {
          await session.player.play();
        }
      } else {
        await session.openOrResume(
          uri: nextUri,
          play: play,
          forceOpen: forceOpen,
          startPosition: startPosition,
        );
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
