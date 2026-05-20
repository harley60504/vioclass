import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image/image.dart' as img;

/// Experimental animated emote renderer that decodes animated emote frames in Dart.
///
/// Decoded frame lists are cached by URL, so repeated emotes reuse the same
/// prepared frames instead of re-decoding every chat row or picker tile.
class TwitchDecodedAnimatedEmoteImage extends StatefulWidget {
  final String imageUrl;
  final String cacheKey;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget fallback;
  final Widget? loading;
  final int maxFrames;
  final bool debug;
  final String debugLabel;

  const TwitchDecodedAnimatedEmoteImage({
    super.key,
    required this.imageUrl,
    required this.cacheKey,
    required this.fallback,
    this.loading,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.maxFrames = 80,
    this.debug = false,
    this.debugLabel = 'TwitchDecodedAnimatedEmoteImage',
  });

  @override
  State<TwitchDecodedAnimatedEmoteImage> createState() =>
      _TwitchDecodedAnimatedEmoteImageState();
}

class _TwitchDecodedAnimatedEmoteImageState
    extends State<TwitchDecodedAnimatedEmoteImage> {
  static const int maxFrameCacheEntries = 220;

  static final LinkedHashMap<String, Future<List<_DecodedAnimatedFrame>>>
      frameCache = LinkedHashMap<String, Future<List<_DecodedAnimatedFrame>>>();

  Future<List<_DecodedAnimatedFrame>>? framesFuture;
  List<_DecodedAnimatedFrame> frames = const <_DecodedAnimatedFrame>[];
  Timer? timer;
  int frameIndex = 0;

  @override
  void initState() {
    super.initState();
    startLoad();
  }

  @override
  void didUpdateWidget(covariant TwitchDecodedAnimatedEmoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.maxFrames != widget.maxFrames) {
      stopTimer();
      frames = const <_DecodedAnimatedFrame>[];
      frameIndex = 0;
      startLoad();
    }
  }

  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }

  void startLoad() {
    framesFuture = loadFramesCached(
      url: widget.imageUrl,
      cacheKey: widget.cacheKey,
      maxFrames: widget.maxFrames,
      debug: widget.debug,
      debugLabel: widget.debugLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final future = framesFuture;
    if (future == null) return widget.fallback;

    return FutureBuilder<List<_DecodedAnimatedFrame>>(
      future: future,
      builder: (context, snapshot) {
        final loadedFrames = snapshot.data;

        if (loadedFrames != null && loadedFrames.isNotEmpty) {
          if (!identical(frames, loadedFrames)) {
            frames = loadedFrames;
            frameIndex = frameIndex.clamp(0, frames.length - 1).toInt();
            scheduleCurrentFrame();
          }

          final safeIndex = frameIndex.clamp(0, frames.length - 1).toInt();
          return Image.memory(
            frames[safeIndex].pngBytes,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, __, ___) => widget.fallback,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loading ?? widget.fallback;
        }

        return widget.fallback;
      },
    );
  }

  void scheduleCurrentFrame() {
    if (timer != null || frames.length <= 1) return;

    final safeIndex = frameIndex.clamp(0, frames.length - 1).toInt();
    final durationMs = frames[safeIndex].durationMs;

    timer = Timer(Duration(milliseconds: durationMs), () {
      timer = null;
      if (!mounted || frames.isEmpty) return;

      setState(() {
        frameIndex = (frameIndex + 1) % frames.length;
      });

      scheduleCurrentFrame();
    });
  }

  void stopTimer() {
    timer?.cancel();
    timer = null;
  }

  static Future<List<_DecodedAnimatedFrame>> loadFramesCached({
    required String url,
    required String cacheKey,
    required int maxFrames,
    required bool debug,
    required String debugLabel,
  }) {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      return Future<List<_DecodedAnimatedFrame>>.value(
        const <_DecodedAnimatedFrame>[],
      );
    }

    final key = '${cacheKey.trim().isEmpty ? cleanUrl : cacheKey.trim()}|$cleanUrl|$maxFrames';
    final cached = frameCache.remove(key);
    if (cached != null) {
      frameCache[key] = cached;
      if (debug) {
        debugPrint('[$debugLabel] frame cache hit entries=${frameCache.length}');
      }
      return cached;
    }

    if (debug) {
      debugPrint('[$debugLabel] frame cache miss entries=${frameCache.length}');
    }

    final future = loadAndDecodeFrames(
      url: cleanUrl,
      maxFrames: maxFrames,
      debug: debug,
      debugLabel: debugLabel,
    ).then((value) {
      if (value.isEmpty) frameCache.remove(key);
      return value;
    });

    frameCache[key] = future;
    trimFrameCache();
    return future;
  }

  static void trimFrameCache() {
    while (frameCache.length > maxFrameCacheEntries) {
      frameCache.remove(frameCache.keys.first);
    }
  }

  static Future<List<_DecodedAnimatedFrame>> loadAndDecodeFrames({
    required String url,
    required int maxFrames,
    required bool debug,
    required String debugLabel,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return const <_DecodedAnimatedFrame>[];

    try {
      final file = await DefaultCacheManager().getSingleFile(cleanUrl);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
        if (debug) {
          debugPrint('[$debugLabel] decode returned null/empty url=$cleanUrl');
        }
        return const <_DecodedAnimatedFrame>[];
      }

      final decodedFrames = decodeFrames(
        decoded: decoded,
        maxFrames: maxFrames,
      );

      if (debug) {
        debugPrint(
          '[$debugLabel] decoded url=$cleanUrl frames=${decodedFrames.length}',
        );
      }

      return decodedFrames;
    } catch (e) {
      if (debug) {
        debugPrint('[$debugLabel] decode failed url=$cleanUrl error=$e');
      }
      return const <_DecodedAnimatedFrame>[];
    }
  }
}

class _DecodedAnimatedFrame {
  final Uint8List pngBytes;
  final int durationMs;

  const _DecodedAnimatedFrame({
    required this.pngBytes,
    required this.durationMs,
  });
}

List<_DecodedAnimatedFrame> decodeFrames({
  required img.Image decoded,
  required int maxFrames,
}) {
  final frameCount = decoded.numFrames <= 0 ? 1 : decoded.numFrames;
  final safeMaxFrames = maxFrames <= 0 ? frameCount : maxFrames;
  final limit = frameCount < safeMaxFrames ? frameCount : safeMaxFrames;

  final output = <_DecodedAnimatedFrame>[];

  for (var i = 0; i < limit; i++) {
    final frame = decoded.getFrame(i);
    if (frame.width <= 0 || frame.height <= 0) continue;

    final rawDuration = frame.frameDuration;
    final durationMs = rawDuration <= 0
        ? 80
        : rawDuration.clamp(25, 1000).toInt();
    final png = Uint8List.fromList(img.encodePng(frame));

    output.add(_DecodedAnimatedFrame(
      pngBytes: png,
      durationMs: durationMs,
    ));
  }

  return output;
}
