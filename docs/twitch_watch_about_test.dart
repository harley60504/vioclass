import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/models/discovery/twitch_live_stream.dart';
import 'package:vioclass/features/twitch/models/discovery/twitch_stream_header_metadata.dart';
import 'package:vioclass/features/twitch/presentation/widgets/channel/twitch_channel_about_section.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/twitch_watch_responsive_body.dart';

void main() {
  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    testWidgets('Short About can be pulled back to the player on $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                platform: platform,
              ),
              child: TwitchWatchResponsiveBody(
                chatVisible: true,
                chatPanelWidth: 300,
                chatPanelRatio: .25,
                minChatPanelWidth: 200,
                maxEffectiveMinChatPanelWidth: 300,
                maxChatPanelWidth: 500,
                minChatPanelRatio: .2,
                minStoredChatPanelRatio: .15,
                maxChatPanelRatio: .5,
                player: const ColoredBox(
                  key: ValueKey('short-player'),
                  color: Colors.black,
                ),
                chat: const Text('chat'),
                belowPlayer: const SizedBox(
                  height: 60,
                  child: Text('short About'),
                ),
                onSetChatPanelWidthForViewport:
                    ({required viewportWidth, required value}) {},
                onPersistChatPanelWidth: () {},
              ),
            ),
          ),
        ),
      );
      final page = tester.widget<PageView>(find.byType(PageView)).controller!;
      page.jumpToPage(1);
      await tester.pumpAndSettle();
      final scroll = find.byType(SingleChildScrollView);
      expect(
        tester
            .state<ScrollableState>(
              find.descendant(of: scroll, matching: find.byType(Scrollable)),
            )
            .position
            .maxScrollExtent,
        0,
      );
      await tester.drag(scroll, const Offset(0, 180));
      await tester.pumpAndSettle();
      expect(page.page, 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Desktop wheel enters About without competing page scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchWatchResponsiveBody(
            chatVisible: true,
            chatPanelWidth: 300,
            chatPanelRatio: .25,
            minChatPanelWidth: 200,
            maxEffectiveMinChatPanelWidth: 300,
            maxChatPanelWidth: 500,
            minChatPanelRatio: .2,
            minStoredChatPanelRatio: .15,
            maxChatPanelRatio: .5,
            player: const ColoredBox(
              key: ValueKey('player'),
              color: Colors.black,
            ),
            chat: const Text('chat'),
            belowPlayer: Column(
              children: [
                for (var i = 0; i < 80; i++)
                  SizedBox(height: 45, child: Text('about line $i')),
              ],
            ),
            onSetChatPanelWidthForViewport:
                ({required viewportWidth, required value}) {},
            onPersistChatPanelWidth: () {},
          ),
        ),
      ),
    );
    final position = tester.getCenter(find.byKey(const ValueKey('player')));
    for (var i = 0; i < 8; i++) {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: position,
          scrollDelta: const Offset(0, 60),
        ),
      );
      await tester.pump(const Duration(milliseconds: 25));
    }
    await tester.pumpAndSettle();
    final page = tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(page.page, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(page.page, 1, reason: 'No snap back after the wheel burst');
    final about = find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    final scroll = tester.state<ScrollableState>(about).position;
    final before = scroll.pixels;
    await tester.sendEventToBinding(
      PointerScrollEvent(position: position, scrollDelta: const Offset(0, 180)),
    );
    await tester.pumpAndSettle();
    expect(scroll.pixels, greaterThan(before));
    expect(page.page, 1);
    scroll.jumpTo(0);
    await tester.pump();
    await tester.sendEventToBinding(
      PointerScrollEvent(position: position, scrollDelta: const Offset(0, -90)),
    );
    await tester.pumpAndSettle();
    expect(page.page, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('About retains panel titles and the entire long description', (
    tester,
  ) async {
    final description = List.generate(
      120,
      (index) => 'Paragraph $index: full channel information.',
    ).join('\n');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TwitchChannelAboutSection(
              metadata: const TwitchStreamHeaderMetadata(
                channelLogin: 'fixture',
              ),
              panels: [
                TwitchChannelPanel(
                  id: 'text',
                  type: 'default',
                  title: 'Panel title',
                  description: description,
                  imageUrl: '',
                  linkUrl: '',
                ),
              ],
              socialLinks: const [],
              loading: false,
              errorText: null,
              onRetry: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Panel title'), findsOneWidget);
    expect(find.text(description), findsOneWidget);
    expect(
      find.byType(AspectRatio),
      findsNothing,
      reason: 'Text-only panels need no empty image placeholder',
    );
    final text = tester.widget<Text>(find.text(description));
    expect(text.maxLines, isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -12000),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
