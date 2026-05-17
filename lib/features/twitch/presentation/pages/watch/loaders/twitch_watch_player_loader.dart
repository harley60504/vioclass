// PATCH VERSION: twitch_watch_player_loader_stage141
//
// Player-only WatchPage startup loader.
// Keep playback/proxy/media_kit opening concerns out of TwitchWatchPage so
// startup order can be optimized without touching UI code.

import '../../../../models/playback/twitch_m3u8_variant.dart';
import '../../../../services/playback/twitch_media_kit_player_host.dart';
import '../../../../services/playback/twitch_playlist_player_runtime.dart';

class TwitchWatchPlayerLoader {
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final TwitchMediaKitPlayerSession playerSession;

  const TwitchWatchPlayerLoader({
    required this.playerRuntime,
    required this.playerSession,
  });

  Future<Uri> loadLive({
    required String channelLogin,
    required Future<void> Function() applyPlayerVolume,
    required Future<void> Function() waitForInitialPlaybackSettle,
  }) async {
    final uri = await playerRuntime.loadLivePlaylist(
      channelLogin: channelLogin,
    );

    if (uri == null) {
      throw StateError('播放清單載入失敗，沒有 playlist uri。');
    }

    await applyPlayerVolume();
    await playerSession.openOrResume(uri: uri.toString(), play: true);
    await applyPlayerVolume();
    await waitForInitialPlaybackSettle();

    return uri;
  }

  Future<Uri> switchQuality({
    required TwitchM3u8Variant variant,
    required Future<void> Function() applyPlayerVolume,
    required Future<void> Function() waitForInitialPlaybackSettle,
  }) async {
    final uri = await playerRuntime.startProxyForVariant(variant);

    if (uri == null) {
      throw StateError('切換畫質失敗：runtime 沒有回傳 playlist uri。');
    }

    await applyPlayerVolume();
    await playerSession.openOrResume(uri: uri.toString(), play: true);
    await applyPlayerVolume();
    await waitForInitialPlaybackSettle();

    return uri;
  }
}
