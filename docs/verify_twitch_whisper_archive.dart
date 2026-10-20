// Pure Dart regression check. No Twitch requests or real user data.
// This standalone regression script intentionally uses local imports and stdout.
// ignore_for_file: avoid_relative_lib_imports, avoid_print
import '../lib/features/twitch/models/chat/twitch_whisper_conversation.dart';
import '../lib/features/twitch/services/chat/twitch_whisper_archive_store.dart';

void check(bool condition, String label) {
  if (!condition) throw StateError(label);
}

Future<void> main() async {
  final disk = <String, String>{};
  TwitchWhisperArchiveStore store() => TwitchWhisperArchiveStore(
    read: (key) async => disk[key],
    write: (key, value) async {
      disk[key] = value;
    },
  );
  final archive = store();
  final peer = TwitchWhisperConversation(
    userId: '2',
    login: 'test_peer',
    displayName: 'Test Peer',
  );
  final incoming = TwitchWhisperMessage(
    id: 'event-1',
    fromUserId: '2',
    toUserId: '1',
    text: 'Test only',
    timestamp: DateTime.utc(2026, 10, 3),
    state: TwitchWhisperMessageState.received,
  );
  await Future.wait([
    archive.append('1', peer, incoming),
    archive.append('1', peer, incoming),
    archive.saveDraft('1', peer, 'Unsent draft'),
  ]);
  final restored = (await store().load('1')).single;
  check(
    restored.messages.length == 1,
    'duplicate events must not duplicate messages',
  );
  check(
    restored.unreadCount == 1,
    'duplicate events must not increase unread count',
  );
  check(
    restored.draft == 'Unsent draft',
    'concurrent changes and restart must preserve draft',
  );
  check(
    (await archive.load('3')).isEmpty,
    'account histories must be isolated',
  );
  await archive.markRead('1', '2');
  check((await archive.load('1')).single.unreadCount == 0, 'mark read');
  final sending = TwitchWhisperMessage(
    id: 'out-1',
    fromUserId: '1',
    toUserId: '2',
    text: 'Unconfirmed request',
    timestamp: DateTime.utc(2026, 10, 3, 1),
    state: TwitchWhisperMessageState.sending,
  );
  await archive.append('1', peer, sending);
  await archive.saveDraft('1', peer, 'Another draft');
  check(
    (await archive.load('1')).single.messages.last.state ==
        TwitchWhisperMessageState.sending,
    'saving a draft in the active session must not fail an in-flight request',
  );
  final recovered = (await store().load('1')).single;
  check(
    recovered.messages.last.state == TwitchWhisperMessageState.failed,
    'interrupted sends must not appear successful',
  );
  check(
    recovered.unreadCount == 0,
    'outgoing messages must not increase unread count',
  );
  final before = disk['vioclass_twitch_whispers_v1_1'];
  var rejected = false;
  try {
    await archive.append('3', peer, incoming);
  } catch (_) {
    rejected = true;
  }
  check(rejected, 'a message belonging to another account must be rejected');
  check(
    disk['vioclass_twitch_whispers_v1_1'] == before,
    'other account data must remain unchanged',
  );
  disk['vioclass_twitch_whispers_v1_4'] = 'broken-json';
  rejected = false;
  try {
    await archive.saveDraft('4', peer, 'should not overwrite');
  } catch (_) {
    rejected = true;
  }
  check(
    rejected && disk['vioclass_twitch_whispers_v1_4'] == 'broken-json',
    'corrupt data must be preserved',
  );
  disk['vioclass_twitch_whispers_v1_5'] = before!;
  rejected = false;
  try {
    await archive.load('5');
  } catch (_) {
    rejected = true;
  }
  check(rejected, 'archive owner mismatch must be rejected');
  print(
    'PASS: persistence, drafts, account isolation, deduplication, unread state, send recovery, corruption protection.',
  );
}
