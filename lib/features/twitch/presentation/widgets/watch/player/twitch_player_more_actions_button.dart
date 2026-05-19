import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../services/playback/twitch_playlist_player_runtime.dart';
import 'twitch_player_debug_copy_actions.dart';

enum _PlayerMoreAction {
  debug,
}

class PlayerMoreActionsButton extends StatefulWidget {
  final TwitchPlaylistPlayerRuntime playerRuntime;

  const PlayerMoreActionsButton({super.key, required this.playerRuntime});

  @override
  State<PlayerMoreActionsButton> createState() => _PlayerMoreActionsButtonState();
}

class _PlayerMoreActionsButtonState extends State<PlayerMoreActionsButton> {
  final GlobalKey _buttonKey = GlobalKey();

  bool get _showDebugMenu {
    return !Platform.isAndroid && !Platform.isIOS;
  }

  @override
  Widget build(BuildContext context) {
    if (!_showDebugMenu) return const SizedBox.shrink();

    return IconButton(
      key: _buttonKey,
      tooltip: '更多',
      splashRadius: 22,
      icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
      onPressed: _openMoreMenu,
    );
  }

  Future<void> _openMoreMenu() async {
    final selected = await _showAnchoredMenu<_PlayerMoreAction>(
      width: 184,
      height: 56,
      items: const <PopupMenuEntry<_PlayerMoreAction>>[
        PopupMenuItem<_PlayerMoreAction>(
          value: _PlayerMoreAction.debug,
          child: DebugMenuRow(
            icon: Icons.bug_report_outlined,
            label: 'Debug  ›',
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case _PlayerMoreAction.debug:
        await _openDebugSubmenu();
        break;
    }
  }

  Future<void> _openDebugSubmenu() async {
    final selected = await _showAnchoredMenu<PlaybackDebugCopyAction>(
      width: 270,
      height: 112,
      items: const <PopupMenuEntry<PlaybackDebugCopyAction>>[
        PopupMenuItem<PlaybackDebugCopyAction>(
          value: PlaybackDebugCopyAction.proxyUrl,
          child: DebugMenuRow(
            icon: Icons.link,
            label: '複製 Dart Proxy URL',
          ),
        ),
        PopupMenuItem<PlaybackDebugCopyAction>(
          value: PlaybackDebugCopyAction.mpvProxyCommand,
          child: DebugMenuRow(
            icon: Icons.terminal,
            label: '複製 mpv Proxy 指令',
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;

    await PlaybackDebugCopyButton.copyAction(
      context: context,
      playerRuntime: widget.playerRuntime,
      action: selected,
    );
  }

  Future<T?> _showAnchoredMenu<T>({
    required double width,
    required double height,
    required List<PopupMenuEntry<T>> items,
  }) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final buttonContext = _buttonKey.currentContext;
    final buttonBox = buttonContext?.findRenderObject() as RenderBox?;

    if (overlay == null || buttonBox == null || !buttonBox.hasSize) {
      return Future<T?>.value(null);
    }

    final buttonTopLeft = buttonBox.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonBottomRight = buttonBox.localToGlobal(
      buttonBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );

    final left = (buttonBottomRight.dx - width)
        .clamp(8.0, math.max(8.0, overlay.size.width - width - 8.0))
        .toDouble();

    final preferAbove = buttonTopLeft.dy > height + 16;
    final top = preferAbove
        ? (buttonTopLeft.dy - height - 10.0)
            .clamp(8.0, math.max(8.0, overlay.size.height - height - 8.0))
            .toDouble()
        : (buttonBottomRight.dy + 8.0)
            .clamp(8.0, math.max(8.0, overlay.size.height - height - 8.0))
            .toDouble();

    return showMenu<T>(
      context: context,
      color: const Color(0xFF18181B),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(left, top, width, height),
        Offset.zero & overlay.size,
      ),
      items: items,
    );
  }
}
