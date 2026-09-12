part of '../twitch_stream_page.dart';

const Color _kBackground = Color(0xFF0A0A0F);

class TwitchStreamPage extends StatefulWidget {
  const TwitchStreamPage({super.key});

  @override
  State<TwitchStreamPage> createState() => _TwitchStreamPageState();
}

class _TwitchStreamPageState extends State<TwitchStreamPage>
    with WidgetsBindingObserver {
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

  TwitchHomeSection selectedSection = TwitchHomeSection.following;

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
  bool loadingChannelSearch = false;
  bool _loginStateLoadRunning = false;
  int _channelSearchGeneration = 0;
  Timer? _channelSearchDebounce;
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

    apiClient = TwitchApiClient();
    authService = TwitchAuthService(apiClient: apiClient);
    dropsAuthService = TwitchDropsAuthService(apiClient: apiClient);
    webGqlAuthService = TwitchWebGqlAuthService(apiClient: apiClient);
    authApi = TwitchAuthApiService(client: apiClient);
    discoveryService = TwitchDiscoveryService(
      client: apiClient,
      authService: authService,
      authApi: authApi,
      webTokenProvider: webGqlAuthService.getToken,
    );
    chatAppearanceController = twitchChatAppearanceController;
    playerSettingsController = TwitchPlayerSettingsController();
    updateController = VioClassUpdateController();
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
      unawaited(VioClassConnectivityService.instance.start());
      unawaited(_loadLoginState());
      unawaited(chatAppearanceController.load());
      unawaited(playerSettingsController.load());
      unawaited(this._loadUpdateSettingsAndCheck());
    });
  }

  @override
  void dispose() {
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
    unawaited(_networkRestoredSubscription?.cancel());
    unawaited(_networkLostSubscription?.cancel());
    searchController.dispose();
    updateController.dispose();
    playerSettingsController.dispose();
    apiClient.close(force: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      this._syncRootAutoPip();
    }
  }

  void _handleRootPlaybackPolicyChanged() {
    if (TwitchAndroidPipController.instance.stoppedOutsidePictureInPicture) {
      unawaited(this._suspendPlaybackOutsidePictureInPicture());
    }
    this._syncRootAutoPip();
    if (mounted) setState(() {});
  }

  bool get _shouldBackEnterPictureInPicture {
    if (!TwitchAndroidPipController.instance.isAndroid) return false;
    if (!playerSettingsController.androidPipEnabled) return false;
    return TwitchPlaybackSessionController.instance.playableState != null ||
        TwitchMiniPlayerController.instance.isActive;
  }

  Future<void> _loadLoginState({bool refreshPages = false}) async {
    if (!mounted || _loginStateLoadRunning) return;

    _loginStateLoadRunning = true;

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
      var nextViewerLabel = '未登入';
      var nextStatus = '未登入 Twitch';

      if (token != null && token.trim().isNotEmpty) {
        try {
          final validation = await authApi.validateToken(token);
          nextViewerLabel = validation.login.isEmpty
              ? '已登入'
              : '@${validation.login}';
          final hasFollows = validation.scopes.contains('user:read:follows');
          final hasChatRead = validation.scopes.contains('chat:read');
          final hasChatEdit = validation.scopes.contains('chat:edit');
          nextStatus = hasFollows && hasChatRead && hasChatEdit
              ? '完整登入'
              : '已登入，但權限不完整';
        } catch (_) {
          nextViewerLabel = 'Token 已保存';
          nextStatus = '登入狀態待驗證';
        }
      }

      if (!mounted) return;
      setState(() {
        viewerLabel = nextViewerLabel;
        loginStatus = nextStatus;
        loadingLoginState = false;
        if (refreshPages) reloadTick++;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        viewerLabel = '未登入';
        loginStatus = '登入狀態讀取失敗：$error';
        loadingLoginState = false;
        if (refreshPages) reloadTick++;
      });
    } finally {
      _loginStateLoadRunning = false;
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

  Future<void> logout() async {
    try {
      await Future.wait<void>(<Future<void>>[
        authService.logout(),
        dropsAuthService.logout(),
        webGqlAuthService.logout(),
      ]);
    } catch (_) {
      // Best effort.
    }

    if (!mounted) return;
    setState(() {
      viewerLabel = '未登入';
      loginStatus = '已登出';
      reloadTick++;
    });
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

  Future<void> openSettings() {
    return showTwitchAppSettingsSheet(
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
  }

  void selectSection(TwitchHomeSection section) {
    if (selectedSection == section) return;
    setState(() => selectedSection = section);
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
      final media = await this._searchChannelMedia(
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
    if (this._setEquals(followedUserIds, ids) &&
        this._setEquals(followedLogins, logins)) {
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
        unawaited(this._enterPictureInPictureFromRootBack());
      },
      child: Scaffold(
        backgroundColor: _kBackground,
        body: AnimatedBuilder(
          animation: playerSettingsController,
          builder: (context, _) {
            return Stack(
              children: <Widget>[
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xFF25113C),
                        Color(0xFF11111A),
                        Color(0xFF07070B),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final layout = TwitchResponsiveLayout.fromConstraints(
                          constraints,
                        );
                        return layout.shouldUseBottomHomeNavigation
                            ? this._buildMobileShell(layout)
                            : this._buildDesktopShell(layout);
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
