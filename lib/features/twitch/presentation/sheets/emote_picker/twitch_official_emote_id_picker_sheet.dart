// PATCH VERSION: twitch_official_emote_id_picker_sheet_stage223_name_only_grid
//
// Twitch official emote ID picker used by Channel Points emote rewards.
// Channel Points still needs emote IDs internally, but the visible picker UX now
// matches the normal emote sheet: grid cards show the image and emote name only.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/emotes/twitch_official_emote.dart';
import '../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../widgets/common/twitch_progressive_grid_view.dart';
import '../../widgets/responsive/twitch_responsive_sheet.dart';
import 'twitch_emote_picker_models.dart';
import 'twitch_emote_picker_widgets.dart';

class TwitchOfficialEmoteIdPickerSheet extends StatefulWidget {
  final TwitchOfficialEmoteCacheService officialCache;
  final bool loading;
  final Future<void> Function() onRefresh;
  final String title;
  final String subtitle;
  final bool includeGlobalEmotes;
  final bool includeUnlockedEmotes;
  final bool includeLockedChannelEmotes;

  const TwitchOfficialEmoteIdPickerSheet({
    super.key,
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
  State<TwitchOfficialEmoteIdPickerSheet> createState() =>
      _TwitchOfficialEmoteIdPickerSheetState();
}

class _TwitchOfficialEmoteIdPickerSheetState
    extends State<TwitchOfficialEmoteIdPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';

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
      setState(() => _query = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cache = widget.officialCache;
    final query = _query.trim().toLowerCase();
    final usable = widget.includeUnlockedEmotes
        ? filterOfficialEmotes(source: cache.usableEmotes, query: query)
        : const <TwitchOfficialEmote>[];
    final locked = widget.includeLockedChannelEmotes
        ? filterOfficialEmotes(source: cache.lockedChannelEmotes, query: query)
        : const <TwitchOfficialEmote>[];
    final global = widget.includeGlobalEmotes
        ? filterOfficialEmotes(source: cache.globalEmotes, query: query)
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
                  hintText: '搜尋貼圖名稱',
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
                onChanged: _setSearchQueryDebounced,
              ),
            ),
            Expanded(
              child: busy && cache.visibleCount == 0
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF9146FF)),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                      children: [
                        if (locked.isNotEmpty)
                          OfficialEmoteIdPickerSection(
                            title: '此頻道可解鎖',
                            emotes: locked,
                            resetKey: 'locked:$query:${locked.length}',
                          ),
                        if (usable.isNotEmpty)
                          OfficialEmoteIdPickerSection(
                            title: '我的可用 / 此頻道',
                            emotes: usable,
                            resetKey: 'usable:$query:${usable.length}',
                          ),
                        if (global.isNotEmpty)
                          OfficialEmoteIdPickerSection(
                            title: 'Twitch 共用',
                            emotes: global,
                            resetKey: 'global:$query:${global.length}',
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
}

class OfficialEmoteIdPickerSection extends StatelessWidget {
  final String title;
  final List<TwitchOfficialEmote> emotes;
  final String resetKey;

  const OfficialEmoteIdPickerSection({
    super.key,
    required this.title,
    required this.emotes,
    required this.resetKey,
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
          TwitchProgressiveGridView<TwitchOfficialEmote>(
            items: emotes,
            resetKey: resetKey,
            initialItemCount: 36,
            pageSize: 36,
            shrinkWrap: true,
            autoLoadOnScroll: false,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 126,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.02,
            ),
            itemBuilder: (context, emote, index) {
              return OfficialEmoteIdGridCard(emote: emote);
            },
          ),
        ],
      ),
    );
  }
}

class OfficialEmoteIdGridCard extends StatelessWidget {
  final TwitchOfficialEmote emote;

  const OfficialEmoteIdGridCard({
    super.key,
    required this.emote,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          debugPrint(
            '[ChannelPointsEmoteIdPicker] selected name=${emote.name} id=${emote.id}',
          );
          Navigator.of(context).pop(emote.id.trim());
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
                  child: TwitchOptimizedEmoteImage(
                    imageUrl: emote.imageUrl,
                    cacheSize: twitchEmoteGridCacheSize,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emote.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
