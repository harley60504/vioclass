// PATCH VERSION: twitch_watch_page_stage188_part_split
// Canonical WatchPage implementation. Keep Windows compatibility in
// twitch_windows_player_page.dart as an export only.

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
import '../widgets/responsive/twitch_responsive_layout.dart';

part 'watch_page_parts/twitch_watch_page_chat_part.dart';
part 'watch_page_parts/twitch_watch_page_engagement_part.dart';
part 'watch_page_parts/twitch_watch_page_layout_part.dart';
part 'watch_page_parts/twitch_watch_page_loading_part.dart';
part 'watch_page_parts/twitch_watch_page_player_part.dart';
part 'watch_page_parts/twitch_watch_page_preferences_part.dart';
part 'watch_page_parts/twitch_watch_page_private_widgets_part.dart';

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
  static const bool _enableChannelPointEmoteMenu = true;

  static const String _chatPanelWidthPreferenceKey =
      'twitch_watch_v2_chat_panel_width';
  static const String _chatPanelRatioPreferenceKey =
      'twitch_watch_v3_chat_panel_ratio';
  static const String _playerVolumePreferenceKey =
      'twitch_watch_v2_player_volume';
  static const String _playerMutedPreferenceKey =
      'twitch_watch_v2_player_muted';
  static const String _chatVisiblePreferenceKey =
      'twitch_watch_v2_chat_visible';

  static const String _legacyChatPanelWidthPreferenceKey =
      'twitch_watch_chat_panel_width';
  static const String _legacyPlayerVolumePreferenceKey =
      'twitch_watch_player_volume';
  static const String _legacyPlayerMutedPreferenceKey =
      'twitch_watch_player_muted';

  static const double _minChatPanelWidth = 180.0;
  static const double _maxEffectiveMinChatPanelWidth = 280.0;
  static const double _maxChatPanelWidth = 620.0;
  static const double _minChatPanelRatio = 0.22;
  static const double _minStoredChatPanelRatio = 0.08;
  static const double _maxChatPanelRatio = 0.48;

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

  bool get _busy => _loadingAuth || _loadingWatch || _loadingPlayer || _connectingChat;

  bool get _showBlockingStartupMask {
    return _loadingAuth ||
        _loadingWatch ||
        _loadingPlayer ||
        _chatBootstrapping ||
        _connectingChat;
  }

  String get _startupMaskTitle {
    if (_loadingAuth) return '正在準備 Twitch 工作階段...';
    if (_loadingPlayer || _loadingWatch) return '正在載入直播...';
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
    return TwitchWatchScope(
      services: _watchServices,
      child: TwitchWatchPortScope(
        ports: _watchPorts,
        child: _buildWatchBody(context),
      ),
    );
  }
}
