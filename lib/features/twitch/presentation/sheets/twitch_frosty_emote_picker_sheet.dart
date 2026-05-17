// PATCH VERSION: twitch_frosty_emote_picker_sheet_stage219a
//
// Frosty-style experimental emote picker.
//
// Goal:
// - Keep the old emote picker files intact.
// - Use a lightweight GridView.builder cell similar to Frosty's emote menu.
// - Show all matching emotes instead of clipping third-party grids to 96 items.
// - Use CachedNetworkImage for smoother repeated scrolling.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/emotes/twitch_official_emote.dart';
import '../../models/emotes/twitch_third_party_emote.dart';
import '../../services/chat/twitch_official_emote_cache_service.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import 'emote_picker/twitch_emote_picker_models.dart';

Future<void> showTwitchFrostyEmotePickerSheet({
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
    builder: (_) => TwitchFrostyEmotePickerSheet(
      cache: cache,
      officialCache: officialCache,
      loading: loading,
      onRefresh: onRefresh,
      onEmoteSelected: onEmoteSelected,
    ),
  );
}

class TwitchFrostyEmotePickerSheet extends StatefulWidget {
  final TwitchThirdPartyEmoteCacheService cache;
  final TwitchOfficialEmoteCacheService? officialCache;
  final bool loading;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onEmoteSelected;

  const TwitchFrostyEmotePickerSheet({
    super.key,
    required this.cache,
    required this.loading,
    required this.onRefresh,
    required this.onEmoteSelected,
    this.officialCache,
  });

  @override
  State<TwitchFrostyEmotePickerSheet> createState() =>
      _TwitchFrostyEmotePickerSheetState();
}

class _TwitchFrostyEmotePickerSheetState
    extends State<TwitchFrostyEmotePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  TwitchEmotePickerTab _selectedTab = TwitchEmotePickerTab.recent;
  String _query = '';

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

  void _selectEntry(_FrostyEmoteEntry entry) {
    if (entry.locked) return;

    final thirdParty = entry.thirdParty;
    if (thirdParty != null) {
      widget.cache.markRecentEmote(thirdParty);
    }

    final official = entry.official;
    if (official != null) {
      _official?.markRecentEmote(official);
    }

    final name = entry.name.trim();
    if (name.isNotEmpty) widget.onEmoteSelected(name);
  }

  void _toggleFavorite(_FrostyEmoteEntry entry) {
    final thirdParty = entry.thirdParty;
    if (thirdParty != null) {
      widget.cache.toggleFavorite(thirdParty);
      setState(() {});
      _showLocalMessage(
        widget.cache.isFavorite(thirdParty) ? '已收藏 ${entry.name}' : '已取消收藏 ${entry.name}',
      );
      return;
    }

    final official = entry.official;
    if (official != null) {
      _official?.toggleFavorite(official);
      setState(() {});
      _showLocalMessage(
        (_official?.isFavorite(official) ?? false)
            ? '已收藏 ${entry.name}'
            : '已取消收藏 ${entry.name}',
      );
    }
  }

  void _showLocalMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entriesForCurrentTab();
    final loading = widget.loading || (_official?.loading ?? false);
    final media = MediaQuery.of(context);
    final compactVertical =
        media.size.height < 520 || media.orientation == Orientation.landscape;

    return SafeArea(
      child: TwitchUnifiedSheetScaffold(
        title: '貼圖 Fast',
        subtitle: 'Frosty-style 測試版｜長按收藏',
        icon: Icons.emoji_emotions_rounded,
        loading: loading,
        onRefresh: widget.onRefresh,
        child: Column(
          children: [
            SizedBox(
              height: compactVertical ? 34 : 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _TabChip(
                    label: '最近',
                    icon: Icons.history_rounded,
                    selected: _selectedTab == TwitchEmotePickerTab.recent,
                    count: _countForTab(TwitchEmotePickerTab.recent),
                    onTap: () => _selectTab(TwitchEmotePickerTab.recent),
                  ),
                  _TabChip(
                    label: '收藏',
                    icon: Icons.star_rounded,
                    selected: _selectedTab == TwitchEmotePickerTab.favorites,
                    count: _countForTab(TwitchEmotePickerTab.favorites),
                    onTap: () => _selectTab(TwitchEmotePickerTab.favorites),
                  ),
                  _TabChip(
                    label: 'Twitch',
                    icon: Icons.lock_rounded,
                    selected: _selectedTab == TwitchEmotePickerTab.twitch,
                    count: _countForTab(TwitchEmotePickerTab.twitch),
                    onTap: () => _selectTab(TwitchEmotePickerTab.twitch),
                  ),
                  _TabChip(
                    label: 'BTTV',
                    selected: _selectedTab == TwitchEmotePickerTab.bttv,
                    count: _countForTab(TwitchEmotePickerTab.bttv),
                    onTap: () => _selectTab(TwitchEmotePickerTab.bttv),
                  ),
                  _TabChip(
                    label: '7TV',
                    selected: _selectedTab == TwitchEmotePickerTab.sevenTv,
                    count: _countForTab(TwitchEmotePickerTab.sevenTv),
                    onTap: () => _selectTab(TwitchEmotePickerTab.sevenTv),
                  ),
                  _TabChip(
                    label: 'FFZ',
                    selected: _selectedTab == TwitchEmotePickerTab.ffz,
                    count: _countForTab(TwitchEmotePickerTab.ffz),
                    onTap: () => _selectTab(TwitchEmotePickerTab.ffz),
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
                    hintText: '搜尋貼圖（${entries.length}）',
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
              child: entries.isEmpty
                  ? _FrostyEmoteEmptyState(
                      loading: loading,
                      selectedTab: _selectedTab,
                    )
                  : _FrostyEmoteGrid(
                      entries: entries,
                      onSelect: _selectEntry,
                      onLongPress: _toggleFavorite,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectTab(TwitchEmotePickerTab tab) {
    if (_selectedTab == tab) return;
    setState(() => _selectedTab = tab);
  }

  int _countForTab(TwitchEmotePickerTab tab) {
    switch (tab) {
      case TwitchEmotePickerTab.recent:
        return widget.cache.recentCount + (_official?.recentCount ?? 0);
      case TwitchEmotePickerTab.favorites:
        return widget.cache.favoriteCount + (_official?.favoriteCount ?? 0);
      case TwitchEmotePickerTab.twitch:
        return _official == null ? 0 : _officialEntries(includeLocked: true).length;
      case TwitchEmotePickerTab.bttv:
        return widget.cache.countForProvider(TwitchThirdPartyEmoteProvider.bttv);
      case TwitchEmotePickerTab.sevenTv:
        return widget.cache.countForProvider(TwitchThirdPartyEmoteProvider.sevenTv);
      case TwitchEmotePickerTab.ffz:
        return widget.cache.countForProvider(TwitchThirdPartyEmoteProvider.ffz);
    }
  }

  List<_FrostyEmoteEntry> _entriesForCurrentTab() {
    final raw = switch (_selectedTab) {
      TwitchEmotePickerTab.recent => <_FrostyEmoteEntry>[
          ...widget.cache.recentEmotes.map(_FrostyEmoteEntry.thirdParty),
          ...(_official?.recentEmotes ?? const <TwitchOfficialEmote>[])
              .map(_FrostyEmoteEntry.official),
        ],
      TwitchEmotePickerTab.favorites => <_FrostyEmoteEntry>[
          ...widget.cache.favoriteEmotes.map(_FrostyEmoteEntry.thirdParty),
          ...(_official?.favoriteEmotes ?? const <TwitchOfficialEmote>[])
              .map(_FrostyEmoteEntry.official),
        ],
      TwitchEmotePickerTab.twitch => _officialEntries(includeLocked: true),
      TwitchEmotePickerTab.bttv => widget.cache
          .emotesForProvider(TwitchThirdPartyEmoteProvider.bttv)
          .map(_FrostyEmoteEntry.thirdParty)
          .toList(growable: false),
      TwitchEmotePickerTab.sevenTv => widget.cache
          .emotesForProvider(TwitchThirdPartyEmoteProvider.sevenTv)
          .map(_FrostyEmoteEntry.thirdParty)
          .toList(growable: false),
      TwitchEmotePickerTab.ffz => widget.cache
          .emotesForProvider(TwitchThirdPartyEmoteProvider.ffz)
          .map(_FrostyEmoteEntry.thirdParty)
          .toList(growable: false),
    };

    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return raw;

    return raw
        .where((entry) =>
            entry.name.toLowerCase().contains(query) ||
            entry.id.toLowerCase().contains(query) ||
            entry.providerLabel.toLowerCase().contains(query))
        .toList(growable: false);
  }

  List<_FrostyEmoteEntry> _officialEntries({required bool includeLocked}) {
    final official = _official;
    if (official == null) return const <_FrostyEmoteEntry>[];

    final byKey = <String, TwitchOfficialEmote>{};

    for (final emote in official.usableEmotes) {
      byKey[_officialKey(emote)] = emote;
    }

    if (includeLocked) {
      for (final emote in official.lockedChannelEmotes) {
        byKey.putIfAbsent(_officialKey(emote), () => emote);
      }
    }

    final output = byKey.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return output.map(_FrostyEmoteEntry.official).toList(growable: false);
  }

  String _officialKey(TwitchOfficialEmote emote) {
    final id = emote.id.trim();
    if (id.isNotEmpty) return 'id:$id';
    return 'name:${emote.name.trim().toLowerCase()}';
  }
}

class _FrostyEmoteGrid extends StatelessWidget {
  final List<_FrostyEmoteEntry> entries;
  final ValueChanged<_FrostyEmoteEntry> onSelect;
  final ValueChanged<_FrostyEmoteEntry> onLongPress;

  const _FrostyEmoteGrid({
    required this.entries,
    required this.onSelect,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;
    final landscape = media.orientation == Orientation.landscape;

    final crossAxisCount = _resolveCrossAxisCount(
      width: width,
      height: height,
      landscape: landscape,
    );

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 14),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
        cacheExtent: 420,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _FrostyEmoteTile(
            key: ValueKey<String>(entry.stableKey),
            entry: entry,
            onTap: () => onSelect(entry),
            onLongPress: () => onLongPress(entry),
          );
        },
      ),
    );
  }

  int _resolveCrossAxisCount({
    required double width,
    required double height,
    required bool landscape,
  }) {
    if (width >= 1200) return landscape ? 14 : 10;
    if (width >= 900) return landscape ? 12 : 9;
    if (width >= 700) return landscape ? 10 : 8;
    return landscape ? 8 : 6;
  }
}

class _FrostyEmoteTile extends StatelessWidget {
  final _FrostyEmoteEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FrostyEmoteTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = entry.imageUrl.trim();
    final locked = entry.locked;

    return InkWell(
      onTap: locked ? null : onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Center(
          child: imageUrl.isEmpty
              ? Icon(
                  locked ? Icons.lock_rounded : Icons.broken_image_rounded,
                  color: Colors.white38,
                  size: 22,
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: locked ? 0.42 : 1,
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        cacheKey: entry.stableKey,
                        fit: BoxFit.contain,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        useOldImageOnUrlChange: true,
                        placeholder: (_, __) => const SizedBox.shrink(),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white38,
                          size: 22,
                        ),
                      ),
                    ),
                    if (locked)
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: Icon(
                          Icons.lock_rounded,
                          color: Color(0xFFFFD166),
                          size: 14,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _TabChip({
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

class _FrostyEmoteEmptyState extends StatelessWidget {
  final bool loading;
  final TwitchEmotePickerTab selectedTab;

  const _FrostyEmoteEmptyState({
    required this.loading,
    required this.selectedTab,
  });

  @override
  Widget build(BuildContext context) {
    final text = loading ? '貼圖載入中...' : _emptyText;
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white54,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String get _emptyText {
    switch (selectedTab) {
      case TwitchEmotePickerTab.recent:
        return '目前沒有最近貼圖。';
      case TwitchEmotePickerTab.favorites:
        return '還沒有收藏貼圖。';
      case TwitchEmotePickerTab.twitch:
        return '目前沒有 Twitch 官方 / 頻道貼圖。';
      case TwitchEmotePickerTab.bttv:
        return '目前沒有 BTTV 貼圖。';
      case TwitchEmotePickerTab.sevenTv:
        return '目前沒有 7TV 貼圖。';
      case TwitchEmotePickerTab.ffz:
        return '目前沒有 FFZ 貼圖。';
    }
  }
}

class _FrostyEmoteEntry {
  final String id;
  final String name;
  final String imageUrl;
  final String providerLabel;
  final bool locked;
  final TwitchThirdPartyEmote? thirdParty;
  final TwitchOfficialEmote? official;

  const _FrostyEmoteEntry({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.providerLabel,
    required this.locked,
    this.thirdParty,
    this.official,
  });

  factory _FrostyEmoteEntry.thirdParty(TwitchThirdPartyEmote emote) {
    return _FrostyEmoteEntry(
      id: emote.id,
      name: emote.name,
      imageUrl: emote.imageUrl,
      providerLabel: emote.providerLabel,
      locked: false,
      thirdParty: emote,
    );
  }

  factory _FrostyEmoteEntry.official(TwitchOfficialEmote emote) {
    return _FrostyEmoteEntry(
      id: emote.id,
      name: emote.name,
      imageUrl: emote.imageUrl,
      providerLabel: emote.sourceLabel,
      locked: emote.locked,
      official: emote,
    );
  }

  String get stableKey {
    final cleanId = id.trim();
    if (cleanId.isNotEmpty) return '$providerLabel:$cleanId';
    return '$providerLabel:${name.trim().toLowerCase()}';
  }
}
