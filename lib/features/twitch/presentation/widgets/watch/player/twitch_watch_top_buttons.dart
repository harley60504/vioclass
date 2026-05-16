part of twitch_watch_player_area;

class _FollowButton extends StatelessWidget {
  final bool followed;
  final bool busy;
  final bool compact;
  final bool tiny;
  final double? height;
  final VoidCallback? onPressed;

  const _FollowButton({
    required this.followed,
    required this.busy,
    this.compact = false,
    this.tiny = false,
    this.height,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final visualHeight = height ?? (tiny ? 36.0 : compact ? 42.0 : 64.0);
    final size = visualHeight;
    final radius = tiny ? 13.0 : compact ? 15.0 : 18.0;

    return Tooltip(
      message: followed ? '取消追隨' : '追隨',
      child: Material(
        color: const Color(0xDD18181B),
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onPressed,
          child: Container(
            width: size,
            height: visualHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    followed ? Icons.favorite : Icons.favorite_border,
                    color: followed ? Colors.pinkAccent : Colors.white,
                    size: tiny ? 20 : compact ? 23 : 32,
                  ),
          ),
        ),
      ),
    );
  }
}

class _SubscribeButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool compact;
  final bool tiny;
  final double? height;

  const _SubscribeButton({
    required this.onPressed,
    this.compact = false,
    this.tiny = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final visualHeight = height ?? (tiny ? 36.0 : compact ? 42.0 : 64.0);
    final radius = tiny ? 13.0 : compact ? 15.0 : 18.0;

    return Material(
      color: const Color(0xDD18181B),
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: visualHeight,
          width: compact ? visualHeight : null,
          padding: compact ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: compact
              ? Icon(Icons.auto_awesome, color: Colors.white, size: tiny ? 19 : 22)
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Subscribe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.auto_awesome, color: Colors.white, size: 19),
                  ],
                ),
        ),
      ),
    );
  }
}
