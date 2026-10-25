import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../../theme/twitch_ui_tokens.dart';
import 'twitch_player_common_buttons.dart';
import 'twitch_player_volume_control.dart';

/// Anchored to its control, like the volume slider; never to the screen bottom.
class PlayerPopoverButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final double width;
  final double maxHeight;
  final VoidCallback? onOpen;
  final Widget Function(BuildContext, VoidCallback close) contentBuilder;

  const PlayerPopoverButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.contentBuilder,
    this.width = 260,
    this.maxHeight = 360,
    this.onOpen,
  });

  @override
  State<PlayerPopoverButton> createState() => _PlayerPopoverButtonState();
}

class _PlayerPopoverButtonState extends State<PlayerPopoverButton> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _anchor = GlobalKey();
  final _tapGroup = Object();
  bool _above = true;
  double _width = 260;
  double _height = 360;
  double _offsetX = 0;

  void _wake() => const VolumeControlInteraction().dispatch(context);

  void _toggle() {
    _wake();
    if (_portal.isShowing) {
      _portal.hide();
      return;
    }
    final box = _anchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final media = MediaQuery.of(context);
    final origin = box.localToGlobal(Offset.zero);
    final top = math.max(0.0, origin.dy - media.padding.top - 6);
    final bottom = math.max(
      0.0,
      media.size.height -
          media.padding.bottom -
          media.viewInsets.bottom -
          origin.dy -
          box.size.height -
          6,
    );
    _above = top >= widget.maxHeight || top >= bottom;
    _height = math.min(widget.maxHeight, _above ? top : bottom);
    _width = math.min(widget.width, math.max(1.0, media.size.width - 12));
    final center = origin.dx + box.size.width / 2;
    final left = (center - _width / 2).clamp(
      6.0,
      math.max(6.0, media.size.width - _width - 6),
    );
    _offsetX = left + _width / 2 - center;
    widget.onOpen?.call();
    _portal.show();
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    key: _anchor,
    link: _link,
    child: TapRegion(
      groupId: _tapGroup,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => Align(
          alignment: Alignment.topLeft,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: _above ? Alignment.topCenter : Alignment.bottomCenter,
            followerAnchor: _above
                ? Alignment.bottomCenter
                : Alignment.topCenter,
            offset: Offset(_offsetX, _above ? -4 : 4),
            child: TapRegion(
              groupId: _tapGroup,
              onTapOutside: (_) => _portal.hide(),
              child: MouseRegion(
                onHover: (_) => _wake(),
                child: Listener(
                  onPointerDown: (_) => _wake(),
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      GestureBinding.instance.pointerSignalResolver.register(
                        event,
                        (_) {},
                      );
                    }
                  },
                  child: Focus(
                    autofocus: true,
                    onKeyEvent: (_, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.escape) {
                        _portal.hide();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TooltipVisibility(
                      visible: false,
                      child: Material(
                        key: const ValueKey('player-anchored-popover'),
                        color: TwitchUiColors.playerOverlay,
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: TwitchUiColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                          width: _width,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: _height),
                            child: widget.contentBuilder(context, _portal.hide),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child: PlainIconButton(
          controlSize: 36,
          size: 22,
          tooltip: widget.tooltip,
          icon: widget.icon,
          onPressed: _toggle,
        ),
      ),
    ),
  );
}
