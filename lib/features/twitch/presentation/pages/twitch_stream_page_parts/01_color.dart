part of '../twitch_stream_page.dart';

const Color _kBackground = Colors.transparent;

/// Coherent account/discovery dependencies for an isolated home session.
/// The page owns the client's lifetime, just as for its default dependencies.
class TwitchStreamPageServices {
  final TwitchApiClient apiClient;
  final TwitchAuthService authService;
  final TwitchDropsAuthService dropsAuthService;
  final TwitchWebGqlAuthService webGqlAuthService;
  final TwitchAuthApiService authApi;
  final TwitchDiscoveryService discoveryService;

  /// Creates a fresh, coherent watch bundle for each media-card route.
  final TwitchWatchServices Function()? watchServicesFactory;
  final TwitchWatchChatRuntimeFactory? watchChatRuntimeFactory;

  TwitchStreamPageServices({
    required this.apiClient,
    required this.authService,
    required this.dropsAuthService,
    required this.webGqlAuthService,
    required this.authApi,
    required this.discoveryService,
    this.watchServicesFactory,
    this.watchChatRuntimeFactory,
  }) : assert(identical(discoveryService.client, apiClient)),
       assert(identical(discoveryService.authService, authService)),
       assert(identical(discoveryService.authApi, authApi));
}

class TwitchStreamPage extends StatefulWidget {
  final TwitchStreamPageServices? services;
  const TwitchStreamPage({super.key, this.services});

  @override
  State<TwitchStreamPage> createState() => _TwitchStreamPageState();
}

class _TwitchStreamPageState extends State<TwitchStreamPage>
    with WidgetsBindingObserver {
  static const Duration _followedLivePollInterval = Duration(minutes: 1);

  final TextEditingController searchController = TextEditingController();

  final GlobalKey<TwitchFollowingPageState> followingPageKey =
      GlobalKey<TwitchFollowingPageState>();
  final GlobalKey<TwitchBrowsePageState> browsePageKey =
      GlobalKey<TwitchBrowsePageState>();

  late final TwitchApiClient apiClient;
  late final TwitchAuthService authService;
  late final TwitchDropsAuthService dropsAuthService;
  late final TwitchWebGqlAuthService webGqlAuthService;
  late final TwitchAuthApiService authApi;
  late final TwitchDiscoveryService discoveryService;
  late final TwitchChatAppearanceController chatAppearanceController;
  late final TwitchPlayerSettingsController playerSettingsController;
  late final VioClassUpdateController updateController;
  late final TwitchWhisperInboxController whisperInbox;
  late final TwitchAccountNotificationMonitor _accountNotifications;

  // Start on public content while the saved session is being checked. A
  // verified viewer can still be routed to Following below, but a guest must
  // never land on an OAuth-only page first.
  TwitchHomeSection selectedSection = TwitchHomeSection.browse;

  String searchText = '';
  String loginStatus = '檢查登入狀態...';
  String viewerLabel = '未登入';
  List<TwitchLiveStream> searchedLiveStreams = const <TwitchLiveStream>[];
  List<TwitchFollowedChannel> searchedOfflineChannels =
      const <TwitchFollowedChannel>[];
  List<_TwitchSearchVideoResult> searchedVideos =
      const <_TwitchSearchVideoResult>[];
  List<_TwitchSearchClipResult> searchedClips =
      const <_TwitchSearchClipResult>[];
  Set<String> followedUserIds = const <String>{};
  Set<String> followedLogins = const <String>{};
  String? channelSearchError;
  int reloadTick = 0;
  bool loadingLoginState = true;
  bool _hasAuthenticatedViewer = false;
  bool _canReadFollows = false;
  bool _homeSectionTouched = false;
  bool loadingChannelSearch = false;
  bool _loginStateLoadRunning = false;
  int _loginStateLoadId = 0;
  bool _loginStateReloadPending = false;
  bool _loggingOut = false;
  int _loginStateGeneration = 0;
  String? _observedAccessToken;
  int _channelSearchGeneration = 0;
  Timer? _channelSearchDebounce;
  Timer? _followedLiveNotificationTimer;
  final _liveNotificationPolicy = TwitchLiveNotificationPolicy();
  bool _checkingFollowedLiveNotifications = false;
  bool _settingsSheetOpen = false;
  StreamSubscription<VioClassConnectivitySnapshot>?
  _networkRestoredSubscription;
  StreamSubscription<VioClassConnectivitySnapshot>? _networkLostSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSize = 300;
    imageCache.maximumSizeBytes = 64 * 1024 * 1024;

    final services = widget.services;
    apiClient = services?.apiClient ?? TwitchApiClient();
    authService =
        services?.authService ?? TwitchAuthService(apiClient: apiClient);
    authService.addListener(_handleAuthSessionChanged);
    dropsAuthService =
        services?.dropsAuthService ??
        TwitchDropsAuthService(apiClient: apiClient);
    webGqlAuthService =
        services?.webGqlAuthService ??
        TwitchWebGqlAuthService(apiClient: apiClient);
    authApi = services?.authApi ?? TwitchAuthApiService(client: apiClient);
    final accountNotificationApi = TwitchAccountNotificationApi(apiClient);
    _accountNotifications = TwitchAccountNotificationMonitor(
      fetch: (ownerId) async {
        // Read existing credentials only. Verify every candidate's owner;
        // never send one account's response to another account's monitor.
        for (final provider in [
          webGqlAuthService.getToken,
          authService.getValidAccessToken,
        ]) {
          try {
            final token = await provider();
            if (token == null || token.trim().isEmpty) continue;
            final validation = await authApi.validateToken(token);
            if (validation.userId != ownerId) continue;
            return await accountNotificationApi.fetch(
              token: token,
              ownerId: ownerId,
            );
          } catch (_) {
            // Try the existing app token, as StreamNook does; no new login.
          }
        }
        throw StateError('Account notification feed unavailable');
      },
      notify: twitchSystemNotificationService.showAccountNotification,
    );
    discoveryService =
        services?.discoveryService ??
        TwitchDiscoveryService(
          client: apiClient,
          authService: authService,
          authApi: authApi,
          webTokenProvider: webGqlAuthService.getToken,
        );
    discoveryService.viewerSession.addListener(_handleViewerIdentityChanged);
    chatAppearanceController = twitchChatAppearanceController;
    playerSettingsController = TwitchPlayerSettingsController();
    updateController = VioClassUpdateController(
      onNewVersion: (info) => twitchSystemNotificationService.showAppUpdate(
        version: info.release.version,
        onOpen: openUpdates,
      ),
    );
    final whisperHistory = TwitchWhisperHistoryApiService(
      client: apiClient,
      webTokenProviders: [webGqlAuthService.getToken],
      androidTokenProviders: [dropsAuthService.getToken],
      integrityHeadersProvider:
          TwitchWhisperLoginIntegrityService.instance.headersFor,
      integrityInvalidator:
          TwitchWhisperLoginIntegrityService.instance.invalidateRejected,
    );
    whisperInbox = TwitchWhisperInboxController(
      archiveApi: TwitchWhisperArchiveApiService(history: whisperHistory),
      historyApi: whisperHistory,
      threadsApi: TwitchWhisperThreadsApiService(
        history: whisperHistory,
        integrityProvider:
            TwitchWhisperLoginIntegrityService.instance.forSession,
        integrityInvalidator:
            TwitchWhisperLoginIntegrityService.instance.invalidateRejected,
      ),
      onIncomingNotification: (peer) => unawaited(
        twitchSystemNotificationService.showWhisper(
          sender: peer.displayName,
          userId: peer.userId,
          ownerId: whisperInbox.ownerId ?? '',
        ),
      ),
      api: TwitchWhisperApiService(
        client: apiClient,
        tokenProviders: [
          authService.getValidAccessToken,
          webGqlAuthService.getToken,
          dropsAuthService.getToken,
        ],
      ),
    );
    twitchAppSettingsLauncher.attach(
      openSettings,
      updateController: updateController,
      updateOpener: openUpdates,
      whisperOpener: openWhispers,
      whisperInbox: whisperInbox,
      navigationReady: false,
    );
    playerSettingsController.addListener(_handleRootPlaybackPolicyChanged);
    TwitchPlaybackSessionController.instance.addListener(
      _handleRootPlaybackPolicyChanged,
    );
    TwitchMiniPlayerController.instance.addListener(
      _handleRootPlaybackPolicyChanged,
    );
    TwitchAndroidPipController.instance.addListener(
      _handleRootPlaybackPolicyChanged,
    );
    _networkRestoredSubscription = VioClassConnectivityService
        .instance
        .onNetworkRestored
        .listen(
          (_) => unawaited(
            TwitchMiniPlayerController.instance.recoverAfterNetworkRestored(),
          ),
        );
    _networkLostSubscription = VioClassConnectivityService
        .instance
        .onNetworkLost
        .listen(
          (_) => TwitchMiniPlayerController.instance.rememberNetworkLoss(),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      twitchAppSettingsLauncher.setNavigationReady(true);
      unawaited(
        twitchAppNotificationCenter.loadHistory(
          onLiveOpen: _openLiveNotification,
          onUpdateOpen: openUpdates,
        ),
      );
      unawaited(twitchSystemNotificationService.initialize());
      unawaited(VioClassConnectivityService.instance.start());
      unawaited(_loadLoginState());
      unawaited(chatAppearanceController.load());
      unawaited(playerSettingsController.load());
      unawaited(_loadUpdateSettingsAndCheck());
      whisperInbox.addListener(_syncAndroidBackgroundReceiving);
      _syncAndroidBackgroundReceiving();
      unawaited(TwitchAndroidBackgroundController.instance.load());
    });
  }

  @override
  void dispose() {
    authService.removeListener(_handleAuthSessionChanged);
    discoveryService.viewerSession.removeListener(_handleViewerIdentityChanged);
    _accountNotifications.stop();
    whisperInbox.removeListener(_syncAndroidBackgroundReceiving);
    unawaited(
      TwitchAndroidBackgroundController.instance.setSession(
        ownerId: null,
        foreground: false,
      ),
    );
    twitchAppSettingsLauncher.detach();
    WidgetsBinding.instance.removeObserver(this);
    playerSettingsController.removeListener(_handleRootPlaybackPolicyChanged);
    TwitchPlaybackSessionController.instance.removeListener(
      _handleRootPlaybackPolicyChanged,
    );
    TwitchMiniPlayerController.instance.removeListener(
      _handleRootPlaybackPolicyChanged,
    );
    TwitchAndroidPipController.instance.removeListener(
      _handleRootPlaybackPolicyChanged,
    );
    unawaited(TwitchAndroidPipController.instance.setAutoEnterEnabled(false));
    _channelSearchDebounce?.cancel();
    _followedLiveNotificationTimer?.cancel();
    unawaited(_networkRestoredSubscription?.cancel());
    unawaited(_networkLostSubscription?.cancel());
    searchController.dispose();
    updateController.dispose();
    whisperInbox.dispose();
    playerSettingsController.dispose();
    apiClient.close(force: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    whisperInbox.setAppForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      _syncRootAutoPip();
      if (_followedLiveNotificationTimer != null) {
        unawaited(_checkFollowedLiveNotifications());
      }
    }
  }

  void _syncAndroidBackgroundReceiving() {
    unawaited(
      TwitchAndroidBackgroundController.instance.setSession(
        ownerId: whisperInbox.ownerId,
        foreground: whisperInbox.appForeground,
      ),
    );
  }

  void _handleRootPlaybackPolicyChanged() {
    if (TwitchAndroidPipController.instance.stoppedOutsidePictureInPicture) {
      unawaited(_suspendPlaybackOutsidePictureInPicture());
    }
    _syncRootAutoPip();
    if (mounted) setState(() {});
  }

  bool get _shouldBackEnterPictureInPicture {
    if (!TwitchAndroidPipController.instance.isAndroid) return false;
    if (!playerSettingsController.androidPipEnabled) return false;
    return TwitchPlaybackSessionController.instance.playableState != null ||
        TwitchMiniPlayerController.instance.isActive;
  }

  void _handleViewerIdentityChanged() {
    if (!mounted) return;
    final identity = discoveryService.viewerSession.snapshot;
    if (discoveryService.viewerSession.status == TwitchViewerStatus.guest) {
      _accountNotifications.stop();
      twitchAppNotificationCenter.retainAccountOwner(null);
    }
    setState(() {
      _hasAuthenticatedViewer = discoveryService.viewerSession.hasAccount;
      _canReadFollows = identity?.canReadFollows == true;
      if (discoveryService.viewerSession.status == TwitchViewerStatus.guest) {
        viewerLabel = '未登入';
        loginStatus = '未登入 Twitch';
        selectedSection = TwitchHomeSection.browse;
      }
    });
  }

  void _handleAuthSessionChanged() {
    final token = authService.accessToken;
    if (!mounted || token == _observedAccessToken) return;
    _observedAccessToken = token;
    _loginStateGeneration++;
    discoveryService.clearViewerAuthCache();
    if (_loggingOut) return;
    setState(() {
      _hasAuthenticatedViewer = discoveryService.viewerSession.hasAccount;
      _canReadFollows = false;
      loadingLoginState = true;
      if (!_hasAuthenticatedViewer) {
        viewerLabel = '未登入';
        selectedSection = TwitchHomeSection.browse;
      }
    });
    unawaited(_loadLoginState(refreshPages: true, replacePending: true));
  }

  Future<void> _loadLoginState({
    bool refreshPages = false,
    bool replacePending = false,
  }) async {
    if (!mounted || _loggingOut) return;
    if (_loginStateLoadRunning && !replacePending) {
      _loginStateReloadPending = true;
      return;
    }

    final loadId = ++_loginStateLoadId;
    _loginStateLoadRunning = true;
    if (replacePending) _loginStateReloadPending = false;

    setState(() {
      loadingLoginState = true;
      loginStatus = '檢查登入狀態...';
    });

    try {
      await Future.wait<void>(<Future<void>>[
        authService.loadStoredSession(),
        dropsAuthService.loadStoredSession(),
        webGqlAuthService.loadStoredSession(),
      ]);

      final token = await authService.getValidAccessToken();
      if (!mounted || _loggingOut || loadId != _loginStateLoadId) return;
      final generation = _loginStateGeneration;
      var nextViewerLabel = '未登入';
      var nextStatus = '未登入 Twitch';
      var canReadFollows = false;
      String? notificationOwner;

      if (token != null && token.trim().isNotEmpty) {
        try {
          final validation = await discoveryService.resolveViewerAuthOrNull();
          notificationOwner = validation?.viewerId;
          nextViewerLabel = validation == null
              ? '未登入'
              : validation.viewerLogin.isEmpty
              ? '已登入'
              : '@${validation.viewerLogin}';
          final hasFollows = validation?.canReadFollows == true;
          canReadFollows = hasFollows;
          final hasChatRead = validation?.scopes.contains('chat:read') == true;
          final hasChatEdit = validation?.scopes.contains('chat:edit') == true;
          nextStatus = validation == null
              ? '未登入 Twitch'
              : hasFollows && hasChatRead && hasChatEdit
              ? '完整登入'
              : '已登入，但權限不完整';
        } catch (_) {
          nextViewerLabel = 'Token 已保存';
          nextStatus = '登入狀態待驗證';
        }
      }

      if (!mounted ||
          _loggingOut ||
          loadId != _loginStateLoadId ||
          generation != _loginStateGeneration)
        return;
      if (notificationOwner != null) {
        twitchAppNotificationCenter.retainAccountOwner(notificationOwner);
        _accountNotifications.start(notificationOwner);
      } else {
        _accountNotifications.stop();
      }
      if (nextViewerLabel != viewerLabel || !canReadFollows) {
        discoveryService.clearFollowedLiveRailCache();
        _stopFollowedLiveNotificationMonitor();
      }
      setState(() {
        _hasAuthenticatedViewer = discoveryService.viewerSession.hasAccount;
        _canReadFollows = canReadFollows;
        if (!_hasAuthenticatedViewer) {
          selectedSection = TwitchHomeSection.browse;
        } else if (!_homeSectionTouched && _canReadFollows) {
          selectedSection = TwitchHomeSection.following;
        }
        viewerLabel = nextViewerLabel;
        loginStatus = nextStatus;
        loadingLoginState = false;
        if (refreshPages) reloadTick++;
      });
      if (canReadFollows) {
        _startFollowedLiveNotificationMonitor();
      } else {
        _stopFollowedLiveNotificationMonitor();
      }
    } catch (error) {
      if (!mounted || _loggingOut || loadId != _loginStateLoadId) return;
      _accountNotifications.stop();
      setState(() {
        _hasAuthenticatedViewer = discoveryService.viewerSession.hasAccount;
        _canReadFollows = false;
        if (!_homeSectionTouched) {
          selectedSection = TwitchHomeSection.browse;
        }
        viewerLabel = _hasAuthenticatedViewer ? '登入狀態待確認' : '未登入';
        loginStatus = '登入狀態讀取失敗：$error';
        loadingLoginState = false;
        if (refreshPages) reloadTick++;
      });
    } finally {
      if (loadId == _loginStateLoadId) {
        _loginStateLoadRunning = false;
        if (mounted && !_loggingOut) {
          if (_loginStateReloadPending) {
            _loginStateReloadPending = false;
            unawaited(_loadLoginState(refreshPages: true));
          } else {
            unawaited(_refreshWhisperNotificationSession());
          }
        }
      }
    }
  }

  Future<void> _refreshWhisperNotificationSession() async {
    await whisperInbox.refreshSession();
    if (mounted && whisperInbox.ownerId != null) {
      twitchAppNotificationCenter.retainWhisperOwner(whisperInbox.ownerId);
    }
  }

  Future<void> runLinkedTwitchLoginFlow() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TwitchLinkedLoginPage(
          mainAuthService: authService,
          webGqlAuthService: webGqlAuthService,
          dropsAuthService: dropsAuthService,
          authApi: authApi,
          apiClient: apiClient,
          autoCloseOnComplete: true,
        ),
      ),
    );

    if (!mounted) return;
    await _loadLoginState(refreshPages: true);
  }

  Future<void> refreshCurrentPage() async {
    await _loadLoginState();
    if (!mounted) return;
    setState(() => reloadTick++);
  }

  Future<void> runWhisperAuthorizationFlow() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => createTwitchWhisperAuthorizationPage(
          mainAuthService: authService,
          webGqlAuthService: webGqlAuthService,
          authApi: authApi,
          apiClient: apiClient,
        ),
      ),
    );
    if (mounted) await _loadLoginState(refreshPages: true);
  }

  Future<void> logout() async {
    _loggingOut = true;
    _loginStateGeneration++;
    _loginStateReloadPending = false;
    _accountNotifications.stop();
    discoveryService.clearViewerAuthCache();
    TwitchWhisperLoginIntegrityService.instance.clear();
    await whisperInbox.flushDrafts();
    whisperInbox.clearSession();
    try {
      await Future.wait<void>(<Future<void>>[
        authService.logout(),
        dropsAuthService.logout(),
        webGqlAuthService.logout(),
      ]);
    } catch (_) {
      // Best effort.
    }

    _loggingOut = false;
    discoveryService.clearViewerAuthCache();
    if (!mounted) return;
    setState(() {
      _hasAuthenticatedViewer = false;
      loadingLoginState = false;
      _canReadFollows = false;
      _homeSectionTouched = false;
      selectedSection = TwitchHomeSection.browse;
      viewerLabel = '未登入';
      loginStatus = '已登出';
      reloadTick++;
    });
    _stopFollowedLiveNotificationMonitor();
    twitchSystemNotificationService.clearPendingPointNotifications();
    twitchAppNotificationCenter.clear();
  }

  void _startFollowedLiveNotificationMonitor() {
    if (_followedLiveNotificationTimer != null) return;
    _followedLiveNotificationTimer = Timer.periodic(
      _followedLivePollInterval,
      (_) => unawaited(_checkFollowedLiveNotifications()),
    );
    unawaited(_checkFollowedLiveNotifications());
  }

  void _stopFollowedLiveNotificationMonitor() {
    _followedLiveNotificationTimer?.cancel();
    _followedLiveNotificationTimer = null;
    _liveNotificationPolicy.reset();
  }

  Future<void> _checkFollowedLiveNotifications() async {
    if (_checkingFollowedLiveNotifications) return;
    _checkingFollowedLiveNotifications = true;
    final monitor = _followedLiveNotificationTimer;

    try {
      final streams = <TwitchLiveStream>[];
      final cursors = <String>{};
      String? cursor;
      do {
        final page = await discoveryService.fetchFollowedStreams(
          first: 100,
          after: cursor,
        );
        if (!mounted ||
            monitor == null ||
            _followedLiveNotificationTimer != monitor) {
          return;
        }
        streams.addAll(page.streams);
        cursor = page.cursor;
        if (cursor != null && cursor.isNotEmpty && !cursors.add(cursor)) {
          throw StateError('Repeated followed-live cursor');
        }
      } while (cursor != null && cursor.isNotEmpty);
      if (!mounted || _followedLiveNotificationTimer != monitor) {
        return;
      }
      var newlyLive = _liveNotificationPolicy.observe(streams);
      if (newlyLive.isEmpty) return;
      newlyLive = await discoveryService.attachNotificationProfiles(newlyLive);
      if (!mounted || _followedLiveNotificationTimer != monitor) return;

      if (newlyLive.length > 3) {
        await twitchSystemNotificationService.showMultipleStreamsLive(
          newlyLive,
        );
      } else {
        for (final stream in newlyLive) {
          await twitchSystemNotificationService.showStreamLive(
            stream,
            onOpen: () => _openLiveNotification(stream),
          );
        }
      }
    } catch (_) {
      // Login, network and Twitch API failures are retried on the next poll.
    } finally {
      _checkingFollowedLiveNotifications = false;
    }
  }

  Future<void> _openLiveNotification(TwitchLiveStream stream) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TwitchWatchRouteGuard(
          initialMetadata: TwitchStreamHeaderMetadata.fromLiveStream(stream),
          initialDiscoveryService: discoveryService,
          initialKnownFollowing: true,
        ),
      ),
    );
  }

  Future<void> openDropsConnectorPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TwitchDropsConnectionPage(
          apiClient: apiClient,
          authService: authService,
          authApi: authApi,
          dropsAuthService: dropsAuthService,
        ),
      ),
    );
  }

  Future<void> openSettings() async {
    if (_settingsSheetOpen) {
      await Navigator.of(context).maybePop();
      return;
    }

    _settingsSheetOpen = true;
    try {
      await showTwitchAppSettingsSheet(
        context: context,
        chatAppearanceController: chatAppearanceController,
        playerSettingsController: playerSettingsController,
        updateController: updateController,
        viewerLabel: () => viewerLabel,
        loginStatus: () => loginStatus,
        loadingLoginState: () => loadingLoginState,
        onLogin: runLinkedTwitchLoginFlow,
        onRefreshLogin: () => _loadLoginState(refreshPages: true),
        onLogout: logout,
      );
    } finally {
      _settingsSheetOpen = false;
    }
  }

  bool _updateSheetOpen = false;
  bool _whisperSheetOpen = false;

  Future<void> openWhispers() async {
    if (!mounted || !_hasAuthenticatedViewer || _whisperSheetOpen) return;
    _whisperSheetOpen = true;
    try {
      await showTwitchWhisperSheet(
        context: context,
        controller: whisperInbox,
        onAuthorize: runWhisperAuthorizationFlow,
      );
    } finally {
      _whisperSheetOpen = false;
    }
  }

  Future<void> openUpdates() async {
    if (_updateSheetOpen || !mounted) return;
    _updateSheetOpen = true;
    try {
      await showVioClassUpdateSheet(
        context: context,
        controller: updateController,
      );
    } finally {
      _updateSheetOpen = false;
    }
  }

  void selectSection(TwitchHomeSection section) {
    if (selectedSection == section) {
      _homeSectionTouched = true;
      return;
    }
    setState(() {
      _homeSectionTouched = true;
      selectedSection = section;
    });
  }

  void showCurrentGameMenu() {
    if (searchText.isEmpty) {
      if (selectedSection == TwitchHomeSection.following) {
        followingPageKey.currentState?.showGameMenu(context);
        return;
      }
      browsePageKey.currentState?.showGameMenu(context);
      return;
    }

    _channelSearchDebounce?.cancel();
    searchController.clear();
    setState(() {
      searchText = '';
      _channelSearchGeneration++;
      searchedLiveStreams = const <TwitchLiveStream>[];
      searchedOfflineChannels = const <TwitchFollowedChannel>[];
      searchedVideos = const <_TwitchSearchVideoResult>[];
      searchedClips = const <_TwitchSearchClipResult>[];
      loadingChannelSearch = false;
      channelSearchError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (selectedSection == TwitchHomeSection.following) {
        followingPageKey.currentState?.showGameMenu(context);
      } else {
        browsePageKey.currentState?.showGameMenu(context);
      }
    });
  }

  void showCurrentLanguageMenu() {
    if (searchText.isEmpty) {
      if (selectedSection == TwitchHomeSection.following) {
        followingPageKey.currentState?.showLanguageMenu(context);
        return;
      }
      browsePageKey.currentState?.showLanguageMenu(context);
      return;
    }

    _channelSearchDebounce?.cancel();
    searchController.clear();
    setState(() {
      searchText = '';
      _channelSearchGeneration++;
      searchedLiveStreams = const <TwitchLiveStream>[];
      searchedOfflineChannels = const <TwitchFollowedChannel>[];
      searchedVideos = const <_TwitchSearchVideoResult>[];
      searchedClips = const <_TwitchSearchClipResult>[];
      loadingChannelSearch = false;
      channelSearchError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (selectedSection == TwitchHomeSection.following) {
        followingPageKey.currentState?.showLanguageMenu(context);
      } else {
        browsePageKey.currentState?.showLanguageMenu(context);
      }
    });
  }

  void updateSearchText(String value) {
    final keyword = value.trim().toLowerCase();
    if (searchText == keyword) return;

    _channelSearchDebounce?.cancel();
    setState(() {
      searchText = keyword;
      if (keyword.isEmpty) {
        _channelSearchGeneration++;
        searchedLiveStreams = const <TwitchLiveStream>[];
        searchedOfflineChannels = const <TwitchFollowedChannel>[];
        searchedVideos = const <_TwitchSearchVideoResult>[];
        searchedClips = const <_TwitchSearchClipResult>[];
        loadingChannelSearch = false;
        channelSearchError = null;
      } else {
        searchedLiveStreams = const <TwitchLiveStream>[];
        searchedOfflineChannels = const <TwitchFollowedChannel>[];
        searchedVideos = const <_TwitchSearchVideoResult>[];
        searchedClips = const <_TwitchSearchClipResult>[];
        loadingChannelSearch = true;
        channelSearchError = null;
      }
    });

    if (keyword.isEmpty) return;

    final generation = ++_channelSearchGeneration;
    _channelSearchDebounce = Timer(const Duration(milliseconds: 360), () {
      unawaited(searchChannels(keyword, generation));
    });
  }

  Future<void> searchChannels(String keyword, int generation) async {
    try {
      final result = await discoveryService.searchChannels(query: keyword);
      if (!mounted || generation != _channelSearchGeneration) return;
      final media = await _searchChannelMedia(
        generation: generation,
        keyword: keyword,
        liveStreams: result.liveStreams,
        offlineChannels: result.offlineChannels,
      );
      if (!mounted || generation != _channelSearchGeneration) return;

      setState(() {
        searchedLiveStreams = result.liveStreams;
        searchedOfflineChannels = result.offlineChannels;
        searchedVideos = media.videos;
        searchedClips = media.clips;
        loadingChannelSearch = false;
        channelSearchError = null;
      });
    } catch (error) {
      if (!mounted || generation != _channelSearchGeneration) return;

      setState(() {
        searchedLiveStreams = const <TwitchLiveStream>[];
        searchedOfflineChannels = const <TwitchFollowedChannel>[];
        searchedVideos = const <_TwitchSearchVideoResult>[];
        searchedClips = const <_TwitchSearchClipResult>[];
        loadingChannelSearch = false;
        channelSearchError = error.toString();
      });
    }
  }

  Future<void> refreshChannelSearch() async {
    final keyword = searchText.trim().toLowerCase();
    if (keyword.isEmpty) return;

    _channelSearchDebounce?.cancel();
    final generation = ++_channelSearchGeneration;
    setState(() {
      loadingChannelSearch = true;
      channelSearchError = null;
    });
    await searchChannels(keyword, generation);
  }

  void rememberFollowedChannels(
    List<TwitchLiveStream> liveStreams,
    List<TwitchFollowedChannel> offlineChannels,
  ) {
    final ids = <String>{
      ...followedUserIds,
      ...liveStreams.map((stream) => stream.userId.trim()),
      ...offlineChannels.map((channel) => channel.broadcasterId.trim()),
    }.where((id) => id.isNotEmpty).toSet();
    final logins = <String>{
      ...followedLogins,
      ...liveStreams.map((stream) => stream.channelLogin),
      ...offlineChannels.map((channel) => channel.channelLogin),
    }.where((login) => login.isNotEmpty).toSet();
    if (_setEquals(followedUserIds, ids) &&
        _setEquals(followedLogins, logins)) {
      return;
    }
    setState(() {
      followedUserIds = ids;
      followedLogins = logins;
    });
  }

  bool? knownFollowStatusFor({
    String? broadcasterId,
    String? broadcasterLogin,
  }) {
    final id = broadcasterId?.trim() ?? '';
    final login = broadcasterLogin?.trim().toLowerCase() ?? '';
    if (id.isNotEmpty && followedUserIds.contains(id)) return true;
    if (login.isNotEmpty && followedLogins.contains(login)) return true;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_shouldBackEnterPictureInPicture,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_enterPictureInPictureFromRootBack());
      },
      child: Scaffold(
        backgroundColor: _kBackground,
        body: AnimatedBuilder(
          animation: playerSettingsController,
          builder: (context, _) {
            return Stack(
              children: <Widget>[
                ColoredBox(
                  color: TwitchUiColors.appBackground,
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final layout = TwitchResponsiveLayout.fromConstraints(
                          constraints,
                        );
                        return TwitchFollowedLiveRailShell(
                          key: ValueKey('home-live-rail:$viewerLabel'),
                          enabled: _canReadFollows,
                          loadStreams:
                              discoveryService.fetchFollowedLiveRailStreams,
                          initialStreams:
                              discoveryService.cachedFollowedLiveRailStreams,
                          onSelect: (stream) async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => TwitchWatchRouteGuard(
                                  initialMetadata:
                                      TwitchStreamHeaderMetadata.fromLiveStream(
                                        stream,
                                      ),
                                  initialDiscoveryService: discoveryService,
                                  initialKnownFollowing: true,
                                ),
                              ),
                            );
                          },
                          child: layout.shouldUseBottomHomeNavigation
                              ? _buildMobileShell(layout)
                              : _buildDesktopShell(layout),
                        );
                      },
                    ),
                  ),
                ),
                TwitchMiniPlayerOverlay(
                  controller: TwitchMiniPlayerController.instance,
                  discoveryService: discoveryService,
                  androidPipEnabled: playerSettingsController.androidPipEnabled,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
