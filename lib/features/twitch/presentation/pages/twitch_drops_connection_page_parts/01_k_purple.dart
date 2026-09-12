part of '../twitch_drops_connection_page.dart';

const Color _kPurple = TwitchUiColors.primary;
const Color _kPurpleLight = TwitchUiColors.primarySoft;
const Color _kPanel = Color(0xFF18181B);
const Color _kPanelSoft = Color(0xFF202027);
const Color _kBackground = Color(0xFF0E0E10);
const Color _kGreen = Color(0xFF5CFFB1);
const Color _kGold = Color(0xFFFFC857);

enum _DropsTab { campaigns, inventory, stats }

class TwitchDropsConnectionPage extends StatefulWidget {
  final TwitchApiClient apiClient;
  final TwitchAuthService authService;
  final TwitchAuthApiService authApi;
  final TwitchDropsAuthService dropsAuthService;

  const TwitchDropsConnectionPage({
    super.key,
    required this.apiClient,
    required this.authService,
    required this.authApi,
    required this.dropsAuthService,
  });

  @override
  State<TwitchDropsConnectionPage> createState() =>
      _TwitchDropsConnectionPageState();
}

class _TwitchDropsConnectionPageState extends State<TwitchDropsConnectionPage> {
  late final TwitchDropsConnectionService service;
  late final TwitchDropsChannelPointsLeaderboardService leaderboardService;

  TwitchDropsConnectionCheck? result;
  final Set<String> claimingDropInstanceIds = <String>{};
  List<TwitchDropsChannelPointsLeaderboardEntry> channelPointsLeaderboard =
      const <TwitchDropsChannelPointsLeaderboardEntry>[];
  _DropsTab activeTab = _DropsTab.campaigns;
  bool checking = false;
  bool loadingChannelPointsLeaderboard = false;
  String? channelPointsLeaderboardError;
  String statusText = '尚未載入 Drops。';

  @override
  void initState() {
    super.initState();
    service = TwitchDropsConnectionService(
      apiClient: widget.apiClient,
      dropsAuthService: widget.dropsAuthService,
    );
    leaderboardService = TwitchDropsChannelPointsLeaderboardService.create(
      apiClient: widget.apiClient,
      authService: widget.authService,
      authApi: widget.authApi,
      dropsAuthService: widget.dropsAuthService,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(runCheck(showToast: false));
    });
  }

  Future<void> runCheck({bool showToast = true}) async {
    if (checking) return;

    setState(() {
      checking = true;
      statusText = '正在載入 Drops 庫存...';
    });

    final next = await service.checkConnection();

    if (!mounted) return;

    setState(() {
      result = next;
      checking = false;
      statusText = next.title;
    });

    final snapshot = next.snapshot;
    if (next.connected) {
      unawaited(
        loadChannelPointsLeaderboard(showLoading: activeTab == _DropsTab.stats),
      );
      if (snapshot != null && snapshot.hasReadyDrops) {
        twitchAppNotificationCenter.showWarning(
          title: '有 Drops 獎勵可領取',
          message: '目前有 ${snapshot.readyDropCount} 個 Drops 獎勵可領取。',
          duration: const Duration(seconds: 8),
        );
      } else if (showToast) {
        twitchAppNotificationCenter.showSuccess(
          title: 'Drops 已更新',
          message: snapshot == null
              ? 'Drops 授權、庫存與活動都已連上。'
              : 'Drops 庫存已更新，${snapshot.watchingDropCount} 個進行中，${snapshot.readyDropCount} 個可領取獎勵。',
        );
      }
    } else {
      twitchAppNotificationCenter.showWarning(
        title: next.title,
        message: next.summary,
        duration: const Duration(seconds: 8),
      );
    }
  }

  Future<void> loadChannelPointsLeaderboard({
    bool showLoading = true,
    bool force = false,
  }) async {
    if (loadingChannelPointsLeaderboard) return;
    if (showLoading) {
      setState(() {
        loadingChannelPointsLeaderboard = true;
        channelPointsLeaderboardError = null;
      });
    } else {
      channelPointsLeaderboardError = null;
    }

    try {
      final ranked = await leaderboardService.load(force: force);
      if (!mounted) return;
      setState(() {
        channelPointsLeaderboard = ranked;
        loadingChannelPointsLeaderboard = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        channelPointsLeaderboardError = error.toString();
        loadingChannelPointsLeaderboard = false;
      });
    }
  }

  void _selectTab(_DropsTab tab) {
    if (activeTab == tab) return;
    setState(() => activeTab = tab);
    if (tab == _DropsTab.stats &&
        channelPointsLeaderboard.isEmpty &&
        !loadingChannelPointsLeaderboard) {
      unawaited(loadChannelPointsLeaderboard());
    }
  }

  Future<void> claimDrop(TwitchDrop drop) async {
    final dropInstanceId = drop.dropInstanceId.trim();
    if (dropInstanceId.isEmpty ||
        claimingDropInstanceIds.contains(dropInstanceId)) {
      return;
    }

    setState(() {
      claimingDropInstanceIds.add(dropInstanceId);
    });

    final claimResult = await service.collectDrop(
      dropInstanceId: dropInstanceId,
    );

    if (!mounted) return;

    setState(() {
      claimingDropInstanceIds.remove(dropInstanceId);
    });

    if (claimResult.ok) {
      twitchAppNotificationCenter.showSuccess(
        title: 'Drops 獎勵領取成功',
        message: drop.displayRewardName,
      );
      await runCheck(showToast: false);
    } else {
      twitchAppNotificationCenter.showWarning(
        title: 'Drops 獎勵領取失敗',
        message: claimResult.message,
        duration: const Duration(seconds: 8),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = result;
    final snapshot = current?.snapshot;
    final connected = current?.connected ?? false;

    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: _kBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kPurple.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kPurple.withValues(alpha: 0.32)),
              ),
              child: const Icon(Icons.card_giftcard_rounded, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Drops 與 Channel Points',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '重新整理 Drops',
            onPressed: checking ? null : () => unawaited(runCheck()),
            icon: checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kPurpleLight,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = TwitchResponsiveLayout.fromConstraints(constraints);
          final List<Widget> bodyChildren;
          if (snapshot == null) {
            bodyChildren = checking
                ? const <Widget>[]
                : <Widget>[
                    _EmptyDropsCard(
                      connected: connected,
                      statusText: statusText,
                    ),
                  ];
          } else {
            bodyChildren = <Widget>[
              _DropsTabBar(activeTab: activeTab, onChanged: _selectTab),
              const SizedBox(height: 14),
              if (activeTab == _DropsTab.stats)
                _DropsStatsPage(
                  snapshot: snapshot,
                  channelPointsLeaderboard: channelPointsLeaderboard,
                  loadingChannelPointsLeaderboard:
                      loadingChannelPointsLeaderboard,
                  channelPointsLeaderboardError: channelPointsLeaderboardError,
                  onRefreshChannelPointsLeaderboard: () =>
                      unawaited(loadChannelPointsLeaderboard(force: true)),
                )
              else if (activeTab == _DropsTab.inventory)
                _DropsInventoryPage(
                  snapshot: snapshot,
                  claimingDropInstanceIds: claimingDropInstanceIds,
                  onClaimDrop: claimDrop,
                )
              else
                _DropsCampaignsPage(
                  snapshot: snapshot,
                  claimingDropInstanceIds: claimingDropInstanceIds,
                  onClaimDrop: claimDrop,
                ),
            ];
          }
          return RefreshIndicator(
            color: _kPurple,
            onRefresh: () => runCheck(showToast: false),
            child: ListView(
              padding: layout.contentPadding,
              children: bodyChildren,
            ),
          );
        },
      ),
    );
  }
}

class _EmptyDropsCard extends StatelessWidget {
  final bool connected;
  final String statusText;

  const _EmptyDropsCard({required this.connected, required this.statusText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.inventory_2_outlined,
            color: _kPurpleLight,
            size: 46,
          ),
          const SizedBox(height: 12),
          Text(
            statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            connected
                ? '目前沒有可顯示的 Drops 庫存。'
                : '如果還沒完成 Drops 授權，請先完成完整登入或 Drops 登入流程。',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DropsTabBar extends StatelessWidget {
  final _DropsTab activeTab;
  final ValueChanged<_DropsTab> onChanged;

  const _DropsTabBar({required this.activeTab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _kPanelSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _DropsTabButton(
              icon: Icons.desktop_windows_rounded,
              label: '活動',
              selected: activeTab == _DropsTab.campaigns,
              onTap: () => onChanged(_DropsTab.campaigns),
            ),
            _DropsTabButton(
              icon: Icons.inventory_2_rounded,
              label: '庫存',
              selected: activeTab == _DropsTab.inventory,
              onTap: () => onChanged(_DropsTab.inventory),
            ),
            _DropsTabButton(
              icon: Icons.analytics_rounded,
              label: '統計',
              selected: activeTab == _DropsTab.stats,
              onTap: () => onChanged(_DropsTab.stats),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropsTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DropsTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                color: selected ? Colors.white : Colors.white54,
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropsCampaignsPage extends StatelessWidget {
  final TwitchDropsSnapshot snapshot;
  final Set<String> claimingDropInstanceIds;
  final ValueChanged<TwitchDrop> onClaimDrop;

  const _DropsCampaignsPage({
    required this.snapshot,
    required this.claimingDropInstanceIds,
    required this.onClaimDrop,
  });

  @override
  Widget build(BuildContext context) {
    final groups = _CampaignGameGroup.fromCampaigns(snapshot.activeCampaigns);
    final campaignCount = groups.fold<int>(
      0,
      (sum, group) => sum + group.campaigns.length,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeader(
          icon: Icons.desktop_windows_rounded,
          title: '活動',
          subtitle: '${groups.length} 個遊戲・$campaignCount 個活動',
          color: _kPurpleLight,
        ),
        const SizedBox(height: 10),
        if (groups.isEmpty)
          const _SimpleInfoCard(text: '目前沒有可顯示的 Drops 活動。')
        else
          _CampaignGamesTable(
            groups: groups,
            claimingDropInstanceIds: claimingDropInstanceIds,
            onClaimDrop: onClaimDrop,
          ),
      ],
    );
  }
}

class _CampaignGameGroup {
  final String key;
  final String gameName;
  final String imageUrl;
  final List<TwitchDropCampaign> campaigns;
  final int totalDrops;
  final int readyDrops;
  final int inProgressDrops;

  const _CampaignGameGroup({
    required this.key,
    required this.gameName,
    required this.imageUrl,
    required this.campaigns,
    required this.totalDrops,
    required this.readyDrops,
    required this.inProgressDrops,
  });

  static List<_CampaignGameGroup> fromCampaigns(
    List<TwitchDropCampaign> campaigns,
  ) {
    final grouped = <String, List<TwitchDropCampaign>>{};
    for (final campaign in campaigns) {
      if (campaign.status.toUpperCase() == 'EXPIRED') continue;
      final gameName = campaign.gameName.trim();
      if (gameName.isEmpty) continue;
      final key = campaign.gameId.trim().isNotEmpty
          ? campaign.gameId.trim()
          : gameName.toLowerCase();
      grouped.putIfAbsent(key, () => <TwitchDropCampaign>[]).add(campaign);
    }

    final groups = grouped.entries.map((entry) {
      final campaigns = List<TwitchDropCampaign>.from(entry.value)
        ..sort((a, b) {
          final statusCompare = _campaignStatusPriority(a.status)
              .compareTo(_campaignStatusPriority(b.status));
          if (statusCompare != 0) return statusCompare;
          final startCompare =
              (b.startAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
                a.startAt ?? DateTime.fromMillisecondsSinceEpoch(0),
              );
          if (startCompare != 0) return startCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      final drops = campaigns
          .expand((campaign) => campaign.timeBasedDrops)
          .toList(growable: false);
      return _CampaignGameGroup(
        key: entry.key,
        gameName: campaigns.first.gameName,
        imageUrl: campaigns
            .map((campaign) => campaign.imageUrl)
            .firstWhere((url) => url.trim().isNotEmpty, orElse: () => ''),
        campaigns: campaigns,
        totalDrops: drops.length,
        readyDrops: drops.where((drop) => drop.readyToCollect).length,
        inProgressDrops: drops
            .where((drop) => !drop.isClaimed && !drop.readyToCollect)
            .length,
      );
    }).toList();

    groups.sort((a, b) {
      if (a.readyDrops != b.readyDrops) return b.readyDrops - a.readyDrops;
      if (a.inProgressDrops != b.inProgressDrops) {
        return b.inProgressDrops - a.inProgressDrops;
      }
      if (a.campaigns.length != b.campaigns.length) {
        return b.campaigns.length - a.campaigns.length;
      }
      return a.gameName.toLowerCase().compareTo(b.gameName.toLowerCase());
    });
    return groups;
  }

  static int _campaignStatusPriority(String status) {
    final normalized = status.trim().toUpperCase();
    if (normalized == 'ACTIVE') return 0;
    if (normalized == 'UPCOMING') return 1;
    return 2;
  }
}
