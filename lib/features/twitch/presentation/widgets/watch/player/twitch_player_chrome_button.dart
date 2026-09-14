import 'package:flutter/material.dart';

import '../../../theme/twitch_ui_tokens.dart';
import '../../shared/twitch_glass.dart';

/// Shared Midnight Glass control used by player chrome.
///
/// Keeps hover / selected / primary / disabled / busy visuals consistent while
/// feature widgets continue to own their existing callbacks and behavior.
class PlayerChromeButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final bool selected;
  final bool primary;
  final bool busy;
  final bool compact;
  final bool tiny;
  final double? height;
  final double? iconSize;
  final Color? accentColor;

  const PlayerChromeButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.label,
    this.selected = false,
    this.primary = false,
    this.busy = false,
    this.compact = false,
    this.tiny = false,
    this.height,
    this.iconSize,
    this.accentColor,
  });

  @override
  State<PlayerChromeButton> createState() => _PlayerChromeButtonState();
}

class _PlayerChromeButtonState extends State<PlayerChromeButton> {
  bool _hovered = false;

  bool get _enabled => widget.onPressed != null && !widget.busy;

  @override
  Widget build(BuildContext context) {
    final controlHeight = widget.height ??
        (widget.tiny
            ? TwitchUiControlSize.hitCompact
            : widget.compact
                ? TwitchUiControlSize.hit
                : TwitchUiControlSize.hitLarge);
    final iconSize = widget.iconSize ??
        (widget.tiny
            ? TwitchUiControlSize.iconCompact
            : widget.compact
                ? TwitchUiControlSize.icon
                : TwitchUiControlSize.iconLarge);
    final radius = widget.tiny ? TwitchUiRadius.sm : TwitchUiRadius.md;
    final accent = widget.accentColor ?? TwitchUiColors.primarySoft;

    final background = widget.primary
        ? (_hovered && _enabled
            ? TwitchUiColors.primaryHover
            : TwitchUiColors.primary)
        : widget.selected
            ? TwitchUiColors.surfaceSelected
            : _hovered && _enabled
                ? TwitchUiColors.surfaceHover
                : TwitchUiColors.surfacePlayer;
    final border = widget.primary
        ? TwitchUiColors.primarySoft.withValues(alpha: 0.42)
        : widget.selected
            ? accent.withValues(alpha: 0.48)
            : _hovered && _enabled
                ? TwitchUiColors.borderStrong
                : TwitchUiColors.border;
    final foreground = widget.primary
        ? TwitchUiColors.textOnAccent
        : widget.selected
            ? accent
            : TwitchUiColors.textPrimary;

    final label = widget.label?.trim();
    final hasLabel = label != null && label.isNotEmpty;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: _enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: _enabled ? (_) => setState(() => _hovered = false) : null,
        child: AnimatedOpacity(
          duration: TwitchUiMotion.fast,
          curve: TwitchUiMotion.standardCurve,
          opacity: _enabled || widget.busy ? 1 : TwitchUiOpacity.disabled,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _enabled ? widget.onPressed : null,
              child: AnimatedContainer(
                duration: TwitchUiMotion.fast,
                curve: TwitchUiMotion.standardCurve,
                child: TwitchGlassSurface(
                  borderRadius: BorderRadius.circular(radius),
                  backgroundColor: background,
                  borderColor: border,
                  blurSigma: 0,
                  boxShadow: TwitchUiShadows.none,
                  child: SizedBox(
                    height: controlHeight,
                    width: hasLabel ? null : controlHeight,
                    child: Padding(
                      padding: hasLabel
                          ? EdgeInsets.symmetric(
                              horizontal: widget.compact
                                  ? TwitchUiSpacing.space8
                                  : TwitchUiSpacing.space12,
                            )
                          : EdgeInsets.zero,
                      child: Center(
                        child: widget.busy
                            ? SizedBox(
                                width: iconSize * 0.78,
                                height: iconSize * 0.78,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: foreground,
                                ),
                              )
                            : hasLabel
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(widget.icon,
                                          color: foreground, size: iconSize),
                                      const SizedBox(
                                          width: TwitchUiSpacing.space8),
                                      Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: foreground,
                                          fontSize: TwitchUiFontSize.bodyCompact,
                                          fontWeight:
                                              TwitchUiFontWeight.strong,
                                        ),
                                      ),
                                    ],
                                  )
                                : Icon(widget.icon,
                                    color: foreground, size: iconSize),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
