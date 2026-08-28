import 'package:flutter/material.dart';

import '../../../models/playback/twitch_m3u8_variant.dart';
import '../../theme/twitch_ui_tokens.dart';

class TwitchQualityOverlayMenu extends StatelessWidget {
  final List<TwitchM3u8Variant> variants;
  final TwitchM3u8Variant? currentVariant;
  final bool busy;
  final ValueChanged<TwitchM3u8Variant> onSelected;
  final VoidCallback onClose;

  const TwitchQualityOverlayMenu({
    super.key,
    required this.variants,
    required this.currentVariant,
    required this.busy,
    required this.onSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final groups = _groupVariants(variants);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 300,
        constraints: const BoxConstraints(maxHeight: 420),
        decoration: BoxDecoration(
          color: const Color(0xF218181B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 26,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2D))),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.high_quality_rounded,
                    size: 19,
                    color: TwitchUiColors.primarySoft,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '畫質',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '關閉',
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: variants.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        '尚未載入畫質清單',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        for (final group in groups)
                          if (group.variants.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 5),
                              child: Text(
                                group.title,
                                style: const TextStyle(
                                  color: TwitchUiColors.primarySoft,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            for (final variant in group.variants)
                              _QualityRow(
                                variant: variant,
                                selected:
                                    identical(variant, currentVariant) ||
                                    variant.url == currentVariant?.url,
                                busy: busy,
                                onTap: () => onSelected(variant),
                              ),
                          ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static List<_QualityGroup> _groupVariants(List<TwitchM3u8Variant> variants) {
    final source = <TwitchM3u8Variant>[];
    final high = <TwitchM3u8Variant>[];
    final medium = <TwitchM3u8Variant>[];
    final low = <TwitchM3u8Variant>[];
    final audio = <TwitchM3u8Variant>[];
    final other = <TwitchM3u8Variant>[];

    for (final variant in variants) {
      final text = '${variant.name} ${variant.videoGroupId ?? ''}'
          .toLowerCase();
      final isSource = text.contains('source') || text.contains('chunked');

      if (variant.isAudioOnly) {
        audio.add(variant);
      } else if (isSource) {
        source.add(variant);
      } else if (variant.height >= 720) {
        high.add(variant);
      } else if (variant.height >= 360) {
        medium.add(variant);
      } else if (variant.height > 0) {
        low.add(variant);
      } else {
        other.add(variant);
      }
    }

    int compare(TwitchM3u8Variant a, TwitchM3u8Variant b) {
      final heightCompare = b.height.compareTo(a.height);
      if (heightCompare != 0) return heightCompare;

      final fpsCompare = b.fpsRounded.compareTo(a.fpsRounded);
      if (fpsCompare != 0) return fpsCompare;

      final bandwidthCompare = (b.bandwidth ?? 0).compareTo(a.bandwidth ?? 0);
      if (bandwidthCompare != 0) return bandwidthCompare;

      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    }

    for (final list in [source, high, medium, low, audio, other]) {
      list.sort(compare);
    }

    return <_QualityGroup>[
      _QualityGroup('自動 / Source', source),
      _QualityGroup('高畫質', high),
      _QualityGroup('中畫質', medium),
      _QualityGroup('低畫質', low),
      _QualityGroup('音訊', audio),
      _QualityGroup('其他', other),
    ];
  }
}

class _QualityRow extends StatelessWidget {
  final TwitchM3u8Variant variant;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  const _QualityRow({
    required this.variant,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (variant.resolution != null) variant.resolution!,
      if (variant.frameRate != null) '${variant.frameRate!.round()} fps',
      if (variant.bandwidth != null) _formatBitrate(variant.bandwidth!),
      if (variant.isAudioOnly) '純音訊',
    ].join(' · ');

    return InkWell(
      onTap: busy || selected ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? TwitchUiColors.primarySoft : Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    variant.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBitrate(int bandwidth) {
    if (bandwidth >= 1000000) {
      final mbps = bandwidth / 1000000;
      return '${mbps.toStringAsFixed(mbps >= 10 ? 0 : 1)} Mbps';
    }

    if (bandwidth >= 1000) {
      return '${(bandwidth / 1000).round()} Kbps';
    }

    return '$bandwidth bps';
  }
}

class _QualityGroup {
  final String title;
  final List<TwitchM3u8Variant> variants;

  const _QualityGroup(this.title, this.variants);
}
