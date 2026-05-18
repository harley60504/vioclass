// PATCH VERSION: twitch_watch_top_action_bar_stage219f_player_stop_only

part of twitch_watch_player_area;

class _WatchTopActionBar extends StatelessWidget {
  final TwitchStreamHeaderMetadata metadata;
  final bool isFollowing;
  final bool followBusy;
  final Player player;
  final VoidCallback onBack;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onSubscribe;
  final VoidCallback? onReload;
  final VoidCallback onStop;

  const _WatchTopActionBar({
    required this.metadata,
    required this.isFollowing,
    required this.followBusy,
    required this.player,
    required this.onBack,
    required this.onToggleFollow,
    required this.onSubscribe,
    required this.onReload,
    required this.onStop,
  });

  Future<void> _pauseThenBack() async {
    try {
      await player.pause();
    } catch (_) {}
    onBack();
  }

  Future<void> _stopPlaybackOnly() async {
    try {
      await player.stop();
    } catch (_) {
      try {
        await player.pause();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final actionTiny = constraints.maxWidth < 430;
        final actionGap = actionTiny ? 6.0 : 9.0;

        // Stage 101: keep every visible item in the top action bar at the
        // same visual height. This avoids the 1px bottom overflow caused by
        // the info card having a different internal height from the buttons.
        final slotHeight = compact ? 62.0 : 78.0;
        final controlHeight = compact ? 52.0 : 72.0;

        final infoCard = _WatchStreamHeaderCard(
          metadata: metadata,
          compact: compact,
          height: controlHeight,
        );

        final actionButtons = <Widget>[
          _FollowButton(
            followed: isFollowing,
            busy: followBusy,
            compact: compact,
            tiny: actionTiny,
            height: controlHeight,
            onPressed: onToggleFollow,
          ),
          SizedBox(width: actionGap),
          _SubscribeButton(
            compact: compact,
            tiny: actionTiny,
            height: controlHeight,
            onPressed: onSubscribe,
          ),
          SizedBox(width: actionGap),
          _RoundIconButton(
            tooltip: '重新載入',
            icon: Icons.refresh,
            iconColor: const Color(0xFFA78BFA),
            backgroundColor: const Color(0xFF4C1D95).withOpacity(0.22),
            borderColor: const Color(0xFFA78BFA).withOpacity(0.24),
            glowOpacity: 0.20,
            compact: compact,
            tiny: actionTiny,
            height: controlHeight,
            onPressed: onReload,
          ),
          SizedBox(width: actionGap),
          _RoundIconButton(
            tooltip: '停止播放',
            icon: Icons.close,
            iconColor: const Color(0xFFFF6B81),
            backgroundColor: const Color(0xFF7F1D1D).withOpacity(0.24),
            borderColor: const Color(0xFFFF6B81).withOpacity(0.26),
            glowOpacity: 0.20,
            compact: compact,
            tiny: actionTiny,
            height: controlHeight,
            onPressed: () => unawaited(_stopPlaybackOnly()),
          ),
        ];

        Widget content;
        double designWidth;

        if (compact) {
          designWidth = actionTiny ? 470 : 570;
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _RoundIconButton(
                tooltip: '返回',
                icon: Icons.arrow_back,
                iconColor: const Color(0xFF93C5FD),
                backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.20),
                borderColor: const Color(0xFF93C5FD).withOpacity(0.22),
                glowOpacity: 0.18,
                compact: true,
                tiny: actionTiny,
                height: controlHeight,
                onPressed: () => unawaited(_pauseThenBack()),
              ),
              SizedBox(width: actionGap),
              _WatchCompactAvatarTile(
                metadata: metadata,
                tiny: actionTiny,
                height: controlHeight,
              ),
              const Spacer(),
              SizedBox(width: actionGap),
              ...actionButtons,
            ],
          );
        } else {
          designWidth = 1040;
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _RoundIconButton(
                tooltip: '返回',
                icon: Icons.arrow_back,
                iconColor: const Color(0xFF93C5FD),
                backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.20),
                borderColor: const Color(0xFF93C5FD).withOpacity(0.22),
                glowOpacity: 0.18,
                height: controlHeight,
                onPressed: () => unawaited(_pauseThenBack()),
              ),
              const SizedBox(width: 10),
              Expanded(child: infoCard),
              const SizedBox(width: 12),
              ...actionButtons,
            ],
          );
        }

        // Stage 102: keep full-width behavior, but restore the top-bar
        // scaleDown safety net for every breakpoint. If the viewport is
        // narrower than the designed row, shrink the whole row instead of
        // letting fixed-height buttons/info cards overflow. When there is
        // enough space, use the full available width so the info card stretches.
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : designWidth;
        final shouldScaleDown = availableWidth < designWidth;

        if (!shouldScaleDown) {
          return SizedBox(
            width: double.infinity,
            height: slotHeight,
            child: content,
          );
        }

        return SizedBox(
          width: double.infinity,
          height: slotHeight,
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: designWidth,
                  height: slotHeight,
                  child: Center(child: content),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}