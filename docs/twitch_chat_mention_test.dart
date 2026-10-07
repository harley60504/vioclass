// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/models/chat/twitch_chat_render_segment.dart';
import '../lib/features/twitch/presentation/widgets/chat/message/twitch_chat_mention.dart';
import '../lib/features/twitch/presentation/widgets/chat/message/twitch_chat_message_segments.dart';
import '../lib/features/twitch/presentation/widgets/chat/message/twitch_chat_message_visual_metrics.dart';

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('Mentions use icons and distinguish viewer at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchChatMentionScope(
              viewerLogin: 'Viewer',
              child: Builder(
                builder: (context) => Text.rich(
                  TextSpan(
                    children: buildTwitchChatMessageSegmentSpans(
                      context: context,
                      segments: const [
                        TwitchChatRenderSegment(
                          type: TwitchChatRenderSegmentType.text,
                          content:
                              'hello @peer and @VIEWER! email test@domain.com',
                        ),
                      ],
                      thirdPartyEmotes: null,
                      officialEmotes: null,
                      metrics: const TwitchChatMessageVisualMetrics(1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('peer'), findsOneWidget);
      expect(find.text('VIEWER'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byIcon(Icons.person_pin_circle_outlined), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('peer')).style!.color,
        isNot(tester.widget<Text>(find.text('VIEWER')).style!.color),
      );
      expect(find.text('domain'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
