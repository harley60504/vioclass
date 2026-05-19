import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../models/discovery/twitch_stream_header_metadata.dart';
import 'twitch_player_common_buttons.dart';
import 'twitch_watch_stream_header.dart';
import 'twitch_watch_top_buttons.dart';

class WatchTopActionBar extends StatelessWidget {
  final TwitchStreamHeaderMetadata metadata;
  final bool isFollowing;
  final bool followBusy;
  final Player player;
  final VoidCallback onBack;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onSubscribe;
  final VoidCallback? onReload;
  final VoidCallback onStop;

  const WatchTopActionBar({
    super.key,
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
        final metrics = _WatchTopActionBarMetrics.fromWidth(
          constraints.maxWidth,
        );
        final actions = _WatchTopActionButtons(
          metadata: metadata,
          isFollowing: isFollowing,
          followBusy: followBusy,
          metrics: metrics,
          onBack: () => unawaited(_pauseThenBack()),
          onToggleFollow: onToggleFollow,
          onSubscribe: onSubscribe,
          onReload: onReload,
          onStopPlaybackOnly: () => unawaited(_stopPlaybackOnly()),
        );

        final content = metrics.compact
            ? _CompactWatchTopActionContent(
                metrics: metrics,
                actions: actions,
                metadata: metadata,
              )
            : _WideWatchTopActionContent(
                metrics: metrics,
                actions: actions,
                metadata: metadata,
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
  final VoidCallback? onToggleFollow;
  final VoidCallback? onSubscribe;
  final VoidCallback? onReload;
  final VoidCallback onStopPlaybackOnly;

  const _WatchTopActionButtons({
    required this.metadata,
    required this.isFollowing,
    required this.followBusy,
    required this.metrics,
    required this.onBack,
    required this.onToggleFollow,
    required this.onSubscribe,
    required this.onReload,
    required this.onStopPlaybackOnly,
  });

  Widget buildBackButton() {
    return RoundIconButton(
      tooltip: '返回',
      icon: Icons.arrow_back,
      iconColor: const Color(0xFF93C5FD),
      backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.20),
      borderColor: const Color(0xFF93C5FD).withOpacity(0.22),
      glowOpacity: 0.18,
      compact: metrics.compact,
      tiny: metrics.tiny,
      height: metrics.controlHeight,
      onPressed: onBack,
    );
  }

  List<Widget> buildRightActions() {
    return <Widget>[
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
      SizedBox(width: metrics.actionGap),
      RoundIconButton(
        tooltip: '重新載入',
        icon: Icons.refresh,
        iconColor: const Color(0xFFA78BFA),
        backgroundColor: const Color(0xFF4C1D95).withOpacity(0.22),
        borderColor: const Color(0xFFA78BFA).withOpacity(0.24),
        glowOpacity: 0.20,
        compact: metrics.compact,
        tiny: metrics.tiny,
        height: metrics.controlHeight,
        onPressed: onReload,
      ),
      SizedBox(width: metrics.actionGap),
      RoundIconButton(
        tooltip: '停止播放',
        icon: Icons.close,
        iconColor: const Color(0xFFFF6B81),
        backgroundColor: const Color(0xFF7F1D1D).withOpacity(0.24),
        borderColor: const Color(0xFFFF6B81).withOpacity(0.26),
        glowOpacity: 0.20,
        compact: metrics.compact,
        tiny: metrics.tiny,
        height: metrics.controlHeight,
        onPressed: onStopPlaybackOnly,
      ),
    ];
  }
}

class _CompactWatchTopActionContent extends StatelessWidget {
  final _WatchTopActionBarMetrics metrics;
  final _WatchTopActionButtons actions;
  final TwitchStreamHeaderMetadata metadata;

  const _CompactWatchTopActionContent({
    required this.metrics,
    required this.actions,
    required this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        actions.buildBackButton(),
        SizedBox(width: metrics.actionGap),
        WatchCompactAvatarTile(
          metadata: metadata,
          tiny: metrics.tiny,
          height: metrics.controlHeight,
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

  const _WideWatchTopActionContent({
    required this.metrics,
    required this.actions,
    required this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        actions.buildBackButton(),
        const SizedBox(width: 10),
        Expanded(
          child: WatchStreamHeaderCard(
            metadata: metadata,
            compact: false,
            height: metrics.controlHeight,
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
