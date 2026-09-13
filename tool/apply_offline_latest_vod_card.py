from pathlib import Path

ROOT = Path('.')
page = ROOT / 'lib/features/twitch/presentation/pages/twitch_watch_page.dart'
startup = ROOT / 'lib/features/twitch/presentation/pages/watch/twitch_watch_page_startup.dart'
nav = ROOT / 'lib/features/twitch/presentation/pages/watch/twitch_watch_page_navigation.dart'
live = ROOT / 'lib/features/twitch/presentation/pages/watch/twitch_live_watch_playback.dart'
widget = ROOT / 'lib/features/twitch/presentation/widgets/watch/twitch_offline_latest_vod_card.dart'


def replace_once(path: Path, old: str, new: str):
    text = path.read_text(encoding='utf-8')
    if old not in text:
        raise RuntimeError(f'pattern not found in {path}: {old[:120]!r}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    page,
    "import '../widgets/channel/twitch_channel_about_section.dart';\n",
    "import '../widgets/channel/twitch_channel_about_section.dart';\nimport '../widgets/watch/twitch_offline_latest_vod_card.dart';\n",
)
replace_once(
    page,
    "  TwitchChannelVideo? offlineVodFallbackVideo;\n  bool showOfflineChannelPlaceholder = false;",
    "  TwitchChannelVideo? offlineVodFallbackVideo;\n  TwitchChannelVideo? offlineLatestVodVideo;\n  bool showOfflineChannelPlaceholder = false;",
)
replace_once(
    page,
    "    final playerArea = TwitchWatchPlayerAreaPortAdapter(\n",
    "    final basePlayerArea = TwitchWatchPlayerAreaPortAdapter(\n",
)
replace_once(
    page,
    "      onError: (message) {\n        if (!mounted) return;\n        playbackController.setError(message);\n        showSnack('播放器操作失敗，請稍後再試。');\n      },\n    );\n    final belowPlayer = TwitchChannelAboutSection(",
    "      onError: (message) {\n        if (!mounted) return;\n        playbackController.setError(message);\n        showSnack('播放器操作失敗，請稍後再試。');\n      },\n    );\n    final playerArea = Stack(\n      fit: StackFit.expand,\n      children: [\n        Positioned.fill(child: basePlayerArea),\n        if (showOfflineChannelPlaceholder && offlineLatestVodVideo != null)\n          Positioned(\n            top: 76,\n            right: 16,\n            child: TwitchOfflineLatestVodCard(\n              video: offlineLatestVodVideo!,\n              onTap: () => unawaited(openOfflineLatestVod()),\n            ),\n          ),\n      ],\n    );\n    final belowPlayer = TwitchChannelAboutSection(",
)

replace_once(
    startup,
    "    showOfflineChannelPlaceholder = true;\n    if (mounted) setState(() {});\n  }\n\n  void primeInitialActiveDvrAvailability",
    "    showOfflineChannelPlaceholder = true;\n    if (mounted) setState(() {});\n    unawaited(\n      loadOfflineLatestVodEntry(channel: channel, generation: generation),\n    );\n  }\n\n  Future<void> loadOfflineLatestVodEntry({\n    required String channel,\n    required int generation,\n  }) async {\n    final fallbackChannel = widget.resolvedInitialOfflineChannel;\n    final discoveryService = widget.initialDiscoveryService;\n    if (fallbackChannel == null || discoveryService == null) {\n      offlineLatestVodVideo = null;\n      if (mounted) setState(() {});\n      return;\n    }\n\n    try {\n      final page = await discoveryService.fetchChannelVideos(\n        userId: fallbackChannel.broadcasterId,\n        first: 1,\n      );\n      if (!isCurrentWatchTask(generation, channel) ||\n          !showOfflineChannelPlaceholder) {\n        return;\n      }\n      offlineLatestVodVideo = page.videos.isEmpty ? null : page.videos.first;\n      if (mounted) setState(() {});\n    } catch (error) {\n      if (!isCurrentWatchTask(generation, channel)) return;\n      debugPrint('[LiveWatch] latest offline VOD lookup failed: $error');\n      offlineLatestVodVideo = null;\n      if (mounted) setState(() {});\n    }\n  }\n\n  void primeInitialActiveDvrAvailability",
)
replace_once(
    startup,
    "      } else if (liveAvailable == true && showOfflineChannelPlaceholder) {\n        showOfflineChannelPlaceholder = false;",
    "      } else if (liveAvailable == true && showOfflineChannelPlaceholder) {\n        offlineLatestVodVideo = null;\n        showOfflineChannelPlaceholder = false;",
)
replace_once(
    startup,
    "    offlineVodFallbackVideo = null;\n    showOfflineChannelPlaceholder = false;",
    "    offlineVodFallbackVideo = null;\n    offlineLatestVodVideo = null;\n    showOfflineChannelPlaceholder = false;",
)

replace_once(
    nav,
    "  Future<void> returnToHome() async {",
    "  Future<void> openOfflineLatestVod() async {\n    final video = offlineLatestVodVideo;\n    if (video == null || !mounted) return;\n\n    await Navigator.of(context).push(\n      MaterialPageRoute<void>(\n        builder: (_) => TwitchWatchPage(\n          initialMetadata: widget.resolvedInitialMetadata.copyWith(\n            streamTitle: video.title,\n            language: video.language,\n            clearViewerCount: true,\n            clearStartedAt: true,\n          ),\n          initialOfflineChannel: widget.resolvedInitialOfflineChannel,\n          initialDiscoveryService: widget.initialDiscoveryService,\n          initialVodVideo: video,\n          initialVodPlaybackOnly: true,\n          initialKnownFollowing: effectiveIsFollowing,\n        ),\n      ),\n    );\n  }\n\n  Future<void> returnToHome() async {",
)

replace_once(
    live,
    "    return isBoundToCurrentLive || video.isLikelyGrowingArchive;",
    "    if (watchMode == TwitchWatchMode.recordedWatch) {\n      return isBoundToCurrentLive;\n    }\n    return isBoundToCurrentLive || video.isLikelyGrowingArchive;",
)

widget.write_text("""import 'package:flutter/material.dart';

import '../../../models/discovery/twitch_live_stream.dart';
import '../shared/twitch_cached_image_layer.dart';

class TwitchOfflineLatestVodCard extends StatelessWidget {
  final TwitchChannelVideo video;
  final VoidCallback onTap;

  const TwitchOfflineLatestVodCard({
    super.key,
    required this.video,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width < 600 ? 230.0 : 300.0;
    final title = video.title.trim().isEmpty ? '最新 VOD' : video.title.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: TwitchCachedImageLayer(
                  imageUrl: video.thumbnail(width: 320, height: 180),
                  width: width < 260 ? 92 : 116,
                  height: width < 260 ? 52 : 65,
                  fit: BoxFit.cover,
                  fallbackColor: Colors.black54,
                  fallbackIcon: Icons.video_library_outlined,
                  fallbackIconColor: Colors.white38,
                  fallbackIconSize: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
""", encoding='utf-8')

print('offline latest VOD card changes applied')
