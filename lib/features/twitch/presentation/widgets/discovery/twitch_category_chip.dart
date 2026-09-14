import 'package:flutter/material.dart';

import '../../../models/discovery/twitch_live_stream.dart';
import '../../theme/twitch_ui_tokens.dart';

class TwitchCategoryChip extends StatelessWidget {
  final TwitchGameCategory game;
  final bool selected;
  final VoidCallback onTap;

  const TwitchCategoryChip({
    super.key,
    required this.game,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(TwitchUiRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: TwitchUiMotion.fast,
            curve: TwitchUiMotion.standardCurve,
            padding: const EdgeInsets.all(TwitchUiSpacing.space8),
            decoration: BoxDecoration(
              color: selected
                  ? TwitchUiColors.surfaceSelected
                  : TwitchUiColors.surfaceCard,
              borderRadius: BorderRadius.circular(TwitchUiRadius.lg),
              border: Border.all(
                color: selected
                    ? TwitchUiColors.borderInteractive
                    : TwitchUiColors.borderSubtle,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(TwitchUiRadius.md),
                    child: game.boxArtUrl.isEmpty
                        ? const ColoredBox(color: TwitchUiColors.surfaceRaised)
                        : Image.network(
                            game.boxArt(width: 188, height: 250),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: TwitchUiColors.surfaceRaised,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: TwitchUiSpacing.space8),
                Text(
                  game.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? TwitchUiColors.primarySoft
                        : TwitchUiColors.textSecondary,
                    fontSize: TwitchUiFontSize.bodyCompact,
                    fontWeight: TwitchUiFontWeight.strong,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
