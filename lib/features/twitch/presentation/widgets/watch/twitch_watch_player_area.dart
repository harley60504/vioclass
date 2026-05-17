// PATCH VERSION: watch_player_area_stage205_restore_contain_fit
// Place at: lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart
//
// StreamNook-style player area entry point.
// Stage 189A: player chrome uses shared glass surfaces.
// Stage 201: player area no longer paints a full black background, allowing the
// WatchPage purple gradient background to show around letterboxed video.
// Stage 205: restore BoxFit.contain. BoxFit.cover can make media_kit's native
// video surface appear clipped/overflowed outside the intended player region on
// Windows. The no-black-bar work now belongs to responsive layout sizing.

library twitch_watch_player_area;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../../models/playback/twitch_m3u8_variant.dart';
import '../../../services/playback/twitch_playlist_player_runtime.dart';
import '../shared/twitch_glass.dart';

part 'player/twitch_watch_controls_overlay.dart';
part 'player/twitch_watch_top_action_bar.dart';
part 'player/twitch_watch_stream_header.dart';
part 'player/twitch_watch_top_buttons.dart';
part 'player/twitch_watch_bottom_control_bar.dart';
part 'player/twitch_live_playback_strip.dart';
part 'player/twitch_player_volume_control.dart';
part 'player/twitch_player_more_actions_button.dart';
part 'player/twitch_player_quality_button.dart';
part 'player/twitch_player_common_buttons.dart';
part 'player/twitch_player_error_card.dart';

class TwitchWatchPlayerArea extends StatelessWidget {
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final Player player;
  final VideoController videoController;
  final TwitchStreamHeaderMetadata metadata;
  final bool loading;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback? onReload;
  final VoidCallback onStop;

  // Compatibility with current watch_page call site. These values are optional
  // aliases because older WatchPage versions pass quality/relationship state
  // directly instead of reading it from playerRuntime.
  final List<TwitchM3u8Variant>? qualityVariants;
  final TwitchM3u8Variant? currentVariant;
  final bool qualityBusy;
  final ValueChanged<TwitchM3u8Variant>? onQualitySelected;
  final bool relationshipBusy;
  final String? relationshipError;

  final bool isFollowing;
  final bool followBusy;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onSubscribe;

  final bool chatVisible;
  final VoidCallback? onToggleChat;
  final bool fullscreen;
  final bool fullscreenMode;
  final bool showFullscreenButton;
  final VoidCallback? onToggleFullscreen;

  final bool muted;
  final double volume;
  final VoidCallback? onToggleMute;
  final ValueChanged<double>? onVolumeChanged;
  final ValueChanged<TwitchM3u8Variant>? onQualityChanged;

  const TwitchWatchPlayerArea({
    super.key,
    required this.playerRuntime,
    required this.player,
    required this.videoController,
    required this.metadata,
    required this.loading,
    required this.error,
    required this.onBack,
    required this.onReload,
    required this.onStop,
    this.qualityVariants,
    this.currentVariant,
    this.qualityBusy = false,
    this.onQualitySelected,
    this.relationshipBusy = false,
    this.relationshipError,
    this.isFollowing = false,
    this.followBusy = false,
    this.onToggleFollow,
    this.onSubscribe,
    this.chatVisible = true,
    this.onToggleChat,
    this.fullscreen = false,
    this.fullscreenMode = false,
    this.showFullscreenButton = true,
    this.onToggleFullscreen,
    this.muted = false,
    this.volume = 100,
    this.onToggleMute,
    this.onVolumeChanged,
    this.onQualityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playerRuntime,
      builder: (context, _) {
        final effectiveFullscreen = fullscreen || fullscreenMode;
        final effectiveChatVisible = chatVisible;
        final effectiveFollowBusy = followBusy || relationshipBusy;
        final effectiveQualityVariants =
            qualityVariants ?? playerRuntime.variants;
        final effectiveCurrentVariant =
            currentVariant ?? playerRuntime.currentVariant;
        final effectiveOnQualityChanged =
            onQualityChanged ?? onQualitySelected;

        return ColoredBox(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: Video(
                  controller: videoController,
                  fit: BoxFit.contain,
                  // v37: 把 Watch Page 的控制列放進 media_kit Video.controls。
                  // Windows 上原生 video surface 有時會蓋住 Flutter Stack overlay，
                  // 造成「有聲音但黑畫面、控制列出不來」。放進 controls layer
                  // 可避免控制列被 video surface 壓在下面。
                  //
                  // Stage 205: keep Video itself safe/contained. Avoid cover here
                  // because native video surfaces may ignore Flutter clipping on
                  // Windows and appear outside the player shell.
                  controls: (_) => _WatchControlsOverlay(
                    loading: loading ||
                        playerRuntime.loading ||
                        playerRuntime.switchingQuality,
                    error: error,
                    runtimeError: playerRuntime.error,
                    metadata: metadata,
                    isFollowing: isFollowing,
                    followBusy: effectiveFollowBusy,
                    onBack: onBack,
                    onToggleFollow: onToggleFollow,
                    onSubscribe: onSubscribe,
                    onReload: onReload,
                    onStop: onStop,
                    player: player,
                    playerRuntime: playerRuntime,
                    muted: muted,
                    volume: volume,
                    fullscreen: effectiveFullscreen,
                    chatVisible: effectiveChatVisible,
                    showFullscreenButton: showFullscreenButton,
                    onToggleMute: onToggleMute,
                    onVolumeChanged: onVolumeChanged,
                    qualityVariants: effectiveQualityVariants,
                    currentVariant: effectiveCurrentVariant,
                    onQualityChanged: effectiveOnQualityChanged,
                    onToggleChat: onToggleChat,
                    onToggleFullscreen: onToggleFullscreen,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
