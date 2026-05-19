part of twitch_watch_player_area;

enum _PlayerMoreAction {
  debug,
}

class _PlayerMoreActionsButton extends StatefulWidget {
  final TwitchPlaylistPlayerRuntime playerRuntime;

  const _PlayerMoreActionsButton({required this.playerRuntime});

  @override
  State<_PlayerMoreActionsButton> createState() => _PlayerMoreActionsButtonState();
}

class _PlayerMoreActionsButtonState extends State<_PlayerMoreActionsButton> {
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
          child: _DebugMenuRow(
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
    final selected = await _showAnchoredMenu<_PlaybackDebugCopyAction>(
      width: 270,
      height: 112,
      items: const <PopupMenuEntry<_PlaybackDebugCopyAction>>[
        PopupMenuItem<_PlaybackDebugCopyAction>(
          value: _PlaybackDebugCopyAction.proxyUrl,
          child: _DebugMenuRow(
            icon: Icons.link,
            label: '複製 Dart Proxy URL',
          ),
        ),
        PopupMenuItem<_PlaybackDebugCopyAction>(
          value: _PlaybackDebugCopyAction.mpvProxyCommand,
          child: _DebugMenuRow(
            icon: Icons.terminal,
            label: '複製 mpv Proxy 指令',
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;

    await _PlaybackDebugCopyButton.copyAction(
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
