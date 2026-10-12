import 'package:flutter/material.dart';

import '../../../localization/vioclass_localizations.dart';
import '../../../theme/twitch_ui_tokens.dart';

const Color _softAccent = Color(0xFF8F7CC0);
const Color _softAccentText = Color(0xFFC9BDEC);

class TwitchWatchChatHeaderBar extends StatelessWidget {
  static const double compactHeight = 40;
  static const double regularHeight = 44;
  final bool connected;
  final bool showPinned;
  final bool showPrediction;
  final bool predictionVisible;
  final bool hasPinned;
  final bool hasPrediction;
  final bool compact;
  final VoidCallback onTogglePinned;
  final VoidCallback onTogglePrediction;
  final VoidCallback? onToggleMode;
  final bool replayMode;
  final bool replayHasError;
  final bool showToggles;

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
    this.onToggleMode,
    this.replayMode = false,
    this.replayHasError = false,
    this.showToggles = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    final headerHeight = compact ? compactHeight : regularHeight;

    return Container(
      height: headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: TwitchUiColors.surfaceRaised,
        border: Border(bottom: BorderSide(color: TwitchUiColors.borderSubtle)),
      ),
      child: Row(
        children: [
          _ConnectionBadge(
            connected: connected,
            compact: compact,
            replayMode: replayMode,
            hasError: replayHasError,
            onToggleMode: onToggleMode,
          ),
          const Spacer(),
          if (showToggles) ...[
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
        ],
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final bool connected;
  final bool compact;
  final bool replayMode;
  final bool hasError;
  final VoidCallback? onToggleMode;

  const _ConnectionBadge({
    required this.connected,
    required this.compact,
    required this.replayMode,
    required this.hasError,
    this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    final color = replayMode
        ? (hasError ? Colors.redAccent : _softAccentText)
        : connected
        ? TwitchUiColors.green
        : Colors.white38;
    final label = replayMode ? 'VOD' : context.vio.t(connected ? '直播' : '離線');

    return Tooltip(
      message: onToggleMode == null
          ? label
          : context.vio.t(replayMode ? '切換到直播聊天室' : '切換到 VOD 聊天回放'),
      child: InkWell(
        onTap: onToggleMode,
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        child: SizedBox(
          height: compact ? 40 : 44,
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
              if (!compact || onToggleMode != null) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
              if (onToggleMode != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.swap_horiz_rounded, size: 14, color: color),
              ],
            ],
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
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? _softAccent.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
                  border: Border.all(
                    color: active
                        ? _softAccentText.withValues(alpha: 0.28)
                        : Colors.transparent,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: enabled ? color : Colors.white24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
