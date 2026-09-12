import 'dart:async';

import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:video_player/video_player.dart' as official_video;

import 'twitch_media_kit_player_host.dart';

/// Test-only coordination for the Android player-engine A/B branch.
///
/// The selected engine and external player controllers live outside the video
/// widget so an Android foreground surface rebuild does not reopen the engine
/// picker or silently change the engine being tested.
class TwitchPlayerEngineDiagnosticState {
  TwitchPlayerEngineDiagnosticState._();

  static const String mediaKitKey = 'mediaKit';
  static const String videoPlayerKey = 'videoPlayer';
  static const String libVlcKey = 'libVlc';

  static String selectedEngineKey = mediaKitKey;
  static bool externalPlaybackActive = false;
  static String engineLabel = 'media_kit / libmpv';
  static String? mediaUri;

  static official_video.VideoPlayerController? videoPlayerController;
  static VlcPlayerController? vlcController;

  static Future<void>? _switching;

  static String labelFor(String key) => switch (key) {
    videoPlayerKey => 'video_player / ExoPlayer',
    libVlcKey => 'LibVLC',
    _ => 'media_kit / libmpv',
  };

  static Future<void> selectEngine({
    required String engineKey,
    required String uri,
  }) async {
    final pending = _switching;
    if (pending != null) await pending;

    final safeUri = uri.trim();
    if (safeUri.isEmpty) return;

    final sameSelection = selectedEngineKey == engineKey && mediaUri == safeUri;
    if (sameSelection) {
      externalPlaybackActive = engineKey != mediaKitKey;
      engineLabel = labelFor(engineKey);
      if (engineKey == mediaKitKey) {
        await TwitchMediaKitPlayerHost.restoreSharedMedia(
          uri: safeUri,
          play: true,
          forceOpen: false,
        );
      } else if (engineKey == videoPlayerKey) {
        final controller = videoPlayerController;
        if (controller != null &&
            controller.value.isInitialized &&
            !controller.value.isPlaying) {
          await controller.play();
        }
      } else if (engineKey == libVlcKey) {
        final controller = vlcController;
        if (controller != null && controller.value.isInitialized) {
          await controller.play();
        }
      }
      return;
    }

    _switching = () async {
      await _disposeExternalControllers();
      selectedEngineKey = engineKey;
      engineLabel = labelFor(engineKey);
      mediaUri = safeUri;

      if (engineKey == mediaKitKey) {
        externalPlaybackActive = false;
        await TwitchMediaKitPlayerHost.restoreSharedMedia(
          uri: safeUri,
          play: true,
          forceOpen: false,
        );
        return;
      }

      externalPlaybackActive = true;
      await TwitchMediaKitPlayerHost.pauseShared();

      if (engineKey == videoPlayerKey) {
        final controller = official_video.VideoPlayerController.networkUrl(
          Uri.parse(safeUri),
          videoPlayerOptions: official_video.VideoPlayerOptions(
            mixWithOthers: false,
          ),
        );
        videoPlayerController = controller;
        await controller.initialize();
        await controller.play();
        return;
      }

      final controller = VlcPlayerController.network(
        safeUri,
        hwAcc: HwAcc.full,
        autoInitialize: true,
        autoPlay: true,
        options: VlcPlayerOptions(),
      );
      vlcController = controller;
    }();

    try {
      await _switching;
    } finally {
      _switching = null;
    }
  }

  static Future<void> _disposeExternalControllers() async {
    final official = videoPlayerController;
    videoPlayerController = null;
    if (official != null) {
      try {
        await official.dispose();
      } catch (_) {}
    }

    final vlc = vlcController;
    vlcController = null;
    if (vlc != null) {
      try {
        await vlc.dispose();
      } catch (_) {}
    }
  }
}
