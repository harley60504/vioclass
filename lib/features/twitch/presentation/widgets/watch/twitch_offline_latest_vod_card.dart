import 'package:flutter/material.dart';

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
