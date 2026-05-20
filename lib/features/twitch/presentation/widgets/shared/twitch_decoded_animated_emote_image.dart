import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image/image.dart' as img;

/// Experimental animated emote renderer that bypasses Flutter's animated image
/// codec by decoding Animated WebP frames in Dart.
///
/// This is intended for problematic Twitch official animated emotes where the
/// Flutter image pipeline reports errors such as:
///   Could not getPixels for frame N
///
/// The widget decodes the animated file into PNG frame bytes, then displays the
/// current frame with Image.memory. If decoding fails, [fallback] is shown.
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
  Future<List<_DecodedAnimatedFrame>>? _framesFuture;
  List<_DecodedAnimatedFrame> _frames = const <_DecodedAnimatedFrame>[];
  Timer? _timer;
  int _frameIndex = 0;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(covariant TwitchDecodedAnimatedEmoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.maxFrames != widget.maxFrames) {
      _stopTimer();
      _frames = const <_DecodedAnimatedFrame>[];
      _frameIndex = 0;
      _startLoad();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _startLoad() {
    _framesFuture = _loadAndDecodeFrames(
      url: widget.imageUrl,
      maxFrames: widget.maxFrames,
      debug: widget.debug,
      debugLabel: widget.debugLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final framesFuture = _framesFuture;
    if (framesFuture == null) return widget.fallback;

    return FutureBuilder<List<_DecodedAnimatedFrame>>(
      future: framesFuture,
      builder: (context, snapshot) {
        final frames = snapshot.data;

        if (frames != null && frames.isNotEmpty) {
          if (!identical(_frames, frames)) {
            _frames = frames;
            _frameIndex = _frameIndex.clamp(0, _frames.length - 1).toInt();
            _scheduleCurrentFrame();
          }

          final safeIndex = _frameIndex.clamp(0, _frames.length - 1).toInt();
          return Image.memory(
            _frames[safeIndex].pngBytes,
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

  void _scheduleCurrentFrame() {
    if (_timer != null || _frames.length <= 1) return;

    final safeIndex = _frameIndex.clamp(0, _frames.length - 1).toInt();
    final durationMs = _frames[safeIndex].durationMs;

    _timer = Timer(Duration(milliseconds: durationMs), () {
      _timer = null;
      if (!mounted || _frames.isEmpty) return;

      setState(() {
        _frameIndex = (_frameIndex + 1) % _frames.length;
      });

      _scheduleCurrentFrame();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<List<_DecodedAnimatedFrame>> _loadAndDecodeFrames({
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

      final frames = await compute<_DecodeAnimatedEmoteRequest,
          List<_DecodedAnimatedFrame>>(
        _decodeAnimatedEmoteFrames,
        _DecodeAnimatedEmoteRequest(
          bytes: bytes,
          maxFrames: maxFrames,
        ),
      );

      if (debug) {
        debugPrint('[$debugLabel] decoded url=$cleanUrl frames=${frames.length}');
      }

      return frames;
    } catch (e, stackTrace) {
      if (debug) {
        debugPrint('[$debugLabel] decode failed url=$cleanUrl error=$e');
        debugPrint('$stackTrace');
      }
      return const <_DecodedAnimatedFrame>[];
    }
  }
}

class _DecodeAnimatedEmoteRequest {
  final Uint8List bytes;
  final int maxFrames;

  const _DecodeAnimatedEmoteRequest({
    required this.bytes,
    required this.maxFrames,
  });
}

class _DecodedAnimatedFrame {
  final Uint8List pngBytes;
  final int durationMs;

  const _DecodedAnimatedFrame({
    required this.pngBytes,
    required this.durationMs,
  });
}

List<_DecodedAnimatedFrame> _decodeAnimatedEmoteFrames(
  _DecodeAnimatedEmoteRequest request,
) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null || !decoded.isValid) {
    return const <_DecodedAnimatedFrame>[];
  }

  final frameCount = decoded.numFrames <= 0 ? 1 : decoded.numFrames;
  final safeMaxFrames = request.maxFrames <= 0 ? frameCount : request.maxFrames;
  final limit = frameCount < safeMaxFrames ? frameCount : safeMaxFrames;

  final output = <_DecodedAnimatedFrame>[];

  for (var i = 0; i < limit; i++) {
    final frame = decoded.getFrame(i);
    if (!frame.isValid || frame.width <= 0 || frame.height <= 0) continue;

    final rawDuration = frame.frameDuration;
    final durationMs = rawDuration <= 0 ? 80 : rawDuration.clamp(25, 1000).toInt();
    final png = Uint8List.fromList(img.encodePng(frame));

    output.add(_DecodedAnimatedFrame(
      pngBytes: png,
      durationMs: durationMs,
    ));
  }

  return output;
}
