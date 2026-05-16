part of twitch_watch_player_area;

class _RoundIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onPressed;
  final bool compact;
  final bool tiny;
  final double? height;

  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    this.iconColor = Colors.white,
    required this.onPressed,
    this.compact = false,
    this.tiny = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final size = height ?? (tiny ? 36.0 : compact ? 42.0 : 64.0);
    final radius = tiny ? 13.0 : compact ? 15.0 : 18.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xDD18181B),
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Icon(icon, color: iconColor, size: tiny ? 20 : compact ? 23 : 30),
          ),
        ),
      ),
    );
  }
}

class _PlainIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final bool active;
  final bool dense;

  const _PlainIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = 25,
    this.active = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!dense) {
      return IconButton(
        tooltip: tooltip,
        splashRadius: 22,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: active ? const Color(0xFFBF94FF) : Colors.white,
          size: size,
        ),
      );
    }

    final hitSize = (size + 16).clamp(34.0, 48.0).toDouble();

    return IconButton(
      tooltip: tooltip,
      splashRadius: hitSize / 2,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: hitSize, height: hitSize),
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: active ? const Color(0xFFBF94FF) : Colors.white,
        size: size,
      ),
    );
  }
}
