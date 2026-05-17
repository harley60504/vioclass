import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/emotes/twitch_official_emote.dart';
import '../../models/emotes/twitch_third_party_emote.dart';
import '../../services/chat/twitch_official_emote_cache_service.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

const double _emoteSize = 30.0;
const int _memCacheSize = 72;
const int _diskCacheSize = 96;

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
    portraitHeightFactor: 0.44,
    landscapeHeightFactor: 0.58,
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
    final tabs = <_EmoteTab>[
      _EmoteTab(
        label: 'Recent',
        entries: <_EmoteEntry>[
          ...widget.cache.recentEmotes.map(_EmoteEntry.thirdParty),
          ...(official?.recentEmotes ?? const <TwitchOfficialEmote>[])
              .map(_EmoteEntry.official),
        ],
      ),
      _EmoteTab(
        label: 'Favorite',
        entries: <_EmoteEntry>[
          ...widget.cache.favoriteEmotes.map(_EmoteEntry.thirdParty),
          ...(official?.favoriteEmotes ?? const <TwitchOfficialEmote>[])
              .map(_EmoteEntry.official),
        ],
      ),
      _EmoteTab(label: 'Twitch', entries: _officialEntries()),
      _EmoteTab(
        label: '7TV',
        entries: widget.cache
            .emotesForProvider(TwitchThirdPartyEmoteProvider.sevenTv)
            .map(_EmoteEntry.thirdParty)
            .toList(growable: false),
      ),
      _EmoteTab(
        label: 'BTTV',
        entries: widget.cache
            .emotesForProvider(TwitchThirdPartyEmoteProvider.bttv)
            .map(_EmoteEntry.thirdParty)
            .toList(growable: false),
      ),
      _EmoteTab(
        label: 'FFZ',
        entries: widget.cache
            .emotesForProvider(TwitchThirdPartyEmoteProvider.ffz)
            .map(_EmoteEntry.thirdParty)
            .toList(growable: false),
      ),
    ];

    return SafeArea(
      child: TwitchUnifiedSheetScaffold(
        title: '貼圖',
        subtitle: 'Frosty-style test',
        icon: Icons.emoji_emotions_rounded,
        loading: loading,
        onRefresh: widget.onRefresh,
        child: DefaultTabController(
          length: tabs.length,
          child: Column(
            children: [
              TabBar(
                isScrollable: true,
                labelColor: const Color(0xFFD9C5FF),
                unselectedLabelColor: Colors.white60,
                indicatorColor: const Color(0xFF9146FF),
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                tabs: [
                  for (final tab in tabs) Tab(text: '${tab.label} ${tab.entries.length}'),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final tab in tabs)
                      _EmoteSection(
                        key: PageStorageKey<String>('frosty-${tab.label}'),
                        entries: tab.entries,
                        emptyText: loading ? 'Loading emotes...' : 'No emotes',
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

  List<_EmoteEntry> _officialEntries() {
    final official = _official;
    if (official == null) return const <_EmoteEntry>[];
    final byKey = <String, TwitchOfficialEmote>{};
    for (final emote in official.usableEmotes) {
      byKey[_officialKey(emote)] = emote;
    }
    for (final emote in official.lockedChannelEmotes) {
      byKey.putIfAbsent(_officialKey(emote), () => emote);
    }
    final output = byKey.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return output.map(_EmoteEntry.official).toList(growable: false);
  }

  String _officialKey(TwitchOfficialEmote emote) {
    final id = emote.id.trim();
    return id.isNotEmpty ? 'id:$id' : 'name:${emote.name.trim().toLowerCase()}';
  }
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
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
        cacheExtent: 120,
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
                      height: _emoteSize,
                      width: _emoteSize,
                      fit: BoxFit.contain,
                      memCacheWidth: _memCacheSize,
                      memCacheHeight: _memCacheSize,
                      maxWidthDiskCache: _diskCacheSize,
                      maxHeightDiskCache: _diskCacheSize,
                      filterQuality: FilterQuality.low,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      useOldImageOnUrlChange: true,
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

class _EmoteTab {
  final String label;
  final List<_EmoteEntry> entries;
  const _EmoteTab({required this.label, required this.entries});
}

class _EmoteEntry {
  final String id;
  final String name;
  final String imageUrl;
  final String providerLabel;
  final bool locked;
  final TwitchThirdPartyEmote? thirdParty;
  final TwitchOfficialEmote? official;

  const _EmoteEntry({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.providerLabel,
    required this.locked,
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
