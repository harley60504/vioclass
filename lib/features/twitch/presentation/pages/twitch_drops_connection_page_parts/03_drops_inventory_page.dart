part of '../twitch_drops_connection_page.dart';

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
            title: '已完成 Drops 獎勵',
            subtitle: '你在所有活動中已取得 $completedDrops 個 Drops 獎勵',
            trailing: '共 $completedDrops 個',
            color: _kGreen,
          ),
          const SizedBox(height: 12),
        ],
        if (groups.isEmpty)
          const _SimpleInfoCard(text: '目前庫存沒有 Drops 活動。')
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
          '全部獎勵',
          snapshot.totalDropCount.toString(),
          Icons.inventory_2_rounded,
          Colors.white70,
        ),
        _SummaryItem(
          '已領取',
          claimedCount.toString(),
          Icons.check_circle_rounded,
          _kGreen,
        ),
        _SummaryItem(
          '可領取',
          snapshot.readyDropCount.toString(),
          Icons.card_giftcard_rounded,
          _kGold,
        ),
        _SummaryItem(
          '進行中',
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
          ? '未知遊戲'
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
        ? '${group.readyDrops} 個可領取'
        : complete
        ? '已完成'
        : '${group.inProgressDrops} 個進行中';

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
                      '${group.campaignCount} 個活動・已領取 ${group.claimedDrops}/${group.totalDrops} 個 Drops 獎勵',
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
          '已領取獎勵',
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
          '可參與活動',
          snapshot.activeCampaignCount.toString(),
          Icons.trending_up_rounded,
          _kGreen,
        ),
        _SummaryItem(
          '進行中',
          snapshot.watchingDropCount.toString(),
          Icons.access_time_rounded,
          Colors.lightBlueAccent,
        ),
      ],
    );
  }
}
