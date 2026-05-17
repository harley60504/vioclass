// PATCH VERSION: twitch_watch_player_area_port_adapter_stage187a
//
// Adapter that lets the Watch player area consume TwitchWatchPlayerPort.
//
// This is the first real migration away from WatchPage passing every player
// dependency manually. WatchPage can keep owning temporary UI state like volume
// and fullscreen while player API/runtime dependencies come from the port.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../../models/playback/twitch_m3u8_variant.dart';
import '../../widgets/watch/twitch_watch_player_area.dart';
import '../twitch_watch_feature_ports.dart';
import '../twitch_watch_port_scope.dart';

class TwitchWatchPlayerAreaPortAdapter extends StatelessWidget {
  final TwitchStreamHeaderMetadata metadata;
  final bool loading;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback? onReload;
  final VoidCallback onStop;

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

  final ValueChanged<String>? onError;

  const TwitchWatchPlayerAreaPortAdapter({
    super.key,
    required this.metadata,
    required this.loading,
    required this.error,
    required this.onBack,
    required this.onReload,
    required this.onStop,
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
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    final port = TwitchWatchPortScope.playerOf(context);

    return TwitchWatchPlayerArea(
      playerRuntime: port.runtime,
      player: port.player,
      videoController: port.videoController,
      metadata: metadata,
      loading: loading,
      error: error,
      qualityVariants: port.qualityVariants,
      currentVariant: port.currentVariant,
      qualityBusy: port.runtime.switchingQuality || loading,
      onQualitySelected: (variant) {
        unawaited(_switchQuality(port, variant));
      },
      relationshipBusy: relationshipBusy,
      relationshipError: relationshipError,
      isFollowing: isFollowing,
      followBusy: followBusy,
      onToggleFollow: onToggleFollow,
      onSubscribe: onSubscribe,
      chatVisible: chatVisible,
      fullscreen: fullscreen,
      fullscreenMode: fullscreenMode,
      showFullscreenButton: showFullscreenButton,
      onToggleChat: onToggleChat,
      onToggleFullscreen: onToggleFullscreen,
      muted: muted,
      volume: volume,
      onToggleMute: onToggleMute,
      onVolumeChanged: onVolumeChanged,
      onBack: onBack,
      onReload: onReload,
      onStop: onStop,
    );
  }

  Future<void> _switchQuality(
    TwitchWatchPlayerPort port,
    TwitchM3u8Variant variant,
  ) async {
    try {
      await port.switchQuality(variant);
    } catch (error) {
      onError?.call(error.toString());
    }
  }
}
