// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/models/chat/twitch_whisper_conversation.dart';

TwitchWhisperMessage row(
  String id, {
  bool historical = false,
  int second = 0,
  String text = 'hello',
  TwitchWhisperMessageState state = TwitchWhisperMessageState.submitted,
  String from = '1',
  String to = '2',
}) => TwitchWhisperMessage(
  id: id,
  fromUserId: from,
  toUserId: to,
  text: text,
  timestamp: DateTime.utc(2026, 10, 5, 0, 0, second),
  state: state,
  historicalOnly: historical,
);

TwitchWhisperConversation peer(List<TwitchWhisperMessage> rows) =>
    TwitchWhisperConversation(
      userId: '2',
      login: 'peer',
      displayName: 'Peer',
      messages: rows,
    );

void main() {
  test(
    'Unique accepted local echo displays official row without deleting storage',
    () {
      final conversation = peer([
        row('local-send'),
        row('official', historical: true, second: 1),
      ]);
      expect(conversation.displayMessages.map((m) => m.id), ['official']);
      expect(conversation.messages.length, 2);
      final restored = TwitchWhisperConversation.fromJson(
        conversation.toJson(),
      );
      expect(restored.messages.length, 2);
      expect(restored.displayMessages.map((m) => m.id), ['official']);
    },
  );
  test('Ambiguous repeated sends are not collapsed', () {
    expect(
      peer([
        row('local-a'),
        row('local-b', second: 1),
        row('remote', historical: true),
      ]).displayMessages.length,
      3,
    );
    expect(
      peer([
        row('local-a'),
        row('remote-a', historical: true),
        row('remote-b', historical: true),
      ]).displayMessages.length,
      3,
    );
  });
  test(
    'Failures, pending sends, different participants and old messages remain',
    () {
      for (final local in [
        row('local-a', state: TwitchWhisperMessageState.failed),
        row('local-a', state: TwitchWhisperMessageState.sending),
        row('local-a', state: TwitchWhisperMessageState.unconfirmed),
        row('local-a', text: 'different'),
        row('local-a', from: '2', to: '1'),
        row('local-a', second: 31),
      ]) {
        expect(
          peer([local, row('remote', historical: true)]).displayMessages.length,
          2,
        );
      }
    },
  );
  test('Real official messages with equal text remain distinct', () {
    expect(
      peer([
        row('remote-a', historical: true),
        row('remote-b', historical: true),
      ]).displayMessages.length,
      2,
    );
  });
}
