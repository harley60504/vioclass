import 'package:flutter/material.dart';

import '../../../../models/emotes/twitch_official_emote.dart';
import '../../../../models/emotes/twitch_third_party_emote.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../twitch_emote_picker_models.dart';
import 'twitch_emote_picker_empty_state.dart';
import 'twitch_mixed_emote_grid.dart';

class TwitchRecentEmotePanel extends StatelessWidget {
  final List<TwitchThirdPartyEmote> thirdPartyRecent;
  final List<TwitchOfficialEmote> officialRecent;
  final TwitchThirdPartyEmoteCacheService thirdPartyCache;
  final TwitchOfficialEmoteCacheService? officialCache;
  final String query;
  final String emptyText;
  final ValueChanged<TwitchThirdPartyEmote> onInsertThirdParty;
  final ValueChanged<TwitchOfficialEmote> onInsertOfficial;
  final VoidCallback onChanged;

  const TwitchRecentEmotePanel({
    super.key,
    required this.thirdPartyRecent,
    required this.officialRecent,
    required this.thirdPartyCache,
    required this.officialCache,
    required this.query,
    required this.emptyText,
    required this.onInsertThirdParty,
    required this.onInsertOfficial,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final lowerQuery = query.trim().toLowerCase();

    final entries = <TwitchMixedEmoteEntry>[
      ...officialRecent
          .where((emote) => lowerQuery.isEmpty ||
              emote.name.toLowerCase().contains(lowerQuery) ||
              emote.id.toLowerCase().contains(lowerQuery))
          .map(TwitchMixedEmoteEntry.official),
      ...thirdPartyRecent
          .where((emote) => lowerQuery.isEmpty ||
              emote.name.toLowerCase().contains(lowerQuery) ||
              emote.id.toLowerCase().contains(lowerQuery))
          .map(TwitchMixedEmoteEntry.thirdParty),
    ].toList(growable: false);

    if (entries.isEmpty) return TwitchEmotePickerEmptyState(text: emptyText);

    return TwitchMixedEmoteGrid(
      entries: entries,
      resetKey: 'recent:$lowerQuery:${entries.length}',
      thirdPartyCache: thirdPartyCache,
      officialCache: officialCache,
      onInsertThirdParty: onInsertThirdParty,
      onInsertOfficial: onInsertOfficial,
      onChanged: onChanged,
    );
  }
}
