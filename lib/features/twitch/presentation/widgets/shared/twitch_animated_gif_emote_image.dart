import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../services/chat/twitch_emote_image_cache_manager.dart';

class TwitchAnimatedGifEmoteImage extends StatefulWidget {
  final String url;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;
  final FilterQuality filterQuality;

  const TwitchAnimatedGifEmoteImage({
    super.key,
    required this.url,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.low,
  });

  @override
  State<TwitchAnimatedGifEmoteImage> createState() =>
      _TwitchAnimatedGifEmoteImageState();
}

class _TwitchAnimatedGifEmoteImageState
    extends State<TwitchAnimatedGifEmoteImage> {
  static final Map<String, Future<_DecodedGifEmote>> _decodedCache =
      <String, Future<_DecodedGifEmote>>{};

  _DecodedGifEmote? _emote;
  Timer? _timer;
  int _frameIndex = 0;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant TwitchAnimatedGifEmoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.url != widget.url) {
      _timer?.cancel();
      _emote = null;
      _frameIndex = 0;
      _error = null;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emote = _emote;
    if (_error != null || emote == null || emote.frames.isEmpty) {
      return widget.fallback;
    }

    final index = _frameIndex.clamp(0, emote.frames.length - 1);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.fallback,
        Image.memory(
          emote.frames[index],
          key: ValueKey<int>(index),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          filterQuality: widget.filterQuality,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Future<void> _load() async {
    final url = widget.url.trim();
    if (url.isEmpty) return;

    try {
      final emote = await _decodedCache.putIfAbsent(url, () => _decodeUrl(url));
      if (!mounted || widget.url.trim() != url) return;
      setState(() {
        _emote = emote;
        _frameIndex = 0;
        _error = null;
      });
      _scheduleNextFrame();
    } catch (error) {
      if (!mounted || widget.url.trim() != url) return;
      setState(() {
        _error = error;
      });
    }
  }

  void _scheduleNextFrame() {
    _timer?.cancel();

    final emote = _emote;
    if (emote == null || emote.frames.length <= 1) return;

    final delay = emote.durations[_frameIndex].clamp(40, 1000);
    _timer = Timer(Duration(milliseconds: delay), () {
      if (!mounted || _emote != emote) return;
      setState(() {
        _frameIndex = (_frameIndex + 1) % emote.frames.length;
      });
      _scheduleNextFrame();
    });
  }

  static Future<_DecodedGifEmote> _decodeUrl(String url) async {
    final source = await TwitchEmoteImageCacheManager.instance.getSingleFile(
      url,
    );
    final bytes = await source.readAsBytes();
    final decoded = await compute(_decodeAnimatedGifFrames, bytes);
    return _DecodedGifEmote.fromPayload(decoded);
  }
}

class _DecodedGifEmote {
  final List<Uint8List> frames;
  final List<int> durations;

  const _DecodedGifEmote({required this.frames, required this.durations});

  factory _DecodedGifEmote.fromPayload(Map<String, Object?> payload) {
    final frames = (payload['frames'] as List<Object?>)
        .cast<Uint8List>()
        .toList(growable: false);
    final durations = (payload['durations'] as List<Object?>)
        .cast<int>()
        .toList(growable: false);

    if (frames.isEmpty || frames.length != durations.length) {
      throw StateError('Invalid animated GIF emote frame payload.');
    }

    return _DecodedGifEmote(frames: frames, durations: durations);
  }
}

Map<String, Object?> _decodeAnimatedGifFrames(Uint8List bytes) {
  final animation = img.decodeGif(bytes);
  if (animation == null || animation.numFrames <= 1) {
    throw StateError('Unable to decode animated GIF emote.');
  }

  final frames = <Uint8List>[];
  final durations = <int>[];

  for (final frame in animation.frames) {
    frames.add(Uint8List.fromList(img.encodePng(frame)));
    durations.add(frame.frameDuration <= 0 ? 60 : frame.frameDuration);
  }

  return <String, Object?>{'frames': frames, 'durations': durations};
}
