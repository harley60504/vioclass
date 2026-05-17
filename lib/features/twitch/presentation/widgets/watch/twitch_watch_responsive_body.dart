import 'package:flutter/material.dart';

import '../responsive/twitch_responsive_layout.dart';
import 'twitch_watch_chat_resize_handle.dart';

class TwitchWatchResponsiveBody extends StatelessWidget {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = TwitchResponsiveLayout.fromConstraints(constraints);

        if (layout.shouldUseBottomChat) {
          final preferredPlayerHeight =
              (layout.width * 9 / 16).clamp(160.0, 320.0).toDouble();
          final maxPlayerHeightWithChat =
              (layout.height - 430.0).clamp(150.0, 320.0).toDouble();
          final playerHeight = chatVisible
              ? preferredPlayerHeight.clamp(150.0, maxPlayerHeightWithChat).toDouble()
              : layout.height;

          return Column(
            children: [
              SizedBox(
                height: playerHeight,
                width: double.infinity,
                child: player,
              ),
              if (chatVisible)
                const Divider(height: 1, thickness: 1, color: Color(0xFF24242A)),
              if (chatVisible) Expanded(child: chat),
            ],
          );
        }

        final effectiveChatWidth = _effectiveChatPanelWidthForViewport(layout);
        return Row(
          children: [
            Expanded(
              flex: layout.isPhoneLandscape ? 10 : 1,
              child: player,
            ),
            if (chatVisible)
              SizedBox(
                width: effectiveChatWidth,
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
                          final currentChatWidth =
                              chatPanelWidth > 0 ? chatPanelWidth : effectiveChatWidth;
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
          ],
        );
      },
    );
  }

  double _effectiveChatPanelWidthForViewport(TwitchResponsiveLayout layout) {
    final ratioWidth = layout.width * chatPanelRatio;
    final minByViewport = layout.width * minChatPanelRatio;
    final minWidth = minByViewport
        .clamp(minChatPanelWidth, maxEffectiveMinChatPanelWidth)
        .toDouble();
    final maxWidth = maxChatPanelWidth
        .clamp(minWidth, layout.width - 120.0)
        .toDouble();
    return ratioWidth.clamp(minWidth, maxWidth).toDouble();
  }
}
