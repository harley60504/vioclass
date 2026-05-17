// PATCH VERSION: twitch_watch_responsive_body_stage201_purple_gradient_background

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
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.82, -0.92),
          radius: 1.45,
          colors: <Color>[
            Color(0xFF2A1645),
            Color(0xFF151321),
            Color(0xFF09090D),
          ],
          stops: <double>[0.0, 0.46, 1.0],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: -170,
            top: -210,
            width: 560,
            height: 560,
            child: _WatchBackgroundGlowOrb(
              color: Color(0x449146FF),
            ),
          ),
          const Positioned(
            right: -260,
            bottom: -280,
            width: 680,
            height: 680,
            child: _WatchBackgroundGlowOrb(
              color: Color(0x245B2D91),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = TwitchResponsiveLayout.fromConstraints(constraints);

                if (layout.shouldUseBottomChat) {
                  final preferredPlayerHeight =
                      (layout.width * 9 / 16).clamp(160.0, 320.0).toDouble();
                  final maxPlayerHeightWithChat =
                      (layout.height - 430.0).clamp(150.0, 320.0).toDouble();
                  final playerHeight = chatVisible
                      ? preferredPlayerHeight
                          .clamp(150.0, maxPlayerHeightWithChat)
                          .toDouble()
                      : layout.height;

                  return Column(
                    children: [
                      SizedBox(
                        height: playerHeight,
                        width: double.infinity,
                        child: player,
                      ),
                      if (chatVisible)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.white.withOpacity(0.06),
                        ),
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
            ),
          ),
        ],
      ),
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

class _WatchBackgroundGlowOrb extends StatelessWidget {
  final Color color;

  const _WatchBackgroundGlowOrb({required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color,
              color.withOpacity(0.0),
            ],
          ),
        ),
      ),
    );
  }
}
