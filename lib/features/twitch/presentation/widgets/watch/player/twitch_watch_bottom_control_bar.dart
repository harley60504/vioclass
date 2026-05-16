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
            final barHeight = useCompactLayout ? 58.0 : 72.0;
            final horizontalPadding = veryNarrow ? 4.0 : useCompactLayout ? 7.0 : 20.0;

            final compactDesignWidth = veryNarrow ? 430.0 : 620.0;
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
