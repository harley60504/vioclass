// PATCH VERSION: twitch_emote_picker_panels_stage179_official_category_filter
//
// Main content panels for the Twitch emote picker sheet.

import 'package:flutter/material.dart';

import '../../../models/emotes/twitch_official_emote.dart';
import '../../../models/emotes/twitch_third_party_emote.dart';
import '../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../services/chat/twitch_third_party_emote_cache_service.dart';
import 'twitch_emote_picker_models.dart';
import 'twitch_emote_picker_widgets.dart';

class TwitchEmotePickerEmptyState extends StatelessWidget {
  final String text;

  const TwitchEmotePickerEmptyState({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white54,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

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
    ].take(twitchCombinedGridLimit).toList(growable: false);

    if (entries.isEmpty) return TwitchEmotePickerEmptyState(text: emptyText);

    return TwitchMixedEmoteGrid(
      entries: entries,
      thirdPartyCache: thirdPartyCache,
      officialCache: officialCache,
      onInsertThirdParty: onInsertThirdParty,
      onInsertOfficial: onInsertOfficial,
      onChanged: onChanged,
    );
  }
}

class TwitchFavoriteEmotePanel extends StatelessWidget {
  final List<TwitchThirdPartyEmote> thirdPartyFavorites;
  final List<TwitchOfficialEmote> officialFavorites;
  final TwitchThirdPartyEmoteCacheService thirdPartyCache;
  final TwitchOfficialEmoteCacheService? officialCache;
  final String query;
  final String emptyText;
  final ValueChanged<TwitchThirdPartyEmote> onInsertThirdParty;
  final ValueChanged<TwitchOfficialEmote> onInsertOfficial;
  final VoidCallback onChanged;

  const TwitchFavoriteEmotePanel({
    super.key,
    required this.thirdPartyFavorites,
    required this.officialFavorites,
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

    final thirdParty = thirdPartyFavorites
        .where((emote) => lowerQuery.isEmpty ||
            emote.name.toLowerCase().contains(lowerQuery) ||
            emote.id.toLowerCase().contains(lowerQuery))
        .map(TwitchMixedEmoteEntry.thirdParty)
        .toList(growable: false);

    final official = officialFavorites
        .where((emote) => lowerQuery.isEmpty ||
            emote.name.toLowerCase().contains(lowerQuery) ||
            emote.id.toLowerCase().contains(lowerQuery))
        .map(TwitchMixedEmoteEntry.official)
        .toList(growable: false);

    final entries = <TwitchMixedEmoteEntry>[
      ...thirdParty,
      ...official,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final visibleEntries = entries.take(twitchCombinedGridLimit).toList(growable: false);
    if (visibleEntries.isEmpty) return TwitchEmotePickerEmptyState(text: emptyText);

    return TwitchMixedEmoteGrid(
      entries: visibleEntries,
      thirdPartyCache: thirdPartyCache,
      officialCache: officialCache,
      onInsertThirdParty: onInsertThirdParty,
      onInsertOfficial: onInsertOfficial,
      onChanged: onChanged,
    );
  }
}

class TwitchMixedEmoteGrid extends StatelessWidget {
  final List<TwitchMixedEmoteEntry> entries;
  final TwitchThirdPartyEmoteCacheService thirdPartyCache;
  final TwitchOfficialEmoteCacheService? officialCache;
  final ValueChanged<TwitchThirdPartyEmote> onInsertThirdParty;
  final ValueChanged<TwitchOfficialEmote> onInsertOfficial;
  final VoidCallback onChanged;

  const TwitchMixedEmoteGrid({
    super.key,
    required this.entries,
    required this.thirdPartyCache,
    required this.officialCache,
    required this.onInsertThirdParty,
    required this.onInsertOfficial,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.08,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];

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

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.08,
      ),
      itemCount: emotes.length,
      itemBuilder: (context, index) {
        final emote = emotes[index];
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

class TwitchOfficialEmotePanel extends StatelessWidget {
  final TwitchOfficialEmoteCacheService? official;
  final String query;
  final bool loading;
  final String emptyText;
  final TwitchOfficialEmoteSubFilter subFilter;
  final ValueChanged<TwitchOfficialEmoteSubFilter> onSubFilterChanged;
  final ValueChanged<TwitchOfficialEmote> onInsert;
  final VoidCallback onChanged;

  const TwitchOfficialEmotePanel({
    super.key,
    required this.official,
    required this.query,
    required this.loading,
    required this.emptyText,
    required this.subFilter,
    required this.onSubFilterChanged,
    required this.onInsert,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final service = official;

    if (service == null) {
      return TwitchEmotePickerEmptyState(text: emptyText);
    }

    final global = filterOfficialEmotes(
      source: service.globalEmotes,
      query: query,
    );
    final usable = filterOfficialEmotes(
      source: service.usableEmotes
          .where((emote) => emote.source != TwitchOfficialEmoteSource.global)
          .toList(growable: false),
      query: query,
    );
    final channel = filterOfficialEmotes(
      source: service.lockedChannelEmotes,
      query: query,
    );

    if (loading && service.visibleCount == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    final selected = switch (subFilter) {
      TwitchOfficialEmoteSubFilter.usable => usable,
      TwitchOfficialEmoteSubFilter.channel => channel,
      TwitchOfficialEmoteSubFilter.global => global,
    };

    final selectedLocked = subFilter == TwitchOfficialEmoteSubFilter.channel;
    final currentEmptyText = switch (subFilter) {
      TwitchOfficialEmoteSubFilter.usable => '目前沒有我的可用 Twitch 貼圖。',
      TwitchOfficialEmoteSubFilter.channel => '目前沒有實況主頻道貼圖。',
      TwitchOfficialEmoteSubFilter.global => '目前沒有 Twitch 共用貼圖。',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (service.userEmotesUnavailable)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2315),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.35)),
            ),
            child: const Text(
              '缺少 user:read:emotes 時，仍會顯示頻道貼圖，但無法完整判斷哪些訂閱貼圖已解鎖。',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFFFFE3A3),
                fontSize: 10,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              TwitchOfficialSubFilterChip(
                label: '我的可用',
                count: usable.length,
                selected: subFilter == TwitchOfficialEmoteSubFilter.usable,
                onTap: () => onSubFilterChanged(TwitchOfficialEmoteSubFilter.usable),
              ),
              TwitchOfficialSubFilterChip(
                label: '實況主',
                count: channel.length,
                selected: subFilter == TwitchOfficialEmoteSubFilter.channel,
                onTap: () => onSubFilterChanged(TwitchOfficialEmoteSubFilter.channel),
              ),
              TwitchOfficialSubFilterChip(
                label: '全部共用',
                count: global.length,
                selected: subFilter == TwitchOfficialEmoteSubFilter.global,
                onTap: () => onSubFilterChanged(TwitchOfficialEmoteSubFilter.global),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: selected.isEmpty
              ? TwitchEmotePickerEmptyState(
                  text: global.isEmpty && usable.isEmpty && channel.isEmpty
                      ? emptyText
                      : currentEmptyText,
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
                  itemCount: selected.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 116,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.02,
                  ),
                  itemBuilder: (context, index) {
                    final emote = selected[index];
                    return TwitchOfficialEmoteGridCard(
                      emote: emote,
                      locked: selectedLocked || emote.locked,
                      favorite: service.isFavorite(emote),
                      onInsert: () => onInsert(emote),
                      onToggleFavorite: () {
                        service.toggleFavorite(emote);
                        onChanged();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
