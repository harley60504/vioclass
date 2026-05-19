// PATCH VERSION: twitch_emote_picker_sheet_stage222_frosty_category_merge
//
// Thin entry/state file for Twitch emote picker sheets. Heavy panels, widgets,
// models, and official emote ID picker live in sheets/emote_picker/*.
// Stage 222: merge Frosty-style scope/category filtering into this original
// sheet and keep favorite toggling on long press.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/emotes/twitch_official_emote.dart';
import '../../models/emotes/twitch_third_party_emote.dart';
import '../../services/chat/twitch_official_emote_cache_service.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import 'emote_picker/twitch_emote_picker_models.dart';
import 'emote_picker/twitch_emote_picker_panels.dart';
import 'emote_picker/twitch_emote_picker_widgets.dart';
import 'emote_picker/twitch_official_emote_id_picker_sheet.dart';

Future<String?> showTwitchOfficialEmoteIdPickerSheet({
  required BuildContext context,
  required TwitchOfficialEmoteCacheService officialCache,
  required bool loading,
  required Future<void> Function() onRefresh,
  String title = '選擇 Twitch 官方貼圖',
  String subtitle = '會回傳 Twitch emote ID，不是貼圖名稱。',
  bool includeGlobalEmotes = true,
  bool includeUnlockedEmotes = true,
  bool includeLockedChannelEmotes = true,
}) {
  return showTwitchResponsiveSheet<String>(
    context: context,
    size: TwitchUnifiedSheetSize.large,
    builder: (_) => TwitchOfficialEmoteIdPickerSheet(
      officialCache: officialCache,
      loading: loading,
      onRefresh: onRefresh,
      title: title,
      subtitle: subtitle,
      includeGlobalEmotes: includeGlobalEmotes,
      includeUnlockedEmotes: includeUnlockedEmotes,
      includeLockedChannelEmotes: includeLockedChannelEmotes,
    ),
  );
}

Future<void> showTwitchEmotePickerSheet({
  required BuildContext context,
  required TwitchThirdPartyEmoteCacheService cache,
  TwitchOfficialEmoteCacheService? officialCache,
  required bool loading,
  required Future<void> Function() onRefresh,
  required ValueChanged<String> onEmoteSelected,
}) {
  return showTwitchResponsiveSheet<void>(
    context: context,
    size: TwitchUnifiedSheetSize.large,
    builder: (_) => TwitchThirdPartyEmotePickerSheet(
      cache: cache,
      officialCache: officialCache,
      loading: loading,
      onRefresh: onRefresh,
      onEmoteSelected: onEmoteSelected,
    ),
  );
}

class TwitchThirdPartyEmotePickerSheet extends StatefulWidget {
  final TwitchThirdPartyEmoteCacheService cache;
  final TwitchOfficialEmoteCacheService? officialCache;
  final bool loading;
  final Future<void> Function() onRefresh;
  final ValueChanged<String>? onEmoteSelected;

  const TwitchThirdPartyEmotePickerSheet({
    super.key,
    required this.cache,
    required this.loading,
    required this.onRefresh,
    this.officialCache,
    this.onEmoteSelected,
  });

  @override
  State<TwitchThirdPartyEmotePickerSheet> createState() =>
      _TwitchThirdPartyEmotePickerSheetState();
}

class _TwitchThirdPartyEmotePickerSheetState
    extends State<TwitchThirdPartyEmotePickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  String _query = '';
  TwitchEmotePickerTab _selectedTab = TwitchEmotePickerTab.recent;
  TwitchOfficialEmoteSubFilter _officialSubFilter =
      TwitchOfficialEmoteSubFilter.usable;
  TwitchThirdPartyEmoteScopeFilter _thirdPartyScopeFilter =
      TwitchThirdPartyEmoteScopeFilter.all;

  TwitchOfficialEmoteCacheService? get _official => widget.officialCache;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setSearchQueryDebounced(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(twitchEmoteSearchDebounceDuration, () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  void _finishInsert(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final callback = widget.onEmoteSelected;
    if (callback != null) {
      callback(trimmed);
      return;
    }

    Navigator.of(context).pop(trimmed);
  }

  void _selectThirdPartyEmote(TwitchThirdPartyEmote emote) {
    widget.cache.markRecentEmote(emote);
    _finishInsert(emote.name);
    if (mounted) setState(() {});
  }

  void _selectOfficialEmote(TwitchOfficialEmote emote) {
    if (emote.locked) return;
    _official?.markRecentEmote(emote);
    _finishInsert(emote.name);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final source = twitchThirdPartyEmotesForTab(
      tab: _selectedTab,
      cache: widget.cache,
    );
    final query = _query.toLowerCase();
    final filtered = filterThirdPartyEmotes(
      source: source,
      query: query,
      scopeFilter: _thirdPartyScopeFilter,
    );

    final official = _official;
    final isRecentTab = _selectedTab == TwitchEmotePickerTab.recent;
    final isTwitchTab = _selectedTab == TwitchEmotePickerTab.twitch;
    final isFavoritesTab = _selectedTab == TwitchEmotePickerTab.favorites;
    final isThirdPartyProviderTab = !isRecentTab && !isTwitchTab && !isFavoritesTab;

    final media = MediaQuery.of(context);
    final compactVertical =
        media.size.height < 520 || media.orientation == Orientation.landscape;
    final emptyText = twitchEmoteEmptyText(
      tab: _selectedTab,
      loading: widget.loading,
      official: official,
    );

    return SafeArea(
      child: TwitchUnifiedSheetScaffold(
        title: '貼圖',
        subtitle: '最近 / 收藏 / Twitch / BTTV / 7TV / FFZ｜長按收藏',
        icon: Icons.emoji_emotions_rounded,
        loading: widget.loading,
        onRefresh: widget.onRefresh,
        child: Column(
          children: [
            SizedBox(
              height: compactVertical ? 34 : 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  TwitchEmotePickerTabChip(
                    label: '最近',
                    icon: Icons.history_rounded,
                    selected: _selectedTab == TwitchEmotePickerTab.recent,
                    count: _countForTab(TwitchEmotePickerTab.recent),
                    onTap: () => _selectTab(TwitchEmotePickerTab.recent),
                  ),
                  TwitchEmotePickerTabChip(
                    label: '收藏',
                    icon: Icons.star_rounded,
                    selected: _selectedTab == TwitchEmotePickerTab.favorites,
                    count: _countForTab(TwitchEmotePickerTab.favorites),
                    onTap: () => _selectTab(TwitchEmotePickerTab.favorites),
                  ),
                  TwitchEmotePickerTabChip(
                    label: 'Twitch',
                    icon: Icons.lock_rounded,
                    selected: _selectedTab == TwitchEmotePickerTab.twitch,
                    count: _countForTab(TwitchEmotePickerTab.twitch),
                    onTap: () => _selectTab(TwitchEmotePickerTab.twitch),
                  ),
                  TwitchEmotePickerTabChip(
                    label: 'BTTV',
                    selected: _selectedTab == TwitchEmotePickerTab.bttv,
                    count: _countForTab(TwitchEmotePickerTab.bttv),
                    onTap: () => _selectTab(TwitchEmotePickerTab.bttv),
                  ),
                  TwitchEmotePickerTabChip(
                    label: '7TV',
                    selected: _selectedTab == TwitchEmotePickerTab.sevenTv,
                    count: _countForTab(TwitchEmotePickerTab.sevenTv),
                    onTap: () => _selectTab(TwitchEmotePickerTab.sevenTv),
                  ),
                  TwitchEmotePickerTabChip(
                    label: 'FFZ',
                    selected: _selectedTab == TwitchEmotePickerTab.ffz,
                    count: _countForTab(TwitchEmotePickerTab.ffz),
                    onTap: () => _selectTab(TwitchEmotePickerTab.ffz),
                  ),
                ],
              ),
            ),
            if (isThirdPartyProviderTab)
              SizedBox(
                height: compactVertical ? 32 : 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  children: [
                    for (final scopeFilter in TwitchThirdPartyEmoteScopeFilter.values)
                      TwitchThirdPartyScopeFilterChip(
                        scopeFilter: scopeFilter,
                        selected: _thirdPartyScopeFilter == scopeFilter,
                        count: twitchThirdPartyEmoteScopeCount(
                          source: source,
                          scopeFilter: scopeFilter,
                        ),
                        onTap: () {
                          setState(() => _thirdPartyScopeFilter = scopeFilter);
                        },
                      ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                isThirdPartyProviderTab ? 0 : 3,
                12,
                7,
              ),
              child: SizedBox(
                height: compactVertical ? 34 : 36,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 32,
                    ),
                    hintText: isTwitchTab
                        ? '搜尋 Twitch 貼圖（${official?.visibleCount ?? 0}）'
                        : isThirdPartyProviderTab
                            ? '搜尋 ${_thirdPartyScopeFilter.label} 貼圖'
                            : '搜尋目前分類貼圖',
                    hintStyle: const TextStyle(fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onChanged: _setSearchQueryDebounced,
                ),
              ),
            ),
            Expanded(
              child: isRecentTab
                  ? TwitchRecentEmotePanel(
                      thirdPartyRecent: widget.cache.recentEmotes,
                      officialRecent:
                          official?.recentEmotes ?? const <TwitchOfficialEmote>[],
                      thirdPartyCache: widget.cache,
                      officialCache: official,
                      query: query,
                      emptyText: emptyText,
                      onInsertThirdParty: _selectThirdPartyEmote,
                      onInsertOfficial: _selectOfficialEmote,
                      onChanged: () => setState(() {}),
                    )
                  : isTwitchTab
                      ? TwitchOfficialEmotePanel(
                          official: official,
                          query: query,
                          loading: widget.loading || (official?.loading ?? false),
                          emptyText: emptyText,
                          subFilter: _officialSubFilter,
                          onSubFilterChanged: (value) {
                            setState(() => _officialSubFilter = value);
                          },
                          onInsert: _selectOfficialEmote,
                          onChanged: () => setState(() {}),
                        )
                      : isFavoritesTab
                          ? TwitchFavoriteEmotePanel(
                              thirdPartyFavorites: widget.cache.favoriteEmotes,
                              officialFavorites:
                                  official?.favoriteEmotes ?? const <TwitchOfficialEmote>[],
                              thirdPartyCache: widget.cache,
                              officialCache: official,
                              query: query,
                              emptyText: emptyText,
                              onInsertThirdParty: _selectThirdPartyEmote,
                              onInsertOfficial: _selectOfficialEmote,
                              onChanged: () => setState(() {}),
                            )
                          : TwitchThirdPartyProviderEmoteGrid(
                              emotes: filtered,
                              cache: widget.cache,
                              emptyText: emptyText,
                              onInsert: _selectThirdPartyEmote,
                              onChanged: () => setState(() {}),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  int _countForTab(TwitchEmotePickerTab tab) {
    return twitchEmoteCountForTab(
      tab: tab,
      cache: widget.cache,
      official: _official,
    );
  }

  void _selectTab(TwitchEmotePickerTab tab) {
    setState(() {
      _selectedTab = tab;
      if (tab == TwitchEmotePickerTab.bttv ||
          tab == TwitchEmotePickerTab.sevenTv ||
          tab == TwitchEmotePickerTab.ffz) {
        _thirdPartyScopeFilter = TwitchThirdPartyEmoteScopeFilter.all;
      }
    });
  }
}
