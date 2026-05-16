// PATCH VERSION: watch_page_ratio_drag_vertical_compact_v56
// Full replacement file for lib/features/twitch/presentation/pages/twitch_watch_page.dart
// v56: chat resize is available on phone landscape too, width is stored as a ratio, and vertical compact layouts reduce overflow.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/channel/twitch_private_gql_relationship_api_service_v1.dart';
import '../../api/chat/twitch_chat_startup_api_service.dart';
import '../../api/chat/twitch_irc_api_service.dart';
import '../../api/chat/twitch_recent_messages_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../api/core/twitch_gql_api_service.dart';
import '../../api/core/twitch_web_gql_persisted_api_service.dart';
import '../../api/emotes/twitch_third_party_emote_api_service.dart';
import '../../api/emotes/twitch_official_emote_api_service.dart';
import '../../api/engagement/twitch_channel_points_api_service.dart';
import '../../api/engagement/twitch_subscribe_api_service_v1.dart';
import '../../api/engagement/twitch_drops_prediction_api_service.dart';
import '../../api/engagement/twitch_pinned_chat_api_service.dart';
import '../../api/engagement/twitch_prediction_api_service.dart';
import '../../api/playback/twitch_playback_api_service.dart';
import '../../models/discovery/twitch_stream_header_metadata.dart';
import '../../models/engagement/twitch_prediction.dart';
import '../../models/playback/twitch_m3u8_variant.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../../services/chat/twitch_badge_cache_service.dart';
import '../../services/chat/twitch_chat_runtime.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../services/chat/twitch_official_emote_cache_service.dart';
import '../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../services/playback/twitch_playlist_player_runtime.dart';
import '../../services/window/twitch_fullscreen_controller.dart';
import '../sheets/twitch_channel_points_sheet.dart';
import '../sheets/twitch_emote_picker_sheet.dart';
import '../sheets/twitch_prediction_bet_sheet.dart';
import '../dialogs/twitch_subscribe_webview_dialog_v1.dart';
import '../widgets/watch/twitch_watch_chat_panel.dart';
import '../widgets/watch/twitch_watch_player_area.dart';
import '../widgets/responsive/twitch_responsive_layout.dart';

class TwitchWatchPage extends StatefulWidget {
  final TwitchStreamHeaderMetadata initialMetadata;

  // Legacy entry-point arguments kept for older pages such as
  // twitch_windows_player_page.dart. New code should prefer initialMetadata.
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

    if (!hasLegacyMetadata) {
      return initialMetadata;
    }

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

  // media_kit native backend uses libmpv. Keep the PlayerConfiguration
  // bufferSize at media_kit default here so internal playback can be compared
  // fairly against external mpv without an artificially tiny demuxer cache.

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

  // Fallback keys from the first preference patch. These allow users who
  // already saved settings with the old patch to keep their values once.
  static const String _legacyChatPanelWidthPreferenceKey =
      'twitch_watch_chat_panel_width';
  static const String _legacyPlayerVolumePreferenceKey =
      'twitch_watch_player_volume';
  static const String _legacyPlayerMutedPreferenceKey =
      'twitch_watch_player_muted';
  static const double _minChatPanelWidth = 220.0;
  static const double _maxEffectiveMinChatPanelWidth = 340.0;
  static const double _maxChatPanelWidth = 620.0;
  static const double _minChatPanelRatio = 0.26;
  static const double _minStoredChatPanelRatio = 0.08;
  static const double _maxChatPanelRatio = 0.48;

  late final TextEditingController _channelController;
  late final TextEditingController _messageController;

  late final TwitchApiClient _apiClient;
  late final TwitchAuthService _authService;
  late final TwitchDropsAuthService _dropsAuthService;
  late final TwitchWebGqlAuthService _webGqlAuthService;
  late final TwitchAuthApiService _authApi;

  late final TwitchGqlApiService _publicGqlApi;
  late final TwitchWebGqlPersistedApiService _publicWebGqlApi;
  late final TwitchPlaybackApiService _playbackApi;
  late final TwitchPlaylistPlayerRuntime _playerRuntime;

  late final TwitchChatStartupApiService _chatStartupApi;
  late final TwitchRecentMessagesApiService _recentMessagesApi;
  late final TwitchThirdPartyEmoteCacheService _thirdPartyEmotes;
  late final TwitchOfficialEmoteCacheService _officialEmotes;

  late final TwitchChannelPointsApiService _channelPointsApi;
  late final TwitchPrivateGqlRelationshipApiServiceV1 _relationshipApi;
  late final TwitchSubscribeApiServiceV1 _subscribeApi;

  late final TwitchChannelPointsRuntimeService _channelPointsRuntimeService;
  late final TwitchPinnedChatApiService _pinnedChatApi;
  late final TwitchPredictionApiService _publicPredictionApi;
  late final TwitchDropsPredictionApiService _dropsPredictionApi;

  late final Player _player;
  late final VideoController _videoController;

  StreamSubscription<double>? _playerVolumeSubscription;
  Timer? _volumePreferenceSaveDebounce;
  Timer? _chatWidthPreferenceSaveDebounce;

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

  double _chatPanelWidth = 430;
  double _chatPanelRatio = 0.34;
  double _volume = 100.0;
  double _lastNonZeroVolume = 100.0;

  String? _viewerLogin;
  String? _viewerId;
  String? _channelId;
  List<String> _viewerScopes = const <String>[];
  String _statusText = '載入 OAuth 中...';
  String? _playerError;
  String? _engagementError;
  String? _relationshipError;

  TwitchChannelPointsRuntimeSnapshot? _channelPointsSnapshot;
  TwitchPredictionSnapshot? _prediction;
  List<dynamic> _pinnedMessages = const <dynamic>[];

  @override
  void initState() {
    super.initState();

    _channelController = TextEditingController(text: widget.resolvedInitialMetadata.channelLogin);
    _messageController = TextEditingController();

    _apiClient = TwitchApiClient();
    _authService = TwitchAuthService(apiClient: _apiClient);
    _dropsAuthService = TwitchDropsAuthService(apiClient: _apiClient);
    _webGqlAuthService = TwitchWebGqlAuthService(apiClient: _apiClient);

    _authApi = TwitchAuthApiService(
      client: _apiClient,
      clientId: TwitchApiConstants.twitchWebClientId,
    );

    _publicGqlApi = TwitchGqlApiService(
      client: _apiClient,
      clientId: TwitchApiConstants.twitchWebClientId,
      accessTokenProvider: null,
    );

    _publicWebGqlApi = TwitchWebGqlPersistedApiService(
      client: _apiClient,
      clientId: TwitchApiConstants.twitchWebClientId,
      accessTokenProvider: _webGqlAuthService.getToken,
    );

    _playbackApi = TwitchPlaybackApiService(gql: _publicGqlApi);
    _playerRuntime = TwitchPlaylistPlayerRuntime(playbackApi: _playbackApi);

    _chatStartupApi = TwitchChatStartupApiService(gql: _publicWebGqlApi);
    _recentMessagesApi = TwitchRecentMessagesApiService(client: _apiClient);
    _thirdPartyEmotes = TwitchThirdPartyEmoteCacheService(
      api: TwitchThirdPartyEmoteApiService(client: _apiClient),
    );
    _officialEmotes = TwitchOfficialEmoteCacheService(
      api: TwitchOfficialEmoteApiService(client: _apiClient),
      accessTokenProvider: _authService.getValidAccessToken,
      clientIdProvider: () async {
        final stored = _authService.clientId?.trim();
        if (stored != null && stored.isNotEmpty) return stored;
        return TwitchApiConstants.twitchWebClientId;
      },
    );

    _channelPointsApi = TwitchChannelPointsApiService(
      gql: _publicWebGqlApi,
      client: _apiClient,
      tokenProvider: _webGqlAuthService.getToken,
      actionClientIdProvider: () => TwitchApiConstants.twitchWebClientId,
    );
    _relationshipApi = TwitchPrivateGqlRelationshipApiServiceV1(
      client: _apiClient,
      // PATCH v15: token providers are split. Status check uses main OAuth;
      // Follow / Unfollow uses Drops Android token only. Web GQL token is not
      // allowed to fallback into relationship mutations.
      oauthTokenProvider: _authService.getValidAccessToken,
      oauthClientIdProvider: () async {
        final stored = _authService.clientId?.trim();
        if (stored != null && stored.isNotEmpty) return stored;
        return TwitchApiConstants.twitchWebClientId;
      },
      dropsTokenProvider: _dropsAuthService.getToken,
      dropsClientIdProvider: () async => _dropsAuthService.dropsClientId,
    );
    _subscribeApi = const TwitchSubscribeApiServiceV1();
    _channelPointsRuntimeService = TwitchChannelPointsRuntimeService(
      channelPointsApi: _channelPointsApi,
    );

    _pinnedChatApi = TwitchPinnedChatApiService(
      client: _apiClient,
      clientId: TwitchApiConstants.twitchWebClientId,
      accessTokenProvider: null,
    );
    _publicPredictionApi = TwitchPredictionApiService(gql: _publicWebGqlApi);
    _dropsPredictionApi = TwitchDropsPredictionApiService(
      client: _apiClient,
      tokenProvider: _dropsAuthService.getToken,
    );

    MediaKit.ensureInitialized();

    _player = Player(
      configuration: const PlayerConfiguration(
        title: 'Twitch Raw Proxy',
      ),
    );
    _videoController = VideoController(_player);
    unawaited(_applyAndroidMediaKitPerformanceHints());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _enterMobileImmersiveByDefault();
      if (!mounted) return;

      await _loadWatchPreferences();
      if (!mounted) return;

      await _loadAuth();
      if (mounted) {
        await _loadWatch();
      }
    });
  }

  @override
  void dispose() {
    _channelController.dispose();
    _messageController.dispose();

    final chatRuntime = _chatRuntime;
    _chatRuntime = null;
    unawaited(chatRuntime?.disposeRuntime());

    _playerRuntime.dispose();

    _volumePreferenceSaveDebounce?.cancel();
    _chatWidthPreferenceSaveDebounce?.cancel();
    unawaited(_saveVolumePreference());
    unawaited(_saveChatPanelWidthPreference());
    unawaited(_playerVolumeSubscription?.cancel());
    unawaited(_player.dispose());

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

  bool get _busy {
    return _loadingAuth || _loadingWatch || _loadingPlayer || _connectingChat;
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

      // Migrate any legacy value into the v2 keys immediately.
      unawaited(_saveChatPanelWidthPreference());
      unawaited(_saveVolumePreference());
    } catch (e) {
      debugPrint('load watch preferences v2 failed: $e');
      // 偏好設定讀取失敗時維持預設值，不阻擋播放器啟動。
    }

    await _applyPlayerVolume();
    _bindPlayerVolumeStream();
  }

  void _bindPlayerVolumeStream() {
    unawaited(_playerVolumeSubscription?.cancel());
    _playerVolumeSubscription = _player.stream.volume.listen((value) {
      _handlePlayerVolumeChanged(value);
    });
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
      if (nextVolume > 0.0) {
        _lastNonZeroVolume = nextVolume;
      }
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

    final effectiveVolume = _isMuted ? 0.0 : _volume.clamp(0.0, 100.0).toDouble();
    await _player.setVolume(effectiveVolume);
  }

  Future<void> _applyAndroidMediaKitPerformanceHints() async {
    if (!TwitchFullscreenController.isMobilePlatform) return;

    dynamic platform;
    try {
      platform = (_player as dynamic).platform;
    } catch (error) {
      debugPrint('media_kit Android tuning skipped: platform unavailable: $error');
      return;
    }

    Future<void> applyOption(String name, String value) async {
      try {
        await platform.setProperty(name, value);
        return;
      } catch (_) {
        try {
          await platform.setOption(name, value);
        } catch (error) {
          debugPrint('media_kit Android tuning failed: $name=$value: $error');
        }
      }
    }

    // Force Android MediaCodec decoding for Twitch H.264 streams. mediacodec-copy
    // is usually safer than direct mediacodec on libmpv based Flutter rendering.
    await applyOption('hwdec', 'mediacodec-copy');
    await applyOption('hwdec-codecs', 'all');

    // Reduce software decoder thread overhead if mpv falls back from MediaCodec.
    await applyOption('vd-lavc-threads', '1');

    // Cheap scaling helps midrange tablet GPUs when the video surface is resized.
    await applyOption('scale', 'bilinear');
    await applyOption('dscale', 'bilinear');
  }

  Future<void> _saveChatVisiblePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chatVisiblePreferenceKey, _chatVisible);
    } catch (e) {
      debugPrint('save watch chat visibility preference v2 failed: $e');
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
    } catch (e) {
      debugPrint('save watch chat width preference v2 failed: $e');
    }
  }

  void _scheduleChatPanelWidthPreferenceSave() {
    _chatWidthPreferenceSaveDebounce?.cancel();
    _chatWidthPreferenceSaveDebounce = Timer(
      const Duration(milliseconds: 250),
      () {
        unawaited(_saveChatPanelWidthPreference());
      },
    );
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
    } catch (e) {
      debugPrint('save watch volume preference v2 failed: $e');
    }
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
    final nextWidth = value
        .clamp(effectiveMinWidth, effectiveMaxWidth)
        .toDouble();
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

    // Keep drag lightweight; persist only on drag end.
    // Debouncing a preference write on every drag update made resize feel sticky.
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

  Future<void> _loadAuth() async {
    setState(() {
      _loadingAuth = true;
      _statusText = '載入 OAuth 中...';
    });

    try {
      await _authService.loadStoredSession();
      await _webGqlAuthService.loadStoredSession();
      await _dropsAuthService.loadStoredSession();

      final token = await _authService.getValidAccessToken();

      if (token == null || token.isEmpty) {
        setState(() {
          _statusText = '沒有可用 OAuth，請先回登入頁登入。';
          _loadingAuth = false;
        });
        return;
      }

      final validation = await _authApi.validateToken(token);

      setState(() {
        _viewerLogin = validation.login;
        _viewerId = validation.userId;
        _viewerScopes = validation.scopes;
        _statusText = [
          _scopeStatusText(validation.scopes),
          _webGqlAuthService.accessToken == null
              ? 'Web GQL token 尚未建立，忠誠點數可能不可用。'
              : 'Web GQL token 已載入。',
          _dropsAuthService.accessToken == null
              ? 'Drops token 尚未建立，Follow/下注可能不可用。'
              : 'Drops token 已載入。',
        ].join(' ');
        _loadingAuth = false;
      });
    } catch (e) {
      setState(() {
        _statusText = 'OAuth 載入失敗：$e';
        _loadingAuth = false;
      });
    }
  }

  Future<void> _loadWatch() async {
    if (_loadingWatch) return;

    final channel = _channelLogin;

    setState(() {
      _loadingWatch = true;
      _statusText = '載入播放器中...';
      _playerError = null;
      _engagementError = null;
      _relationshipError = null;
    });

    try {
      await _stopCurrentSession(clearStatus: false);

      // PATCH v33: keep the critical path short. The user should see video as
      // soon as the live playlist/media player is ready; chat, pinned message,
      // prediction, channel points and relationship status are loaded in the
      // background instead of blocking the whole page transition.
      await _loadPlayer(channel);

      if (!mounted) return;

      setState(() {
        _statusText = '播放器已載入 #$channel，聊天室與互動資料背景載入中...';
      });

      unawaited(
        _connectChat(channel).catchError((Object error, StackTrace stackTrace) {
          if (!mounted) return;
          setState(() {
            _statusText = '聊天室背景連線失敗：$error';
          });
          _showSnack('聊天室連線失敗：$error');
        }),
      );

      unawaited(_refreshRelationshipStatus(channelLogin: channel));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = '載入 Watch Page 失敗：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWatch = false;
        });
      }
    }
  }

  Future<void> _loadPlayer(String channel) async {
    setState(() {
      _loadingPlayer = true;
      _playerError = null;
    });

    try {
      final dynamic result = await _playerRuntime.loadLivePlaylist(
        channelLogin: channel,
      );

      final Uri? playlistUri = result is Uri
          ? result
          : _readPlayerRuntimePlaylistUri();

      if (playlistUri == null) {
        throw StateError('播放清單載入失敗，沒有 playlist uri。');
      }

      await _applyAndroidMediaKitPerformanceHints();
      await _applyPlayerVolume();
      await _player.open(Media(playlistUri.toString()), play: true);
      await _applyPlayerVolume();
      await _waitForInitialPlaybackSettle();
    } catch (e) {
      _playerError = e.toString();
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _loadingPlayer = false;
        });
      }
    }
  }

  Future<void> _waitForInitialPlaybackSettle() async {
    // The raw proxy can already be producing live bytes while media_kit is still
    // initializing. Keep the first-page critical path player-only until the
    // native player has at least started producing a video stream, or until a
    // short timeout is reached. Chat, emotes and engagement requests are started
    // only after this guard so they do not compete with the first few frames.
    if (_player.state.width != null && _player.state.width! > 0) {
      return;
    }

    final completer = Completer<void>();
    StreamSubscription<int?>? widthSubscription;
    StreamSubscription<bool>? playingSubscription;
    Timer? timeout;

    void complete() {
      if (completer.isCompleted) return;
      completer.complete();
      unawaited(widthSubscription?.cancel());
      unawaited(playingSubscription?.cancel());
      timeout?.cancel();
    }

    widthSubscription = _player.stream.width.listen((width) {
      if ((width ?? 0) > 0) complete();
    });
    playingSubscription = _player.stream.playing.listen((playing) {
      if (playing) {
        // Give the decoder a tiny head start after play starts; this keeps the
        // initial proxy route closer to external mpv without forcing a long wait.
        Timer(const Duration(milliseconds: 180), complete);
      }
    });
    timeout = Timer(const Duration(milliseconds: 850), complete);

    return completer.future;
  }

  Uri? _readPlayerRuntimePlaylistUri() {
    try {
      final dynamic runtime = _playerRuntime;
      final value = runtime.playlistUri;
      if (value is Uri) return value;
      if (value != null) return Uri.tryParse(value.toString());
    } catch (_) {
      // The runtime implementation may not expose playlistUri.
    }
    return null;
  }

  Future<void> _selectPlayerQuality(TwitchM3u8Variant variant) async {
    if (_loadingPlayer) return;

    setState(() {
      _loadingPlayer = true;
      _playerError = null;
    });

    try {
      final uri = await _playerRuntime.startProxyForVariant(variant);
      if (uri == null) {
        throw StateError('切換畫質失敗：runtime 沒有回傳 playlist uri。');
      }

      await _applyAndroidMediaKitPerformanceHints();
      await _applyPlayerVolume();
      await _player.open(Media(uri.toString()), play: true);
      await _applyPlayerVolume();
      await _waitForInitialPlaybackSettle();
    } catch (e) {
      _playerError = e.toString();
      _showSnack('切換畫質失敗：$e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingPlayer = false;
        });
      }
    }
  }

  Future<void> _refreshRelationshipStatus({String? channelLogin}) async {
    final login = (channelLogin ?? _channelLogin).trim().toLowerCase();
    if (login.isEmpty || _checkingRelationship) return;

    if (mounted) {
      setState(() {
        _checkingRelationship = true;
        _relationshipError = null;
      });
    }

    try {
      final snapshot = await _relationshipApi.fetchRelationship(
        channelLogin: login,
        targetUserId: _channelId,
        viewerUserId: _viewerId,
      );

      if (!mounted) return;

      setState(() {
        _isFollowing = snapshot.isFollowing;
        if (snapshot.userId.trim().isNotEmpty) {
          _channelId = snapshot.userId.trim();
        }
        _relationshipError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _relationshipError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingRelationship = false;
        });
      }
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
          ? await _relationshipApi.unfollowChannel(
              channelLogin: login,
              targetUserId: _channelId,
              viewerUserId: _viewerId,
            )
          : await _relationshipApi.followChannel(
              channelLogin: login,
              targetUserId: _channelId,
              viewerUserId: _viewerId,
            );

      if (!mounted) return;

      setState(() {
        _isFollowing = snapshot.isFollowing;
        if (snapshot.userId.trim().isNotEmpty) {
          _channelId = snapshot.userId.trim();
        }
        _relationshipError = null;
      });

      _showSnack(_isFollowing ? '已追隨 $login' : '已取消追隨 $login');

      // Follow/unfollow can take a short moment to propagate. Refresh once more
      // without blocking the button state.
      unawaited(Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return Future<void>.value();
        return _refreshRelationshipStatus(channelLogin: login);
      }));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _relationshipError = e.toString();
      });
      _showSnack('追隨狀態更新失敗：$e');
    } finally {
      if (mounted) {
        setState(() {
          _followBusy = false;
        });
      }
    }
  }

  Future<void> _openSubscribePage() async {
    try {
      final uri = _subscribeApi.buildSubscribeUri(_channelLogin);
      await showTwitchSubscribeWebViewDialogV1(
        context: context,
        initialUri: uri,
        channelLogin: _channelLogin,
      );
    } catch (e) {
      _showSnack('開啟訂閱彈窗失敗：$e');
    }
  }

  Future<void> _enterMobileImmersiveByDefault() async {
    if (!TwitchFullscreenController.isMobilePlatform) return;

    try {
      await TwitchFullscreenController.setFullscreen(true);
      _mobileImmersiveEntered = true;
    } catch (_) {
      // Best effort only. Do not block watch page startup.
    }
  }

  void _toggleChatVisibility() {
    setState(() {
      _chatVisible = !_chatVisible;
    });
    unawaited(_saveChatVisiblePreference());
  }

  Future<void> _toggleFullscreenMode() async {
    final next = !_fullscreenMode;

    try {
      await TwitchFullscreenController.setFullscreen(next);

      if (!mounted) return;

      setState(() {
        _fullscreenMode = next;
      });
    } catch (e) {
      _showSnack('切換全螢幕失敗：$e');
    }
  }

  Future<void> _connectChat(String channel) async {
    setState(() {
      _connectingChat = true;
    });

    try {
        await _chatRuntime?.disposeRuntime();

      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw StateError('沒有可用 OAuth，不能連線可發言聊天室。');
      }

      await _dropsAuthService.loadStoredSession();

      final validation = await _authApi.validateToken(token);
      final startup = await _chatStartupApi.fetchParsedStartupSnapshot(
        channelLogin: channel,
      );

      final runtime = TwitchChatRuntime(
        ircApi: TwitchIrcApiService(),
        writeIrcApi: TwitchIrcApiService(),
        badgeCache: TwitchBadgeCacheService(),
        recentMessagesApi: _recentMessagesApi,
      );

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

      unawaited(_loadThirdPartyEmotes());
      unawaited(_refreshEngagement(showSnackOnError: false));

      if (mounted) {
        setState(() {
          _statusText = '已連線 #$channel，互動資料背景更新中...';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _connectingChat = false;
        });
      }
    }
  }

  Future<void> _stopCurrentSession({bool clearStatus = true}) async {

    await _chatRuntime?.disconnect();
    await _player.stop();

    _thirdPartyEmotes.clear();
    _officialEmotes.clear();

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

      if (clearStatus) {
        _statusText = '已停止播放與聊天室。';
      }
    });
  }

  Future<void> _loadThirdPartyEmotes({
    bool forceRefresh = false,
  }) async {
    final channelId = _channelId;
    final channelLogin = _channelLogin;
    final viewerId = _viewerId;

    if (channelId == null || channelId.isEmpty) return;

    setState(() {
      _loadingEmotes = true;
    });

    try {
      await Future.wait<void>(
        <Future<void>>[
          _thirdPartyEmotes.loadForChannel(
            channelId: channelId,
            channelLogin: channelLogin,
          ),
          _officialEmotes.loadForChannel(
            channelId: channelId,
            viewerId: viewerId ?? '',
            forceRefresh: forceRefresh,
          ),
        ],
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingEmotes = false;
        });
      }
    }
  }

  Future<void> _refreshEngagement({
    bool showSnackOnError = true,
  }) async {
    final channelLogin = _channelLogin;
    final channelId = _channelId;

    if (!mounted) return;

    setState(() {
      _loadingEngagement = true;
      _engagementError = null;
    });

    final errors = <Object>[];
    TwitchChannelPointsRuntimeSnapshot? nextChannelPointsSnapshot;
    TwitchPredictionSnapshot? nextPrediction;
    List<dynamic>? nextPinnedMessages;

    Future<void> loadChannelPoints() async {
      try {
        nextChannelPointsSnapshot = await _channelPointsRuntimeService.load(
          channelLogin: channelLogin,
        );
      } catch (e) {
        errors.add(e);
      }
    }

    Future<void> loadPrediction() async {
      try {
        nextPrediction = await _publicPredictionApi.fetchPredictionContext(
          channelLogin: channelLogin,
        );
      } catch (e) {
        errors.add(e);
      }
    }

    Future<void> loadPinnedMessages() async {
      if (channelId == null || channelId.isEmpty) {
        nextPinnedMessages = const <dynamic>[];
        return;
      }

      try {
        nextPinnedMessages = await _pinnedChatApi.getPinnedChatMessages(
          channelId: channelId,
        );
      } catch (e) {
        errors.add(e);
      }
    }

    try {
      // PATCH v33: these three requests are independent snapshots. Start them
      // together so pinned chat / prediction / channel points no longer form a
      // slow serial chain after chat connects.
      await Future.wait<void>(<Future<void>>[
        loadChannelPoints(),
        loadPrediction(),
        loadPinnedMessages(),
      ]);
    } catch (e) {
      errors.add(e);
    }

    if (!mounted || channelLogin != _channelLogin) return;

    final lastError = errors.isEmpty ? null : errors.last;

    setState(() {
      if (nextChannelPointsSnapshot != null) {
        _channelPointsSnapshot = nextChannelPointsSnapshot;
      }
      if (nextPrediction != null) {
        _prediction = nextPrediction;
      }
      if (nextPinnedMessages != null) {
        _pinnedMessages = nextPinnedMessages!;
      }

      _engagementError = lastError?.toString();
      _loadingEngagement = false;
    });

    if (lastError != null && showSnackOnError) {
      _showSnack('互動資料更新失敗：$lastError');
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

    if (!_viewerScopes.contains('chat:edit')) {
      _showSnack('目前 OAuth scope 沒有 chat:edit，可能無法發送訊息。');
    }

    setState(() {
      _sending = true;
    });

    try {
      await runtime.sendMessage(message);
      _messageController.clear();
    } catch (e) {
      _showSnack('發送失敗：$e');
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _openEmotePicker() async {
    await showTwitchEmotePickerSheet(
      context: context,
      cache: _thirdPartyEmotes,
      officialCache: _officialEmotes,
      loading: _thirdPartyEmotes.loading ||
          _officialEmotes.loading ||
          _loadingEmotes,
      onRefresh: () => _loadThirdPartyEmotes(forceRefresh: true),
      onEmoteSelected: (emoteText) {
        if (emoteText.trim().isEmpty) return;
        _insertMessageText('${emoteText.trim()} ');
      },
    );
  }

  Future<void> _openChannelPointsSheet() async {
    await showTwitchChannelPointsSheet(
      context: context,
      snapshot: _channelPointsSnapshot,
      loading: _loadingEngagement,
      onRefresh: () => _refreshEngagement(showSnackOnError: true),
      onClaim: _claimCommunityPoints,
      onRedeemReward: _redeemChannelPointReward,
      onLoadChannelPointEmotes: _enableChannelPointEmoteMenu
          ? (_) => _loadChannelPointModifiableEmotes()
          : null,
    );
  }

  Future<List<TwitchChannelPointEmoteOption>> _loadChannelPointModifiableEmotes() async {
    try {
      return await _channelPointsApi.getModifiableEmotes(
        channelLogin: _channelLogin,
        channelId: _channelPointsSnapshot?.channelId ?? _channelId,
      );
    } catch (error) {
      _showSnack('載入忠誠點數 emote 失敗：$error');
      return const <TwitchChannelPointEmoteOption>[];
    }
  }

  Future<void> _claimCommunityPoints(String claimId) async {
    final channelId = _channelPointsSnapshot?.channelId ?? _channelId;

    if (channelId == null || channelId.isEmpty) {
      _showSnack('沒有 channelId，不能領取忠誠點數。');
      return;
    }

    try {
      final result = await _channelPointsRuntimeService.claimBonus(
        channelId: channelId,
        claimId: claimId,
      );

      _showSnack('已送出領取忠誠點數：+${result.pointsEarned}');
      await _refreshEngagement(showSnackOnError: false);
    } catch (e) {
      _showSnack('領取失敗：$e');
    }
  }

  Future<void> _redeemChannelPointReward(
    Map<String, dynamic> reward,
    String textInput,
  ) async {
    final channelId = _channelPointsSnapshot?.channelId ?? _channelId;
    final title = reward['title']?.toString() ?? 'Reward';

    if (channelId == null || channelId.isEmpty) {
      _showSnack('沒有 channelId，不能兌換忠誠點數獎勵。');
      return;
    }

    try {
      await _channelPointsRuntimeService.redeemReward(
        channelId: channelId,
        reward: reward,
        textInput: textInput,
      );

      _showSnack('已兌換：$title');
      await _refreshEngagement(showSnackOnError: false);
    } catch (e) {
      _showSnack('兌換失敗：$e');
    }
  }

  Future<void> _openPredictionBetSheet() async {
    final prediction = _prediction;
    if (prediction == null || !prediction.hasPrediction) {
      _showSnack('目前沒有賭盤。');
      return;
    }

    await showTwitchPredictionBetSheet(
      context: context,
      prediction: prediction,
      onBet: _placePredictionBet,
    );
  }

  Future<void> _placePredictionBet(
    TwitchPredictionOutcome outcome,
    int points,
  ) async {
    final prediction = _prediction;
    if (prediction == null || !prediction.hasPrediction) {
      _showSnack('目前沒有可下注的賭盤。');
      return;
    }

    try {
      await _dropsPredictionApi.makePrediction(
        prediction: prediction,
        outcome: outcome,
        points: points,
      );

      _showSnack('已送出下注：${outcome.title} · $points 點');
      await _refreshEngagement(showSnackOnError: false);
    } catch (e) {
      _showSnack('下注失敗：$e');
    }
  }

  void _insertMessageText(String text) {
    final current = _messageController.text;
    final selection = _messageController.selection;

    final start = selection.start < 0 ? current.length : selection.start;
    final end = selection.end < 0 ? current.length : selection.end;

    final next = current.replaceRange(start, end, text);
    final offset = start + text.length;

    _messageController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  String _scopeStatusText(List<String> scopes) {
    final hasRead = scopes.contains('chat:read');
    final hasEdit = scopes.contains('chat:edit');

    if (hasRead && hasEdit) {
      return 'Scope OK：chat:read / chat:edit 都存在。';
    }

    return 'Scope 警告：chat:read=${hasRead ? "OK" : "缺少"}，chat:edit=${hasEdit ? "OK" : "缺少"}。';
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _chatRuntime;

    Widget buildPlayerArea() {
      return TwitchWatchPlayerArea(
        playerRuntime: _playerRuntime,
        player: _player,
        videoController: _videoController,
        metadata: widget.resolvedInitialMetadata.copyWith(channelLogin: _channelLogin),
        loading: _loadingPlayer,
        error: _playerError,
        qualityVariants: _playerRuntime.variants,
        currentVariant: _playerRuntime.currentVariant,
        qualityBusy: _playerRuntime.switchingQuality || _loadingPlayer,
        onQualitySelected: (variant) => unawaited(_selectPlayerQuality(variant)),
        isFollowing: _isFollowing,
        relationshipBusy: _checkingRelationship || _followBusy,
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
      );
    }

    Widget buildChatPanel() {
      return TwitchWatchChatPanel(
        runtime: runtime,
        viewerLogin: _viewerLogin,
        viewerId: _viewerId,
        thirdPartyEmoteCache: _thirdPartyEmotes,
        emoteCount: _thirdPartyEmotes.count,
        loadingEmotes: _loadingEmotes || _thirdPartyEmotes.loading,
        channelPoints: _channelPointsSnapshot,
        pinnedMessages: _pinnedMessages,
        prediction: _prediction,
        loadingEngagement: _loadingEngagement,
        engagementError: _engagementError,
        messageController: _messageController,
        sending: _sending,
        onSend: _sendMessage,
        onOpenEmotes: _openEmotePicker,
        onRefreshEmotes: () => _loadThirdPartyEmotes(forceRefresh: true),
        onRefreshEngagement: () => _refreshEngagement(
          showSnackOnError: true,
        ),
        onOpenChannelPoints: _openChannelPointsSheet,
        onOpenPrediction: _openPredictionBetSheet,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: LayoutBuilder(
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
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFF24242A),
                  ),
                if (_chatVisible)
                  Expanded(
                    child: buildChatPanel(),
                  ),
              ],
            );
          }

          final effectiveChatWidth = _effectiveChatPanelWidthForViewport(layout);
          final playerFlex = layout.isPhoneLandscape ? 10 : 1;

          return Row(
            children: [
              Expanded(
                flex: playerFlex,
                child: buildPlayerArea(),
              ),
              if (_chatVisible)
                SizedBox(
                  width: effectiveChatWidth,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: buildChatPanel(),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 10,
                        child: _ChatResizeHandle(
                          onDragUpdate: (delta) {
                            final currentChatWidth = _chatPanelWidth > 0
                                ? _chatPanelWidth
                                : effectiveChatWidth;
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
