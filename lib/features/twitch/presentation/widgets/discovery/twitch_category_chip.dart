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
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected
                ? TwitchUiColors.primary.withValues(alpha: 0.20)
                : const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? TwitchUiColors.primary.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: game.boxArtUrl.isEmpty
                      ? const ColoredBox(color: Color(0xFF242429))
                      : Image.network(
                          game.boxArt(width: 188, height: 250),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Color(0xFF242429)),
                        ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                game.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? TwitchUiColors.primarySoft : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
