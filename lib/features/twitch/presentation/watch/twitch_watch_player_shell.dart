// PATCH VERSION: twitch_watch_player_shell_stage186e
//
// UI-only shell for the future WatchPlayer composition.
//
// It does not own APIs. It only arranges the already-built feature widgets.

import 'package:flutter/material.dart';

class TwitchWatchPlayerShell extends StatelessWidget {
  final Widget player;
  final Widget? chat;
  final Widget? topOverlay;
  final Widget? bottomOverlay;
  final Widget? sideOverlay;
  final bool chatVisible;
  final double chatWidth;
  final ValueChanged<double>? onChatWidthChanged;

  const TwitchWatchPlayerShell({
    super.key,
    required this.player,
    this.chat,
    this.topOverlay,
    this.bottomOverlay,
    this.sideOverlay,
    this.chatVisible = true,
    this.chatWidth = 430,
    this.onChatWidthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveChat = chatVisible ? chat : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              player,
              if (topOverlay != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: topOverlay!,
                ),
              if (bottomOverlay != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: bottomOverlay!,
                ),
              if (sideOverlay != null)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: sideOverlay!,
                ),
            ],
          ),
        ),
        if (effectiveChat != null) ...[
          _TwitchWatchPlayerShellDivider(
            onDragDelta: onChatWidthChanged,
          ),
          SizedBox(
            width: chatWidth,
            child: effectiveChat,
          ),
        ],
      ],
    );
  }
}

class _TwitchWatchPlayerShellDivider extends StatelessWidget {
  final ValueChanged<double>? onDragDelta;

  const _TwitchWatchPlayerShellDivider({this.onDragDelta});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: onDragDelta == null
            ? null
            : (details) => onDragDelta!(details.delta.dx),
        child: Container(
          width: 6,
          color: const Color(0xFF18181B),
          alignment: Alignment.center,
          child: Container(
            width: 1,
            color: Colors.white.withOpacity(0.08),
          ),
        ),
      ),
    );
  }
}
