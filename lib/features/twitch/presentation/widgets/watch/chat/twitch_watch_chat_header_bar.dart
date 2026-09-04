import 'package:flutter/material.dart';

import '../../../localization/vioclass_localizations.dart';
import '../../../theme/twitch_ui_tokens.dart';

const Color _softAccent = Color(0xFF8F7CC0);
const Color _softAccentText = Color(0xFFC9BDEC);

class TwitchWatchChatHeaderBar extends StatelessWidget {
  final bool connected;
  final bool showPinned;
  final bool showPrediction;
  final bool predictionVisible;
  final bool hasPinned;
  final bool hasPrediction;
  final bool compact;
  final VoidCallback onTogglePinned;
  final VoidCallback onTogglePrediction;

  const TwitchWatchChatHeaderBar({
    super.key,
    required this.connected,
    required this.showPinned,
    required this.showPrediction,
    required this.predictionVisible,
    required this.hasPinned,
    required this.hasPrediction,
    required this.compact,
    required this.onTogglePinned,
    required this.onTogglePrediction,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    final headerHeight = compact ? 44.0 : 56.0;

    return Container(
      height: headerHeight,
      padding: EdgeInsets.fromLTRB(12, compact ? 5 : 8, 10, compact ? 5 : 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.028),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.060)),
        ),
      ),
      child: Row(
        children: [
          _ConnectionBadge(connected: connected, compact: compact),
          const Spacer(),
          _HeaderToggleButton(
            tooltip: l10n.t(showPinned ? '隱藏置頂留言' : '顯示置頂留言'),
            icon: Icons.push_pin_rounded,
            active: showPinned && hasPinned,
            enabled: hasPinned,
            onTap: onTogglePinned,
          ),
          const SizedBox(width: 5),
          _HeaderToggleButton(
            tooltip: predictionVisible
                ? l10n.t('隱藏賭盤通知')
                : hasPrediction
                ? l10n.t('顯示賭盤通知')
                : l10n.t('沒有賭盤'),
            icon: Icons.how_to_vote_rounded,
            active: predictionVisible,
            enabled: hasPrediction,
            onTap: onTogglePrediction,
          ),
        ],
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final bool connected;
  final bool compact;

  const _ConnectionBadge({required this.connected, required this.compact});

  @override
  Widget build(BuildContext context) {
    final color = connected ? TwitchUiColors.green : Colors.white38;
    final label = context.vio.t(connected ? '直播' : '離線');

    return Container(
      height: compact ? 25 : 28,
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 8),
      decoration: BoxDecoration(
        color: connected
            ? color.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.042),
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        border: Border.all(
          color: color.withValues(alpha: connected ? 0.30 : 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: connected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: color.withValues(alpha: 0.38),
                        blurRadius: 6,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: TwitchUiFontWeight.heavy,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderToggleButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  const _HeaderToggleButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _softAccentText : Colors.white38;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? _softAccent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.052),
            borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
            border: Border.all(
              color: active
                  ? _softAccentText.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.080),
            ),
          ),
          child: Icon(icon, size: 16, color: enabled ? color : Colors.white24),
        ),
      ),
    );
  }
}
