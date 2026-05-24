// PATCH VERSION: twitch_emote_picker_sheet_stage249_shared_emote_image

import 'package:flutter/material.dart';

import '../../models/emotes/twitch_official_emote.dart';
import '../../models/emotes/twitch_third_party_emote.dart';
import '../../services/chat/twitch_official_emote_cache_service.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../theme/twitch_ui_tokens.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import '../widgets/shared/twitch_emote_image.dart';

const int _initialGridCount = 96;
const int _searchGridLimit = 240;
const double _cardMaxExtent = 154.0;
const double _cardAspectRatio = 0.98;
const bool _emotePickerDebugEnabled = false;

void _emotePickerDebugLog(String message) {
  if (!_emotePickerDebugEnabled) return;
  debugPrint('[TwitchEmotePickerDebug] $message', wrapWidth: 1024);
}

Future<void> showTwitchEmotePickerSheet({
  required BuildContext context,
  required TwitchThirdPartyEmoteCacheService cache,
  TwitchOfficialEmoteCacheService? officialCache,
  required bool loading,
  required Future<void> Function() onRefresh,
  required ValueChanged<String> onEmoteSelected,
}) {
  _emotePickerDebugLog(
    'show sheet loading=$loading thirdParty=${cache.count} '
    'officialChannel=${officialCache?.channelEmotes.length} '
    'officialGlobal=${officialCache?.globalEmotes.length} '
    'officialUser=${officialCache?.userEmotes.length}',
  );

  return showTwitchResponsiveSheet<void>(
    context: context,
    size: TwitchUnifiedSheetSize.large,
    builder: (_) => TwitchUnifiedEmotePickerSheet(
      cache: cache,
      officialCache: officialCache,
      loading: loading,
      onRefresh: onRefresh,
      onEmoteSelected: onEmoteSelected,
    ),
  );
}

class TwitchUnifiedEmotePickerSheet extends StatefulWidget {
  final TwitchThirdPartyEmoteCacheService cache;
  final TwitchOfficialEmoteCacheService? officialCache;
  final bool loading;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onEmoteSelected;

  const TwitchUnifiedEmotePickerSheet({
    super.key,
    required this.cache,
    required this.loading,
    required this.onRefresh,
    required this.onEmoteSelected,
    this.officialCache,
  });

  @override
  State<TwitchUnifiedEmotePickerSheet> createState() =>
      _TwitchUnifiedEmotePickerSheetState();
}

class _TwitchUnifiedEmotePickerSheetState
    extends State<TwitchUnifiedEmotePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  TwitchOfficialEmoteCacheService? get _official => widget.officialCache;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final official = _official;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.cache,
        if (official != null) official,
      ]),
      builder: (context, _) {
        final loading =
            widget.loading ||
            widget.cache.loading ||
            (official?.loading ?? false);

        final tabs = <_OuterTab>[
          _recentTab(),
          _favoriteTab(),
          _officialTab(),
          _thirdPartyTab('7TV', TwitchThirdPartyEmoteProvider.sevenTv),
          _thirdPartyTab('BTTV', TwitchThirdPartyEmoteProvider.bttv),
          _thirdPartyTab('FFZ', TwitchThirdPartyEmoteProvider.ffz),
        ];

        return SafeArea(
          child: TwitchUnifiedSheetScaffold(
            title: '貼圖',
            subtitle: '最近 / 最愛 / Twitch / 7TV / BTTV / FFZ｜長按收藏',
            icon: Icons.emoji_emotions_rounded,
            loading: loading,
            onRefresh: widget.onRefresh,
            child: DefaultTabController(
              length: tabs.length,
              child: Column(
                children: [
                  _SearchBar(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _query = value.trim().toLowerCase();
                      });
                    },
                  ),
                  _MainTabBar(tabs: tabs),
                  const Divider(height: 1),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (final tab in tabs)
                          _ProviderPage(
                            key: PageStorageKey<String>(
                              'provider-${tab.label}',
                            ),
                            tab: tab,
                            query: _query,
                            loading: loading,
                            onSelect: _selectEntry,
                            onLongPress: _toggleFavorite,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  _OuterTab _recentTab() {
    final official = _official;
    return _OuterTab(
      label: 'Recent',
      pages: [
        _InnerPage(
          label: 'Recent',
          entries: <_EmoteEntry>[
            ...widget.cache.recentEmotes.map(_thirdPartyEntry),
            ...(official?.recentEmotes ?? const <TwitchOfficialEmote>[]).map(
              _officialEntry,
            ),
          ],
        ),
      ],
    );
  }

  _OuterTab _favoriteTab() {
    final official = _official;
    return _OuterTab(
      label: 'Favorite',
      pages: [
        _InnerPage(
          label: 'Favorite',
          entries: <_EmoteEntry>[
            ...widget.cache.favoriteEmotes.map(_thirdPartyEntry),
            ...(official?.favoriteEmotes ?? const <TwitchOfficialEmote>[]).map(
              _officialEntry,
            ),
          ],
        ),
      ],
    );
  }

  _OuterTab _officialTab() {
    final official = _official;

    if (official == null) {
      return const _OuterTab(
        label: 'Twitch',
        pages: [
          _InnerPage(label: 'Channel', entries: <_EmoteEntry>[]),
          _InnerPage(label: 'Global', entries: <_EmoteEntry>[]),
          _InnerPage(label: 'Unlocked', entries: <_EmoteEntry>[]),
        ],
      );
    }

    final channel = _uniqueOfficial(official.channelEmotes);
    final global = _uniqueOfficial(official.globalEmotes);
    final user = _uniqueOfficial(official.userEmotes);

    _emotePickerDebugLog(
      'official tab channel=${channel.length} global=${global.length} user=${user.length}',
    );

    final channelKeys = channel.map(_officialKey).toSet();
    final globalKeys = global.map(_officialKey).toSet();
    final currentChannelId = official.channelId.trim();

    final userOnly = user
        .where((emote) {
          final key = _officialKey(emote);
          if (channelKeys.contains(key)) return false;
          if (globalKeys.contains(key)) return false;
          if (currentChannelId.isNotEmpty &&
              emote.ownerId.trim() == currentChannelId) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    final unlocked = _uniqueOfficial(
      userOnly.where((emote) => _isUnlockedOfficialEmote(emote)),
    );
    final subscriptions = _uniqueOfficial(
      userOnly.where((emote) => !_isUnlockedOfficialEmote(emote)),
    );
    final subscriptionGroups = _groupOfficialByOwner(subscriptions);

    return _OuterTab(
      label: 'Twitch',
      pages: [
        _InnerPage(
          label: 'Channel',
          entries: channel.map(_officialEntry).toList(growable: false),
        ),
        _InnerPage(
          label: 'Global',
          entries: global.map(_officialEntry).toList(growable: false),
        ),
        for (final group in subscriptionGroups.entries)
          _InnerPage(
            label: group.key,
            entries: group.value.map(_officialEntry).toList(growable: false),
          ),
        _InnerPage(
          label: 'Unlocked',
          entries: unlocked.map(_officialEntry).toList(growable: false),
        ),
      ],
    );
  }

  _OuterTab _thirdPartyTab(
    String label,
    TwitchThirdPartyEmoteProvider provider,
  ) {
    final source = widget.cache.emotesForProvider(provider);
    final channel = source
        .where((emote) => emote.scope == TwitchThirdPartyEmoteScope.channel)
        .map(_thirdPartyEntry)
        .toList(growable: false);
    final shared = source
        .where((emote) => emote.scope == TwitchThirdPartyEmoteScope.shared)
        .map(_thirdPartyEntry)
        .toList(growable: false);
    final global = source
        .where((emote) => emote.scope == TwitchThirdPartyEmoteScope.global)
        .map(_thirdPartyEntry)
        .toList(growable: false);
    final other = source
        .where((emote) => emote.scope == TwitchThirdPartyEmoteScope.other)
        .map(_thirdPartyEntry)
        .toList(growable: false);
    final zeroWidth = source
        .where((emote) => emote.isZeroWidth)
        .map(_thirdPartyEntry)
        .toList(growable: false);

    return _OuterTab(
      label: label,
      pages: [
        _InnerPage(
          label: 'Channel',
          entries: <_EmoteEntry>[...channel, ...shared, ...other],
        ),
        _InnerPage(label: 'Global', entries: global),
        if (zeroWidth.isNotEmpty) _InnerPage(label: 'ZW', entries: zeroWidth),
      ],
    );
  }

  _EmoteEntry _thirdPartyEntry(TwitchThirdPartyEmote emote) {
    return _EmoteEntry.thirdParty(
      emote,
      favorite: widget.cache.isFavorite(emote),
    );
  }

  _EmoteEntry _officialEntry(TwitchOfficialEmote emote) {
    return _EmoteEntry.official(
      emote,
      favorite: _official?.isFavorite(emote) ?? false,
      locked: _isOfficialEntryLocked(emote),
    );
  }

  bool _isOfficialEntryLocked(TwitchOfficialEmote emote) {
    final official = _official;
    if (official == null) return emote.locked;
    if (official.isUsable(emote)) return false;
    if (official.userEmotesUnavailable &&
        emote.source == TwitchOfficialEmoteSource.channel) {
      return false;
    }
    return true;
  }

  Map<String, List<TwitchOfficialEmote>> _groupOfficialByOwner(
    List<TwitchOfficialEmote> emotes,
  ) {
    final grouped = <String, List<TwitchOfficialEmote>>{};
    for (final emote in emotes) {
      final ownerLabel = _ownerLabel(emote);
      grouped.putIfAbsent(ownerLabel, () => <TwitchOfficialEmote>[]).add(emote);
    }
    final keys = grouped.keys.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return <String, List<TwitchOfficialEmote>>{
      for (final key in keys)
        key: _uniqueOfficial(grouped[key] ?? const <TwitchOfficialEmote>[]),
    };
  }

  String _ownerLabel(TwitchOfficialEmote emote) {
    final display = emote.ownerDisplayName.trim();
    if (display.isNotEmpty) return display;
    final ownerId = emote.ownerId.trim();
    if (ownerId.isNotEmpty) return 'Sub $ownerId';
    final setId = emote.emoteSetId.trim();
    if (setId.isNotEmpty) return 'Sub $setId';
    return 'Sub';
  }

  bool _isUnlockedOfficialEmote(TwitchOfficialEmote emote) {
    final ownerId = emote.ownerId.trim();
    final ownerDisplayName = emote.ownerDisplayName.trim();
    final ownerIsMissing = ownerId.isEmpty && ownerDisplayName.isEmpty;
    final type = emote.emoteType.toLowerCase();
    return ownerIsMissing ||
        type.contains('unlock') ||
        type.contains('unlocked') ||
        type.contains('hypetrain') ||
        type.contains('prime') ||
        type.contains('limitedtime');
  }

  List<TwitchOfficialEmote> _uniqueOfficial(
    Iterable<TwitchOfficialEmote> source,
  ) {
    final byKey = <String, TwitchOfficialEmote>{};
    for (final emote in source) {
      byKey[_officialKey(emote)] = emote;
    }
    final output = byKey.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return output;
  }

  String _officialKey(TwitchOfficialEmote emote) {
    final id = emote.id.trim();
    return id.isNotEmpty ? 'id:$id' : 'name:${emote.name.trim().toLowerCase()}';
  }

  void _selectEntry(_EmoteEntry entry) {
    if (entry.locked) return;
    var changedRecent = false;
    final thirdParty = entry.thirdParty;
    if (thirdParty != null) {
      widget.cache.markRecentEmote(thirdParty);
      changedRecent = true;
    }
    final official = entry.official;
    if (official != null) {
      _official?.markRecentEmote(official);
      changedRecent = true;
    }
    if (changedRecent && mounted) setState(() {});
    final name = entry.name.trim();
    if (name.isNotEmpty) widget.onEmoteSelected(name);
  }

  void _toggleFavorite(_EmoteEntry entry) {
    final thirdParty = entry.thirdParty;
    if (thirdParty != null) {
      widget.cache.toggleFavorite(thirdParty);
      setState(() {});
      return;
    }
    final official = entry.official;
    if (official != null) {
      _official?.toggleFavorite(official);
      setState(() {});
    }
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: SizedBox(
        height: 38,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          cursorColor: TwitchUiColors.sheet.backplate.foreground,
          decoration: InputDecoration(
            isDense: true,
            hintText: '搜尋貼圖名稱',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Colors.white54,
              size: 18,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 34,
              minHeight: 34,
            ),
            filled: true,
            fillColor: TwitchUiColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
          ),
        ),
      ),
    );
  }
}

class _MainTabBar extends StatelessWidget {
  final List<_OuterTab> tabs;

  const _MainTabBar({required this.tabs});

  @override
  Widget build(BuildContext context) {
    return TabBar(
      isScrollable: true,
      labelColor: TwitchUiColors.sheet.backplate.foreground,
      unselectedLabelColor: Colors.white60,
      indicatorColor: TwitchUiColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
      tabs: [
        for (final tab in tabs) Tab(text: '${tab.label} ${tab.totalCount}'),
      ],
    );
  }
}

class _ProviderPage extends StatefulWidget {
  final _OuterTab tab;
  final String query;
  final bool loading;
  final ValueChanged<_EmoteEntry> onSelect;
  final ValueChanged<_EmoteEntry> onLongPress;

  const _ProviderPage({
    super.key,
    required this.tab,
    required this.query,
    required this.loading,
    required this.onSelect,
    required this.onLongPress,
  });

  @override
  State<_ProviderPage> createState() => _ProviderPageState();
}

class _ProviderPageState extends State<_ProviderPage>
    with AutomaticKeepAliveClientMixin<_ProviderPage> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tab = widget.tab;

    return DefaultTabController(
      length: tab.pages.length,
      child: Column(
        children: [
          if (tab.pages.length > 1)
            SizedBox(
              height: 34,
              child: TabBar(
                isScrollable: true,
                labelColor: TwitchUiColors.sheet.backplate.foreground,
                unselectedLabelColor: Colors.white54,
                indicatorColor: TwitchUiColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                labelStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  for (final page in tab.pages)
                    Tab(text: '${page.label} ${page.entries.length}'),
                ],
              ),
            ),
          if (tab.pages.length > 1) const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                for (final page in tab.pages)
                  _EmoteSection(
                    key: PageStorageKey<String>(
                      'section-${tab.label}-${page.label}',
                    ),
                    entries: page.entries,
                    query: widget.query,
                    emptyText: widget.loading
                        ? 'Loading emotes...'
                        : 'No emotes',
                    onSelect: widget.onSelect,
                    onLongPress: widget.onLongPress,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _EmoteSection extends StatefulWidget {
  final List<_EmoteEntry> entries;
  final String query;
  final String emptyText;
  final ValueChanged<_EmoteEntry> onSelect;
  final ValueChanged<_EmoteEntry> onLongPress;

  const _EmoteSection({
    super.key,
    required this.entries,
    required this.query,
    required this.emptyText,
    required this.onSelect,
    required this.onLongPress,
  });

  @override
  State<_EmoteSection> createState() => _EmoteSectionState();
}

class _EmoteSectionState extends State<_EmoteSection>
    with AutomaticKeepAliveClientMixin<_EmoteSection> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final entries = _filteredEntries();

    if (entries.isEmpty) {
      return Center(
        child: Text(
          widget.emptyText,
          style: const TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
        cacheExtent: 360,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _cardMaxExtent,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: _cardAspectRatio,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _EmoteTile(
            key: ValueKey<String>(entry.stableKey),
            entry: entry,
            onTap: () => widget.onSelect(entry),
            onLongPress: () => widget.onLongPress(entry),
          );
        },
      ),
    );
  }

  List<_EmoteEntry> _filteredEntries() {
    final query = widget.query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.entries.take(_initialGridCount).toList(growable: false);
    }
    return widget.entries
        .where((entry) {
          return entry.name.toLowerCase().contains(query) ||
              entry.id.toLowerCase().contains(query) ||
              entry.providerLabel.toLowerCase().contains(query);
        })
        .take(_searchGridLimit)
        .toList(growable: false);
  }

  @override
  bool get wantKeepAlive => true;
}

class _EmoteTile extends StatelessWidget {
  final _EmoteEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _EmoteTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final locked = entry.locked;

    return RepaintBoundary(
      child: Tooltip(
        message: entry.favorite ? '長按取消收藏' : '長按加入收藏',
        waitDuration: const Duration(milliseconds: 650),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: locked ? null : onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 9, 8, 8),
            decoration: BoxDecoration(
              color: TwitchUiColors.sheet.cardFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: entry.favorite
                    ? const Color(0xFFEAB308).withOpacity(0.78)
                    : locked
                    ? const Color(0xFFFFD166).withOpacity(0.38)
                    : TwitchUiColors.sheet.backplate.border,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: entry.imageUrl.trim().isEmpty
                            ? Icon(
                                locked
                                    ? Icons.lock_rounded
                                    : Icons.broken_image_rounded,
                                color: Colors.white38,
                                size: 24,
                              )
                            : TwitchEmoteImage(
                                id: entry.id,
                                name: entry.name,
                                imageUrl: entry.imageUrl,
                                providerLabel: entry.providerLabel,
                                isOfficial: entry.isOfficial,
                                locked: locked,
                                fit: BoxFit.contain,
                                memCacheWidth: 144,
                                memCacheHeight: 144,
                                placeholder: const SizedBox.shrink(),
                                errorPlaceholder: const Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.white38,
                                  size: 22,
                                ),
                                debug: false,
                                debugTag: 'TwitchEmotePickerImage',
                              ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (entry.favorite)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      Icons.star_rounded,
                      color: Color(0xFFEAB308),
                      size: 17,
                    ),
                  ),
                if (locked)
                  const Positioned(
                    right: 0,
                    bottom: 20,
                    child: Icon(
                      Icons.lock_rounded,
                      color: Color(0xFFFFD166),
                      size: 17,
                    ),
                  ),
                if (entry.zeroWidth)
                  const Positioned(
                    top: 0,
                    left: 0,
                    child: Text(
                      'ZW',
                      style: TextStyle(
                        color: Color(0xFFEAB308),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
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

class _OuterTab {
  final String label;
  final List<_InnerPage> pages;

  const _OuterTab({required this.label, required this.pages});

  int get totalCount {
    return pages.fold<int>(0, (sum, page) => sum + page.entries.length);
  }
}

class _InnerPage {
  final String label;
  final List<_EmoteEntry> entries;

  const _InnerPage({required this.label, required this.entries});
}

class _EmoteEntry {
  final String id;
  final String name;
  final String imageUrl;
  final String providerLabel;
  final bool locked;
  final bool favorite;
  final bool zeroWidth;
  final TwitchThirdPartyEmote? thirdParty;
  final TwitchOfficialEmote? official;

  const _EmoteEntry({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.providerLabel,
    required this.locked,
    required this.favorite,
    required this.zeroWidth,
    this.thirdParty,
    this.official,
  });

  factory _EmoteEntry.thirdParty(
    TwitchThirdPartyEmote emote, {
    required bool favorite,
  }) {
    return _EmoteEntry(
      id: emote.id,
      name: emote.name,
      imageUrl: emote.imageUrl,
      providerLabel: emote.providerLabel,
      locked: false,
      favorite: favorite,
      zeroWidth: emote.isZeroWidth,
      thirdParty: emote,
    );
  }

  factory _EmoteEntry.official(
    TwitchOfficialEmote emote, {
    required bool favorite,
    bool? locked,
  }) {
    return _EmoteEntry(
      id: emote.id,
      name: emote.name,
      imageUrl: emote.imageUrl,
      providerLabel: emote.sourceLabel,
      locked: locked ?? emote.locked,
      favorite: favorite,
      zeroWidth: false,
      official: emote,
    );
  }

  bool get isOfficial => official != null;

  String get stableKey {
    final cleanId = id.trim();
    return cleanId.isNotEmpty
        ? '$providerLabel:$cleanId'
        : '$providerLabel:${name.trim().toLowerCase()}';
  }
}
