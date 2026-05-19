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
import 'player/twitch_live_playback_strip.dart';
import 'player/twitch_media_kit_video_surface.dart';
import 'player/twitch_player_common_buttons.dart';
import 'player/twitch_player_error_card.dart';
import 'player/twitch_player_more_actions_button.dart';
import 'player/twitch_player_pip_button.dart';
import 'player/twitch_player_quality_button.dart';
import 'player/twitch_player_volume_control.dart';
import 'player/twitch_watch_stream_header.dart';
import 'player/twitch_watch_top_action_bar.dart';
import 'player/twitch_watch_top_buttons.dart';

part 'player/twitch_watch_controls_overlay.dart';
part 'player/twitch_watch_bottom_control_bar.dart';

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
        final state = _WatchPlayerAreaState.fromWidget(
          widget: this,
          pip: pip,
        );

        return _WatchPlayerShell(
          inPipMode: state.inPipMode,
          video: _WatchPlayerVideoStage(
            controller: state.videoController,
          ),
          overlay: state.shouldShowControlsOverlay
              ? _WatchControlsOverlay(
                  loading: state.overlayLoading,
                  error: error,
                  runtimeError: playerRuntime.error,
                  metadata: metadata,
                  isFollowing: isFollowing,
                  followBusy: state.effectiveFollowBusy,
                  onBack: onBack,
                  onToggleFollow: onToggleFollow,
                  onSubscribe: onSubscribe,
                  onReload: onReload,
                  onStop: onStop,
                  player: state.player!,
                  playerRuntime: playerRuntime,
                  muted: muted,
                  volume: volume,
                  fullscreen: state.effectiveFullscreen,
                  chatVisible: state.effectiveChatVisible,
                  showFullscreenButton: showFullscreenButton,
                  onToggleMute: onToggleMute,
                  onVolumeChanged: onVolumeChanged,
                  qualityVariants: state.effectiveQualityVariants,
                  currentVariant: state.effectiveCurrentVariant,
                  onQualityChanged: state.effectiveOnQualityChanged,
                  onToggleChat: onToggleChat,
                  onToggleFullscreen: onToggleFullscreen,
                )
              : null,
          waitingOverlay: state.shouldShowWaitingOverlay
              ? _WatchControlsNotReadyOverlay(
                  metadata: metadata,
                  loading: loading || playerRuntime.loading,
                  onBack: onBack,
                  onReload: onReload,
                )
              : null,
        );
      },
    );
  }
}

class _WatchPlayerAreaState {
  final Player? player;
  final VideoController? videoController;
  final bool playerReady;
  final bool inPipMode;
  final bool effectiveFullscreen;
  final bool effectiveChatVisible;
  final bool effectiveFollowBusy;
  final bool overlayLoading;
  final List<TwitchM3u8Variant> effectiveQualityVariants;
  final TwitchM3u8Variant? effectiveCurrentVariant;
  final ValueChanged<TwitchM3u8Variant>? effectiveOnQualityChanged;

  const _WatchPlayerAreaState({
    required this.player,
    required this.videoController,
    required this.playerReady,
    required this.inPipMode,
    required this.effectiveFullscreen,
    required this.effectiveChatVisible,
    required this.effectiveFollowBusy,
    required this.overlayLoading,
    required this.effectiveQualityVariants,
    required this.effectiveCurrentVariant,
    required this.effectiveOnQualityChanged,
  });

  factory _WatchPlayerAreaState.fromWidget({
    required TwitchWatchPlayerArea widget,
    required TwitchAndroidPipController pip,
  }) {
    final playerReady = widget.player != null && widget.videoController != null;

    return _WatchPlayerAreaState(
      player: widget.player,
      videoController: widget.videoController,
      playerReady: playerReady,
      inPipMode: pip.isInPictureInPictureMode,
      effectiveFullscreen: widget.fullscreen || widget.fullscreenMode,
      effectiveChatVisible:
          pip.isInPictureInPictureMode ? false : widget.chatVisible,
      effectiveFollowBusy: widget.followBusy || widget.relationshipBusy,
      overlayLoading: widget.loading ||
          widget.playerRuntime.loading ||
          widget.playerRuntime.switchingQuality,
      effectiveQualityVariants:
          widget.qualityVariants ?? widget.playerRuntime.variants,
      effectiveCurrentVariant:
          widget.currentVariant ?? widget.playerRuntime.currentVariant,
      effectiveOnQualityChanged:
          widget.onQualityChanged ?? widget.onQualitySelected,
    );
  }

  bool get shouldShowControlsOverlay => playerReady && !inPipMode;
  bool get shouldShowWaitingOverlay => !playerReady && !inPipMode;
}

class _WatchPlayerShell extends StatelessWidget {
  final bool inPipMode;
  final Widget video;
  final Widget? overlay;
  final Widget? waitingOverlay;

  const _WatchPlayerShell({
    required this.inPipMode,
    required this.video,
    required this.overlay,
    required this.waitingOverlay,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: inPipMode ? Colors.black : Colors.transparent,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(child: video),
          if (overlay != null) Positioned.fill(child: overlay!),
          if (waitingOverlay != null) Positioned.fill(child: waitingOverlay!),
        ],
      ),
    );
  }
}

class _WatchPlayerVideoStage extends StatelessWidget {
  final VideoController? controller;

  const _WatchPlayerVideoStage({required this.controller});

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) return const TwitchMediaKitVideoWaitingSurface();
    return TwitchMediaKitVideoSurface(controller: controller);
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
                  PlainIconButton(
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
                  PlainIconButton(
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