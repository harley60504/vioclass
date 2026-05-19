// PATCH VERSION: twitch_emote_picker_models_stage222_frosty_category_merge
//
// Shared enums, constants and non-widget helpers for Twitch emote picker sheets.
// Stage 222: merge Frosty-style scope/category filtering into the original sheet.

import '../../../models/emotes/twitch_official_emote.dart';
import '../../../models/emotes/twitch_third_party_emote.dart';
import '../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../services/chat/twitch_third_party_emote_cache_service.dart';

const int twitchThirdPartyGridLimit = 96;
const int twitchCombinedGridLimit = 120;
const int twitchEmoteGridCacheSize = 96;
const int twitchEmotePreviewCacheSize = 144;
const Duration twitchEmoteSearchDebounceDuration = Duration(milliseconds: 180);

enum TwitchEmotePickerTab {
  recent,
  favorites,
  twitch,
  bttv,
  sevenTv,
  ffz,
}

enum TwitchOfficialEmoteSubFilter {
  usable,
  channel,
  global,
}

enum TwitchThirdPartyEmoteScopeFilter {
  all,
  channel,
  shared,
  global,
  zeroWidth,
}

extension TwitchThirdPartyEmoteScopeFilterUi
    on TwitchThirdPartyEmoteScopeFilter {
  String get label {
    switch (this) {
      case TwitchThirdPartyEmoteScopeFilter.all:
        return '全部';
      case TwitchThirdPartyEmoteScopeFilter.channel:
        return '頻道';
      case TwitchThirdPartyEmoteScopeFilter.shared:
        return 'Shared';
      case TwitchThirdPartyEmoteScopeFilter.global:
        return '全域';
      case TwitchThirdPartyEmoteScopeFilter.zeroWidth:
        return 'ZW';
    }
  }
}

class TwitchMixedEmoteEntry {
  final TwitchThirdPartyEmote? thirdParty;
  final TwitchOfficialEmote? official;

  const TwitchMixedEmoteEntry.thirdParty(TwitchThirdPartyEmote emote)
      : thirdParty = emote,
        official = null;

  const TwitchMixedEmoteEntry.official(TwitchOfficialEmote emote)
      : thirdParty = null,
        official = emote;

  String get name => thirdParty?.name ?? official?.name ?? '';
}

List<TwitchThirdPartyEmote> twitchThirdPartyEmotesForTab({
  required TwitchEmotePickerTab tab,
  required TwitchThirdPartyEmoteCacheService cache,
}) {
  switch (tab) {
    case TwitchEmotePickerTab.recent:
      return const <TwitchThirdPartyEmote>[];
    case TwitchEmotePickerTab.favorites:
      return cache.favoriteEmotes;
    case TwitchEmotePickerTab.twitch:
      return const <TwitchThirdPartyEmote>[];
    case TwitchEmotePickerTab.bttv:
      return cache.emotesForProvider(TwitchThirdPartyEmoteProvider.bttv);
    case TwitchEmotePickerTab.sevenTv:
      return cache.emotesForProvider(TwitchThirdPartyEmoteProvider.sevenTv);
    case TwitchEmotePickerTab.ffz:
      return cache.emotesForProvider(TwitchThirdPartyEmoteProvider.ffz);
  }
}

int twitchEmoteCountForTab({
  required TwitchEmotePickerTab tab,
  required TwitchThirdPartyEmoteCacheService cache,
  required TwitchOfficialEmoteCacheService? official,
}) {
  switch (tab) {
    case TwitchEmotePickerTab.recent:
      return cache.recentCount + (official?.recentCount ?? 0);
    case TwitchEmotePickerTab.favorites:
      return cache.favoriteEmotes.length + (official?.favoriteCount ?? 0);
    case TwitchEmotePickerTab.twitch:
      return official?.visibleCount ?? 0;
    case TwitchEmotePickerTab.bttv:
      return cache.countForProvider(TwitchThirdPartyEmoteProvider.bttv);
    case TwitchEmotePickerTab.sevenTv:
      return cache.countForProvider(TwitchThirdPartyEmoteProvider.sevenTv);
    case TwitchEmotePickerTab.ffz:
      return cache.countForProvider(TwitchThirdPartyEmoteProvider.ffz);
  }
}

String twitchEmoteEmptyText({
  required TwitchEmotePickerTab tab,
  required bool loading,
  required TwitchOfficialEmoteCacheService? official,
}) {
  if (loading) return '貼圖預載中...';

  switch (tab) {
    case TwitchEmotePickerTab.recent:
      return '目前沒有最近貼圖。';
    case TwitchEmotePickerTab.favorites:
      return '還沒有收藏貼圖。';
    case TwitchEmotePickerTab.twitch:
      if (official == null) return '官方 Twitch 貼圖服務尚未初始化。';
      if (official.userEmotesUnavailable) {
        return '已讀取 Twitch 全域 / 頻道貼圖；我的可用貼圖需要 user:read:emotes scope，缺少時訂閱貼圖會以鎖住狀態顯示。';
      }
      return '目前沒有 Twitch 官方 / 頻道貼圖。';
    case TwitchEmotePickerTab.bttv:
      return '目前沒有 BTTV 貼圖。';
    case TwitchEmotePickerTab.sevenTv:
      return '目前沒有 7TV 貼圖。';
    case TwitchEmotePickerTab.ffz:
      return '目前沒有 FFZ 貼圖。';
  }
}

bool twitchThirdPartyEmoteMatchesScopeFilter({
  required TwitchThirdPartyEmote emote,
  required TwitchThirdPartyEmoteScopeFilter scopeFilter,
}) {
  switch (scopeFilter) {
    case TwitchThirdPartyEmoteScopeFilter.all:
      return true;
    case TwitchThirdPartyEmoteScopeFilter.channel:
      return emote.scope == TwitchThirdPartyEmoteScope.channel ||
          emote.scope == TwitchThirdPartyEmoteScope.other;
    case TwitchThirdPartyEmoteScopeFilter.shared:
      return emote.scope == TwitchThirdPartyEmoteScope.shared;
    case TwitchThirdPartyEmoteScopeFilter.global:
      return emote.scope == TwitchThirdPartyEmoteScope.global;
    case TwitchThirdPartyEmoteScopeFilter.zeroWidth:
      return emote.isZeroWidth;
  }
}

int twitchThirdPartyEmoteScopeCount({
  required List<TwitchThirdPartyEmote> source,
  required TwitchThirdPartyEmoteScopeFilter scopeFilter,
}) {
  return source.where((emote) {
    return twitchThirdPartyEmoteMatchesScopeFilter(
      emote: emote,
      scopeFilter: scopeFilter,
    );
  }).length;
}

List<TwitchThirdPartyEmote> filterThirdPartyEmotes({
  required List<TwitchThirdPartyEmote> source,
  required String query,
  TwitchThirdPartyEmoteScopeFilter scopeFilter =
      TwitchThirdPartyEmoteScopeFilter.all,
  int limit = twitchThirdPartyGridLimit,
}) {
  final lowerQuery = query.trim().toLowerCase();
  return source
      .where((emote) => twitchThirdPartyEmoteMatchesScopeFilter(
            emote: emote,
            scopeFilter: scopeFilter,
          ))
      .where((emote) => lowerQuery.isEmpty ||
          emote.name.toLowerCase().contains(lowerQuery) ||
          emote.id.toLowerCase().contains(lowerQuery))
      .take(limit)
      .toList(growable: false);
}

List<TwitchOfficialEmote> filterOfficialEmotes({
  required List<TwitchOfficialEmote> source,
  required String query,
}) {
  final lowerQuery = query.trim().toLowerCase();
  return source
      .where((emote) => lowerQuery.isEmpty ||
          emote.name.toLowerCase().contains(lowerQuery) ||
          emote.id.toLowerCase().contains(lowerQuery))
      .toList(growable: false);
}
