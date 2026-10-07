// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/models/chat/twitch_whisper_conversation.dart';
import '../lib/features/twitch/services/chat/twitch_whisper_archive_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final phase in ['queued', 'read', 'write']) {
    test('Local delete context changes while $phase', () async {
      final disk = <String, String>{};
      final peer = TwitchWhisperConversation(
        userId: '2',
        login: 'peer',
        displayName: 'Peer',
      );
      final seed = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, raw) async {
          disk[key] = raw;
        },
      );
      await seed.saveDraft('1', peer, 'original');
      await seed.saveDraft('9', peer, 'other account');
      final original = disk['vioclass_twitch_whispers_v1_1'];
      final entered = Completer<void>();
      final release = Completer<void>();
      var permitted = true;
      var armed = true;
      var targetWrites = 0;
      final store = TwitchWhisperArchiveStore(
        read: (key) async {
          if (armed && phase == 'read' && key.endsWith('_1')) {
            armed = false;
            entered.complete();
            await release.future;
          }
          return disk[key];
        },
        write: (key, raw) async {
          if (key.endsWith('_1')) targetWrites++;
          if (armed &&
              ((phase == 'write' && key.endsWith('_1')) ||
                  (phase == 'queued' && key.endsWith('_9')))) {
            armed = false;
            entered.complete();
            await release.future;
          }
          disk[key] = raw;
        },
      );
      Future<void>? blocker;
      if (phase == 'queued') {
        blocker = store.saveDraft('9', peer, 'other draft during queue');
        await entered.future;
      }
      final removal = store.removeConversation(
        '1',
        '2',
        canApply: () => permitted,
      );
      if (phase != 'queued') await entered.future;
      permitted = false;
      release.complete();
      final committed = await removal;
      await blocker;
      expect(committed, phase == 'write');
      expect(targetWrites, phase == 'write' ? 1 : 0);
      final old = await store.load('1');
      if (phase == 'write') {
        expect(old, isEmpty);
      } else {
        expect(disk['vioclass_twitch_whispers_v1_1'], original);
        expect(old.single.draft, 'original');
      }
      expect(
        (await store.load('9')).single.draft,
        phase == 'queued' ? 'other draft during queue' : 'other account',
      );
    });
  }
}
