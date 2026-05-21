// PATCH VERSION: twitch_stream_page_stage233e_emote_policy_setting
// Adds a home-page setting for chat emote animation behavior.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../../services/chat/twitch_emote_animation_policy_service.dart';
import '../../services/discovery/twitch_discovery_service.dart';
import 'twitch_browse_page.dart';
import 'twitch_following_page.dart';
import 'twitch_linked_login_page.dart';
import '../widgets/responsive/twitch_responsive_layout.dart';

const Color _kTwitchPurple = Color(0xFF9146FF);
const Color _kTwitchPurpleLight = Color(0xFFBF94FF);
const Color _kBackground = Color(0xFF0A0A0F);
const Color _kPanel = Color(0xCC15121F);
const Color _kSoftPanel = Color(0xB8221B32);
const Color _kBorder = Color(0xFF392A50);

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
  TwitchEmoteAnimationPolicy emoteAnimationPolicy =
      TwitchEmoteAnimationPolicyService.defaultPolicy;

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
      unawaited(_loadEmoteAnimationPolicy());
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    apiClient.close(force: true);
    super.dispose();
  }

  Future<void> _loadEmoteAnimationPolicy() async {
    final policy = await TwitchEmoteAnimationPolicyService.load();
    if (!mounted) return;
    setState(() => emoteAnimationPolicy = policy);
  }

  Future<void> _setEmoteAnimationPolicy(
    TwitchEmoteAnimationPolicy policy, {
    bool showSnack = true,
  }) async {
    await TwitchEmoteAnimationPolicyService.save(policy);
    if (!mounted) return;
    setState(() => emoteAnimationPolicy = policy);
    if (showSnack) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('聊天室貼圖動畫：${policy.label}'),
          duration: const Duration(milliseconds: 1300),
        ),
      );
    }
  }

  Future<void> _cycleEmoteAnimationPolicy() async {
    final next = TwitchEmoteAnimationPolicyService.next(emoteAnimationPolicy);
    await _setEmoteAnimationPolicy(next);
  }

  Future<void> _loadLoginState({bool refreshPages = false}) async {
    if (!mounted || _loginStateLoadRunning) return;

    _loginStateLoadRunning = true;

    if (mounted) {
      setState(() {
        loadingLoginState = true;
        loginStatus = '檢查登入狀態...';
      });
    }

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
      // Best effort. Services may already be empty or token revoke may fail.
    }

    if (!mounted) return;
    setState(() {
      viewerLabel = '未登入';
      loginStatus = '已登出';
      reloadTick++;
    });
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
              final useBottomNavigation = _shouldUseBottomNavigation(layout);
              final useTwoRowToolbar = _shouldUseTwoRowToolbar(layout);

              if (useBottomNavigation) {
                return Column(
                  children: <Widget>[
                    _buildTopToolbar(
                      layout: layout,
                      twoRows: true,
                    ),
                    Expanded(child: _buildHomeContent()),
                    _buildBottomNavigationBar(layout),
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  _buildSidebar(),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        _buildTopToolbar(
                          layout: layout,
                          twoRows: useTwoRowToolbar,
                        ),
                        Expanded(child: _buildHomeContent()),
                      ],
                    ),
                  ),
                ],
              );
            },
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

  bool _shouldUseBottomNavigation(TwitchResponsiveLayout layout) {
    return layout.isPhonePortrait ||
        layout.width < 700 ||
        (layout.width < 880 && layout.aspectRatio < 1.15);
  }

  bool _shouldUseTwoRowToolbar(TwitchResponsiveLayout layout) {
    return _shouldUseBottomNavigation(layout) ||
        layout.width < 860 ||
        (layout.width < 1040 && layout.aspectRatio < 1.25);
  }

  Widget _buildSidebar() {
    return Container(
      width: 132,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF2F1750),
            Color(0xDD171322),
            Color(0xEE0B0B10),
          ],
        ),
        border: Border(right: BorderSide(color: _kTwitchPurple.withOpacity(0.28))),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _kTwitchPurple.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(8, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  _kTwitchPurple.withOpacity(0.95),
                  const Color(0xFF6E2FD8).withOpacity(0.88),
                ],
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.18)),
              ),
            ),
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
                    color: Colors.black.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.26)),
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
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => selectSection(section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _kTwitchPurple.withOpacity(0.24) : Colors.white.withOpacity(0.035),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? _kTwitchPurpleLight.withOpacity(0.42) : Colors.white.withOpacity(0.06),
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: _kTwitchPurple.withOpacity(0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const <BoxShadow>[],
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

  Widget _buildTopToolbar({
    required TwitchResponsiveLayout layout,
    required bool twoRows,
  }) {
    final compact = twoRows || layout.width < 760;

    return Container(
      height: twoRows ? null : 76,
      padding: EdgeInsets.fromLTRB(18, twoRows ? 9 : 11, 18, twoRows ? 9 : 11),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.34),
        border: Border(
          bottom: BorderSide(color: _kTwitchPurple.withOpacity(0.24)),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.36),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _kTwitchPurple.withOpacity(0.10),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: twoRows
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _buildSearchField(
                        height: 44,
                        compact: compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildAccountMenuButton(size: 44, compact: true),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(child: _buildCompactLoginStatusPill()),
                    const SizedBox(width: 8),
                    ..._buildToolbarActionButtons(buttonSize: 42, spacing: 6),
                  ],
                ),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(
                  child: _buildSearchField(
                    height: 50,
                    compact: false,
                  ),
                ),
                const SizedBox(width: 10),
                ..._buildToolbarActionButtons(buttonSize: 50, spacing: 7),
                const SizedBox(width: 7),
                _buildAccountMenuButton(size: 50, compact: false),
              ],
            ),
    );
  }

  Widget _buildSearchField({
    required double height,
    required bool compact,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _kTwitchPurple.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          setState(() => searchText = value.trim().toLowerCase());
        },
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 13.5 : 14.5,
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
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white54,
            size: compact ? 20 : 21,
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
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: compact ? 12 : 14,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  List<Widget> _buildToolbarActionButtons({
    required double buttonSize,
    required double spacing,
  }) {
    final children = <Widget>[];

    void addSpacingIfNeeded() {
      if (children.isNotEmpty) {
        children.add(SizedBox(width: spacing));
      }
    }

    if (selectedSection == TwitchHomeSection.browse) {
      addSpacingIfNeeded();
      children.add(
        _ToolbarIconButton(
          tooltip: '遊戲分類',
          icon: Icons.sports_esports_rounded,
          size: buttonSize,
          onPressed: () => browsePageKey.currentState?.showGameMenu(context),
        ),
      );
    }

    addSpacingIfNeeded();
    children.add(
      _ToolbarIconButton(
        tooltip: '語言篩選',
        icon: Icons.tune_rounded,
        size: buttonSize,
        onPressed: () {
          if (selectedSection == TwitchHomeSection.following) {
            followingPageKey.currentState?.showLanguageMenu(context);
          } else {
            browsePageKey.currentState?.showLanguageMenu(context);
          }
        },
      ),
    );

    addSpacingIfNeeded();
    children.add(
      _ToolbarIconButton(
        tooltip: '貼圖動畫：${emoteAnimationPolicy.label}',
        icon: Icons.gif_box_rounded,
        size: buttonSize,
        onPressed: () => unawaited(_cycleEmoteAnimationPolicy()),
      ),
    );

    addSpacingIfNeeded();
    children.add(
      _ToolbarIconButton(
        tooltip: '重新整理',
        icon: Icons.refresh_rounded,
        size: buttonSize,
        onPressed: () => unawaited(refreshCurrentPage()),
      ),
    );

    return children;
  }

  Widget _buildAccountMenuButton({
    required double size,
    required bool compact,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _kSoftPanel,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.13)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _kTwitchPurple.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        tooltip: '帳號',
        padding: EdgeInsets.zero,
        color: const Color(0xFF191421),
        icon: Icon(
          Icons.account_circle_rounded,
          color: _kTwitchPurpleLight,
          size: compact ? 24 : 26,
        ),
        onSelected: (value) async {
          switch (value) {
            case 'login':
              await runLinkedTwitchLoginFlow();
              break;
            case 'logout':
              await logout();
              break;
            case 'refresh':
              await refreshCurrentPage();
              break;
            case 'emote_visible':
              await _setEmoteAnimationPolicy(
                TwitchEmoteAnimationPolicy.visibleAnimated,
              );
              break;
            case 'emote_scroll':
              await _setEmoteAnimationPolicy(
                TwitchEmoteAnimationPolicy.staticWhileScroll,
              );
              break;
            case 'emote_always':
              await _setEmoteAnimationPolicy(
                TwitchEmoteAnimationPolicy.alwaysAnimated,
              );
              break;
            case 'emote_static':
              await _setEmoteAnimationPolicy(
                TwitchEmoteAnimationPolicy.staticOnly,
              );
              break;
          }
        },
        itemBuilder: (context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'login',
            child: Text('完整登入 / 修復登入'),
          ),
          const PopupMenuItem<String>(
            value: 'refresh',
            child: Text('重新檢查登入狀態'),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'emote_visible',
            child: _AccountMenuPolicyItem(
              title: TwitchEmoteAnimationPolicy.visibleAnimated.label,
              subtitle: TwitchEmoteAnimationPolicy.visibleAnimated.description,
              selected: emoteAnimationPolicy ==
                  TwitchEmoteAnimationPolicy.visibleAnimated,
            ),
          ),
          PopupMenuItem<String>(
            value: 'emote_scroll',
            child: _AccountMenuPolicyItem(
              title: TwitchEmoteAnimationPolicy.staticWhileScroll.label,
              subtitle: TwitchEmoteAnimationPolicy.staticWhileScroll.description,
              selected: emoteAnimationPolicy ==
                  TwitchEmoteAnimationPolicy.staticWhileScroll,
            ),
          ),
          PopupMenuItem<String>(
            value: 'emote_always',
            child: _AccountMenuPolicyItem(
              title: TwitchEmoteAnimationPolicy.alwaysAnimated.label,
              subtitle: TwitchEmoteAnimationPolicy.alwaysAnimated.description,
              selected: emoteAnimationPolicy ==
                  TwitchEmoteAnimationPolicy.alwaysAnimated,
            ),
          ),
          PopupMenuItem<String>(
            value: 'emote_static',
            child: _AccountMenuPolicyItem(
              title: TwitchEmoteAnimationPolicy.staticOnly.label,
              subtitle: TwitchEmoteAnimationPolicy.staticOnly.description,
              selected: emoteAnimationPolicy == TwitchEmoteAnimationPolicy.staticOnly,
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'logout',
            child: Text('登出'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLoginStatusPill() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kSoftPanel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            loadingLoginState ? Icons.sync_rounded : Icons.person_rounded,
            color: _kTwitchPurpleLight,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  viewerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loadingLoginState ? '檢查中' : loginStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(TwitchResponsiveLayout layout) {
    final compact = layout.width < 380;

    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.42),
        border: Border(top: BorderSide(color: _kTwitchPurple.withOpacity(0.24))),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _BottomNavigationButton(
              section: TwitchHomeSection.following,
              selected: selectedSection == TwitchHomeSection.following,
              compact: compact,
              onTap: () => selectSection(TwitchHomeSection.following),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _BottomNavigationButton(
              section: TwitchHomeSection.browse,
              selected: selectedSection == TwitchHomeSection.browse,
              compact: compact,
              onTap: () => selectSection(TwitchHomeSection.browse),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountMenuPolicyItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;

  const _AccountMenuPolicyItem({
    required this.title,
    required this.subtitle,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: selected ? _kTwitchPurpleLight : Colors.white38,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10.5,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double? iconSize;

  const _ToolbarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = 48,
    this.iconSize,
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
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.13)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _kTwitchPurple.withOpacity(0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: onPressed == null ? Colors.white30 : _kTwitchPurpleLight,
              size: iconSize ?? (size <= 42 ? 20 : 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavigationButton extends StatelessWidget {
  final TwitchHomeSection section;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _BottomNavigationButton({
    required this.section,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _kTwitchPurple.withOpacity(0.24) : Colors.white.withOpacity(0.035),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _kTwitchPurpleLight.withOpacity(0.40) : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                section.icon,
                color: selected ? _kTwitchPurpleLight : Colors.white54,
                size: 21,
              ),
              if (!compact) ...<Widget>[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    section.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
