// PATCH VERSION: twitch_stream_page_stage254_mobile_shell
//
// 這份主頁已拆分：
// - twitch_stream_home_models_stage249.dart
// - widgets/home/twitch_stream_home_sidebar_stage249.dart
// - widgets/home/twitch_stream_home_toolbar_stage249.dart
// - widgets/home/twitch_stream_home_account_menu_stage249.dart
// - twitch_drops_connection_page_stage249.dart
//
// Stage 254:
// - 使用 TwitchResponsiveLayout 作為共用手機判定。
// - 手機寬度時 sidebar 移到底部 NavigationBar。
// - 手機寬度時 toolbar 會拆成兩排，避免按鈕擠爆。

import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../../services/discovery/twitch_discovery_service.dart';
import '../../services/notifications/twitch_app_notification_service_stage249.dart';
import '../widgets/home/twitch_stream_home_bottom_nav_stage254.dart';
import '../widgets/home/twitch_stream_home_sidebar_stage249.dart';
import '../widgets/home/twitch_stream_home_toolbar_stage249.dart';
import '../widgets/responsive/twitch_responsive_layout.dart';
import 'twitch_browse_page.dart';
import 'twitch_following_page.dart';
import 'twitch_linked_login_page.dart';
import 'twitch_stream_home_models_stage249.dart';
import 'twitch_drops_connection_page_stage249.dart';

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

  TwitchHomeSection selectedSection = TwitchHomeSection.following;

  String searchText = '';
  String loginStatus = '檢查登入狀態...';
  String viewerLabel = '未登入';
  int reloadTick = 0;
  bool loadingLoginState = true;
  bool _loginStateLoadRunning = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadLoginState());
    });
  }

  @override
  void dispose() {
    searchController.dispose();
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
          nextViewerLabel =
              validation.login.isEmpty ? '已登入' : '@${validation.login}';
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

  void showStage249InternalNotificationTest() {
    final hasDropsToken = dropsAuthService.accessToken?.trim().isNotEmpty ?? false;
    final tokenLabel = hasDropsToken ? 'Drops token 已存在' : '尚未登入 Drops token';

    twitchAppNotificationCenter.showSuccess(
      title: 'Stage 249 程式內部通知測試',
      message: '$tokenLabel。之後 Drops 可領取、進度完成、token 失效都會先走這個 App 內通知。',
      duration: const Duration(seconds: 6),
    );
  }

  Future<void> openDropsConnectorPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TwitchDropsConnectionPageStage249(
          apiClient: apiClient,
          dropsAuthService: dropsAuthService,
        ),
      ),
    );
  }

  void selectSection(TwitchHomeSection section) {
    if (selectedSection == section) return;
    setState(() {
      selectedSection = section;
      reloadTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: DecoratedBox(
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
              final layout = TwitchResponsiveLayout.fromConstraints(constraints);
              return layout.shouldUseBottomHomeNavigation
                  ? _buildMobileShell(layout)
                  : _buildDesktopShell(layout);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopShell(TwitchResponsiveLayout layout) {
    return Row(
      children: <Widget>[
        TwitchStreamHomeSidebarStage249(
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
        TwitchStreamHomeBottomNavigationStage254(
          selectedSection: selectedSection,
          onSelectSection: selectSection,
        ),
      ],
    );
  }

  Widget _buildContentColumn(TwitchResponsiveLayout layout) {
    return Column(
      children: <Widget>[
        TwitchStreamHomeToolbarStage249(
          selectedSection: selectedSection,
          searchController: searchController,
          forceTwoRows: layout.shouldUseTwoRowHomeToolbar,
          onSearchChanged: (value) {
            setState(() => searchText = value.trim().toLowerCase());
          },
          onClearSearch: () {
            searchController.clear();
            setState(() => searchText = '');
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
          onLogin: runLinkedTwitchLoginFlow,
          onOpenDropsConnector: openDropsConnectorPage,
          onTestAppNotification: showStage249InternalNotificationTest,
          onLogout: logout,
        ),
        Expanded(child: _buildHomeContent()),
      ],
    );
  }

  Widget _buildHomeContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: selectedSection == TwitchHomeSection.following
          ? TwitchFollowingPage(
              key: followingPageKey,
              discoveryService: discoveryService,
              searchText: searchText,
              reloadTick: reloadTick,
              onLoginPressed: runLinkedTwitchLoginFlow,
            )
          : TwitchBrowsePage(
              key: browsePageKey,
              discoveryService: discoveryService,
              searchText: searchText,
              reloadTick: reloadTick,
              onLoginPressed: runLinkedTwitchLoginFlow,
            ),
    );
  }
}
