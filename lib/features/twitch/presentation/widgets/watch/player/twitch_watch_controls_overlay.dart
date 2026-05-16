part of twitch_watch_player_area;

class _WatchControlsOverlay extends StatefulWidget {
  final bool loading;
  final String? error;
  final Object? runtimeError;
  final TwitchStreamHeaderMetadata metadata;
  final bool isFollowing;
  final bool followBusy;
  final VoidCallback onBack;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onSubscribe;
  final VoidCallback? onReload;
  final VoidCallback onStop;
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

  const _WatchControlsOverlay({
    required this.loading,
    required this.error,
    required this.runtimeError,
    required this.metadata,
    required this.isFollowing,
    required this.followBusy,
    required this.onBack,
    required this.onToggleFollow,
    required this.onSubscribe,
    required this.onReload,
    required this.onStop,
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
  State<_WatchControlsOverlay> createState() => _WatchControlsOverlayState();
}

class _WatchControlsOverlayState extends State<_WatchControlsOverlay> {
  bool _visible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant _WatchControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading || widget.error != null || widget.runtimeError != null) {
      _showAndHold();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (widget.loading || widget.error != null || widget.runtimeError != null) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _visible = false);
    });
  }

  void _showAndHold() {
    _hideTimer?.cancel();
    if (!_visible && mounted) {
      setState(() => _visible = true);
    }
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showAndHold(),
      onHover: (_) => _showAndHold(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _showAndHold,
        child: Stack(
          children: [
            Positioned.fill(
              child: _PlayerDimOverlay(visible: widget.loading),
            ),
            IgnorePointer(
              ignoring: !_visible,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: Stack(
                  children: [
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 12,
                      child: _WatchTopActionBar(
                        metadata: widget.metadata,
                        isFollowing: widget.isFollowing,
                        followBusy: widget.followBusy,
                        onBack: widget.onBack,
                        onToggleFollow: widget.onToggleFollow,
                        onSubscribe: widget.onSubscribe,
                        onReload: widget.onReload,
                        onStop: widget.onStop,
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: SafeArea(
                        top: false,
                        minimum: const EdgeInsets.only(bottom: 2),
                        child: _WatchBottomControlBar(
                          player: widget.player,
                          playerRuntime: widget.playerRuntime,
                          muted: widget.muted,
                          volume: widget.volume,
                          fullscreen: widget.fullscreen,
                          chatVisible: widget.chatVisible,
                          showFullscreenButton: widget.showFullscreenButton,
                          onToggleMute: widget.onToggleMute,
                          onVolumeChanged: widget.onVolumeChanged,
                          qualityVariants: widget.qualityVariants,
                          currentVariant: widget.currentVariant,
                          onQualityChanged: widget.onQualityChanged,
                          onToggleChat: widget.onToggleChat,
                          onToggleFullscreen: widget.onToggleFullscreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.error != null && widget.error!.trim().isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 88,
                child: _ErrorCard(message: widget.error!),
              ),
            if (widget.runtimeError != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 88,
                child: _ErrorCard(message: widget.runtimeError.toString()),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerDimOverlay extends StatelessWidget {
  final bool visible;

  const _PlayerDimOverlay({required this.visible});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return const ColoredBox(
      color: Color(0x66000000),
      child: Center(
        child: CircularProgressIndicator(color: Color(0xFF9146FF)),
      ),
    );
  }
}
