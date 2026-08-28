import 'package:flutter/material.dart';

import '../../../models/bootstrap/twitch_api_bootstrap.dart';
import '../../../services/playback/twitch_playlist_player_runtime.dart';
import '../../theme/twitch_ui_tokens.dart';

class TwitchRuntimePlayerPreview extends StatelessWidget {
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final TwitchApiBootstrapSnapshot? snapshot;

  const TwitchRuntimePlayerPreview({
    super.key,
    required this.playerRuntime,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playerRuntime,
      builder: (context, _) {
        final stream = snapshot?.stream;
        final user = snapshot?.user;
        final title = stream?['title']?.toString() ?? '尚未載入直播';
        final gameName = stream?['gameName']?.toString() ?? '';
        final viewerCount = stream?['viewerCount']?.toString() ?? '';
        final displayName = user?['displayName']?.toString() ?? '';

        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  size: 96,
                  color: Colors.white24,
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: 16,
                child: _InfoCard(
                  displayName: displayName,
                  title: title,
                  gameName: gameName,
                  viewerCount: viewerCount,
                  loading: playerRuntime.loading,
                ),
              ),
              if (playerRuntime.error != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Text(
                      '播放器暫時無法載入，請稍後再試。',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String displayName;
  final String title;
  final String gameName;
  final String viewerCount;
  final bool loading;

  const _InfoCard({
    required this.displayName,
    required this.title,
    required this.gameName,
    required this.viewerCount,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: TwitchUiColors.primarySoft,
                  ),
                )
              else
                const Icon(
                  Icons.live_tv,
                  size: 16,
                  color: TwitchUiColors.primary,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayName.isEmpty ? '播放器預覽' : displayName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (viewerCount.isNotEmpty)
                Text(
                  '$viewerCount 位觀眾',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
          if (gameName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              gameName,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
