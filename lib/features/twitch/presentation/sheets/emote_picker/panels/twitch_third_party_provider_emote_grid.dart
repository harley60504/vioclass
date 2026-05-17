import 'package:flutter/material.dart';

import '../../../../models/emotes/twitch_third_party_emote.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../../widgets/common/twitch_progressive_grid_view.dart';
import '../twitch_emote_picker_widgets.dart';
import 'twitch_emote_picker_empty_state.dart';

class TwitchThirdPartyProviderEmoteGrid extends StatelessWidget {
  final List<TwitchThirdPartyEmote> emotes;
  final TwitchThirdPartyEmoteCacheService cache;
  final String emptyText;
  final ValueChanged<TwitchThirdPartyEmote> onInsert;
  final VoidCallback onChanged;

  const TwitchThirdPartyProviderEmoteGrid({
    super.key,
    required this.emotes,
    required this.cache,
    required this.emptyText,
    required this.onInsert,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (emotes.isEmpty) return TwitchEmotePickerEmptyState(text: emptyText);

    return TwitchProgressiveGridView<TwitchThirdPartyEmote>(
      items: emotes,
      resetKey: 'third:${emptyText.hashCode}:${emotes.length}',
      initialItemCount: 48,
      pageSize: 48,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.08,
      ),
      itemBuilder: (context, emote, index) {
        return TwitchThirdPartyEmoteGridCard(
          emote: emote,
          favorite: cache.isFavorite(emote),
          onInsert: () => onInsert(emote),
          onToggleFavorite: () {
            cache.toggleFavorite(emote);
            onChanged();
          },
        );
      },
    );
  }
}
