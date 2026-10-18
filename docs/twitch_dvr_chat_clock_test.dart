// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import '../lib/features/twitch/api/chat/twitch_vod_comments_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message.dart';
import '../lib/features/twitch/parsers/chat/twitch_chat_message_normalizer.dart';
import '../lib/features/twitch/services/chat/twitch_badge_cache_service.dart';
import '../lib/features/twitch/services/chat/twitch_vod_chat_replay_runtime.dart';

class _State implements PlayerState {
  @override
  Duration position = Duration.zero;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player implements Player {
  @override
  final state = _State();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Api implements TwitchVodCommentsApiService {
  final offsets = <double>[];
  final gates = <Completer<List<TwitchVodComment>>>[];
  @override
  Future<List<TwitchVodComment>> fetchComments({
    required String videoId,
    required String channelLogin,
    required double offsetSeconds,
  }) {
    offsets.add(offsetSeconds);
    final gate = Completer<List<TwitchVodComment>>();
    gates.add(gate);
    return gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TwitchVodComment comment(String id, double seconds) => TwitchVodComment(
  contentOffsetSeconds: seconds,
  message: TwitchChatMessageNormalizer(badgeCache: TwitchBadgeCacheService())
      .normalize(
        receivedAt: DateTime.fromMillisecondsSinceEpoch(0),
        TwitchChatMessage.synthetic(
          channelLogin: 'fixture',
          userLogin: 'viewer',
          displayName: 'viewer',
          message: id,
          tags: {'id': id},
        ),
      ),
);

void main() {
  testWidgets(
    'DVR chat follows canonical clock, not segment-local player time',
    (tester) async {
      final api = _Api();
      final player = _Player();
      final runtime = TwitchVodChatReplayRuntime(api: api);
      addTearDown(runtime.dispose);
      var clock = const Duration(hours: 1);
      await runtime.start(
        videoId: 'vod',
        channelLogin: 'fixture',
        player: player,
        timelinePositionProvider: () => clock,
      );
      expect(api.offsets.single, 3585);
      api.gates.single.complete([
        comment('before', 3599),
        comment('after', 3601),
      ]);
      await tester.pump();
      await runtime.nudge();
      expect(runtime.messages.map((m) => m.id), ['before']);
      player.state.position = const Duration(seconds: 100);
      await runtime.nudge();
      expect(runtime.messages.map((m) => m.id), ['before']);
      clock = const Duration(seconds: 3602);
      await runtime.nudge();
      expect(runtime.messages.map((m) => m.id), ['before', 'after']);
      // Seeking beyond the buffered range must fetch at the new clock.
      clock = const Duration(seconds: 4000);
      await runtime.nudge();
      await tester.pump(const Duration(milliseconds: 410));
      expect(api.offsets.last, 3985);
      expect(runtime.messages, isEmpty);
      runtime.stop();
    },
  );

  testWidgets(
    'Same-VOD restart and mini return ignore stale pages and local zero',
    (tester) async {
      final api = _Api();
      final player = _Player();
      final runtime = TwitchVodChatReplayRuntime(api: api);
      addTearDown(runtime.dispose);
      await runtime.start(
        videoId: 'vod',
        channelLogin: 'fixture',
        player: player,
        timelinePositionProvider: () => const Duration(hours: 1),
      );
      await runtime.start(
        videoId: 'vod',
        channelLogin: 'fixture',
        player: player,
        timelinePositionProvider: () => const Duration(hours: 2),
      );
      expect(api.offsets, [3585, 7185]);
      api.gates[0].complete([comment('stale', 3600)]);
      await tester.pump();
      expect(runtime.fetching, isTrue);
      expect(runtime.messages, isEmpty);
      api.gates[1].complete([comment('current', 7200)]);
      await tester.pump();
      await runtime.nudge();
      expect(runtime.messages.map((m) => m.id), ['current']);
      expect(runtime.error, isNull);
      runtime.stop();
    },
  );

  testWidgets('Ordinary VOD keeps its native-player clock', (tester) async {
    final api = _Api();
    final player = _Player();
    player.state.position = const Duration(seconds: 60);
    final runtime = TwitchVodChatReplayRuntime(api: api);
    addTearDown(runtime.dispose);
    await runtime.start(
      videoId: 'vod',
      channelLogin: 'fixture',
      player: player,
    );
    expect(api.offsets.single, 45);
    api.gates.single.complete([comment('native', 62)]);
    await tester.pump();
    player.state.position = const Duration(seconds: 63);
    await runtime.nudge();
    expect(runtime.messages.map((m) => m.id), ['native']);
    runtime.stop();
  });
}
