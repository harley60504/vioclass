library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/channel/twitch_user_api_service.dart';
import '../../api/chat/twitch_recent_messages_api_service.dart';
import '../../api/chat/twitch_vod_comments_api_service.dart';
import '../../api/core/twitch_helix_api_service.dart';
import '../../models/discovery/twitch_stream_header_metadata.dart';
import '../../models/discovery/twitch_live_stream.dart';
import '../../models/engagement/twitch_prediction.dart';
import '../../models/playback/twitch_m3u8_variant.dart';
import '../../models/special_actions/twitch_pending_special_message.dart';
import '../../models/special_actions/twitch_viewer_special_message_models.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../../services/chat/twitch_badge_cache_service.dart';
import '../../services/chat/twitch_chat_runtime.dart';
import '../../services/chat/twitch_vod_chat_replay_runtime.dart';
import '../../services/discovery/twitch_channel_snapshot_cache.dart';
import '../../services/discovery/twitch_discovery_service.dart';
import '../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../services/engagement/twitch_hype_train_controller.dart';
import '../../services/engagement/twitch_prediction_hermes_runtime_service.dart';
import '../../services/playback/twitch_media_kit_player_host.dart';
import '../../services/playback/twitch_playlist_player_runtime.dart';
import '../../services/watch/twitch_watch_services.dart';
import '../../services/playback/twitch_vod_snapshot_playlist_proxy.dart';
import '../../services/window/twitch_fullscreen_controller.dart';
import '../../platform/android_pip/twitch_android_pip_controller.dart';
import '../watch/adapters/twitch_watch_player_area_port_adapter.dart';
import '../watch/controllers/twitch_watch_chat_controller.dart';
import '../watch/controllers/twitch_watch_engagement_controller.dart';
import '../watch/controllers/twitch_watch_playback_controller.dart';
import '../watch/controllers/twitch_watch_preferences_controller.dart';
import '../watch/controllers/twitch_watch_relationship_controller.dart';
import '../watch/sheets/twitch_watch_sheet_port_launcher.dart';
import '../watch/twitch_watch_feature_ports.dart';
import '../watch/twitch_watch_port_scope.dart';
import '../watch/twitch_watch_playback_kind.dart';
import '../watch/twitch_watch_scope.dart';
import '../mini_player/twitch_mini_player_controller.dart';
import '../watch/twitch_playback_session_controller.dart';
import '../dialogs/twitch_clip_editor_dialog.dart';
import '../widgets/channel/twitch_channel_about_section.dart';
import '../widgets/watch/chat/twitch_vod_replay_chat_panel.dart';
import '../widgets/watch/twitch_watch_responsive_body.dart';
import '../settings/twitch_player_settings_controller.dart';
import 'twitch_channel_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'watch/twitch_watch_page_session.dart';
import 'watch/twitch_watch_page_preferences.dart';
import 'watch/twitch_watch_page_startup.dart';
import 'watch/twitch_watch_page_chat.dart';
import 'watch/twitch_watch_page_engagement.dart';
import 'watch/twitch_watch_page_navigation.dart';
import 'watch/twitch_watch_page_relationship.dart';
import 'watch/twitch_watch_page_ui.dart';
import 'watch/twitch_watch_playback_state.dart';

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
  final TwitchFollowedChannel? initialOfflineChannel;
  final TwitchDiscoveryService? initialDiscoveryService;
  final bool initialOfflineFallbackAllowed;
  final TwitchChannelVideo? initialActiveDvrVideo;
  final TwitchChannelVideo? initialVodVideo;
  final TwitchChannelClip? initialClip;
  final double? initialVodReplayRatio;
  final bool initialPreferVodReplayChat;
  final bool initialVodPlaybackOnly;
  final bool initialReuseCurrentPlayback;
  final TwitchPlaylistPlayerRuntime? initialPlayerRuntime;
  final bool? initialKnownFollowing;

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
    this.initialOfflineChannel,
    this.initialDiscoveryService,
    this.initialOfflineFallbackAllowed = false,
    this.initialActiveDvrVideo,
    this.initialVodVideo,
    this.initialClip,
    this.initialVodReplayRatio,
    this.initialPreferVodReplayChat = false,
    this.initialVodPlaybackOnly = false,
    this.initialReuseCurrentPlayback = false,
    this.initialPlayerRuntime,
    this.initialKnownFollowing,
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

    if (!hasLegacyMetadata) {
      return TwitchChannelSnapshotCache.instance.resolveHeaderMetadata(
        initialMetadata,
      );
    }

    final legacyLogin = initialChannelLogin?.trim();
    final legacyTitle = initialStreamTitle?.trim();
    final legacyGame = initialGameName?.trim();
    final legacyLanguage = initialLanguage?.trim();
    final legacyProfileImage = initialProfileImageUrl?.trim();

    final metadata = initialMetadata.copyWith(
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
    return TwitchChannelSnapshotCache.instance.resolveHeaderMetadata(metadata);
  }

  TwitchFollowedChannel? get resolvedInitialOfflineChannel {
    return TwitchChannelSnapshotCache.instance.resolveFollowedChannel(
      channel: initialOfflineChannel,
      metadata: resolvedInitialMetadata,
    );
  }

  bool? get resolvedInitialFollowStatus {
    if (initialKnownFollowing != null) return initialKnownFollowing;

    final channel = resolvedInitialOfflineChannel;
    return TwitchChannelSnapshotCache.instance.findKnownFollowStatus(
      id: channel?.broadcasterId,
      login: channel?.channelLogin ?? resolvedInitialMetadata.channelLogin,
    );
  }

  @override
  State<TwitchWatchPage> createState() => TwitchWatchPageState();
}

class TwitchWatchPageState extends State<TwitchWatchPage>
    with WidgetsBindingObserver {
  final Object playbackRouteOwner = Object();

  late final TextEditingController channelController;
  late final TextEditingController messageController;
  late final TwitchWatchSessionHandles session;
  late final TwitchWatchPreferencesController preferencesController;
  late final TwitchWatchChatController chatController;
  late final TwitchWatchEngagementController engagementController;
  late final TwitchWatchRelationshipController relationshipController;
  late final TwitchWatchPlaybackController playbackController;
  late final TwitchVodChatReplayRuntime vodReplayController;
  late final TwitchVodSnapshotPlaylistProxy vodSnapshotPlaylistProxy;

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
  TwitchPlaybackSessionState? restorePlaybackOnDispose;
  TwitchPlaybackSessionState? ownedPlaybackForVisibleRoute;
  bool handedOffToMiniPlayer = false;
  bool leavingToMiniPlayer = false;
  bool reuseCurrentPlaybackOnNextLiveLoad = false;
  bool? _initialKnownFollowStatus;

  bool loadingAuth = true;
  bool loadingWatch = false;
  bool creatingClip = false;
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
  bool get effectiveIsFollowing {
    if (relationshipController.hasResolvedRelationshipStatus) {
      return relationshipController.isFollowing;
    }
    return _initialKnownFollowStatus ?? relationshipController.isFollowing;
  }

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
  TwitchChannelVideo? offlineVodFallbackVideo;
  bool showOfflineChannelPlaceholder = false;
  TwitchChannelVideo? activeGrowingVodVideo;
  TwitchChannelVideo? currentVodQualityVideo;
  TwitchChannelClip? currentClipQualityClip;
  List<TwitchM3u8Variant> vodQualityVariants = const <TwitchM3u8Variant>[];
  TwitchM3u8Variant? currentVodQualityVariant;
  String? warmedLiveDvrVideoId;
  String? warmedLiveDvrQualityKey;
  DateTime? warmedLiveDvrResolvedAt;
  bool preferVodReplayChat = false;
  List<TwitchChannelPanel> aboutPanels = const <TwitchChannelPanel>[];
  List<TwitchChannelSocialLink> aboutSocialLinks =
      const <TwitchChannelSocialLink>[];
  String? aboutErrorText;
  bool loadingAboutPanels = false;

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

  Future<void> createLiveClip() async {
    if (creatingClip) return;
    if (currentPlaybackKind != TwitchWatchPlaybackKind.live) {
      showSnack('目前在 VOD/片段模式，請先回直播再建立片段。');
      return;
    }

    final activeChannelId = channelId?.trim();
    final fallbackChannelId =
        widget.resolvedInitialOfflineChannel?.broadcasterId.trim() ?? '';
    final cleanChannelId = activeChannelId != null && activeChannelId.isNotEmpty
        ? activeChannelId
        : fallbackChannelId;
    if (cleanChannelId.isEmpty) {
      showSnack('正在取得頻道資訊，稍後再試一次。');
      return;
    }

    setState(() => creatingClip = true);
    try {
      final live = await watchServices.clipApi.getLiveBroadcast(
        broadcasterId: cleanChannelId,
      );
      final startedAt = live.startedAt;
      final offsetSeconds = startedAt == null
          ? 0.0
          : DateTime.now()
                .toUtc()
                .difference(startedAt.toUtc())
                .inSeconds
                .toDouble();
      if (offsetSeconds < 30) {
        showSnack('直播剛開始，至少約 30 秒後才能剪片段。');
        return;
      }
      if (!mounted) return;
      setState(() => creatingClip = false);
      await showTwitchClipEditorDialog(
        context: context,
        clipApi: watchServices.clipApi,
        playbackApi: watchServices.playbackApi,
        broadcastId: live.broadcastId,
        offsetSeconds: offsetSeconds,
        channelName: channelLogin,
      );
    } catch (error) {
      final message = error.toString();
      if (message.contains('Drops / Android token')) {
        showSnack('片段剪輯失敗，請先補 Drops / Android 授權。');
      } else if (_looksLikeClipDisabledError(message)) {
        showSnack('這個實況主可能沒有開放片段。');
      } else {
        showSnack('片段剪輯暫時失敗，稍後再試。');
      }
    } finally {
      if (mounted) setState(() => creatingClip = false);
    }
  }

  bool _looksLikeClipDisabledError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('disabled') ||
        lower.contains('forbidden') ||
        lower.contains('notfound') ||
        lower.contains('createclip') ||
        lower.contains('createrawmedia') ||
        lower.contains('raw media') ||
        lower.contains('rawmedia') ||
        lower.contains('clip finalize') ||
        lower.contains('沒有回傳 raw media') ||
        lower.contains('一直沒有完成處理');
  }

  Future<void> loadChannelAboutPanels() async {
    final login = channelLogin;
    if (login.trim().isEmpty) return;
    setState(() {
      loadingAboutPanels = true;
      aboutErrorText = null;
      aboutPanels = const <TwitchChannelPanel>[];
      aboutSocialLinks = const <TwitchChannelSocialLink>[];
    });

    try {
      final discoveryService =
          widget.initialDiscoveryService ??
          TwitchDiscoveryService(
            client: watchServices.apiClient,
            authService: authService,
            authApi: authApi,
          );
      final loaded = await discoveryService.fetchChannelAbout(login: login);
      if (!mounted || login != channelLogin) return;
      setState(() {
        aboutPanels = loaded.panels;
        aboutSocialLinks = loaded.socialLinks;
        loadingAboutPanels = false;
      });
    } catch (error) {
      if (!mounted || login != channelLogin) return;
      setState(() {
        aboutErrorText = error.toString();
        loadingAboutPanels = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TwitchPlaybackSessionController.instance.registerRouteOwner(
      playbackRouteOwner,
      onRestore: reconcileVisibleRoutePlayback,
    );
    reuseCurrentPlaybackOnNextLiveLoad = widget.initialReuseCurrentPlayback;

    channelController = TextEditingController(
      text: widget.resolvedInitialMetadata.channelLogin,
    );
    _initialKnownFollowStatus = widget.resolvedInitialFollowStatus;
    messageController = TextEditingController();
    session = TwitchWatchSessionHandles.create(
      playerTitle: 'Twitch Raw Proxy',
      playerRuntime: widget.initialPlayerRuntime,
    );
    vodSnapshotPlaylistProxy = TwitchVodSnapshotPlaylistProxy();
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
      onViewerResolved: (resolvedViewerLogin, resolvedViewerId) {
        viewerLogin = resolvedViewerLogin;
        viewerId = resolvedViewerId;
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
    final knownFollowStatus = _initialKnownFollowStatus;
    if (knownFollowStatus != null) {
      relationshipController.seedKnownFollowStatus(
        knownFollowStatus,
        resolvedUserId: widget.resolvedInitialOfflineChannel?.broadcasterId,
      );
    }
    playbackController = TwitchWatchPlaybackController(
      playerPort: watchPorts.player,
      applyPlayerVolume: applyPlayerVolume,
      waitForInitialPlaybackSettle: waitForInitialPlaybackSettle,
    )..addListener(notifyControllerChanged);
    vodReplayController = TwitchVodChatReplayRuntime(
      api: TwitchVodCommentsApiService(
        client: watchServices.apiClient,
        badgeCache: TwitchBadgeCacheService(),
      ),
    )..addListener(notifyControllerChanged);

    if (widget.initialReuseCurrentPlayback) {
      unawaited(primeReusedPlaybackSurface());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await syncWatchPageAutoPip();
      if (!mounted) return;
      await enterMobileImmersiveByDefault();
      if (!mounted) return;
      await loadWatchPreferences();
      if (!mounted) return;
      await loadAuth();
      if (mounted) {
        await loadWatch();
        unawaited(loadChannelAboutPanels());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(recoverWatchAfterForeground());
    }
  }

  Future<void> recoverWatchAfterForeground() async {
    if (!mounted) return;
    final channel = channelLogin;

    try {
      final currentUri = TwitchMediaKitPlayerHost.currentMediaUri?.trim();
      if (currentUri != null && currentUri.isNotEmpty) {
        await playerSession.ensureReady();
        if (!mounted) return;
        await preferencesController.applyPlayerVolume();
        final isLiveDvrReplay =
            currentPlaybackKind == TwitchWatchPlaybackKind.liveDvr;
        if (isLiveDvrReplay) {
          final recovered = await recoverLiveDvrPlaybackAfterForeground(
            channel: channel,
            generation: watchLoadGeneration,
          );
          if (recovered) return;
        }
        final player = playerSession.playerOrNull;
        if (player != null && !player.state.playing) {
          await player.play();
        }
      } else if (!loadingPlayer && !widget.initialVodPlaybackOnly) {
        await loadPlayer(channel, forceOpen: true);
      }
    } catch (error) {
      if (mounted) {
        debugPrint('foreground playback recovery failed: $error');
      }
    }

    if (!mounted) return;
    final runtime = chatController.runtime;
    if ((runtime == null || (!runtime.connected && !runtime.connecting)) &&
        !connectingChat) {
      unawaited(runDeferredChatStartup(channel, watchLoadGeneration));
    }

    if (!engagementBootstrapping && !loadingEngagement) {
      unawaited(
        refreshEngagement(showSnackOnError: false, notifyBalanceDelta: false),
      );
    }

    if (channelId != null && channelId!.trim().isNotEmpty) {
      unawaited(
        TwitchPredictionHermesGlobalRuntime.ensureConnected(
          channelId: channelId,
          viewerUserId: viewerId,
          previousPrediction: prediction,
        ),
      );
    }
  }

  Future<void> primeReusedPlaybackSurface() async {
    try {
      final moved = TwitchMiniPlayerController.instance.moveActiveSurfaceInto(
        playerSession,
      );
      if (!moved) {
        await playerSession.ensureReady();
      }
      final player = playerSession.playerOrNull;
      if (player != null && !player.state.playing) {
        await player.play();
      }
      if (!mounted) return;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        TwitchMiniPlayerController.instance.close(pausePlayback: false);
      });
    } catch (_) {
      // The regular watch startup path will still attempt a normal live load.
    }
  }

  @override
  void dispose() {
    watchLoadGeneration++;
    unawaited(
      TwitchPlaybackSessionController.instance.restoreAfterUnregisterRouteOwner(
        playbackRouteOwner,
      ),
    );
    WidgetsBinding.instance.removeObserver(this);
    if (!handedOffToMiniPlayer) {
      unawaited(TwitchAndroidPipController.instance.setAutoEnterEnabled(false));
    }
    cancelDeferredWatchTasks(rebuild: false);
    channelController.dispose();
    messageController.dispose();

    if (!handedOffToMiniPlayer) {
      unawaited(watchPorts.player.disposeRuntime());
    }
    playbackController.removeListener(notifyControllerChanged);
    vodReplayController.removeListener(notifyControllerChanged);
    relationshipController.removeListener(notifyControllerChanged);
    engagementController.removeListener(notifyControllerChanged);
    chatController.removeListener(notifyControllerChanged);
    preferencesController.removeListener(notifyControllerChanged);
    playbackController.dispose();
    vodReplayController.dispose();
    if (!handedOffToMiniPlayer) {
      unawaited(vodSnapshotPlaylistProxy.dispose());
    }
    relationshipController.dispose();
    engagementController.dispose();
    chatController.dispose();
    preferencesController.dispose();

    final volumeSubscriptionCancel = playerVolumeSubscription?.cancel();
    if (volumeSubscriptionCancel != null) {
      unawaited(volumeSubscriptionCancel);
    }

    final restorePlayback = restorePlaybackOnDispose;
    if (handedOffToMiniPlayer) {
      // The shared player is now owned by the in-app mini player.
    } else if (!isPushedMediaPlayback &&
        restorePlayback != null &&
        restorePlayback.mediaUri.trim().isNotEmpty) {
      TwitchPlaybackSessionController.instance.restorePlayback(restorePlayback);
      unawaited(
        TwitchMediaKitPlayerHost.restoreSharedMedia(
          uri: restorePlayback.mediaUri,
          play: true,
          forceOpen: true,
        ).catchError((_) {}),
      );
    } else {
      unawaited(playerSession.pauseCurrent().catchError((_) {}));
    }
    playerSession.release();

    if (fullscreenMode || mobileImmersiveEntered) {
      unawaited(TwitchFullscreenController.exitFullscreen());
    }

    if (!handedOffToMiniPlayer) {
      session.closeApiClient();
    }
    super.dispose();
  }

  Future<void> syncWatchPageAutoPip() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool(
          TwitchPlayerSettingsController.androidPipEnabledPreferenceKey,
        ) ??
        true;
    await TwitchAndroidPipController.instance.setAutoEnterEnabled(enabled);
  }

  Future<void> openCurrentChannelSheet(
    TwitchStreamHeaderMetadata metadata,
  ) async {
    final login = metadata.channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      showSnack('目前沒有可開啟的頻道資訊。');
      return;
    }

    final knownChannel = widget.resolvedInitialOfflineChannel;
    final knownChannelId = knownChannel?.broadcasterId.trim().isNotEmpty == true
        ? knownChannel!.broadcasterId.trim()
        : channelId?.trim() ?? '';
    final discoveryService = TwitchDiscoveryService(
      client: watchServices.apiClient,
      authService: authService,
      authApi: authApi,
    );
    if (knownChannelId.isNotEmpty) {
      final channel = TwitchFollowedChannel(
        broadcasterId: knownChannelId,
        broadcasterLogin:
            knownChannel?.broadcasterLogin.trim().isNotEmpty == true
            ? knownChannel!.broadcasterLogin
            : login,
        broadcasterName: knownChannel?.broadcasterName.trim().isNotEmpty == true
            ? knownChannel!.broadcasterName
            : login,
        followedAt: knownChannel?.followedAt,
        profileImageUrl: knownChannel?.profileImageUrl.trim().isNotEmpty == true
            ? knownChannel!.profileImageUrl
            : metadata.profileImageUrl,
        offlineImageUrl: knownChannel?.offlineImageUrl ?? '',
        description: knownChannel?.description ?? '',
      );

      await showTwitchChannelSheet(
        context: context,
        discoveryService: discoveryService,
        channel: channel,
      );
      return;
    }

    try {
      final userApi = TwitchUserApiService(
        helix: TwitchHelixApiService(
          client: watchServices.apiClient,
          accessTokenProvider: authService.getValidAccessToken,
        ),
        gql: watchServices.publicGqlApi,
      );
      final user = await userApi.getChannelProfileByLogin(login);
      if (!mounted) return;
      if (user == null || user.id.trim().isEmpty) {
        showSnack('頻道資訊讀取失敗，無法開啟關於 / VOD。');
        return;
      }

      final channel = TwitchFollowedChannel(
        broadcasterId: user.id,
        broadcasterLogin: user.login.isEmpty ? login : user.login,
        broadcasterName: user.displayName.isEmpty ? login : user.displayName,
        followedAt: null,
        profileImageUrl: user.profileImageUrl.isEmpty
            ? metadata.profileImageUrl
            : user.profileImageUrl,
        offlineImageUrl: user.offlineImageUrl,
        description: user.description,
      );

      await showTwitchChannelSheet(
        context: context,
        discoveryService: discoveryService,
        channel: channel,
      );
    } catch (error) {
      if (!mounted) return;
      showSnack('頻道資訊暫時讀取失敗，稍後再試。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = chatRuntime;
    final fallbackVideo = offlineVodFallbackVideo;
    final metadata = widget.resolvedInitialMetadata.copyWith(
      channelLogin: channelLogin,
      streamTitle: fallbackVideo == null
          ? widget.resolvedInitialMetadata.streamTitle
          : fallbackVideo.title,
      gameName: widget.resolvedInitialMetadata.gameName,
      clearViewerCount: fallbackVideo != null,
    );

    final playerArea = TwitchWatchPlayerAreaPortAdapter(
      metadata: metadata,
      loading: loadingPlayer,
      error: playerError,
      showOfflinePlaceholder: showOfflineChannelPlaceholder,
      offlineImageUrl: widget.resolvedInitialOfflineChannel?.offlineImageUrl,
      isFollowing: effectiveIsFollowing,
      relationshipBusy:
          checkingRelationship ||
          followBusy ||
          (relationshipBootstrapping && _initialKnownFollowStatus == null),
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
      qualityVariants: usesVodQualityControls ? vodQualityVariants : null,
      currentVariant: usesVodQualityControls ? currentVodQualityVariant : null,
      onQualitySelected: usesVodQualityControls
          ? (variant) => unawaited(switchVodQuality(variant))
          : null,
      onBack: () => unawaited(leaveToMiniPlayer()),
      onHome: () => unawaited(returnToHome()),
      onOpenChannel: () => unawaited(openCurrentChannelSheet(metadata)),
      onCreateClip: () => unawaited(createLiveClip()),
      creatingClip: creatingClip,
      hasDvrReplay: hasDvrReplayPlayback,
      showLiveEdgeLabel: showsLiveDvrEdgeLabel,
      playbackKind: currentPlaybackKind,
      liveDvrDuration:
          watchPorts.player.runtime.liveDvrBridgeDuration ??
          activeGrowingVodVideo?.parsedDuration,
      liveDvrStartedAt:
          activeGrowingVodVideo?.createdAt ??
          activeGrowingVodVideo?.publishedAt,
      onOpenDvrReplayAt: watchPorts.player.runtime.usingLiveDvrBridge
          ? (ratio) => unawaited(seekLiveDvrBridgePlayback(ratio))
          : activeGrowingVodVideo == null
          ? null
          : (ratio) => unawaited(openActiveDvrReplay(initialRatio: ratio)),
      onReturnToLive: () {
        unawaited(returnToLivePlayback());
      },
      onError: (message) {
        if (!mounted) return;
        playbackController.setError(message);
        showSnack('播放器操作失敗，請稍後再試。');
      },
    );
    final belowPlayer = TwitchChannelAboutSection(
      metadata: metadata,
      description: widget.resolvedInitialOfflineChannel?.description ?? '',
      panels: aboutPanels,
      socialLinks: aboutSocialLinks,
      loading: loadingAboutPanels,
      errorText: aboutErrorText,
      onRetry: () => unawaited(loadChannelAboutPanels()),
    );

    Widget buildLiveChatPanel({bool showHeader = true}) {
      return TwitchWatchChatPanelPortAdapter(
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
        showHeader: showHeader,
      );
    }

    final liveChatPanel = buildLiveChatPanel();
    final liveChatPanelWithoutHeader = buildLiveChatPanel(showHeader: false);
    final chatPanel = !shouldShowVodReplayChat
        ? liveChatPanel
        : TwitchVodReplayChatPanel(
            runtime: vodReplayController,
            liveChat: liveChatPanelWithoutHeader,
            thirdPartyEmoteCache: watchPorts.emotes.thirdParty,
            officialEmoteCache: watchPorts.emotes.official,
            preferredMode: preferVodReplayChat
                ? TwitchVodReplayChatMode.replay
                : TwitchVodReplayChatMode.live,
          );

    final scaffold = PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || leavingToMiniPlayer) return;
        unawaited(leaveToMiniPlayer());
      },
      child: Scaffold(
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
                belowPlayer: belowPlayer,
                onSetChatPanelWidthForViewport: setChatPanelWidthForViewport,
                onPersistChatPanelWidth: () {
                  unawaited(saveChatPanelWidthPreference());
                },
              ),
            ),
          ],
        ),
      ),
    );

    return TwitchWatchScope(
      services: watchServices,
      child: TwitchWatchPortScope(ports: watchPorts, child: scaffold),
    );
  }
}
