import 'package:flutter/material.dart';

import '../../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../../localization/vioclass_localizations.dart';
import '../../../theme/twitch_ui_tokens.dart';
import 'twitch_player_common_buttons.dart';
import 'twitch_watch_stream_header.dart';
import 'twitch_watch_top_buttons.dart';

class WatchTopActionBar extends StatelessWidget {
  final TwitchStreamHeaderMetadata metadata;
  final bool isFollowing;
  final bool followBusy;
  final VoidCallback onBack;
  final VoidCallback? onHome;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onSubscribe;
  final VoidCallback? onOpenChannel;
  final VoidCallback? onCreateClip;
  final bool creatingClip;

  const WatchTopActionBar({
    super.key,
    required this.metadata,
    required this.isFollowing,
    required this.followBusy,
    required this.onBack,
    this.onHome,
    required this.onToggleFollow,
    required this.onSubscribe,
    this.onOpenChannel,
    this.onCreateClip,
    this.creatingClip = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _WatchTopActionBarMetrics.fromWidth(
          constraints.maxWidth,
        );
        final actions = _WatchTopActionButtons(
          metadata: metadata,
          isFollowing: isFollowing,
          followBusy: followBusy,
          metrics: metrics,
          onBack: onBack,
          onHome: onHome,
          onToggleFollow: onToggleFollow,
          onSubscribe: onSubscribe,
          onOpenChannel: onOpenChannel,
          onCreateClip: onCreateClip,
          creatingClip: creatingClip,
        );

        final content = metrics.compact
            ? _CompactWatchTopActionContent(
                metrics: metrics,
                actions: actions,
                metadata: metadata,
                onOpenChannel: onOpenChannel,
              )
            : _WideWatchTopActionContent(
                metrics: metrics,
                actions: actions,
                metadata: metadata,
                onOpenChannel: onOpenChannel,
              );

        return _ScaledWatchTopActionSlot(
          metrics: metrics,
          availableWidth: constraints.maxWidth,
          child: content,
        );
      },
    );
  }
}

class _WatchTopActionBarMetrics {
  final bool compact;
  final bool tiny;
  final double actionGap;
  final double slotHeight;
  final double controlHeight;
  final double designWidth;

  const _WatchTopActionBarMetrics({
    required this.compact,
    required this.tiny,
    required this.actionGap,
    required this.slotHeight,
    required this.controlHeight,
    required this.designWidth,
  });

  factory _WatchTopActionBarMetrics.fromWidth(double width) {
    final compact = width < 680;
    final tiny = width < 430;

    return _WatchTopActionBarMetrics(
      compact: compact,
      tiny: tiny,
      actionGap: tiny ? 6.0 : 9.0,
      slotHeight: compact ? 62.0 : 78.0,
      controlHeight: compact ? 52.0 : 72.0,
      designWidth: compact ? (tiny ? 470.0 : 570.0) : 1040.0,
    );
  }
}

class _WatchTopActionButtons {
  final TwitchStreamHeaderMetadata metadata;
  final bool isFollowing;
  final bool followBusy;
  final _WatchTopActionBarMetrics metrics;
  final VoidCallback onBack;
  final VoidCallback? onHome;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onSubscribe;
  final VoidCallback? onOpenChannel;
  final VoidCallback? onCreateClip;
  final bool creatingClip;

  const _WatchTopActionButtons({
    required this.metadata,
    required this.isFollowing,
    required this.followBusy,
    required this.metrics,
    required this.onBack,
    required this.onHome,
    required this.onToggleFollow,
    required this.onSubscribe,
    required this.onOpenChannel,
    required this.onCreateClip,
    required this.creatingClip,
  });

  Widget buildBackButton(BuildContext context) {
    return RoundIconButton(
      tooltip: context.vio.t('返回'),
      icon: Icons.arrow_back,
      iconColor: const Color(0xFF93C5FD),
      backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.20),
      borderColor: const Color(0xFF93C5FD).withValues(alpha: 0.22),
      glowOpacity: 0.18,
      compact: metrics.compact,
      tiny: metrics.tiny,
      height: metrics.controlHeight,
      onPressed: onBack,
    );
  }

  Widget buildHomeButton(BuildContext context) {
    return RoundIconButton(
      tooltip: context.vio.t('回主畫面'),
      icon: Icons.home_rounded,
      iconColor: const Color(0xFFE9D5FF),
      backgroundColor: const Color(0xFF4C1D95).withValues(alpha: 0.22),
      borderColor: TwitchUiColors.primarySoft.withValues(alpha: 0.22),
      glowOpacity: 0.14,
      compact: metrics.compact,
      tiny: metrics.tiny,
      height: metrics.controlHeight,
      onPressed: onHome,
    );
  }

  List<Widget> buildRightActions() {
    return <Widget>[
      ChannelLibraryButton(
        compact: metrics.compact,
        tiny: metrics.tiny,
        height: metrics.controlHeight,
        onPressed: onOpenChannel,
      ),
      SizedBox(width: metrics.actionGap),
      CreateClipButton(
        compact: metrics.compact,
        tiny: metrics.tiny,
        height: metrics.controlHeight,
        busy: creatingClip,
        onPressed: onCreateClip,
      ),
      SizedBox(width: metrics.actionGap),
      FollowButton(
        followed: isFollowing,
        busy: followBusy,
        compact: metrics.compact,
        tiny: metrics.tiny,
        height: metrics.controlHeight,
        onPressed: onToggleFollow,
      ),
      SizedBox(width: metrics.actionGap),
      SubscribeButton(
        compact: metrics.compact,
        tiny: metrics.tiny,
        height: metrics.controlHeight,
        onPressed: onSubscribe,
      ),
    ];
  }
}

class _CompactWatchTopActionContent extends StatelessWidget {
  final _WatchTopActionBarMetrics metrics;
  final _WatchTopActionButtons actions;
  final TwitchStreamHeaderMetadata metadata;
  final VoidCallback? onOpenChannel;

  const _CompactWatchTopActionContent({
    required this.metrics,
    required this.actions,
    required this.metadata,
    required this.onOpenChannel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        actions.buildBackButton(context),
        SizedBox(width: metrics.actionGap),
        actions.buildHomeButton(context),
        SizedBox(width: metrics.actionGap),
        WatchCompactAvatarTile(
          metadata: metadata,
          tiny: metrics.tiny,
          height: metrics.controlHeight,
          onOpenChannel: onOpenChannel,
        ),
        const Spacer(),
        SizedBox(width: metrics.actionGap),
        ...actions.buildRightActions(),
      ],
    );
  }
}

class _WideWatchTopActionContent extends StatelessWidget {
  final _WatchTopActionBarMetrics metrics;
  final _WatchTopActionButtons actions;
  final TwitchStreamHeaderMetadata metadata;
  final VoidCallback? onOpenChannel;

  const _WideWatchTopActionContent({
    required this.metrics,
    required this.actions,
    required this.metadata,
    required this.onOpenChannel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        actions.buildBackButton(context),
        const SizedBox(width: 10),
        actions.buildHomeButton(context),
        const SizedBox(width: 10),
        Expanded(
          child: WatchStreamHeaderCard(
            metadata: metadata,
            compact: false,
            height: metrics.controlHeight,
            onOpenChannel: onOpenChannel,
          ),
        ),
        const SizedBox(width: 12),
        ...actions.buildRightActions(),
      ],
    );
  }
}

class _ScaledWatchTopActionSlot extends StatelessWidget {
  final _WatchTopActionBarMetrics metrics;
  final double availableWidth;
  final Widget child;

  const _ScaledWatchTopActionSlot({
    required this.metrics,
    required this.availableWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final safeAvailableWidth = availableWidth.isFinite
        ? availableWidth
        : metrics.designWidth;
    final shouldScaleDown = safeAvailableWidth < metrics.designWidth;

    if (!shouldScaleDown) {
      return SizedBox(
        width: double.infinity,
        height: metrics.slotHeight,
        child: child,
      );
    }

    return SizedBox(
      width: double.infinity,
      height: metrics.slotHeight,
      child: ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: metrics.designWidth,
              height: metrics.slotHeight,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
