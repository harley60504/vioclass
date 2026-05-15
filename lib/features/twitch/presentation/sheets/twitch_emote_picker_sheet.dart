import 'package:flutter/material.dart';
import '../../models/emotes/twitch_official_emote.dart';
import '../../models/emotes/twitch_third_party_emote.dart';
import '../../services/chat/twitch_official_emote_cache_service.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

enum _EmotePickerTab {
  recent,
  favorites,
  twitch,
  bttv,
  sevenTv,
  ffz,
}

enum _OfficialEmoteSubFilter {
  usable,
  channel,
  global,
}

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
    builder: (_) => _TwitchOfficialEmoteIdPickerSheet(
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

  String _query = '';
  _EmotePickerTab _selectedTab = _EmotePickerTab.recent;
  _OfficialEmoteSubFilter _officialSubFilter = _OfficialEmoteSubFilter.usable;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  TwitchOfficialEmoteCacheService? get _official => widget.officialCache;

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

  List<TwitchThirdPartyEmote> _thirdPartyEmotesForSelectedTab() {
    switch (_selectedTab) {
      case _EmotePickerTab.recent:
        return const <TwitchThirdPartyEmote>[];

      case _EmotePickerTab.favorites:
        return widget.cache.favoriteEmotes;

      case _EmotePickerTab.twitch:
        return const <TwitchThirdPartyEmote>[];

      case _EmotePickerTab.bttv:
        return widget.cache.emotesForProvider(TwitchThirdPartyEmoteProvider.bttv);

      case _EmotePickerTab.sevenTv:
        return widget.cache.emotesForProvider(TwitchThirdPartyEmoteProvider.sevenTv);

      case _EmotePickerTab.ffz:
        return widget.cache.emotesForProvider(TwitchThirdPartyEmoteProvider.ffz);
    }
  }

  int _countForTab(_EmotePickerTab tab) {
    switch (tab) {
      case _EmotePickerTab.recent:
        return widget.cache.recentCount + (_official?.recentCount ?? 0);
      case _EmotePickerTab.favorites:
        return widget.cache.favoriteEmotes.length + (_official?.favoriteCount ?? 0);
      case _EmotePickerTab.twitch:
        return _official?.visibleCount ?? 0;
      case _EmotePickerTab.bttv:
        return widget.cache.countForProvider(TwitchThirdPartyEmoteProvider.bttv);
      case _EmotePickerTab.sevenTv:
        return widget.cache.countForProvider(TwitchThirdPartyEmoteProvider.sevenTv);
      case _EmotePickerTab.ffz:
        return widget.cache.countForProvider(TwitchThirdPartyEmoteProvider.ffz);
    }
  }

  String _emptyText() {
    if (widget.loading) return '貼圖預載中...';

    switch (_selectedTab) {
      case _EmotePickerTab.recent:
        return '目前沒有最近貼圖。';
      case _EmotePickerTab.favorites:
        return '還沒有收藏貼圖。';
      case _EmotePickerTab.twitch:
        final official = _official;
        if (official == null) return '官方 Twitch 貼圖服務尚未初始化。';
        if (official.userEmotesUnavailable) {
          return '已讀取 Twitch 全域 / 頻道貼圖；我的可用貼圖需要 user:read:emotes scope，缺少時訂閱貼圖會以鎖住狀態顯示。';
        }
        return '目前沒有 Twitch 官方 / 頻道貼圖。';
      case _EmotePickerTab.bttv:
        return '目前沒有 BTTV 貼圖。';
      case _EmotePickerTab.sevenTv:
        return '目前沒有 7TV 貼圖。';
      case _EmotePickerTab.ffz:
        return '目前沒有 FFZ 貼圖。';
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _thirdPartyEmotesForSelectedTab();
    final query = _query.toLowerCase();

    final filtered = source
        .where((emote) => query.isEmpty ||
            emote.name.toLowerCase().contains(query) ||
            emote.id.toLowerCase().contains(query))
        .take(240)
        .toList(growable: false);

    final official = _official;
    final isRecentTab = _selectedTab == _EmotePickerTab.recent;
    final isTwitchTab = _selectedTab == _EmotePickerTab.twitch;
    final isFavoritesTab = _selectedTab == _EmotePickerTab.favorites;

    final media = MediaQuery.of(context);
    final compactVertical = media.size.height < 520 || media.orientation == Orientation.landscape;

    return SafeArea(
      child: TwitchUnifiedSheetScaffold(
        title: '貼圖',
        subtitle: '最近 / 收藏 / Twitch / BTTV / 7TV / FFZ',
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
                  _EmoteTabChip(
                    label: '最近',
                    icon: Icons.history_rounded,
                    selected: _selectedTab == _EmotePickerTab.recent,
                    count: _countForTab(_EmotePickerTab.recent),
                    onTap: () => setState(() => _selectedTab = _EmotePickerTab.recent),
                  ),
                  _EmoteTabChip(
                    label: '收藏',
                    icon: Icons.star_rounded,
                    selected: _selectedTab == _EmotePickerTab.favorites,
                    count: _countForTab(_EmotePickerTab.favorites),
                    onTap: () => setState(() => _selectedTab = _EmotePickerTab.favorites),
                  ),
                  _EmoteTabChip(
                    label: 'Twitch',
                    icon: Icons.lock_rounded,
                    selected: _selectedTab == _EmotePickerTab.twitch,
                    count: _countForTab(_EmotePickerTab.twitch),
                    onTap: () => setState(() => _selectedTab = _EmotePickerTab.twitch),
                  ),
                  _EmoteTabChip(
                    label: 'BTTV',
                    selected: _selectedTab == _EmotePickerTab.bttv,
                    count: _countForTab(_EmotePickerTab.bttv),
                    onTap: () => setState(() => _selectedTab = _EmotePickerTab.bttv),
                  ),
                  _EmoteTabChip(
                    label: '7TV',
                    selected: _selectedTab == _EmotePickerTab.sevenTv,
                    count: _countForTab(_EmotePickerTab.sevenTv),
                    onTap: () => setState(() => _selectedTab = _EmotePickerTab.sevenTv),
                  ),
                  _EmoteTabChip(
                    label: 'FFZ',
                    selected: _selectedTab == _EmotePickerTab.ffz,
                    count: _countForTab(_EmotePickerTab.ffz),
                    onTap: () => setState(() => _selectedTab = _EmotePickerTab.ffz),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 3, 12, 7),
              child: SizedBox(
                height: compactVertical ? 34 : 36,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
                        : '搜尋目前分類貼圖',
                    hintStyle: const TextStyle(fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
              ),
            ),
            Expanded(
              child: isRecentTab
                  ? _RecentEmotePanel(
                      thirdPartyRecent: widget.cache.recentEmotes,
                      officialRecent: official?.recentEmotes ?? const <TwitchOfficialEmote>[],
                      thirdPartyCache: widget.cache,
                      officialCache: official,
                      query: query,
                      emptyText: _emptyText(),
                      onInsertThirdParty: _selectThirdPartyEmote,
                      onInsertOfficial: _selectOfficialEmote,
                      onChanged: () => setState(() {}),
                    )
                  : isTwitchTab
                  ? _TwitchOfficialEmotePanel(
                      official: official,
                      query: query,
                      loading: widget.loading || (official?.loading ?? false),
                      emptyText: _emptyText(),
                      subFilter: _officialSubFilter,
                      onSubFilterChanged: (value) {
                        setState(() => _officialSubFilter = value);
                      },
                      onInsert: _selectOfficialEmote,
                      onChanged: () => setState(() {}),
                    )
                  : isFavoritesTab
                      ? _FavoriteEmotePanel(
                          thirdPartyFavorites: widget.cache.favoriteEmotes,
                          officialFavorites:
                              official?.favoriteEmotes ?? const <TwitchOfficialEmote>[],
                          thirdPartyCache: widget.cache,
                          officialCache: official,
                          query: query,
                          emptyText: _emptyText(),
                          onInsertThirdParty: _selectThirdPartyEmote,
                          onInsertOfficial: _selectOfficialEmote,
                          onChanged: () => setState(() {}),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  _emptyText(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 120,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 1.08,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final emote = filtered[index];
                                final favorite = widget.cache.isFavorite(emote);

                                return _ThirdPartyEmoteGridCard(
                                  emote: emote,
                                  favorite: favorite,
                                  onInsert: () => _selectThirdPartyEmote(emote),
                                  onToggleFavorite: () {
                                    setState(() {
                                      widget.cache.toggleFavorite(emote);
                                    });
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}



class _RecentEmotePanel extends StatelessWidget {
  final List<TwitchThirdPartyEmote> thirdPartyRecent;
  final List<TwitchOfficialEmote> officialRecent;
  final TwitchThirdPartyEmoteCacheService thirdPartyCache;
  final TwitchOfficialEmoteCacheService? officialCache;
  final String query;
  final String emptyText;
  final ValueChanged<TwitchThirdPartyEmote> onInsertThirdParty;
  final ValueChanged<TwitchOfficialEmote> onInsertOfficial;
  final VoidCallback onChanged;

  const _RecentEmotePanel({
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

    final entries = <_FavoriteEmoteEntry>[
      ...officialRecent
          .where((emote) => lowerQuery.isEmpty ||
              emote.name.toLowerCase().contains(lowerQuery) ||
              emote.id.toLowerCase().contains(lowerQuery))
          .map(_FavoriteEmoteEntry.official),
      ...thirdPartyRecent
          .where((emote) => lowerQuery.isEmpty ||
              emote.name.toLowerCase().contains(lowerQuery) ||
              emote.id.toLowerCase().contains(lowerQuery))
          .map(_FavoriteEmoteEntry.thirdParty),
    ];

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              height: 1.35,
            ),
          ),
        ),
      );
    }

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
          return _ThirdPartyEmoteGridCard(
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
        return _OfficialEmoteGridCard(
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

class _FavoriteEmotePanel extends StatelessWidget {
  final List<TwitchThirdPartyEmote> thirdPartyFavorites;
  final List<TwitchOfficialEmote> officialFavorites;
  final TwitchThirdPartyEmoteCacheService thirdPartyCache;
  final TwitchOfficialEmoteCacheService? officialCache;
  final String query;
  final String emptyText;
  final ValueChanged<TwitchThirdPartyEmote> onInsertThirdParty;
  final ValueChanged<TwitchOfficialEmote> onInsertOfficial;
  final VoidCallback onChanged;

  const _FavoriteEmotePanel({
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
        .map(_FavoriteEmoteEntry.thirdParty)
        .toList(growable: false);

    final official = officialFavorites
        .where((emote) => lowerQuery.isEmpty ||
            emote.name.toLowerCase().contains(lowerQuery) ||
            emote.id.toLowerCase().contains(lowerQuery))
        .map(_FavoriteEmoteEntry.official)
        .toList(growable: false);

    final entries = <_FavoriteEmoteEntry>[
      ...thirdParty,
      ...official,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              height: 1.35,
            ),
          ),
        ),
      );
    }

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
          return _ThirdPartyEmoteGridCard(
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
        final locked = emote.locked;
        return _OfficialEmoteGridCard(
          emote: emote,
          locked: locked,
          favorite: cache?.isFavorite(emote) ?? true,
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

class _FavoriteEmoteEntry {
  final TwitchThirdPartyEmote? thirdParty;
  final TwitchOfficialEmote? official;

  const _FavoriteEmoteEntry.thirdParty(TwitchThirdPartyEmote emote)
      : thirdParty = emote,
        official = null;

  const _FavoriteEmoteEntry.official(TwitchOfficialEmote emote)
      : thirdParty = null,
        official = emote;

  String get name => thirdParty?.name ?? official?.name ?? '';
}

class _TwitchOfficialEmotePanel extends StatelessWidget {
  final TwitchOfficialEmoteCacheService? official;
  final String query;
  final bool loading;
  final String emptyText;
  final _OfficialEmoteSubFilter subFilter;
  final ValueChanged<_OfficialEmoteSubFilter> onSubFilterChanged;
  final ValueChanged<TwitchOfficialEmote> onInsert;
  final VoidCallback onChanged;

  const _TwitchOfficialEmotePanel({
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
      return Center(
        child: Text(
          emptyText,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    final global = _filter(service.globalEmotes);
    final usable = _filter(service.usableEmotes)
        .where((emote) => emote.source != TwitchOfficialEmoteSource.global)
        .toList(growable: false);
    final channel = _filter(service.lockedChannelEmotes);

    if (loading && service.visibleCount == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    final selected = switch (subFilter) {
      _OfficialEmoteSubFilter.usable => usable,
      _OfficialEmoteSubFilter.channel => channel,
      _OfficialEmoteSubFilter.global => global,
    };

    final selectedLocked = subFilter == _OfficialEmoteSubFilter.channel;
    final currentEmptyText = switch (subFilter) {
      _OfficialEmoteSubFilter.usable => '目前沒有我的可用 Twitch 貼圖。',
      _OfficialEmoteSubFilter.channel => '目前沒有實況主頻道貼圖。',
      _OfficialEmoteSubFilter.global => '目前沒有 Twitch 共用貼圖。',
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
              _OfficialSubFilterChip(
                label: '我的可用',
                count: usable.length,
                selected: subFilter == _OfficialEmoteSubFilter.usable,
                onTap: () => onSubFilterChanged(_OfficialEmoteSubFilter.usable),
              ),
              _OfficialSubFilterChip(
                label: '實況主',
                count: channel.length,
                selected: subFilter == _OfficialEmoteSubFilter.channel,
                onTap: () => onSubFilterChanged(_OfficialEmoteSubFilter.channel),
              ),
              _OfficialSubFilterChip(
                label: '全部共用',
                count: global.length,
                selected: subFilter == _OfficialEmoteSubFilter.global,
                onTap: () => onSubFilterChanged(_OfficialEmoteSubFilter.global),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: selected.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      global.isEmpty && usable.isEmpty && channel.isEmpty
                          ? emptyText
                          : currentEmptyText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        height: 1.35,
                      ),
                    ),
                  ),
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
                    return _OfficialEmoteGridCard(
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

  List<TwitchOfficialEmote> _filter(List<TwitchOfficialEmote> source) {
    return source
        .where((emote) => query.isEmpty ||
            emote.name.toLowerCase().contains(query) ||
            emote.id.toLowerCase().contains(query))
        .take(120)
        .toList(growable: false);
  }
}

class _OfficialSubFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _OfficialSubFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? const Color(0xFF9146FF).withOpacity(0.26)
        : const Color(0xFF242429);
    final foreground = selected ? const Color(0xFFD9C5FF) : Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF9146FF).withOpacity(0.7)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  color: foreground.withOpacity(0.62),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmoteTabChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _EmoteTabChip({
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? const Color(0xFF9146FF).withOpacity(0.26)
        : const Color(0xFF242429);
    final foreground = selected ? const Color(0xFFD9C5FF) : Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF9146FF).withOpacity(0.7)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  color: foreground.withOpacity(0.62),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThirdPartyEmoteGridCard extends StatelessWidget {
  final TwitchThirdPartyEmote emote;
  final bool favorite;
  final VoidCallback onInsert;
  final VoidCallback onToggleFavorite;

  const _ThirdPartyEmoteGridCard({
    required this.emote,
    required this.favorite,
    required this.onInsert,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onInsert,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF242429),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: emote.isZeroWidth
                ? const Color(0xFFEAB308).withOpacity(0.55)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: Image.network(
                      emote.imageUrl,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  emote.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      emote.providerLabel,
                      style: const TextStyle(fontSize: 9, color: Colors.white38),
                    ),
                    if (emote.isZeroWidth) ...[
                      const SizedBox(width: 4),
                      const Text(
                        'ZW',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFFEAB308),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            Positioned(
              top: -8,
              right: -8,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onToggleFavorite,
                icon: Icon(
                  favorite ? Icons.star : Icons.star_border,
                  size: 18,
                  color: favorite ? const Color(0xFFEAB308) : Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficialEmoteGridCard extends StatelessWidget {
  final TwitchOfficialEmote emote;
  final bool locked;
  final bool favorite;
  final VoidCallback onInsert;
  final VoidCallback onToggleFavorite;

  const _OfficialEmoteGridCard({
    required this.emote,
    required this.locked,
    required this.favorite,
    required this.onInsert,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: locked ? null : onInsert,
      child: Opacity(
          opacity: locked ? 0.48 : 1,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF242429),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: locked
                    ? const Color(0xFFFFD166).withOpacity(0.32)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Image.network(
                          emote.imageUrl,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      emote.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      locked ? 'LOCKED' : emote.sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: locked ? const Color(0xFFFFD166) : Colors.white38,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggleFavorite,
                    icon: Icon(
                      favorite ? Icons.star : Icons.star_border,
                      size: 18,
                      color: favorite ? const Color(0xFFEAB308) : Colors.white54,
                    ),
                  ),
                ),
                if (locked)
                  const Positioned(
                    top: 0,
                    left: 0,
                    child: Icon(
                      Icons.lock_rounded,
                      size: 16,
                      color: Color(0xFFFFD166),
                    ),
                  ),
              ],
            ),
          ),
        ),
    );
  }
}


class _TwitchOfficialEmoteIdPickerSheet extends StatefulWidget {
  final TwitchOfficialEmoteCacheService officialCache;
  final bool loading;
  final Future<void> Function() onRefresh;
  final String title;
  final String subtitle;
  final bool includeGlobalEmotes;
  final bool includeUnlockedEmotes;
  final bool includeLockedChannelEmotes;

  const _TwitchOfficialEmoteIdPickerSheet({
    required this.officialCache,
    required this.loading,
    required this.onRefresh,
    required this.title,
    required this.subtitle,
    required this.includeGlobalEmotes,
    required this.includeUnlockedEmotes,
    required this.includeLockedChannelEmotes,
  });

  @override
  State<_TwitchOfficialEmoteIdPickerSheet> createState() =>
      _TwitchOfficialEmoteIdPickerSheetState();
}

class _TwitchOfficialEmoteIdPickerSheetState
    extends State<_TwitchOfficialEmoteIdPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cache = widget.officialCache;
    final query = _query.trim().toLowerCase();
    final usable = widget.includeUnlockedEmotes
        ? _filter(cache.usableEmotes, query)
        : const <TwitchOfficialEmote>[];
    final locked = widget.includeLockedChannelEmotes
        ? _filter(cache.lockedChannelEmotes, query)
        : const <TwitchOfficialEmote>[];
    final global = widget.includeGlobalEmotes
        ? _filter(cache.globalEmotes, query)
        : const <TwitchOfficialEmote>[];
    final busy = widget.loading || cache.loading;

    return SafeArea(
      child: TwitchUnifiedSheetScaffold(
        title: widget.title,
        subtitle: widget.subtitle,
        icon: Icons.emoji_emotions_rounded,
        loading: busy,
        onRefresh: () async {
          await widget.onRefresh();
          if (mounted) setState(() {});
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                cursorColor: const Color(0xFFBF94FF),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '搜尋 Twitch 官方貼圖名稱或 ID',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF0E0E10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2D2D35)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2D2D35)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF9146FF)),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: busy && cache.visibleCount == 0
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF9146FF),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                      children: [
                        if (locked.isNotEmpty)
                          _OfficialIdPickerSection(
                            title: '此頻道可解鎖',
                            emotes: locked,
                            badge: 'LOCKED',
                          ),
                        if (usable.isNotEmpty)
                          _OfficialIdPickerSection(
                            title: '我的可用 / 此頻道',
                            emotes: usable,
                            badge: 'OWNED',
                          ),
                        if (global.isNotEmpty)
                          _OfficialIdPickerSection(
                            title: 'Twitch 共用',
                            emotes: global,
                            badge: 'GLOBAL',
                          ),
                        if (locked.isEmpty && usable.isEmpty && global.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                '沒有可選的 Twitch 官方貼圖。請重新整理或確認 OAuth scope / channelId。',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white54,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<TwitchOfficialEmote> _filter(
    List<TwitchOfficialEmote> source,
    String query,
  ) {
    return source
        .where((emote) =>
            query.isEmpty ||
            emote.name.toLowerCase().contains(query) ||
            emote.id.toLowerCase().contains(query))
        .take(160)
        .toList(growable: false);
  }
}

class _OfficialIdPickerSection extends StatelessWidget {
  final String title;
  final List<TwitchOfficialEmote> emotes;
  final String badge;

  const _OfficialIdPickerSection({
    required this.title,
    required this.emotes,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Text(
              '$title · ${emotes.length}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: emotes.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 126,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.86,
            ),
            itemBuilder: (context, index) {
              final emote = emotes[index];
              return _OfficialEmoteIdGridCard(
                emote: emote,
                badge: badge,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OfficialEmoteIdGridCard extends StatelessWidget {
  final TwitchOfficialEmote emote;
  final String badge;

  const _OfficialEmoteIdGridCard({
    required this.emote,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
          final selectedId = await _confirmOfficialEmoteId(
            context: context,
            emote: emote,
            badge: badge,
          );
          if (selectedId == null || selectedId.trim().isEmpty) return;
          if (!context.mounted) return;
          debugPrint(
            '[ChannelPointsEmoteIdPicker] selected name=${emote.name} id=$selectedId badge=$badge',
          );
          Navigator.of(context).pop(selectedId.trim());
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF242429),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Image.network(
                    emote.imageUrl,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                emote.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ID: ${emote.id}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                badge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
    );
  }
}

Future<String?> _confirmOfficialEmoteId({
  required BuildContext context,
  required TwitchOfficialEmote emote,
  required String badge,
}) {
  return showTwitchUnifiedSheet<String>(
    context: context,
    title: '確認使用這個 emote ID',
    subtitle: emote.name,
    icon: Icons.tag_rounded,
    size: TwitchUnifiedSheetSize.compact,
    showRefresh: false,
    builder: (dialogContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Image.network(
                        emote.imageUrl,
                        width: 72,
                        height: 72,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image, color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      emote.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      emote.id,
                      style: const TextStyle(
                        color: Color(0xFFBF94FF),
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      badge,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(emote.id),
                  child: const Text('使用'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
