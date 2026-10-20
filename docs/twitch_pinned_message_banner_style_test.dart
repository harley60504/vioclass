// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/models/engagement/twitch_pinned_chat.dart';
import '../lib/features/twitch/presentation/widgets/chat/cards/twitch_pinned_message_banner.dart';
import '../lib/features/twitch/presentation/widgets/shared/twitch_ui_avatar.dart';

const _message = TwitchPinnedChatMessage(
  pinId: 'fixture-pin',
  type: 'MOD',
  messageId: 'fixture-message',
  text:
      '這是假的置頂留言，用來確認窄畫面文字換行與展開收合，不會對帳號寫入。'
      '這是假的置頂留言，用來確認窄畫面文字換行與展開收合，不會對帳號寫入。',
  sender: TwitchPinnedChatUser(
    id: 'fixture-sender',
    displayName: '很長的測試使用者名稱',
    chatColor: '#12AB34',
  ),
  pinnedBy: TwitchPinnedChatUser(
    id: 'fixture-moderator',
    displayName: '很長的測試管理員名稱',
  ),
);

Future<void> _mount(WidgetTester tester, double width, double scale) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: TwitchPinnedMessageBanner(
              message: _message,
              fontScale: scale,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _body => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText() == _message.text,
);

void main() {
  for (final width in [240.0, 600.0]) {
    for (final scale in [0.82, 1.36]) {
      testWidgets('pinned style and expand width=$width scale=$scale', (
        tester,
      ) async {
        await _mount(tester, width, scale);
        final ink = tester.widget<Ink>(
          find.descendant(
            of: find.byType(TwitchPinnedMessageBanner),
            matching: find.byType(Ink),
          ),
        );
        final decoration = ink.decoration! as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(18));
        expect(
          decoration.border,
          Border.all(color: Colors.white.withValues(alpha: 0.09)),
        );
        expect((decoration.gradient! as LinearGradient).colors, [
          const Color(0xFF242031).withValues(alpha: 0.85),
          const Color(0xFF17171E).withValues(alpha: 0.90),
        ]);
        expect(decoration.boxShadow, hasLength(2));
        final pin = find.byIcon(Icons.push_pin_rounded);
        expect(tester.widget<Icon>(pin).size, 15);
        final pinBox = tester.widget<Container>(
          find.ancestor(of: pin, matching: find.byType(Container)).first,
        );
        expect(pinBox.constraints!.maxWidth, 28);
        expect(pinBox.constraints!.maxHeight, 28);
        final avatar = find.byType(TwitchUiAvatar);
        expect(
          tester.getTopLeft(avatar).dy,
          greaterThan(tester.getBottomLeft(pin).dy),
        );
        expect(
          tester.getCenter(avatar).dx,
          closeTo(tester.getCenter(pin).dx, 0.1),
        );
        expect(
          tester.getTopLeft(pin).dx,
          lessThan(tester.getTopLeft(find.text('很長的測試使用者名稱')).dx),
        );
        final sender = tester.widget<Text>(find.text('很長的測試使用者名稱'));
        expect(sender.style!.color, const Color(0xFF12AB34));
        expect(sender.style!.fontWeight, FontWeight.w600);
        expect(tester.widget<RichText>(_body).maxLines, 2);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(TwitchPinnedMessageBanner));
        await tester.pumpAndSettle();
        expect(tester.widget<RichText>(_body).maxLines, 12);
        expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(TwitchPinnedMessageBanner));
        await tester.pumpAndSettle();
        expect(tester.widget<RichText>(_body).maxLines, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('long press retains copy through fake clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await _mount(tester, 320, 1);
    await tester.longPress(find.byType(TwitchPinnedMessageBanner));
    await tester.pumpAndSettle();
    expect(copied, _message.text);
    expect(tester.widget<RichText>(_body).maxLines, 2);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
  });
}
