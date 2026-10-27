import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/discovery/twitch_live_stream.dart';
import '../../models/discovery/twitch_stream_header_metadata.dart';
import '../../services/playback/twitch_media_kit_player_host.dart';
import '../../services/playback/twitch_playlist_player_runtime.dart';
import '../watch/twitch_playback_session_controller.dart';
import '../watch/twitch_watch_playback_kind.dart';
import '../watch/controllers/twitch_playback_timeline_controller.dart';

class TwitchMiniPlayerEntry {
  final TwitchPlaybackSessionState playback;
  final TwitchPlaylistPlayerRuntime? playerRuntime;
  final bool playOnOpen;

  const TwitchMiniPlayerEntry({
    required this.playback,
    this.playerRuntime,
    this.playOnOpen = true,
  });

  int get revision => playback.revision;
  TwitchStreamHeaderMetadata get metadata => playback.metadata;
  String get mediaUri => playback.mediaUri;
  TwitchWatchPlaybackKind get kind => playback.kind;
  TwitchChannelVideo? get activeDvrVideo => playback.activeDvrVideo;
  TwitchChannelVideo? get resumeVodVideo => playback.resumeVodVideo;
  // Live snapshots may retain a VOD as their DVR archive, but that must not
  // select the recorded-watch route when expanding the mini player.
  TwitchChannelVideo? get watchPageVodVideo =>
      kind == TwitchWatchPlaybackKind.vod ? resumeVodVideo : null;
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
  bool _wasPlayingBeforeNetworkLoss = false;
  final _mediaTimeline = TwitchPlaybackTimelineController();
  int _mediaSeekRevision = 0;

  ({Duration position, Duration duration, Duration minimum})?
  timelineForMediaControls() {
    final entry = _entry;
    if (entry == null) return null;
    final player = _activeSession?.playerOrNull;
    final runtime = entry.playerRuntime;
    final duration = runtime?.canonicalLiveTimelineDuration;
    if (entry.kind != TwitchWatchPlaybackKind.liveDvr ||
        player == null ||
        duration == null ||
        duration <= Duration.zero) {
      return null;
    }
    _mediaTimeline.configure(
      mode: TwitchPlaybackTimelineMode.liveDvr,
      timelineEnabled: true,
      advancing: player.state.playing && !player.state.buffering,
      position: runtime?.liveDvrBridgeTimelinePosition,
      duration: duration,
    );
    return (
      position: _mediaTimeline.positionFor(duration),
      duration: duration,
      minimum:
          entry.activeDvrVideo != null ||
              duration <= const Duration(seconds: 20)
          ? Duration.zero
          : duration - const Duration(seconds: 20),
    );
  }

  Future<void> seekFromMediaControls(Duration target) async {
    final entry = _entry;
    final session = _activeSession;
    final player = session?.playerOrNull;
    if (entry == null || session == null || player == null) return;
    if (entry.kind == TwitchWatchPlaybackKind.vod ||
        entry.kind == TwitchWatchPlaybackKind.clip) {
      await player.seek(target);
      return;
    }
    if (entry.kind != TwitchWatchPlaybackKind.liveDvr) return;
    final timeline = timelineForMediaControls();
    final runtime = entry.playerRuntime;
    if (timeline == null || runtime == null) return;
    final revision = ++_mediaSeekRevision;
    final play = player.state.playing;
    final safeTarget = Duration(
      milliseconds: target.inMilliseconds.clamp(
        timeline.minimum.inMilliseconds,
        timeline.duration.inMilliseconds,
      ),
    );
    final fromLive = timeline.duration - safeTarget;
    String? uri;
    Duration? start;
    var kind = TwitchWatchPlaybackKind.liveDvr;
    if (fromLive <= Duration.zero) {
      uri = (await runtime.prepareLowLatencyLiveFromWarmUpstream())?.toString();
      kind = TwitchWatchPlaybackKind.live;
    } else {
      if (fromLive <= const Duration(seconds: 20)) {
        uri = await runtime.seekLiveBufferReplay(
          fromLive: fromLive,
          timelineDuration: timeline.duration,
        );
      }
      if (uri == null && entry.activeDvrVideo != null) {
        final result = await runtime.seekLiveDvrBridgePosition(
          safeTarget,
          targetProgramDateTime: runtime.canonicalTimelineOrigin?.add(
            safeTarget,
          ),
        );
        uri = result?.playbackUrl;
        start = result?.startPosition;
      }
    }
    if (uri == null ||
        revision != _mediaSeekRevision ||
        !identical(_entry, entry) ||
        !identical(_activeSession, session)) {
      return;
    }
    await TwitchMediaKitPlayerHost.openOrResume(
      session,
      uri: uri,
      forceOpen: true,
      play: play,
      startPosition: start,
    );
    if (revision != _mediaSeekRevision || !identical(_entry, entry)) return;
    _mediaTimeline.commitPosition(safeTarget);
    final playback = TwitchPlaybackSessionState(
      revision: entry.revision + 1,
      kind: kind,
      mediaUri: uri,
      metadata: entry.metadata,
      activeDvrVideo: entry.activeDvrVideo,
      vodVideo: entry.resumeVodVideo,
      preferVodReplayChat: entry.resumeVodReplayChat,
    );
    TwitchMediaKitPlayerHost.keepPlayingWithoutSession(uri);
    showPlayback(playback: playback, playerRuntime: runtime, playOnOpen: play);
  }

  TwitchMiniPlayerEntry? get entry => _entry;
  bool get isActive => _entry != null;

  bool isActiveMediaUri(String? uri) {
    final value = uri?.trim();
    return value != null &&
        value.isNotEmpty &&
        value == _entry?.mediaUri.trim();
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
    bool playOnOpen = true,
  }) {
    final safeUri = playback.mediaUri.trim();
    if (safeUri.isEmpty) return;
    if (_entry?.metadata.channelLogin != playback.metadata.channelLogin ||
        _entry?.metadata.streamId != playback.metadata.streamId ||
        _entry?.kind != playback.kind) {
      _mediaTimeline.reset();
    }
    _entry = TwitchMiniPlayerEntry(
      playback: playback,
      playerRuntime: playerRuntime,
      playOnOpen: playOnOpen,
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
    _mediaSeekRevision++;
    _mediaTimeline.reset();
    TwitchMediaKitPlayerHost.keepPlayingWithoutSession(null);
    if (pausePlayback) {
      TwitchPlaybackSessionController.instance.clear();
      unawaited(TwitchMediaKitPlayerHost.pauseShared().catchError((_) {}));
    }
    notifyListeners();
  }

  void rememberNetworkLoss() {
    _wasPlayingBeforeNetworkLoss =
        _entry != null &&
        (_activeSession?.playerOrNull?.state.playing ?? false);
  }

  Future<void> recoverAfterNetworkRestored({
    bool forceResume = false,
    // Tests can hold recovery before native open without changing OS network.
    Future<void>? beforeOpenForTesting,
  }) async {
    final activeEntry = _entry;
    final session = _activeSession;
    final player = session?.playerOrNull;
    final shouldResume = forceResume || _wasPlayingBeforeNetworkLoss;
    _wasPlayingBeforeNetworkLoss = false;
    if (!shouldResume ||
        activeEntry == null ||
        session == null ||
        player == null) {
      return;
    }

    final position = player.state.position;
    if (beforeOpenForTesting != null) await beforeOpenForTesting;
    if (!identical(_entry, activeEntry) ||
        !identical(_activeSession, session)) {
      return;
    }
    var uri = activeEntry.mediaUri;
    if (forceResume && activeEntry.kind == TwitchWatchPlaybackKind.live) {
      final fresh = await activeEntry.playerRuntime
          ?.prepareLowLatencyLiveFromWarmUpstream(forceProxyReconnect: true);
      if (!identical(_entry, activeEntry) ||
          !identical(_activeSession, session)) {
        return;
      }
      uri = fresh?.toString() ?? uri;
    }
    await TwitchMediaKitPlayerHost.restoreSharedMedia(
      uri: uri,
      forceOpen: true,
    );
    if (!identical(_entry, activeEntry) ||
        !identical(_activeSession, session)) {
      return;
    }
    if (activeEntry.kind != TwitchWatchPlaybackKind.live &&
        position > Duration.zero) {
      await player.seek(position);
    }
  }
}
