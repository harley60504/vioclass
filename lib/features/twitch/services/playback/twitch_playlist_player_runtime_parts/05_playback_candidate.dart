part of '../twitch_playlist_player_runtime.dart';

class _PlaybackCandidate {
  final String sourceTag;
  final Uri masterUri;
  final String masterPlaylistText;
  final TwitchPlaybackAccessToken token;
  final List<TwitchM3u8Variant> variants;

  const _PlaybackCandidate({
    required this.sourceTag,
    required this.masterUri,
    required this.masterPlaylistText,
    required this.token,
    required this.variants,
  });
}
