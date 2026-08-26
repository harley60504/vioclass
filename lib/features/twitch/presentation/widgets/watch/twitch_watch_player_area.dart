import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../../models/playback/twitch_m3u8_variant.dart';
import '../../../platform/android_pip/twitch_android_pip_controller.dart';
import '../../../services/playback/twitch_playlist_player_runtime.dart';
import 'player/twitch_media_kit_video_surface.dart';
import 'player/twitch_watch_controls_overlay.dart';

/// Repaint isolation switches for profiling the 2nd-entry FPS drop.
///
/// Run examples:
/// flutter run --profile --dart-define=TWITCH_WATCH_DEBUG_VIDEO_PLACEHOLDER=true
/// flutter run --profile --dart-define=TWITCH_WATCH_DEBUG_HIDE_OVERLAY=true
/// flutter run --profile --dart-define=TWITCH_WATCH_DEBUG_VIDEO_PLACEHOLDER=true --dart-define=TWITCH_WATCH_DEBUG_HIDE_OVERLAY=true
const bool _debugUseVideoPlaceholder = bool.fromEnvironment(
  'TWITCH_WATCH_DEBUG_VIDEO_PLACEHOLDER',
  defaultValue: false,
);

const bool _debugHidePlayerOverlay = bool.fromEnvironment(
  'TWITCH_WATCH_DEBUG_HIDE_OVERLAY',
  defaultValue: false,
);

const bool _debugShowPlayerIsolationLabel = bool.fromEnvironment(
  'TWITCH_WATCH_DEBUG_SHOW_ISOLATION_LABEL',
  defaultValue: true,
);

class TwitchWatchPlayerArea extends StatelessWidget {
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final Player? player;
  final VideoController? videoController;
  final TwitchStreamHeaderMetadata metadata;
  final bool loading;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback? onReload;
  final VoidCallback? onOpenChannel;
  final VoidCallback? onCreateClip;
  final bool creatingClip;
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
  final bool hasDvrReplay;
  final bool showLiveEdgeLabel;
  final Duration? liveDvrDuration;
  final DateTime? liveDvrStartedAt;
  final ValueChanged<double>? onOpenDvrReplayAt;
  final VoidCallback? onReturnToLive;

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
    this.onOpenChannel,
    this.onCreateClip,
    this.creatingClip = false,
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
    this.hasDvrReplay = false,
    this.showLiveEdgeLabel = false,
    this.liveDvrDuration,
    this.liveDvrStartedAt,
    this.onOpenDvrReplayAt,
    this.onReturnToLive,
  });

  @override
  Widget build(BuildContext context) {
    final pip = TwitchAndroidPipController.instance;
    final stableVideoStage = _WatchPlayerVideoStage(
      controller: videoController,
      usePlaceholder: _debugUseVideoPlaceholder,
    );

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[playerRuntime, pip]),
      child: stableVideoStage,
      builder: (context, child) {
        final state = _WatchPlayerAreaState.fromWidget(widget: this, pip: pip);

        return _WatchPlayerShell(
          inPipMode: state.inPipMode,
          video: child ?? stableVideoStage,
          overlay: state.shouldShowControlsOverlay && !_debugHidePlayerOverlay
              ? RepaintBoundary(
                  child: WatchControlsOverlay(
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
                    onOpenChannel: onOpenChannel,
                    onCreateClip: onCreateClip,
                    creatingClip: creatingClip,
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
                    hasDvrReplay: hasDvrReplay,
                    showLiveEdgeLabel: showLiveEdgeLabel,
                    liveDvrDuration: liveDvrDuration,
                    liveDvrStartedAt: liveDvrStartedAt,
                    onOpenDvrReplayAt: onOpenDvrReplayAt,
                    onReturnToLive: onReturnToLive,
                  ),
                )
              : null,
          waitingOverlay: null,
          debugLabel: _debugShowPlayerIsolationLabel
              ? _buildIsolationDebugLabel()
              : null,
        );
      },
    );
  }

  String _buildIsolationDebugLabel() {
    final parts = <String>[];
    if (_debugUseVideoPlaceholder) parts.add('video=placeholder');
    if (_debugHidePlayerOverlay) parts.add('overlay=hidden');
    if (parts.isEmpty) parts.add('normal');
    return 'Stage243C ${parts.join(' / ')}';
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
      effectiveChatVisible: pip.isInPictureInPictureMode
          ? false
          : widget.chatVisible,
      effectiveFollowBusy: widget.followBusy || widget.relationshipBusy,
      overlayLoading:
          widget.loading ||
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
  final String? debugLabel;

  const _WatchPlayerShell({
    required this.inPipMode,
    required this.video,
    required this.overlay,
    required this.waitingOverlay,
    required this.debugLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: inPipMode ? Colors.black : Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: RepaintBoundary(child: video)),
          if (overlay != null) Positioned.fill(child: overlay!),
          if (waitingOverlay != null) Positioned.fill(child: waitingOverlay!),
          if (debugLabel != null &&
              (_debugUseVideoPlaceholder || _debugHidePlayerOverlay))
            Positioned(
              left: 10,
              bottom: 10,
              child: IgnorePointer(
                child: _WatchPlayerIsolationLabel(text: debugLabel!),
              ),
            ),
        ],
      ),
    );
  }
}

class _WatchPlayerVideoStage extends StatelessWidget {
  final VideoController? controller;
  final bool usePlaceholder;

  const _WatchPlayerVideoStage({
    required this.controller,
    required this.usePlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    if (usePlaceholder) {
      return const _WatchVideoPlaceholderSurface();
    }

    final controller = this.controller;
    if (controller == null) return const TwitchMediaKitVideoWaitingSurface();
    return TwitchMediaKitVideoSurface(controller: controller);
  }
}

class _WatchVideoPlaceholderSurface extends StatelessWidget {
  const _WatchVideoPlaceholderSurface();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Text(
          'Video placeholder\nmedia_kit / proxy still running',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _WatchPlayerIsolationLabel extends StatelessWidget {
  final String text;

  const _WatchPlayerIsolationLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
