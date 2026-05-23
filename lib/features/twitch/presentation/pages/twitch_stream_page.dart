// PATCH VERSION: twitch_stream_page_stage249_internal_notification_test

import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../../services/discovery/twitch_discovery_service.dart';
import '../../services/notifications/twitch_app_notification_service_stage249.dart';
import 'twitch_browse_page.dart';
import 'twitch_following_page.dart';
import 'twitch_linked_login_page.dart';

const Color _kTwitchPurple = Color(0xFF9146FF);
const Color _kTwitchPurpleLight = Color(0xFFBF94FF);
const Color _kBackground = Color(0xFF0A0A0F);
const Color _kPanel = Color(0xCC15121F);
const Color _kSoftPanel = Color(0xB8221B32);

class TwitchStreamPage extends StatefulWidget {
  const TwitchStreamPage({super.key});

  @override
  State<TwitchStreamPage> createState() => _TwitchStreamPageState();
}

enum TwitchHomeSection {
  following,
  browse,
}

extension TwitchHomeSectionUi on TwitchHomeSection {
  String get label {
    switch (this) {
      case TwitchHomeSection.following:
        return '追隨';
      case TwitchHomeSection.browse:
        return '瀏覽';
    }
  }

  IconData get icon {
    switch (this) {
      case TwitchHomeSection.following:
        return Icons.favorite_rounded;
      case TwitchHomeSection.browse:
        return Icons.explore_rounded;
    }
  }
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
          nextViewerLabel = validation.login.isEmpty ? '已登入' : '@${validation.login}';
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
          child: Row(
            children: <Widget>[
              _buildSidebar(),
              Expanded(
                child: Column(
                  children: <Widget>[
                    _buildTopToolbar(),
                    Expanded(child: _buildHomeContent()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildSidebar() {
    return Container(
      width: 132,
      decoration: BoxDecoration(
        color: _kPanel,
        border: Border(
          right: BorderSide(color: _kTwitchPurple.withOpacity(0.24)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
            color: _kTwitchPurple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Twitch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  viewerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.24)),
                  ),
                  child: Text(
                    loadingLoginState ? '檢查中' : loginStatus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 18),
              children: <Widget>[
                _buildSidebarButton(TwitchHomeSection.following),
                const SizedBox(height: 8),
                _buildSidebarButton(TwitchHomeSection.browse),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarButton(TwitchHomeSection section) {
    final selected = selectedSection == section;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => selectSection(section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? _kTwitchPurple.withOpacity(0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? _kTwitchPurpleLight.withOpacity(0.38)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                section.icon,
                color: selected ? _kTwitchPurpleLight : Colors.white54,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopToolbar() {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.30),
        border: Border(
          bottom: BorderSide(color: _kTwitchPurple.withOpacity(0.22)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _buildSearchField()),
          const SizedBox(width: 8),
          if (selectedSection == TwitchHomeSection.browse) ...<Widget>[
            _ToolbarIconButton(
              tooltip: '遊戲分類',
              icon: Icons.sports_esports_rounded,
              onPressed: () => browsePageKey.currentState?.showGameMenu(context),
            ),
            const SizedBox(width: 4),
          ],
          _ToolbarIconButton(
            tooltip: '語言篩選',
            icon: Icons.tune_rounded,
            onPressed: () {
              if (selectedSection == TwitchHomeSection.following) {
                followingPageKey.currentState?.showLanguageMenu(context);
              } else {
                browsePageKey.currentState?.showLanguageMenu(context);
              }
            },
          ),
          const SizedBox(width: 4),
          _ToolbarIconButton(
            tooltip: '重新整理',
            icon: Icons.refresh_rounded,
            onPressed: () => unawaited(refreshCurrentPage()),
          ),
          const SizedBox(width: 4),
          _buildAccountMenuButton(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          setState(() => searchText = value.trim().toLowerCase());
        },
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: selectedSection == TwitchHomeSection.following
              ? '搜尋追隨直播'
              : '搜尋直播、遊戲或實況主',
          hintStyle: const TextStyle(
            color: Colors.white38,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Colors.white54,
            size: 21,
          ),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  tooltip: '清除搜尋',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    searchController.clear();
                    setState(() => searchText = '');
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 19,
                  ),
                )
              : null,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildAccountMenuButton() {
    return PopupMenuButton<String>(
      tooltip: '設定',
      color: const Color(0xFF191421),
      icon: const Icon(
        Icons.settings_rounded,
        color: _kTwitchPurpleLight,
      ),
      onSelected: (value) async {
        switch (value) {
          case 'login':
            await runLinkedTwitchLoginFlow();
            break;
          case 'refresh':
            await refreshCurrentPage();
            break;
          case 'test_app_notification':
            showStage249InternalNotificationTest();
            break;
          case 'logout':
            await logout();
            break;
        }
      },
      itemBuilder: (context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'login',
          child: Text('完整登入 / 修復登入'),
        ),
        PopupMenuItem<String>(
          value: 'refresh',
          child: Text('重新檢查登入狀態'),
        ),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'test_app_notification',
          child: Text('測試程式內部通知'),
        ),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Text('登出'),
        ),
      ],
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ToolbarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _kSoftPanel,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(
              icon,
              color: onPressed == null ? Colors.white30 : _kTwitchPurpleLight,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
