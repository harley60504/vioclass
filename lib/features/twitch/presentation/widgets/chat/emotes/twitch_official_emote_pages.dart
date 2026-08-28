import '../../../../models/emotes/twitch_official_emote.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';

class TwitchOfficialEmotePage {
  final String label;
  final List<TwitchOfficialEmote> emotes;

  const TwitchOfficialEmotePage({required this.label, required this.emotes});
}

List<TwitchOfficialEmotePage> buildTwitchOfficialEmotePages(
  TwitchOfficialEmoteCacheService cache,
) {
  final channel = uniqueTwitchOfficialEmotes(cache.channelEmotes);
  final global = uniqueTwitchOfficialEmotes(cache.globalEmotes);
  final user = uniqueTwitchOfficialEmotes(cache.userEmotes);

  final channelKeys = channel.map(twitchOfficialEmoteKey).toSet();
  final globalKeys = global.map(twitchOfficialEmoteKey).toSet();
  final userOnly = user
      .where((emote) {
        final key = twitchOfficialEmoteKey(emote);
        if (channelKeys.contains(key)) return false;
        if (globalKeys.contains(key)) return false;
        return true;
      })
      .toList(growable: false);

  final unlocked = uniqueTwitchOfficialEmotes(
    userOnly.where(isStandaloneUnlockedTwitchOfficialEmote),
  );
  final subscriptions = uniqueTwitchOfficialEmotes(
    userOnly.where((emote) => !isStandaloneUnlockedTwitchOfficialEmote(emote)),
  );
  final subscriptionGroups = groupTwitchOfficialEmotesByOwner(subscriptions);

  return <TwitchOfficialEmotePage>[
    TwitchOfficialEmotePage(label: 'Channel', emotes: channel),
    TwitchOfficialEmotePage(label: 'Global', emotes: global),
    for (final group in subscriptionGroups.entries)
      TwitchOfficialEmotePage(label: group.key, emotes: group.value),
    TwitchOfficialEmotePage(label: 'Unlocked', emotes: unlocked),
  ];
}

Map<String, List<TwitchOfficialEmote>> groupTwitchOfficialEmotesByOwner(
  List<TwitchOfficialEmote> emotes,
) {
  final grouped = <String, List<TwitchOfficialEmote>>{};
  for (final emote in emotes) {
    final ownerLabel = twitchOfficialEmoteOwnerLabel(emote);
    grouped.putIfAbsent(ownerLabel, () => <TwitchOfficialEmote>[]).add(emote);
  }

  final keys = grouped.keys.toList(growable: false);

  return <String, List<TwitchOfficialEmote>>{
    for (final key in keys)
      key: uniqueTwitchOfficialEmotes(
        grouped[key] ?? const <TwitchOfficialEmote>[],
      ),
  };
}

List<TwitchOfficialEmote> uniqueTwitchOfficialEmotes(
  Iterable<TwitchOfficialEmote> source,
) {
  final byKey = <String, TwitchOfficialEmote>{};
  for (final emote in source) {
    byKey[twitchOfficialEmoteKey(emote)] = emote;
  }
  return byKey.values.toList(growable: false);
}

String twitchOfficialEmoteKey(TwitchOfficialEmote emote) {
  final id = emote.id.trim();
  return id.isNotEmpty ? 'id:$id' : 'name:${emote.name.trim().toLowerCase()}';
}

String twitchOfficialEmoteOwnerLabel(TwitchOfficialEmote emote) {
  final display = emote.ownerDisplayName.trim();
  if (display.isNotEmpty) return display;

  final ownerId = emote.ownerId.trim();
  if (ownerId.isNotEmpty) return 'Sub $ownerId';

  final setId = emote.emoteSetId.trim();
  if (setId.isNotEmpty) return 'Sub $setId';

  return 'Sub';
}

bool isStandaloneUnlockedTwitchOfficialEmote(TwitchOfficialEmote emote) {
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
