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

  TwitchPlaybackSessionState? playableStateForRouteOwner(Object owner) {
    final current = _routePlayback[owner];
    return current != null && current.playable ? current : null;
  }

  TwitchPlaybackSessionState? playableStateBeforeRouteOwner(Object owner) {
    final ownerIndex = _routeOwners.indexWhere(
      (candidate) => identical(candidate, owner),
    );
    if (ownerIndex <= 0) return null;

    for (var index = ownerIndex - 1; index >= 0; index--) {
      final current = _routePlayback[_routeOwners[index]];
      if (current != null && current.playable) return current;
    }
    return null;
  }

  bool isTopRouteOwner(Object owner) {
    return _routeOwners.isNotEmpty && identical(_routeOwners.last, owner);
  }

  void registerRouteOwner(Object owner, {Future<void> Function()? onRestore}) {
    if (!_routeOwners.any((candidate) => identical(candidate, owner))) {
      _routeOwners.add(owner);
    }
    if (onRestore != null) {
      _routeRestoreCallbacks[owner] = onRestore;
    }
  }

  void activateRouteOwner(Object owner) {
    registerRouteOwner(owner);
    _routeOwners.removeWhere((candidate) => identical(candidate, owner));
    _routeOwners.add(owner);
    final playback = playableStateForRouteOwner(owner);
    if (playback != null) {
      restorePlayback(playback);
    }
  }

  void setRoutePlayback(Object owner, TwitchPlaybackSessionState? playback) {
    if (!_routeOwners.any((candidate) => identical(candidate, owner))) {
      registerRouteOwner(owner);
    }
    if (playback == null || !playback.playable) {
      _routePlayback.remove(owner);
    } else {
      _routePlayback[owner] = playback;
    }
  }

  void setRouteOwnedPlayback({
    required Object owner,
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
      clearRoutePlayback(owner);
      if (isTopRouteOwner(owner)) clear();
      return;
    }

    final playback = TwitchPlaybackSessionState(
      revision: _revision + 1,
      kind: kind,
      mediaUri: safeUri,
      metadata: metadata,
      activeDvrVideo: activeDvrVideo,
      vodVideo: vodVideo,
      clip: clip,
      vodRatio: vodRatio,
      preferVodReplayChat: preferVodReplayChat,
    );
    setRoutePlayback(owner, playback);
    if (!isTopRouteOwner(owner)) {
      debugPrint(
        '[PlaybackSession] keep hidden route playback '
        'kind=$kind uri=$safeUri',
      );
      return;
    }

    setPlayback(
      kind: kind,
      mediaUri: safeUri,
      metadata: metadata,
      activeDvrVideo: activeDvrVideo,
      vodVideo: vodVideo,
      clip: clip,
      vodRatio: vodRatio,
      preferVodReplayChat: preferVodReplayChat,
    );
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
