import 'package:flutter/material.dart';

import '../../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../../localization/vioclass_localizations.dart';
import '../../../theme/twitch_ui_tokens.dart';
import '../../channel_points/twitch_channel_points_sheet_utils.dart';
import '../../chat/twitch_chat_composer_button_style.dart';
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
    return Tooltip(
      message: hasClaim
          ? '${context.vio.t('忠誠點數')} $fullLabel · ${context.vio.t('有可領獎勵')}'
          : '${context.vio.t('忠誠點數')} $fullLabel',
      child: TextButton(
        onPressed: onTap,
        style: twitchChatComposerButtonStyle(
          enabled: true,
          active: hasClaim,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChannelPointsIcon(iconUrl: iconUrl, hasClaim: hasClaim),
            if (balance != null) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1,
                  fontWeight: TwitchUiFontWeight.heavy,
                ),
              ),
            ],
          ],
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
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        style: twitchChatComposerButtonStyle(
          enabled: onTap != null,
          active: active,
        ),
        icon: Icon(icon, size: 16),
      ),
    );
  }
}
