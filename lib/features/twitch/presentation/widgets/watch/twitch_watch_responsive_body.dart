// PATCH VERSION: twitch_watch_responsive_body_stage212_full_player_pane_controls

import 'package:flutter/material.dart';

import '../responsive/twitch_responsive_layout.dart';
import 'twitch_watch_chat_resize_handle.dart';

class TwitchWatchResponsiveBody extends StatelessWidget {
  static const double _chatMinWidthVisualBoost = 18.0;
  static const double _playerAspectRatio = 16 / 9;
  static const Color _watchBackgroundColor = Color(0xFF171222);

  final bool chatVisible;
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
    return ColoredBox(
      color: _watchBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = TwitchResponsiveLayout.fromConstraints(constraints);
          final shellPadding = _shellPaddingFor(layout);
          final shellGap = _shellGapFor(layout);

          if (layout.shouldUseBottomChat) {
            final availableWidth = layout.width - shellPadding.horizontal;
            final availableHeight = layout.height - shellPadding.vertical;
            final preferredPlayerHeight =
                (availableWidth / _playerAspectRatio).clamp(150.0, 320.0).toDouble();
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

          final effectiveChatWidth = _effectiveChatPanelWidthForViewport(layout);
          final horizontalPadding = shellPadding.horizontal;
          final usableWidth = (layout.width - horizontalPadding - shellGap)
              .clamp(1.0, layout.width)
              .toDouble();
          var dragStartWidth = effectiveChatWidth;
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
                        dragStartWidth = effectiveChatWidth;
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
                    width: effectiveChatWidth,
                    child: _WatchSurface(child: chat),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  EdgeInsets _shellPaddingFor(TwitchResponsiveLayout layout) {
    if (layout.isPhonePortrait) {
      return const EdgeInsets.all(8);
    }
    if (layout.width < 900 || layout.isPhoneLandscape) {
      return const EdgeInsets.all(10);
    }
    return const EdgeInsets.all(14);
  }

  double _shellGapFor(TwitchResponsiveLayout layout) {
    if (layout.isPhonePortrait || layout.width < 900) return 8;
    return 12;
  }

  double _effectiveChatPanelWidthForViewport(TwitchResponsiveLayout layout) {
    final horizontalPadding = _shellPaddingFor(layout).horizontal;
    final gapWidth = chatVisible ? _shellGapFor(layout) : 0.0;
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
