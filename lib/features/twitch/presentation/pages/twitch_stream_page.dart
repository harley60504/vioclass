import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../models/discovery/twitch_live_stream.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../../services/discovery/twitch_discovery_service.dart';
import '../settings/twitch_chat_appearance_controller.dart';
import '../settings/twitch_player_settings_controller.dart';
import '../mini_player/twitch_mini_player_controller.dart';
import '../mini_player/twitch_mini_player_overlay.dart';
import '../sheets/twitch_app_settings_sheet.dart';
import '../theme/twitch_ui_tokens.dart';
import '../widgets/discovery/twitch_discovery_stream_template.dart';
import '../widgets/discovery/twitch_offline_channel_card.dart';
import '../widgets/home/twitch_stream_home_bottom_nav.dart';
import '../widgets/home/twitch_stream_home_sidebar.dart';
import '../widgets/home/twitch_stream_home_toolbar.dart';
import '../widgets/responsive/twitch_responsive_layout.dart';
import 'twitch_browse_page.dart';
import 'twitch_drops_connection_page.dart';
import 'twitch_following_page.dart';
import 'twitch_linked_login_page.dart';
import 'twitch_stream_home_models.dart';

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

  TwitchHomeSection selectedSection = TwitchHomeSection.following;

  String searchText = '';
  String loginStatus = '檢查登入狀態...';
  String viewerLabel = '未登入';
  List<TwitchLiveStream> searchedLiveStreams = const <TwitchLiveStream>[];
  List<TwitchFollowedChannel> searchedOfflineChannels =
      const <TwitchFollowedChannel>[];
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
    );
    chatAppearanceController = twitchChatAppearanceController;
    playerSettingsController = TwitchPlayerSettingsController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadLoginState());
      unawaited(chatAppearanceController.load());
      unawaited(playerSettingsController.load());
    });
  }

  @override
  void dispose() {
    _channelSearchDebounce?.cancel();
    searchController.dispose();
    playerSettingsController.dispose();
    apiClient.close(force: true);
    super.dispose();
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
        loadingChannelSearch = false;
        channelSearchError = null;
      } else {
        searchedLiveStreams = const <TwitchLiveStream>[];
        searchedOfflineChannels = const <TwitchFollowedChannel>[];
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

      setState(() {
        searchedLiveStreams = result.liveStreams;
        searchedOfflineChannels = result.offlineChannels;
        loadingChannelSearch = false;
        channelSearchError = null;
      });
    } catch (error) {
      if (!mounted || generation != _channelSearchGeneration) return;

      setState(() {
        searchedLiveStreams = const <TwitchLiveStream>[];
        searchedOfflineChannels = const <TwitchFollowedChannel>[];
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

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
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
          onShowGameMenu: selectedSection == TwitchHomeSection.browse
              ? () => browsePageKey.currentState?.showGameMenu(context)
              : null,
          onShowLanguageMenu: () {
            if (selectedSection == TwitchHomeSection.following) {
              followingPageKey.currentState?.showLanguageMenu(context);
            } else {
              browsePageKey.currentState?.showLanguageMenu(context);
            }
          },
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
              followedUserIds: followedUserIds,
              followedLogins: followedLogins,
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
            ),
    );
  }
}

class _TwitchChannelSearchPage extends StatelessWidget {
  final String query;
  final List<TwitchLiveStream> liveStreams;
  final List<TwitchFollowedChannel> offlineChannels;
  final Set<String> followedUserIds;
  final Set<String> followedLogins;
  final bool loading;
  final String? errorText;
  final TwitchDiscoveryService discoveryService;
  final Future<void> Function() onRefresh;

  const _TwitchChannelSearchPage({
    super.key,
    required this.query,
    required this.liveStreams,
    required this.offlineChannels,
    required this.followedUserIds,
    required this.followedLogins,
    required this.loading,
    required this.errorText,
    required this.discoveryService,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final hasResults = liveStreams.isNotEmpty || offlineChannels.isNotEmpty;
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
                count: liveStreams.length + offlineChannels.length,
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
                        '正在搜尋頻道...',
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
                  title: '已追隨的直播',
                  streams: followedLiveStreams,
                  discoveryService: discoveryService,
                  onReturnFromStream: onRefresh,
                ),
              if (followedOfflineChannels.isNotEmpty)
                ..._offlineChannelSlivers(
                  icon: Icons.favorite_border_rounded,
                  title: '已追隨但未開台',
                  channels: followedOfflineChannels,
                ),
            ],
            if (otherLiveStreams.isNotEmpty)
              TwitchDiscoveryStreamSliverSection(
                icon: Icons.live_tv_rounded,
                title: '直播',
                streams: otherLiveStreams,
                discoveryService: discoveryService,
                onReturnFromStream: onRefresh,
              ),
            if (otherOfflineChannels.isNotEmpty)
              ..._offlineChannelSlivers(
                icon: Icons.tv_off_rounded,
                title: '未開台頻道',
                channels: otherOfflineChannels,
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
    if (id.isNotEmpty && followedUserIds.contains(id)) return true;
    return login.isNotEmpty && followedLogins.contains(login);
  }

  bool _isFollowedChannel(TwitchFollowedChannel channel) {
    final id = channel.broadcasterId.trim();
    final login = channel.channelLogin;
    if (id.isNotEmpty && followedUserIds.contains(id)) return true;
    return login.isNotEmpty && followedLogins.contains(login);
  }

  List<Widget> _offlineChannelSlivers({
    required IconData icon,
    required String title,
    required List<TwitchFollowedChannel> channels,
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
            );
          }, childCount: channels.length),
        ),
      ),
    ];
  }
}
