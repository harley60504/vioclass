// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/chat/twitch_irc_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_recent_messages_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message.dart';
import '../lib/features/twitch/services/chat/twitch_badge_cache_service.dart';
import '../lib/features/twitch/services/chat/twitch_chat_runtime.dart';

class _Irc extends TwitchIrcApiService {
  final incoming = StreamController<TwitchChatMessage>.broadcast();
  @override
  Stream<TwitchChatMessage> get messages => incoming.stream;
  @override
  Stream<String> get rawLines => const Stream.empty();
  @override
  Future<void> connect({
    required String channelLogin,
    String? accessToken,
    String nick = 'justinfan12345',
  }) async {}
  @override
  Future<Map<String, String>> waitForCurrentUserState({
    Duration timeout = Duration.zero,
  }) async => {};
  @override
  Future<void> disconnect() async {}
}

class _History implements TwitchRecentMessagesApiService {
  final gate = Completer<TwitchRecentMessagesResult>();
  @override
  Future<TwitchRecentMessagesResult> getRecentMessages({
    required String channelLogin,
    int limit = 100,
    bool includeClearchat = false,
  }) => gate.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TwitchChatMessage message(String id) => TwitchChatMessage.synthetic(
  channelLogin: 'fixture',
  userLogin: 'viewer',
  displayName: 'viewer',
  message: id,
  tags: {'id': id},
);

void main() {
  for (final stale in [false, true]) {
    test('IRC connects before pending history; stale history=$stale', () async {
      final irc = _Irc();
      final history = _History();
      final runtime = TwitchChatRuntime(
        ircApi: irc,
        badgeCache: TwitchBadgeCacheService(),
        recentMessagesApi: history,
      );
      await runtime
          .connect(channelLogin: 'fixture')
          .timeout(const Duration(seconds: 1));
      expect(runtime.connected, isTrue);
      expect(history.gate.isCompleted, isFalse);
      irc.incoming.add(message('live'));
      await Future<void>.delayed(Duration.zero);
      expect(runtime.messages.map((item) => item.id), contains('live'));
      if (stale) await runtime.disconnect();
      history.gate.complete(
        TwitchRecentMessagesResult(
          channelLogin: 'fixture',
          messages: [message('history')],
          rawMessages: const [],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(runtime.messages.map((item) => item.id), contains('live'));
      expect(runtime.messages.any((item) => item.id == 'history'), !stale);
      if (!stale) {
        runtime.applyRecentHistory([message('official'), message('live')]);
        expect(
          runtime.messages.map((item) => item.id),
          containsAll(['live', 'history', 'official']),
        );
        expect(runtime.messages.where((item) => item.id == 'live').length, 1);
        expect(runtime.connected, isTrue);
      }
      await runtime.disposeRuntime();
      runtime.dispose();
      await irc.incoming.close();
    });
  }
}
