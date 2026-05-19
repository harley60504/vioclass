import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../platform/android_pip/twitch_android_pip_controller.dart';

const double twitchWatchVideoAspectRatio = 16 / 9;

class TwitchMediaKitVideoSurface extends StatefulWidget {
  final VideoController controller;
  final double aspectRatio;
  final BoxFit fit;
  final bool reportAndroidPipSourceRect;

  const TwitchMediaKitVideoSurface({
    super.key,
    required this.controller,
    this.aspectRatio = twitchWatchVideoAspectRatio,
    this.fit = BoxFit.contain,
    this.reportAndroidPipSourceRect = true,
  });

  @override
  State<TwitchMediaKitVideoSurface> createState() => _TwitchMediaKitVideoSurfaceState();
}

class _TwitchMediaKitVideoSurfaceState extends State<TwitchMediaKitVideoSurface> {
  final GlobalKey _videoSurfaceKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportSourceRectHint());
  }

  @override
  void didUpdateWidget(covariant TwitchMediaKitVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportSourceRectHint());
  }

  void _reportSourceRectHint() {
    if (!mounted || !Platform.isAndroid || !widget.reportAndroidPipSourceRect) return;
    final context = _videoSurfaceKey.currentContext;
    if (context == null) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final rect = topLeft & renderObject.size;
    unawaited(TwitchAndroidPipController.instance.setSourceRectHint(rect));
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;
          if (maxWidth <= 0 || maxHeight <= 0) return const SizedBox.shrink();

          var width = maxWidth;
          var height = width / widget.aspectRatio;
          if (height > maxHeight) {
            height = maxHeight;
            width = height * widget.aspectRatio;
          }
          width = width.clamp(1.0, maxWidth).toDouble();
          height = height.clamp(1.0, maxHeight).toDouble();
          WidgetsBinding.instance.addPostFrameCallback((_) => _reportSourceRectHint());

          return Center(
            child: SizedBox(
              key: _videoSurfaceKey,
              width: width,
              height: height,
              child: Video(
                controller: widget.controller,
                fit: widget.fit,
                controls: NoVideoControls,
              ),
            ),
          );
        },
      ),
    );
  }
}

class TwitchMediaKitVideoWaitingSurface extends StatelessWidget {
  const TwitchMediaKitVideoWaitingSurface({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}
