// PATCH VERSION: twitch_watch_page_stage187f_internal_cleanup
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

  Future<void> _loadWatchPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedChatPanelWidth =
          (prefs.getDouble(_chatPanelWidthPreferenceKey) ??
                  prefs.getDouble(_legacyChatPanelWidthPreferenceKey) ??
                  _chatPanelWidth)
              .clamp(_minChatPanelWidth, _maxChatPanelWidth)
              .toDouble();
      final savedChatPanelRatio =
          (prefs.getDouble(_chatPanelRatioPreferenceKey) ?? _chatPanelRatio)
              .clamp(_minStoredChatPanelRatio, _maxChatPanelRatio)
              .toDouble();
      final savedVolume =
          (prefs.getDouble(_playerVolumePreferenceKey) ??
                  prefs.getDouble(_legacyPlayerVolumePreferenceKey) ??
                  _volume)
              .clamp(0.0, 100.0)
              .toDouble();
      final savedMuted = prefs.getBool(_playerMutedPreferenceKey) ??
          prefs.getBool(_legacyPlayerMutedPreferenceKey) ??
          false;
      final savedChatVisible = prefs.getBool(_chatVisiblePreferenceKey) ?? _chatVisible;

      if (!mounted) return;
      setState(() {
        _chatPanelWidth = savedChatPanelWidth;
        _chatPanelRatio = savedChatPanelRatio;
        _volume = savedVolume;
        _lastNonZeroVolume = savedVolume > 0 ? savedVolume : 100.0;
        _isMuted = savedMuted;
        _chatVisible = savedChatVisible;
      });

      unawaited(_saveChatPanelWidthPreference());
      unawaited(_saveVolumePreference());
    } catch (error) {
      debugPrint('load watch preferences failed: $error');
    }

    await _applyPlayerVolume();
    _bindPlayerVolumeStream();
  }

  void _bindPlayerVolumeStream() {
    final previousCancel = _playerVolumeSubscription?.cancel();
    if (previousCancel != null) {
      unawaited(previousCancel);
    }
    _playerVolumeSubscription = _player.stream.volume.listen(_handlePlayerVolumeChanged);
  }

  void _handlePlayerVolumeChanged(double value) {
    final safeValue = value.clamp(0.0, 100.0).toDouble();

    void apply() {
      if (safeValue > 0) {
        _volume = safeValue;
        _lastNonZeroVolume = safeValue;
        _isMuted = false;
      } else {
        _isMuted = true;
      }
    }

    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
    _scheduleVolumePreferenceSave();
  }

  Future<void> _setPlayerVolume(double value) async {
    final nextVolume = value.clamp(0.0, 100.0).toDouble();
    setState(() {
      _volume = nextVolume;
      _isMuted = nextVolume <= 0.0;
      if (nextVolume > 0.0) _lastNonZeroVolume = nextVolume;
    });
    await _player.setVolume(_isMuted ? 0.0 : nextVolume);
    _scheduleVolumePreferenceSave();
  }

  Future<void> _togglePlayerMute() async {
    final nextMuted = !_isMuted;
    final nextVolume = nextMuted
        ? 0.0
        : (_volume > 0.0 ? _volume : _lastNonZeroVolume)
            .clamp(1.0, 100.0)
            .toDouble();
    setState(() {
      _isMuted = nextMuted;
      if (!nextMuted) {
        _volume = nextVolume;
        _lastNonZeroVolume = nextVolume;
      }
    });
    await _player.setVolume(nextMuted ? 0.0 : nextVolume);
    _scheduleVolumePreferenceSave();
  }

  Future<void> _applyPlayerVolume() async {
    if (!_isMuted && _volume <= 0) {
      _volume = _lastNonZeroVolume.clamp(1.0, 100.0).toDouble();
    }
    await _player.setVolume(_isMuted ? 0.0 : _volume.clamp(0.0, 100.0).toDouble());
  }

  void _scheduleVolumePreferenceSave() {
    _volumePreferenceSaveDebounce?.cancel();
    _volumePreferenceSaveDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_saveVolumePreference());
    });
  }

  Future<void> _saveVolumePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
        _playerVolumePreferenceKey,
        _volume.clamp(0.0, 100.0).toDouble(),
      );
      await prefs.setBool(_playerMutedPreferenceKey, _isMuted);
    } catch (error) {
      debugPrint('save watch volume preference failed: $error');
    }
  }

  Future<void> _saveChatVisiblePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chatVisiblePreferenceKey, _chatVisible);
    } catch (error) {
      debugPrint('save watch chat visibility preference failed: $error');
    }
  }

  Future<void> _saveChatPanelWidthPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
        _chatPanelWidthPreferenceKey,
        _chatPanelWidth.clamp(_minChatPanelWidth, _maxChatPanelWidth).toDouble(),
      );
      await prefs.setDouble(
        _chatPanelRatioPreferenceKey,
        _chatPanelRatio.clamp(_minStoredChatPanelRatio, _maxChatPanelRatio).toDouble(),
      );
    } catch (error) {
      debugPrint('save watch chat width preference failed: $error');
    }
  }

  double _effectiveChatPanelWidthForViewport(TwitchResponsiveLayout layout) {
    final ratioWidth = layout.width * _chatPanelRatio;
    final minByViewport = layout.width * _minChatPanelRatio;
    final minWidth = minByViewport
        .clamp(_minChatPanelWidth, _maxEffectiveMinChatPanelWidth)
        .toDouble();
    final maxWidth = _maxChatPanelWidth
        .clamp(minWidth, layout.width - 120.0)
        .toDouble();
    return ratioWidth.clamp(minWidth, maxWidth).toDouble();
  }

  void _setChatPanelWidthForViewport({
    required double viewportWidth,
    required double value,
  }) {
    if (viewportWidth <= 0) return;
    final ratioLimitedMin = viewportWidth * _minChatPanelRatio;
    final effectiveMinWidth = ratioLimitedMin
        .clamp(_minChatPanelWidth, _maxEffectiveMinChatPanelWidth)
        .toDouble();
    final effectiveMaxWidth = _maxChatPanelWidth
        .clamp(effectiveMinWidth, viewportWidth - 120.0)
        .toDouble();
    final nextWidth = value.clamp(effectiveMinWidth, effectiveMaxWidth).toDouble();
    final effectiveMinRatio = (effectiveMinWidth / viewportWidth)
        .clamp(_minStoredChatPanelRatio, _maxChatPanelRatio)
        .toDouble();
    final nextRatio = (nextWidth / viewportWidth)
        .clamp(effectiveMinRatio, _maxChatPanelRatio)
        .toDouble();

    if ((_chatPanelWidth - nextWidth).abs() < 0.5 &&
        (_chatPanelRatio - nextRatio).abs() < 0.002) {
      return;
    }

    setState(() {
      _chatPanelWidth = nextWidth;
      _chatPanelRatio = nextRatio;
    });
  }

  Future<void> _loadAuth() async {
    setState(() => _loadingAuth = true);
    try {
      await _authService.loadStoredSession();
      await _webGqlAuthService.loadStoredSession();
      await _dropsAuthService.loadStoredSession();

      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => _loadingAuth = false);
        return;
      }

      final validation = await _authApi.validateToken(token);
      if (!mounted) return;
      setState(() {
        _viewerLogin = validation.login;
        _viewerId = validation.userId;
        _viewerScopes = validation.scopes;
        _loadingAuth = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingAuth = false);
      _showSnack('OAuth 載入失敗：$error');
    }
  }

  Future<void> _loadWatch() async {
    if (_loadingWatch) return;
    final channel = _channelLogin;
    _cancelDeferredWatchTasks();
    final generation = ++_watchLoadGeneration;

    setState(() {
      _loadingWatch = true;
      _playerError = null;
      _engagementError = null;
      _relationshipError = null;
      _chatBootstrapping = false;
      _engagementBootstrapping = false;
      _emoteBootstrapping = false;
      _relationshipBootstrapping = false;
    });

    try {
      await _stopCurrentSession(
        clearStatus: false,
        cancelDeferredTasks: false,
      );
      if (!_isCurrentWatchTask(generation, channel)) return;

      await _loadPlayer(channel);
      if (!_isCurrentWatchTask(generation, channel)) return;

      setState(() => _loadingWatch = false);
      unawaited(_runWatchStartupPipeline(
        channel: channel,
        generation: generation,
      ));
    } catch (error) {
      if (mounted) _showSnack('載入 Watch Page 失敗：$error');
    } finally {
      if (mounted && generation == _watchLoadGeneration && _loadingWatch) {
        setState(() => _loadingWatch = false);
      }
    }
  }

  Future<void> _loadPlayer(String channel) async {
    setState(() {
      _loadingPlayer = true;
      _playerError = null;
    });

    try {
      await _applyPlayerVolume();
      await _watchPorts.player.openLive(channelLogin: channel);
      await _applyPlayerVolume();
      await _waitForInitialPlaybackSettle();
    } catch (error) {
      _playerError = error.toString();
      rethrow;
    } finally {
      if (mounted) setState(() => _loadingPlayer = false);
    }
  }

  Future<void> _waitForInitialPlaybackSettle() async {
    if (_player.state.width != null && _player.state.width! > 0) return;

    final completer = Completer<void>();
    StreamSubscription<int?>? widthSubscription;
    StreamSubscription<bool>? playingSubscription;
    Timer? timeout;

    void complete() {
      if (completer.isCompleted) return;
      completer.complete();
      final widthCancel = widthSubscription?.cancel();
      if (widthCancel != null) unawaited(widthCancel);
      final playingCancel = playingSubscription?.cancel();
      if (playingCancel != null) unawaited(playingCancel);
      timeout?.cancel();
    }

    widthSubscription = _player.stream.width.listen((width) {
      if ((width ?? 0) > 0) complete();
    });
    playingSubscription = _player.stream.playing.listen((playing) {
      if (playing) Timer(const Duration(milliseconds: 180), complete);
    });
    timeout = Timer(const Duration(milliseconds: 850), complete);
    return completer.future;
  }

  Future<void> _runWatchStartupPipeline({
    required String channel,
    required int generation,
  }) async {
    await _yieldToUi();
    if (!_isCurrentWatchTask(generation, channel)) return;

    setState(() => _chatBootstrapping = true);
    await _runDeferredChatStartup(channel, generation);
    await _yieldToUi();
    if (!_isCurrentWatchTask(generation, channel)) return;

    setState(() => _engagementBootstrapping = true);
    await _runDeferredEngagementStartup(generation, channel);
    await _yieldToUi();
    if (!_isCurrentWatchTask(generation, channel)) return;

    setState(() => _emoteBootstrapping = true);
    await _runDeferredEmoteStartup(generation, channel);
    await _yieldToUi();
    if (!_isCurrentWatchTask(generation, channel)) return;

    setState(() => _relationshipBootstrapping = true);
    await _runDeferredRelationshipStartup(generation, channel);
  }

  Future<void> _yieldToUi() async {
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _runDeferredChatStartup(
    String channel,
    int generation,
  ) async {
    try {
      await _connectChat(channel);
    } catch (error) {
      if (_isCurrentWatchTask(generation, channel)) {
        _showSnack('聊天室連線失敗：$error');
      }
    } finally {
      if (_isCurrentWatchTask(generation, channel)) {
        setState(() => _chatBootstrapping = false);
      }
    }
  }

  Future<void> _runDeferredEngagementStartup(
    int generation,
    String channel,
  ) async {
    try {
      await _refreshEngagement(showSnackOnError: false);
    } finally {
      if (_isCurrentWatchTask(generation, channel)) {
        setState(() => _engagementBootstrapping = false);
      }
    }
  }

  Future<void> _runDeferredEmoteStartup(
    int generation,
    String channel,
  ) async {
    try {
      await _loadThirdPartyEmotes();
    } finally {
      if (_isCurrentWatchTask(generation, channel)) {
        setState(() => _emoteBootstrapping = false);
      }
    }
  }

  Future<void> _runDeferredRelationshipStartup(
    int generation,
    String channel,
  ) async {
    try {
      await _refreshRelationshipStatus(channelLogin: channel);
    } finally {
      if (_isCurrentWatchTask(generation, channel)) {
        setState(() => _relationshipBootstrapping = false);
      }
    }
  }

  bool _isCurrentWatchTask(int generation, String channel) {
    return mounted &&
        generation == _watchLoadGeneration &&
        channel.trim().toLowerCase() == _channelLogin;
  }

  void _cancelDeferredWatchTasks() {
    if (!mounted) return;
    setState(() {
      _chatBootstrapping = false;
      _engagementBootstrapping = false;
      _emoteBootstrapping = false;
      _relationshipBootstrapping = false;
    });
  }

  Future<void> _connectChat(String channel) async {
    setState(() => _connectingChat = true);
    try {
      await _chatRuntime?.disposeRuntime();

      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw StateError('沒有可用 OAuth，不能連線可發言聊天室。');
      }

      await _dropsAuthService.loadStoredSession();
      final validation = await _authApi.validateToken(token);
      final startup = await _watchPorts.chat.fetchStartupSnapshot(
        channelLogin: channel,
      );
      final runtime = TwitchChatRuntime(
        ircApi: TwitchIrcApiService(),
        writeIrcApi: TwitchIrcApiService(),
        badgeCache: TwitchBadgeCacheService(),
        recentMessagesApi: _recentMessagesApi,
      );

      if (!mounted) return;
      setState(() {
        _chatRuntime = runtime;
        _viewerLogin = validation.login;
        _viewerId = validation.userId;
        _viewerScopes = validation.scopes;
        _channelId = startup.channelId;
      });

      await runtime.connect(
        channelLogin: channel,
        accessToken: token,
        ircNick: validation.login,
        viewerLogin: validation.login,
        viewerDisplayName: validation.login,
        viewerUserId: validation.userId,
        badgeCatalog: startup.badgeCatalog,
        preloadRecentMessages: true,
        recentMessageLimit: 100,
      );
    } finally {
      if (mounted) setState(() => _connectingChat = false);
    }
  }

  Future<void> _stopCurrentSession({
    bool clearStatus = true,
    bool cancelDeferredTasks = true,
  }) async {
    if (cancelDeferredTasks) {
      _watchLoadGeneration++;
      _cancelDeferredWatchTasks();
    }

    await _chatRuntime?.disconnect();
    _watchPorts.emotes.clear();

    if (!mounted) return;
    setState(() {
      _channelId = null;
      _channelPointsSnapshot = null;
      _prediction = null;
      _pinnedMessages = const <dynamic>[];
      _engagementError = null;
      _playerError = null;
      _relationshipError = null;
      _isFollowing = false;
      _chatBootstrapping = false;
      _engagementBootstrapping = false;
      _emoteBootstrapping = false;
      _relationshipBootstrapping = false;
    });
  }

  Future<void> _loadThirdPartyEmotes({bool forceRefresh = false}) async {
    final channelId = _channelId;
    if (channelId == null || channelId.isEmpty) return;

    setState(() => _loadingEmotes = true);
    try {
      await _watchPorts.emotes.loadForChannel(
        channelId: channelId,
        channelLogin: _channelLogin,
        viewerId: _viewerId ?? '',
        forceRefresh: forceRefresh,
      );
    } finally {
      if (mounted) setState(() => _loadingEmotes = false);
    }
  }

  Future<void> _refreshEngagement({bool showSnackOnError = true}) async {
    final channelLogin = _channelLogin;
    final channelId = _channelId;
    if (!mounted) return;

    setState(() {
      _loadingEngagement = true;
      _engagementError = null;
    });

    final snapshot = await _watchPorts.engagement.refresh(
      channelLogin: channelLogin,
      channelId: channelId,
    );

    if (!mounted || channelLogin != _channelLogin) return;
    final lastError = snapshot.error;
    setState(() {
      if (snapshot.channelPoints != null) {
        _channelPointsSnapshot = snapshot.channelPoints;
      }
      if (snapshot.prediction != null) _prediction = snapshot.prediction;
      _pinnedMessages = snapshot.pinnedMessages;
      _engagementError = lastError?.toString();
      _loadingEngagement = false;
    });

    if (lastError != null && showSnackOnError) {
      _showSnack('互動資料更新失敗：$lastError');
    }
  }

  Future<void> _refreshRelationshipStatus({String? channelLogin}) async {
    final login = (channelLogin ?? _channelLogin).trim().toLowerCase();
    if (login.isEmpty || _checkingRelationship) return;

    setState(() {
      _checkingRelationship = true;
      _relationshipError = null;
    });

    try {
      final snapshot = await _watchPorts.relationship.fetchRelationship(
        channelLogin: login,
        targetUserId: _channelId,
        viewerUserId: _viewerId,
      );
      if (!mounted) return;
      setState(() {
        _isFollowing = snapshot.isFollowing;
        if (snapshot.userId.trim().isNotEmpty) _channelId = snapshot.userId.trim();
        _relationshipError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _relationshipError = error.toString());
    } finally {
      if (mounted) setState(() => _checkingRelationship = false);
    }
  }

  Future<void> _toggleFollowChannel() async {
    if (_followBusy) return;
    final login = _channelLogin.trim().toLowerCase();
    if (login.isEmpty) return;

    setState(() {
      _followBusy = true;
      _relationshipError = null;
    });

    try {
      final snapshot = _isFollowing
          ? await _watchPorts.relationship.unfollowChannel(
              channelLogin: login,
              targetUserId: _channelId,
              viewerUserId: _viewerId,
            )
          : await _watchPorts.relationship.followChannel(
              channelLogin: login,
              targetUserId: _channelId,
              viewerUserId: _viewerId,
            );
      if (!mounted) return;
      setState(() {
        _isFollowing = snapshot.isFollowing;
        if (snapshot.userId.trim().isNotEmpty) _channelId = snapshot.userId.trim();
        _relationshipError = null;
      });
      _showSnack(_isFollowing ? '已追隨 $login' : '已取消追隨 $login');
    } catch (error) {
      if (mounted) {
        setState(() => _relationshipError = error.toString());
        _showSnack('追隨狀態更新失敗：$error');
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _openSubscribePage() async {
    try {
      final uri = _watchPorts.relationship.buildSubscribeUri(_channelLogin);
      await showTwitchSubscribeWebViewDialogV1(
        context: context,
        initialUri: uri,
        channelLogin: _channelLogin,
      );
    } catch (error) {
      _showSnack('開啟訂閱彈窗失敗：$error');
    }
  }

  Future<void> _enterMobileImmersiveByDefault() async {
    if (!TwitchFullscreenController.isMobilePlatform) return;
    try {
      await TwitchFullscreenController.setFullscreen(true);
      _mobileImmersiveEntered = true;
    } catch (_) {}
  }

  void _toggleChatVisibility() {
    setState(() => _chatVisible = !_chatVisible);
    unawaited(_saveChatVisiblePreference());
  }

  Future<void> _toggleFullscreenMode() async {
    final next = !_fullscreenMode;
    try {
      await TwitchFullscreenController.setFullscreen(next);
      if (!mounted) return;
      setState(() => _fullscreenMode = next);
    } catch (error) {
      _showSnack('切換全螢幕失敗：$error');
    }
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final runtime = _chatRuntime;
    if (runtime == null || !runtime.connected) {
      _showSnack('聊天室尚未連線。');
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _sending = true);
    try {
      await runtime.sendMessage(message);
      _messageController.clear();
    } catch (error) {
      _showSnack('發送失敗：$error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openEmotePicker() {
    return _sheetLauncher.openEmotePicker(context);
  }

  Future<void> _openChannelPointsSheet() {
    return _sheetLauncher.openChannelPointsSheet(context);
  }

  Future<void> _openPredictionBetSheet() {
    return _sheetLauncher.openPredictionBetSheet(context);
  }

  void _insertMessageText(String text) {
    final current = _messageController.text;
    final selection = _messageController.selection;
    final start = selection.start < 0 ? current.length : selection.start;
    final end = selection.end < 0 ? current.length : selection.end;
    final next = current.replaceRange(start, end, text);
    _messageController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _chatRuntime;
    final metadata = widget.resolvedInitialMetadata.copyWith(channelLogin: _channelLogin);

    Widget buildPlayerArea() {
      return TwitchWatchPlayerAreaPortAdapter(
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
    }

    Widget buildChatPanel() {
      return TwitchWatchChatPanelPortAdapter(
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
    }

    Widget buildMainBody() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final layout = TwitchResponsiveLayout.fromConstraints(constraints);

          if (layout.shouldUseBottomChat) {
            final preferredPlayerHeight =
                (layout.width * 9 / 16).clamp(160.0, 320.0).toDouble();
            final maxPlayerHeightWithChat =
                (layout.height - 430.0).clamp(150.0, 320.0).toDouble();
            final playerHeight = _chatVisible
                ? preferredPlayerHeight.clamp(150.0, maxPlayerHeightWithChat).toDouble()
                : layout.height;

            return Column(
              children: [
                SizedBox(
                  height: playerHeight,
                  width: double.infinity,
                  child: buildPlayerArea(),
                ),
                if (_chatVisible)
                  const Divider(height: 1, thickness: 1, color: Color(0xFF24242A)),
                if (_chatVisible) Expanded(child: buildChatPanel()),
              ],
            );
          }

          final effectiveChatWidth = _effectiveChatPanelWidthForViewport(layout);
          return Row(
            children: [
              Expanded(
                flex: layout.isPhoneLandscape ? 10 : 1,
                child: buildPlayerArea(),
              ),
              if (_chatVisible)
                SizedBox(
                  width: effectiveChatWidth,
                  child: Stack(
                    children: [
                      Positioned.fill(child: buildChatPanel()),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 10,
                        child: _ChatResizeHandle(
                          onDragUpdate: (delta) {
                            final currentChatWidth =
                                _chatPanelWidth > 0 ? _chatPanelWidth : effectiveChatWidth;
                            _setChatPanelWidthForViewport(
                              viewportWidth: layout.width,
                              value: currentChatWidth - delta.delta.dx,
                            );
                          },
                          onDragEnd: () {
                            _chatWidthPreferenceSaveDebounce?.cancel();
                            unawaited(_saveChatPanelWidthPreference());
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      );
    }

    final scaffold = Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: Stack(
        children: [
          Positioned.fill(child: buildMainBody()),
          if (_showBlockingStartupMask)
            Positioned.fill(
              child: _WatchBlockingStartupOverlay(
                title: _startupMaskTitle,
                subtitle: '正在啟動播放器與聊天室，互動資料會在背景載入。',
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

class _WatchBlockingStartupOverlay extends StatelessWidget {
  final String title;
  final String subtitle;

  const _WatchBlockingStartupOverlay({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: true,
      child: Container(
        color: const Color(0xFF050507).withOpacity(0.76),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B).withOpacity(0.96),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xAA000000),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatResizeHandle extends StatefulWidget {
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback? onDragEnd;

  const _ChatResizeHandle({
    required this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  State<_ChatResizeHandle> createState() => _ChatResizeHandleState();
}

class _ChatResizeHandleState extends State<_ChatResizeHandle> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovering || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: widget.onDragUpdate,
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onDragEnd?.call();
        },
        onHorizontalDragCancel: () {
          setState(() => _dragging = false);
          widget.onDragEnd?.call();
        },
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: active ? 2 : 1,
            height: double.infinity,
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF9146FF)
                  : Colors.white.withOpacity(0.06),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: const Color(0xFF9146FF).withOpacity(0.45),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
