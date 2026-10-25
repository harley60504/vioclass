import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/models/chat/twitch_chat_message.dart';
import 'package:vioclass/features/twitch/models/chat/twitch_chat_message_metadata.dart';
import 'package:vioclass/features/twitch/models/chat/twitch_chat_runtime_message.dart';
import 'package:vioclass/features/twitch/presentation/theme/twitch_ui_tokens.dart';
import 'package:vioclass/features/twitch/presentation/widgets/chat/twitch_runtime_message_tile.dart';
import 'package:vioclass/features/twitch/presentation/widgets/chat/message/twitch_chat_message_user_style.dart';

void main() {
  for (final source in [
    TwitchChatMessageSource.liveIrc,
    TwitchChatMessageSource.recentObject,
  ]) {
    testWidgets('Black name is rendered readably in chat: $source', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final raw = TwitchChatMessage.synthetic(
        channelLogin: 'fixture',
        userLogin: 'blackname',
        displayName: 'BlackName',
        message: 'Black username readability test',
        tags: const {'color': '#000000'},
        source: source,
      );
      final message = TwitchChatRuntimeMessage(
        source: raw,
        resolvedBadges: const [],
        receivedAt: DateTime(2026),
        fragments: const [],
        segments: const [],
        metadata: TwitchChatMessageMetadata.fromMessage(raw),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: TwitchUiColors.surfaceRaised,
            body: TwitchRuntimeMessageTile(message: message),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final names = <TextSpan>[];
      void collect(InlineSpan span) {
        if (span is TextSpan) {
          if (span.text == 'BlackName') names.add(span);
          for (final child in span.children ?? <InlineSpan>[]) {
            collect(child);
          }
        }
      }

      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        collect(rich.text);
      }
      expect(names, hasLength(1));
      final rendered = names.single.style!.color!;
      expect(rendered, isNot(Colors.black));
      expect(
        (rendered.computeLuminance() + .05) /
            (TwitchUiColors.surfaceRaised.computeLuminance() + .05),
        greaterThanOrEqualTo(4.5),
      );
      expect(message.color, '#000000');
      expect(tester.takeException(), isNull);
    });
  }
  test('Dark Twitch names remain readable on dark chat surfaces', () {
    for (final hex in ['#000000', '#000080', '#800000', '#008000', '#0000FF']) {
      final source = parseTwitchChatUserColor(hex)!;
      final adjusted = parseTwitchChatUserColorOrFallback(
        color: hex,
        login: 'viewer',
      );
      final contrast =
          (adjusted.computeLuminance() + .05) /
          (TwitchUiColors.surfaceRaised.computeLuminance() + .05);
      expect(contrast, greaterThanOrEqualTo(4.5), reason: hex);
      if (HSLColor.fromColor(source).saturation > 0) {
        expect(
          HSLColor.fromColor(adjusted).hue,
          closeTo(HSLColor.fromColor(source).hue, 1),
        );
      }
      expect(parseTwitchChatUserColor(hex), source);
    }
  });

  test(
    'Readable colors are preserved and missing colors use readable fallback',
    () {
      const white = Color(0xFFFFFFFF);
      expect(readableTwitchChatUserColor(white), white);
      for (var index = 0; index < 50; index++) {
        final color = parseTwitchChatUserColorOrFallback(
          color: '',
          login: 'viewer$index',
        );
        expect(
          (color.computeLuminance() + .05) /
              (TwitchUiColors.surfaceRaised.computeLuminance() + .05),
          greaterThanOrEqualTo(4.5),
        );
      }
    },
  );
}
