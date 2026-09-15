part of '../twitch_drops_connection_page.dart';

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
          _StatusDetailRow(label: '目前獎勵', value: drop.displayRewardName),
          if (campaign != null)
            _StatusDetailRow(
              label: '帳號',
              value: campaign!.isAccountConnected ? '已連結' : '未連結',
              valueColor: campaign!.isAccountConnected
                  ? _kGreen
                  : Colors.orangeAccent,
            ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Text(
                '進度',
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
                  'Channel Points 排行榜',
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
                  ? 'Channel Points 暫時讀取失敗，稍後再試。'
                  : '目前沒有可顯示的 Channel Points 點數。',
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
              label: '頻道總數',
              value: entries.length.toString(),
            ),
            const SizedBox(height: 5),
            _LeaderboardTotalRow(
              label: '點數總計',
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
              value.isEmpty ? '未知' : value,
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
            '目前沒有正在累積的 Drops 獎勵。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            '挑一個有 Drops 獎勵的直播觀看後，進度會顯示在這裡。',
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
