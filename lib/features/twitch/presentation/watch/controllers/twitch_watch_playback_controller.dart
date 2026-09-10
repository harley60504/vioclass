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
        // A DVR playlist may intentionally include one or two preroll
        // segments. Let mpv decode forward from an earlier keyframe instead of
        // snapping to a coarse keyframe-only position.
        await session.ensureReady();
        session.player.setProperty('hr-seek', 'yes');
        session.player.setProperty('hr-seek-demuxer-offset', '2.0');
      }

      final isLocalGrowingDvrPlaylist =
          startPosition != null &&
          nextUri.startsWith('http://127.0.0.1:') &&
          nextUri.contains('/playlist.m3u8?v=');
      final shouldDeferInitialSeek =
          startPosition != null &&
          (deferInitialSeek || isLocalGrowingDvrPlaylist);

      if (shouldDeferInitialSeek) {
        // Do not use Media(start:) for the growing local DVR HLS playlist.
        // mpv/FFmpeg can receive the initial seek before the HLS demuxer has
        // built its segment map; larger preroll-relative starts (20-30 s) can
        // then stall. Open paused first, let the playlist become visible to the
        // demuxer, then issue a normal precise player.seek().
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
    // Player.open() only guarantees that the open command was accepted. For a
    // local HLS playlist the duration/segment map normally appears shortly
    // afterwards. Keep this bounded so a stream with unknown duration still
    // proceeds to seek instead of hanging the UI action.
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
