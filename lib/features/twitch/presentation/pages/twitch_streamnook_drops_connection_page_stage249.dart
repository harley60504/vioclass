import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/core/twitch_api_client.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/drops/twitch_streamnook_drops_connection_check_stage249.dart';
import '../../services/drops/twitch_streamnook_drops_connection_service_stage249.dart';
import '../../services/drops/twitch_streamnook_drops_snapshot_stage249.dart';
import '../../services/notifications/twitch_app_notification_service_stage249.dart';

const Color _kStage249Purple = Color(0xFF9146FF);
const Color _kStage249PurpleLight = Color(0xFFBF94FF);
const Color _kStage249Panel = Color(0xFF18181B);
const Color _kStage249PanelSoft = Color(0xFF202027);
const Color _kStage249Background = Color(0xFF0E0E10);
const Color _kStage249Green = Color(0xFF5CFFB1);
const Color _kStage249Gold = Color(0xFFFFC857);

class TwitchStreamNookDropsConnectionPageStage249 extends StatefulWidget {
  final TwitchApiClient apiClient;
  final TwitchDropsAuthService dropsAuthService;

  const TwitchStreamNookDropsConnectionPageStage249({
    super.key,
    required this.apiClient,
    required this.dropsAuthService,
  });

  @override
  State<TwitchStreamNookDropsConnectionPageStage249> createState() =>
      _TwitchStreamNookDropsConnectionPageStage249State();
}

class _TwitchStreamNookDropsConnectionPageStage249State
    extends State<TwitchStreamNookDropsConnectionPageStage249> {
  late final TwitchStreamNookDropsConnectionServiceStage249 service;

  TwitchStreamNookDropsConnectionCheckStage249? result;
  final Set<String> claimingDropInstanceIds = <String>{};
  bool checking = false;
  bool showDebug = false;
  String statusText = '尚未載入 Drops。';

  @override
  void initState() {
    super.initState();
    service = TwitchStreamNookDropsConnectionServiceStage249(
      apiClient: widget.apiClient,
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
              : '已整理 ${snapshot.inventoryCampaignCount} 個 inventory campaign、${snapshot.totalDropCount} 個 drop。',
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

  Future<void> claimDrop(TwitchStreamNookDropStage249 drop) async {
    final dropInstanceId = drop.dropInstanceId.trim();
    if (dropInstanceId.isEmpty || claimingDropInstanceIds.contains(dropInstanceId)) {
      return;
    }

    setState(() {
      claimingDropInstanceIds.add(dropInstanceId);
    });

    final claimResult = await service.collectDrop(dropInstanceId: dropInstanceId);

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
      backgroundColor: _kStage249Background,
      appBar: AppBar(
        backgroundColor: _kStage249Background,
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
                color: _kStage249Purple.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kStage249Purple.withOpacity(0.32)),
              ),
              child: const Icon(Icons.card_giftcard_rounded, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Drops',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: showDebug ? '隱藏 Debug' : '顯示 Debug',
            onPressed: () => setState(() => showDebug = !showDebug),
            icon: Icon(showDebug ? Icons.bug_report : Icons.bug_report_outlined),
          ),
          IconButton(
            tooltip: '重新整理 Drops',
            onPressed: checking ? null : () => unawaited(runCheck()),
            icon: checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kStage249PurpleLight,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: _kStage249Purple,
        onRefresh: () => runCheck(showToast: false),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: <Widget>[
            _HeroCard(
              connected: connected,
              checking: checking,
              statusText: statusText,
              snapshot: snapshot,
              onRefresh: () => unawaited(runCheck()),
            ),
            const SizedBox(height: 14),
            if (snapshot == null)
              _EmptyDropsCard(
                checking: checking,
                connected: connected,
                statusText: statusText,
              )
            else
              _DropsDashboard(
                snapshot: snapshot,
                claimingDropInstanceIds: claimingDropInstanceIds,
                onClaimDrop: claimDrop,
              ),
            if (showDebug && current != null) ...<Widget>[
              const SizedBox(height: 14),
              _DebugResultCard(current: current),
              const SizedBox(height: 14),
              _PreviewCard(
                title: 'Inventory response preview',
                subtitle: current.inventoryRootSummary,
                text: current.inventoryPreview,
              ),
              const SizedBox(height: 14),
              _PreviewCard(
                title: 'Campaigns response preview',
                subtitle: current.campaignsRootSummary,
                text: current.campaignsPreview,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool connected;
  final bool checking;
  final String statusText;
  final TwitchStreamNookDropsSnapshotStage249? snapshot;
  final VoidCallback onRefresh;

  const _HeroCard({
    required this.connected,
    required this.checking,
    required this.statusText,
    required this.snapshot,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final readyCount = snapshot?.readyDropCount ?? 0;
    final watchingCount = snapshot?.watchingDropCount ?? 0;
    final campaignCount = snapshot?.inventoryCampaignCount ?? 0;
    final activeCount = snapshot?.activeCampaignCount ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            _kStage249Purple.withOpacity(0.26),
            _kStage249Panel,
            _kStage249Panel,
          ],
        ),
        border: Border.all(
          color: readyCount > 0
              ? _kStage249Gold.withOpacity(0.48)
              : connected
                  ? _kStage249Green.withOpacity(0.32)
                  : Colors.white.withOpacity(0.10),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    readyCount > 0
                        ? Icons.notifications_active_rounded
                        : connected
                            ? Icons.check_circle_rounded
                            : Icons.cable_rounded,
                    color: readyCount > 0
                        ? _kStage249Gold
                        : connected
                            ? _kStage249Green
                            : _kStage249PurpleLight,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      readyCount > 0 ? '有 $readyCount 個 Drops 可領取' : statusText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                snapshot == null
                    ? '從 StreamNook-style Drops API 載入 Inventory 與 Campaigns。'
                    : 'Inventory $campaignCount 個 campaign，Active campaigns $activeCount，進行中 $watchingCount，可領取 $readyCount。',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );

          final actions = Row(
            mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
            children: <Widget>[
              Expanded(
                flex: compact ? 1 : 0,
                child: ElevatedButton.icon(
                  onPressed: checking ? null : onRefresh,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kStage249Purple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(142, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(checking ? '更新中' : '更新 Drops'),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                titleBlock,
                const SizedBox(height: 16),
                actions,
              ],
            );
          }

          return Row(
            children: <Widget>[
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _EmptyDropsCard extends StatelessWidget {
  final bool checking;
  final bool connected;
  final String statusText;

  const _EmptyDropsCard({
    required this.checking,
    required this.connected,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: _kStage249Panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            checking ? Icons.sync_rounded : Icons.inventory_2_outlined,
            color: _kStage249PurpleLight,
            size: 46,
          ),
          const SizedBox(height: 12),
          Text(
            checking ? '正在載入 Drops...' : statusText,
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

class _DropsDashboard extends StatelessWidget {
  final TwitchStreamNookDropsSnapshotStage249 snapshot;
  final Set<String> claimingDropInstanceIds;
  final ValueChanged<TwitchStreamNookDropStage249> onClaimDrop;

  const _DropsDashboard({
    required this.snapshot,
    required this.claimingDropInstanceIds,
    required this.onClaimDrop,
  });

  @override
  Widget build(BuildContext context) {
    final campaigns = _sortedCampaigns(snapshot.inventoryCampaigns);
    final readyCampaigns = campaigns
        .where((campaign) => campaign.timeBasedDrops.any((drop) => drop.readyToCollect))
        .toList(growable: false);
    final activeCampaigns = campaigns
        .where((campaign) => campaign.status.toUpperCase() == 'ACTIVE')
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SummaryGrid(snapshot: snapshot),
        const SizedBox(height: 14),
        if (snapshot.readyDrops.isNotEmpty) ...<Widget>[
          _SectionHeader(
            icon: Icons.card_giftcard_rounded,
            title: '可領取 Drops',
            subtitle: '${snapshot.readyDropCount} 個 ready drop',
            color: _kStage249Gold,
          ),
          const SizedBox(height: 10),
          for (final campaign in readyCampaigns) ...<Widget>[
            _CampaignTile(
              campaign: campaign,
              highlightReady: true,
              claimingDropInstanceIds: claimingDropInstanceIds,
              onClaimDrop: onClaimDrop,
            ),
            const SizedBox(height: 12),
          ],
        ],
        _SectionHeader(
          icon: Icons.play_circle_rounded,
          title: '進行中 / Inventory',
          subtitle: '${snapshot.inventoryCampaignCount} 個 campaign，ACTIVE ${activeCampaigns.length} 個',
          color: _kStage249PurpleLight,
        ),
        const SizedBox(height: 10),
        if (campaigns.isEmpty)
          const _SimpleInfoCard(text: '目前 Inventory 沒有 Drops campaign。')
        else
          for (final campaign in campaigns.take(20)) ...<Widget>[
            _CampaignTile(
              campaign: campaign,
              highlightReady: false,
              claimingDropInstanceIds: claimingDropInstanceIds,
              onClaimDrop: onClaimDrop,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  List<TwitchStreamNookDropCampaignStage249> _sortedCampaigns(
    List<TwitchStreamNookDropCampaignStage249> campaigns,
  ) {
    final sorted = List<TwitchStreamNookDropCampaignStage249>.from(campaigns);
    sorted.sort((a, b) {
      final priorityCompare = _campaignPriority(a).compareTo(_campaignPriority(b));
      if (priorityCompare != 0) return priorityCompare;
      final progressCompare = _campaignBestProgress(b).compareTo(_campaignBestProgress(a));
      if (progressCompare != 0) return progressCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  int _campaignPriority(TwitchStreamNookDropCampaignStage249 campaign) {
    final hasReady = campaign.timeBasedDrops.any((drop) => drop.readyToCollect);
    if (hasReady) return 0;
    if (campaign.status.toUpperCase() == 'ACTIVE') return 1;
    final hasWatching = campaign.timeBasedDrops.any((drop) => !drop.isClaimed);
    if (hasWatching) return 2;
    return 3;
  }

  int _campaignBestProgress(TwitchStreamNookDropCampaignStage249 campaign) {
    if (campaign.timeBasedDrops.isEmpty) return 0;
    return campaign.timeBasedDrops
        .map((drop) => drop.progressPercent)
        .fold<int>(0, (previous, value) => value > previous ? value : previous);
  }
}

class _SummaryGrid extends StatelessWidget {
  final TwitchStreamNookDropsSnapshotStage249 snapshot;

  const _SummaryGrid({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final items = <_SummaryItem>[
      _SummaryItem('可領取', snapshot.readyDropCount.toString(), Icons.card_giftcard_rounded, _kStage249Gold),
      _SummaryItem('進行中', snapshot.watchingDropCount.toString(), Icons.timelapse_rounded, _kStage249PurpleLight),
      _SummaryItem('Drops', snapshot.totalDropCount.toString(), Icons.inventory_2_rounded, Colors.lightBlueAccent),
      _SummaryItem('未連結', snapshot.unlinkedCampaignCount.toString(), Icons.link_off_rounded, Colors.orangeAccent),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980 ? 4 : constraints.maxWidth >= 560 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 4.2 : 2.8,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kStage249Panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: item.color.withOpacity(0.22)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
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
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
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
  final TwitchStreamNookDropCampaignStage249 campaign;
  final bool highlightReady;
  final Set<String> claimingDropInstanceIds;
  final ValueChanged<TwitchStreamNookDropStage249> onClaimDrop;

  const _CampaignTile({
    required this.campaign,
    required this.highlightReady,
    required this.claimingDropInstanceIds,
    required this.onClaimDrop,
  });

  @override
  Widget build(BuildContext context) {
    final sortedDrops = List<TwitchStreamNookDropStage249>.from(campaign.timeBasedDrops)
      ..sort((a, b) {
        final priorityCompare = _dropPriority(a).compareTo(_dropPriority(b));
        if (priorityCompare != 0) return priorityCompare;
        return b.progressPercent.compareTo(a.progressPercent);
      });
    final hasReady = sortedDrops.any((drop) => drop.readyToCollect);
    final accent = hasReady ? _kStage249Gold : campaign.status.toUpperCase() == 'ACTIVE' ? _kStage249Green : _kStage249PurpleLight;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kStage249Panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (highlightReady || hasReady) ? _kStage249Gold.withOpacity(0.34) : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.extension_rounded, color: accent, size: 21),
              ),
              const SizedBox(width: 12),
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
                        fontSize: 15,
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
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _MiniBadge(
                text: campaign.status.isEmpty ? 'UNKNOWN' : campaign.status,
                color: campaign.status.toUpperCase() == 'ACTIVE' ? _kStage249Green : _kStage249Gold,
              ),
              const SizedBox(width: 6),
              _MiniBadge(
                text: campaign.isAccountConnected ? '已連結' : '未連結',
                color: campaign.isAccountConnected ? _kStage249Green : Colors.orangeAccent,
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
                claiming: claimingDropInstanceIds.contains(drop.dropInstanceId.trim()),
                onClaimDrop: onClaimDrop,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  int _dropPriority(TwitchStreamNookDropStage249 drop) {
    if (drop.readyToCollect) return 0;
    if (!drop.isClaimed && drop.progressComplete) return 1;
    if (!drop.isClaimed) return 2;
    return 3;
  }
}

class _DropRow extends StatelessWidget {
  final TwitchStreamNookDropStage249 drop;
  final bool claiming;
  final ValueChanged<TwitchStreamNookDropStage249> onClaimDrop;

  const _DropRow({
    required this.drop,
    required this.claiming,
    required this.onClaimDrop,
  });

  @override
  Widget build(BuildContext context) {
    final accent = drop.readyToCollect
        ? _kStage249Gold
        : drop.isClaimed
            ? _kStage249Green
            : _kStage249PurpleLight;
    final canClaim = drop.readyToCollect && drop.dropInstanceId.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kStage249PanelSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canClaim ? _kStage249Gold.withOpacity(0.32) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
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
                  onPressed: canClaim && !claiming ? () => onClaimDrop(drop) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kStage249Gold,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white.withOpacity(0.08),
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
                    backgroundColor: Colors.white.withOpacity(0.10),
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

class _MiniBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.32)),
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
        color: _kStage249Panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white54),
      ),
    );
  }
}

class _DebugResultCard extends StatelessWidget {
  final TwitchStreamNookDropsConnectionCheckStage249 current;

  const _DebugResultCard({required this.current});

  @override
  Widget build(BuildContext context) {
    return _DebugCard(
      title: 'Debug Result',
      subtitle: 'connection / parsed snapshot',
      text: current.prettyJson,
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String text;

  const _PreviewCard({
    required this.title,
    required this.subtitle,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return _DebugCard(
      title: title,
      subtitle: subtitle,
      text: text.isEmpty ? '沒有 response preview。' : text,
    );
  }
}

class _DebugCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String text;

  const _DebugCard({
    required this.title,
    required this.subtitle,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kStage249Panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              height: 1.35,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
