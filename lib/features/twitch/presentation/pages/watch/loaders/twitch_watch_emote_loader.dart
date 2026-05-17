// PATCH VERSION: twitch_watch_emote_loader_stage141
//
// Emote-only WatchPage background loader.
// This lane is intentionally non-blocking for WatchPage startup.

import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';

class TwitchWatchEmoteLoader {
  final TwitchThirdPartyEmoteCacheService thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService officialEmotes;

  const TwitchWatchEmoteLoader({
    required this.thirdPartyEmotes,
    required this.officialEmotes,
  });

  Future<void> loadForChannel({
    required String channelId,
    required String channelLogin,
    required String viewerId,
    bool forceRefresh = false,
  }) async {
    final safeChannelId = channelId.trim();
    if (safeChannelId.isEmpty) return;

    await Future.wait<void>([
      thirdPartyEmotes.loadForChannel(
        channelId: safeChannelId,
        channelLogin: channelLogin,
      ),
      officialEmotes.loadForChannel(
        channelId: safeChannelId,
        viewerId: viewerId,
        forceRefresh: forceRefresh,
      ),
    ]);
  }
}
