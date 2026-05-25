import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../services/playback/twitch_playlist_player_runtime.dart';

enum PlaybackDebugCopyAction { proxyUrl, mpvProxyCommand }

class PlaybackDebugCopyButton extends StatelessWidget {
  final TwitchPlaylistPlayerRuntime playerRuntime;

  const PlaybackDebugCopyButton({super.key, required this.playerRuntime});

  static const String _mpvUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  @override
  Widget build(BuildContext context) {
    final proxyUrl =
        playerRuntime.proxyMpvUrl?.trim() ?? playerRuntime.proxyUrl?.trim();
    final hasProxyUrl = proxyUrl != null && proxyUrl.isNotEmpty;

    return PopupMenuButton<PlaybackDebugCopyAction>(
      tooltip: 'Debug：複製 Dart Proxy URL',
      color: const Color(0xFF18181B),
      icon: const Icon(
        Icons.bug_report_outlined,
        color: Colors.white,
        size: 23,
      ),
      enabled: hasProxyUrl,
      onSelected: (action) => _handleCopy(context, action),
      itemBuilder: (context) => <PopupMenuEntry<PlaybackDebugCopyAction>>[
        PopupMenuItem<PlaybackDebugCopyAction>(
          value: PlaybackDebugCopyAction.proxyUrl,
          enabled: hasProxyUrl,
          child: const DebugMenuRow(
            icon: Icons.link,
            label: '複製 Dart Proxy URL',
          ),
        ),
        PopupMenuItem<PlaybackDebugCopyAction>(
          value: PlaybackDebugCopyAction.mpvProxyCommand,
          enabled: hasProxyUrl,
          child: const DebugMenuRow(
            icon: Icons.terminal,
            label: '複製 mpv Proxy 指令',
          ),
        ),
      ],
    );
  }

  Future<void> _handleCopy(
    BuildContext context,
    PlaybackDebugCopyAction action,
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
    required PlaybackDebugCopyAction action,
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

  static PlaybackDebugCopyPayload _buildCopyPayload({
    required PlaybackDebugCopyAction action,
    required String proxyUrl,
  }) {
    switch (action) {
      case PlaybackDebugCopyAction.proxyUrl:
        return PlaybackDebugCopyPayload(
          label: 'Dart Proxy URL',
          text: proxyUrl,
        );
      case PlaybackDebugCopyAction.mpvProxyCommand:
        return PlaybackDebugCopyPayload(
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class PlaybackDebugCopyPayload {
  final String label;
  final String text;

  const PlaybackDebugCopyPayload({required this.label, required this.text});
}

class DebugMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const DebugMenuRow({super.key, required this.icon, required this.label});

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
