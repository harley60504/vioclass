import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../models/playback/twitch_m3u8_variant.dart';
import '../../../../services/playback/twitch_playlist_player_runtime.dart';
import '../../../localization/vioclass_localizations.dart';
import '../../../theme/twitch_ui_tokens.dart';
import '../../../watch/controllers/twitch_playback_timeline_controller.dart';
import '../../../watch/twitch_watch_playback_kind.dart';
import '../../shared/twitch_glass.dart';
import 'twitch_player_common_buttons.dart';
import 'twitch_player_more_actions_button.dart';
import 'twitch_player_pip_button.dart';
import 'twitch_player_quality_button.dart';
import 'twitch_player_volume_control.dart';
import 'twitch_vod_playback_strip.dart';

const Duration _liveSeekWindowDuration = Duration(seconds: 20);

class WatchBottomControlBar extends StatelessWidget {
  final Player player;
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final bool muted;
  final double volume;
  final bool fullscreen;
  final bool chatVisible;
  final bool showFullscreenButton;
  final VoidCallback? onToggleMute;
  final ValueChanged<double>? onVolumeChanged;
  final List<TwitchM3u8Variant> qualityVariants;
  final TwitchM3u8Variant? currentVariant;
  final ValueChanged<TwitchM3u8Variant>? onQualityChanged;
  final VoidCallback? onToggleChat;
  final VoidCallback? onToggleFullscreen;
  final bool hasDvrReplay;
  final bool hasFullLiveDvr;
  final bool showLiveEdgeLabel;
  final Duration? liveDvrDuration;
  final DateTime? liveDvrStartedAt;
  final ValueChanged<Duration>? onOpenDvrReplayAtPosition;
  final VoidCallback? onReturnToLive;
  final TwitchWatchPlaybackKind playbackKind;
  final bool timelineEnabled;
  final TwitchPlaybackTimelineController? playbackTimelineController;

  const WatchBottomControlBar({
    super.key,
    required this.player,
    required this.playerRuntime,
    required this.muted,
    required this.volume,
    required this.fullscreen,
    required this.chatVisible,
    required this.showFullscreenButton,
    required this.onToggleMute,
    required this.onVolumeChanged,
    required this.qualityVariants,
    required this.currentVariant,
    required this.onQualityChanged,
    required this.onToggleChat,
    required this.onToggleFullscreen,
    this.hasDvrReplay = false,
    this.hasFullLiveDvr = false,
    this.showLiveEdgeLabel = false,
    this.liveDvrDuration,
    this.liveDvrStartedAt,
    this.onOpenDvrReplayAtPosition,
    this.onReturnToLive,
    this.playbackKind = TwitchWatchPlaybackKind.live,
    this.timelineEnabled = true,
    this.playbackTimelineController,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (context, playingSnapshot) {
        return StreamBuilder<bool>(
          stream: player.stream.buffering,
          initialData: player.state.buffering,
          builder: (context, bufferingSnapshot) {
            return StreamBuilder<Duration>(
              stream: player.stream.position,
              initialData: player.state.position,
              builder: (context, positionSnapshot) {
                return StreamBuilder<Duration>(
                  stream: player.stream.duration,
                  initialData: player.state.duration,
                  builder: (context, durationSnapshot) {
                    final playing = playingSnapshot.data ?? false;
                    final buffering = bufferingSnapshot.data ?? false;
                    _configureTimelineController(
                      playerPosition: positionSnapshot.data ?? Duration.zero,
                      playerDuration: durationSnapshot.data ?? Duration.zero,
                      advancing: playing && !buffering,
                    );

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final layout = _WatchBottomControlBarLayout.fromWidth(
                          constraints.maxWidth,
                        );

                        final controlsContent = SizedBox(
                          width: layout.contentWidth,
                          height: layout.contentHeight,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: layout.horizontalPadding,
                            ),
                            child: layout.useCompactLayout
                                ? _CompactWatchBottomControls(
                                    player: player,
                                    playerRuntime: playerRuntime,
                                    playing: playing,
                                    muted: muted,
                                    volume: volume,
                                    fullscreen: fullscreen,
                                    chatVisible: chatVisible,
                                    showFullscreenButton: showFullscreenButton,
                                    onToggleMute: onToggleMute,
                                    onVolumeChanged: onVolumeChanged,
                                    qualityVariants: qualityVariants,
                                    currentVariant: currentVariant,
                                    onQualityChanged: onQualityChanged,
                                    onToggleChat: onToggleChat,
                                    onToggleFullscreen: onToggleFullscreen,
                                    hasDvrReplay: hasDvrReplay,
                                    hasFullLiveDvr: hasFullLiveDvr,
                                    showLiveEdgeLabel: showLiveEdgeLabel,
                                    liveDvrDuration: liveDvrDuration,
                                    liveDvrStartedAt: liveDvrStartedAt,
                                    onOpenDvrReplayAtPosition:
                                        onOpenDvrReplayAtPosition,
                                    onReturnToLive: onReturnToLive,
                                    playbackKind: playbackKind,
                                    timelineEnabled: timelineEnabled,
                                    playbackTimelineController:
                                        playbackTimelineController,
                                    veryNarrow: layout.veryNarrow,
                                  )
                                : _WideWatchBottomControls(
                                    player: player,
                                    playerRuntime: playerRuntime,
                                    playing: playing,
                                    muted: muted,
                                    volume: volume,
                                    fullscreen: fullscreen,
                                    chatVisible: chatVisible,
                                    showFullscreenButton: showFullscreenButton,
                                    onToggleMute: onToggleMute,
                                    onVolumeChanged: onVolumeChanged,
                                    qualityVariants: qualityVariants,
                                    currentVariant: currentVariant,
                                    onQualityChanged: onQualityChanged,
                                    onToggleChat: onToggleChat,
                                    onToggleFullscreen: onToggleFullscreen,
                                    hasDvrReplay: hasDvrReplay,
                                    hasFullLiveDvr: hasFullLiveDvr,
                                    showLiveEdgeLabel: showLiveEdgeLabel,
                                    liveDvrDuration: liveDvrDuration,
                                    liveDvrStartedAt: liveDvrStartedAt,
                                    onOpenDvrReplayAtPosition:
                                        onOpenDvrReplayAtPosition,
                                    onReturnToLive: onReturnToLive,
                                    playbackKind: playbackKind,
                                    timelineEnabled: timelineEnabled,
                                    playbackTimelineController:
                                        playbackTimelineController,
                                  ),
                          ),
                        );

                        return SizedBox(
                          height: layout.barHeight,
                          child: controlsContent,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _configureTimelineController({
    required Duration playerPosition,
    required Duration playerDuration,
    required bool advancing,
  }) {
    final controller = playbackTimelineController;
    if (controller == null) return;

    final usingLiveTimelineReplay = playerRuntime.usingLiveTimelineReplay;
    final isPlainLive =
        playbackKind == TwitchWatchPlaybackKind.live &&
        !usingLiveTimelineReplay;
    final liveHasReplayStepControls =
        isPlainLive &&
        liveDvrDuration != null &&
        liveDvrDuration! > Duration.zero &&
        onOpenDvrReplayAtPosition != null;
    final isLiveTimeline =
        usingLiveTimelineReplay ||
        liveHasReplayStepControls ||
        showLiveEdgeLabel ||
        playbackKind == TwitchWatchPlaybackKind.liveDvr;

    final mode = isPlainLive && !liveHasReplayStepControls
        ? TwitchPlaybackTimelineMode.live
        : switch (playbackKind) {
            TwitchWatchPlaybackKind.clip => TwitchPlaybackTimelineMode.clip,
            TwitchWatchPlaybackKind.liveDvr =>
              TwitchPlaybackTimelineMode.liveDvr,
            TwitchWatchPlaybackKind.vod => TwitchPlaybackTimelineMode.vod,
            TwitchWatchPlaybackKind.none => TwitchPlaybackTimelineMode.live,
            TwitchWatchPlaybackKind.live =>
              isLiveTimeline
                  ? TwitchPlaybackTimelineMode.liveDvr
                  : TwitchPlaybackTimelineMode.live,
          };
    final duration = isLiveTimeline ? liveDvrDuration : playerDuration;
    final position = isLiveTimeline
        ? usingLiveTimelineReplay
              ? playerRuntime.liveDvrBridgeTimelinePosition
              : duration
        : playerPosition;

    controller.configure(
      mode: mode,
      timelineEnabled:
          timelineEnabled && (!isPlainLive || liveHasReplayStepControls),
      advancing: advancing,
      position: position,
      duration: duration,
    );
  }
}

class _WatchBottomControlBarLayout {
  final bool veryNarrow;
  final bool useCompactLayout;
  final double barHeight;
  final double horizontalPadding;
  final double contentWidth;
  final double contentHeight;

  const _WatchBottomControlBarLayout({
    required this.veryNarrow,
    required this.useCompactLayout,
    required this.barHeight,
    required this.horizontalPadding,
    required this.contentWidth,
    required this.contentHeight,
  });

  factory _WatchBottomControlBarLayout.fromWidth(double width) {
    final veryNarrow = width < 430;
    final useCompactLayout = width < 700;
    const barHeight = 128.0;

    return _WatchBottomControlBarLayout(
      veryNarrow: veryNarrow,
      useCompactLayout: useCompactLayout,
      barHeight: barHeight,
      horizontalPadding: veryNarrow
          ? 4.0
          : useCompactLayout
          ? 7.0
          : 20.0,
      contentWidth: width,
      contentHeight: barHeight,
    );
  }
}

class _WatchBottomControlSurface extends StatelessWidget {
  final double height;
  final Widget child;

  const _WatchBottomControlSurface({required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.only(
      bottomLeft: Radius.circular(TwitchUiRadius.lg),
      bottomRight: Radius.circular(TwitchUiRadius.lg),
    );
    // Clip the real backdrop blur to the dock; foreground controls stay sharp.
    return TwitchPlayerGlassSurface(
      borderRadius: radius,
      border: Border(
        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: SizedBox(height: height, child: child),
    );
  }
}

class _CompactWatchBottomControls extends StatelessWidget {
  final Player player;
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final bool playing;
  final bool muted;
  final double volume;
  final bool fullscreen;
  final bool chatVisible;
  final bool showFullscreenButton;
  final VoidCallback? onToggleMute;
  final ValueChanged<double>? onVolumeChanged;
  final List<TwitchM3u8Variant> qualityVariants;
  final TwitchM3u8Variant? currentVariant;
  final ValueChanged<TwitchM3u8Variant>? onQualityChanged;
  final VoidCallback? onToggleChat;
  final VoidCallback? onToggleFullscreen;
  final bool hasDvrReplay;
  final bool hasFullLiveDvr;
  final bool showLiveEdgeLabel;
  final Duration? liveDvrDuration;
  final DateTime? liveDvrStartedAt;
  final ValueChanged<Duration>? onOpenDvrReplayAtPosition;
  final VoidCallback? onReturnToLive;
  final bool veryNarrow;
  final TwitchWatchPlaybackKind playbackKind;
  final bool timelineEnabled;
  final TwitchPlaybackTimelineController? playbackTimelineController;

  const _CompactWatchBottomControls({
    required this.player,
    required this.playerRuntime,
    required this.playing,
    required this.muted,
    required this.volume,
    required this.fullscreen,
    required this.chatVisible,
    required this.showFullscreenButton,
    required this.onToggleMute,
    required this.onVolumeChanged,
    required this.qualityVariants,
    required this.currentVariant,
    required this.onQualityChanged,
    required this.onToggleChat,
    required this.onToggleFullscreen,
    required this.hasDvrReplay,
    required this.hasFullLiveDvr,
    required this.showLiveEdgeLabel,
    required this.liveDvrDuration,
    required this.liveDvrStartedAt,
    required this.onOpenDvrReplayAtPosition,
    required this.onReturnToLive,
    required this.veryNarrow,
    required this.playbackKind,
    required this.timelineEnabled,
    required this.playbackTimelineController,
  });

  @override
  Widget build(BuildContext context) {
    return _WatchPlaybackStrip(
      player: player,
      playerRuntime: playerRuntime,
      compact: true,
      hasDvrReplay: hasDvrReplay,
      hasFullLiveDvr: hasFullLiveDvr,
      showLiveEdgeLabel: showLiveEdgeLabel,
      liveDvrDuration: liveDvrDuration,
      liveDvrStartedAt: liveDvrStartedAt,
      onOpenDvrReplayAtPosition: onOpenDvrReplayAtPosition,
      onReturnToLive: onReturnToLive,
      playbackKind: playbackKind,
      timelineEnabled: timelineEnabled,
      playbackTimelineController: playbackTimelineController,
      timelineLayoutBuilder: (slider, timeControls) => Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [slider, const SizedBox(height: 29)],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _WatchBottomControlSurface(
              height: 48,
              child: _WatchControlZones(
                left: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PlayPauseButton(
                      player: player,
                      playing: playing,
                      size: veryNarrow ? 26 : 28,
                      dense: true,
                    ),
                  ],
                ),
                center: timeControls,
                right: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerVolumeButton(
                      muted: muted,
                      volume: volume,
                      onToggleMute: onToggleMute,
                      onVolumeChanged: onVolumeChanged,
                    ),
                    SizedBox(width: veryNarrow ? 1 : 4),
                    SizedBox.square(
                      dimension: 36,
                      child: QualityButton(
                        variants: qualityVariants,
                        currentVariant: currentVariant,
                        onChanged: onQualityChanged,
                      ),
                    ),
                    _ChatToggleButton(
                      chatVisible: chatVisible,
                      size: veryNarrow ? 21 : 23,
                      dense: true,
                      onPressed: onToggleChat,
                    ),
                    if (showFullscreenButton)
                      _FullscreenToggleButton(
                        fullscreen: fullscreen,
                        size: veryNarrow ? 23 : 25,
                        dense: true,
                        onPressed: onToggleFullscreen,
                      ),
                    const AndroidPipButton(dense: true, size: 22),
                    PlayerMoreActionsButton(playerRuntime: playerRuntime),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideWatchBottomControls extends StatelessWidget {
  final Player player;
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final bool playing;
  final bool muted;
  final double volume;
  final bool fullscreen;
  final bool chatVisible;
  final bool showFullscreenButton;
  final VoidCallback? onToggleMute;
  final ValueChanged<double>? onVolumeChanged;
  final List<TwitchM3u8Variant> qualityVariants;
  final TwitchM3u8Variant? currentVariant;
  final ValueChanged<TwitchM3u8Variant>? onQualityChanged;
  final VoidCallback? onToggleChat;
  final VoidCallback? onToggleFullscreen;
  final bool hasDvrReplay;
  final bool hasFullLiveDvr;
  final bool showLiveEdgeLabel;
  final Duration? liveDvrDuration;
  final DateTime? liveDvrStartedAt;
  final ValueChanged<Duration>? onOpenDvrReplayAtPosition;
  final VoidCallback? onReturnToLive;
  final TwitchWatchPlaybackKind playbackKind;
  final bool timelineEnabled;
  final TwitchPlaybackTimelineController? playbackTimelineController;

  const _WideWatchBottomControls({
    required this.player,
    required this.playerRuntime,
    required this.playing,
    required this.muted,
    required this.volume,
    required this.fullscreen,
    required this.chatVisible,
    required this.showFullscreenButton,
    required this.onToggleMute,
    required this.onVolumeChanged,
    required this.qualityVariants,
    required this.currentVariant,
    required this.onQualityChanged,
    required this.onToggleChat,
    required this.onToggleFullscreen,
    required this.hasDvrReplay,
    required this.hasFullLiveDvr,
    required this.showLiveEdgeLabel,
    required this.liveDvrDuration,
    required this.liveDvrStartedAt,
    required this.onOpenDvrReplayAtPosition,
    required this.onReturnToLive,
    required this.playbackKind,
    required this.timelineEnabled,
    required this.playbackTimelineController,
  });

  @override
  Widget build(BuildContext context) {
    return _WatchPlaybackStrip(
      player: player,
      playerRuntime: playerRuntime,
      hasDvrReplay: hasDvrReplay,
      hasFullLiveDvr: hasFullLiveDvr,
      showLiveEdgeLabel: showLiveEdgeLabel,
      liveDvrDuration: liveDvrDuration,
      liveDvrStartedAt: liveDvrStartedAt,
      onOpenDvrReplayAtPosition: onOpenDvrReplayAtPosition,
      onReturnToLive: onReturnToLive,
      playbackKind: playbackKind,
      timelineEnabled: timelineEnabled,
      playbackTimelineController: playbackTimelineController,
      timelineLayoutBuilder: (slider, timeControls) => Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [slider, const SizedBox(height: 29)],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _WatchBottomControlSurface(
              height: 48,
              child: _WatchControlZones(
                left: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PlayPauseButton(
                      player: player,
                      playing: playing,
                      size: 26,
                    ),
                  ],
                ),
                center: timeControls,
                right: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerVolumeButton(
                      muted: muted,
                      volume: volume,
                      onToggleMute: onToggleMute,
                      onVolumeChanged: onVolumeChanged,
                    ),
                    SizedBox.square(
                      dimension: 36,
                      child: QualityButton(
                        variants: qualityVariants,
                        currentVariant: currentVariant,
                        onChanged: onQualityChanged,
                      ),
                    ),
                    _ChatToggleButton(
                      chatVisible: chatVisible,
                      size: 23,
                      onPressed: onToggleChat,
                    ),
                    if (showFullscreenButton)
                      _FullscreenToggleButton(
                        fullscreen: fullscreen,
                        size: 25,
                        onPressed: onToggleFullscreen,
                      ),
                    const AndroidPipButton(dense: true, size: 20),
                    PlayerMoreActionsButton(playerRuntime: playerRuntime),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchPlaybackStrip extends StatelessWidget {
  final Player player;
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final bool compact;
  final Widget Function(Widget slider, Widget timeControls)?
  timelineLayoutBuilder;
  final bool hasDvrReplay;
  final bool hasFullLiveDvr;
  final bool showLiveEdgeLabel;
  final Duration? liveDvrDuration;
  final DateTime? liveDvrStartedAt;
  final ValueChanged<Duration>? onOpenDvrReplayAtPosition;
  final VoidCallback? onReturnToLive;
  final TwitchWatchPlaybackKind playbackKind;
  final bool timelineEnabled;
  final TwitchPlaybackTimelineController? playbackTimelineController;

  const _WatchPlaybackStrip({
    required this.player,
    required this.playerRuntime,
    this.compact = false,
    this.timelineLayoutBuilder,
    required this.hasDvrReplay,
    required this.hasFullLiveDvr,
    required this.showLiveEdgeLabel,
    required this.liveDvrDuration,
    required this.liveDvrStartedAt,
    required this.onOpenDvrReplayAtPosition,
    required this.onReturnToLive,
    required this.playbackKind,
    required this.timelineEnabled,
    required this.playbackTimelineController,
  });

  @override
  Widget build(BuildContext context) {
    if (playerRuntime.usingExternalVodPlayback) {
      final useLiveTimeline = playbackKind == TwitchWatchPlaybackKind.liveDvr;
      return TwitchVodPlaybackStrip(
        player: player,
        fullWidthTimeline: true,
        timelineLayoutBuilder: timelineLayoutBuilder,
        timelineController: playbackTimelineController,
        compact: compact,
        showLiveEdgeLabel: useLiveTimeline && showLiveEdgeLabel,
        liveTimelineDuration: useLiveTimeline ? liveDvrDuration : null,
        liveTimelineStartedAt: useLiveTimeline ? liveDvrStartedAt : null,
        liveSeekWindowDuration: useLiveTimeline && !hasFullLiveDvr
            ? _liveSeekWindowDuration
            : null,
        playbackKind: playbackKind,
        onOpenDvrReplayAtPosition: useLiveTimeline
            ? onOpenDvrReplayAtPosition
            : null,
        onReturnToLive: useLiveTimeline ? onReturnToLive : null,
        timelineEnabled: timelineEnabled,
      );
    }

    if (hasDvrReplay) {
      final usingLiveTimelineReplay = playerRuntime.usingLiveTimelineReplay;
      return TwitchVodPlaybackStrip(
        player: player,
        fullWidthTimeline: true,
        timelineLayoutBuilder: timelineLayoutBuilder,
        timelineController: playbackTimelineController,
        compact: compact,
        showLiveEdgeLabel: true,
        forceLiveEdge: !usingLiveTimelineReplay,
        liveTimelineDuration: liveDvrDuration,
        liveTimelineStartedAt: liveDvrStartedAt,
        liveSeekWindowDuration: !hasFullLiveDvr
            ? _liveSeekWindowDuration
            : null,
        timelinePosition: usingLiveTimelineReplay
            ? playerRuntime.liveDvrBridgeTimelinePosition
            : liveDvrDuration,
        playbackKind: playbackKind,
        onOpenDvrReplayAtPosition: onOpenDvrReplayAtPosition,
        onReturnToLive: onReturnToLive,
        timelineEnabled: timelineEnabled,
      );
    }

    return TwitchVodPlaybackStrip(
      player: player,
      fullWidthTimeline: true,
      timelineLayoutBuilder: timelineLayoutBuilder,
      timelineController: playbackTimelineController,
      compact: compact,
      showLiveEdgeLabel: true,
      forceLiveEdge: true,
      liveTimelineDuration: liveDvrDuration,
      liveTimelineStartedAt: liveDvrStartedAt,
      timelinePosition: liveDvrDuration,
      playbackKind: TwitchWatchPlaybackKind.live,
      onOpenDvrReplayAtPosition: onOpenDvrReplayAtPosition,
      onReturnToLive: onReturnToLive,
      timelineEnabled: false,
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final Player player;
  final bool playing;
  final double size;
  final bool dense;

  const _PlayPauseButton({
    required this.player,
    required this.playing,
    required this.size,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return PlainIconButton(
      controlSize: 36,
      tooltip: context.vio.t(playing ? '暫停' : '播放'),
      icon: playing ? Icons.pause : Icons.play_arrow,
      size: size,
      dense: dense,
      onPressed: () {
        unawaited(playing ? player.pause() : player.play());
      },
    );
  }
}

class _ChatToggleButton extends StatelessWidget {
  final bool chatVisible;
  final double size;
  final bool dense;
  final VoidCallback? onPressed;

  const _ChatToggleButton({
    required this.chatVisible,
    required this.size,
    required this.onPressed,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return PlainIconButton(
      controlSize: 36,
      tooltip: context.vio.t(chatVisible ? '隱藏聊天室' : '顯示聊天室'),
      icon: chatVisible ? Icons.chat_bubble : Icons.chat_bubble_outline,
      size: size,
      active: chatVisible,
      dense: dense,
      onPressed: onPressed,
    );
  }
}

class _FullscreenToggleButton extends StatelessWidget {
  final bool fullscreen;
  final double size;
  final bool dense;
  final VoidCallback? onPressed;

  const _FullscreenToggleButton({
    required this.fullscreen,
    required this.size,
    required this.onPressed,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return PlainIconButton(
      controlSize: 36,
      tooltip: context.vio.t(fullscreen ? '離開全螢幕' : '全螢幕'),
      icon: fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
      size: size,
      active: fullscreen,
      dense: dense,
      onPressed: onPressed,
    );
  }
}

/// Centers the time when possible, shifting it left before clipping controls.
class _WatchControlZones extends StatelessWidget {
  final Widget left;
  final Widget center;
  final Widget right;
  const _WatchControlZones({
    required this.left,
    required this.center,
    required this.right,
  });

  @override
  Widget build(BuildContext context) => CustomMultiChildLayout(
    delegate: _WatchControlZoneLayout(),
    children: [
      LayoutId(
        id: _ControlZone.left,
        child: SingleChildScrollView(
          key: const ValueKey('player-control-left'),
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.hardEdge,
          child: left,
        ),
      ),
      LayoutId(
        id: _ControlZone.center,
        child: FittedBox(fit: BoxFit.scaleDown, child: center),
      ),
      LayoutId(
        id: _ControlZone.right,
        child: SingleChildScrollView(
          key: const ValueKey('player-control-right'),
          scrollDirection: Axis.horizontal,
          reverse: true,
          clipBehavior: Clip.hardEdge,
          child: right,
        ),
      ),
    ],
  );
}

enum _ControlZone { left, center, right }

class _WatchControlZoneLayout extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    final left = layoutChild(
      _ControlZone.left,
      BoxConstraints(maxWidth: size.width * 0.25, maxHeight: size.height),
    );
    // Reserve readable time space on small screens; only clip side controls
    // once their combined natural widths genuinely exceed the whole dock.
    final timeReserve = size.width < 256 ? size.width * 0.25 : 64.0;
    final right = layoutChild(
      _ControlZone.right,
      BoxConstraints(
        maxWidth: (size.width - left.width - 18 - timeReserve).clamp(
          0.0,
          size.width,
        ),
        maxHeight: size.height,
      ),
    );
    final center = layoutChild(
      _ControlZone.center,
      BoxConstraints(
        maxWidth: (size.width - left.width - right.width - 18).clamp(
          0.0,
          size.width,
        ),
        maxHeight: size.height,
      ),
    );
    final minimumX = left.width + 6;
    final maximumX = (size.width - right.width - 12 - center.width).clamp(
      minimumX,
      size.width,
    );
    final centerX = ((size.width - center.width) / 2).clamp(minimumX, maximumX);
    positionChild(
      _ControlZone.left,
      Offset(0, (size.height - left.height) / 2),
    );
    positionChild(
      _ControlZone.center,
      Offset(centerX, (size.height - center.height) / 2),
    );
    positionChild(
      _ControlZone.right,
      Offset(size.width - right.width, (size.height - right.height) / 2),
    );
  }

  @override
  bool shouldRelayout(covariant _WatchControlZoneLayout oldDelegate) => false;
}
