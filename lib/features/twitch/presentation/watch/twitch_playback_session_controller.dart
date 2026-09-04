import 'package:flutter/foundation.dart';

import '../../models/discovery/twitch_live_stream.dart';
import '../../models/discovery/twitch_stream_header_metadata.dart';
import 'twitch_watch_playback_kind.dart';

class TwitchPlaybackSessionState {
  final int revision;
  final TwitchWatchPlaybackKind kind;
  final String mediaUri;
  final TwitchStreamHeaderMetadata metadata;
  final TwitchChannelVideo? activeDvrVideo;
  final TwitchChannelVideo? vodVideo;
  final TwitchChannelClip? clip;
  final double? vodRatio;
  final bool preferVodReplayChat;

  const TwitchPlaybackSessionState({
    required this.revision,
    required this.kind,
    required this.mediaUri,
    required this.metadata,
    this.activeDvrVideo,
    this.vodVideo,
    this.clip,
    this.vodRatio,
    this.preferVodReplayChat = false,
  });

  bool get playable =>
      kind != TwitchWatchPlaybackKind.none && mediaUri.trim().isNotEmpty;

  bool get usesReplayChat =>
      kind == TwitchWatchPlaybackKind.liveDvr ||
      kind == TwitchWatchPlaybackKind.vod ||
      kind == TwitchWatchPlaybackKind.clip;

  TwitchChannelVideo? get resumeVodVideo => vodVideo;

  TwitchChannelClip? get resumeClip => clip;

  double? get resumeVodRatio => vodRatio;

  bool get resumeVodReplayChat => usesReplayChat && preferVodReplayChat;
}

class TwitchPlaybackSessionController extends ChangeNotifier {
  TwitchPlaybackSessionController._();

  static final TwitchPlaybackSessionController instance =
      TwitchPlaybackSessionController._();

  int _revision = 0;
  TwitchPlaybackSessionState? _state;
  final List<Object> _routeOwners = <Object>[];
  final Map<Object, TwitchPlaybackSessionState> _routePlayback =
      <Object, TwitchPlaybackSessionState>{};
  final Map<Object, Future<void> Function()> _routeRestoreCallbacks =
      <Object, Future<void> Function()>{};

  TwitchPlaybackSessionState? get state => _state;

  TwitchPlaybackSessionState? get playableState {
    final current = _state;
    return current != null && current.playable ? current : null;
  }

  TwitchPlaybackSessionState? playableStateForMediaUri(String? mediaUri) {
    final current = playableState;
    if (current == null) return null;

    final safeUri = mediaUri?.trim();
    if (safeUri == null || safeUri.isEmpty) return null;
    return current.mediaUri.trim() == safeUri ? current : null;
  }

  void registerRouteOwner(Object owner, {Future<void> Function()? onRestore}) {
    _routeOwners.removeWhere((candidate) => identical(candidate, owner));
    _routeOwners.add(owner);
    if (onRestore != null) {
      _routeRestoreCallbacks[owner] = onRestore;
    }
  }

  void setRoutePlayback(Object owner, TwitchPlaybackSessionState? playback) {
    registerRouteOwner(owner);
    if (playback == null || !playback.playable) {
      _routePlayback.remove(owner);
    } else {
      _routePlayback[owner] = playback;
    }
  }

  void clearRoutePlayback(Object owner) {
    _routePlayback.remove(owner);
  }

  Future<void> restoreAfterUnregisterRouteOwner(Object owner) async {
    final wasTop =
        _routeOwners.isNotEmpty && identical(_routeOwners.last, owner);
    _routeOwners.removeWhere((candidate) => identical(candidate, owner));
    _routePlayback.remove(owner);
    _routeRestoreCallbacks.remove(owner);
    if (!wasTop) return;

    for (final candidate in _routeOwners.reversed) {
      final playback = _routePlayback[candidate];
      if (playback == null || !playback.playable) continue;
      final callback = _routeRestoreCallbacks[candidate];
      if (callback != null) {
        await callback();
        return;
      }
      restorePlayback(playback);
      return;
    }
  }

  void setPlayback({
    required TwitchWatchPlaybackKind kind,
    required String? mediaUri,
    required TwitchStreamHeaderMetadata metadata,
    TwitchChannelVideo? activeDvrVideo,
    TwitchChannelVideo? vodVideo,
    TwitchChannelClip? clip,
    double? vodRatio,
    bool preferVodReplayChat = false,
  }) {
    final safeUri = mediaUri?.trim() ?? '';
    if (safeUri.isEmpty || kind == TwitchWatchPlaybackKind.none) {
      clear();
      return;
    }

    _state = TwitchPlaybackSessionState(
      revision: ++_revision,
      kind: kind,
      mediaUri: safeUri,
      metadata: metadata,
      activeDvrVideo: activeDvrVideo,
      vodVideo: vodVideo,
      clip: clip,
      vodRatio: vodRatio,
      preferVodReplayChat: preferVodReplayChat,
    );
    debugPrint('[PlaybackSession] #$_revision kind=$kind uri=$safeUri');
    notifyListeners();
  }

  void restorePlayback(TwitchPlaybackSessionState playback) {
    setPlayback(
      kind: playback.kind,
      mediaUri: playback.mediaUri,
      metadata: playback.metadata,
      activeDvrVideo: playback.activeDvrVideo,
      vodVideo: playback.vodVideo,
      clip: playback.clip,
      vodRatio: playback.vodRatio,
      preferVodReplayChat: playback.preferVodReplayChat,
    );
  }

  void clear() {
    if (_state == null) return;
    _state = null;
    _revision++;
    debugPrint('[PlaybackSession] #$_revision kind=none');
    notifyListeners();
  }
}
