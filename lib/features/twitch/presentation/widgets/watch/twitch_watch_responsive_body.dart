// PATCH VERSION: twitch_watch_responsive_body_stage207_flat_lavender_square_shell

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
                    Expanded(
                      child: _WatchAspectSurface(child: player),
                    ),
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
          return Padding(
            padding: shellPadding,
            child: Row(
              children: [
                Expanded(
                  flex: layout.isPhoneLandscape ? 10 : 1,
                  child: _WatchAspectSurface(child: player),
                ),
                if (chatVisible) SizedBox(width: shellGap),
                if (chatVisible)
                  SizedBox(
                    width: effectiveChatWidth,
                    child: _WatchSurface(
                      child: Stack(
                        children: [
                          Positioned.fill(child: chat),
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 10,
                            child: TwitchWatchChatResizeHandle(
                              onDragUpdate: (delta) {
                                final currentChatWidth = chatPanelWidth > 0
                                    ? chatPanelWidth
                                    : effectiveChatWidth;
                                onSetChatPanelWidthForViewport(
                                  viewportWidth: layout.width,
                                  value: currentChatWidth - delta.delta.dx,
                                );
                              },
                              onDragEnd: onPersistChatPanelWidth,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _WatchAspectSurface extends StatelessWidget {
  final Widget child;

  const _WatchAspectSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;

        if (maxWidth <= 0 || maxHeight <= 0) {
          return const SizedBox.shrink();
        }

        var width = maxWidth;
        var height = width / TwitchWatchResponsiveBody._playerAspectRatio;

        if (height > maxHeight) {
          height = maxHeight;
          width = height * TwitchWatchResponsiveBody._playerAspectRatio;
        }

        width = width.clamp(1.0, maxWidth).toDouble();
        height = height.clamp(1.0, maxHeight).toDouble();

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: _WatchSurface(child: child),
          ),
        );
      },
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
        color: Colors.black.withOpacity(0.16),
        border: Border.all(color: Colors.white.withOpacity(0.055)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
