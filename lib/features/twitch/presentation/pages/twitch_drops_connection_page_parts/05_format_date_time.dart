part of '../twitch_drops_connection_page.dart';

String _formatDateTime(DateTime? value) {
  if (value == null) return '未知';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String _formatCampaignStatus(String status) {
  switch (status.trim().toUpperCase()) {
    case 'ACTIVE':
      return '進行中';
    case 'UPCOMING':
      return '即將開始';
    case 'EXPIRED':
      return '已結束';
    default:
      return '未知狀態';
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
                    '${campaign.gameName}｜${sortedDrops.length} 個 Drops 獎勵',
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
              text: _formatCampaignStatus(campaign.status),
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
            '這個活動沒有可顯示的累積型 Drops 獎勵。',
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
