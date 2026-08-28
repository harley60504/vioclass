import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/discovery/twitch_live_stream.dart';
import '../../models/discovery/twitch_stream_header_metadata.dart';
import '../../services/playback/twitch_media_kit_player_host.dart';
import '../../services/playback/twitch_playlist_player_runtime.dart';
import '../watch/twitch_playback_session_controller.dart';
import '../watch/twitch_watch_playback_kind.dart';

class TwitchMiniPlayerEntry {
  final TwitchPlaybackSessionState playback;
  final TwitchPlaylistPlayerRuntime? playerRuntime;

  const TwitchMiniPlayerEntry({required this.playback, this.playerRuntime});

  int get revision => playback.revision;
  TwitchStreamHeaderMetadata get metadata => playback.metadata;
  String get mediaUri => playback.mediaUri;
  TwitchWatchPlaybackKind get kind => playback.kind;
  TwitchChannelVideo? get activeDvrVideo => playback.activeDvrVideo;
  TwitchChannelVideo? get resumeVodVideo => playback.resumeVodVideo;
  TwitchChannelClip? get resumeClip => playback.resumeClip;
  double? get resumeVodRatio => playback.resumeVodRatio;
  bool get resumeVodReplayChat => playback.resumeVodReplayChat;
}

class TwitchMiniPlayerController extends ChangeNotifier {
  TwitchMiniPlayerController._();

  static final TwitchMiniPlayerController instance =
      TwitchMiniPlayerController._();

  TwitchMiniPlayerEntry? _entry;
  TwitchMediaKitPlayerSession? _activeSession;

  TwitchMiniPlayerEntry? get entry => _entry;
  bool get isActive => _entry != null;

  bool isActiveMediaUri(String? uri) {
    final value = uri?.trim();
    return value != null && value.isNotEmpty && value == _entry?.mediaUri;
  }

  void attachSession(TwitchMediaKitPlayerSession session) {
    _activeSession = session;
  }

  void detachSession(TwitchMediaKitPlayerSession session) {
    if (identical(_activeSession, session)) {
      _activeSession = null;
    }
  }

  bool moveActiveSurfaceInto(TwitchMediaKitPlayerSession target) {
    final source = _activeSession;
    if (source == null) return false;
    final moved = target.moveSurfaceFrom(source);
    if (moved) _activeSession = null;
    return moved;
  }

  void show({
    required int revision,
    required TwitchStreamHeaderMetadata metadata,
    required String mediaUri,
    TwitchWatchPlaybackKind kind = TwitchWatchPlaybackKind.live,
    TwitchPlaylistPlayerRuntime? playerRuntime,
    TwitchChannelVideo? activeDvrVideo,
    TwitchChannelVideo? resumeVodVideo,
    TwitchChannelClip? resumeClip,
    double? resumeVodRatio,
    bool resumeVodReplayChat = false,
  }) {
    showPlayback(
      playback: TwitchPlaybackSessionState(
        revision: revision,
        kind: kind,
        mediaUri: mediaUri,
        metadata: metadata,
        activeDvrVideo: activeDvrVideo,
        vodVideo: resumeVodVideo,
        clip: resumeClip,
        vodRatio: resumeVodRatio,
        preferVodReplayChat: resumeVodReplayChat,
      ),
      playerRuntime: playerRuntime,
    );
  }

  void showPlayback({
    required TwitchPlaybackSessionState playback,
    TwitchPlaylistPlayerRuntime? playerRuntime,
  }) {
    final safeUri = playback.mediaUri.trim();
    if (safeUri.isEmpty) return;
    _entry = TwitchMiniPlayerEntry(
      playback: playback,
      playerRuntime: playerRuntime,
    );
    debugPrint(
      '[MiniPlayer] show revision=${playback.revision} '
      'kind=${playback.kind} uri=$safeUri',
    );
    notifyListeners();
  }

  void close({bool pausePlayback = true}) {
    if (_entry == null) return;
    _entry = null;
    TwitchMediaKitPlayerHost.keepPlayingWithoutSession(null);
    if (pausePlayback) {
      unawaited(TwitchMediaKitPlayerHost.pauseShared().catchError((_) {}));
    }
    notifyListeners();
  }
}
