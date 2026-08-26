import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../../models/engagement/twitch_prediction.dart';
import '../../../models/playback/twitch_m3u8_variant.dart';
import '../../../models/special_actions/twitch_pending_special_message.dart';
import '../../../services/chat/twitch_chat_runtime.dart';
import '../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../../services/engagement/twitch_hype_train_controller.dart';
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
  final VoidCallback? onOpenChannel;
  final VoidCallback? onCreateClip;
  final bool creatingClip;
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
  final List<TwitchM3u8Variant>? qualityVariants;
  final TwitchM3u8Variant? currentVariant;
  final ValueChanged<TwitchM3u8Variant>? onQualitySelected;
  final ValueChanged<String>? onError;
  final bool hasDvrReplay;
  final bool showLiveEdgeLabel;
  final Duration? liveDvrDuration;
  final DateTime? liveDvrStartedAt;
  final ValueChanged<double>? onOpenDvrReplayAt;
  final VoidCallback? onReturnToLive;

  const TwitchWatchPlayerAreaPortAdapter({
    super.key,
    required this.metadata,
    required this.loading,
    required this.error,
    required this.onBack,
    required this.onReload,
    this.onOpenChannel,
    this.onCreateClip,
    this.creatingClip = false,
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
    this.qualityVariants,
    this.currentVariant,
    this.onQualitySelected,
    this.onError,
    this.hasDvrReplay = false,
    this.showLiveEdgeLabel = false,
    this.liveDvrDuration,
    this.liveDvrStartedAt,
    this.onOpenDvrReplayAt,
    this.onReturnToLive,
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
      qualityVariants: qualityVariants ?? port.qualityVariants,
      currentVariant: currentVariant ?? port.currentVariant,
      qualityBusy: port.runtime.switchingQuality || loading,
      onQualitySelected:
          onQualitySelected ??
          (variant) => unawaited(_switchQuality(port, variant)),
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
      onOpenChannel: onOpenChannel,
      onCreateClip: onCreateClip,
      creatingClip: creatingClip,
      onStop: onStop,
      hasDvrReplay: hasDvrReplay,
      showLiveEdgeLabel: showLiveEdgeLabel,
      liveDvrDuration: liveDvrDuration,
      liveDvrStartedAt: liveDvrStartedAt,
      onOpenDvrReplayAt: onOpenDvrReplayAt,
      onReturnToLive: onReturnToLive,
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
  final TwitchPendingSpecialMessage? pendingSpecialMessage;
  final List<dynamic> pinnedMessages;
  final TwitchPredictionSnapshot? prediction;
  final TwitchHypeTrainController hypeTrainController;
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
  final VoidCallback? onOpenSpecialActions;
  final VoidCallback? onCancelPendingSpecialMessage;
  final bool showHeader;

  const TwitchWatchChatPanelPortAdapter({
    super.key,
    required this.runtime,
    required this.viewerLogin,
    required this.viewerId,
    required this.metadata,
    required this.channelPoints,
    this.pendingSpecialMessage,
    required this.pinnedMessages,
    required this.prediction,
    required this.hypeTrainController,
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
    this.onOpenSpecialActions,
    this.onCancelPendingSpecialMessage,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final emotes = TwitchWatchPortScope.emotesOf(context);
    final openAction = onOpenSpecialActions;
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
      loadingEmotes:
          loadingEmotes || emotes.thirdParty.loading || emotes.official.loading,
      channelPoints: channelPoints,
      pendingSpecialMessage: pendingSpecialMessage,
      pinnedMessages: pinnedMessages,
      prediction: prediction,
      hypeTrainController: hypeTrainController,
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
      onOpenSpecialActions: openAction,
      onCancelPendingSpecialMessage: onCancelPendingSpecialMessage,
      showHeader: showHeader,
    );
  }
}
