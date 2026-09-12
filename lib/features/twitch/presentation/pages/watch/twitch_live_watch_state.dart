import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../watch/twitch_playback_session_controller.dart';
import '../../watch/twitch_watch_playback_kind.dart';
import '../twitch_watch_page.dart';
import 'twitch_live_watch_recovery.dart';
import 'twitch_watch_page_startup.dart';

// ignore_for_file: invalid_use_of_protected_member

final Expando<TwitchLiveWatchRecovery> _liveWatchRecoveryByPage =
    Expando<TwitchLiveWatchRecovery>('twitch-live-watch-recovery');

TwitchWatchMode resolveWatchMode(TwitchWatchPageState state) {
  final widget = state.widget;
  final recorded =
      widget.initialClip != null ||
      widget.initialVodVideo != null ||
      widget.initialVodPlaybackOnly;
  return recorded ? TwitchWatchMode.recordedWatch : TwitchWatchMode.liveWatch;
}

void ensureWatchModeRuntime(TwitchWatchPageState state) {
  final mode = resolveWatchMode(state);
  var recovery = _liveWatchRecoveryByPage[state];

  if (recovery == null) {
    if (mode != TwitchWatchMode.liveWatch) return;
    late final TwitchLiveWatchRecovery created;
    created = TwitchLiveWatchRecovery(
      onPoll: () async {
        if (!state.mounted) {
          created.stop();
          return;
        }
        if (!TwitchPlaybackSessionController.instance.isTopRouteOwner(
          state.playbackRouteOwner,
        )) {
          return;
        }

        final previousStreamId = state.liveTimelineStreamId?.trim() ?? '';
        final previousStartedAt = state.liveTimelineStartedAt;
        final live = await state.refreshLiveTimelineStartedAt(
          allowWithoutLivePlayback: true,
          preserveStateWhenOffline: true,
        );
        if (!state.mounted || live != true) return;

        final nextStreamId = state.liveTimelineStreamId?.trim() ?? '';
        final nextStartedAt = state.liveTimelineStartedAt;
        final changed =
            nextStreamId != previousStreamId ||
            nextStartedAt != previousStartedAt;
        if (!changed) return;

        debugPrint(
          '[LiveWatch] discovered new live generation '
          'stream=$previousStreamId->$nextStreamId '
          'startedAt=$previousStartedAt->$nextStartedAt; '
          'restarting unified live/DVR startup',
        );
        await state.loadWatch();
      },
    );
    _liveWatchRecoveryByPage[state] = created;
    recovery = created;
  }

  recovery.setMode(mode);
}

extension TwitchLiveWatchStateMethods on TwitchWatchPageState {
  TwitchWatchMode get watchMode {
    final mode = resolveWatchMode(this);
    ensureWatchModeRuntime(this);
    return mode;
  }

  bool get hasUsableLiveDvrArchive {
    final video = activeGrowingVodVideo;
    return video != null &&
        warmedLiveDvrVideoId == video.id &&
        watchPorts.player.runtime.hasWarmLiveDvrBridge;
  }

  bool get hasDvrReplayPlayback {
    return watchPorts.player.runtime.usingLiveTimelineReplay ||
        watchPorts.player.runtime.usingExternalVodPlayback ||
        hasUsableLiveDvrArchive ||
        watchPorts.player.runtime.hasLiveReplayBuffer;
  }

  bool get showsLiveDvrEdgeLabel {
    return watchPorts.player.runtime.usingLiveTimelineReplay ||
        activeGrowingVodVideo != null;
  }
}
