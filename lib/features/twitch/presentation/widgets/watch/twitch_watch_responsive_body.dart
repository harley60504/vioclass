import 'package:flutter/material.dart';

import '../../../platform/android_pip/twitch_android_pip_controller.dart';
import '../responsive/twitch_responsive_layout.dart';
import 'twitch_watch_chat_resize_handle.dart';

const bool _enableWatchPlayer = bool.fromEnvironment(
  'TWITCH_ENABLE_WATCH_PLAYER',
  defaultValue: true,
);

class TwitchWatchResponsiveBody extends StatelessWidget {
  static const double _chatMinWidthVisualBoost = 18.0;
  static const double _playerAspectRatio = 16 / 9;
  static const Color _watchBackgroundColor = Color(0xFF171222);

  final bool chatVisible;
  final bool fullscreenMode;
  final double chatPanelWidth;
  final double chatPanelRatio;
  final double minChatPanelWidth;
  final double maxEffectiveMinChatPanelWidth;
  final double maxChatPanelWidth;
  final double minChatPanelRatio;
  final double minStoredChatPanelRatio;
  final double maxChatPanelRatio;
  final Widget player;
  final Widget chat;
  final void Function({required double viewportWidth, required double value})
      onSetChatPanelWidthForViewport;
  final VoidCallback onPersistChatPanelWidth;

  const TwitchWatchResponsiveBody({
    super.key,
    required this.chatVisible,
    this.fullscreenMode = false,
    required this.chatPanelWidth,
    required this.chatPanelRatio,
    required this.minChatPanelWidth,
    required this.maxEffectiveMinChatPanelWidth,
    required this.maxChatPanelWidth,
    required this.minChatPanelRatio,
    required this.minStoredChatPanelRatio,
    required this.maxChatPanelRatio,
    required this.player,
    required this.chat,
    required this.onSetChatPanelWidthForViewport,
    required this.onPersistChatPanelWidth,
  });

  @override
  Widget build(BuildContext context) {
    final pip = TwitchAndroidPipController.instance;

    return AnimatedBuilder(
      animation: pip,
      builder: (context, _) {
        if (pip.shouldRenderPlayerOnly || fullscreenMode) {
          return _PlayerOnlySurface(player: player);
        }

        return ColoredBox(
          color: _watchBackgroundColor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = TwitchResponsiveLayout.fromConstraints(constraints);

              if (!_enableWatchPlayer) {
                return _DisabledPlayerLayout(
                  layout: layout,
                  chatVisible: chatVisible,
                  chat: chat,
                );
              }

              if (layout.shouldUseBottomChat) {
                return _BottomChatLayout(
                  layout: layout,
                  chatVisible: chatVisible,
                  player: player,
                  chat: chat,
                );
              }

              return _SideChatLayout(
                layout: layout,
                chatVisible: chatVisible,
                chatPanelWidth: _effectiveChatPanelWidthForViewport(layout),
                player: player,
                chat: chat,
                onSetChatPanelWidthForViewport: onSetChatPanelWidthForViewport,
                onPersistChatPanelWidth: onPersistChatPanelWidth,
              );
            },
          ),
        );
      },
    );
  }

  static EdgeInsets shellPaddingFor(TwitchResponsiveLayout layout) {
    if (layout.isPhonePortrait) return const EdgeInsets.all(8);
    if (layout.width < 900 || layout.isPhoneLandscape) return const EdgeInsets.all(10);
    return const EdgeInsets.all(14);
  }

  static double shellGapFor(TwitchResponsiveLayout layout) {
    if (layout.isPhonePortrait || layout.width < 900) return 8;
    return 12;
  }

  double _effectiveChatPanelWidthForViewport(TwitchResponsiveLayout layout) {
    final horizontalPadding = shellPaddingFor(layout).horizontal;
    final gapWidth = chatVisible ? shellGapFor(layout) : 0.0;
    final usableWidth = (layout.width - horizontalPadding - gapWidth)
        .clamp(1.0, layout.width)
        .toDouble();
    final ratioWidth = usableWidth * chatPanelRatio;
    final minByViewport = usableWidth * minChatPanelRatio;
    final boostedMinChatPanelWidth = minChatPanelWidth + _chatMinWidthVisualBoost;
    final boostedMaxEffectiveMinChatPanelWidth =
        maxEffectiveMinChatPanelWidth + _chatMinWidthVisualBoost;
    final minWidth = minByViewport
        .clamp(boostedMinChatPanelWidth, boostedMaxEffectiveMinChatPanelWidth)
        .toDouble();
    final maxWidth = maxChatPanelWidth
        .clamp(minWidth, usableWidth - 120.0)
        .toDouble();
    return ratioWidth.clamp(minWidth, maxWidth).toDouble();
  }
}

class _PlayerOnlySurface extends StatelessWidget {
  final Widget player;

  const _PlayerOnlySurface({required this.player});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(child: player),
    );
  }
}

class _DisabledPlayerLayout extends StatelessWidget {
  final TwitchResponsiveLayout layout;
  final bool chatVisible;
  final Widget chat;

  const _DisabledPlayerLayout({
    required this.layout,
    required this.chatVisible,
    required this.chat,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: TwitchWatchResponsiveBody.shellPaddingFor(layout),
      child: _WatchSurface(
        child: chatVisible ? chat : const _WatchPlayerDisabledPlaceholder(),
      ),
    );
  }
}

class _BottomChatLayout extends StatelessWidget {
  final TwitchResponsiveLayout layout;
  final bool chatVisible;
  final Widget player;
  final Widget chat;

  const _BottomChatLayout({
    required this.layout,
    required this.chatVisible,
    required this.player,
    required this.chat,
  });

  @override
  Widget build(BuildContext context) {
    final shellPadding = TwitchWatchResponsiveBody.shellPaddingFor(layout);
    final shellGap = TwitchWatchResponsiveBody.shellGapFor(layout);

    final availableWidth = layout.width - shellPadding.horizontal;
    final availableHeight = layout.height - shellPadding.vertical;
    final preferredPlayerHeight =
        (availableWidth / TwitchWatchResponsiveBody._playerAspectRatio)
            .clamp(150.0, 320.0)
            .toDouble();
    final maxPlayerHeightWithChat =
        (availableHeight - 430.0).clamp(140.0, 320.0).toDouble();
    final playerHeight = preferredPlayerHeight
        .clamp(140.0, maxPlayerHeightWithChat)
        .toDouble();

    return Padding(
      padding: shellPadding,
      child: Column(
        children: [
          if (chatVisible)
            SizedBox(
              height: playerHeight,
              width: double.infinity,
              child: _WatchSurface(child: player),
            )
          else
            Expanded(child: _WatchSurface(child: player)),
          if (chatVisible) SizedBox(height: shellGap),
          if (chatVisible)
            Expanded(
              child: _WatchSurface(child: chat),
            ),
        ],
      ),
    );
  }
}

class _SideChatLayout extends StatelessWidget {
  final TwitchResponsiveLayout layout;
  final bool chatVisible;
  final double chatPanelWidth;
  final Widget player;
  final Widget chat;
  final void Function({required double viewportWidth, required double value})
      onSetChatPanelWidthForViewport;
  final VoidCallback onPersistChatPanelWidth;

  const _SideChatLayout({
    required this.layout,
    required this.chatVisible,
    required this.chatPanelWidth,
    required this.player,
    required this.chat,
    required this.onSetChatPanelWidthForViewport,
    required this.onPersistChatPanelWidth,
  });

  @override
  Widget build(BuildContext context) {
    final shellPadding = TwitchWatchResponsiveBody.shellPaddingFor(layout);
    final shellGap = TwitchWatchResponsiveBody.shellGapFor(layout);
    final usableWidth = (layout.width - shellPadding.horizontal - shellGap)
        .clamp(1.0, layout.width)
        .toDouble();
    var dragStartWidth = chatPanelWidth;
    var accumulatedDx = 0.0;

    return Padding(
      padding: shellPadding,
      child: Row(
        children: [
          Expanded(
            flex: layout.isPhoneLandscape ? 10 : 1,
            child: _WatchSurface(child: player),
          ),
          if (chatVisible)
            SizedBox(
              width: shellGap,
              child: TwitchWatchChatResizeHandle(
                onDragStart: (_) {
                  dragStartWidth = chatPanelWidth;
                  accumulatedDx = 0.0;
                },
                onDragUpdate: (delta) {
                  accumulatedDx += delta.delta.dx;
                  onSetChatPanelWidthForViewport(
                    viewportWidth: usableWidth,
                    value: dragStartWidth - accumulatedDx,
                  );
                },
                onDragEnd: onPersistChatPanelWidth,
              ),
            ),
          if (chatVisible)
            SizedBox(
              width: chatPanelWidth,
              child: _WatchSurface(child: chat),
            ),
        ],
      ),
    );
  }
}

class _WatchSurface extends StatelessWidget {
  final Widget child;

  const _WatchSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.045)),
      ),
      child: child,
    );
  }
}

class _WatchPlayerDisabledPlaceholder extends StatelessWidget {
  const _WatchPlayerDisabledPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '播放器已停用',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
