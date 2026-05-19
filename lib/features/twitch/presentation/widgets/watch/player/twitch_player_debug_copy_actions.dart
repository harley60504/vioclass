part of twitch_watch_player_area;

enum _PlaybackDebugCopyAction {
  proxyUrl,
  mpvProxyCommand,
}

class _PlaybackDebugCopyButton extends StatelessWidget {
  final TwitchPlaylistPlayerRuntime playerRuntime;

  const _PlaybackDebugCopyButton({required this.playerRuntime});

  static const String _mpvUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  @override
  Widget build(BuildContext context) {
    final proxyUrl = playerRuntime.proxyMpvUrl?.trim() ?? playerRuntime.proxyUrl?.trim();
    final hasProxyUrl = proxyUrl != null && proxyUrl.isNotEmpty;

    return PopupMenuButton<_PlaybackDebugCopyAction>(
      tooltip: 'Debug：複製 Dart Proxy URL',
      color: const Color(0xFF18181B),
      icon: const Icon(Icons.bug_report_outlined, color: Colors.white, size: 23),
      enabled: hasProxyUrl,
      onSelected: (action) => _handleCopy(context, action),
      itemBuilder: (context) => <PopupMenuEntry<_PlaybackDebugCopyAction>>[
        PopupMenuItem<_PlaybackDebugCopyAction>(
          value: _PlaybackDebugCopyAction.proxyUrl,
          enabled: hasProxyUrl,
          child: const _DebugMenuRow(
            icon: Icons.link,
            label: '複製 Dart Proxy URL',
          ),
        ),
        PopupMenuItem<_PlaybackDebugCopyAction>(
          value: _PlaybackDebugCopyAction.mpvProxyCommand,
          enabled: hasProxyUrl,
          child: const _DebugMenuRow(
            icon: Icons.terminal,
            label: '複製 mpv Proxy 指令',
          ),
        ),
      ],
    );
  }

  Future<void> _handleCopy(
    BuildContext context,
    _PlaybackDebugCopyAction action,
  ) {
    return copyAction(
      context: context,
      playerRuntime: playerRuntime,
      action: action,
    );
  }

  static Future<void> copyAction({
    required BuildContext context,
    required TwitchPlaylistPlayerRuntime playerRuntime,
    required _PlaybackDebugCopyAction action,
  }) async {
    final proxyUrl =
        playerRuntime.proxyMpvUrl?.trim() ?? playerRuntime.proxyUrl?.trim();
    if (proxyUrl == null || proxyUrl.isEmpty) {
      _showCopySnack(context, '目前沒有可複製的 Dart Proxy URL。');
      return;
    }

    final copied = _buildCopyPayload(action: action, proxyUrl: proxyUrl);
    await Clipboard.setData(ClipboardData(text: copied.text));
    if (!context.mounted) return;
    _showCopySnack(context, '已複製${copied.label}。');
  }

  static _PlaybackDebugCopyPayload _buildCopyPayload({
    required _PlaybackDebugCopyAction action,
    required String proxyUrl,
  }) {
    switch (action) {
      case _PlaybackDebugCopyAction.proxyUrl:
        return _PlaybackDebugCopyPayload(
          label: 'Dart Proxy URL',
          text: proxyUrl,
        );
      case _PlaybackDebugCopyAction.mpvProxyCommand:
        return _PlaybackDebugCopyPayload(
          label: 'mpv Proxy 指令',
          text: _buildMpvCommand(proxyUrl),
        );
    }
  }

  static String _buildMpvCommand(String url) {
    final escapedUrl = _escapeForDoubleQuotedShell(url);
    return 'mpv '
        '--msg-level=ffmpeg/video=fatal '
        '--user-agent="$_mpvUserAgent" '
        '--referrer="https://www.twitch.tv/" '
        '--http-header-fields="Origin: https://www.twitch.tv" '
        '"$escapedUrl"';
  }

  static String _escapeForDoubleQuotedShell(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('"', r'\"')
        .replaceAll(r'$', r'\$')
        .replaceAll('`', r'\`');
  }

  static void _showCopySnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _PlaybackDebugCopyPayload {
  final String label;
  final String text;

  const _PlaybackDebugCopyPayload({
    required this.label,
    required this.text,
  });
}

class _DebugMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DebugMenuRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFBF94FF), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
