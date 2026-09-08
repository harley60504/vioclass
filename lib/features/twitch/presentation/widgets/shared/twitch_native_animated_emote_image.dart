import 'package:flutter/material.dart';
import 'package:native_animated_image/native_animated_image.dart';

import '../../../services/chat/twitch_emote_image_cache_manager.dart';

class TwitchNativeAnimatedEmoteImage extends StatelessWidget {
  final String url;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;
  final FilterQuality filterQuality;

  const TwitchNativeAnimatedEmoteImage({
    super.key,
    required this.url,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.low,
  });

  @override
  Widget build(BuildContext context) {
    final sourceUrl = url.trim();
    return Image(
      image: NativeAnimatedImageProvider.fromBytesProvider(
        tag: sourceUrl,
        loader: () async {
          final file = await TwitchEmoteImageCacheManager.instance
              .getSingleFile(sourceUrl);
          return file.readAsBytes();
        },
      ),
      width: width,
      height: height,
      fit: fit,
      filterQuality: filterQuality,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          frame == null ? fallback : child,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
