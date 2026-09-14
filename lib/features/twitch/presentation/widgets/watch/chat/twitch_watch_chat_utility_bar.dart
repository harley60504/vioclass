import 'package:flutter/material.dart';

import '../../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../../localization/vioclass_localizations.dart';
import '../../../theme/twitch_ui_tokens.dart';
import '../../channel_points/twitch_channel_points_sheet_utils.dart';
import '../../shared/twitch_cached_image_layer.dart';
import '../../shared/twitch_default_channel_points_icon.dart';

class TwitchWatchChatUtilityBar extends StatelessWidget {
  final TwitchChannelPointsRuntimeSnapshot? channelPoints;
  final bool loadingEmotes;
  final VoidCallback onOpenChannelPoints;
  final VoidCallback onOpenEmotes;
  final VoidCallback? onOpenSpecialActions;
  final EdgeInsetsGeometry padding;

  const TwitchWatchChatUtilityBar({
    super.key,
    required this.channelPoints,
    required this.loadingEmotes,
    required this.onOpenChannelPoints,
    required this.onOpenEmotes,
    this.onOpenSpecialActions,
    this.padding = const EdgeInsets.fromLTRB(10, 7, 10, 4),
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    final balance = channelPoints?.balance;
    final pointsIconUrl = channelPoints?.pointsIconUrl;
    final hasClaim = (channelPoints?.availableClaimId ?? '').isNotEmpty;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          _ChannelPointsCompactButton(
            balance: balance,
            iconUrl: pointsIconUrl,
            hasClaim: hasClaim,
            onTap: onOpenChannelPoints,
          ),
          const SizedBox(width: 6),
          _UtilityButton(
            tooltip: l10n.t('特殊訊息'),
            icon: Icons.auto_awesome_rounded,
            active: false,
            onTap: onOpenSpecialActions,
          ),
          const SizedBox(width: 6),
          _UtilityButton(
            tooltip: l10n.t(loadingEmotes ? '貼圖載入中' : '貼圖'),
            icon: loadingEmotes ? Icons.sync_rounded : Icons.tag_faces_rounded,
            active: loadingEmotes,
            onTap: onOpenEmotes,
          ),
        ],
      ),
    );
  }
}

class _ChannelPointsCompactButton extends StatelessWidget {
  final int? balance;
  final String? iconUrl;
  final bool hasClaim;
  final VoidCallback onTap;

  const _ChannelPointsCompactButton({
    required this.balance,
    required this.iconUrl,
    required this.hasClaim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = balance == null
        ? '--'
        : formatChannelPointCompactNumber(balance!);
    final fullLabel = balance == null
        ? '--'
        : formatChannelPointFullNumber(balance!);
    final palette = TwitchUiColors.sheet.backplate;

    return Tooltip(
      message: hasClaim
          ? '${context.vio.t('忠誠點數')} $fullLabel · ${context.vio.t('有可領獎勵')}'
          : '${context.vio.t('忠誠點數')} $fullLabel',
      child: InkWell(
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        onTap: onTap,
        child: Container(
          height: 30,
          padding: const EdgeInsets.fromLTRB(8, 0, 9, 0),
          decoration: BoxDecoration(
            color: hasClaim ? palette.fillActive : palette.fill,
            borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
            border: Border.all(
              color: hasClaim ? palette.borderActive : palette.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChannelPointsIcon(iconUrl: iconUrl, hasClaim: hasClaim),
              if (balance != null) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: hasClaim
                        ? palette.foreground
                        : palette.foregroundMuted,
                    fontSize: 11,
                    fontWeight: TwitchUiFontWeight.heavy,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelPointsIcon extends StatelessWidget {
  final String? iconUrl;
  final bool hasClaim;

  const _ChannelPointsIcon({required this.iconUrl, required this.hasClaim});

  @override
  Widget build(BuildContext context) {
    final url = iconUrl?.trim();

    if (url != null && url.isNotEmpty) {
      return TwitchCachedImageLayer.avatar(
        imageUrl: url,
        size: 18,
        cacheWidth: 36,
        cacheHeight: 36,
        fallbackColor: Colors.transparent,
        errorWidget: _fallbackIcon(),
      );
    }

    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    if (hasClaim) {
      return const Icon(
        Icons.card_giftcard_rounded,
        color: TwitchUiColors.primarySoft,
        size: 17,
      );
    }

    return const TwitchDefaultChannelPointsIcon(size: 18);
  }
}

class _UtilityButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _UtilityButton({
    required this.tooltip,
    required this.icon,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = TwitchUiColors.sheet.backplate;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? palette.fillActive : palette.fill,
            borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
            border: Border.all(
              color: active ? palette.borderActive : palette.border,
            ),
          ),
          child: Icon(
            icon,
            size: 15,
            color: active ? palette.foreground : palette.foregroundMuted,
          ),
        ),
      ),
    );
  }
}
