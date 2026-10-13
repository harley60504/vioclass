import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../localization/vioclass_localizations.dart';
import '../../../theme/twitch_ui_tokens.dart';
import 'twitch_player_common_buttons.dart';

class VolumeControlInteraction extends Notification {
  const VolumeControlInteraction();
}

class PlayerVolumeButton extends StatefulWidget {
  final bool muted;
  final double volume;
  final VoidCallback? onToggleMute;
  final ValueChanged<double>? onVolumeChanged;
  const PlayerVolumeButton({
    super.key,
    required this.muted,
    required this.volume,
    this.onToggleMute,
    this.onVolumeChanged,
  });
  @override
  State<PlayerVolumeButton> createState() => _VolumeButtonState();
}

class _VolumeButtonState extends State<PlayerVolumeButton> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _anchorKey = GlobalKey();
  final _tapGroup = Object();
  Timer? _closeTimer;
  bool _overButton = false;
  bool _overPopup = false;
  bool _dragging = false;
  bool _pinned = false;
  double _level = 0;
  bool _silent = false;
  double _popupHeight = 180;
  double _offsetX = 0;
  bool _above = true;

  @override
  void didUpdateWidget(covariant PlayerVolumeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging) _level = widget.volume.clamp(0.0, 100.0).toDouble();
    _silent = widget.muted;
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  void _wake() => const VolumeControlInteraction().dispatch(context);
  void _show() {
    _closeTimer?.cancel();
    _wake();
    if (_portal.isShowing) return;
    _level = widget.volume.clamp(0.0, 100.0).toDouble();
    _silent = widget.muted;
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final media = MediaQuery.of(context);
    final origin = box.localToGlobal(Offset.zero);
    final topSpace = math.max(0.0, origin.dy - media.padding.top - 6);
    final bottomSpace = math.max(
      0.0,
      media.size.height -
          media.padding.bottom -
          media.viewInsets.bottom -
          origin.dy -
          box.size.height -
          6,
    );
    _above = topSpace >= 180 || topSpace >= bottomSpace;
    _popupHeight = math.min(180.0, _above ? topSpace : bottomSpace);
    final anchorX = origin.dx + box.size.width / 2;
    _offsetX =
        anchorX.clamp(30.0, math.max(30.0, media.size.width - 30)) - anchorX;
    _portal.show();
  }

  void _hide() {
    _closeTimer?.cancel();
    _pinned = false;
    _portal.hide();
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted && !_overButton && !_overPopup && !_dragging && !_pinned) {
        _hide();
      }
    });
  }

  Widget _popup(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: CompositedTransformFollower(
      link: _link,
      showWhenUnlinked: false,
      targetAnchor: _above ? Alignment.topCenter : Alignment.bottomCenter,
      followerAnchor: _above ? Alignment.bottomCenter : Alignment.topCenter,
      offset: Offset(_offsetX, _above ? -4 : 4),
      child: TapRegion(
        groupId: _tapGroup,
        onTapOutside: (_) => _hide(),
        child: MouseRegion(
          onEnter: (_) {
            _overPopup = true;
            _closeTimer?.cancel();
            _wake();
          },
          onHover: (_) => _wake(),
          onExit: (_) {
            _overPopup = false;
            _scheduleClose();
          },
          child: Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                _hide();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Material(
              key: const ValueKey('player-volume-popover'),
              color: TwitchUiColors.surfaceRaised,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: TwitchUiColors.border),
              ),
              child: SizedBox(
                width: 52,
                height: _popupHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    children: [
                      Text(
                        '${_level.round()}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 10,
                              ),
                            ),
                            child: Slider(
                              autofocus: true,
                              value: _level,
                              min: 0,
                              max: 100,
                              onChangeStart: widget.onVolumeChanged == null
                                  ? null
                                  : (_) {
                                      _dragging = true;
                                      _closeTimer?.cancel();
                                      _wake();
                                    },
                              onChangeEnd: widget.onVolumeChanged == null
                                  ? null
                                  : (_) {
                                      _dragging = false;
                                      _scheduleClose();
                                    },
                              onChanged: widget.onVolumeChanged == null
                                  ? null
                                  : (value) {
                                      widget.onVolumeChanged!(value);
                                      _wake();
                                      setState(() {
                                        _level = value;
                                        if (value <= 0) _silent = true;
                                      });
                                    },
                            ),
                          ),
                        ),
                      ),
                      // Tooltip positioning cannot resolve a transform through
                      // the follower above. Keep its semantics, not its popup.
                      TooltipVisibility(
                        visible: false,
                        child: PlainIconButton(
                          controlSize: 30,
                          size: 18,
                          tooltip: context.vio.t(_silent ? '取消靜音' : '靜音'),
                          icon: _silent
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          onPressed: widget.onToggleMute == null
                              ? null
                              : () {
                                  widget.onToggleMute!();
                                  _wake();
                                  setState(() => _silent = !_silent);
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    key: _anchorKey,
    link: _link,
    child: TapRegion(
      groupId: _tapGroup,
      child: MouseRegion(
        onEnter: (_) {
          _overButton = true;
          _show();
        },
        onExit: (_) {
          _overButton = false;
          _scheduleClose();
        },
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: _popup,
          child: PlainIconButton(
            controlSize: 36,
            size: 22,
            tooltip: context.vio.t('音量'),
            icon: widget.muted || widget.volume <= 0
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            onPressed: () {
              if (_pinned) {
                _hide();
              } else {
                _pinned = true;
                _show();
              }
            },
          ),
        ),
      ),
    ),
  );
}

class CompactInlineVolumeControl extends StatelessWidget {
  final double? controlSize;
  final bool muted;
  final double volume;
  final double sliderWidth;
  final VoidCallback? onToggleMute;
  final ValueChanged<double>? onVolumeChanged;

  const CompactInlineVolumeControl({
    super.key,
    this.controlSize,
    required this.muted,
    required this.volume,
    required this.sliderWidth,
    required this.onToggleMute,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = muted || volume <= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlainIconButton(
          controlSize: controlSize,
          tooltip: context.vio.t(muted ? '取消靜音' : '靜音'),
          icon: inactive ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          size: TwitchUiControlSize.icon,
          dense: true,
          active: inactive,
          onPressed: onToggleMute,
        ),
        SizedBox(
          width: sliderWidth,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: inactive
                  ? TwitchUiColors.textMuted
                  : TwitchUiColors.primary,
              inactiveTrackColor: TwitchUiColors.borderStrong,
              thumbColor: inactive
                  ? TwitchUiColors.textSecondary
                  : TwitchUiColors.primarySoft,
              overlayColor: TwitchUiColors.selectedOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
            ),
            child: Slider(
              value: volume.clamp(0.0, 100.0).toDouble(),
              min: 0,
              max: 100,
              onChanged: onVolumeChanged,
            ),
          ),
        ),
      ],
    );
  }
}
