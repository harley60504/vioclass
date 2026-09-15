import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../../models/playback/twitch_m3u8_variant.dart';
import '../../../platform/android_pip/twitch_android_pip_controller.dart';
import '../../watch/twitch_watch_playback_kind.dart';
import '../../watch/controllers/twitch_playback_timeline_controller.dart';
import '../../../services/playback/twitch_playlist_player_runtime.dart';
import '../../localization/vioclass_localizations.dart';
import 'player/twitch_media_kit_video_surface.dart';
import 'player/twitch_player_common_buttons.dart';
import 'player/twitch_watch_controls_overlay.dart';
import 'player/twitch_watch_top_action_bar.dart';
import '../shared/twitch_cached_image_layer.dart';
import '../shared/twitch_glass.dart';

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
  final bool showOfflinePlaceholder;
  final String? offlineImageUrl;
  final VoidCallback onBack;
  final VoidCallback? onHome;
  final VoidCallback? onOpenChannel;
  final VoidCallback? onCreateClip;
  final bool creatingClip;

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
  final bool hasFullLiveDvr;
  final bool showLiveEdgeLabel;
  final Duration? liveDvrDuration;
  final DateTime? liveDvrStartedAt;
  final ValueChanged<Duration>? onOpenDvrReplayAtPosition;
  final VoidCallback? onReturnToLive;
  final TwitchWatchPlaybackKind playbackKind;
  final TwitchPlaybackTimelineController? playbackTimelineController;

  const TwitchWatchPlayerArea({
    super.key,
    required this.playerRuntime,
    required this.player,
    required this.videoController,
    required this.metadata,
    required this.loading,
    required this.error,
    this.showOfflinePlaceholder = false,
    this.offlineImageUrl,
    required this.onBack,
    this.onHome,
    this.onOpenChannel,
    this.onCreateClip,
    this.creatingClip = false,
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
    this.hasFullLiveDvr = false,
    this.showLiveEdgeLabel = false,
    this.liveDvrDuration,
    this.liveDvrStartedAt,
    this.onOpenDvrReplayAtPosition,
    this.onReturnToLive,
    this.playbackKind = TwitchWatchPlaybackKind.live,
    this.playbackTimelineController,
  });

  @override
  Widget build(BuildContext context) {
    return _TwitchWatchPlayerFrame(area: this);
  }
}

class _TwitchWatchPlayerFrame extends StatefulWidget {
  final TwitchWatchPlayerArea area;

  const _TwitchWatchPlayerFrame({required this.area});

  @override
  State<_TwitchWatchPlayerFrame> createState() =>
      _TwitchWatchPlayerFrameState();
}

class _TwitchWatchPlayerFrameState extends State<_TwitchWatchPlayerFrame> {
  late final WatchControlsChromeController _chromeController;

  @override
  void initState() {
    super.initState();
    _chromeController = WatchControlsChromeController();
  }

  @override
  void dispose() {
    _chromeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.area;
    final pip = TwitchAndroidPipController.instance;
    final stableVideoStage = _WatchPlayerVideoStage(
      controller: area.videoController,
      usePlaceholder: _debugUseVideoPlaceholder,
      showOfflinePlaceholder: area.showOfflinePlaceholder,
      offlineImageUrl: area.offlineImageUrl,
    );

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[area.playerRuntime, pip]),
      child: stableVideoStage,
      builder: (context, child) {
        final state = _WatchPlayerAreaState.fromWidget(widget: area, pip: pip);
        final showOfflineControls =
            area.showOfflinePlaceholder &&
            !state.inPipMode &&
            !_debugHidePlayerOverlay;
        final showPlayerControls =
            !area.showOfflinePlaceholder &&
            state.shouldShowControlsOverlay &&
            !_debugHidePlayerOverlay;

        final fixedPlayer = _FixedPlayerCanvas(
          child: _WatchPlayerShell(
            inPipMode: state.inPipMode,
            video: state.effectiveCurrentVariant?.isAudioOnly == true
                ? const ColoredBox(color: Colors.black)
                : child ?? stableVideoStage,
            overlay: showOfflineControls
                ? RepaintBoundary(
                    child: _WatchOfflineControlsOverlay(
                      chatVisible: state.effectiveChatVisible,
                      fullscreen: state.effectiveFullscreen,
                      showFullscreenButton: area.showFullscreenButton,
                      onToggleChat: area.onToggleChat,
                      onToggleFullscreen: area.onToggleFullscreen,
                    ),
                  )
                : showPlayerControls
                ? RepaintBoundary(
                    child: WatchControlsOverlay(
                      loading: state.overlayLoading,
                      error: area.error,
                      runtimeError: area.playerRuntime.error,
                      metadata: area.metadata,
                      isFollowing: area.isFollowing,
                      followBusy: state.effectiveFollowBusy,
                      onBack: area.onBack,
                      onHome: area.onHome,
                      onToggleFollow: area.onToggleFollow,
                      onSubscribe: area.onSubscribe,
                      onOpenChannel: area.onOpenChannel,
                      onCreateClip: area.onCreateClip,
                      creatingClip: area.creatingClip,
                      player: state.player!,
                      playerRuntime: area.playerRuntime,
                      muted: area.muted,
                      volume: area.volume,
                      fullscreen: state.effectiveFullscreen,
                      chatVisible: state.effectiveChatVisible,
                      showFullscreenButton: area.showFullscreenButton,
                      onToggleMute: area.onToggleMute,
                      onVolumeChanged: area.onVolumeChanged,
                      qualityVariants: state.effectiveQualityVariants,
                      currentVariant: state.effectiveCurrentVariant,
                      onQualityChanged: state.effectiveOnQualityChanged,
                      onToggleChat: area.onToggleChat,
                      onToggleFullscreen: area.onToggleFullscreen,
                      hasDvrReplay: area.hasDvrReplay,
                      hasFullLiveDvr: area.hasFullLiveDvr,
                      showLiveEdgeLabel: area.showLiveEdgeLabel,
                      liveDvrDuration: area.liveDvrDuration,
                      liveDvrStartedAt: area.liveDvrStartedAt,
                      onOpenDvrReplayAtPosition:
                          area.onOpenDvrReplayAtPosition,
                      onReturnToLive: area.onReturnToLive,
                      playbackKind: area.playbackKind,
                      playbackTimelineController:
                          area.playbackTimelineController,
                      timelineEnabled: !state.hasError,
                      showTopActionBar: false,
                      chromeController: _chromeController,
                    ),
                  )
                : null,
            waitingOverlay: null,
            debugLabel: _debugShowPlayerIsolationLabel
                ? _buildIsolationDebugLabel()
                : null,
          ),
        );

        Widget? topActionBar;
        if (showOfflineControls) {
          topActionBar = _WatchTopActionBarViewport(
            persistent: true,
            controller: _chromeController,
            child: WatchTopActionBar(
              metadata: area.metadata,
              isFollowing: area.isFollowing,
              followBusy: state.effectiveFollowBusy,
              onBack: area.onBack,
              onHome: area.onHome,
              onToggleFollow: area.onToggleFollow,
              onSubscribe: area.onSubscribe,
              onOpenChannel: area.onOpenChannel,
              onCreateClip: null,
              creatingClip: false,
            ),
          );
        } else if (showPlayerControls) {
          topActionBar = _WatchTopActionBarViewport(
            persistent: false,
            controller: _chromeController,
            child: WatchTopActionBar(
              metadata: area.metadata,
              isFollowing: area.isFollowing,
              followBusy: state.effectiveFollowBusy,
              onBack: area.onBack,
              onHome: area.onHome,
              onToggleFollow: area.onToggleFollow,
              onSubscribe: area.onSubscribe,
              onOpenChannel: area.onOpenChannel,
              onCreateClip: area.onCreateClip,
              creatingClip: area.creatingClip,
            ),
          );
        }

        return _WatchPlayerViewportShell(
          inPipMode: state.inPipMode,
          fixedPlayer: fixedPlayer,
          topActionBar: topActionBar,
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
  final bool hasError;
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
    required this.hasError,
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
      effectiveFollowBusy: widget.followBusy,
      overlayLoading:
          !playerReady &&
          (widget.loading ||
              widget.playerRuntime.loading ||
              widget.playerRuntime.switchingQuality),
      effectiveQualityVariants:
          widget.qualityVariants ?? widget.playerRuntime.variants,
      effectiveCurrentVariant:
          widget.currentVariant ?? widget.playerRuntime.currentVariant,
      effectiveOnQualityChanged:
          widget.onQualityChanged ?? widget.onQualitySelected,
      hasError:
          (widget.error != null && widget.error!.trim().isNotEmpty) ||
          widget.playerRuntime.error != null,
    );
  }

  bool get shouldShowControlsOverlay =>
      player != null && !inPipMode && (playerReady || hasError);
  bool get shouldShowWaitingOverlay => !playerReady && !inPipMode;
}

class _WatchPlayerViewportShell extends StatelessWidget {
  final bool inPipMode;
  final Widget fixedPlayer;
  final Widget? topActionBar;

  const _WatchPlayerViewportShell({
    required this.inPipMode,
    required this.fixedPlayer,
    required this.topActionBar,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: fixedPlayer),
          if (!inPipMode && topActionBar != null)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: topActionBar!,
            ),
        ],
      ),
    );
  }
}

class _FixedPlayerCanvas extends StatelessWidget {
  static const double _canvasWidth = 1280.0;
  static const double _canvasHeight = 720.0;

  final Widget child;

  const _FixedPlayerCanvas({required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: _canvasWidth,
            height: _canvasHeight,
            child: RepaintBoundary(child: child),
          ),
        ),
      ),
    );
  }
}

class _WatchTopActionBarViewport extends StatelessWidget {
  static const Duration _fadeDuration = Duration(milliseconds: 180);

  final bool persistent;
  final WatchControlsChromeController controller;
  final Widget child;

  const _WatchTopActionBarViewport({
    required this.persistent,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (persistent) {
      return child;
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final visible = controller.visible;
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: _fadeDuration,
            curve: Curves.easeOutCubic,
            child: MouseRegion(
              onEnter: (_) => controller.wake(),
              onHover: (_) => controller.wake(),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: controller.wake,
                child: RepaintBoundary(child: child),
              ),
            ),
          ),
        );
      },
    );
  }
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
  final bool showOfflinePlaceholder;
  final String? offlineImageUrl;

  const _WatchPlayerVideoStage({
    required this.controller,
    required this.usePlaceholder,
    required this.showOfflinePlaceholder,
    required this.offlineImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (usePlaceholder) {
      return const _WatchVideoPlaceholderSurface();
    }

    if (showOfflinePlaceholder) {
      return _WatchOfflineImageSurface(imageUrl: offlineImageUrl);
    }

    final controller = this.controller;
    if (controller == null) return const TwitchMediaKitVideoWaitingSurface();
    return TwitchMediaKitVideoSurface(controller: controller);
  }
}

class _WatchOfflineControlsOverlay extends StatelessWidget {
  final bool chatVisible;
  final bool fullscreen;
  final bool showFullscreenButton;
  final VoidCallback? onToggleChat;
  final VoidCallback? onToggleFullscreen;

  const _WatchOfflineControlsOverlay({
    required this.chatVisible,
    required this.fullscreen,
    required this.showFullscreenButton,
    required this.onToggleChat,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 12,
          right: 12,
          bottom: 10,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 2),
            child: _WatchOfflineBottomControlBar(
              chatVisible: chatVisible,
              fullscreen: fullscreen,
              showFullscreenButton: showFullscreenButton,
              onToggleChat: onToggleChat,
              onToggleFullscreen: onToggleFullscreen,
            ),
          ),
        ),
      ],
    );
  }
}

class _WatchOfflineBottomControlBar extends StatelessWidget {
  final bool chatVisible;
  final bool fullscreen;
  final bool showFullscreenButton;
  final VoidCallback? onToggleChat;
  final VoidCallback? onToggleFullscreen;

  const _WatchOfflineBottomControlBar({
    required this.chatVisible,
    required this.fullscreen,
    required this.showFullscreenButton,
    required this.onToggleChat,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return TwitchGlassSurface(
      borderRadius: BorderRadius.circular(24),
      backgroundColor: Colors.black.withValues(alpha: 0.56),
      borderColor: Colors.white.withValues(alpha: 0.12),
      blurSigma: 0,
      boxShadow: const <BoxShadow>[],
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.tv_off_rounded,
                color: Colors.white.withValues(alpha: 0.72),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.vio.t('目前未開台'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PlainIconButton(
                tooltip: context.vio.t(chatVisible ? '隱藏聊天室' : '顯示聊天室'),
                icon: chatVisible
                    ? Icons.chat_bubble
                    : Icons.chat_bubble_outline,
                size: 23,
                active: chatVisible,
                dense: true,
                onPressed: onToggleChat,
              ),
              if (showFullscreenButton)
                PlainIconButton(
                  tooltip: context.vio.t(fullscreen ? '離開全螢幕' : '全螢幕'),
                  icon: fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  size: 25,
                  active: fullscreen,
                  dense: true,
                  onPressed: onToggleFullscreen,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchOfflineImageSurface extends StatelessWidget {
  final String? imageUrl;

  const _WatchOfflineImageSurface({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;
          if (maxWidth <= 0 || maxHeight <= 0) {
            return const SizedBox.shrink();
          }

          var width = maxWidth;
          var height = width / twitchWatchVideoAspectRatio;
          if (height > maxHeight) {
            height = maxHeight;
            width = height * twitchWatchVideoAspectRatio;
          }
          width = width.clamp(1.0, maxWidth).toDouble();
          height = height.clamp(1.0, maxHeight).toDouble();
          final dpr = MediaQuery.devicePixelRatioOf(context);

          return Center(
            child: TwitchCachedImageLayer(
              imageUrl: imageUrl,
              width: width,
              height: height,
              cacheWidth: (width * dpr).round().clamp(320, 1920),
              cacheHeight: (height * dpr).round().clamp(180, 1080),
              fit: BoxFit.contain,
              fallbackColor: Colors.black,
              fallbackIcon: Icons.tv_off_rounded,
              fallbackIconColor: Colors.white30,
              fallbackIconSize: 42,
            ),
          );
        },
      ),
    );
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
