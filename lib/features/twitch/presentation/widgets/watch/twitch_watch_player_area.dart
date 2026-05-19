// PATCH VERSION: watch_player_area_stage226_android_pip
// Place at: lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart
//
// StreamNook-style player area entry point.
// Stage 220I: allow WatchPage to build before the lazy PiliPlus media_kit
// session has finished creating Player / VideoController.
// Stage 226: Android PiP integration hides all non-video chrome while PiP is
// active and exposes a PiP button through the player controls.

library twitch_watch_player_area;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../../models/playback/twitch_m3u8_variant.dart';
import '../../../platform/android_pip/twitch_android_pip_controller.dart';
import '../../../services/playback/twitch_playlist_player_runtime.dart';
import '../shared/twitch_glass.dart';

part 'player/twitch_watch_controls_overlay.dart';
part 'player/twitch_watch_top_action_bar.dart';
part 'player/twitch_watch_stream_header.dart';
part 'player/twitch_watch_top_buttons.dart';
part 'player/twitch_watch_bottom_control_bar.dart';
part 'player/twitch_live_playback_strip.dart';
part 'player/twitch_player_volume_control.dart';
part 'player/twitch_player_more_actions_button.dart';
part 'player/twitch_player_quality_button.dart';
part 'player/twitch_player_common_buttons.dart';
part 'player/twitch_player_error_card.dart';
part 'player/twitch_player_pip_button.dart';

const double _watchVideoAspectRatio = 16 / 9;

class TwitchWatchPlayerArea extends StatelessWidget {
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final Player? player;
  final VideoController? videoController;
  final TwitchStreamHeaderMetadata metadata;
  final bool loading;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback? onReload;
  final VoidCallback onStop;

  final List<TwitchM3u8Variant>? qualityVariants;
  final TwitchM3u8Variant? currentVariant;
  final bool qualityBusy;
  final ValueChanged<TwitchM3u8Variant>? onQualitySelected;
  final bool relationshipBusy;
  final String? relationshipError;

  final bool isFollowing;
  final bool followBusy;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onSubscribe;

  final bool chatVisible;
  final VoidCallback? onToggleChat;
  final bool fullscreen;
  final bool fullscreenMode;
  final bool showFullscreenButton;
  final VoidCallback? onToggleFullscreen;

  final bool muted;
  final double volume;
  final VoidCallback? onToggleMute;
  final ValueChanged<double>? onVolumeChanged;
  final ValueChanged<TwitchM3u8Variant>? onQualityChanged;

  const TwitchWatchPlayerArea({
    super.key,
    required this.playerRuntime,
    required this.player,
    required this.videoController,
    required this.metadata,
    required this.loading,
    required this.error,
    required this.onBack,
    required this.onReload,
    required this.onStop,
    this.qualityVariants,
    this.currentVariant,
    this.qualityBusy = false,
    this.onQualitySelected,
    this.relationshipBusy = false,
    this.relationshipError,
    this.isFollowing = false,
    this.followBusy = false,
    this.onToggleFollow,
    this.onSubscribe,
    this.chatVisible = true,
    this.onToggleChat,
    this.fullscreen = false,
    this.fullscreenMode = false,
    this.showFullscreenButton = true,
    this.onToggleFullscreen,
    this.muted = false,
    this.volume = 100,
    this.onToggleMute,
    this.onVolumeChanged,
    this.onQualityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pip = TwitchAndroidPipController.instance;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[playerRuntime, pip]),
      builder: (context, _) {
        final currentPlayer = player;
        final currentVideoController = videoController;
        final playerReady = currentPlayer != null && currentVideoController != null;
        final inPipMode = pip.isInPictureInPictureMode;
        final effectiveFullscreen = fullscreen || fullscreenMode;
        final effectiveChatVisible = inPipMode ? false : chatVisible;
        final effectiveFollowBusy = followBusy || relationshipBusy;
        final effectiveQualityVariants = qualityVariants ?? playerRuntime.variants;
        final effectiveCurrentVariant = currentVariant ?? playerRuntime.currentVariant;
        final effectiveOnQualityChanged = onQualityChanged ?? onQualitySelected;

        return ColoredBox(
          color: inPipMode ? Colors.black : Colors.transparent,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: playerReady
                    ? _WatchCenteredVideoSurface(controller: currentVideoController)
                    : const _WatchPlayerWaitingSurface(),
              ),
              if (!inPipMode)
                if (playerReady)
                  Positioned.fill(
                    child: _WatchControlsOverlay(
                      loading: loading ||
                          playerRuntime.loading ||
                          playerRuntime.switchingQuality,
                      error: error,
                      runtimeError: playerRuntime.error,
                      metadata: metadata,
                      isFollowing: isFollowing,
                      followBusy: effectiveFollowBusy,
                      onBack: onBack,
                      onToggleFollow: onToggleFollow,
                      onSubscribe: onSubscribe,
                      onReload: onReload,
                      onStop: onStop,
                      player: currentPlayer,
                      playerRuntime: playerRuntime,
                      muted: muted,
                      volume: volume,
                      fullscreen: effectiveFullscreen,
                      chatVisible: effectiveChatVisible,
                      showFullscreenButton: showFullscreenButton,
                      onToggleMute: onToggleMute,
                      onVolumeChanged: onVolumeChanged,
                      qualityVariants: effectiveQualityVariants,
                      currentVariant: effectiveCurrentVariant,
                      onQualityChanged: effectiveOnQualityChanged,
                      onToggleChat: onToggleChat,
                      onToggleFullscreen: onToggleFullscreen,
                    ),
                  )
                else
                  Positioned.fill(
                    child: _WatchControlsNotReadyOverlay(
                      metadata: metadata,
                      loading: loading || playerRuntime.loading,
                      onBack: onBack,
                      onReload: onReload,
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _WatchPlayerWaitingSurface extends StatelessWidget {
  const _WatchPlayerWaitingSurface();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0E0E10),
      child: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _WatchControlsNotReadyOverlay extends StatelessWidget {
  final TwitchStreamHeaderMetadata metadata;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback? onReload;

  const _WatchControlsNotReadyOverlay({
    required this.metadata,
    required this.loading,
    required this.onBack,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: TwitchGlassSurface(
            borderRadius: BorderRadius.circular(18),
            backgroundColor: Colors.black.withOpacity(0.34),
            borderColor: Colors.white.withOpacity(0.10),
            blurSigma: 18,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  _PlainIconButton(
                    tooltip: '返回',
                    icon: Icons.arrow_back,
                    size: 24,
                    onPressed: onBack,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      metadata.displayName.isNotEmpty
                          ? metadata.displayName
                          : metadata.channelLogin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _PlainIconButton(
                    tooltip: '重新載入',
                    icon: Icons.refresh,
                    size: 24,
                    onPressed: onReload,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (loading)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WatchCenteredVideoSurface extends StatelessWidget {
  final VideoController controller;

  const _WatchCenteredVideoSurface({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;

        if (maxWidth <= 0 || maxHeight <= 0) return const SizedBox.shrink();

        var width = maxWidth;
        var height = width / _watchVideoAspectRatio;

        if (height > maxHeight) {
          height = maxHeight;
          width = height * _watchVideoAspectRatio;
        }

        width = width.clamp(1.0, maxWidth).toDouble();
        height = height.clamp(1.0, maxHeight).toDouble();

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Video(
              controller: controller,
              fit: BoxFit.contain,
              controls: NoVideoControls,
            ),
          ),
        );
      },
    );
  }
}
