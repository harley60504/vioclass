// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/api/chat/twitch_irc_api_service.dart';
import '../lib/features/twitch/services/chat/twitch_badge_cache_service.dart';
import '../lib/features/twitch/services/chat/twitch_chat_runtime.dart';

class _InterruptedIrc extends TwitchIrcApiService {
  final events = StreamController<String>.broadcast();
  String? interruption;
  int connections = 0;

  @override
  Stream<String> get rawLines => events.stream;

  @override
  Future<void> connect({
    required String channelLogin,
    String? accessToken,
    String nick = 'justinfan12345',
  }) async {
    connections++;
  }

  @override
  Future<Map<String, String>> waitForCurrentUserState({
    Duration timeout = Duration.zero,
  }) async {
    final event = interruption;
    if (event != null) {
      events.add(event);
      await Future<void>.delayed(Duration.zero);
    }
    return {};
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {
    await events.close();
    await super.dispose();
  }
}

void main() {
  test('Public Twitch IRC socket reconnect receives ROOMSTATE again', () async {
    final irc = TwitchIrcApiService();
    final runtime = TwitchChatRuntime(
      ircApi: irc,
      badgeCache: TwitchBadgeCacheService(),
    );
    addTearDown(() async {
      await runtime.disposeRuntime();
      runtime.dispose();
    });
    Future<void> joined() => irc.messages
        .firstWhere((message) => message.command == 'ROOMSTATE')
        .timeout(const Duration(seconds: 12))
        .then((_) {});
    final firstJoin = joined();
    await Future.wait([firstJoin, runtime.connect(channelLogin: 'twitch')]);
    expect(runtime.connected, isTrue);
    // Inject only the server control signal; both transports below are real
    // anonymous Twitch sockets. No account state or chat text is sent.
    irc.handleSocketMessage(':tmi.twitch.tv RECONNECT');
    await Future<void>.delayed(Duration.zero);
    expect(runtime.connected, isFalse);
    final secondJoin = joined();
    await Future.wait([secondJoin, runtime.reconnect()]);
    expect(runtime.connected, isTrue);
  }, skip: Platform.environment['VIOCLASS_TEST_LIVE_CHAT'] != '1');
  for (final interruption in ['DISCONNECTED', 'ERROR fixture socket failure']) {
    test(
      'startup interruption remains eligible for reconnect: $interruption',
      () async {
        final irc = _InterruptedIrc()..interruption = interruption;
        final runtime = TwitchChatRuntime(
          ircApi: irc,
          badgeCache: TwitchBadgeCacheService(),
        );
        addTearDown(() async {
          await runtime.disposeRuntime();
          runtime.dispose();
        });

        await runtime.connect(channelLogin: 'fixture');
        expect(runtime.connecting, isFalse);
        expect(runtime.connected, isFalse);
        expect(runtime.error, isNotNull);

        irc.interruption = null;
        await runtime.reconnect();
        expect(irc.connections, 2);
        expect(runtime.connected, isTrue);
        expect(runtime.error, isNull);
        irc.handleSocketMessage(
          '@id=recovered;display-name=Viewer :viewer!v@v PRIVMSG #fixture :after recovery',
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          runtime.messages.any((message) => message.id == 'recovered'),
          isTrue,
        );
      },
    );
  }

  test('server RECONNECT makes the runtime eligible for recovery', () async {
    final irc = _InterruptedIrc();
    final runtime = TwitchChatRuntime(
      ircApi: irc,
      badgeCache: TwitchBadgeCacheService(),
    );
    addTearDown(() async {
      await runtime.disposeRuntime();
      runtime.dispose();
    });
    await runtime.connect(channelLogin: 'fixture');
    irc.handleSocketMessage(':tmi.twitch.tv RECONNECT');
    await Future<void>.delayed(Duration.zero);
    expect(runtime.connected, isFalse);
    await runtime.reconnect();
    expect(runtime.connected, isTrue);
    expect(irc.connections, 2);
  });
}
