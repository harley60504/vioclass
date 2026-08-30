import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../models/discovery/twitch_live_stream.dart';
import '../../models/discovery/twitch_stream_header_metadata.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../../services/discovery/twitch_discovery_service.dart';
import '../settings/twitch_chat_appearance_controller.dart';
import '../settings/twitch_player_settings_controller.dart';
import '../settings/vioclass_update_controller.dart';
import '../mini_player/twitch_mini_player_controller.dart';
import '../mini_player/twitch_mini_player_overlay.dart';
import '../sheets/twitch_app_settings_sheet.dart';
import '../theme/twitch_ui_tokens.dart';
import '../twitch_follow_status_resolver.dart';
import '../widgets/discovery/twitch_discovery_stream_template.dart';
import '../widgets/discovery/twitch_offline_channel_card.dart';
import '../widgets/home/twitch_stream_home_bottom_nav.dart';
import '../widgets/home/twitch_stream_home_sidebar.dart';
import '../widgets/home/twitch_stream_home_toolbar.dart';
import '../widgets/responsive/twitch_responsive_layout.dart';
import '../widgets/shared/twitch_cached_image_layer.dart';
import 'twitch_browse_page.dart';
import 'twitch_drops_connection_page.dart';
import 'twitch_following_page.dart';
import 'twitch_linked_login_page.dart';
import 'twitch_stream_home_models.dart';
import 'twitch_watch_route_guard.dart';

const Color _kBackground = Color(0xFF0A0A0F);

class TwitchStreamPage extends StatefulWidget {
  const TwitchStreamPage({super.key});

  @override
  State<TwitchStreamPage> createState() => _TwitchStreamPageState();
}

class _TwitchStreamPageState extends State<TwitchStreamPage> {
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

  @override
  void initState() {
    super.initState();

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadLoginState());
      unawaited(chatAppearanceController.load());
      unawaited(playerSettingsController.load());
      unawaited(_loadUpdateSettingsAndCheck());
    });
  }

  @override
  void dispose() {
    _channelSearchDebounce?.cancel();
    searchController.dispose();
    updateController.dispose();
    playerSettingsController.dispose();
    apiClient.close(force: true);
    super.dispose();
  }

  Future<void> _loadUpdateSettingsAndCheck() async {
    await updateController.load();
    if (!mounted || !updateController.autoCheckEnabled) return;
    final info = await updateController.checkNow();
    if (!mounted || info?.updateAvailable != true) return;
    unawaited(
      showVioClassUpdateSheet(
        context: context,
        controller: updateController,
        startupPrompt: true,
      ),
    );
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
      final media = await _searchChannelMedia(
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

  Future<_TwitchSearchMediaBundle> _searchChannelMedia({
    required String keyword,
    required List<TwitchLiveStream> liveStreams,
    required List<TwitchFollowedChannel> offlineChannels,
  }) async {
    final cleanKeyword = keyword.trim().toLowerCase();
    if (cleanKeyword.isEmpty) return const _TwitchSearchMediaBundle.empty();

    final candidates = _searchMediaCandidateChannels(
      liveStreams: liveStreams,
      offlineChannels: offlineChannels,
    );
    if (candidates.isEmpty) return const _TwitchSearchMediaBundle.empty();

    final videoResults = <_TwitchSearchVideoResult>[];
    final clipResults = <_TwitchSearchClipResult>[];

    for (final channel in candidates.take(8)) {
      if (videoResults.length < 12) {
        try {
          final page = await discoveryService.fetchChannelVideos(
            userId: channel.broadcasterId,
            first: 8,
          );
          videoResults.addAll(
            page.videos
                .where((video) => _matchesSearchMediaVideo(video, cleanKeyword))
                .take(4)
                .map(
                  (video) =>
                      _TwitchSearchVideoResult(channel: channel, video: video),
                ),
          );
        } catch (_) {}
      }

      if (clipResults.length < 12) {
        try {
          final page = await discoveryService.fetchChannelClips(
            broadcasterId: channel.broadcasterId,
            first: 8,
          );
          clipResults.addAll(
            page.clips
                .where((clip) => _matchesSearchMediaClip(clip, cleanKeyword))
                .take(4)
                .map(
                  (clip) =>
                      _TwitchSearchClipResult(channel: channel, clip: clip),
                ),
          );
        } catch (_) {}
      }

      if (videoResults.length >= 12 && clipResults.length >= 12) break;
    }

    return _TwitchSearchMediaBundle(
      videos: videoResults.take(12).toList(growable: false),
      clips: clipResults.take(12).toList(growable: false),
    );
  }

  List<TwitchFollowedChannel> _searchMediaCandidateChannels({
    required List<TwitchLiveStream> liveStreams,
    required List<TwitchFollowedChannel> offlineChannels,
  }) {
    final byId = <String, TwitchFollowedChannel>{};

    for (final channel in offlineChannels) {
      final id = channel.broadcasterId.trim();
      if (id.isEmpty) continue;
      byId[id] = channel;
    }

    for (final stream in liveStreams) {
      final id = stream.userId.trim();
      if (id.isEmpty || byId.containsKey(id)) continue;
      byId[id] = TwitchFollowedChannel(
        broadcasterId: id,
        broadcasterLogin: stream.channelLogin,
        broadcasterName: stream.displayName,
        followedAt: null,
        profileImageUrl: stream.profileImageUrl,
        description: stream.title,
      );
    }

    return byId.values.toList(growable: false);
  }

  bool _matchesSearchMediaVideo(TwitchChannelVideo video, String keyword) {
    return video.title.toLowerCase().contains(keyword) ||
        video.userName.toLowerCase().contains(keyword);
  }

  bool _matchesSearchMediaClip(TwitchChannelClip clip, String keyword) {
    return clip.title.toLowerCase().contains(keyword) ||
        clip.broadcasterName.toLowerCase().contains(keyword) ||
        clip.creatorName.toLowerCase().contains(keyword);
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

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
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
    return Scaffold(
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
                          ? _buildMobileShell(layout)
                          : _buildDesktopShell(layout);
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
    );
  }

  Widget _buildDesktopShell(TwitchResponsiveLayout layout) {
    return Row(
      children: <Widget>[
        TwitchStreamHomeSidebar(
          selectedSection: selectedSection,
          viewerLabel: viewerLabel,
          loginStatus: loginStatus,
          loadingLoginState: loadingLoginState,
          onSelectSection: selectSection,
        ),
        Expanded(child: _buildContentColumn(layout)),
      ],
    );
  }

  Widget _buildMobileShell(TwitchResponsiveLayout layout) {
    return Column(
      children: <Widget>[
        Expanded(child: _buildContentColumn(layout)),
        TwitchStreamHomeBottomNavigation(
          selectedSection: selectedSection,
          onSelectSection: selectSection,
        ),
      ],
    );
  }

  Widget _buildContentColumn(TwitchResponsiveLayout layout) {
    return Column(
      children: <Widget>[
        TwitchStreamHomeToolbar(
          selectedSection: selectedSection,
          searchController: searchController,
          forceTwoRows: layout.shouldUseTwoRowHomeToolbar,
          onSearchChanged: updateSearchText,
          onClearSearch: () {
            searchController.clear();
            updateSearchText('');
          },
          onShowGameMenu: showCurrentGameMenu,
          onShowLanguageMenu: showCurrentLanguageMenu,
          onRefresh: refreshCurrentPage,
          onOpenDropsConnector: openDropsConnectorPage,
          onOpenSettings: openSettings,
        ),
        Expanded(child: _buildHomeContent()),
      ],
    );
  }

  Widget _buildHomeContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: searchText.isNotEmpty
          ? _TwitchChannelSearchPage(
              key: const ValueKey<String>('twitch-channel-search-page'),
              query: searchText,
              liveStreams: searchedLiveStreams,
              offlineChannels: searchedOfflineChannels,
              videos: searchedVideos,
              clips: searchedClips,
              followStatusFor: knownFollowStatusFor,
              loading: loadingChannelSearch,
              errorText: channelSearchError,
              discoveryService: discoveryService,
              onRefresh: refreshChannelSearch,
            )
          : selectedSection == TwitchHomeSection.following
          ? TwitchFollowingPage(
              key: followingPageKey,
              discoveryService: discoveryService,
              searchText: searchText,
              searchedLiveStreams: searchedLiveStreams,
              searchedOfflineChannels: searchedOfflineChannels,
              loadingChannelSearch: loadingChannelSearch,
              channelSearchError: channelSearchError,
              reloadTick: reloadTick,
              onLoginPressed: runLinkedTwitchLoginFlow,
              onFollowedChannelsChanged: rememberFollowedChannels,
              followStatusFor: knownFollowStatusFor,
            )
          : TwitchBrowsePage(
              key: browsePageKey,
              discoveryService: discoveryService,
              searchText: searchText,
              searchedLiveStreams: searchedLiveStreams,
              searchedOfflineChannels: searchedOfflineChannels,
              loadingChannelSearch: loadingChannelSearch,
              channelSearchError: channelSearchError,
              reloadTick: reloadTick,
              onLoginPressed: runLinkedTwitchLoginFlow,
              followStatusFor: knownFollowStatusFor,
            ),
    );
  }
}

class _TwitchChannelSearchPage extends StatelessWidget {
  final String query;
  final List<TwitchLiveStream> liveStreams;
  final List<TwitchFollowedChannel> offlineChannels;
  final List<_TwitchSearchVideoResult> videos;
  final List<_TwitchSearchClipResult> clips;
  final TwitchFollowStatusResolver followStatusFor;
  final bool loading;
  final String? errorText;
  final TwitchDiscoveryService discoveryService;
  final Future<void> Function() onRefresh;

  const _TwitchChannelSearchPage({
    super.key,
    required this.query,
    required this.liveStreams,
    required this.offlineChannels,
    required this.videos,
    required this.clips,
    required this.followStatusFor,
    required this.loading,
    required this.errorText,
    required this.discoveryService,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final hasResults =
        liveStreams.isNotEmpty ||
        offlineChannels.isNotEmpty ||
        videos.isNotEmpty ||
        clips.isNotEmpty;
    final followedLiveStreams = liveStreams
        .where(_isFollowedStream)
        .toList(growable: false);
    final otherLiveStreams = liveStreams
        .where((stream) => !_isFollowedStream(stream))
        .toList(growable: false);
    final followedOfflineChannels = offlineChannels
        .where(_isFollowedChannel)
        .toList(growable: false);
    final otherOfflineChannels = offlineChannels
        .where((channel) => !_isFollowedChannel(channel))
        .toList(growable: false);
    final followedCount =
        followedLiveStreams.length + followedOfflineChannels.length;

    if (!loading && !hasResults) {
      return TwitchDiscoveryEmptyState(
        icon: Icons.search_off_rounded,
        title: '找不到符合條件的頻道',
        message: errorText?.trim().isNotEmpty == true
            ? 'Twitch 頻道搜尋暫時失敗，稍後再試。'
            : '可以換個實況主名稱或登入名稱搜尋。',
        onRetry: onRefresh,
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.72, -0.92),
          radius: 1.35,
          colors: <Color>[
            Color(0xFF24133A),
            Color(0xFF14121E),
            Color(0xFF0A0A0F),
          ],
          stops: <double>[0.0, 0.46, 1.0],
        ),
      ),
      child: RefreshIndicator(
        color: TwitchUiColors.primary,
        onRefresh: onRefresh,
        child: CustomScrollView(
          key: const PageStorageKey<String>('twitch_channel_search_page'),
          physics: const AlwaysScrollableScrollPhysics(),
          cacheExtent: 840,
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: TwitchDiscoverySectionHeader(
                icon: Icons.search_rounded,
                title: '搜尋結果',
                count:
                    liveStreams.length +
                    offlineChannels.length +
                    videos.length +
                    clips.length,
              ),
            ),
            if (loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(26, 0, 26, 20),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: TwitchUiColors.primary,
                          strokeWidth: 2.4,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        '正在搜尋...',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (followedCount > 0) ...[
              if (followedLiveStreams.isNotEmpty)
                TwitchDiscoveryStreamSliverSection(
                  icon: Icons.favorite_rounded,
                  title: '已追隨 · 直播中',
                  streams: followedLiveStreams,
                  discoveryService: discoveryService,
                  onReturnFromStream: onRefresh,
                  followStatusFor: followStatusFor,
                  streamKnownFollowing: true,
                ),
              if (followedOfflineChannels.isNotEmpty)
                ..._offlineChannelSlivers(
                  icon: Icons.favorite_border_rounded,
                  title: '已追隨 · 未開台',
                  channels: followedOfflineChannels,
                  knownFollowing: true,
                ),
            ],
            if (otherLiveStreams.isNotEmpty)
              TwitchDiscoveryStreamSliverSection(
                icon: Icons.live_tv_rounded,
                title: '其他頻道 · 直播中',
                streams: otherLiveStreams,
                discoveryService: discoveryService,
                onReturnFromStream: onRefresh,
                followStatusFor: followStatusFor,
              ),
            if (otherOfflineChannels.isNotEmpty)
              ..._offlineChannelSlivers(
                icon: Icons.tv_off_rounded,
                title: '其他頻道 · 未開台',
                channels: otherOfflineChannels,
              ),
            if (videos.isNotEmpty)
              _mediaSliverSection<_TwitchSearchVideoResult>(
                icon: Icons.video_library_outlined,
                title: '影片',
                items: videos,
                itemBuilder: (context, result) {
                  return _SearchVodCard(
                    discoveryService: discoveryService,
                    result: result,
                    followStatusFor: followStatusFor,
                  );
                },
              ),
            if (clips.isNotEmpty)
              _mediaSliverSection<_TwitchSearchClipResult>(
                icon: Icons.movie_filter_outlined,
                title: '片段',
                items: clips,
                itemBuilder: (context, result) {
                  return _SearchClipCard(
                    discoveryService: discoveryService,
                    result: result,
                    followStatusFor: followStatusFor,
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  bool _isFollowedStream(TwitchLiveStream stream) {
    final id = stream.userId.trim();
    final login = stream.channelLogin;
    return followStatusFor(broadcasterId: id, broadcasterLogin: login) == true;
  }

  bool _isFollowedChannel(TwitchFollowedChannel channel) {
    final id = channel.broadcasterId.trim();
    final login = channel.channelLogin;
    return followStatusFor(broadcasterId: id, broadcasterLogin: login) == true;
  }

  List<Widget> _offlineChannelSlivers({
    required IconData icon,
    required String title,
    required List<TwitchFollowedChannel> channels,
    bool? knownFollowing,
  }) {
    return <Widget>[
      SliverToBoxAdapter(
        child: TwitchDiscoverySectionHeader(
          icon: icon,
          title: title,
          count: channels.length,
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            mainAxisExtent: 168,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            return TwitchOfflineChannelCard(
              channel: channels[index],
              discoveryService: discoveryService,
              initialKnownFollowing:
                  knownFollowing ??
                  followStatusFor(
                    broadcasterId: channels[index].broadcasterId,
                    broadcasterLogin: channels[index].channelLogin,
                  ),
            );
          }, childCount: channels.length),
        ),
      ),
    ];
  }

  Widget _mediaSliverSection<T>({
    required IconData icon,
    required String title,
    required List<T> items,
    required Widget Function(BuildContext context, T item) itemBuilder,
  }) {
    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: TwitchDiscoverySectionHeader(
            icon: icon,
            title: title,
            count: items.length,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 340,
              mainAxisExtent: 238,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              return itemBuilder(context, items[index]);
            }, childCount: items.length),
          ),
        ),
      ],
    );
  }
}

class _TwitchSearchMediaBundle {
  final List<_TwitchSearchVideoResult> videos;
  final List<_TwitchSearchClipResult> clips;

  const _TwitchSearchMediaBundle({required this.videos, required this.clips});

  const _TwitchSearchMediaBundle.empty()
    : videos = const <_TwitchSearchVideoResult>[],
      clips = const <_TwitchSearchClipResult>[];
}

class _TwitchSearchVideoResult {
  final TwitchFollowedChannel channel;
  final TwitchChannelVideo video;

  const _TwitchSearchVideoResult({required this.channel, required this.video});
}

class _TwitchSearchClipResult {
  final TwitchFollowedChannel channel;
  final TwitchChannelClip clip;

  const _TwitchSearchClipResult({required this.channel, required this.clip});
}

class _SearchVodCard extends StatelessWidget {
  final TwitchDiscoveryService discoveryService;
  final _TwitchSearchVideoResult result;
  final TwitchFollowStatusResolver followStatusFor;

  const _SearchVodCard({
    required this.discoveryService,
    required this.result,
    required this.followStatusFor,
  });

  @override
  Widget build(BuildContext context) {
    final video = result.video;
    final channel = result.channel;
    final isGrowingArchive = video.isLikelyGrowingArchive;

    return _SearchMediaCardFrame(
      thumbnailUrl: video.thumbnail(),
      fallbackIcon: Icons.video_library_outlined,
      topLeftPill: isGrowingArchive ? '直播存檔中' : 'VOD',
      bottomRightPill: video.duration,
      title: video.title.trim().isEmpty ? '未命名 VOD' : video.title,
      subtitle: '${channel.displayName} · ${_formatCount(video.viewCount)} 次觀看',
      avatarUrl: channel.profileImageUrl,
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => TwitchWatchRouteGuard(
              initialMetadata: TwitchStreamHeaderMetadata(
                channelLogin: channel.channelLogin,
                streamTitle: video.title,
                language: video.language,
                profileImageUrl: channel.profileImageUrl,
              ),
              initialOfflineChannel: channel,
              initialDiscoveryService: discoveryService,
              initialActiveDvrVideo: isGrowingArchive ? video : null,
              initialVodVideo: isGrowingArchive ? null : video,
              initialVodPlaybackOnly: !isGrowingArchive,
              initialKnownFollowing: followStatusFor(
                broadcasterId: channel.broadcasterId,
                broadcasterLogin: channel.channelLogin,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchClipCard extends StatelessWidget {
  final TwitchDiscoveryService discoveryService;
  final _TwitchSearchClipResult result;
  final TwitchFollowStatusResolver followStatusFor;

  const _SearchClipCard({
    required this.discoveryService,
    required this.result,
    required this.followStatusFor,
  });

  @override
  Widget build(BuildContext context) {
    final clip = result.clip;
    final channel = result.channel;

    return _SearchMediaCardFrame(
      thumbnailUrl: clip.thumbnailUrl,
      fallbackIcon: Icons.movie_filter_outlined,
      topLeftPill: '片段',
      bottomRightPill: '${clip.duration.toStringAsFixed(1)}s',
      title: clip.title.trim().isEmpty ? '未命名片段' : clip.title,
      subtitle: '${channel.displayName} · ${_formatCount(clip.viewCount)} 次觀看',
      avatarUrl: channel.profileImageUrl,
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => TwitchWatchRouteGuard(
              initialMetadata: TwitchStreamHeaderMetadata(
                channelLogin: channel.channelLogin,
                streamTitle: clip.title,
                language: clip.language,
                profileImageUrl: channel.profileImageUrl,
              ),
              initialOfflineChannel: channel,
              initialDiscoveryService: discoveryService,
              initialClip: clip,
              initialKnownFollowing: followStatusFor(
                broadcasterId: channel.broadcasterId,
                broadcasterLogin: channel.channelLogin,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchMediaCardFrame extends StatelessWidget {
  final String thumbnailUrl;
  final IconData fallbackIcon;
  final String topLeftPill;
  final String bottomRightPill;
  final String title;
  final String subtitle;
  final String avatarUrl;
  final VoidCallback onTap;

  const _SearchMediaCardFrame({
    required this.thumbnailUrl,
    required this.fallbackIcon,
    required this.topLeftPill,
    required this.bottomRightPill,
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.062),
                Colors.white.withValues(alpha: 0.022),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return TwitchCachedImageLayer(
                          imageUrl: thumbnailUrl,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          fit: BoxFit.cover,
                          fallbackColor: Colors.white.withValues(alpha: 0.06),
                          fallbackIcon: fallbackIcon,
                          fallbackIconColor: Colors.white38,
                        );
                      },
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _SearchMediaPill(text: topLeftPill),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: _SearchMediaPill(text: bottomRightPill),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 74,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          height: 1.14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: <Widget>[
                          TwitchCachedImageLayer.avatar(
                            imageUrl: avatarUrl,
                            size: 20,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchMediaPill extends StatelessWidget {
  final String text;

  const _SearchMediaPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

String _formatCount(int value) {
  if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)}萬';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}
