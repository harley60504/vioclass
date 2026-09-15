import 'package:flutter/material.dart';

import '../../theme/twitch_ui_tokens.dart';

/// Shared Midnight Glass surface primitive.
class TwitchUiSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final List<BoxShadow> shadows;

  const TwitchUiSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.color,
    this.borderColor,
    this.radius = TwitchUiRadius.lg,
    this.shadows = TwitchUiShadows.none,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? TwitchUiColors.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? TwitchUiColors.borderSubtle,
          width: TwitchUiBorderWidth.standard,
        ),
        boxShadow: shadows,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Stateful desktop-friendly surface with centralized hover / selected visuals.
class TwitchUiInteractiveSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;
  final EdgeInsetsGeometry padding;
  final double radius;

  const TwitchUiInteractiveSurface({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.enabled = true,
    this.padding = EdgeInsets.zero,
    this.radius = TwitchUiRadius.lg,
  });

  @override
  State<TwitchUiInteractiveSurface> createState() =>
      _TwitchUiInteractiveSurfaceState();
}

class _TwitchUiInteractiveSurfaceState
    extends State<TwitchUiInteractiveSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onTap != null;
    final background = widget.selected
        ? TwitchUiColors.surfaceSelected
        : _hovered && enabled
        ? TwitchUiColors.surfaceHover
        : TwitchUiColors.surfaceCard;
    final border = widget.selected
        ? TwitchUiColors.borderInteractive
        : _hovered && enabled
        ? TwitchUiColors.borderStrong
        : TwitchUiColors.borderSubtle;

    return MouseRegion(
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled ? (_) => setState(() => _hovered = false) : null,
      child: AnimatedContainer(
        duration: TwitchUiMotion.fast,
        curve: TwitchUiMotion.standardCurve,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: border),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? widget.onTap : null,
            child: Opacity(
              opacity: widget.enabled ? 1 : TwitchUiOpacity.disabled,
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class TwitchUiStatusChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color? accent;

  const TwitchUiStatusChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accent ?? TwitchUiColors.primarySoft;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TwitchUiSpacing.space8,
        vertical: TwitchUiSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: selected
            ? TwitchUiColors.selectedOverlay
            : TwitchUiColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        border: Border.all(
          color: selected ? effectiveAccent : TwitchUiColors.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: effectiveAccent),
            const SizedBox(width: TwitchUiSpacing.space4),
          ],
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? effectiveAccent
                  : TwitchUiColors.textSecondary,
              fontSize: TwitchUiFontSize.chip,
              fontWeight: TwitchUiFontWeight.strong,
            ),
          ),
        ],
      ),
    );
  }
}
