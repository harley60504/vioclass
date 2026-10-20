// Test fixtures are kept in docs per this repository's test workflow.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_media_kit_player_host.dart';
import 'package:vioclass/features/twitch/models/discovery/twitch_stream_header_metadata.dart';
import 'package:vioclass/features/twitch/presentation/mini_player/twitch_mini_player_controller.dart';
import 'package:vioclass/features/twitch/presentation/watch/twitch_watch_playback_kind.dart';

// No native Player, media requests, video controller, or stored credentials.
class _ControlledPlayer implements Player {
  final opens = <String, Completer<void>>{};
  final seeks = <Duration>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #state) {
      return PlayerState(playing: true, position: const Duration(seconds: 30));
    }
    if (invocation.memberName == #seek) {
      seeks.add(invocation.positionalArguments.single as Duration);
      return Future<void>.value();
    }
    if (invocation.memberName == #open) {
      final media = invocation.positionalArguments.single as Media;
      final gate = Completer<void>();
      opens[media.uri] = gate;
      return gate.future;
    }
    if (invocation.memberName == #pause || invocation.memberName == #dispose) {
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _Session implements TwitchMediaKitPlayerSession {
  _Session(this.playerOrNull);
  @override
  final Player? playerOrNull;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _ControlledPlayer player;
  final mini = TwitchMiniPlayerController.instance;
  setUp(() {
    expect(TwitchMediaKitPlayerHost.playerOrNull, isNull);
    player = _ControlledPlayer();
    TwitchMediaKitPlayerHost.installIsolatedPlayerForTesting(player);
  });
  tearDown(() async {
    mini.close(pausePlayback: false);
    await TwitchMediaKitPlayerHost.disposeNow();
    expect(TwitchMediaKitPlayerHost.playerOrNull, isNull);
  });

  for (final change in ['replace', 'close', 'session', 'unchanged']) {
    for (final failure in [false, true]) {
      test(
        'Controlled mini restore overlap: $change failure=$failure',
        () async {
          final session = _Session(player);
          mini.attachSession(session);
          addTearDown(() => mini.detachSession(session));
          mini.show(
            revision: 1,
            metadata: const TwitchStreamHeaderMetadata(channelLogin: 'fixture'),
            mediaUri: 'fixture-old',
            kind: TwitchWatchPlaybackKind.vod,
          );
          mini.rememberNetworkLoss();
          final recovery = mini.recoverAfterNetworkRestored();
          expect(player.opens.keys, ['fixture-old']);
          if (change == 'replace') {
            mini.show(
              revision: 2,
              metadata: const TwitchStreamHeaderMetadata(channelLogin: 'new'),
              mediaUri: 'fixture-new',
            );
          } else if (change == 'close') {
            mini.close(pausePlayback: false);
          } else if (change == 'session') {
            final replacement = _Session(player);
            mini.attachSession(replacement);
            addTearDown(() => mini.detachSession(replacement));
          }
          if (change != 'unchanged') {
            final newer = TwitchMediaKitPlayerHost.restoreSharedMedia(
              uri: 'fixture-new',
              forceOpen: true,
            );
            player.opens['fixture-new']!.complete();
            await newer;
          }
          if (failure) {
          final originalError = StateError('fixture old restore failed');
          final rejected = expectLater(recovery, throwsA(same(originalError)));
            player.opens['fixture-old']!.completeError(
            originalError,
            );
            await rejected;
          } else {
            player.opens['fixture-old']!.complete();
            await recovery;
          }
          expect(
            player.seeks,
            change == 'unchanged' && !failure
                ? [const Duration(seconds: 30)]
                : isEmpty,
          );
          expect(
            TwitchMediaKitPlayerHost.currentMediaUri,
            change == 'unchanged'
                ? (failure ? null : 'fixture-old')
                : 'fixture-new',
          );
        },
      );
    }
  }

  test('Late old restore does not overwrite the newer source', () async {
    final old = TwitchMediaKitPlayerHost.restoreSharedMedia(
      uri: 'fixture-old',
      forceOpen: true,
    );
    final newer = TwitchMediaKitPlayerHost.restoreSharedMedia(
      uri: 'fixture-new',
      forceOpen: true,
    );
    expect(player.opens.keys, ['fixture-old', 'fixture-new']);
    player.opens['fixture-new']!.complete();
    await newer;
    expect(TwitchMediaKitPlayerHost.currentMediaUri, 'fixture-new');
    player.opens['fixture-old']!.complete();
    await old;
    expect(TwitchMediaKitPlayerHost.currentMediaUri, 'fixture-new');
  });

  test('Disposed player cannot publish a late restore completion', () async {
    final old = TwitchMediaKitPlayerHost.restoreSharedMedia(
      uri: 'fixture-old',
      forceOpen: true,
    );
    await TwitchMediaKitPlayerHost.disposeNow();
    player.opens['fixture-old']!.complete();
    await old;
    expect(TwitchMediaKitPlayerHost.currentMediaUri, isNull);
  });

  test('Pause cancels pending restore state publication', () async {
    final old = TwitchMediaKitPlayerHost.restoreSharedMedia(
      uri: 'fixture-old',
      forceOpen: true,
    );
    await TwitchMediaKitPlayerHost.pauseShared();
    player.opens['fixture-old']!.complete();
    await old;
    expect(TwitchMediaKitPlayerHost.currentMediaUri, isNull);
  });

  test('Old failure keeps the newer source and original error', () async {
    final old = TwitchMediaKitPlayerHost.restoreSharedMedia(
      uri: 'fixture-old',
      forceOpen: true,
    );
    final failure = expectLater(old, throwsStateError);
    final newer = TwitchMediaKitPlayerHost.restoreSharedMedia(
      uri: 'fixture-new',
      forceOpen: true,
    );
    player.opens['fixture-new']!.complete();
    await newer;
    player.opens['fixture-old']!.completeError(StateError('fixture failure'));
    await failure;
    expect(TwitchMediaKitPlayerHost.currentMediaUri, 'fixture-new');
  });

  test('Newer failure does not grant old completion ownership', () async {
    final old = TwitchMediaKitPlayerHost.restoreSharedMedia(
      uri: 'fixture-old',
      forceOpen: true,
    );
    final newer = TwitchMediaKitPlayerHost.restoreSharedMedia(
      uri: 'fixture-new',
      forceOpen: true,
    );
    final failure = expectLater(newer, throwsStateError);
    player.opens['fixture-new']!.completeError(StateError('fixture failure'));
    await failure;
    player.opens['fixture-old']!.complete();
    await old;
    expect(TwitchMediaKitPlayerHost.currentMediaUri, isNull);
  });

  test('Same URI reuse still supersedes an older pending open', () async {
    final initial = TwitchMediaKitPlayerHost.restoreSharedMedia(
      uri: 'fixture-current',
      forceOpen: true,
    );
    player.opens['fixture-current']!.complete();
    await initial;
    final old = TwitchMediaKitPlayerHost.restoreSharedMedia(
      uri: 'fixture-old',
      forceOpen: true,
    );
    await TwitchMediaKitPlayerHost.restoreSharedMedia(
      uri: 'fixture-current',
      play: false,
    );
    expect(player.opens.length, 2);
    player.opens['fixture-old']!.complete();
    await old;
    expect(TwitchMediaKitPlayerHost.currentMediaUri, 'fixture-current');
  });

  test(
    'Late completion cannot overwrite a replacement player source',
    () async {
      final oldPlayer = player;
      final old = TwitchMediaKitPlayerHost.restoreSharedMedia(
        uri: 'fixture-old',
        forceOpen: true,
      );
      await TwitchMediaKitPlayerHost.disposeNow();
      player = _ControlledPlayer();
      TwitchMediaKitPlayerHost.installIsolatedPlayerForTesting(player);
      final newer = TwitchMediaKitPlayerHost.restoreSharedMedia(
        uri: 'fixture-new',
        forceOpen: true,
      );
      player.opens['fixture-new']!.complete();
      await newer;
      oldPlayer.opens['fixture-old']!.complete();
      await old;
      expect(TwitchMediaKitPlayerHost.currentMediaUri, 'fixture-new');
      expect(TwitchMediaKitPlayerHost.playerOrNull, same(player));
    },
  );
}
