import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../platform/android_pip/twitch_android_pip_controller.dart';
import '../../../theme/twitch_ui_tokens.dart';
import '../../../watch/controllers/twitch_dvr_transition_mask_controller.dart';

const double twitchWatchVideoAspectRatio = 16 / 9;

class TwitchMediaKitVideoSurface extends StatefulWidget {
  final VideoController controller;
  final double aspectRatio;
  final BoxFit fit;
  final bool reportAndroidPipSourceRect;
  final VideoControlsBuilder? controls;

  const TwitchMediaKitVideoSurface({
    super.key,
    required this.controller,
    this.aspectRatio = twitchWatchVideoAspectRatio,
    this.fit = BoxFit.contain,
    this.reportAndroidPipSourceRect = true,
    this.controls = NoVideoControls,
  });

  @override
  State<TwitchMediaKitVideoSurface> createState() =>
      _TwitchMediaKitVideoSurfaceState();
}

class _TwitchMediaKitVideoSurfaceState
    extends State<TwitchMediaKitVideoSurface> {
  static const Duration _androidSourceRectSettleDelay = Duration(
    milliseconds: 140,
  );

  final GlobalKey _videoSurfaceKey = GlobalKey();
  Timer? _sourceRectSettleTimer;
  Rect? _lastReportedSourceRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scheduleSourceRectHint(),
    );
  }

  @override
  void didUpdateWidget(covariant TwitchMediaKitVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scheduleSourceRectHint(),
    );
  }

  @override
  void dispose() {
    _sourceRectSettleTimer?.cancel();
    super.dispose();
  }

  void _scheduleSourceRectHint() {
    if (!mounted || !Platform.isAndroid || !widget.reportAndroidPipSourceRect) {
      return;
    }

    _sourceRectSettleTimer?.cancel();
    _sourceRectSettleTimer = Timer(_androidSourceRectSettleDelay, () {
      if (!mounted) return;
      _reportSourceRectHint();
    });
  }

  void _reportSourceRectHint() {
    if (!mounted || !Platform.isAndroid || !widget.reportAndroidPipSourceRect) {
      return;
    }
    final context = _videoSurfaceKey.currentContext;
    if (context == null) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        renderObject.size.isEmpty) {
      return;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final rect = topLeft & renderObject.size;
    final lastRect = _lastReportedSourceRect;
    if (lastRect != null && _rectNearlyEqual(lastRect, rect)) return;
    _lastReportedSourceRect = rect;
    unawaited(TwitchAndroidPipController.instance.setSourceRectHint(rect));
  }

  bool _rectNearlyEqual(Rect a, Rect b) {
    const tolerance = 1.0;
    return (a.left - b.left).abs() <= tolerance &&
        (a.top - b.top).abs() <= tolerance &&
        (a.right - b.right).abs() <= tolerance &&
        (a.bottom - b.bottom).abs() <= tolerance;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;
          if (maxWidth <= 0 || maxHeight <= 0) {
            return const SizedBox.shrink();
          }

          var width = maxWidth;
          var height = width / widget.aspectRatio;
          if (height > maxHeight) {
            height = maxHeight;
            width = height * widget.aspectRatio;
          }
          width = width.clamp(1.0, maxWidth).toDouble();
          height = height.clamp(1.0, maxHeight).toDouble();

          // Keep PiP geometry updates coalesced, but let media_kit's Video
          // widget follow the Flutter layout normally. Caching the Video widget
          // and forcing it through zero-sized intermediate constraints caused
          // Android SurfaceTexture resize flashes on some devices.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scheduleSourceRectHint(),
          );

          final transitionMask = TwitchDvrTransitionMaskController.instance;
          return Center(
            child: SizedBox(
              key: _videoSurfaceKey,
              width: width,
              height: height,
              child: AnimatedBuilder(
                animation: transitionMask,
                child: Video(
                  controller: widget.controller,
                  fit: widget.fit,
                  controls: widget.controls,
                ),
                builder: (context, video) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      video ?? const SizedBox.shrink(),
                      if (transitionMask.visible)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _PlaybackTransitionOverlay(
                              previewImageUrl:
                                  transitionMask.previewImageUrl,
                              showLoading: transitionMask.showLoading,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlaybackTransitionOverlay extends StatelessWidget {
  final String previewImageUrl;
  final bool showLoading;

  const _PlaybackTransitionOverlay({
    required this.previewImageUrl,
    required this.showLoading,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = previewImageUrl.trim();
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (imageUrl.isNotEmpty)
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        if (imageUrl.isNotEmpty)
          ColoredBox(color: Colors.black.withValues(alpha: 0.42)),
        if (showLoading)
          Center(
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.48),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: TwitchUiColors.primarySoft,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class TwitchMediaKitVideoWaitingSurface extends StatelessWidget {
  const TwitchMediaKitVideoWaitingSurface({super.key});

  @override
  Widget build(BuildContext context) {
    final transitionMask = TwitchDvrTransitionMaskController.instance;
    return AnimatedBuilder(
      animation: transitionMask,
      builder: (context, _) {
        if (transitionMask.visible) {
          return _PlaybackTransitionOverlay(
            previewImageUrl: transitionMask.previewImageUrl,
            showLoading: transitionMask.showLoading,
          );
        }
        return const ColoredBox(
          color: Colors.black,
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: TwitchUiColors.primarySoft,
              ),
            ),
          ),
        );
      },
    );
  }
}
