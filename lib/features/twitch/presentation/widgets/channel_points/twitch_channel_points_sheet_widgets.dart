// PATCH VERSION: twitch_channel_points_sheet_widgets_stage216_transparent_reward_cards

import 'package:flutter/material.dart';

import '../../localization/twitch_reward_localizer.dart';

import 'twitch_channel_points_sheet_utils.dart';

class ChannelPointsHeader extends StatelessWidget {
  final String title;
  final String? iconUrl;
  final int? balance;
  final int rewardCount;
  final int availableCount;
  final bool loading;
  final Future<void> Function() onRefresh;

  const ChannelPointsHeader({
    required this.title,
    required this.iconUrl,
    required this.balance,
    required this.rewardCount,
    required this.availableCount,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF2A1740).withOpacity(0.92),
            const Color(0xFF15141C).withOpacity(0.96),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: const Color(0xFF9146FF).withOpacity(0.22)),
        ),
      ),
      child: Row(
        children: [
          _PointsIcon(iconUrl: iconUrl, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title · $availableCount/$rewardCount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
          _StatusChip(
            iconUrl: iconUrl,
            label: balance == null ? '--' : formatChannelPointFullNumber(balance!),
            highlight: balance != null,
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: loading ? null : onRefresh,
            tooltip: '重新整理忠誠點數',
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '關閉',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class ChannelPointsErrorBanner extends StatelessWidget {
  final String label;
  final String message;

  const ChannelPointsErrorBanner({
    required this.label,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.35)),
      ),
      child: Text(
        '$label：$message',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.orangeAccent,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ChannelPointsEmptyRewards extends StatelessWidget {
  final bool hasSnapshot;
  final bool loading;
  final Future<void> Function() onRefresh;

  const ChannelPointsEmptyRewards({
    required this.hasSnapshot,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.040),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF9146FF).withOpacity(0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.redeem_rounded, color: Color(0xFFBF94FF), size: 30),
              const SizedBox(height: 10),
              Text(
                hasSnapshot ? '目前沒有可顯示的忠誠點數獎勵。' : '尚未載入忠誠點數資料。',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                '請重新整理，或確認目前頻道是否有開放忠誠點數獎勵。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新整理'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChannelPointsRewardTile extends StatelessWidget {
  final Map<String, dynamic> reward;
  final int? balance;
  final String? pointsIconUrl;
  final Future<void> Function() onTap;

  const ChannelPointsRewardTile({
    required this.reward,
    required this.balance,
    required this.pointsIconUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title =
        TwitchRewardLocalizer.title(reward['title']?.toString() ?? 'Reward');
    final prompt = reward['prompt']?.toString() ?? '';
    final imageUrl = resolveChannelPointRewardDisplayImageUrl(reward);
    final cost = readChannelPointInt(reward['cost']);
    final color = parseChannelPointColor(reward['backgroundColor']?.toString());
    final available = isChannelPointRewardAvailable(reward, balance: balance);
    final statusText = channelPointRewardStatusText(reward, balance: balance);
    final enough = balance == null || balance! >= cost;

    return Opacity(
      opacity: available ? 1 : 0.50,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: available ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.038),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: available
                    ? const Color(0xFF9146FF).withOpacity(0.26)
                    : Colors.white.withOpacity(0.060),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: available
                      ? const Color(0xFF9146FF).withOpacity(0.070)
                      : Colors.black.withOpacity(0.080),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  right: 8,
                  child: _CostChip(
                    cost: cost,
                    iconUrl: pointsIconUrl,
                    enough: enough,
                    compact: true,
                  ),
                ),
                if (!available)
                  const Positioned(
                    right: 10,
                    bottom: 10,
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white30,
                      size: 18,
                    ),
                  )
                else
                  const Positioned(
                    right: 8,
                    bottom: 8,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white38,
                      size: 20,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 30, 10, 22),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.82),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: color.withOpacity(0.18),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: imageUrl.isEmpty
                              ? const Center(
                                  child: Icon(
                                    Icons.diamond_outlined,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                )
                              : Image.network(
                                  imageUrl,
                                  width: 78,
                                  height: 78,
                                  cacheWidth: 156,
                                  cacheHeight: 156,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.low,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.diamond_outlined,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            height: 1.12,
                          ),
                        ),
                        if (prompt.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            prompt,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ],
                        if (statusText != null && !available) ...[
                          const SizedBox(height: 6),
                          _StatusBadge(label: statusText, warning: true),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CostChip extends StatelessWidget {
  final int cost;
  final String? iconUrl;
  final bool enough;
  final bool compact;

  const _CostChip({
    required this.cost,
    required this.iconUrl,
    required this.enough,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enough ? const Color(0xFFBF94FF) : Colors.redAccent;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 7,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PointsIcon(iconUrl: iconUrl, size: compact ? 12 : 13),
          SizedBox(width: compact ? 3 : 4),
          Text(
            formatChannelPointFullNumber(cost),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;

  const _MiniBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool warning;

  const _StatusBadge({required this.label, required this.warning});

  @override
  Widget build(BuildContext context) {
    final color = warning ? Colors.orangeAccent : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String? iconUrl;
  final String label;
  final bool highlight;

  const _StatusChip({
    required this.iconUrl,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? const Color(0xFFBF94FF) : Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(highlight ? 0.13 : 0.06),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: color.withOpacity(highlight ? 0.30 : 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PointsIcon(iconUrl: iconUrl, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsIcon extends StatelessWidget {
  final String? iconUrl;
  final double size;

  const _PointsIcon({required this.iconUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = iconUrl?.trim();

    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: size,
        height: size,
        cacheWidth: (size * 2).round(),
        cacheHeight: (size * 2).round(),
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => _FallbackPointsIcon(size: size),
      );
    }

    return _FallbackPointsIcon(size: size);
  }
}

class _FallbackPointsIcon extends StatelessWidget {
  final double size;

  const _FallbackPointsIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FallbackPointsIconPainter(),
    );
  }
}

class _FallbackPointsIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.16
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE7F7FF);

    canvas.drawCircle(center, radius * 0.62, paint);
    canvas.drawCircle(center, radius * 0.28, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
