// PATCH VERSION: twitch_player_common_buttons_stage221c_no_control_blur

part of twitch_watch_player_area;

class _RoundIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double glowOpacity;
  final VoidCallback? onPressed;
  final bool compact;
  final bool tiny;
  final double? height;

  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    this.iconColor = Colors.white,
    this.backgroundColor,
    this.borderColor,
    this.glowOpacity = 0.18,
    required this.onPressed,
    this.compact = false,
    this.tiny = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final size = height ?? (tiny ? 36.0 : compact ? 42.0 : 64.0);
    final radius = tiny ? 14.0 : compact ? 16.0 : 20.0;
    final effectiveBackgroundColor = backgroundColor ?? Colors.black.withOpacity(0.42);
    final effectiveBorderColor = borderColor ?? Colors.white.withOpacity(0.10);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: TwitchGlassSurface(
            borderRadius: BorderRadius.circular(radius),
            backgroundColor: effectiveBackgroundColor,
            borderColor: effectiveBorderColor,
            blurSigma: 0,
            boxShadow: const <BoxShadow>[],
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                color: iconColor,
                size: tiny ? 20 : compact ? 23 : 30,
              ),
            ),
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
