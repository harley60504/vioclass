import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../models/emotes/twitch_official_emote.dart';
import '../../models/emotes/twitch_third_party_emote.dart';
import '../../services/chat/twitch_official_emote_cache_service.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

const double _emoteSize = 30.0;

final CacheManager _sheetEmoteCacheManager = CacheManager(
  Config(
    'twitchPublicSheetEmoteImageCache',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 10000,
  ),
);

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
    size: TwitchUnifiedSheetSize.medium,
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
  TwitchOfficialEmoteCacheService? get _official => widget.officialCache;

  @override
  Widget build(BuildContext context) {
    final official = _official;
    final loading = widget.loading || (official?.loading ?? false);
    final tabs = <_OuterTab>[
      _OuterTab(
        label: 'Recent',
        pages: [
          _InnerPage(
            label: 'Recent',
            entries: <_EmoteEntry>[
              ...widget.cache.recentEmotes.map(_EmoteEntry.thirdParty),
              ...(official?.recentEmotes ?? const <TwitchOfficialEmote>[])
                  .map(_EmoteEntry.official),
            ],
          ),
        ],
      ),
      _OuterTab(
        label: 'Favorite',
        pages: [
          _InnerPage(
            label: 'Favorite',
            entries: <_EmoteEntry>[
              ...widget.cache.favoriteEmotes.map(_EmoteEntry.thirdParty),
              ...(official?.favoriteEmotes ?? const <TwitchOfficialEmote>[])
                  .map(_EmoteEntry.official),
            ],
          ),
        ],
      ),
      _officialTab(),
      _thirdPartyTab('7TV', TwitchThirdPartyEmoteProvider.sevenTv),
      _thirdPartyTab('BTTV', TwitchThirdPartyEmoteProvider.bttv),
      _thirdPartyTab('FFZ', TwitchThirdPartyEmoteProvider.ffz),
    ];

    return SafeArea(
      child: TwitchUnifiedSheetScaffold(
        title: '貼圖',
        subtitle: 'Frosty-like 分類｜Twitch / 7TV / BTTV / FFZ',
        icon: Icons.emoji_emotions_rounded,
        loading: loading,
        onRefresh: widget.onRefresh,
        child: DefaultTabController(
          length: tabs.length,
          child: Column(
            children: [
              _MainTabBar(tabs: tabs),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final tab in tabs)
                      _ProviderPage(
                        key: PageStorageKey<String>('provider-${tab.label}'),
                        tab: tab,
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

    final channelKeys = channel.map(_officialKey).toSet();
    final globalKeys = global.map(_officialKey).toSet();
    final currentChannelId = official.channelId.trim();

    final userOnly = user.where((emote) {
      final key = _officialKey(emote);
      if (channelKeys.contains(key)) return false;
      if (globalKeys.contains(key)) return false;
      if (currentChannelId.isNotEmpty && emote.ownerId.trim() == currentChannelId) {
        return false;
      }
      return true;
    }).toList(growable: false);

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
          entries: channel.map(_EmoteEntry.official).toList(growable: false),
        ),
        _InnerPage(
          label: 'Global',
          entries: global.map(_EmoteEntry.official).toList(growable: false),
        ),
        for (final group in subscriptionGroups.entries)
          _InnerPage(
            label: group.key,
            entries: group.value.map(_EmoteEntry.official).toList(growable: false),
          ),
        _InnerPage(
          label: 'Unlocked',
          entries: unlocked.map(_EmoteEntry.official).toList(growable: false),
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
        .map(_EmoteEntry.thirdParty)
        .toList(growable: false);
    final shared = source
        .where((emote) => emote.scope == TwitchThirdPartyEmoteScope.shared)
        .map(_EmoteEntry.thirdParty)
        .toList(growable: false);
    final global = source
        .where((emote) => emote.scope == TwitchThirdPartyEmoteScope.global)
        .map(_EmoteEntry.thirdParty)
        .toList(growable: false);
    final other = source
        .where((emote) => emote.scope == TwitchThirdPartyEmoteScope.other)
        .map(_EmoteEntry.thirdParty)
        .toList(growable: false);

    return _OuterTab(
      label: label,
      pages: [
        _InnerPage(
          label: 'Channel',
          entries: <_EmoteEntry>[...channel, ...shared, ...other],
        ),
        _InnerPage(label: 'Global', entries: global),
      ],
    );
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

  List<TwitchOfficialEmote> _uniqueOfficial(Iterable<TwitchOfficialEmote> source) {
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
    final thirdParty = entry.thirdParty;
    if (thirdParty != null) widget.cache.markRecentEmote(thirdParty);
    final official = entry.official;
    if (official != null) _official?.markRecentEmote(official);
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

class _MainTabBar extends StatelessWidget {
  final List<_OuterTab> tabs;

  const _MainTabBar({required this.tabs});

  @override
  Widget build(BuildContext context) {
    return TabBar(
      isScrollable: true,
      labelColor: const Color(0xFFD9C5FF),
      unselectedLabelColor: Colors.white60,
      indicatorColor: const Color(0xFF9146FF),
      indicatorSize: TabBarIndicatorSize.label,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
      unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      tabs: [
        for (final tab in tabs) Tab(text: '${tab.label} ${tab.totalCount}'),
      ],
    );
  }
}

class _ProviderPage extends StatefulWidget {
  final _OuterTab tab;
  final bool loading;
  final ValueChanged<_EmoteEntry> onSelect;
  final ValueChanged<_EmoteEntry> onLongPress;

  const _ProviderPage({
    super.key,
    required this.tab,
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
          SizedBox(
            height: 32,
            child: TabBar(
              isScrollable: true,
              labelColor: const Color(0xFFD9C5FF),
              unselectedLabelColor: Colors.white54,
              indicatorColor: const Color(0xFF9146FF),
              indicatorSize: TabBarIndicatorSize.label,
              labelPadding: const EdgeInsets.symmetric(horizontal: 10),
              labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
              tabs: [
                for (final page in tab.pages)
                  Tab(text: '${page.label} ${page.entries.length}'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                for (final page in tab.pages)
                  _EmoteSection(
                    key: PageStorageKey<String>('section-${tab.label}-${page.label}'),
                    entries: page.entries,
                    emptyText: widget.loading ? 'Loading emotes...' : 'No emotes',
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
  final String emptyText;
  final ValueChanged<_EmoteEntry> onSelect;
  final ValueChanged<_EmoteEntry> onLongPress;

  const _EmoteSection({
    super.key,
    required this.entries,
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
    if (widget.entries.isEmpty) {
      return Center(
        child: Text(
          widget.emptyText,
          style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700),
        ),
      );
    }
    final media = MediaQuery.of(context);
    final columns = _columns(media.size.width, media.orientation == Orientation.landscape);
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(6, 3, 6, 10),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
        cacheExtent: 90,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 0,
          crossAxisSpacing: 0,
        ),
        itemCount: widget.entries.length,
        itemBuilder: (context, index) {
          final entry = widget.entries[index];
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

  int _columns(double width, bool landscape) {
    if (landscape) return 6;
    if (width >= 700) return 8;
    return 6;
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
    final imageUrl = entry.imageUrl.trim();
    final locked = entry.locked;
    final width = entry.width == null || entry.width! <= 0
        ? null
        : entry.width!.toDouble().clamp(12.0, 96.0);
    final height = entry.height == null || entry.height! <= 0
        ? _emoteSize
        : entry.height!.toDouble().clamp(12.0, 96.0);

    return InkWell(
      onTap: locked ? null : onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Center(
          child: imageUrl.isEmpty
              ? Icon(
                  locked ? Icons.lock_rounded : Icons.broken_image_rounded,
                  color: Colors.white38,
                  size: 20,
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      cacheKey: entry.stableKey,
                      height: height,
                      width: width,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.low,
                      fadeInDuration: const Duration(milliseconds: 500),
                      fadeOutDuration: const Duration(milliseconds: 500),
                      fadeInCurve: Curves.easeOut,
                      fadeOutCurve: Curves.easeIn,
                      useOldImageOnUrlChange: false,
                      cacheManager: _sheetEmoteCacheManager,
                      color: locked ? Colors.white.withOpacity(0.42) : null,
                      colorBlendMode: locked ? BlendMode.modulate : null,
                      placeholder: (_, __) => const SizedBox.shrink(),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white38,
                        size: 20,
                      ),
                    ),
                    if (locked)
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: Icon(Icons.lock_rounded, color: Color(0xFFFFD166), size: 13),
                      ),
                  ],
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
  int get totalCount => pages.fold<int>(0, (sum, page) => sum + page.entries.length);
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
  final int? width;
  final int? height;
  final TwitchThirdPartyEmote? thirdParty;
  final TwitchOfficialEmote? official;

  const _EmoteEntry({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.providerLabel,
    required this.locked,
    this.width,
    this.height,
    this.thirdParty,
    this.official,
  });

  factory _EmoteEntry.thirdParty(TwitchThirdPartyEmote emote) {
    return _EmoteEntry(
      id: emote.id,
      name: emote.name,
      imageUrl: emote.imageUrl,
      providerLabel: emote.providerLabel,
      locked: false,
      width: emote.width,
      height: emote.height,
      thirdParty: emote,
    );
  }

  factory _EmoteEntry.official(TwitchOfficialEmote emote) {
    return _EmoteEntry(
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
    return cleanId.isNotEmpty ? '$providerLabel:$cleanId' : '$providerLabel:${name.trim().toLowerCase()}';
  }
}
