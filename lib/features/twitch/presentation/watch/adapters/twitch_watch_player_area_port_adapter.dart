import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
import '../twitch_watch_playback_kind.dart';
import '../twitch_watch_port_scope.dart';
import '../controllers/twitch_playback_timeline_controller.dart';

/// Temporary isolation mode for the Android resize-black-frame investigation.
///
/// In a normal `flutter run` this is enabled by default because kDebugMode is
/// true. The mode can be disabled explicitly with:
/// --dart-define=TWITCH_DEBUG_MINIMAL_LIVE_WATCH=false
///
/// Release builds keep the normal Watch UI unless the define is explicitly
/// enabled.
const bool _debugMinimalLiveWatch = bool.fromEnvironment(
  'TWITCH_DEBUG_MINIMAL_LIVE_WATCH',
  defaultValue: kDebugMode,
);

/// Keep the normal Watch layout/player path but replace the expensive chat
/// subtree with a flat panel. This isolates whether relayout of live chat
/// content is what makes Android's external video texture flash during drag.
const bool _debugBlankChat = bool.fromEnvironment(
  'TWITCH_WATCH_DEBUG_BLANK_CHAT',
  defaultValue: false,
);

class TwitchWatchPlayerAreaPortAdapter extends StatelessWidget {
  final TwitchStreamHeaderMetadata metadata;
  final bool loading;
  final String? error;
  final bool showOfflinePlaceholder;
  final String? offlineImageUrl;
  final VoidCallback onBack;
  final VoidCallback? onHome;
  final VoidCallback? onOpenChannel;
  final VoidCallback? onCreateClip;
  final bool creatingClip;
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
  final bool hasFullLiveDvr;
  final bool showLiveEdgeLabel;
  final Duration? liveDvrDuration;
  final DateTime? liveDvrStartedAt;
  final ValueChanged<Duration>? onOpenDvrReplayAtPosition;
  final VoidCallback? onReturnToLive;
  final TwitchWatchPlaybackKind playbackKind;
  final TwitchPlaybackTimelineController? playbackTimelineController;

  const TwitchWatchPlayerAreaPortAdapter({
    super.key,
    required this.metadata,
    required this.loading,
    required this.error,
    this.showOfflinePlaceholder = false,
    this.offlineImageUrl,
    required this.onBack,
    this.onHome,
    this.onOpenChannel,
    this.onCreateClip,
    this.creatingClip = false,
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
    this.hasFullLiveDvr = false,
    this.showLiveEdgeLabel = false,
    this.liveDvrDuration,
    this.liveDvrStartedAt,
    this.onOpenDvrReplayAtPosition,
    this.onReturnToLive,
    this.playbackKind = TwitchWatchPlaybackKind.live,
    this.playbackTimelineController,
  });

  @override
  Widget build(BuildContext context) {
    final port = TwitchWatchPortScope.playerOf(context);

    if (_debugMinimalLiveWatch) {
      return _MinimalLiveResizeVideo(
        playbackKind: playbackKind,
        controller: port.videoControllerOrNull,
        error: error ?? port.runtime.error?.toString(),
      );
    }

    final usesLiveTimeline =
        playbackKind == TwitchWatchPlaybackKind.live ||
        playbackKind == TwitchWatchPlaybackKind.liveDvr;
    final effectiveLiveDvrDuration = usesLiveTimeline
        ? port.runtime.canonicalLiveTimelineDuration ?? liveDvrDuration
        : liveDvrDuration;
    return TwitchWatchPlayerArea(
      key: GlobalObjectKey(port.runtime),
      playerRuntime: port.runtime,
      player: port.playerOrNull,
      videoController: port.videoControllerOrNull,
      metadata: metadata,
      loading: loading,
      error: error,
      showOfflinePlaceholder: showOfflinePlaceholder,
      offlineImageUrl: offlineImageUrl,
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
      onHome: onHome,
      onOpenChannel: onOpenChannel,
      onCreateClip: onCreateClip,
      creatingClip: creatingClip,
      hasDvrReplay: hasDvrReplay,
      hasFullLiveDvr: hasFullLiveDvr,
      showLiveEdgeLabel: showLiveEdgeLabel,
      liveDvrDuration: effectiveLiveDvrDuration,
      liveDvrStartedAt: liveDvrStartedAt,
      onOpenDvrReplayAtPosition: onOpenDvrReplayAtPosition,
      onReturnToLive: onReturnToLive,
      playbackKind: playbackKind,
      playbackTimelineController: playbackTimelineController,
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

class _MinimalLiveResizeVideo extends StatelessWidget {
  final TwitchWatchPlaybackKind playbackKind;
  final VideoController? controller;
  final String? error;

  const _MinimalLiveResizeVideo({
    required this.playbackKind,
    required this.controller,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    // Use a conspicuous non-black backing color. If a resize exposes Flutter's
    // layout underneath the native texture, the flash will be purple instead
    // of black. If it still flashes pure black, that black comes from the raw
    // Video/native texture path rather than our Watch chrome or masks.
    const diagnosticBackground = Color(0xFF35134A);

    if (playbackKind != TwitchWatchPlaybackKind.live &&
        playbackKind != TwitchWatchPlaybackKind.none) {
      return const ColoredBox(
        color: diagnosticBackground,
        child: Center(
          child: Text(
            'DEBUG LIVE ONLY',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final videoController = controller;
    if (videoController == null) {
      return ColoredBox(
        color: diagnosticBackground,
        child: Center(
          child: Text(
            error?.trim().isNotEmpty == true
                ? 'LIVE ERROR\n$error'
                : 'WAITING FOR RAW LIVE VIDEO',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    // Deliberately bypass TwitchMediaKitVideoSurface, transition masks,
    // loading overlays, Watch controls, RepaintBoundary wrappers and all
    // custom player chrome. This is the closest possible test to raw
    // media_kit Video under the existing live playback session.
    return const ColoredBox(
      color: diagnosticBackground,
      child: SizedBox.expand(),
    ).withRawVideo(videoController);
  }
}

extension on Widget {
  Widget withRawVideo(VideoController controller) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        this,
        Video(
          controller: controller,
          fit: BoxFit.contain,
          controls: NoVideoControls,
        ),
      ],
    );
  }
}

class TwitchWatchChatPanelPortAdapter extends StatelessWidget {
  final TwitchChatRuntime? runtime;
  final String? viewerLogin;
  final String? viewerId;
  final bool viewerIsFollowing;
  final DateTime? viewerFollowedAt;
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
    required this.viewerIsFollowing,
    required this.viewerFollowedAt,
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
    if (_debugMinimalLiveWatch || _debugBlankChat) {
      // Preserve the real side-panel geometry and drag behavior while removing
      // chat message layout/repaint cost from the frame. This lets us separate
      // responsive-layout issues from chat-subtree pressure.
      return const ColoredBox(color: Color(0xFF1C1025));
    }

    final emotes = TwitchWatchPortScope.emotesOf(context);
    final openAction = onOpenSpecialActions;
    return TwitchWatchChatPanel(
      runtime: runtime,
      viewerLogin: viewerLogin,
      viewerId: viewerId,
      viewerIsFollowing: viewerIsFollowing,
      viewerFollowedAt: viewerFollowedAt,
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
