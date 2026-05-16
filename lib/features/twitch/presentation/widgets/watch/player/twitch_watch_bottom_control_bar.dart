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
            final veryNarrow = constraints.maxWidth < 430;
            final useCompactLayout = constraints.maxWidth < 700;
            final collapseLivePlayback = veryNarrow;
            final barHeight = useCompactLayout ? 58.0 : 72.0;
            final horizontalPadding = veryNarrow ? 4.0 : useCompactLayout ? 7.0 : 20.0;

            final compactDesignWidth = veryNarrow ? 360.0 : 620.0;
            final compactDesignHeight = 58.0;
            final contentWidth = useCompactLayout ? compactDesignWidth : constraints.maxWidth;
            final contentHeight = useCompactLayout ? compactDesignHeight : barHeight;

            final controlsContent = SizedBox(
              width: contentWidth,
              height: contentHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: useCompactLayout
                    ? Row(
                        children: [
                          _PlainIconButton(
                            tooltip: playing ? '暫停' : '播放',
                            icon: playing ? Icons.pause : Icons.play_arrow,
                            size: veryNarrow ? 26 : 28,
                            dense: true,
                            onPressed: () {
                              unawaited(playing ? player.pause() : player.play());
                            },
                          ),
                          SizedBox(width: veryNarrow ? 2 : 6),
                          if (collapseLivePlayback)
                            _LivePlaybackOverlayButton(
                              player: player,
                              playerRuntime: playerRuntime,
                            )
                          else
                            Expanded(
                              child: TwitchLivePlaybackStrip(
                                player: player,
                                playerRuntime: playerRuntime,
                                compact: true,
                              ),
                            ),
                          SizedBox(width: veryNarrow ? 2 : 6),
                          _CompactInlineVolumeControl(
                            muted: muted,
                            volume: volume,
                            sliderWidth: veryNarrow ? 54 : 76,
                            onToggleMute: onToggleMute,
                            onVolumeChanged: onVolumeChanged,
                          ),
                          if (!veryNarrow) ...[
                            const SizedBox(width: 4),
                            _QualityButton(
                              variants: qualityVariants,
                              currentVariant: currentVariant,
                              onChanged: onQualityChanged,
                            ),
                          ],
                          _PlainIconButton(
                            tooltip: chatVisible ? '隱藏聊天室' : '顯示聊天室',
                            icon: chatVisible
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            size: veryNarrow ? 21 : 23,
                            active: chatVisible,
                            dense: true,
                            onPressed: onToggleChat,
                          ),
                          if (showFullscreenButton)
                            _PlainIconButton(
                              tooltip: fullscreen ? '離開全螢幕' : '全螢幕',
                              icon: fullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              size: veryNarrow ? 23 : 25,
                              active: fullscreen,
                              dense: true,
                              onPressed: onToggleFullscreen,
                            ),
                          _PlayerMoreActionsButton(playerRuntime: playerRuntime),
                        ],
                      )
                    : Row(
                        children: [
                          _PlainIconButton(
                            tooltip: playing ? '暫停' : '播放',
                            icon: playing ? Icons.pause : Icons.play_arrow,
                            size: 32,
                            onPressed: () {
                              unawaited(playing ? player.pause() : player.play());
                            },
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TwitchLivePlaybackStrip(
                              player: player,
                              playerRuntime: playerRuntime,
                            ),
                          ),
                          const SizedBox(width: 16),
                          _PlainIconButton(
                            tooltip: muted ? '取消靜音' : '靜音',
                            icon: muted || volume <= 0
                                ? Icons.volume_off
                                : Icons.volume_up,
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
                          _QualityButton(
                            variants: qualityVariants,
                            currentVariant: currentVariant,
                            onChanged: onQualityChanged,
                          ),
                          _PlainIconButton(
                            tooltip: chatVisible ? '隱藏聊天室' : '顯示聊天室',
                            icon: chatVisible
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            size: 23,
                            active: chatVisible,
                            onPressed: onToggleChat,
                          ),
                          if (showFullscreenButton)
                            _PlainIconButton(
                              tooltip: fullscreen ? '離開全螢幕' : '全螢幕',
                              icon: fullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              size: 25,
                              active: fullscreen,
                              onPressed: onToggleFullscreen,
                            ),
                          _PlayerMoreActionsButton(playerRuntime: playerRuntime),
                        ],
                      ),
              ),
            );

            return Container(
              height: barHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xEE0E0E10),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: useCompactLayout
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

class _LivePlaybackOverlayButton extends StatefulWidget {
  final Player player;
  final TwitchPlaylistPlayerRuntime playerRuntime;

  const _LivePlaybackOverlayButton({
    required this.player,
    required this.playerRuntime,
  });

  @override
  State<_LivePlaybackOverlayButton> createState() =>
      _LivePlaybackOverlayButtonState();
}

class _LivePlaybackOverlayButtonState extends State<_LivePlaybackOverlayButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  bool get _showingOverlay => _overlayEntry != null;

  @override
  void dispose() {
    _removeOverlay(notify: false);
    super.dispose();
  }

  void _toggleOverlay() {
    if (_showingOverlay) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (overlayContext) {
        final screenWidth = MediaQuery.of(overlayContext).size.width;
        final overlayWidth = math
            .min(screenWidth - 24.0, 420.0)
            .clamp(280.0, 420.0)
            .toDouble();

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topCenter,
              followerAnchor: Alignment.bottomCenter,
              offset: const Offset(0, -12),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: overlayWidth,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xF20E0E10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.timeline_rounded,
                            color: Color(0xFFBF94FF),
                            size: 16,
                          ),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              '播放進度',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: _removeOverlay,
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white54,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TwitchLivePlaybackStrip(
                        player: widget.player,
                        playerRuntime: widget.playerRuntime,
                        compact: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    _overlayEntry = entry;
    overlay.insert(entry);
    if (mounted) setState(() {});
  }

  void _removeOverlay({bool notify = true}) {
    final entry = _overlayEntry;
    _overlayEntry = null;
    entry?.remove();
    if (notify && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: _PlainIconButton(
        tooltip: _showingOverlay ? '關閉播放進度' : '打開播放進度',
        icon: Icons.timeline_rounded,
        size: 22,
        active: _showingOverlay,
        dense: true,
        onPressed: _toggleOverlay,
      ),
    );
  }
}
