import 'package:flutter/material.dart';

import '../../../../models/playback/twitch_m3u8_variant.dart';
import '../../../localization/vioclass_localizations.dart';
import '../../../theme/twitch_ui_tokens.dart';

class QualityButton extends StatelessWidget {
  final List<TwitchM3u8Variant> variants;
  final TwitchM3u8Variant? currentVariant;
  final ValueChanged<TwitchM3u8Variant>? onChanged;

  const QualityButton({
    super.key,
    required this.variants,
    required this.currentVariant,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    return PopupMenuButton<TwitchM3u8Variant>(
      tooltip:
          '${l10n.t('畫質：')}${currentVariant?.displayName ?? currentVariant?.name ?? l10n.t('自動')}',
      color: TwitchUiColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TwitchUiRadius.md),
        side: const BorderSide(color: TwitchUiColors.border),
      ),
      icon: const Icon(
        Icons.tune_rounded,
        color: TwitchUiColors.textPrimary,
        size: TwitchUiControlSize.icon,
      ),
      onSelected: onChanged,
      itemBuilder: (context) {
        if (variants.isEmpty) {
          return [
            PopupMenuItem<TwitchM3u8Variant>(
              enabled: false,
              child: Text(
                l10n.t('尚未取得畫質'),
                style: const TextStyle(
                  color: TwitchUiColors.textMuted,
                  fontSize: TwitchUiFontSize.bodyCompact,
                ),
              ),
            ),
          ];
        }

        return variants.map((variant) {
          final selected =
              variant.name == currentVariant?.name &&
              variant.url == currentVariant?.url;
          return PopupMenuItem<TwitchM3u8Variant>(
            value: variant,
            child: Row(
              children: [
                SizedBox(
                  width: TwitchUiSpacing.space24,
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: TwitchUiColors.primarySoft,
                          size: TwitchUiControlSize.iconCompact,
                        )
                      : null,
                ),
                const SizedBox(width: TwitchUiSpacing.space8),
                Expanded(
                  child: Text(
                    variant.displayName.isNotEmpty
                        ? variant.displayName
                        : variant.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? TwitchUiColors.primarySoft
                          : TwitchUiColors.textPrimary,
                      fontSize: TwitchUiFontSize.body,
                      fontWeight: selected
                          ? TwitchUiFontWeight.strong
                          : TwitchUiFontWeight.medium,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
