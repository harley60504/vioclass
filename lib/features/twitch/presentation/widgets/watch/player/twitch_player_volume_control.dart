import 'package:flutter/material.dart';

import '../../../localization/vioclass_localizations.dart';
import '../../../theme/twitch_ui_tokens.dart';
import 'twitch_player_common_buttons.dart';

class CompactInlineVolumeControl extends StatelessWidget {
  final bool muted;
  final double volume;
  final double sliderWidth;
  final VoidCallback? onToggleMute;
  final ValueChanged<double>? onVolumeChanged;

  const CompactInlineVolumeControl({
    super.key,
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
