part of twitch_watch_player_area;

class _CompactInlineVolumeControl extends StatelessWidget {
  final bool muted;
  final double volume;
  final double sliderWidth;
  final VoidCallback? onToggleMute;
  final ValueChanged<double>? onVolumeChanged;

  const _CompactInlineVolumeControl({
    required this.muted,
    required this.volume,
    required this.sliderWidth,
    required this.onToggleMute,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlainIconButton(
          tooltip: muted ? '取消靜音' : '靜音',
          icon: muted || volume <= 0 ? Icons.volume_off : Icons.volume_up,
          size: 21,
          dense: true,
          active: muted || volume <= 0,
          onPressed: onToggleMute,
        ),
        SizedBox(
          width: sliderWidth,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.4,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 5.5,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 10,
              ),
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
