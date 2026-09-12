import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/discovery/twitch_live_stream.dart';
import '../../../services/playback/twitch_media_kit_player_host.dart';
import '../../watch/twitch_watch_playback_kind.dart';
import '../twitch_watch_page.dart';
import 'twitch_recorded_watch_playback.dart';
import 'twitch_watch_page_startup.dart';
import 'twitch_watch_playback_state.dart';

// ignore_for_file: invalid_use_of_protected_member

const Duration _liveDvrWarmTtl = Duration(minutes: 8);
const Duration _liveReplaySeekWindowDuration = Duration(seconds: 20);
const Duration _liveReplayCacheDuration = Duration(seconds: 22);
const Duration _liveTimelineEdgeTolerance = Duration(milliseconds: 500);

enum _LiveTimelineSeekRoute { liveEdge, liveBuffer, dvrArchive }

extension TwitchLiveWatchPlaybackMethods on TwitchWatchPageState {
  bool usesLiveDvrArchive(TwitchChannelVideo video) {
    final activeVideoId = activeGrowingVodVideo?.id.trim() ?? '';
    final videoId = video.id.trim();
    final isBoundToCurrentLive =
        videoId.isNotEmpty &&
        activeVideoId == videoId &&
        liveTimelineStreamId?.trim().isNotEmpty == true &&
        liveTimelineStartedAt != null;
    return isBoundToCurrentLive || video.isLikelyGrowingArchive;
  }

  Future<void> prepareActiveGrowingVod({
    required String channel,
    required int generation,
  }) async {
    final fallbackChannel = widget.resolvedInitialOfflineChannel;
    final discoveryService = widget.initialDiscoveryService;
    if (fallbackChannel == null || discoveryService == null) return;

    try {
      final page = await discoveryService.fetchChannelVideos(
        userId: fallbackChannel.broadcasterId,
        first: 1,
      );
      if (!isCurrentWatchTask(generation, channel)) return;
      final video = page.videos.isEmpty ? null : page.videos.first;
      activeGrowingVodVideo = video != null && video.isLikelyGrowingArchive
          ? video
          : null;
      if (activeGrowingVodVideo == null) {
        warmedLiveDvrVideoId = null;
        warmedLiveDvrResolvedAt = null;
      }
      watchPorts.player.runtime.setLiveDvrPlaylistOverride(null);
      if (activeGrowingVodVideo != null) {
        markOwnedPlayback(
          kind: currentPlaybackKind,
          mediaUri: TwitchMediaKitPlayerHost.currentMediaUri,
        );
        unawaited(
          warmLiveDvrBridgeSource(
            video: activeGrowingVodVideo!,
            channel: channel,
            generation: generation,
          ),
        );
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (isCurrentWatchTask(generation, channel)) {
        debugPrint('prepare active growing VOD failed: $error');
      }
    }
  }

  Future<void> warmLiveDvrBridgeSource({
    required TwitchChannelVideo video,
    required String channel,
    required int generation,
  }) async {
    if (!usesLiveDvrArchive(video)) return;
    final wasUsable = hasUsableLiveDvrArchive;

    try {
      final playlist = await watchServices.playbackApi.resolveVodPlaylist(
        videoId: video.id,
        preferredQuality: _preferredLiveDvrQuality(),
      );
      if (!isCurrentWatchTask(generation, channel)) return;
      final warmed = await watchPorts.player.runtime.warmLiveDvrBridge(
        dvrPlaylistUri: playlist.playlistUri,
      );
      vodQualityVariants = playlist.variants;
      currentVodQualityVariant = playlist.selectedVariant;
      currentVodQualityVideo = video;
      currentClipQualityClip = null;
      if (warmed) {
        warmedLiveDvrVideoId = video.id;
        warmedLiveDvrQualityKey = playlist.selectedVariant?.adAwareQualityKey;
        warmedLiveDvrResolvedAt = DateTime.now();
        markOwnedPlayback(
          kind: currentPlaybackKind,
          mediaUri: TwitchMediaKitPlayerHost.currentMediaUri,
        );
      }
      if (wasUsable != hasUsableLiveDvrArchive) {
        playbackTimelineController.reset();
      }
      if (mounted) setState(() {});
    } catch (error) {
      warmedLiveDvrVideoId = null;
      warmedLiveDvrQualityKey = null;
      warmedLiveDvrResolvedAt = null;
      if (isCurrentWatchTask(generation, channel)) {
        debugPrint('warm live DVR bridge failed: $error');
        if (wasUsable != hasUsableLiveDvrArchive) {
          playbackTimelineController.reset();
        }
        if (mounted) setState(() {});
      }
    }
  }

  Future<bool> prepareLiveDvrBridgeSource(TwitchChannelVideo? video) async {
    if (video == null || !usesLiveDvrArchive(video)) {
      watchPorts.player.runtime.setLiveDvrPlaylistOverride(null);
      return false;
    }

    final preferredQuality = _preferredLiveDvrQuality();
    final preferredQualityKey = _normalizeWatchQualityKey(preferredQuality);
    final warmedAt = warmedLiveDvrResolvedAt;
    final hasFreshWarmBridge =
        warmedAt != null &&
        DateTime.now().difference(warmedAt) < _liveDvrWarmTtl;
    if (warmedLiveDvrVideoId == video.id &&
        (preferredQualityKey == null ||
            warmedLiveDvrQualityKey == preferredQualityKey) &&
        watchPorts.player.runtime.hasWarmLiveDvrBridge &&
        hasFreshWarmBridge) {
      debugPrint('[LiveDvrBridge] reuse warmed active archive video=${video.id}');
      return true;
    }

    try {
      final playlist = await watchServices.playbackApi.resolveVodPlaylist(
        videoId: video.id,
        preferredQuality: preferredQuality,
      );
      watchPorts.player.runtime.setLiveDvrPlaylistOverride(null);
      final warmed = await watchPorts.player.runtime.warmLiveDvrBridge(
        dvrPlaylistUri: playlist.playlistUri,
      );
      vodQualityVariants = playlist.variants;
      currentVodQualityVariant = playlist.selectedVariant;
      currentVodQualityVideo = video;
      currentClipQualityClip = null;
      debugPrint(
        '[LiveDvrBridge] active archive warmed video=${video.id} '
        'dvr=${playlist.playlistUri} warmed=$warmed',
      );
      if (warmed) {
        warmedLiveDvrVideoId = video.id;
        warmedLiveDvrQualityKey = playlist.selectedVariant?.adAwareQualityKey;
        warmedLiveDvrResolvedAt = DateTime.now();
      }
      return warmed;
    } catch (error) {
      watchPorts.player.runtime.setLiveDvrPlaylistOverride(null);
      warmedLiveDvrVideoId = null;
      warmedLiveDvrQualityKey = null;
      warmedLiveDvrResolvedAt = null;
      debugPrint('prepare live DVR bridge failed: $error');
      return false;
    }
  }

  Future<void> openActiveDvrReplay({Duration? initialPosition}) async {
    final duration = currentLiveTimelineDuration();
    if (duration != null && duration.inMilliseconds > 0) {
      await openActiveDvrReplayAt(
        initialPosition ?? defaultLiveDvrReplayPosition(),
      );
      return;
    }

    final generation = watchLoadGeneration;
    final channel = channelLogin;
    final target = initialPosition ?? defaultLiveDvrReplayPosition();
    if (await tryOpenLiveBufferReplayAt(target)) return;

    var video = activeGrowingVodVideo;
    if (video == null) {
      await prepareActiveGrowingVod(channel: channel, generation: generation);
      video = activeGrowingVodVideo;
    }
    if (video == null) {
      showSnack('目前找不到可回看的直播 VOD。');
      return;
    }

    if (usesLiveDvrArchive(video)) {
      await switchToLiveDvrReplay(video: video, position: target);
      return;
    }

    final loaded = await openVodPlayback(
      channel: channel,
      generation: generation,
      video: video,
      initialRatio: ratioForVodPosition(target, video.parsedDuration),
    );
    if (!loaded) showSnack('DVR 回放載入失敗。');
  }

  Future<void> openActiveDvrReplayAt(Duration target) async {
    final duration = currentLiveTimelineDuration();
    final targetMs = duration == null || duration.inMilliseconds <= 0
        ? target.inMilliseconds
        : target.inMilliseconds.clamp(0, duration.inMilliseconds).toInt();
    pendingLiveTimelineSeekTarget = Duration(milliseconds: targetMs);
    pendingLiveTimelineReturnToLive = false;
    await drainLiveTimelineActions();
  }

  Future<void> openActiveDvrReplayAtOnce(Duration target) async {
    final duration = currentLiveTimelineDuration();
    if (duration == null || duration.inMilliseconds <= 0) {
      await openActiveDvrReplay();
      return;
    }

    final safeTarget = clampLiveTimelinePosition(target, duration);
    final route = _liveTimelineSeekRoute(safeTarget, duration);
    final generation = watchLoadGeneration;
    final channel = channelLogin;
    switch (route) {
      case _LiveTimelineSeekRoute.liveEdge:
        await returnToLivePlaybackOnce();
        return;
      case _LiveTimelineSeekRoute.liveBuffer:
        if (await openLiveBufferReplayIfAvailable(safeTarget, duration)) return;
        if (!hasUsableLiveDvrArchive) return;
        break;
      case _LiveTimelineSeekRoute.dvrArchive:
        if (!hasUsableLiveDvrArchive) {
          final bufferStart = duration > _liveReplaySeekWindowDuration
              ? duration - _liveReplaySeekWindowDuration
              : Duration.zero;
          await openLiveBufferReplayIfAvailable(bufferStart, duration);
          return;
        }
        break;
    }

    if (watchPorts.player.runtime.usingLiveDvrBridge) {
      await seekLiveDvrBridgePlaybackAt(safeTarget);
      return;
    }

    var video = activeGrowingVodVideo;
    if (video == null) {
      await prepareActiveGrowingVod(channel: channel, generation: generation);
      video = activeGrowingVodVideo;
    }
    if (video == null) {
      showSnack('目前找不到可回看的直播 VOD。');
      return;
    }

    if (usesLiveDvrArchive(video)) {
      final prepared = await prepareLiveDvrBridgeSource(video);
      if (!prepared) {
        showSnack('目前找不到可用的 DVR 播放來源。');
        return;
      }
      await seekLiveDvrBridgePlaybackAt(safeTarget);
      return;
    }

    final loaded = await openVodPlayback(
      channel: channel,
      generation: generation,
      video: video,
      initialRatio: ratioForVodPosition(safeTarget, video.parsedDuration),
    );
    if (!loaded) showSnack('DVR 回放載入失敗。');
  }

  Future<void> returnToLivePlayback() async {
    pendingLiveTimelineSeekTarget = null;
    pendingLiveTimelineReturnToLive = true;
    await drainLiveTimelineActions();
  }

  Future<void> drainLiveTimelineActions() async {
    if (liveTimelineActionInFlight) return;
    liveTimelineActionInFlight = true;
    try {
      while (mounted) {
        final shouldReturnToLive = pendingLiveTimelineReturnToLive;
        final nextTarget = pendingLiveTimelineSeekTarget;
        if (!shouldReturnToLive && nextTarget == null) break;
        pendingLiveTimelineReturnToLive = false;
        pendingLiveTimelineSeekTarget = null;
        final generation = watchLoadGeneration;
        final channel = channelLogin;
        if (shouldReturnToLive) {
          await returnToLivePlaybackOnce();
        } else if (nextTarget != null) {
          await openActiveDvrReplayAtOnce(nextTarget);
        }
        if (!isCurrentWatchTask(generation, channel)) {
          pendingLiveTimelineReturnToLive = false;
          pendingLiveTimelineSeekTarget = null;
          break;
        }
      }
    } finally {
      liveTimelineActionInFlight = false;
    }
  }

  Future<void> returnToLivePlaybackOnce() async {
    if (watchPorts.player.runtime.usingLiveTimelineReplay) {
      debugPrint('[LiveDvrBridge] return to low-latency live requested');
      await switchToLowLatencyLivePlayback();
      return;
    }
    if (!watchPorts.player.runtime.usingExternalVodPlayback) {
      debugPrint('[LiveDvrBridge] return to low-latency live ignored');
      return;
    }
    debugPrint('[LiveDvrBridge] return external replay to low-latency live');
    _clearExternalReplaySelection();
    await switchToLowLatencyLivePlayback();
  }

  Future<void> switchToLiveDvrReplay({
    required TwitchChannelVideo video,
    required Duration position,
  }) async {
    final prepared = await prepareLiveDvrBridgeSource(video);
    if (!prepared) {
      showSnack('目前找不到可用的 DVR 播放來源。');
      return;
    }
    await seekLiveDvrBridgePlaybackAt(position);
  }

  Future<void> seekLiveDvrBridgePlaybackAt(Duration target) async {
    final video = activeGrowingVodVideo;
    final timelineDuration = currentLiveTimelineDuration();
    final safeTarget = timelineDuration == null
        ? target
        : clampLiveTimelinePosition(target, timelineDuration);
    final timelineOffsetSeconds =
        timelineDuration == null || timelineDuration.inMilliseconds <= 0
        ? null
        : safeTarget.inMilliseconds / 1000;
    final timelineOrigin = watchPorts.player.runtime.canonicalTimelineOrigin;
    final targetProgramDateTime = timelineOrigin?.add(safeTarget);
    final seekResult = await watchPorts.player.runtime.seekLiveDvrBridgePosition(
      safeTarget,
      targetProgramDateTime: targetProgramDateTime,
    );
    if (seekResult == null) return;
    await playerSession.useLiveDvrHlsCacheProfile();
    final playbackUrl = seekResult.playbackUrl;
    await openLiveDvrBridgeMedia(
      playbackUrl,
      startPosition: seekResult.startPosition,
    );
    if (video != null) {
      preferVodReplayChat = true;
      markOwnedPlayback(
        kind: TwitchWatchPlaybackKind.liveDvr,
        mediaUri: playbackUrl,
      );
      await vodReplayController.start(
        videoId: video.id,
        channelLogin: channelLogin,
        player: playerSession.player,
        timelineOffsetSeconds: timelineOffsetSeconds,
      );
    } else {
      markOwnedPlayback(
        kind: TwitchWatchPlaybackKind.liveDvr,
        mediaUri: playbackUrl,
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> openLiveDvrBridgeMedia(
    String playbackUrl, {
    required Duration startPosition,
  }) async {
    await playbackController.openMedia(
      uri: playbackUrl,
      play: true,
      forceOpen: true,
      startPosition: startPosition,
    );
  }

  Future<bool> tryOpenLiveBufferReplayAt(Duration target) async {
    final timelineDuration = currentLiveTimelineDuration();
    if (timelineDuration == null || timelineDuration.inMilliseconds <= 0) {
      return false;
    }
    return openLiveBufferReplayIfAvailable(target, timelineDuration);
  }

  Future<bool> openLiveBufferReplayIfAvailable(
    Duration target,
    Duration timelineDuration,
  ) async {
    final safeTarget = clampLiveTimelinePosition(target, timelineDuration);
    final fromLiveMs =
        timelineDuration.inMilliseconds - safeTarget.inMilliseconds;
    if (fromLiveMs <= 0 ||
        fromLiveMs > _liveReplayCacheDuration.inMilliseconds) {
      return false;
    }

    final playbackUrl = await watchPorts.player.runtime.seekLiveBufferReplay(
      fromLive: Duration(milliseconds: fromLiveMs),
      timelineDuration: timelineDuration,
    );
    if (playbackUrl == null) return false;

    vodReplayController.stop();
    preferVodReplayChat = false;
    playbackController.setError(null);
    await playbackController.openMedia(
      uri: playbackUrl,
      play: true,
      forceOpen: true,
    );
    markOwnedPlayback(
      kind: TwitchWatchPlaybackKind.liveDvr,
      mediaUri: playbackUrl,
    );
    if (mounted) setState(() {});
    return true;
  }

  _LiveTimelineSeekRoute _liveTimelineSeekRoute(
    Duration target,
    Duration timelineDuration,
  ) {
    final safeTarget = clampLiveTimelinePosition(target, timelineDuration);
    final fromLiveMs =
        timelineDuration.inMilliseconds - safeTarget.inMilliseconds;
    if (fromLiveMs <= _liveTimelineEdgeTolerance.inMilliseconds) {
      return _LiveTimelineSeekRoute.liveEdge;
    }
    if (fromLiveMs <= _liveReplaySeekWindowDuration.inMilliseconds) {
      return _LiveTimelineSeekRoute.liveBuffer;
    }
    return _LiveTimelineSeekRoute.dvrArchive;
  }

  Duration clampLiveTimelinePosition(
    Duration target,
    Duration timelineDuration,
  ) {
    if (timelineDuration.inMilliseconds <= 0) return Duration.zero;
    return Duration(
      milliseconds: target.inMilliseconds
          .clamp(0, timelineDuration.inMilliseconds)
          .toInt(),
    );
  }

  Duration? currentLiveTimelineDuration() {
    return watchPorts.player.runtime.canonicalLiveTimelineDuration;
  }

  Duration? currentLiveTimelinePosition() {
    final runtimePosition =
        watchPorts.player.runtime.liveDvrBridgeTimelinePosition;
    if (runtimePosition != null && runtimePosition >= Duration.zero) {
      return runtimePosition;
    }

    final timelineDuration = currentLiveTimelineDuration();
    final playerPosition = playerSession.playerOrNull?.state.position;
    if (playerPosition != null && playerPosition >= Duration.zero) {
      if (timelineDuration == null || timelineDuration.inMilliseconds <= 0) {
        return playerPosition;
      }
      return Duration(
        milliseconds: playerPosition.inMilliseconds
            .clamp(0, timelineDuration.inMilliseconds)
            .toInt(),
      );
    }
    return null;
  }

  Duration defaultLiveDvrReplayPosition() {
    final timelineDuration = currentLiveTimelineDuration();
    if (timelineDuration == null || timelineDuration.inMilliseconds <= 0) {
      return Duration.zero;
    }
    final backoff = _liveReplaySeekWindowDuration ~/ 2;
    if (timelineDuration <= backoff) return Duration.zero;
    return timelineDuration - backoff;
  }

  double? ratioForVodPosition(Duration position, Duration? duration) {
    if (duration == null || duration.inMilliseconds <= 0) return null;
    return (position.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  Duration? positionForVodRatio(double? ratio, Duration? duration) {
    if (ratio == null || duration == null || duration.inMilliseconds <= 0) {
      return null;
    }
    return Duration(
      milliseconds: (duration.inMilliseconds * ratio.clamp(0.0, 1.0)).round(),
    );
  }

  Future<void> switchToLowLatencyLivePlayback() async {
    debugPrint('[LiveDvrBridge] switch to low-latency live');
    await playerSession.useLowLatencyHlsProfile();
    watchPorts.player.runtime.setLiveDvrPlaylistOverride(null);
    vodReplayController.stop();
    preferVodReplayChat = false;
    playbackController.setError(null);
    if (mounted) setState(() {});
    final preparedUri = await watchPorts.player.runtime
        .prepareLowLatencyLiveFromWarmUpstream();
    if (preparedUri != null) {
      await playbackController.openMedia(
        uri: preparedUri.toString(),
        play: true,
        forceOpen: true,
      );
      markOwnedPlayback(
        kind: TwitchWatchPlaybackKind.live,
        mediaUri: preparedUri.toString(),
      );
    } else {
      await loadPlayer(channelLogin, forceOpen: true);
    }
    await preferencesController.applyPlayerVolume();
  }

  void _clearExternalReplaySelection() {
    offlineVodFallbackVideo = null;
    currentVodQualityVideo = null;
    currentClipQualityClip = null;
    vodQualityVariants = const [];
    currentVodQualityVariant = null;
    preferVodReplayChat = false;
  }

  String _preferredLiveDvrQuality() {
    final current = watchPorts.player.runtime.currentVariant;
    if (current == null) return 'source';
    final key = current.adAwareQualityKey.trim();
    return key.isEmpty || key == 'unknown' ? current.name : key;
  }

  String? _normalizeWatchQualityKey(String value) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty || text == 'source' || text == 'best') return null;
    return text
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('_', '')
        .replaceAll('-', '');
  }
}
