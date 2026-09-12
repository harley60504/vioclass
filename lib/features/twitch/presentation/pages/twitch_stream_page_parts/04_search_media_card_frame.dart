part of '../twitch_stream_page.dart';

class _SearchMediaCardFrame extends StatelessWidget {
  final String thumbnailUrl;
  final IconData fallbackIcon;
  final String topLeftPill;
  final String bottomRightPill;
  final String title;
  final String subtitle;
  final String avatarUrl;
  final VoidCallback onTap;

  const _SearchMediaCardFrame({
    required this.thumbnailUrl,
    required this.fallbackIcon,
    required this.topLeftPill,
    required this.bottomRightPill,
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.062),
                Colors.white.withValues(alpha: 0.022),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return TwitchCachedImageLayer(
                          imageUrl: thumbnailUrl,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          fit: BoxFit.cover,
                          fallbackColor: Colors.white.withValues(alpha: 0.06),
                          fallbackIcon: fallbackIcon,
                          fallbackIconColor: Colors.white38,
                        );
                      },
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _SearchMediaPill(text: topLeftPill),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: _SearchMediaPill(text: bottomRightPill),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 74,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          height: 1.14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: <Widget>[
                          TwitchCachedImageLayer.avatar(
                            imageUrl: avatarUrl,
                            size: 20,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchMediaPill extends StatelessWidget {
  final String text;

  const _SearchMediaPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
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

String _formatCount(int value) {
  if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)}萬';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}
