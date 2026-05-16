part of twitch_watch_player_area;

class _WatchTopActionBar extends StatelessWidget {
  final TwitchStreamHeaderMetadata metadata;
  final bool isFollowing;
  final bool followBusy;
  final VoidCallback onBack;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onSubscribe;
  final VoidCallback? onReload;
  final VoidCallback onStop;

  const _WatchTopActionBar({
    required this.metadata,
    required this.isFollowing,
    required this.followBusy,
    required this.onBack,
    required this.onToggleFollow,
    required this.onSubscribe,
    required this.onReload,
    required this.onStop,
  });

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
            compact: compact,
            tiny: actionTiny,
            height: controlHeight,
            onPressed: onReload,
          ),
          SizedBox(width: actionGap),
          _RoundIconButton(
            tooltip: '停止',
            icon: Icons.close,
            iconColor: Colors.redAccent,
            compact: compact,
            tiny: actionTiny,
            height: controlHeight,
            onPressed: onStop,
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
                compact: true,
                tiny: actionTiny,
                height: controlHeight,
                onPressed: onBack,
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
                height: controlHeight,
                onPressed: onBack,
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
