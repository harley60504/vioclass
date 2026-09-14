import 'package:flutter/material.dart';

import '../../theme/twitch_ui_tokens.dart';

class TwitchDiscoveryEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const TwitchDiscoveryEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(TwitchUiSpacing.space24),
        decoration: BoxDecoration(
          color: TwitchUiColors.surfaceCard,
          borderRadius: BorderRadius.circular(TwitchUiRadius.xl),
          border: Border.all(color: TwitchUiColors.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TwitchUiColors.selectedOverlay,
                borderRadius: BorderRadius.circular(TwitchUiRadius.lg),
                border: Border.all(color: TwitchUiColors.borderInteractive),
              ),
              child: Icon(icon, color: TwitchUiColors.primarySoft, size: 28),
            ),
            const SizedBox(height: TwitchUiSpacing.space16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: TwitchUiColors.textPrimary,
                fontWeight: TwitchUiFontWeight.strong,
                fontSize: TwitchUiFontSize.title,
              ),
            ),
            const SizedBox(height: TwitchUiSpacing.space8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: TwitchUiColors.textSecondary,
                fontSize: TwitchUiFontSize.body,
                height: 1.45,
                fontWeight: TwitchUiFontWeight.regular,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: TwitchUiSpacing.space20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
