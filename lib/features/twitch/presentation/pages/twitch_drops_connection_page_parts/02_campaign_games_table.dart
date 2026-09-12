part of '../twitch_drops_connection_page.dart';

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
        ? '${group.readyDrops} 個可領取'
        : '${group.campaigns.length} 個活動';
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
                      group.gameName.isEmpty ? '未知遊戲' : group.gameName,
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
                            label: '活動',
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
                      active ? '進行中' : '即將開始',
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
                        '${group.campaigns.length} 個活動・${group.totalDrops} 個 Drops 獎勵',
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
                  tooltip: '關閉',
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
                campaign.name.isEmpty ? '未命名活動' : campaign.name,
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
              text: _formatCampaignStatus(campaign.status),
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
            _MiniBadge(text: '${sortedDrops.length} 個 Drops 獎勵', color: _kGold),
            if (campaign.allowedChannels.isNotEmpty)
              _MiniBadge(
                text: '${campaign.allowedChannels.length} 個頻道',
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
              _CampaignLinkText(label: '連結帳號', url: campaign.accountLinkUrl),
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
            '這個活動沒有可顯示的 Drops 獎勵。',
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
