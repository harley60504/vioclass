// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/models/discovery/twitch_live_stream.dart';
import '../lib/features/twitch/models/discovery/twitch_stream_header_metadata.dart';
import '../lib/features/twitch/presentation/mini_player/twitch_mini_player_controller.dart';
import '../lib/features/twitch/presentation/pages/twitch_watch_page.dart';
import '../lib/features/twitch/presentation/pages/watch/twitch_live_watch_state.dart';
import '../lib/features/twitch/presentation/watch/twitch_playback_session_controller.dart';
import '../lib/features/twitch/presentation/watch/twitch_watch_playback_kind.dart';
import '../lib/features/twitch/services/playback/twitch_media_kit_player_host.dart';

const metadata = TwitchStreamHeaderMetadata(channelLogin: 'fixture');
final vod = TwitchChannelVideo.fromHelixJson({'id': 'fixture-vod'});
final clip = TwitchChannelClip.fromHelixJson({'id': 'fixture-clip'});

class _ExpansionRouteState extends TwitchWatchPageState {
  _ExpansionRouteState(this.page);
  final TwitchWatchPage page;
  @override
  TwitchWatchPage get widget => page;
}

TwitchPlaybackSessionState _state(TwitchWatchPlaybackKind kind, String uri) =>
    TwitchPlaybackSessionState(
      revision: 20,
      kind: kind,
      mediaUri: uri,
      metadata: metadata,
      activeDvrVideo: vod,
      vodVideo: vod,
      clip: clip,
      vodRatio: .4,
      preferVodReplayChat: true,
    );

void main() {
  final controller = TwitchPlaybackSessionController.instance;
  final mini = TwitchMiniPlayerController.instance;
  final owners = <Object>[];
  Object owner() {
    final value = Object();
    owners.add(value);
    controller.registerRouteOwner(value);
    return value;
  }

  setUp(() {
    // Never acquire a native session or instantiate media_kit Player.
    expect(TwitchMediaKitPlayerHost.playerOrNull, isNull);
    controller.clear();
    mini.close(pausePlayback: false);
    owners.clear();
  });
  tearDown(() async {
    mini.close(pausePlayback: false);
    for (final value in owners.reversed) {
      await controller.restoreAfterUnregisterRouteOwner(value);
    }
    controller.clear();
    expect(TwitchMediaKitPlayerHost.playerOrNull, isNull);
  });

  for (final kind in [
    TwitchWatchPlaybackKind.live,
    TwitchWatchPlaybackKind.liveDvr,
    TwitchWatchPlaybackKind.vod,
    TwitchWatchPlaybackKind.clip,
  ]) {
    test('Mini expansion selects the correct watch mode for $kind', () {
      mini.showPlayback(playback: _state(kind, 'fixture-media'));
      final entry = mini.entry!;
      final page = TwitchWatchPage(
        initialMetadata: entry.metadata,
        initialActiveDvrVideo: entry.activeDvrVideo,
        initialVodVideo: entry.watchPageVodVideo,
        initialClip: kind == TwitchWatchPlaybackKind.clip
            ? entry.resumeClip
            : null,
        initialPreferVodReplayChat: entry.resumeVodReplayChat,
        initialReuseCurrentPlayback: true,
      );
      final live =
          kind == TwitchWatchPlaybackKind.live ||
          kind == TwitchWatchPlaybackKind.liveDvr;
      expect(
        resolveWatchMode(_ExpansionRouteState(page)),
        live ? TwitchWatchMode.liveWatch : TwitchWatchMode.recordedWatch,
      );
      expect(page.initialActiveDvrVideo, same(vod));
      expect(
        page.initialVodVideo,
        live || kind == TwitchWatchPlaybackKind.clip ? isNull : same(vod),
      );
      if (kind == TwitchWatchPlaybackKind.live) {
        expect(page.initialPreferVodReplayChat, isFalse);
      }
    });
    test(
      'Mini matches padded $kind URI without changing playback snapshot',
      () {
        final state = _state(kind, '  fixture-media?generation=1  ');
        mini.showPlayback(playback: state);
        expect(mini.entry!.playback, same(state));
        expect(mini.isActiveMediaUri('fixture-media?generation=1'), true);
        expect(mini.isActiveMediaUri(' fixture-media?generation=1 '), true);
        expect(mini.isActiveMediaUri('fixture-media?generation=2'), false);
        expect(mini.isActiveMediaUri('fixture-media'), false);
        expect(mini.isActiveMediaUri('   '), false);
        expect(mini.isActiveMediaUri(null), false);
      },
    );
    test(
      'Mini entry preserves $kind resume metadata without native playback',
      () {
        final state = _state(kind, 'fixture-media');
        mini.showPlayback(playback: state);
        final entry = mini.entry!;
        expect(entry.playback, same(state));
        expect(entry.kind, kind);
        expect(entry.revision, 20);
        expect(entry.metadata, same(metadata));
        expect(entry.activeDvrVideo, same(vod));
        expect(entry.resumeVodVideo, same(vod));
        expect(entry.resumeClip, same(clip));
        expect(entry.resumeVodRatio, .4);
        expect(entry.resumeVodReplayChat, kind != TwitchWatchPlaybackKind.live);
        expect(entry.playerRuntime, isNull);
        expect(mini.isActiveMediaUri(' fixture-media '), true);
        expect(mini.isActiveMediaUri('other-media'), false);
      },
    );
  }

  test(
    'Mini rejects empty entry and closes without clearing retained playback',
    () {
      controller.restorePlayback(
        _state(TwitchWatchPlaybackKind.vod, 'fixture-vod'),
      );
      final before = controller.state;
      mini.showPlayback(
        playback: _state(TwitchWatchPlaybackKind.vod, 'fixture-vod'),
      );
      mini.showPlayback(playback: _state(TwitchWatchPlaybackKind.live, '   '));
      expect(mini.entry!.mediaUri, 'fixture-vod');
      mini.close(pausePlayback: false);
      expect(mini.isActive, false);
      expect(controller.state, same(before));
    },
  );

  test(
    'Closing mini with pause clears session state without native Player',
    () {
      controller.restorePlayback(
        _state(TwitchWatchPlaybackKind.live, 'fixture-live'),
      );
      mini.showPlayback(playback: controller.state!);
      mini.close();
      expect(controller.state, isNull);
      expect(mini.entry, isNull);
    },
  );

  test('Mini show normalizes media URI for subsequent identity matching', () {
    mini.show(revision: 1, metadata: metadata, mediaUri: ' fixture-live ');
    expect(mini.isActiveMediaUri('fixture-live'), true);
  });

  test('Inactive mini rejects null and empty URI identities', () {
    expect(mini.isActiveMediaUri(null), false);
    expect(mini.isActiveMediaUri(''), false);
  });

  test(
    'Dormant mini network restoration never creates a native Player',
    () async {
      mini.showPlayback(
        playback: _state(TwitchWatchPlaybackKind.vod, 'fixture-vod'),
      );
      mini.rememberNetworkLoss();
      await mini.recoverAfterNetworkRestored();
      expect(mini.entry!.kind, TwitchWatchPlaybackKind.vod);
      expect(TwitchMediaKitPlayerHost.playerOrNull, isNull);
    },
  );

  test('Hidden route completion cannot replace top route playback', () {
    final root = owner();
    controller.setRoutePlayback(
      root,
      _state(TwitchWatchPlaybackKind.live, 'root'),
    );
    final top = owner();
    controller.setRouteOwnedPlayback(
      owner: top,
      kind: TwitchWatchPlaybackKind.clip,
      mediaUri: 'top',
      metadata: metadata,
    );
    final visible = controller.state;
    controller.setRouteOwnedPlayback(
      owner: root,
      kind: TwitchWatchPlaybackKind.liveDvr,
      mediaUri: 'hidden',
      metadata: metadata,
    );
    expect(controller.state, same(visible));
    expect(controller.playableStateBeforeRouteOwner(top)!.mediaUri, 'hidden');
  });

  test(
    'Removing hidden owner does not restore or replace visible playback',
    () async {
      final root = owner();
      controller.setRoutePlayback(
        root,
        _state(TwitchWatchPlaybackKind.live, 'root'),
      );
      final top = owner();
      controller.setRouteOwnedPlayback(
        owner: top,
        kind: TwitchWatchPlaybackKind.vod,
        mediaUri: 'top',
        metadata: metadata,
      );
      final visible = controller.state;
      await controller.restoreAfterUnregisterRouteOwner(root);
      expect(controller.state, same(visible));
      expect(controller.isTopRouteOwner(top), true);
    },
  );

  test(
    'Popping top restores prior playable snapshot across a nonplayable owner',
    () async {
      final root = owner();
      final snapshot = _state(TwitchWatchPlaybackKind.liveDvr, 'root-dvr');
      controller.setRoutePlayback(root, snapshot);
      owner();
      final top = owner();
      controller.setRouteOwnedPlayback(
        owner: top,
        kind: TwitchWatchPlaybackKind.clip,
        mediaUri: 'top',
        metadata: metadata,
      );
      await controller.restoreAfterUnregisterRouteOwner(top);
      expect(controller.state!.mediaUri, 'root-dvr');
      expect(controller.state!.activeDvrVideo, same(vod));
      expect(controller.state!.vodRatio, .4);
      expect(controller.state!.preferVodReplayChat, true);
    },
  );

  test(
    'Top removal invokes the closest saved restore callback exactly once',
    () async {
      final root = owner();
      var callbacks = 0;
      final snapshot = _state(TwitchWatchPlaybackKind.vod, 'root-vod');
      controller.setRoutePlayback(root, snapshot);
      controller.registerRouteOwner(
        root,
        onRestore: () async {
          callbacks++;
          controller.restorePlayback(snapshot);
        },
      );
      final top = owner();
      await controller.restoreAfterUnregisterRouteOwner(top);
      await controller.restoreAfterUnregisterRouteOwner(top);
      expect(callbacks, 1);
      expect(controller.state!.resumeVodVideo, same(vod));
    },
  );

  test(
    'Clearing an invalid hidden playback does not clear visible session',
    () {
      final root = owner();
      final top = owner();
      controller.setRouteOwnedPlayback(
        owner: top,
        kind: TwitchWatchPlaybackKind.live,
        mediaUri: 'top',
        metadata: metadata,
      );
      final visible = controller.state;
      controller.setRouteOwnedPlayback(
        owner: root,
        kind: TwitchWatchPlaybackKind.none,
        mediaUri: '',
        metadata: metadata,
      );
      expect(controller.state, same(visible));
      expect(controller.playableStateForRouteOwner(root), isNull);
      expect(controller.playableStateForMediaUri(' top '), same(visible));
      expect(controller.playableStateForMediaUri('other'), isNull);
    },
  );

  test(
    'Media controls follow top route and discard disposed seek/timeline callbacks',
    () async {
      final root = owner();
      final top = owner();
      final seeks = <String>[];
      controller.registerRouteOwner(
        root,
        onMediaSeek: (target) async {
          seeks.add('root:${target.inSeconds}');
        },
        mediaTimeline: () => (
          position: const Duration(seconds: 10),
          duration: const Duration(seconds: 100),
          minimum: Duration.zero,
        ),
      );
      controller.registerRouteOwner(
        top,
        onMediaSeek: (target) async {
          seeks.add('top:${target.inSeconds}');
        },
        mediaTimeline: () => (
          position: const Duration(seconds: 80),
          duration: const Duration(seconds: 100),
          minimum: const Duration(seconds: 80),
        ),
      );
      expect(
        controller.timelineForMediaControls()!.minimum,
        const Duration(seconds: 80),
      );
      expect(
        await controller.seekFromMediaControls(const Duration(seconds: 90)),
        true,
      );
      expect(seeks, ['top:90']);
      await controller.restoreAfterUnregisterRouteOwner(top);
      expect(controller.timelineForMediaControls()!.minimum, Duration.zero);
      await controller.seekFromMediaControls(const Duration(seconds: 15));
      expect(seeks, ['top:90', 'root:15']);
      await controller.restoreAfterUnregisterRouteOwner(root);
      expect(controller.timelineForMediaControls(), isNull);
      expect(await controller.seekFromMediaControls(Duration.zero), false);
    },
  );

  for (final removeMiddleFirst in [false, true]) {
    test('Three route stack restores only surviving owners '
        '(remove middle first=$removeMiddleFirst)', () async {
      final restored = <String>[];
      final root = owner();
      final middle = owner();
      final top = owner();
      for (final entry in {
        root: 'root',
        middle: 'middle',
        top: 'top',
      }.entries) {
        final snapshot = _state(TwitchWatchPlaybackKind.vod, entry.value);
        controller.setRoutePlayback(entry.key, snapshot);
        controller.registerRouteOwner(
          entry.key,
          onRestore: () async {
            restored.add(entry.value);
            controller.restorePlayback(snapshot);
          },
        );
      }
      controller.activateRouteOwner(top);
      if (removeMiddleFirst) {
        await controller.restoreAfterUnregisterRouteOwner(middle);
        expect(restored, isEmpty);
        expect(controller.state!.mediaUri, 'top');
        expect(controller.playableStateForRouteOwner(middle), isNull);
      }
      await controller.restoreAfterUnregisterRouteOwner(top);
      expect(restored, [removeMiddleFirst ? 'root' : 'middle']);
      expect(controller.state!.mediaUri, restored.last);
      expect(controller.playableStateForRouteOwner(top), isNull);
      if (!removeMiddleFirst) {
        await controller.restoreAfterUnregisterRouteOwner(middle);
        expect(restored, ['middle', 'root']);
        expect(controller.state!.mediaUri, 'root');
      }
      await controller.restoreAfterUnregisterRouteOwner(top);
      await controller.restoreAfterUnregisterRouteOwner(middle);
      expect(restored.where((value) => value == 'root'), hasLength(1));
      expect(controller.isTopRouteOwner(root), true);
    });
  }
}
