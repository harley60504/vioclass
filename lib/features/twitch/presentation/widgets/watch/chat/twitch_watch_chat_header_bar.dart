import 'package:flutter/material.dart';

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
  final bool loading;
  final bool compact;
  final VoidCallback onTogglePinned;
  final VoidCallback onTogglePrediction;
  final VoidCallback onRefresh;
  final VoidCallback onOpenAppearance;

  const TwitchWatchChatHeaderBar({
    super.key,
    required this.connected,
    required this.showPinned,
    required this.showPrediction,
    required this.predictionVisible,
    required this.hasPinned,
    required this.hasPrediction,
    required this.loading,
    required this.compact,
    required this.onTogglePinned,
    required this.onTogglePrediction,
    required this.onRefresh,
    required this.onOpenAppearance,
  });

  @override
  Widget build(BuildContext context) {
    final headerHeight = compact ? 44.0 : 56.0;

    return Container(
      height: headerHeight,
      padding: EdgeInsets.fromLTRB(12, compact ? 5 : 8, 10, compact ? 5 : 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.028),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.060)),
        ),
      ),
      child: Row(
        children: [
          _ConnectionBadge(
            connected: connected,
            compact: compact,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'STREAM CHAT',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: TwitchUiColors.textPrimary,
                fontSize: compact ? 12 : 13,
                fontWeight: TwitchUiFontWeight.heavy,
                letterSpacing: 0.45,
              ),
            ),
          ),
          _HeaderToggleButton(
            tooltip: showPinned ? '隱藏置頂留言' : '顯示置頂留言',
            icon: Icons.push_pin_rounded,
            active: showPinned && hasPinned,
            enabled: hasPinned,
            onTap: onTogglePinned,
          ),
          const SizedBox(width: 5),
          _HeaderToggleButton(
            tooltip: predictionVisible
                ? '隱藏賭盤通知'
                : hasPrediction
                    ? '顯示賭盤通知'
                    : '沒有賭盤',
            icon: Icons.how_to_vote_rounded,
            active: predictionVisible,
            enabled: hasPrediction,
            onTap: onTogglePrediction,
          ),
          const SizedBox(width: 5),
          _HeaderIconButton(
            tooltip: '聊天室字體',
            icon: Icons.format_size_rounded,
            onTap: onOpenAppearance,
          ),
          const SizedBox(width: 5),
          _HeaderIconButton(
            tooltip: '刷新互動',
            icon: Icons.refresh_rounded,
            loading: loading,
            onTap: loading ? null : onRefresh,
          ),
        ],
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final bool connected;
  final bool compact;

  const _ConnectionBadge({
    required this.connected,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final color = connected ? TwitchUiColors.green : Colors.white38;
    final label = connected ? 'LIVE' : 'OFF';

    return Container(
      height: compact ? 25 : 28,
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 8),
      decoration: BoxDecoration(
        color: connected ? color.withOpacity(0.10) : Colors.white.withOpacity(0.042),
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        border: Border.all(color: color.withOpacity(connected ? 0.30 : 0.16)),
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
                        color: color.withOpacity(0.38),
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
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    this.loading = false,
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
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.052),
            borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
            border: Border.all(color: Colors.white.withOpacity(0.080)),
          ),
          child: loading
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  icon,
                  size: 17,
                  color: onTap == null ? Colors.white24 : _softAccentText,
                ),
        ),
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
                ? _softAccent.withOpacity(0.18)
                : Colors.white.withOpacity(0.052),
            borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
            border: Border.all(
              color: active
                  ? _softAccentText.withOpacity(0.28)
                  : Colors.white.withOpacity(0.080),
            ),
          ),
          child: Icon(icon, size: 16, color: enabled ? color : Colors.white24),
        ),
      ),
    );
  }
}
