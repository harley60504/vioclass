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
    final width = MediaQuery.sizeOf(context).width < 600 ? 260.0 : 340.0;
    final imageWidth = width - 20;
    final imageHeight = imageWidth * 9 / 16;
    final title = video.title.trim().isEmpty ? '最新 VOD' : video.title.trim();

    return Transform.translate(
      offset: const Offset(0, 28),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: width,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TwitchCachedImageLayer(
                    imageUrl: video.thumbnail(width: 640, height: 360),
                    width: imageWidth,
                    height: imageHeight,
                    fit: BoxFit.cover,
                    fallbackColor: Colors.black54,
                    fallbackIcon: Icons.video_library_outlined,
                    fallbackIconColor: Colors.white38,
                    fallbackIconSize: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
