import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

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
      if (startPosition != null) {
        // DVR snapshots include preroll segments. High-resolution seek lets mpv
        // begin from an earlier keyframe and decode forward to the requested
        // sub-segment offset.
        await session.ensureReady();
        session.player.setProperty('hr-seek', 'yes');
        session.player.setProperty('hr-seek-demuxer-offset', '2.0');
      }

      final isLocalDvrSnapshot =
          startPosition != null &&
          nextUri.startsWith('http://127.0.0.1:') &&
          nextUri.contains('/playlist.m3u8?v=');

      if (isLocalDvrSnapshot) {
        debugPrint(
          '[TwitchPlayer] VOD snapshot precise start '
          'target=${(startPosition.inMilliseconds / 1000).toStringAsFixed(3)}s',
        );
      }

      if (startPosition != null && deferInitialSeek) {
        // Retained for callers that explicitly need a post-open seek. Frozen
        // DVR snapshots do not use this path: they are finite VOD-style HLS and
        // can safely use Media(start:).
        await session.openOrResume(
          uri: nextUri,
          play: false,
          forceOpen: forceOpen,
        );
        await _waitForSeekableMedia(session.player, startPosition);
        debugPrint(
          '[TwitchPlayer] deferred precise seek '
          'target=${(startPosition.inMilliseconds / 1000).toStringAsFixed(3)}s '
          'duration=${(session.player.state.duration.inMilliseconds / 1000).toStringAsFixed(3)}s',
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
}
