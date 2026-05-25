library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/chat/twitch_recent_messages_api_service.dart';
import '../../models/discovery/twitch_stream_header_metadata.dart';
import '../../models/engagement/twitch_prediction.dart';
import '../../models/special_actions/twitch_pending_special_message.dart';
import '../../models/special_actions/twitch_viewer_special_message_models.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../../services/chat/twitch_chat_runtime.dart';
import '../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../services/engagement/twitch_hype_train_controller.dart';
import '../../services/playback/twitch_media_kit_player_host.dart';
import '../../services/watch/twitch_watch_services.dart';
import '../../services/window/twitch_fullscreen_controller.dart';
import '../watch/adapters/twitch_watch_player_area_port_adapter.dart';
import '../watch/controllers/twitch_watch_chat_controller.dart';
import '../watch/controllers/twitch_watch_engagement_controller.dart';
import '../watch/controllers/twitch_watch_playback_controller.dart';
import '../watch/controllers/twitch_watch_preferences_controller.dart';
import '../watch/controllers/twitch_watch_relationship_controller.dart';
import '../watch/sheets/twitch_watch_sheet_port_launcher.dart';
import '../watch/twitch_watch_feature_ports.dart';
import '../watch/twitch_watch_port_scope.dart';
import '../watch/twitch_watch_scope.dart';
import '../widgets/watch/twitch_watch_blocking_startup_overlay.dart';
import '../widgets/watch/twitch_watch_responsive_body.dart';

import 'watch/twitch_watch_page_session.dart';
import 'watch/twitch_watch_page_preferences.dart';
import 'watch/twitch_watch_page_startup.dart';
import 'watch/twitch_watch_page_chat.dart';
import 'watch/twitch_watch_page_engagement.dart';
import 'watch/twitch_watch_page_relationship.dart';
import 'watch/twitch_watch_page_ui.dart';

const bool enableWatchPlayer = bool.fromEnvironment(
  'TWITCH_ENABLE_WATCH_PLAYER',
  defaultValue: true,
);

const bool enableChannelPointEmoteMenu = true;

const double minChatPanelWidth = 180.0;
const double maxEffectiveMinChatPanelWidth = 280.0;
const double maxChatPanelWidth = 620.0;
const double minChatPanelRatio = 0.22;
const double minStoredChatPanelRatio = 0.08;
const double maxChatPanelRatio = 0.48;

class TwitchWatchPage extends StatefulWidget {
  final TwitchStreamHeaderMetadata initialMetadata;

  final String? initialChannelLogin;
  final String? initialStreamTitle;
  final String? initialGameName;
  final String? initialLanguage;
  final List<String>? initialTags;
  final bool? initialIsMature;
  final int? initialViewerCount;
  final String? initialProfileImageUrl;

  const TwitchWatchPage({
    super.key,
    this.initialMetadata = const TwitchStreamHeaderMetadata.empty(),
    this.initialChannelLogin,
    this.initialStreamTitle,
    this.initialGameName,
    this.initialLanguage,
    this.initialTags,
    this.initialIsMature,
    this.initialViewerCount,
    this.initialProfileImageUrl,
  });

  TwitchStreamHeaderMetadata get resolvedInitialMetadata {
    final hasLegacyMetadata =
        initialChannelLogin != null ||
        initialStreamTitle != null ||
        initialGameName != null ||
        initialLanguage != null ||
        initialTags != null ||
        initialIsMature != null ||
        initialViewerCount != null ||
        initialProfileImageUrl != null;

    if (!hasLegacyMetadata) return initialMetadata;

    final legacyLogin = initialChannelLogin?.trim();
    final legacyTitle = initialStreamTitle?.trim();
    final legacyGame = initialGameName?.trim();
    final legacyLanguage = initialLanguage?.trim();
    final legacyProfileImage = initialProfileImageUrl?.trim();

    return initialMetadata.copyWith(
      channelLogin: legacyLogin != null && legacyLogin.isNotEmpty
          ? legacyLogin
          : initialMetadata.channelLogin,
      streamTitle: legacyTitle != null && legacyTitle.isNotEmpty
          ? legacyTitle
          : initialMetadata.streamTitle,
      gameName: legacyGame != null && legacyGame.isNotEmpty
          ? legacyGame
          : initialMetadata.gameName,
      language: legacyLanguage != null && legacyLanguage.isNotEmpty
          ? legacyLanguage
          : initialMetadata.language,
      tags: initialTags ?? initialMetadata.tags,
      isMature: initialIsMature ?? initialMetadata.isMature,
      viewerCount: initialViewerCount ?? initialMetadata.viewerCount,
      profileImageUrl:
          legacyProfileImage != null && legacyProfileImage.isNotEmpty
          ? legacyProfileImage
          : initialMetadata.profileImageUrl,
    );
  }

  @override
  State<TwitchWatchPage> createState() => TwitchWatchPageState();
}

class TwitchWatchPageState extends State<TwitchWatchPage> {
  late final TextEditingController channelController;
  late final TextEditingController messageController;
  late final TwitchWatchSessionHandles session;
  late final TwitchWatchPreferencesController preferencesController;
  late final TwitchWatchChatController chatController;
  late final TwitchWatchEngagementController engagementController;
  late final TwitchWatchRelationshipController relationshipController;
  late final TwitchWatchPlaybackController playbackController;

  TwitchWatchServices get watchServices => session.services;
  TwitchWatchFeaturePorts get watchPorts => session.ports;
  TwitchAuthService get authService => session.authService;
  TwitchDropsAuthService get dropsAuthService => session.dropsAuthService;
  TwitchWebGqlAuthService get webGqlAuthService => session.webGqlAuthService;
  TwitchAuthApiService get authApi => session.authApi;
  TwitchRecentMessagesApiService get recentMessagesApi =>
      session.recentMessagesApi;
  TwitchMediaKitPlayerSession get playerSession => session.playerSession;

  StreamSubscription<double>? playerVolumeSubscription;

  int watchLoadGeneration = 0;

  bool loadingAuth = true;
  bool loadingWatch = false;
  bool fullscreenMode = false;
  bool mobileImmersiveEntered = false;
  bool chatBootstrapping = false;
  bool engagementBootstrapping = false;
  bool emoteBootstrapping = false;
  bool relationshipBootstrapping = false;

  String? viewerLogin;
  String? viewerId;
  String? channelId;

  TwitchChatRuntime? get chatRuntime => chatController.runtime;
  bool get loadingPlayer => playbackController.loadingPlayer;
  bool get connectingChat => chatController.connectingChat;
  bool get sending => chatController.sending;
  bool get loadingEmotes => engagementController.loadingEmotes;
  bool get loadingEngagement => engagementController.loadingEngagement;
  bool get isMuted => preferencesController.muted;
  bool get checkingRelationship => relationshipController.checkingRelationship;
  bool get followBusy => relationshipController.followBusy;
  bool get isFollowing => relationshipController.isFollowing;
  bool get chatVisible => preferencesController.chatVisible;
  bool get loadingSpecialMessages => chatController.loadingSpecialMessages;
  double get chatPanelWidth => preferencesController.chatPanelWidth;
  double get chatPanelRatio => preferencesController.chatPanelRatio;
  double get volume => preferencesController.volume;
  String? get playerError => playbackController.playerError;
  String? get engagementError => engagementController.engagementError;
  String? get relationshipError => relationshipController.relationshipError;
  TwitchChannelPointsRuntimeSnapshot? get channelPointsSnapshot =>
      engagementController.channelPointsSnapshot;
  TwitchViewerSpecialMessagesSnapshotStage251? get specialMessagesSnapshot =>
      chatController.specialMessagesSnapshot;
  TwitchPendingSpecialMessage? get pendingSpecialMessage =>
      chatController.pendingSpecialMessage;
  TwitchPredictionSnapshot? get prediction => engagementController.prediction;
  TwitchHypeTrainController get hypeTrainController =>
      engagementController.hypeTrainController;
  List<dynamic> get pinnedMessages => engagementController.pinnedMessages;

  TwitchWatchSheetPortLauncher get sheetLauncher =>
      TwitchWatchSheetPortLauncher(
        emotes: watchPorts.emotes,
        engagement: watchPorts.engagement,
        showMessage: showSnack,
        insertMessageText: insertMessageText,
        setPendingSpecialMessage: setPendingSpecialMessage,
        refreshEngagement: refreshEngagement,
        refreshEmotes: loadThirdPartyEmotes,
        channelLogin: () => channelLogin,
        channelId: () => channelId,
        channelPointsSnapshot: () => channelPointsSnapshot,
        predictionSnapshot: () => prediction,
        loadingEmotes: () => loadingEmotes,
        emoteBootstrapping: () => emoteBootstrapping,
        loadingEngagement: () => loadingEngagement,
        engagementBootstrapping: () => engagementBootstrapping,
        enableChannelPointEmoteMenu: enableChannelPointEmoteMenu,
      );

  String get channelLogin {
    final value = channelController.text.trim().toLowerCase();
    return value.isEmpty ? 'roger9527' : value;
  }

  bool get busy =>
      loadingAuth ||
      loadingWatch ||
      loadingPlayer ||
      connectingChat ||
      chatBootstrapping;

  bool get showBlockingStartupMask {
    return loadingAuth ||
        loadingWatch ||
        chatBootstrapping ||
        connectingChat ||
        (enableWatchPlayer && loadingPlayer);
  }

  String get startupMaskTitle {
    if (loadingAuth) return '正在準備 Twitch 工作階段...';
    if (loadingWatch) return '正在準備觀看頁...';
    if (enableWatchPlayer && loadingPlayer) return '正在啟動播放器...';
    if (chatBootstrapping || connectingChat) return '正在連線聊天室...';
    return '正在載入...';
  }

  void notifyControllerChanged() {
    if (mounted) setState(() {});
  }

  void setResolvedChannelId(String resolvedChannelId) {
    final next = resolvedChannelId.trim();
    if (next.isEmpty || next == channelId) return;
    channelId = next;
    if (mounted) setState(() {});
  }

  bool isCurrentWatchTask(int generation, String channel) {
    return mounted &&
        generation == watchLoadGeneration &&
        channel.trim().toLowerCase() == channelLogin;
  }

  void showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();

    channelController = TextEditingController(
      text: widget.resolvedInitialMetadata.channelLogin,
    );
    messageController = TextEditingController();
    session = TwitchWatchSessionHandles.create(playerTitle: 'Twitch Raw Proxy');
    preferencesController = TwitchWatchPreferencesController(
      applyVolume: (volume) async {
        final player = playerSession.playerOrNull;
        if (player != null) await player.setVolume(volume);
      },
      minChatPanelWidth: minChatPanelWidth,
      maxEffectiveMinChatPanelWidth: maxEffectiveMinChatPanelWidth,
      maxChatPanelWidth: maxChatPanelWidth,
      minChatPanelRatio: minChatPanelRatio,
      minStoredChatPanelRatio: minStoredChatPanelRatio,
      maxChatPanelRatio: maxChatPanelRatio,
    )..addListener(notifyControllerChanged);
    chatController = TwitchWatchChatController(
      authService: authService,
      dropsAuthService: dropsAuthService,
      authApi: authApi,
      recentMessagesApi: recentMessagesApi,
      chatPort: watchPorts.chat,
      engagementPort: watchPorts.engagement,
      specialMessagesRuntime: watchServices.specialMessagesStage251.runtime,
      channelLogin: () => channelLogin,
      channelId: () => channelId,
      viewerId: () => viewerId,
      channelPointsSnapshot: () => channelPointsSnapshot,
      refreshEngagement: ({bool showSnackOnError = true}) =>
          refreshEngagement(showSnackOnError: showSnackOnError),
      refreshSpecialMessages: ({bool autoSelectPending = true}) =>
          refreshSpecialMessages(autoSelectPending: autoSelectPending),
      onChannelIdResolved: setResolvedChannelId,
      onViewerResolved: (viewerLogin, viewerId) {
        viewerLogin = viewerLogin;
        viewerId = viewerId;
      },
      showMessage: showSnack,
    )..addListener(notifyControllerChanged);
    engagementController = TwitchWatchEngagementController(
      emotesPort: watchPorts.emotes,
      engagementPort: watchPorts.engagement,
      channelLogin: () => channelLogin,
      channelId: () => channelId,
      viewerId: () => viewerId,
      isCurrentWatchTask: isCurrentWatchTask,
    )..addListener(notifyControllerChanged);
    relationshipController = TwitchWatchRelationshipController(
      relationshipPort: watchPorts.relationship,
      channelLogin: () => channelLogin,
      channelId: () => channelId,
      viewerId: () => viewerId,
      onChannelIdResolved: setResolvedChannelId,
      showMessage: showSnack,
    )..addListener(notifyControllerChanged);
    playbackController = TwitchWatchPlaybackController(
      playerPort: watchPorts.player,
      applyPlayerVolume: applyPlayerVolume,
      waitForInitialPlaybackSettle: waitForInitialPlaybackSettle,
    )..addListener(notifyControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await enterMobileImmersiveByDefault();
      if (!mounted) return;
      await loadWatchPreferences();
      if (!mounted) return;
      await loadAuth();
      if (mounted) await loadWatch();
    });
  }

  @override
  void dispose() {
    cancelDeferredWatchTasks();
    channelController.dispose();
    messageController.dispose();

    unawaited(watchPorts.player.disposeRuntime());
    playbackController.removeListener(notifyControllerChanged);
    relationshipController.removeListener(notifyControllerChanged);
    engagementController.removeListener(notifyControllerChanged);
    chatController.removeListener(notifyControllerChanged);
    preferencesController.removeListener(notifyControllerChanged);
    playbackController.dispose();
    relationshipController.dispose();
    engagementController.dispose();
    chatController.dispose();
    preferencesController.dispose();

    final volumeSubscriptionCancel = playerVolumeSubscription?.cancel();
    if (volumeSubscriptionCancel != null) {
      unawaited(volumeSubscriptionCancel);
    }

    unawaited(playerSession.pauseCurrent().catchError((_) {}));
    playerSession.release();

    if (fullscreenMode || mobileImmersiveEntered) {
      unawaited(TwitchFullscreenController.exitFullscreen());
    }

    session.closeApiClient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = chatRuntime;
    final metadata = widget.resolvedInitialMetadata.copyWith(
      channelLogin: channelLogin,
    );

    final playerArea = TwitchWatchPlayerAreaPortAdapter(
      metadata: metadata,
      loading: loadingPlayer,
      error: playerError,
      isFollowing: isFollowing,
      relationshipBusy:
          checkingRelationship || followBusy || relationshipBootstrapping,
      relationshipError: relationshipError,
      onToggleFollow: toggleFollowChannel,
      onSubscribe: openSubscribePage,
      chatVisible: fullscreenMode ? false : chatVisible,
      fullscreenMode: fullscreenMode,
      showFullscreenButton: TwitchFullscreenController.isDesktopPlatform,
      onToggleChat: fullscreenMode ? null : toggleChatVisibility,
      onToggleFullscreen: () => unawaited(toggleFullscreenMode()),
      muted: isMuted,
      volume: volume,
      onToggleMute: () => unawaited(togglePlayerMute()),
      onVolumeChanged: (value) => unawaited(setPlayerVolume(value)),
      onBack: () => Navigator.of(context).maybePop(),
      onReload: busy ? null : loadWatch,
      onStop: () => stopCurrentSession(),
      onError: (message) {
        if (!mounted) return;
        playbackController.setError(message);
        showSnack('播放器操作失敗：$message');
      },
    );

    final chatPanel = TwitchWatchChatPanelPortAdapter(
      runtime: runtime,
      viewerLogin: viewerLogin,
      viewerId: viewerId,
      metadata: metadata,
      channelPoints: channelPointsSnapshot,
      pendingSpecialMessage: pendingSpecialMessage,
      pinnedMessages: pinnedMessages,
      prediction: prediction,
      hypeTrainController: hypeTrainController,
      loadingEmotes: loadingEmotes || emoteBootstrapping,
      loadingEngagement: loadingEngagement || engagementBootstrapping,
      engagementError: engagementError,
      messageController: messageController,
      sending: sending,
      onSend: sendMessage,
      onOpenEmotes: openEmotePicker,
      onRefreshEmotes: () => loadThirdPartyEmotes(forceRefresh: true),
      onRefreshEngagement: () => refreshEngagement(showSnackOnError: true),
      onOpenChannelPoints: openChannelPointsSheet,
      onOpenPrediction: openPredictionBetSheet,
      onOpenSpecialActions: openSpecialMessagesSheet,
      onCancelPendingSpecialMessage: clearPendingSpecialMessage,
    );

    final scaffold = Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: Stack(
        children: [
          Positioned.fill(
            child: TwitchWatchResponsiveBody(
              chatVisible: fullscreenMode ? false : chatVisible,
              fullscreenMode: fullscreenMode,
              chatPanelWidth: chatPanelWidth,
              chatPanelRatio: chatPanelRatio,
              minChatPanelWidth: minChatPanelWidth,
              maxEffectiveMinChatPanelWidth: maxEffectiveMinChatPanelWidth,
              maxChatPanelWidth: maxChatPanelWidth,
              minChatPanelRatio: minChatPanelRatio,
              minStoredChatPanelRatio: minStoredChatPanelRatio,
              maxChatPanelRatio: maxChatPanelRatio,
              player: playerArea,
              chat: chatPanel,
              onSetChatPanelWidthForViewport: setChatPanelWidthForViewport,
              onPersistChatPanelWidth: () {
                unawaited(saveChatPanelWidthPreference());
              },
            ),
          ),
          if (showBlockingStartupMask)
            Positioned.fill(
              child: TwitchWatchBlockingStartupOverlay(
                title: startupMaskTitle,
                subtitle: enableWatchPlayer
                    ? '先啟動播放器，再連線聊天室；互動資料與貼圖會在背景補上。'
                    : '正在連線聊天室；互動資料與貼圖會在背景補上。',
              ),
            ),
        ],
      ),
    );

    return TwitchWatchScope(
      services: watchServices,
      child: TwitchWatchPortScope(ports: watchPorts, child: scaffold),
    );
  }
}
