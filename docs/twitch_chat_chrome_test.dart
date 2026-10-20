// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/services/engagement/twitch_channel_points_runtime_service.dart';
import '../lib/features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart';
import '../lib/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_header_bar.dart';
import '../lib/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_input_section.dart';
import '../lib/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_layout_metrics.dart';
import '../lib/features/twitch/presentation/widgets/watch/chat/twitch_vod_replay_chat_panel.dart';
import '../lib/features/twitch/services/chat/twitch_vod_chat_replay_runtime.dart';
import '../lib/features/twitch/api/chat/twitch_vod_comments_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/services/chat/twitch_badge_cache_service.dart';

class LargeBalance extends TwitchChannelPointsRuntimeSnapshot {
  LargeBalance()
    : super(
        channelLogin: 'tester',
        startedAt: DateTime(2026),
        completedAt: DateTime(2026),
        publicRead: null,
        publicError: null,
        context: null,
        contextError: null,
        rewardsResult: null,
        rewardsError: null,
      );
  @override
  int get balance => 999999999999;
}

Widget host(
  Widget child, {
  double width = 320,
  double scale = 1,
  double keyboard = 0,
}) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 600),
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child,
        ),
      ),
    ),
  ),
);

TwitchWatchChatInputSection composer(
  TextEditingController controller, {
  TwitchChannelPointsRuntimeSnapshot? points,
  bool sending = false,
  VoidCallback? identity,
  VoidCallback? emotes,
  VoidCallback? loyalty,
  VoidCallback? send,
}) => TwitchWatchChatInputSection(
  channelPoints: points,
  runtime: null,
  viewerIsFollowing: false,
  viewerFollowedAt: null,
  messageController: controller,
  loadingEmotes: false,
  compact: false,
  enabled: true,
  sending: sending,
  onOpenChannelPoints: loyalty ?? () {},
  onOpenEmotes: emotes ?? () {},
  onOpenSpecialActions: identity,
  onSend: send ?? () {},
);

void main() {
  for (final height in [390.0, 600.0]) {
    testWidgets(
      'VOD and live chat use one header with complete live toggles at $height',
      (tester) async {
        final runtime = TwitchVodChatReplayRuntime(
          api: TwitchVodCommentsApiService(
            client: TwitchApiClient(),
            badgeCache: TwitchBadgeCacheService(),
          ),
        );
        addTearDown(runtime.dispose);
        var pins = 0;
        var predictions = 0;
        await tester.pumpWidget(
          host(
            SizedBox(
              height: height,
              child: TwitchVodReplayChatPanel(
                runtime: runtime,
                liveChat: const SizedBox(),
                liveChatBuilder: (toggle) => Column(
                  children: [
                    TwitchWatchChatHeaderBar(
                      connected: true,
                      showPinned: true,
                      showPrediction: true,
                      predictionVisible: true,
                      hasPinned: true,
                      hasPrediction: true,
                      compact: height < 520,
                      onTogglePinned: () => pins++,
                      onTogglePrediction: () => predictions++,
                      onToggleMode: toggle,
                    ),
                    const Expanded(child: Text('live messages')),
                  ],
                ),
              ),
            ),
            width: 220,
            scale: 2,
          ),
        );
        await tester.pump();
        final header = find.byType(TwitchWatchChatHeaderBar);
        expect(header, findsOneWidget);
        final originalHeight = tester.getSize(header).height;
        expect(originalHeight, height < 520 ? 40 : 44);
        expect(find.text('VOD'), findsOneWidget);
        await tester.tap(find.byTooltip('切換到直播聊天室'));
        await tester.pump();
        expect(header, findsOneWidget);
        expect(tester.getSize(header).height, originalHeight);
        expect(find.text('live messages'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.push_pin_rounded));
        await tester.tap(find.byIcon(Icons.how_to_vote_rounded));
        expect(pins, 1);
        expect(predictions, 1);
        await tester.tap(find.byTooltip('切換到 VOD 聊天回放'));
        await tester.pump();
        expect(find.text('VOD'), findsOneWidget);
        expect(find.text('live messages'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final width in [220.0, 280.0, 320.0, 768.0]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('composer $width px, ${scale}x text', (tester) async {
        final controller = TextEditingController();
        await tester.pumpWidget(
          host(
            composer(controller, points: LargeBalance(), identity: () {}),
            width: width,
            scale: scale,
            keyboard: width < 400 ? 280 : 0,
          ),
        );
        expect(tester.takeException(), isNull);
        final points = find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message?.startsWith('忠誠點數') ?? false),
        );
        final emotes = find.byTooltip('貼圖');
        final identity = find.byTooltip('聊天身分與互動');
        final send = find.byIcon(Icons.send_rounded);
        expect(
          tester.getCenter(points).dx,
          lessThan(tester.getCenter(emotes).dx),
        );
        expect(
          tester.getCenter(emotes).dx,
          lessThan(tester.getCenter(identity).dx),
        );
        expect(
          tester.getCenter(identity).dx,
          lessThan(tester.getCenter(send).dx),
        );
        expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
        expect(find.byIcon(Icons.badge_outlined), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      });
    }
  }
  testWidgets('all four actions retain their callbacks', (tester) async {
    final controller = TextEditingController(text: 'hello');
    final actions = <String>[];
    await tester.pumpWidget(
      host(
        composer(
          controller,
          loyalty: () => actions.add('points'),
          emotes: () => actions.add('emotes'),
          identity: () => actions.add('identity'),
          send: () => actions.add('send'),
        ),
      ),
    );
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message?.startsWith('忠誠點數') ?? false),
      ),
    );
    await tester.tap(find.byTooltip('貼圖'));
    await tester.tap(find.byTooltip('聊天身分與互動'));
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(actions, ['points', 'emotes', 'identity', 'send']);
    expect(controller.text, 'hello');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('empty message does not send; absent identity is disabled', (
    tester,
  ) async {
    final controller = TextEditingController(text: '  ');
    var calls = 0;
    await tester.pumpWidget(host(composer(controller, send: () => calls++)));
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(calls, 0);
    final identity = tester.widget<TextButton>(
      find.ancestor(
        of: find.byIcon(Icons.badge_outlined),
        matching: find.byType(TextButton),
      ),
    );
    expect(identity.onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('sending disables send, not emotes or identity', (tester) async {
    final controller = TextEditingController(text: 'hello');
    var calls = 0;
    await tester.pumpWidget(
      host(
        composer(
          controller,
          sending: true,
          identity: () => calls++,
          send: () => calls += 10,
        ),
      ),
    );
    await tester.tap(find.byTooltip('聊天身分與互動'));
    await tester.pump();
    expect(calls, 1);
    expect(find.byIcon(Icons.send_rounded), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  for (final compact in [true, false]) {
    testWidgets('header height and toggles: compact=$compact', (tester) async {
      var pins = 0;
      var predictions = 0;
      await tester.pumpWidget(
        host(
          TwitchWatchChatHeaderBar(
            connected: true,
            showPinned: true,
            showPrediction: true,
            predictionVisible: true,
            hasPinned: true,
            hasPrediction: true,
            compact: compact,
            onTogglePinned: () => pins++,
            onTogglePrediction: () => predictions++,
          ),
          width: 220,
          scale: 2,
        ),
      );
      expect(
        tester.getSize(find.byType(TwitchWatchChatHeaderBar)).height,
        compact ? 40 : 44,
      );
      expect(
        tester.getSize(find.byTooltip('隱藏置頂留言')).height,
        inInclusiveRange(39, 40),
      ); // Compact header includes a 1px divider.
      await tester.tap(find.byIcon(Icons.push_pin_rounded));
      await tester.tap(find.byIcon(Icons.how_to_vote_rounded));
      expect(pins, 1);
      expect(predictions, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('unavailable header actions cannot toggle', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        TwitchWatchChatHeaderBar(
          connected: false,
          showPinned: false,
          showPrediction: false,
          predictionVisible: false,
          hasPinned: false,
          hasPrediction: false,
          compact: false,
          onTogglePinned: () => calls++,
          onTogglePrediction: () => calls++,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.push_pin_rounded));
    await tester.tap(find.byIcon(Icons.how_to_vote_rounded));
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
  });
  test('layout accounts for actual header and composer heights', () {
    final normal = TwitchWatchChatLayoutMetrics.resolve(
      constraints: const BoxConstraints(maxWidth: 320, maxHeight: 600),
      media: const MediaQueryData(size: Size(320, 600)),
    );
    expect(normal.hideOptionalEngagement, isFalse);
    final keyboard = TwitchWatchChatLayoutMetrics.resolve(
      constraints: const BoxConstraints(maxWidth: 220, maxHeight: 250),
      media: const MediaQueryData(
        size: Size(220, 600),
        viewInsets: EdgeInsets.only(bottom: 280),
      ),
    );
    expect(keyboard.hideOptionalEngagement, isTrue);
  });
  testWidgets('shared input remains compatible without trailing action', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      host(
        TwitchChatInputBar(
          controller: controller,
          enabled: true,
          sending: false,
          onSend: () {},
        ),
        width: 220,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
