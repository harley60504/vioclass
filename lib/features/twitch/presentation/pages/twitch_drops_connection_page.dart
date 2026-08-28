import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/drops/twitch_drops_channel_points_leaderboard_service.dart';
import '../../services/drops/twitch_drops_connection_check.dart';
import '../../services/drops/twitch_drops_connection_service.dart';
import '../../services/drops/twitch_drops_snapshot.dart';
import '../../services/notifications/twitch_app_notification_service.dart';
import '../widgets/responsive/twitch_responsive_layout.dart';

const Color _kPurple = Color(0xFF9146FF);
const Color _kPurpleLight = Color(0xFFBF94FF);
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
      statusText = '正在載入 Drops inventory...';
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
          title: '有 Drops 可領取',
          message: '目前有 ${snapshot.readyDropCount} 個 Drops 可領取。',
          duration: const Duration(seconds: 8),
        );
      } else if (showToast) {
        twitchAppNotificationCenter.showSuccess(
          title: 'Drops 已更新',
          message: snapshot == null
              ? 'Drops token、Inventory、Campaigns 都已連上。'
              : 'Inventory 已更新，${snapshot.watchingDropCount} 個進行中，${snapshot.readyDropCount} 個可領取。',
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
        title: 'Drop 領取成功',
        message: drop.displayRewardName,
      );
      await runCheck(showToast: false);
    } else {
      twitchAppNotificationCenter.showWarning(
        title: 'Drop 領取失敗',
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
              'Drops & Channel Points',
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
                ? '目前沒有可顯示的 Drops inventory。'
                : '如果還沒登入 Drops token，請先完成完整登入或 Drops 登入流程。',
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
              label: 'Campaigns',
              selected: activeTab == _DropsTab.campaigns,
              onTap: () => onChanged(_DropsTab.campaigns),
            ),
            _DropsTabButton(
              icon: Icons.inventory_2_rounded,
              label: 'Inventory',
              selected: activeTab == _DropsTab.inventory,
              onTap: () => onChanged(_DropsTab.inventory),
            ),
            _DropsTabButton(
              icon: Icons.analytics_rounded,
              label: 'Stats',
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
          title: 'Campaigns',
          subtitle: '${groups.length} games・$campaignCount campaigns',
          color: _kPurpleLight,
        ),
        const SizedBox(height: 10),
        if (groups.isEmpty)
          const _SimpleInfoCard(text: '目前沒有可顯示的 Drops campaign。')
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
          final statusCompare = _campaignStatusPriority(
            a.status,
          ).compareTo(_campaignStatusPriority(b.status));
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

class _CampaignGamesTable extends StatelessWidget {
  final List<_CampaignGameGroup> groups;
  final Set<String> claimingDropInstanceIds;
  final ValueChanged<TwitchDrop> onClaimDrop;

  const _CampaignGamesTable({
    required this.groups,
    required this.claimingDropInstanceIds,
    required this.onClaimDrop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1320
            ? 6
            : width >= 1080
            ? 5
            : width >= 840
            ? 4
            : width >= 600
            ? 3
            : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: groups.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.66,
          ),
          itemBuilder: (context, index) {
            final group = groups[index];
            return _CampaignGameGridCard(
              group: group,
              onTap: () => _showCampaignGameDialog(context, group),
            );
          },
        );
      },
    );
  }

  Future<void> _showCampaignGameDialog(
    BuildContext context,
    _CampaignGameGroup group,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
            child: _CampaignGameDialog(
              group: group,
              claimingDropInstanceIds: claimingDropInstanceIds,
              onClaimDrop: onClaimDrop,
            ),
          ),
        );
      },
    );
  }
}

class _CampaignGameGridCard extends StatelessWidget {
  final _CampaignGameGroup group;
  final VoidCallback onTap;

  const _CampaignGameGridCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = group.campaigns.any(
      (campaign) => campaign.status.toUpperCase() == 'ACTIVE',
    );
    final color = active ? _kGreen : _kPurpleLight;
    final badgeText = group.readyDrops > 0
        ? '${group.readyDrops} ready'
        : '${group.campaigns.length} campaigns';
    return Material(
      color: _kPanel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _CampaignGamePoster(imageUrl: group.imageUrl, color: color),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _MiniBadge(text: badgeText, color: color),
                    ),
                    const Positioned(
                      right: 8,
                      top: 8,
                      child: Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      group.gameName.isEmpty ? 'Unknown Game' : group.gameName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _CampaignGridMetric(
                            value: group.campaigns.length.toString(),
                            label: 'Campaigns',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CampaignGridMetric(
                            value: group.totalDrops.toString(),
                            label: 'Drops',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      active ? 'Active' : 'Upcoming',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignGamePoster extends StatelessWidget {
  final String imageUrl;
  final Color color;

  const _CampaignGamePoster({required this.imageUrl, required this.color});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    return Container(
      color: color.withValues(alpha: 0.12),
      child: url.isEmpty
          ? Icon(Icons.extension_rounded, color: color, size: 36)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.extension_rounded, color: color, size: 36);
              },
            ),
    );
  }
}

class _CampaignGridMetric extends StatelessWidget {
  final String value;
  final String label;

  const _CampaignGridMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignGameDialog extends StatelessWidget {
  final _CampaignGameGroup group;
  final Set<String> claimingDropInstanceIds;
  final ValueChanged<TwitchDrop> onClaimDrop;

  const _CampaignGameDialog({
    required this.group,
    required this.claimingDropInstanceIds,
    required this.onClaimDrop,
  });

  @override
  Widget build(BuildContext context) {
    final active = group.campaigns.any(
      (campaign) => campaign.status.toUpperCase() == 'ACTIVE',
    );
    final color = active ? _kGreen : _kPurpleLight;
    return Container(
      decoration: BoxDecoration(
        color: _kBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            decoration: BoxDecoration(
              color: _kPanel,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: <Widget>[
                _InventoryGameImage(imageUrl: group.imageUrl, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        group.gameName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.campaigns.length} campaigns・${group.totalDrops} drops',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                for (final campaign in group.campaigns) ...<Widget>[
                  _CampaignDetailCard(
                    campaign: campaign,
                    claimingDropInstanceIds: claimingDropInstanceIds,
                    onClaimDrop: onClaimDrop,
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignDetailCard extends StatelessWidget {
  final TwitchDropCampaign campaign;
  final Set<String> claimingDropInstanceIds;
  final ValueChanged<TwitchDrop> onClaimDrop;

  const _CampaignDetailCard({
    required this.campaign,
    required this.claimingDropInstanceIds,
    required this.onClaimDrop,
  });

  @override
  Widget build(BuildContext context) {
    final sortedDrops = List<TwitchDrop>.from(campaign.timeBasedDrops)
      ..sort((a, b) {
        final priorityCompare = _dropPriority(a).compareTo(_dropPriority(b));
        if (priorityCompare != 0) return priorityCompare;
        return b.progressPercent.compareTo(a.progressPercent);
      });
    final hasReady = sortedDrops.any((drop) => drop.readyToCollect);
    final accent = hasReady
        ? _kGold
        : campaign.status.toUpperCase() == 'ACTIVE'
        ? _kGreen
        : _kPurpleLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 620;
          final body = _CampaignDetailBody(
            campaign: campaign,
            sortedDrops: sortedDrops,
            accent: accent,
            claimingDropInstanceIds: claimingDropInstanceIds,
            onClaimDrop: onClaimDrop,
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _CampaignPoster(
                  imageUrl: campaign.imageUrl,
                  accent: accent,
                  compact: true,
                ),
                const SizedBox(height: 14),
                body,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CampaignPoster(
                imageUrl: campaign.imageUrl,
                accent: accent,
                compact: false,
              ),
              const SizedBox(width: 16),
              Expanded(child: body),
            ],
          );
        },
      ),
    );
  }

  int _dropPriority(TwitchDrop drop) {
    if (drop.readyToCollect) return 0;
    if (!drop.isClaimed && drop.progressComplete) return 1;
    if (!drop.isClaimed) return 2;
    return 3;
  }
}

class _CampaignDetailBody extends StatelessWidget {
  final TwitchDropCampaign campaign;
  final List<TwitchDrop> sortedDrops;
  final Color accent;
  final Set<String> claimingDropInstanceIds;
  final ValueChanged<TwitchDrop> onClaimDrop;

  const _CampaignDetailBody({
    required this.campaign,
    required this.sortedDrops,
    required this.accent,
    required this.claimingDropInstanceIds,
    required this.onClaimDrop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                campaign.name.isEmpty ? 'Untitled campaign' : campaign.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _MiniBadge(
              text: campaign.status.isEmpty ? 'UNKNOWN' : campaign.status,
              color: accent,
            ),
            const SizedBox(width: 6),
            _MiniBadge(
              text: campaign.isAccountConnected ? '已連結' : '未連結',
              color: campaign.isAccountConnected
                  ? _kGreen
                  : Colors.orangeAccent,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _MiniBadge(text: campaign.gameName, color: _kPurpleLight),
            _MiniBadge(text: '${sortedDrops.length} drops', color: _kGold),
            if (campaign.allowedChannels.isNotEmpty)
              _MiniBadge(
                text: '${campaign.allowedChannels.length} channels',
                color: Colors.lightBlueAccent,
              ),
            if (campaign.startAt != null)
              _MiniBadge(
                text: '開始 ${_formatDateTime(campaign.startAt)}',
                color: Colors.white54,
              ),
            if (campaign.endAt != null)
              _MiniBadge(
                text: '結束 ${_formatDateTime(campaign.endAt)}',
                color: Colors.white54,
              ),
          ],
        ),
        if (!campaign.isAccountConnected &&
            campaign.accountLinkUrl.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: <Widget>[
              _CampaignLinkText(
                label: 'Connect account',
                url: campaign.accountLinkUrl,
              ),
            ],
          ),
        ],
        if (campaign.description.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            campaign.description.trim(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (campaign.allowedChannels.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            '可觀看頻道：${campaign.allowedChannels.take(12).map((channel) => channel.name.isEmpty ? channel.id : channel.name).join('、')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (sortedDrops.isEmpty)
          const Text(
            '這個 campaign 沒有可顯示的 Drops。',
            style: TextStyle(color: Colors.white54),
          )
        else
          for (final drop in sortedDrops.take(8)) ...<Widget>[
            _DropRow(
              drop: drop,
              claiming: claimingDropInstanceIds.contains(
                drop.dropInstanceId.trim(),
              ),
              onClaimDrop: onClaimDrop,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _DropsInventoryPage extends StatefulWidget {
  final TwitchDropsSnapshot snapshot;
  final Set<String> claimingDropInstanceIds;
  final ValueChanged<TwitchDrop> onClaimDrop;

  const _DropsInventoryPage({
    required this.snapshot,
    required this.claimingDropInstanceIds,
    required this.onClaimDrop,
  });

  @override
  State<_DropsInventoryPage> createState() => _DropsInventoryPageState();
}

class _DropsInventoryPageState extends State<_DropsInventoryPage> {
  final Set<String> expandedGameKeys = <String>{};

  void toggleGame(String key) {
    setState(() {
      if (!expandedGameKeys.add(key)) {
        expandedGameKeys.remove(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = _InventoryGameGroup.fromCampaigns(
      widget.snapshot.inventoryCampaigns,
    );
    final completedDrops = widget.snapshot.allDrops
        .where((drop) => drop.isClaimed)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _InventorySummaryGrid(snapshot: widget.snapshot),
        const SizedBox(height: 14),
        if (completedDrops > 0) ...<Widget>[
          _InventoryCompactRow(
            icon: Icons.check_rounded,
            title: 'Completed Drops',
            subtitle:
                '$completedDrops drops you have earned across all campaigns',
            trailing: '$completedDrops total',
            color: _kGreen,
          ),
          const SizedBox(height: 12),
        ],
        if (groups.isEmpty)
          const _SimpleInfoCard(text: '目前 Inventory 沒有 Drops campaign。')
        else
          for (final group in groups) ...<Widget>[
            _InventoryGameRow(
              group: group,
              expanded: expandedGameKeys.contains(group.key),
              onTap: () => toggleGame(group.key),
            ),
            if (expandedGameKeys.contains(group.key)) ...<Widget>[
              const SizedBox(height: 10),
              for (final campaign in group.campaigns) ...<Widget>[
                _CampaignTile(
                  campaign: campaign,
                  highlightReady: campaign.timeBasedDrops.any(
                    (drop) => drop.readyToCollect,
                  ),
                  claimingDropInstanceIds: widget.claimingDropInstanceIds,
                  onClaimDrop: widget.onClaimDrop,
                ),
                const SizedBox(height: 12),
              ],
            ],
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _InventorySummaryGrid extends StatelessWidget {
  final TwitchDropsSnapshot snapshot;

  const _InventorySummaryGrid({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final claimedCount = snapshot.allDrops
        .where((drop) => drop.isClaimed)
        .length;
    return _SummaryGrid(
      items: <_SummaryItem>[
        _SummaryItem(
          'Total Drops',
          snapshot.totalDropCount.toString(),
          Icons.inventory_2_rounded,
          Colors.white70,
        ),
        _SummaryItem(
          'Claimed',
          claimedCount.toString(),
          Icons.check_circle_rounded,
          _kGreen,
        ),
        _SummaryItem(
          'Ready to Claim',
          snapshot.readyDropCount.toString(),
          Icons.card_giftcard_rounded,
          _kGold,
        ),
        _SummaryItem(
          'In Progress',
          snapshot.watchingDropCount.toString(),
          Icons.timelapse_rounded,
          _kPurpleLight,
        ),
      ],
    );
  }
}

class _InventoryGameGroup {
  final String key;
  final String gameName;
  final String imageUrl;
  final int campaignCount;
  final int totalDrops;
  final int claimedDrops;
  final int readyDrops;
  final int inProgressDrops;
  final List<TwitchDropCampaign> campaigns;

  const _InventoryGameGroup({
    required this.key,
    required this.gameName,
    required this.imageUrl,
    required this.campaignCount,
    required this.totalDrops,
    required this.claimedDrops,
    required this.readyDrops,
    required this.inProgressDrops,
    required this.campaigns,
  });

  static List<_InventoryGameGroup> fromCampaigns(
    List<TwitchDropCampaign> campaigns,
  ) {
    final grouped = <String, List<TwitchDropCampaign>>{};
    for (final campaign in campaigns) {
      final key = campaign.gameName.trim().isEmpty
          ? 'Unknown Game'
          : campaign.gameName.trim();
      grouped.putIfAbsent(key, () => <TwitchDropCampaign>[]).add(campaign);
    }

    final groups = grouped.entries.map((entry) {
      final campaigns = List<TwitchDropCampaign>.from(entry.value)
        ..sort((a, b) {
          final aReady = a.timeBasedDrops.any((drop) => drop.readyToCollect);
          final bReady = b.timeBasedDrops.any((drop) => drop.readyToCollect);
          if (aReady != bReady) return bReady ? 1 : -1;
          final statusCompare = a.status.compareTo(b.status);
          if (statusCompare != 0) return statusCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      final drops = campaigns
          .expand((campaign) => campaign.timeBasedDrops)
          .toList(growable: false);
      return _InventoryGameGroup(
        key: entry.key.toLowerCase(),
        gameName: entry.key,
        imageUrl: campaigns
            .map((campaign) => campaign.imageUrl)
            .firstWhere((url) => url.trim().isNotEmpty, orElse: () => ''),
        campaignCount: campaigns.length,
        totalDrops: drops.length,
        claimedDrops: drops.where((drop) => drop.isClaimed).length,
        readyDrops: drops.where((drop) => drop.readyToCollect).length,
        inProgressDrops: drops
            .where((drop) => !drop.isClaimed && !drop.readyToCollect)
            .length,
        campaigns: campaigns,
      );
    }).toList();

    groups.sort((a, b) {
      if (a.readyDrops != b.readyDrops) return b.readyDrops - a.readyDrops;
      if (a.inProgressDrops != b.inProgressDrops) {
        return b.inProgressDrops - a.inProgressDrops;
      }
      return a.gameName.toLowerCase().compareTo(b.gameName.toLowerCase());
    });
    return groups;
  }
}

class _InventoryCompactRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final Color color;

  const _InventoryCompactRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _MiniBadge(text: trailing, color: color),
        ],
      ),
    );
  }
}

class _InventoryGameRow extends StatelessWidget {
  final _InventoryGameGroup group;
  final bool expanded;
  final VoidCallback onTap;

  const _InventoryGameRow({
    required this.group,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final complete =
        group.totalDrops > 0 && group.claimedDrops >= group.totalDrops;
    final color = group.readyDrops > 0
        ? _kGold
        : complete
        ? _kGreen
        : _kPurpleLight;
    final badgeText = group.readyDrops > 0
        ? '${group.readyDrops} ready'
        : complete
        ? 'completed'
        : '${group.inProgressDrops} in progress';

    return Material(
      color: _kPanel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: expanded
                  ? color.withValues(alpha: 0.24)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: <Widget>[
              _InventoryGameImage(imageUrl: group.imageUrl, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      group.gameName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${group.campaignCount} campaign・${group.claimedDrops}/${group.totalDrops} drops claimed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _MiniBadge(text: badgeText, color: color),
              const SizedBox(width: 8),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.chevron_right_rounded,
                color: expanded ? color : Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryGameImage extends StatelessWidget {
  final String imageUrl;
  final Color color;

  const _InventoryGameImage({required this.imageUrl, required this.color});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Icon(Icons.extension_rounded, color: color, size: 22)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.extension_rounded, color: color, size: 22);
              },
            ),
    );
  }
}

class _DropsStatsPage extends StatelessWidget {
  final TwitchDropsSnapshot snapshot;
  final List<TwitchDropsChannelPointsLeaderboardEntry> channelPointsLeaderboard;
  final bool loadingChannelPointsLeaderboard;
  final String? channelPointsLeaderboardError;
  final VoidCallback onRefreshChannelPointsLeaderboard;

  const _DropsStatsPage({
    required this.snapshot,
    required this.channelPointsLeaderboard,
    required this.loadingChannelPointsLeaderboard,
    required this.channelPointsLeaderboardError,
    required this.onRefreshChannelPointsLeaderboard,
  });

  @override
  Widget build(BuildContext context) {
    final currentDrop = _currentDrop(snapshot);
    final campaign = currentDrop == null
        ? null
        : _campaignForDrop(snapshot, currentDrop);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StatsSummaryGrid(
          snapshot: snapshot,
          totalChannelPoints: _totalChannelPoints,
        ),
        const SizedBox(height: 16),
        if (currentDrop == null)
          const _IdleStatusCard()
        else
          _CurrentDropStatusCard(drop: currentDrop, campaign: campaign),
        const SizedBox(height: 16),
        _ChannelPointsLeaderboardCard(
          entries: channelPointsLeaderboard,
          loading: loadingChannelPointsLeaderboard,
          errorText: channelPointsLeaderboardError,
          onRefresh: onRefreshChannelPointsLeaderboard,
        ),
      ],
    );
  }

  int? get _totalChannelPoints {
    if (channelPointsLeaderboard.isEmpty) return null;
    return channelPointsLeaderboard.fold<int>(
      0,
      (sum, entry) => sum + entry.points,
    );
  }

  TwitchDrop? _currentDrop(TwitchDropsSnapshot snapshot) {
    final drops = snapshot.watchingDrops
        .where((drop) => drop.requiredMinutesWatched > 0)
        .toList();
    if (drops.isEmpty) return null;
    drops.sort((a, b) {
      final activeCompare = (b.currentMinutesWatched > 0 ? 1 : 0).compareTo(
        a.currentMinutesWatched > 0 ? 1 : 0,
      );
      if (activeCompare != 0) return activeCompare;
      final progressCompare = b.progressPercent.compareTo(a.progressPercent);
      if (progressCompare != 0) return progressCompare;
      return a.remainingMinutes.compareTo(b.remainingMinutes);
    });
    return drops.first;
  }

  TwitchDropCampaign? _campaignForDrop(
    TwitchDropsSnapshot snapshot,
    TwitchDrop drop,
  ) {
    for (final campaign in snapshot.inventoryCampaigns) {
      if (campaign.id == drop.campaignId) return campaign;
    }
    return null;
  }
}

class _StatsSummaryGrid extends StatelessWidget {
  final TwitchDropsSnapshot snapshot;
  final int? totalChannelPoints;

  const _StatsSummaryGrid({
    required this.snapshot,
    required this.totalChannelPoints,
  });

  @override
  Widget build(BuildContext context) {
    final claimedCount = snapshot.allDrops
        .where((drop) => drop.isClaimed)
        .length;
    return _SummaryGrid(
      items: <_SummaryItem>[
        _SummaryItem(
          'Drops Claimed',
          claimedCount.toString(),
          Icons.card_giftcard_rounded,
          Colors.lightBlueAccent,
        ),
        _SummaryItem(
          'Channel Points',
          _formatNumber(totalChannelPoints),
          Icons.workspace_premium_rounded,
          _kPurpleLight,
        ),
        _SummaryItem(
          'Available Campaigns',
          snapshot.activeCampaignCount.toString(),
          Icons.trending_up_rounded,
          _kGreen,
        ),
        _SummaryItem(
          'In Progress',
          snapshot.watchingDropCount.toString(),
          Icons.access_time_rounded,
          Colors.lightBlueAccent,
        ),
      ],
    );
  }
}

class _CurrentDropStatusCard extends StatelessWidget {
  final TwitchDrop drop;
  final TwitchDropCampaign? campaign;

  const _CurrentDropStatusCard({required this.drop, required this.campaign});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGreen.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const _PulseDot(),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  '正在累積',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _kGreen,
                    fontSize: 12,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StatusDetailRow(label: '遊戲', value: drop.gameName),
          _StatusDetailRow(label: '活動', value: drop.campaignName),
          _StatusDetailRow(
            label: 'Current Drop',
            value: drop.displayRewardName,
          ),
          if (campaign != null)
            _StatusDetailRow(
              label: 'Account',
              value: campaign!.isAccountConnected ? '已連結' : '未連結',
              valueColor: campaign!.isAccountConnected
                  ? _kGreen
                  : Colors.orangeAccent,
            ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Text(
                'Progress',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${drop.currentMinutesWatched}/${drop.requiredMinutesWatched}m',
                style: const TextStyle(
                  color: _kGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: drop.progressRatio,
              color: _kGreen,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelPointsLeaderboardCard extends StatelessWidget {
  final List<TwitchDropsChannelPointsLeaderboardEntry> entries;
  final bool loading;
  final String? errorText;
  final VoidCallback onRefresh;

  const _ChannelPointsLeaderboardCard({
    required this.entries,
    required this.loading,
    required this.errorText,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final totalPoints = entries.fold<int>(0, (sum, item) => sum + item.points);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.emoji_events_outlined,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Channel Points Leaderboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '更新 Channel Points',
                onPressed: loading ? null : onRefresh,
                color: Colors.white70,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _kPurpleLight,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              loading
                  ? '正在讀取你追隨頻道的 Channel Points...'
                  : (errorText?.trim().isNotEmpty ?? false)
                  ? 'Channel Points 讀取失敗：$errorText'
                  : '目前沒有可顯示的 Channel Points balance。',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
          else ...<Widget>[
            for (final entry in entries.take(8)) ...<Widget>[
              _ChannelPointsLeaderboardRow(entry: entry),
              const SizedBox(height: 8),
            ],
            const Divider(color: Colors.white10, height: 18),
            _LeaderboardTotalRow(
              label: 'Total Streamers',
              value: entries.length.toString(),
            ),
            const SizedBox(height: 5),
            _LeaderboardTotalRow(
              label: 'Total Points',
              value: _formatNumber(totalPoints),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChannelPointsLeaderboardRow extends StatelessWidget {
  final TwitchDropsChannelPointsLeaderboardEntry entry;

  const _ChannelPointsLeaderboardRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final medalColor = switch (entry.rank) {
      1 => _kGold,
      2 => const Color(0xFFC0C6D4),
      3 => const Color(0xFFE28A3B),
      _ => const Color(0xFF9FB4C7),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: medalColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: medalColor.withValues(alpha: 0.30)),
            ),
            child: Text(
              entry.rank.toString(),
              style: TextStyle(
                color: medalColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _LeaderboardAvatar(imageUrl: entry.profileImageUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.displayName.isEmpty
                  ? entry.channelLogin
                  : entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                _formatNumber(entry.points),
                style: const TextStyle(
                  color: Color(0xFF9FB4C7),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'pts',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardAvatar extends StatelessWidget {
  final String imageUrl;

  const _LeaderboardAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    return ClipOval(
      child: Container(
        width: 38,
        height: 38,
        color: Colors.white.withValues(alpha: 0.08),
        child: url.isEmpty
            ? const Icon(Icons.person_rounded, color: Colors.white38, size: 20)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.person_rounded,
                    color: Colors.white38,
                    size: 20,
                  );
                },
              ),
      ),
    );
  }
}

class _LeaderboardTotalRow extends StatelessWidget {
  final String label;
  final String value;

  const _LeaderboardTotalRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9FB4C7),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF9FB4C7),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _StatusDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatusDetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Unknown' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdleStatusCard extends StatelessWidget {
  const _IdleStatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          style: BorderStyle.solid,
        ),
      ),
      child: const Column(
        children: <Widget>[
          Icon(Icons.extension_rounded, color: Colors.white38, size: 34),
          SizedBox(height: 12),
          Text(
            'Not currently earning any drops.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            '挑一個有 Drops 的直播觀看後，進度會顯示在這裡。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: _kGreen,
        borderRadius: BorderRadius.circular(999),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _kGreen.withValues(alpha: 0.45),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final List<_SummaryItem> items;

  const _SummaryGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: columns == 1 ? 74 : 88,
          ),
          itemBuilder: (context, index) => _SummaryCard(item: items[index]),
        );
      },
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryItem(this.label, this.value, this.icon, this.color);
}

class _SummaryCard extends StatelessWidget {
  final _SummaryItem item;

  const _SummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(item.icon, color: item.color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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

class _CampaignLinkText extends StatelessWidget {
  final String label;
  final String url;

  const _CampaignLinkText({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final text = url.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: _kPurpleLight,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => _openExternalUrl(text),
        icon: const Icon(Icons.open_in_new_rounded, size: 16),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

Future<void> _openExternalUrl(String rawUrl) async {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _formatNumber(int? value) {
  if (value == null) return '—';
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

String _formatDateTime(DateTime? value) {
  if (value == null) return 'Unknown';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CampaignTile extends StatelessWidget {
  final TwitchDropCampaign campaign;
  final bool highlightReady;
  final Set<String> claimingDropInstanceIds;
  final ValueChanged<TwitchDrop> onClaimDrop;

  const _CampaignTile({
    required this.campaign,
    required this.highlightReady,
    required this.claimingDropInstanceIds,
    required this.onClaimDrop,
  });

  @override
  Widget build(BuildContext context) {
    final sortedDrops = List<TwitchDrop>.from(campaign.timeBasedDrops)
      ..sort((a, b) {
        final priorityCompare = _dropPriority(a).compareTo(_dropPriority(b));
        if (priorityCompare != 0) return priorityCompare;
        return b.progressPercent.compareTo(a.progressPercent);
      });
    final hasReady = sortedDrops.any((drop) => drop.readyToCollect);
    final accent = hasReady
        ? _kGold
        : campaign.status.toUpperCase() == 'ACTIVE'
        ? _kGreen
        : _kPurpleLight;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (highlightReady || hasReady)
              ? _kGold.withValues(alpha: 0.34)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = TwitchResponsiveLayout.fromConstraints(constraints);
          final content = _CampaignDropsContent(
            campaign: campaign,
            sortedDrops: sortedDrops,
            accent: accent,
            claimingDropInstanceIds: claimingDropInstanceIds,
            onClaimDrop: onClaimDrop,
          );

          if (layout.shouldStackDropsCampaignCard) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _CampaignPoster(
                  imageUrl: campaign.imageUrl,
                  accent: accent,
                  compact: true,
                ),
                const SizedBox(height: 14),
                content,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CampaignPoster(
                imageUrl: campaign.imageUrl,
                accent: accent,
                compact: false,
              ),
              const SizedBox(width: 16),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  int _dropPriority(TwitchDrop drop) {
    if (drop.readyToCollect) return 0;
    if (!drop.isClaimed && drop.progressComplete) return 1;
    if (!drop.isClaimed) return 2;
    return 3;
  }
}

class _CampaignDropsContent extends StatelessWidget {
  final TwitchDropCampaign campaign;
  final List<TwitchDrop> sortedDrops;
  final Color accent;
  final Set<String> claimingDropInstanceIds;
  final ValueChanged<TwitchDrop> onClaimDrop;

  const _CampaignDropsContent({
    required this.campaign,
    required this.sortedDrops,
    required this.accent,
    required this.claimingDropInstanceIds,
    required this.onClaimDrop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    campaign.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${campaign.gameName}｜${sortedDrops.length} drops',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _MiniBadge(
              text: campaign.status.isEmpty ? 'UNKNOWN' : campaign.status,
              color: campaign.status.toUpperCase() == 'ACTIVE'
                  ? _kGreen
                  : _kGold,
            ),
            const SizedBox(width: 6),
            _MiniBadge(
              text: campaign.isAccountConnected ? '已連結' : '未連結',
              color: campaign.isAccountConnected
                  ? _kGreen
                  : Colors.orangeAccent,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (sortedDrops.isEmpty)
          const Text(
            '這個 campaign 沒有 time based drops。',
            style: TextStyle(color: Colors.white54),
          )
        else
          for (final drop in sortedDrops.take(8)) ...<Widget>[
            _DropRow(
              drop: drop,
              claiming: claimingDropInstanceIds.contains(
                drop.dropInstanceId.trim(),
              ),
              onClaimDrop: onClaimDrop,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _CampaignPoster extends StatelessWidget {
  final String imageUrl;
  final Color accent;
  final bool compact;

  const _CampaignPoster({
    required this.imageUrl,
    required this.accent,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    final width = compact ? double.infinity : 150.0;
    final height = compact ? 170.0 : 210.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Icon(
              Icons.extension_rounded,
              color: accent,
              size: compact ? 42 : 54,
            )
          : Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.network(
                  url,
                  fit: compact ? BoxFit.contain : BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.extension_rounded,
                      color: accent,
                      size: compact ? 42 : 54,
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      ),
                    );
                  },
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.10),
                        Colors.black.withValues(alpha: 0.42),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DropRow extends StatelessWidget {
  final TwitchDrop drop;
  final bool claiming;
  final ValueChanged<TwitchDrop> onClaimDrop;

  const _DropRow({
    required this.drop,
    required this.claiming,
    required this.onClaimDrop,
  });

  @override
  Widget build(BuildContext context) {
    final accent = drop.readyToCollect
        ? _kGold
        : drop.isClaimed
        ? _kGreen
        : _kPurpleLight;
    final canClaim =
        drop.readyToCollect && drop.dropInstanceId.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kPanelSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canClaim
              ? _kGold.withValues(alpha: 0.32)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _DropRewardThumbnail(
                imageUrl: drop.rewardImageUrl,
                accent: accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  drop.displayRewardName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _MiniBadge(text: drop.statusLabel, color: accent),
              const SizedBox(width: 8),
              SizedBox(
                height: 34,
                child: ElevatedButton.icon(
                  onPressed: canClaim && !claiming
                      ? () => onClaimDrop(drop)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGold,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white.withValues(
                      alpha: 0.08,
                    ),
                    disabledForegroundColor: Colors.white30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: claiming
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.card_giftcard_rounded, size: 16),
                  label: Text(claiming ? '領取中' : '領取'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: drop.progressRatio,
                    color: accent,
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${drop.currentMinutesWatched}/${drop.requiredMinutesWatched} 分鐘',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DropRewardThumbnail extends StatelessWidget {
  final String imageUrl;
  final Color accent;

  const _DropRewardThumbnail({required this.imageUrl, required this.accent});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Icon(Icons.card_giftcard_rounded, color: accent, size: 22)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.card_giftcard_rounded,
                  color: accent,
                  size: 22,
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SimpleInfoCard extends StatelessWidget {
  final String text;

  const _SimpleInfoCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white54)),
    );
  }
}
