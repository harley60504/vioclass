import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../../models/emotes/twitch_official_emote.dart';
import '../../../../models/emotes/twitch_third_party_emote.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';

const double _embeddedEmoteSize = 30.0;
const String _debugTargetEmoteName = 'corgiHHH';
const String _debugTargetKeyword = 'corgi';

bool _isDebugTargetEmoteName(String name) {
  return name.trim().toLowerCase().contains(_debugTargetKeyword);
}

String _officialAnimatedEmoteUrl(String id) {
  final cleanId = id.trim();
  if (cleanId.isEmpty) return '';
  return 'https://static-cdn.jtvnw.net/emoticons/v2/$cleanId/animated/dark/2.0';
}

String _officialDefaultEmoteUrl(String id) {
  final cleanId = id.trim();
  if (cleanId.isEmpty) return '';
  return 'https://static-cdn.jtvnw.net/emoticons/v2/$cleanId/default/dark/2.0';
}

void _debugTargetEmoteLog(String message) {
  final line = '[TwitchEmoteDebug][$_debugTargetEmoteName] $message';
  debugPrint(line, wrapWidth: 1024);
  // ignore: avoid_print
  print(line);
}

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
      _officialProviderTab(),
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

  _EmbeddedEmoteProviderTab _officialProviderTab() {
    final channel = _uniqueOfficial(widget.officialCache.channelEmotes);
    final global = _uniqueOfficial(widget.officialCache.globalEmotes);
    final user = _uniqueOfficial(widget.officialCache.userEmotes);

    _debugOfficialBucketScan('channel', channel);
    _debugOfficialBucketScan('global', global);
    _debugOfficialBucketScan('user', user);
    _debugTargetEmoteLog(
      'official tab scan counts '
      'channel=${channel.length} global=${global.length} user=${user.length} '
      'recent=${widget.officialCache.recentCount} favorite=${widget.officialCache.favoriteCount} '
      'loading=${widget.loading} channelId=${widget.officialCache.channelId} '
      'viewerId=${widget.officialCache.viewerId} error=${widget.officialCache.error}',
    );

    final channelKeys = channel.map(_officialKey).toSet();
    final globalKeys = global.map(_officialKey).toSet();
    final currentChannelId = widget.officialCache.channelId.trim();

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

    final pages = <_EmbeddedEmotePage>[
      _EmbeddedEmotePage(
        label: 'Channel',
        entries: channel.map(_EmbeddedEmoteEntry.official).toList(growable: false),
      ),
      _EmbeddedEmotePage(
        label: 'Global',
        entries: global.map(_EmbeddedEmoteEntry.official).toList(growable: false),
      ),
      for (final group in subscriptionGroups.entries)
        _EmbeddedEmotePage(
          label: group.key,
          entries: group.value.map(_EmbeddedEmoteEntry.official).toList(growable: false),
        ),
      _EmbeddedEmotePage(
        label: 'Unlocked',
        entries: unlocked.map(_EmbeddedEmoteEntry.official).toList(growable: false),
      ),
    ];

    return _EmbeddedEmoteProviderTab(label: 'Twitch', pages: pages);
  }

  void _debugOfficialBucketScan(
    String bucket,
    Iterable<TwitchOfficialEmote> emotes,
  ) {
    final matches = emotes.where((emote) => _isDebugTargetEmoteName(emote.name));

    for (final emote in matches) {
      _debugTargetEmoteLog(
        'official bucket=$bucket match name=${emote.name} id=${emote.id} '
        'imageUrl=${emote.imageUrl} locked=${emote.locked} '
        'source=${emote.source.name} unlocked=${emote.unlocked} '
        'emoteType=${emote.emoteType} tier=${emote.tier} '
        'emoteSetId=${emote.emoteSetId} ownerId=${emote.ownerId} '
        'owner=${emote.ownerDisplayName} '
        'animatedCandidate=${_officialAnimatedEmoteUrl(emote.id)} '
        'defaultCandidate=${_officialDefaultEmoteUrl(emote.id)}',
      );
    }
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
        key: (_uniqueOfficial(grouped[key] ?? const <TwitchOfficialEmote>[])),
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

  _EmbeddedEmoteProviderTab _thirdPartyProviderTab(
    String label,
    TwitchThirdPartyEmoteProvider provider,
  ) {
    final source = widget.thirdPartyCache.emotesForProvider(provider);
    final channel = source
        .where((emote) => emote.scope == TwitchThirdPartyEmoteScope.channel)
        .map(_EmbeddedEmoteEntry.thirdParty)
        .toList(growable: false);
    final shared = source
        .where((emote) => emote.scope == TwitchThirdPartyEmoteScope.shared)
        .map(_EmbeddedEmoteEntry.thirdParty)
        .toList(growable: false);
    final global = source
        .where((emote) => emote.scope == TwitchThirdPartyEmoteScope.global)
        .map(_EmbeddedEmoteEntry.thirdParty)
        .toList(growable: false);
    final other = source
        .where((emote) => emote.scope == TwitchThirdPartyEmoteScope.other)
        .map(_EmbeddedEmoteEntry.thirdParty)
        .toList(growable: false);

    final channelLike = <_EmbeddedEmoteEntry>[
      ...channel,
      ...shared,
      ...other,
    ];

    return _EmbeddedEmoteProviderTab(
      label: label,
      pages: [
        _EmbeddedEmotePage(label: 'Channel', entries: channelLike),
        _EmbeddedEmotePage(label: 'Global', entries: global),
      ],
    );
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

  void _insertEntry(_EmbeddedEmoteEntry entry) {
    if (entry.locked) return;

    if (_isDebugTargetEmoteName(entry.name)) {
      _debugTargetEmoteLog(
        'insert entry provider=${entry.providerLabel} id=${entry.id} '
        'stableKey=${entry.stableKey} imageUrl=${entry.imageUrl}',
      );
    }

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

    if (entry.isDebugTarget) {
      _debugTargetEmoteLog(
        'tile build name=${entry.name} provider=${entry.providerLabel} id=${entry.id} locked=$locked '
        'stableKey=${entry.stableKey} imageUrl=$imageUrl '
        'animatedCandidate=${entry.officialAnimatedUrl} '
        'defaultCandidate=${entry.officialDefaultUrl}',
      );
    }

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
                  errorWidget: (_, url, error) {
                    if (entry.isDebugTarget) {
                      _debugTargetEmoteLog(
                        'image error name=${entry.name} url=$url error=$error '
                        'provider=${entry.providerLabel} id=${entry.id} '
                        'stableKey=${entry.stableKey} '
                        'animatedCandidate=${entry.officialAnimatedUrl} '
                        'defaultCandidate=${entry.officialDefaultUrl}',
                      );
                    }

                    return const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white38,
                      size: 20,
                    );
                  },
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
    final entry = _EmbeddedEmoteEntry(
      id: emote.id,
      name: emote.name,
      imageUrl: emote.imageUrl,
      providerLabel: emote.providerLabel,
      locked: false,
      width: emote.width,
      height: emote.height,
      thirdParty: emote,
    );

    if (entry.isDebugTarget) {
      _debugTargetEmoteLog(
        'entry third-party name=${entry.name} provider=${entry.providerLabel} id=${entry.id} '
        'imageUrl=${entry.imageUrl} width=${entry.width} height=${entry.height}',
      );
    }

    return entry;
  }

  factory _EmbeddedEmoteEntry.official(TwitchOfficialEmote emote) {
    final entry = _EmbeddedEmoteEntry(
      id: emote.id,
      name: emote.name,
      imageUrl: emote.imageUrl,
      providerLabel: emote.sourceLabel,
      locked: emote.locked,
      official: emote,
    );

    if (entry.isDebugTarget) {
      _debugTargetEmoteLog(
        'entry official name=${entry.name} provider=${entry.providerLabel} id=${entry.id} '
        'imageUrl=${entry.imageUrl} locked=${entry.locked} '
        'source=${emote.source.name} unlocked=${emote.unlocked} '
        'emoteType=${emote.emoteType} tier=${emote.tier} '
        'emoteSetId=${emote.emoteSetId} ownerId=${emote.ownerId} '
        'owner=${emote.ownerDisplayName} '
        'animatedCandidate=${entry.officialAnimatedUrl} '
        'defaultCandidate=${entry.officialDefaultUrl}',
      );
    }

    return entry;
  }

  bool get isDebugTarget => _isDebugTargetEmoteName(name);

  String get officialAnimatedUrl => _officialAnimatedEmoteUrl(id);

  String get officialDefaultUrl => _officialDefaultEmoteUrl(id);

  String get stableKey {
    final cleanId = id.trim();
    return cleanId.isNotEmpty
        ? '$providerLabel:$cleanId'
        : '$providerLabel:${name.trim().toLowerCase()}';
  }
}
