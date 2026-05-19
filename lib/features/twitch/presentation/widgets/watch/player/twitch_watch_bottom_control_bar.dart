part of twitch_watch_player_area;

class _WatchBottomControlBar extends StatelessWidget {
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

  const _WatchBottomControlBar({
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
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (context, playingSnapshot) {
        final playing = playingSnapshot.data ?? false;

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
                      ),
              ),
            );

            return _WatchBottomControlSurface(
              height: layout.barHeight,
              child: layout.useCompactLayout
                  ? ClipRect(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: controlsContent,
                      ),
                    )
                  : controlsContent,
            );
          },
        );
      },
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
    final barHeight = useCompactLayout ? 58.0 : 72.0;

    return _WatchBottomControlBarLayout(
      veryNarrow: veryNarrow,
      useCompactLayout: useCompactLayout,
      barHeight: barHeight,
      horizontalPadding: veryNarrow ? 4.0 : useCompactLayout ? 7.0 : 20.0,
      contentWidth: useCompactLayout ? (veryNarrow ? 390.0 : 620.0) : width,
      contentHeight: useCompactLayout ? 58.0 : barHeight,
    );
  }
}

class _WatchBottomControlSurface extends StatelessWidget {
  final double height;
  final Widget child;

  const _WatchBottomControlSurface({
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TwitchGlassSurface(
      borderRadius: BorderRadius.circular(24),
      backgroundColor: Colors.black.withOpacity(0.56),
      borderColor: Colors.white.withOpacity(0.12),
      blurSigma: 0,
      boxShadow: const <BoxShadow>[],
      child: SizedBox(
        height: height,
        child: child,
      ),
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
  final bool veryNarrow;

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
    required this.veryNarrow,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PlayPauseButton(
          player: player,
          playing: playing,
          size: veryNarrow ? 26 : 28,
          dense: true,
        ),
        SizedBox(width: veryNarrow ? 2 : 6),
        if (veryNarrow) ...[
          _LivePlaybackSheetButton(
            player: player,
            playerRuntime: playerRuntime,
          ),
          const Spacer(),
        ] else ...[
          Expanded(
            child: TwitchLivePlaybackStrip(
              player: player,
              playerRuntime: playerRuntime,
              compact: true,
            ),
          ),
        ],
        SizedBox(width: veryNarrow ? 2 : 6),
        _CompactInlineVolumeControl(
          muted: muted,
          volume: volume,
          sliderWidth: veryNarrow ? 50 : 76,
          onToggleMute: onToggleMute,
          onVolumeChanged: onVolumeChanged,
        ),
        SizedBox(width: veryNarrow ? 1 : 4),
        QualityButton(
          variants: qualityVariants,
          currentVariant: currentVariant,
          onChanged: onQualityChanged,
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
        const _AndroidPipButton(
          dense: true,
          size: 22,
        ),
        PlayerMoreActionsButton(playerRuntime: playerRuntime),
      ],
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
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PlayPauseButton(
          player: player,
          playing: playing,
          size: 32,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TwitchLivePlaybackStrip(
            player: player,
            playerRuntime: playerRuntime,
          ),
        ),
        const SizedBox(width: 16),
        _WideVolumeControl(
          muted: muted,
          volume: volume,
          onToggleMute: onToggleMute,
          onVolumeChanged: onVolumeChanged,
        ),
        QualityButton(
          variants: qualityVariants,
          currentVariant: currentVariant,
          onChanged: onQualityChanged,
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
        const _AndroidPipButton(size: 23),
        PlayerMoreActionsButton(playerRuntime: playerRuntime),
      ],
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
    return _PlainIconButton(
      tooltip: playing ? '暫停' : '播放',
      icon: playing ? Icons.pause : Icons.play_arrow,
      size: size,
      dense: dense,
      onPressed: () {
        unawaited(playing ? player.pause() : player.play());
      },
    );
  }
}

class _WideVolumeControl extends StatelessWidget {
  final bool muted;
  final double volume;
  final VoidCallback? onToggleMute;
  final ValueChanged<double>? onVolumeChanged;

  const _WideVolumeControl({
    required this.muted,
    required this.volume,
    required this.onToggleMute,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlainIconButton(
          tooltip: muted ? '取消靜音' : '靜音',
          icon: muted || volume <= 0 ? Icons.volume_off : Icons.volume_up,
          size: 24,
          onPressed: onToggleMute,
        ),
        SizedBox(
          width: 92,
          child: Slider(
            value: volume.clamp(0.0, 100.0).toDouble(),
            min: 0,
            max: 100,
            onChanged: onVolumeChanged,
          ),
        ),
      ],
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
    return _PlainIconButton(
      tooltip: chatVisible ? '隱藏聊天室' : '顯示聊天室',
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
    return _PlainIconButton(
      tooltip: fullscreen ? '離開全螢幕' : '全螢幕',
      icon: fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
      size: size,
      active: fullscreen,
      dense: dense,
      onPressed: onPressed,
    );
  }
}

class _LivePlaybackSheetButton extends StatelessWidget {
  final Player player;
  final TwitchPlaylistPlayerRuntime playerRuntime;

  const _LivePlaybackSheetButton({
    required this.player,
    required this.playerRuntime,
  });

  void _showPlaybackSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: false,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        final screenWidth = MediaQuery.of(sheetContext).size.width;
        final sheetWidth = screenWidth.clamp(280.0, 520.0).toDouble();

        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TwitchGlassSurface(
              borderRadius: BorderRadius.circular(22),
              backgroundColor: Colors.black.withOpacity(0.56),
              borderColor: Colors.white.withOpacity(0.13),
              blurSigma: 0,
              boxShadow: const <BoxShadow>[],
              child: SizedBox(
                width: sheetWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.timeline_rounded,
                            color: Color(0xFFBF94FF),
                            size: 17,
                          ),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              '播放進度',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => Navigator.of(sheetContext).maybePop(),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white54,
                                size: 19,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TwitchLivePlaybackStrip(
                        player: player,
                        playerRuntime: playerRuntime,
                        compact: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PlainIconButton(
      tooltip: '打開播放進度',
      icon: Icons.timeline_rounded,
      size: 22,
      dense: true,
      onPressed: () => _showPlaybackSheet(context),
    );
  }
}
