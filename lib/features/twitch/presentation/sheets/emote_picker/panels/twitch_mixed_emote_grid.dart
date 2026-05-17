import 'package:flutter/material.dart';

import '../../../../models/emotes/twitch_official_emote.dart';
import '../../../../models/emotes/twitch_third_party_emote.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../../widgets/common/twitch_progressive_grid_view.dart';
import '../twitch_emote_picker_models.dart';
import '../twitch_emote_picker_widgets.dart';

class TwitchMixedEmoteGrid extends StatelessWidget {
  final List<TwitchMixedEmoteEntry> entries;
  final String resetKey;
  final TwitchThirdPartyEmoteCacheService thirdPartyCache;
  final TwitchOfficialEmoteCacheService? officialCache;
  final ValueChanged<TwitchThirdPartyEmote> onInsertThirdParty;
  final ValueChanged<TwitchOfficialEmote> onInsertOfficial;
  final VoidCallback onChanged;

  const TwitchMixedEmoteGrid({
    super.key,
    required this.entries,
    required this.resetKey,
    required this.thirdPartyCache,
    required this.officialCache,
    required this.onInsertThirdParty,
    required this.onInsertOfficial,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TwitchProgressiveGridView<TwitchMixedEmoteEntry>(
      items: entries,
      resetKey: resetKey,
      initialItemCount: 48,
      pageSize: 48,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.08,
      ),
      itemBuilder: (context, entry, index) {
        if (entry.thirdParty != null) {
          final emote = entry.thirdParty!;
          return TwitchThirdPartyEmoteGridCard(
            emote: emote,
            favorite: thirdPartyCache.isFavorite(emote),
            onInsert: () => onInsertThirdParty(emote),
            onToggleFavorite: () {
              thirdPartyCache.toggleFavorite(emote);
              onChanged();
            },
          );
        }

        final emote = entry.official!;
        final cache = officialCache;
        return TwitchOfficialEmoteGridCard(
          emote: emote,
          locked: emote.locked,
          favorite: cache?.isFavorite(emote) ?? false,
          onInsert: () => onInsertOfficial(emote),
          onToggleFavorite: () {
            cache?.toggleFavorite(emote);
            onChanged();
          },
        );
      },
    );
  }
}
