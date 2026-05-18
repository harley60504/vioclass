import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../../models/emotes/twitch_official_emote.dart';
import '../../../../models/emotes/twitch_third_party_emote.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';

const double _embeddedEmoteSize = 30.0;

final CacheManager _embeddedEmoteCacheManager = CacheManager(
  Config(
    'twitchEmbeddedEmoteImageCache',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 10000,
  ),
);

class TwitchWatchEmbeddedEmotePanel extends StatefulWidget {
  final TwitchThirdPartyEmoteCacheService thirdPartyCache;
  final TwitchOfficialEmoteCacheService officialCache;
  final bool loading;
  final TextEditingController messageController;
  final VoidCallback onRefresh;

  const TwitchWatchEmbeddedEmotePanel({
    super.key,
    required this.thirdPartyCache,
    required this.officialCache,
    required this.loading,
    required this.messageController,
    required this.onRefresh,
  });

  @override
  State<TwitchWatchEmbeddedEmotePanel> createState() =>
      _TwitchWatchEmbeddedEmotePanelState();
}

class _TwitchWatchEmbeddedEmotePanelState
    extends State<TwitchWatchEmbeddedEmotePanel> {
  @override
  Widget build(BuildContext context) {
    final tabs = <_EmbeddedEmoteProviderTab>[
      _EmbeddedEmoteProviderTab(
        label: 'Recent',
        pages: [
          _EmbeddedEmotePage(
            label: 'Recent',
            entries: <_EmbeddedEmoteEntry>[
              ...widget.thirdPartyCache.recentEmotes
                  .map(_EmbeddedEmoteEntry.thirdParty),
              ...widget.officialCache.recentEmotes
                  .map(_EmbeddedEmoteEntry.official),
            ],
          ),
        ],
      ),
      _EmbeddedEmoteProviderTab(
        label: 'Favorite',
        pages: [
          _EmbeddedEmotePage(
            label: 'Favorite',
            entries: <_EmbeddedEmoteEntry>[
              ...widget.thirdPartyCache.favoriteEmotes
                  .map(_EmbeddedEmoteEntry.thirdParty),
              ...widget.officialCache.favoriteEmotes
                  .map(_EmbeddedEmoteEntry.official),
            ],
          ),
        ],
      ),
      _EmbeddedEmoteProviderTab(
        label: 'Twitch',
        pages: [
          _EmbeddedEmotePage(label: 'All', entries: _officialEntries()),
        ],
      ),
      _thirdPartyProviderTab('7TV', TwitchThirdPartyEmoteProvider.sevenTv),
      _thirdPartyProviderTab('BTTV', TwitchThirdPartyEmoteProvider.bttv),
      _thirdPartyProviderTab('FFZ', TwitchThirdPartyEmoteProvider.ffz),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E10).withOpacity(0.94),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: DefaultTabController(
        length: tabs.length,
        child: Column(
          children: [
            SizedBox(
              height: 38,
              child: Row(
                children: [
                  Expanded(child: _ProviderTabBar(tabs: tabs)),
                  if (widget.loading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF9146FF),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: null,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
                      onPressed: widget.onRefresh,
                    ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final tab in tabs)
                    _EmbeddedProviderPage(
                      key: PageStorageKey<String>('embedded-emote-${tab.label}'),
                      tab: tab,
                      loading: widget.loading,
                      onSelect: _insertEntry,
                      onLongPress: _showEntryDetails,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _EmbeddedEmoteProviderTab _thirdPartyProviderTab(
    String label,
    TwitchThirdPartyEmoteProvider provider,
  ) {
    final entries = widget.thirdPartyCache
        .emotesForProvider(provider)
        .map(_EmbeddedEmoteEntry.thirdParty)
        .toList(growable: false);

    return _EmbeddedEmoteProviderTab(
      label: label,
      pages: [
        _EmbeddedEmotePage(label: 'All', entries: entries),
      ],
    );
  }

  List<_EmbeddedEmoteEntry> _officialEntries() {
    final byKey = <String, TwitchOfficialEmote>{};

    for (final emote in widget.officialCache.usableEmotes) {
      byKey[_officialKey(emote)] = emote;
    }
    for (final emote in widget.officialCache.lockedChannelEmotes) {
      byKey.putIfAbsent(_officialKey(emote), () => emote);
    }

    final output = byKey.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return output.map(_EmbeddedEmoteEntry.official).toList(growable: false);
  }

  String _officialKey(TwitchOfficialEmote emote) {
    final id = emote.id.trim();
    return id.isNotEmpty ? 'id:$id' : 'name:${emote.name.trim().toLowerCase()}';
  }

  void _insertEntry(_EmbeddedEmoteEntry entry) {
    if (entry.locked) return;

    final thirdParty = entry.thirdParty;
    if (thirdParty != null) {
      widget.thirdPartyCache.markRecentEmote(thirdParty);
    }

    final official = entry.official;
    if (official != null) {
      widget.officialCache.markRecentEmote(official);
    }

    final name = entry.name.trim();
    if (name.isEmpty) return;

    final controller = widget.messageController;
    final current = controller.text;
    final selection = controller.selection;
    final start = selection.start < 0 ? current.length : selection.start;
    final end = selection.end < 0 ? current.length : selection.end;
    final insertText = '$name ';
    final next = current.replaceRange(start, end, insertText);

    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + insertText.length),
    );
  }

  void _showEntryDetails(_EmbeddedEmoteEntry entry) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('${entry.name} · ${entry.providerLabel}'),
        duration: const Duration(milliseconds: 850),
      ),
    );
  }
}

class _ProviderTabBar extends StatelessWidget {
  final List<_EmbeddedEmoteProviderTab> tabs;

  const _ProviderTabBar({required this.tabs});

  @override
  Widget build(BuildContext context) {
    return TabBar(
      isScrollable: true,
      labelColor: const Color(0xFFD9C5FF),
      unselectedLabelColor: Colors.white60,
      indicatorColor: const Color(0xFF9146FF),
      indicatorSize: TabBarIndicatorSize.label,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      tabs: [
        for (final tab in tabs) Tab(text: '${tab.label} ${tab.totalCount}'),
      ],
    );
  }
}

class _EmbeddedProviderPage extends StatefulWidget {
  final _EmbeddedEmoteProviderTab tab;
  final bool loading;
  final ValueChanged<_EmbeddedEmoteEntry> onSelect;
  final ValueChanged<_EmbeddedEmoteEntry> onLongPress;

  const _EmbeddedProviderPage({
    super.key,
    required this.tab,
    required this.loading,
    required this.onSelect,
    required this.onLongPress,
  });

  @override
  State<_EmbeddedProviderPage> createState() => _EmbeddedProviderPageState();
}

class _EmbeddedProviderPageState extends State<_EmbeddedProviderPage>
    with AutomaticKeepAliveClientMixin<_EmbeddedProviderPage> {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final tab = widget.tab;
    if (tab.pages.length == 1) {
      final page = tab.pages.first;
      return _EmbeddedEmoteGrid(
        key: PageStorageKey<String>('grid-${tab.label}-${page.label}'),
        entries: page.entries,
        emptyText: widget.loading ? 'Loading emotes...' : 'No emotes',
        onSelect: widget.onSelect,
        onLongPress: widget.onLongPress,
      );
    }

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
          Expanded(
            child: TabBarView(
              children: [
                for (final page in tab.pages)
                  _EmbeddedEmoteGrid(
                    key: PageStorageKey<String>('grid-${tab.label}-${page.label}'),
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

class _EmbeddedEmoteGrid extends StatefulWidget {
  final List<_EmbeddedEmoteEntry> entries;
  final String emptyText;
  final ValueChanged<_EmbeddedEmoteEntry> onSelect;
  final ValueChanged<_EmbeddedEmoteEntry> onLongPress;

  const _EmbeddedEmoteGrid({
    super.key,
    required this.entries,
    required this.emptyText,
    required this.onSelect,
    required this.onLongPress,
  });

  @override
  State<_EmbeddedEmoteGrid> createState() => _EmbeddedEmoteGridState();
}

class _EmbeddedEmoteGridState extends State<_EmbeddedEmoteGrid>
    with AutomaticKeepAliveClientMixin<_EmbeddedEmoteGrid> {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.entries.isEmpty) {
      return Center(
        child: Text(
          widget.emptyText,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final media = MediaQuery.of(context);
    final columns = _columns(
      width: media.size.width,
      landscape: media.orientation == Orientation.landscape,
    );

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(6, 3, 6, 8),
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
          return _EmbeddedEmoteTile(
            key: ValueKey<String>(entry.stableKey),
            entry: entry,
            onTap: () => widget.onSelect(entry),
            onLongPress: () => widget.onLongPress(entry),
          );
        },
      ),
    );
  }

  int _columns({required double width, required bool landscape}) {
    if (landscape) return 6;
    if (width >= 700) return 8;
    return 6;
  }

  @override
  bool get wantKeepAlive => true;
}

class _EmbeddedEmoteTile extends StatelessWidget {
  final _EmbeddedEmoteEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _EmbeddedEmoteTile({
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
        ? _embeddedEmoteSize
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
              : CachedNetworkImage(
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
                  cacheManager: _embeddedEmoteCacheManager,
                  color: locked ? Colors.white.withOpacity(0.42) : null,
                  colorBlendMode: locked ? BlendMode.modulate : null,
                  placeholder: (_, __) => const SizedBox.shrink(),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white38,
                    size: 20,
                  ),
                ),
        ),
      ),
    );
  }
}

class _EmbeddedEmoteProviderTab {
  final String label;
  final List<_EmbeddedEmotePage> pages;

  const _EmbeddedEmoteProviderTab({
    required this.label,
    required this.pages,
  });

  int get totalCount => pages.fold<int>(0, (sum, page) => sum + page.entries.length);
}

class _EmbeddedEmotePage {
  final String label;
  final List<_EmbeddedEmoteEntry> entries;

  const _EmbeddedEmotePage({
    required this.label,
    required this.entries,
  });
}

class _EmbeddedEmoteEntry {
  final String id;
  final String name;
  final String imageUrl;
  final String providerLabel;
  final bool locked;
  final int? width;
  final int? height;
  final TwitchThirdPartyEmote? thirdParty;
  final TwitchOfficialEmote? official;

  const _EmbeddedEmoteEntry({
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

  factory _EmbeddedEmoteEntry.thirdParty(TwitchThirdPartyEmote emote) {
    return _EmbeddedEmoteEntry(
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

  factory _EmbeddedEmoteEntry.official(TwitchOfficialEmote emote) {
    return _EmbeddedEmoteEntry(
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
    return cleanId.isNotEmpty
        ? '$providerLabel:$cleanId'
        : '$providerLabel:${name.trim().toLowerCase()}';
  }
}
