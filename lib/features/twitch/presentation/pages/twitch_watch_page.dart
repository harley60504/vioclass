library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/chat/twitch_recent_messages_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../models/discovery/twitch_stream_header_metadata.dart';
import '../../models/engagement/twitch_prediction.dart';
import '../../models/special_actions/twitch_pending_special_message.dart';
import '../../models/special_actions/twitch_viewer_special_message_models.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../../services/chat/twitch_chat_runtime.dart';
import '../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../services/playback/twitch_media_kit_player_host.dart';
import '../../services/watch/twitch_watch_services.dart';
import '../../services/window/twitch_fullscreen_controller.dart';
import '../dialogs/twitch_subscribe_webview_dialog_v1.dart';
import '../sheets/twitch_special_message_debug_probe_sheet.dart';
import '../sheets/twitch_special_message_sheet.dart';
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

part 'watch/twitch_watch_page_session.dart';
part 'watch/twitch_watch_page_methods.dart';
part 'watch/twitch_watch_page_preferences.dart';
part 'watch/twitch_watch_page_startup.dart';
part 'watch/twitch_watch_page_chat.dart';
part 'watch/twitch_watch_page_engagement.dart';
part 'watch/twitch_watch_page_relationship.dart';
part 'watch/twitch_watch_page_ui.dart';

const bool _enableWatchPlayer = bool.fromEnvironment(
  'TWITCH_ENABLE_WATCH_PLAYER',
  defaultValue: true,
);

const bool _enableChannelPointEmoteMenu = true;

const double _minChatPanelWidth = 180.0;
const double _maxEffectiveMinChatPanelWidth = 280.0;
const double _maxChatPanelWidth = 620.0;
const double _minChatPanelRatio = 0.22;
const double _minStoredChatPanelRatio = 0.08;
const double _maxChatPanelRatio = 0.48;

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
  State<TwitchWatchPage> createState() => _TwitchWatchPageState();
}

class _TwitchWatchPageState extends State<TwitchWatchPage> {
  late final TextEditingController _channelController;
  late final TextEditingController _messageController;
  late final _TwitchWatchSessionHandles _session;
  late final TwitchWatchPreferencesController _preferencesController;
  late final TwitchWatchChatController _chatController;
  late final TwitchWatchEngagementController _engagementController;
  late final TwitchWatchRelationshipController _relationshipController;
  late final TwitchWatchPlaybackController _playbackController;

  TwitchWatchServices get _watchServices => _session.services;
  TwitchWatchFeaturePorts get _watchPorts => _session.ports;
  TwitchAuthService get _authService => _session.authService;
  TwitchDropsAuthService get _dropsAuthService => _session.dropsAuthService;
  TwitchWebGqlAuthService get _webGqlAuthService => _session.webGqlAuthService;
  TwitchAuthApiService get _authApi => _session.authApi;
  TwitchRecentMessagesApiService get _recentMessagesApi =>
      _session.recentMessagesApi;
  TwitchMediaKitPlayerSession get _playerSession => _session.playerSession;

  StreamSubscription<double>? _playerVolumeSubscription;

  int _watchLoadGeneration = 0;

  bool _loadingAuth = true;
  bool _loadingWatch = false;
  bool _fullscreenMode = false;
  bool _mobileImmersiveEntered = false;
  bool _chatBootstrapping = false;
  bool _engagementBootstrapping = false;
  bool _emoteBootstrapping = false;
  bool _relationshipBootstrapping = false;

  String? _viewerLogin;
  String? _viewerId;
  String? _channelId;

  TwitchChatRuntime? get _chatRuntime => _chatController.runtime;
  bool get _loadingPlayer => _playbackController.loadingPlayer;
  bool get _connectingChat => _chatController.connectingChat;
  bool get _sending => _chatController.sending;
  bool get _loadingEmotes => _engagementController.loadingEmotes;
  bool get _loadingEngagement => _engagementController.loadingEngagement;
  bool get _isMuted => _preferencesController.muted;
  bool get _checkingRelationship =>
      _relationshipController.checkingRelationship;
  bool get _followBusy => _relationshipController.followBusy;
  bool get _isFollowing => _relationshipController.isFollowing;
  bool get _chatVisible => _preferencesController.chatVisible;
  bool get _loadingSpecialMessages => _chatController.loadingSpecialMessages;
  double get _chatPanelWidth => _preferencesController.chatPanelWidth;
  double get _chatPanelRatio => _preferencesController.chatPanelRatio;
  double get _volume => _preferencesController.volume;
  String? get _playerError => _playbackController.playerError;
  String? get _engagementError => _engagementController.engagementError;
  String? get _relationshipError => _relationshipController.relationshipError;
  TwitchChannelPointsRuntimeSnapshot? get _channelPointsSnapshot =>
      _engagementController.channelPointsSnapshot;
  TwitchViewerSpecialMessagesSnapshotStage251? get _specialMessagesSnapshot =>
      _chatController.specialMessagesSnapshot;
  TwitchPendingSpecialMessage? get _pendingSpecialMessage =>
      _chatController.pendingSpecialMessage;
  TwitchPredictionSnapshot? get _prediction => _engagementController.prediction;
  List<dynamic> get _pinnedMessages => _engagementController.pinnedMessages;

  TwitchWatchSheetPortLauncher get _sheetLauncher =>
      TwitchWatchSheetPortLauncher(
        emotes: _watchPorts.emotes,
        engagement: _watchPorts.engagement,
        showMessage: _showSnack,
        insertMessageText: _insertMessageText,
        setPendingSpecialMessage: _setPendingSpecialMessage,
        refreshEngagement: _refreshEngagement,
        refreshEmotes: _loadThirdPartyEmotes,
        channelLogin: () => _channelLogin,
        channelId: () => _channelId,
        channelPointsSnapshot: () => _channelPointsSnapshot,
        predictionSnapshot: () => _prediction,
        loadingEmotes: () => _loadingEmotes,
        emoteBootstrapping: () => _emoteBootstrapping,
        loadingEngagement: () => _loadingEngagement,
        engagementBootstrapping: () => _engagementBootstrapping,
        enableChannelPointEmoteMenu: _enableChannelPointEmoteMenu,
      );

  String get _channelLogin {
    final value = _channelController.text.trim().toLowerCase();
    return value.isEmpty ? 'roger9527' : value;
  }

  bool get _busy =>
      _loadingAuth ||
      _loadingWatch ||
      _loadingPlayer ||
      _connectingChat ||
      _chatBootstrapping;

  bool get _showBlockingStartupMask {
    return _loadingAuth ||
        _loadingWatch ||
        _chatBootstrapping ||
        _connectingChat ||
        (_enableWatchPlayer && _loadingPlayer);
  }

  String get _startupMaskTitle {
    if (_loadingAuth) return '正在準備 Twitch 工作階段...';
    if (_loadingWatch) return '正在準備觀看頁...';
    if (_enableWatchPlayer && _loadingPlayer) return '正在啟動播放器...';
    if (_chatBootstrapping || _connectingChat) return '正在連線聊天室...';
    return '正在載入...';
  }

  @override
  void initState() {
    super.initState();

    _channelController = TextEditingController(
      text: widget.resolvedInitialMetadata.channelLogin,
    );
    _messageController = TextEditingController();
    _session = _TwitchWatchSessionHandles.create(
      playerTitle: 'Twitch Raw Proxy',
    );
    _preferencesController = TwitchWatchPreferencesController(
      applyVolume: (volume) async {
        final player = _playerSession.playerOrNull;
        if (player != null) await player.setVolume(volume);
      },
      minChatPanelWidth: _minChatPanelWidth,
      maxEffectiveMinChatPanelWidth: _maxEffectiveMinChatPanelWidth,
      maxChatPanelWidth: _maxChatPanelWidth,
      minChatPanelRatio: _minChatPanelRatio,
      minStoredChatPanelRatio: _minStoredChatPanelRatio,
      maxChatPanelRatio: _maxChatPanelRatio,
    )..addListener(_notifyControllerChanged);
    _chatController = TwitchWatchChatController(
      authService: _authService,
      dropsAuthService: _dropsAuthService,
      authApi: _authApi,
      recentMessagesApi: _recentMessagesApi,
      chatPort: _watchPorts.chat,
      engagementPort: _watchPorts.engagement,
      specialMessagesRuntime: _watchServices.specialMessagesStage251.runtime,
      channelLogin: () => _channelLogin,
      channelId: () => _channelId,
      viewerId: () => _viewerId,
      channelPointsSnapshot: () => _channelPointsSnapshot,
      refreshEngagement: ({bool showSnackOnError = true}) =>
          _refreshEngagement(showSnackOnError: showSnackOnError),
      refreshSpecialMessages: ({bool autoSelectPending = true}) =>
          _refreshSpecialMessages(autoSelectPending: autoSelectPending),
      onChannelIdResolved: _setResolvedChannelId,
      onViewerResolved: (viewerLogin, viewerId) {
        _viewerLogin = viewerLogin;
        _viewerId = viewerId;
      },
      showMessage: _showSnack,
    )..addListener(_notifyControllerChanged);
    _engagementController = TwitchWatchEngagementController(
      emotesPort: _watchPorts.emotes,
      engagementPort: _watchPorts.engagement,
      channelLogin: () => _channelLogin,
      channelId: () => _channelId,
      viewerId: () => _viewerId,
      isCurrentWatchTask: _isCurrentWatchTask,
    )..addListener(_notifyControllerChanged);
    _relationshipController = TwitchWatchRelationshipController(
      relationshipPort: _watchPorts.relationship,
      channelLogin: () => _channelLogin,
      channelId: () => _channelId,
      viewerId: () => _viewerId,
      onChannelIdResolved: _setResolvedChannelId,
      showMessage: _showSnack,
    )..addListener(_notifyControllerChanged);
    _playbackController = TwitchWatchPlaybackController(
      playerPort: _watchPorts.player,
      applyPlayerVolume: _applyPlayerVolume,
      waitForInitialPlaybackSettle: _waitForInitialPlaybackSettle,
    )..addListener(_notifyControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _enterMobileImmersiveByDefault();
      if (!mounted) return;
      await _loadWatchPreferences();
      if (!mounted) return;
      await _loadAuth();
      if (mounted) await _loadWatch();
    });
  }

  @override
  void dispose() {
    _cancelDeferredWatchTasks();
    _channelController.dispose();
    _messageController.dispose();

    unawaited(_watchPorts.player.disposeRuntime());
    _playbackController.removeListener(_notifyControllerChanged);
    _relationshipController.removeListener(_notifyControllerChanged);
    _engagementController.removeListener(_notifyControllerChanged);
    _chatController.removeListener(_notifyControllerChanged);
    _preferencesController.removeListener(_notifyControllerChanged);
    _playbackController.dispose();
    _relationshipController.dispose();
    _engagementController.dispose();
    _chatController.dispose();
    _preferencesController.dispose();

    final volumeSubscriptionCancel = _playerVolumeSubscription?.cancel();
    if (volumeSubscriptionCancel != null) {
      unawaited(volumeSubscriptionCancel);
    }

    unawaited(_playerSession.pauseCurrent().catchError((_) {}));
    _playerSession.release();

    if (_fullscreenMode || _mobileImmersiveEntered) {
      unawaited(TwitchFullscreenController.exitFullscreen());
    }

    _session.closeApiClient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _chatRuntime;
    final metadata = widget.resolvedInitialMetadata.copyWith(
      channelLogin: _channelLogin,
    );

    final playerArea = TwitchWatchPlayerAreaPortAdapter(
      metadata: metadata,
      loading: _loadingPlayer,
      error: _playerError,
      isFollowing: _isFollowing,
      relationshipBusy:
          _checkingRelationship || _followBusy || _relationshipBootstrapping,
      relationshipError: _relationshipError,
      onToggleFollow: _toggleFollowChannel,
      onSubscribe: _openSubscribePage,
      chatVisible: _fullscreenMode ? false : _chatVisible,
      fullscreenMode: _fullscreenMode,
      showFullscreenButton: TwitchFullscreenController.isDesktopPlatform,
      onToggleChat: _fullscreenMode ? null : _toggleChatVisibility,
      onToggleFullscreen: () => unawaited(_toggleFullscreenMode()),
      muted: _isMuted,
      volume: _volume,
      onToggleMute: () => unawaited(_togglePlayerMute()),
      onVolumeChanged: (value) => unawaited(_setPlayerVolume(value)),
      onBack: () => Navigator.of(context).maybePop(),
      onReload: _busy ? null : _loadWatch,
      onStop: () => _stopCurrentSession(),
      onError: (message) {
        if (!mounted) return;
        _playbackController.setError(message);
        _showSnack('播放器操作失敗：$message');
      },
    );

    final chatPanel = TwitchWatchChatPanelPortAdapter(
      runtime: runtime,
      viewerLogin: _viewerLogin,
      viewerId: _viewerId,
      metadata: metadata,
      channelPoints: _channelPointsSnapshot,
      pendingSpecialMessage: _pendingSpecialMessage,
      pinnedMessages: _pinnedMessages,
      prediction: _prediction,
      loadingEmotes: _loadingEmotes || _emoteBootstrapping,
      loadingEngagement: _loadingEngagement || _engagementBootstrapping,
      engagementError: _engagementError,
      messageController: _messageController,
      sending: _sending,
      onSend: _sendMessage,
      onOpenEmotes: _openEmotePicker,
      onRefreshEmotes: () => _loadThirdPartyEmotes(forceRefresh: true),
      onRefreshEngagement: () => _refreshEngagement(showSnackOnError: true),
      onOpenChannelPoints: _openChannelPointsSheet,
      onOpenPrediction: _openPredictionBetSheet,
      onOpenSpecialActions: _openSpecialMessagesSheet,
      onCancelPendingSpecialMessage: _clearPendingSpecialMessage,
    );

    final scaffold = Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: Stack(
        children: [
          Positioned.fill(
            child: TwitchWatchResponsiveBody(
              chatVisible: _fullscreenMode ? false : _chatVisible,
              fullscreenMode: _fullscreenMode,
              chatPanelWidth: _chatPanelWidth,
              chatPanelRatio: _chatPanelRatio,
              minChatPanelWidth: _minChatPanelWidth,
              maxEffectiveMinChatPanelWidth: _maxEffectiveMinChatPanelWidth,
              maxChatPanelWidth: _maxChatPanelWidth,
              minChatPanelRatio: _minChatPanelRatio,
              minStoredChatPanelRatio: _minStoredChatPanelRatio,
              maxChatPanelRatio: _maxChatPanelRatio,
              player: playerArea,
              chat: chatPanel,
              onSetChatPanelWidthForViewport: _setChatPanelWidthForViewport,
              onPersistChatPanelWidth: () {
                unawaited(_saveChatPanelWidthPreference());
              },
            ),
          ),
          if (_showBlockingStartupMask)
            Positioned.fill(
              child: TwitchWatchBlockingStartupOverlay(
                title: _startupMaskTitle,
                subtitle: _enableWatchPlayer
                    ? '先啟動播放器，再連線聊天室；互動資料與貼圖會在背景補上。'
                    : '正在連線聊天室；互動資料與貼圖會在背景補上。',
              ),
            ),
        ],
      ),
    );

    return TwitchWatchScope(
      services: _watchServices,
      child: TwitchWatchPortScope(ports: _watchPorts, child: scaffold),
    );
  }
}
