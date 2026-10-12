import 'package:flutter/material.dart';

import '../../../localization/vioclass_localizations.dart';
import '../../../theme/twitch_ui_tokens.dart';
import 'twitch_player_common_buttons.dart';
import '../../responsive/twitch_responsive_sheet.dart';

class PlayerVolumeButton extends StatelessWidget {
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
  Widget build(BuildContext context) => PlainIconButton(
    controlSize: 36,
    size: 22,
    tooltip: context.vio.t('音量'),
    icon: muted || volume <= 0
        ? Icons.volume_off_rounded
        : Icons.volume_up_rounded,
    onPressed: () {
      var level = volume.clamp(0.0, 100.0).toDouble();
      var silent = muted;
      showTwitchUnifiedSheet<void>(
        context: context,
        title: context.vio.t('音量'),
        icon: Icons.volume_up_rounded,
        size: TwitchUnifiedSheetSize.compact,
        portraitHeightFactor: 0.3,
        showRefresh: false,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                PlainIconButton(
                  controlSize: 36,
                  size: 22,
                  tooltip: context.vio.t(silent ? '取消靜音' : '靜音'),
                  icon: silent
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  onPressed: onToggleMute == null
                      ? null
                      : () {
                          onToggleMute!();
                          update(() => silent = !silent);
                        },
                ),
                Expanded(
                  child: Slider(
                    value: level,
                    min: 0,
                    max: 100,
                    onChanged: onVolumeChanged == null
                        ? null
                        : (value) {
                            onVolumeChanged!(value);
                            update(() {
                              level = value;
                              if (value <= 0) silent = true;
                            });
                          },
                  ),
                ),
                SizedBox(width: 36, child: Text('${level.round()}')),
              ],
            ),
          ),
        ),
      );
    },
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
