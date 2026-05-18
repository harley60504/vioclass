// PATCH VERSION: twitch_watch_port_adapters_stage220i_nullable_player_handles

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../../models/engagement/twitch_prediction.dart';
import '../../../models/playback/twitch_m3u8_variant.dart';
import '../../../services/chat/twitch_chat_runtime.dart';
import '../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../widgets/watch/twitch_watch_chat_panel.dart';
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
      player: port.playerOrNull,
      videoController: port.videoControllerOrNull,
      metadata: metadata,
      loading: loading,
      error: error,
      qualityVariants: port.qualityVariants,
      currentVariant: port.currentVariant,
      qualityBusy: port.runtime.switchingQuality || loading,
      onQualitySelected: (variant) => unawaited(_switchQuality(port, variant)),
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

class TwitchWatchChatPanelPortAdapter extends StatelessWidget {
  final TwitchChatRuntime? runtime;
  final String? viewerLogin;
  final String? viewerId;
  final TwitchStreamHeaderMetadata metadata;
  final TwitchChannelPointsRuntimeSnapshot? channelPoints;
  final List<dynamic> pinnedMessages;
  final TwitchPredictionSnapshot? prediction;
  final bool loadingEmotes;
  final bool loadingEngagement;
  final String? engagementError;
  final TextEditingController messageController;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onOpenEmotes;
  final VoidCallback onRefreshEmotes;
  final VoidCallback onRefreshEngagement;
  final VoidCallback onOpenChannelPoints;
  final VoidCallback onOpenPrediction;

  const TwitchWatchChatPanelPortAdapter({
    super.key,
    required this.runtime,
    required this.viewerLogin,
    required this.viewerId,
    required this.metadata,
    required this.channelPoints,
    required this.pinnedMessages,
    required this.prediction,
    required this.loadingEmotes,
    required this.loadingEngagement,
    required this.engagementError,
    required this.messageController,
    required this.sending,
    required this.onSend,
    required this.onOpenEmotes,
    required this.onRefreshEmotes,
    required this.onRefreshEngagement,
    required this.onOpenChannelPoints,
    required this.onOpenPrediction,
  });

  @override
  Widget build(BuildContext context) {
    final emotes = TwitchWatchPortScope.emotesOf(context);
    return TwitchWatchChatPanel(
      runtime: runtime,
      viewerLogin: viewerLogin,
      viewerId: viewerId,
      fallbackProfileImageUrl: metadata.profileImageUrl,
      fallbackDisplayName: metadata.displayName,
      fallbackUserId: metadata.channelId,
      fallbackLogin: metadata.channelLogin,
      thirdPartyEmoteCache: emotes.thirdParty,
      officialEmoteCache: emotes.official,
      emoteCount: emotes.thirdParty.count,
      loadingEmotes: loadingEmotes ||
          emotes.thirdParty.loading ||
          emotes.official.loading,
      channelPoints: channelPoints,
      pinnedMessages: pinnedMessages,
      prediction: prediction,
      loadingEngagement: loadingEngagement,
      engagementError: engagementError,
      messageController: messageController,
      sending: sending,
      onSend: onSend,
      onOpenEmotes: onOpenEmotes,
      onRefreshEmotes: onRefreshEmotes,
      onRefreshEngagement: onRefreshEngagement,
      onOpenChannelPoints: onOpenChannelPoints,
      onOpenPrediction: onOpenPrediction,
    );
  }
}
