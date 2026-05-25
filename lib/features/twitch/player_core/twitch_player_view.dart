// Stage 220A: Independent Twitch player view.
//
// This view renders the media_kit Video surface owned by TwitchPlayerController.
// It is intentionally small: no WatchPage chat, no engagement UI, no sheet logic.

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'twitch_player_controller.dart';

class TwitchPlayerView extends StatelessWidget {
  final TwitchPlayerController controller;
  final BoxFit fit;
  final Color backgroundColor;
  final bool showDebugOverlay;
  final Widget? overlay;

  const TwitchPlayerView({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
    this.backgroundColor = Colors.black,
    this.showDebugOverlay = false,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final videoController = controller.videoControllerOrNull;

        return ColoredBox(
          color: backgroundColor,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (videoController == null)
                const _TwitchPlayerCorePlaceholder()
              else
                Video(
                  controller: videoController,
                  fit: fit,
                  controls: NoVideoControls,
                ),
              if (state.opening || state.buffering)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                  ),
                ),
              if (state.error != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: _TwitchPlayerCoreErrorCard(error: state.error!),
                    ),
                  ),
                ),
              if (overlay != null) Positioned.fill(child: overlay!),
              if (showDebugOverlay)
                Positioned(
                  left: 8,
                  top: 8,
                  child: _TwitchPlayerCoreDebugBadge(controller: controller),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TwitchPlayerCorePlaceholder extends StatelessWidget {
  const _TwitchPlayerCorePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Twitch Player Core',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TwitchPlayerCoreErrorCard extends StatelessWidget {
  final Object error;

  const _TwitchPlayerCoreErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC1F1329),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        error.toString(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TwitchPlayerCoreDebugBadge extends StatelessWidget {
  final TwitchPlayerController controller;

  const _TwitchPlayerCoreDebugBadge({required this.controller});

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final text = [
      state.profile.id,
      state.playing ? 'playing' : 'paused',
      if (state.buffering) 'buffering',
      if (state.hasVideoSize) '${state.videoWidth}x${state.videoHeight}',
      'vol=${state.volume.toStringAsFixed(0)}',
    ].join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xAA000000),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
