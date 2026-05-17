// PATCH VERSION: twitch_watch_chat_header_bar_stage148
//
// Extracted WatchPage chat header UI. Keep visual style here so the main
// TwitchWatchChatPanel can focus on composition and data wiring.

import 'package:flutter/material.dart';

import '../../../theme/twitch_ui_tokens.dart';

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
    return Container(
      height: compact ? 42 : 54,
      padding: EdgeInsets.fromLTRB(12, compact ? 5 : 8, 10, compact ? 5 : 8),
      decoration: const BoxDecoration(
        color: TwitchUiColors.surfaceAlt,
        border: Border(bottom: BorderSide(color: Color(0xFF2D2D35))),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.circle : Icons.circle_outlined,
            size: 10,
            color: connected ? Colors.greenAccent : Colors.white38,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'STREAM CHAT',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: TwitchUiColors.textPrimary,
                fontSize: compact ? 12 : 13,
                fontWeight: TwitchUiFontWeight.heavy,
                letterSpacing: 0.4,
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
          IconButton(
            tooltip: '聊天室字體',
            visualDensity: VisualDensity.compact,
            onPressed: onOpenAppearance,
            icon: const Icon(Icons.format_size_rounded, size: 19),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: '刷新互動',
            visualDensity: VisualDensity.compact,
            onPressed: loading ? null : onRefresh,
            icon: loading
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 19),
          ),
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
    final color = active ? TwitchUiColors.primarySoft : Colors.white38;

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
                ? TwitchUiColors.primary.withOpacity(0.20)
                : const Color(0xFF1B1B22),
            borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
            border: Border.all(
              color: active
                  ? TwitchUiColors.primary.withOpacity(0.38)
                  : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Icon(icon, size: 16, color: enabled ? color : Colors.white24),
        ),
      ),
    );
  }
}
