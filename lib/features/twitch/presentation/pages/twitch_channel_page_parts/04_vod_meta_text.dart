part of '../twitch_channel_page.dart';

class _VodMetaText extends StatelessWidget {
  final TwitchChannelVideo video;
  final bool isGrowingArchive;

  const _VodMetaText({required this.video, required this.isGrowingArchive});

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(video.publishedAt ?? video.createdAt);
    final views = _formatCount(context, video.viewCount);
    final l10n = context.vio;
    return Text(
      isGrowingArchive
          ? l10n.t('目前直播中，點擊會進直播觀看頁')
          : l10n.isEnglish
          ? '$views ${l10n.t('次觀看')}${date.isEmpty ? '' : ' · $date'}'
          : '$views 次觀看${date.isEmpty ? '' : ' · $date'}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}';
  }

  String _formatCount(BuildContext context, int value) {
    if (context.vio.isEnglish && value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (context.vio.isEnglish && value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)}萬';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }
}

class _VodPill extends StatelessWidget {
  final String text;

  const _VodPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final label = text.trim();
    if (label.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ChannelAvatar extends StatelessWidget {
  final TwitchFollowedChannel channel;

  const _ChannelAvatar({required this.channel});

  @override
  Widget build(BuildContext context) {
    const size = 58.0;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: TwitchCachedImageLayer.avatar(
        imageUrl: channel.profileImageUrl,
        size: size,
        cacheWidth: 116,
        cacheHeight: 116,
        fallbackColor: Colors.white.withValues(alpha: 0.07),
        fallbackIconColor: Colors.white38,
      ),
    );
  }
}

class _CenteredAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  const _CenteredAction({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white38, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
