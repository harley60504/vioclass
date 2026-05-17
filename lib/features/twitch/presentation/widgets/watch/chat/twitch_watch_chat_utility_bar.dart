// PATCH VERSION: twitch_watch_chat_utility_bar_stage215_more_transparent_chips
//
// Stage 209: remove the extra section background. Only the actual chips/buttons
// keep translucent styling.
// Stage 215: make channel-points and emote chips lighter / more transparent so
// they blend with the translucent chat panel instead of looking like solid pills.

import 'package:flutter/material.dart';

import '../../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../../theme/twitch_ui_tokens.dart';
import '../../channel_points/twitch_channel_points_sheet_utils.dart';
import '../../shared/twitch_cached_image_layer.dart';
import '../../shared/twitch_default_channel_points_icon.dart';

const Color _softAccent = Color(0xFF8F7CC0);
const Color _softAccentText = Color(0xFFC9BDEC);

class TwitchWatchChatUtilityBar extends StatelessWidget {
  final TwitchChannelPointsRuntimeSnapshot? channelPoints;
  final bool loadingEmotes;
  final bool compact;
  final VoidCallback onOpenChannelPoints;
  final VoidCallback onOpenEmotes;

  const TwitchWatchChatUtilityBar({
    super.key,
    required this.channelPoints,
    required this.loadingEmotes,
    required this.compact,
    required this.onOpenChannelPoints,
    required this.onOpenEmotes,
  });

  @override
  Widget build(BuildContext context) {
    final balance = channelPoints?.balance;
    final pointsIconUrl = channelPoints?.pointsIconUrl;
    final hasClaim = (channelPoints?.availableClaimId ?? '').isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(10, compact ? 7 : 9, 10, compact ? 4 : 5),
      child: Row(
        children: [
          _ChannelPointsCompactButton(
            balance: balance,
            iconUrl: pointsIconUrl,
            hasClaim: hasClaim,
            compact: compact,
            onTap: onOpenChannelPoints,
          ),
          if (!compact) const Spacer() else const SizedBox(width: 6),
          _UtilityButton(
            tooltip: loadingEmotes ? '貼圖載入中' : '貼圖',
            icon: loadingEmotes ? Icons.sync_rounded : Icons.tag_faces_rounded,
            active: loadingEmotes,
            compact: compact,
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
  final bool compact;
  final VoidCallback onTap;

  const _ChannelPointsCompactButton({
    required this.balance,
    required this.iconUrl,
    required this.hasClaim,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = balance == null ? '--' : formatChannelPointCompactNumber(balance!);
    final fullLabel = balance == null ? '--' : formatChannelPointFullNumber(balance!);

    return Tooltip(
      message: hasClaim ? '忠誠點數 $fullLabel · 有可領獎勵' : '忠誠點數 $fullLabel',
      child: InkWell(
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        onTap: onTap,
        child: Container(
          height: compact ? 30 : 34,
          padding: EdgeInsets.fromLTRB(compact ? 8 : 10, 0, compact ? 9 : 12, 0),
          decoration: BoxDecoration(
            color: hasClaim
                ? _softAccent.withOpacity(0.075)
                : Colors.white.withOpacity(0.024),
            borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
            border: Border.all(
              color: hasClaim
                  ? _softAccentText.withOpacity(0.18)
                  : Colors.white.withOpacity(0.050),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChannelPointsIcon(
                iconUrl: iconUrl,
                hasClaim: hasClaim,
              ),
              if (balance != null) ...[
                SizedBox(width: compact ? 5 : 7),
                Text(
                  label,
                  style: TextStyle(
                    color: hasClaim ? const Color(0xFFD8CEF2) : Colors.white60,
                    fontSize: compact ? 11 : 12.5,
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

  const _ChannelPointsIcon({
    required this.iconUrl,
    required this.hasClaim,
  });

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
        color: _softAccentText,
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
  final bool compact;
  final VoidCallback? onTap;

  const _UtilityButton({
    required this.tooltip,
    required this.icon,
    this.active = false,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        onTap: onTap,
        child: Container(
          width: 34,
          height: compact ? 30 : 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? _softAccent.withOpacity(0.070)
                : Colors.white.withOpacity(0.024),
            borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
            border: Border.all(
              color: active
                  ? _softAccentText.withOpacity(0.17)
                  : Colors.white.withOpacity(0.050),
            ),
          ),
          child: Icon(
            icon,
            size: compact ? 15 : 17,
            color: active ? _softAccentText : Colors.white54,
          ),
        ),
      ),
    );
  }
}
