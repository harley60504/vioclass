// PATCH VERSION: twitch_watch_page_stage220k_split_shell_constants_library_scope
// Place at: lib/features/twitch/presentation/pages/twitch_watch_page.dart
// Canonical WatchPage implementation. Keep Windows compatibility in
// twitch_windows_player_page.dart as an export only.
//
// Stage 220J:
// - Split large WatchPage lifecycle/helper methods into a part file.
// - Keep this file focused on fields, initialization, disposal, and build.
// - Compatible with the PiliPlus media_kit fork: no direct stream.volume /
//   stream.width usage remains in this shell.
//
// Stage 220K:
// - Move preference/layout constants to library scope so the methods part can
//   reference them without unqualified static-member analyzer errors.

library twitch_watch_page;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/chat/twitch_irc_api_service.dart';
import '../../api/chat/twitch_recent_messages_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../models/discovery/twitch_stream_header_metadata.dart';
import '../../models/engagement/twitch_prediction.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../../services/chat/twitch_badge_cache_service.dart';
import '../../services/chat/twitch_chat_runtime.dart';
import '../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../services/playback/twitch_media_kit_player_host.dart';
import '../../services/watch/twitch_watch_services.dart';
import '../../services/window/twitch_fullscreen_controller.dart';
import '../dialogs/twitch_subscribe_webview_dialog_v1.dart';
import '../watch/adapters/twitch_watch_player_area_port_adapter.dart';
import '../watch/sheets/twitch_watch_sheet_port_launcher.dart';
import '../watch/twitch_watch_feature_ports.dart';
import '../watch/twitch_watch_port_scope.dart';
import '../watch/twitch_watch_scope.dart';
import '../widgets/watch/twitch_watch_blocking_startup_overlay.dart';
import '../widgets/watch/twitch_watch_responsive_body.dart';

part 'watch/twitch_watch_page_methods.dart';

const bool _enableWatchPlayer = bool.fromEnvironment(
  'TWITCH_ENABLE_WATCH_PLAYER',
  defaultValue: true,
);

const bool _enableChannelPointEmoteMenu = true;

const String _chatPanelWidthPreferenceKey = 'twitch_watch_v2_chat_panel_width';
const String _chatPanelRatioPreferenceKey = 'twitch_watch_v3_chat_panel_ratio';
const String _playerVolumePreferenceKey = 'twitch_watch_v2_player_volume';
const String _playerMutedPreferenceKey = 'twitch_watch_v2_player_muted';
const String _chatVisiblePreferenceKey = 'twitch_watch_v2_chat_visible';

const String _legacyChatPanelWidthPreferenceKey = 'twitch_watch_chat_panel_width';
const String _legacyPlayerVolumePreferenceKey = 'twitch_watch_player_volume';
const String _legacyPlayerMutedPreferenceKey = 'twitch_watch_player_muted';

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
    final hasLegacyMetadata = initialChannelLogin != null ||
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
      profileImageUrl: legacyProfileImage != null && legacyProfileImage.isNotEmpty
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

  late final TwitchWatchServices _watchServices;
  late final TwitchWatchFeaturePorts _watchPorts;

  late final TwitchApiClient _apiClient;
  late final TwitchAuthService _authService;
  late final TwitchDropsAuthService _dropsAuthService;
  late final TwitchWebGqlAuthService _webGqlAuthService;
  late final TwitchAuthApiService _authApi;
  late final TwitchRecentMessagesApiService _recentMessagesApi;
  late final TwitchMediaKitPlayerSession _playerSession;

  Player get _player => _playerSession.player;

  StreamSubscription<double>? _playerVolumeSubscription;
  Timer? _volumePreferenceSaveDebounce;
  Timer? _chatWidthPreferenceSaveDebounce;

  int _watchLoadGeneration = 0;

  TwitchChatRuntime? _chatRuntime;

  bool _loadingAuth = true;
  bool _loadingWatch = false;
  bool _loadingPlayer = false;
  bool _connectingChat = false;
  bool _sending = false;
  bool _loadingEmotes = false;
  bool _loadingEngagement = false;
  bool _isMuted = false;
  bool _checkingRelationship = false;
  bool _followBusy = false;
  bool _isFollowing = false;
  bool _chatVisible = true;
  bool _fullscreenMode = false;
  bool _mobileImmersiveEntered = false;
  bool _chatBootstrapping = false;
  bool _engagementBootstrapping = false;
  bool _emoteBootstrapping = false;
  bool _relationshipBootstrapping = false;

  double _chatPanelWidth = 430;
  double _chatPanelRatio = 0.34;
  double _volume = 100.0;
  double _lastNonZeroVolume = 100.0;

  String? _viewerLogin;
  String? _viewerId;
  String? _channelId;
  List<String> _viewerScopes = const <String>[];
  String? _playerError;
  String? _engagementError;
  String? _relationshipError;

  TwitchChannelPointsRuntimeSnapshot? _channelPointsSnapshot;
  TwitchPredictionSnapshot? _prediction;
  List<dynamic> _pinnedMessages = const <dynamic>[];

  TwitchWatchSheetPortLauncher get _sheetLauncher => TwitchWatchSheetPortLauncher(
        emotes: _watchPorts.emotes,
        engagement: _watchPorts.engagement,
        showMessage: _showSnack,
        insertMessageText: _insertMessageText,
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
      _chatBootstrapping ||
      _engagementBootstrapping ||
      _emoteBootstrapping ||
      _relationshipBootstrapping;

  bool get _showBlockingStartupMask {
    return _loadingAuth ||
        _loadingWatch ||
        _relationshipBootstrapping ||
        _engagementBootstrapping ||
        _emoteBootstrapping ||
        _chatBootstrapping ||
        _connectingChat ||
        (_enableWatchPlayer && _loadingPlayer);
  }

  String get _startupMaskTitle {
    if (_loadingAuth) return '正在準備 Twitch 工作階段...';
    if (_loadingWatch) return '正在準備觀看頁...';
    if (_relationshipBootstrapping) return '正在準備頻道資料...';
    if (_engagementBootstrapping) return '正在預載互動資料...';
    if (_emoteBootstrapping) return '正在預載聊天室貼圖...';
    if (_chatBootstrapping || _connectingChat) return '正在連線聊天室...';
    if (_enableWatchPlayer && _loadingPlayer) return '正在啟動播放器...';
    return '正在載入...';
  }

  @override
  void initState() {
    super.initState();

    _channelController = TextEditingController(
      text: widget.resolvedInitialMetadata.channelLogin,
    );
    _messageController = TextEditingController();

    _watchServices = TwitchWatchServices.create(playerTitle: 'Twitch Raw Proxy');
    _watchPorts = TwitchWatchFeaturePorts.fromServices(_watchServices);

    _apiClient = _watchServices.apiClient;
    _authService = _watchServices.authService;
    _dropsAuthService = _watchServices.dropsAuthService;
    _webGqlAuthService = _watchServices.webGqlAuthService;
    _authApi = _watchServices.authApi;
    _recentMessagesApi = _watchServices.recentMessagesApi;
    _playerSession = _watchServices.playerSession;

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

    final chatRuntime = _chatRuntime;
    _chatRuntime = null;
    if (chatRuntime != null) {
      unawaited(chatRuntime.disposeRuntime());
    }

    unawaited(_watchPorts.player.disposeRuntime());
    _volumePreferenceSaveDebounce?.cancel();
    _chatWidthPreferenceSaveDebounce?.cancel();
    unawaited(_saveVolumePreference());
    unawaited(_saveChatPanelWidthPreference());

    final volumeSubscriptionCancel = _playerVolumeSubscription?.cancel();
    if (volumeSubscriptionCancel != null) {
      unawaited(volumeSubscriptionCancel);
    }

    unawaited(_playerSession.pauseCurrent().catchError((_) {}));
    _playerSession.release();

    if (_fullscreenMode || _mobileImmersiveEntered) {
      unawaited(TwitchFullscreenController.exitFullscreen());
    }

    _apiClient.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _chatRuntime;
    final metadata = widget.resolvedInitialMetadata.copyWith(channelLogin: _channelLogin);

    final playerArea = TwitchWatchPlayerAreaPortAdapter(
      metadata: metadata,
      loading: _loadingPlayer,
      error: _playerError,
      isFollowing: _isFollowing,
      relationshipBusy: _checkingRelationship || _followBusy || _relationshipBootstrapping,
      relationshipError: _relationshipError,
      onToggleFollow: _toggleFollowChannel,
      onSubscribe: _openSubscribePage,
      chatVisible: _chatVisible,
      fullscreenMode: _fullscreenMode,
      showFullscreenButton: TwitchFullscreenController.isDesktopPlatform,
      onToggleChat: _toggleChatVisibility,
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
        setState(() => _playerError = message);
        _showSnack('播放器操作失敗：$message');
      },
    );

    final chatPanel = TwitchWatchChatPanelPortAdapter(
      runtime: runtime,
      viewerLogin: _viewerLogin,
      viewerId: _viewerId,
      metadata: metadata,
      channelPoints: _channelPointsSnapshot,
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
    );

    final scaffold = Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: Stack(
        children: [
          Positioned.fill(
            child: TwitchWatchResponsiveBody(
              chatVisible: _chatVisible,
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
                _chatWidthPreferenceSaveDebounce?.cancel();
                unawaited(_saveChatPanelWidthPreference());
              },
            ),
          ),
          if (_showBlockingStartupMask)
            Positioned.fill(
              child: TwitchWatchBlockingStartupOverlay(
                title: _startupMaskTitle,
                subtitle: _enableWatchPlayer
                    ? '先預載頻道與互動資料，再啟動聊天室，最後載入播放器。'
                    : '先預載頻道與互動資料，再啟動聊天室；播放器目前已停用。',
              ),
            ),
        ],
      ),
    );

    return TwitchWatchScope(
      services: _watchServices,
      child: TwitchWatchPortScope(
        ports: _watchPorts,
        child: scaffold,
      ),
    );
  }
}
