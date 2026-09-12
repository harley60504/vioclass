part of '../twitch_playlist_player_runtime.dart';

enum TwitchDvrHealthState {
  inactive,
  probing,
  healthy,
  stale,
  recovering,
  unavailable,
}
