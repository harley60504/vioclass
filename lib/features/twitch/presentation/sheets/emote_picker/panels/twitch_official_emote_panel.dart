import 'package:flutter/material.dart';

import '../../../../models/emotes/twitch_official_emote.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../widgets/common/twitch_progressive_grid_view.dart';
import '../twitch_emote_picker_models.dart';
import '../twitch_emote_picker_widgets.dart';
import 'twitch_emote_picker_empty_state.dart';

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
      source: service.nonGlobalUsableEmotes,
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
      TwitchOfficialEmoteSubFilter.usable => '目前沒有訂閱或擁有的 Twitch 官方貼圖。',
      TwitchOfficialEmoteSubFilter.channel => '目前沒有實況主頻道貼圖。',
      TwitchOfficialEmoteSubFilter.global => '目前沒有 Twitch 共用貼圖。',
    };
    final resetKey = 'official:${subFilter.name}:${query.trim().toLowerCase()}:${selected.length}';

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
              : TwitchProgressiveGridView<TwitchOfficialEmote>(
                  items: selected,
                  resetKey: resetKey,
                  initialItemCount: 48,
                  pageSize: 48,
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 116,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.02,
                  ),
                  itemBuilder: (context, emote, index) {
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
