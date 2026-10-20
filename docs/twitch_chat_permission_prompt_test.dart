import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/presentation/localization/vioclass_localizations.dart';
import 'package:vioclass/features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_input_section.dart';

void main() {
  for (final english in [false, true]) {
    for (final status in ['checking', 'guest', 'missing', 'authenticated']) {
      testWidgets('Chat permission prompt status=$status english=$english', (
        tester,
      ) async {
        final draft = TextEditingController(text: 'fixture draft');
        addTearDown(draft.dispose);
        var logins = 0;
        var sends = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: english ? const Locale('en') : null,
            localizationsDelegates: english
                ? const [VioClassLocalizations.delegate]
                : null,
            home: Scaffold(
              body: TwitchWatchChatInputSection(
                channelPoints: null,
                runtime: null,
                viewerIsFollowing: false,
                viewerFollowedAt: null,
                messageController: draft,
                loadingEmotes: false,
                compact: false,
                enabled: status == 'authenticated',
                sending: false,
                readOnlyGuest: status == 'guest',
                missingSendPermission: status == 'missing',
                onOpenChannelPoints: () {},
                onOpenEmotes: () {},
                onLoginPressed: () => logins++,
                onSend: () => sends++,
              ),
            ),
          ),
        );
        expect(logins, 0);
        if (status == 'guest' || status == 'missing') {
          final label = status == 'guest'
              ? (english ? 'Sign in' : '登入')
              : (english ? 'Authorize again' : '重新授權');
          expect(find.byType(TwitchChatInputBar), findsNothing);
          if (status == 'missing') {
            expect(
              find.text(
                english
                    ? 'You are signed in, but lack permission to send chat messages. Please authorize again.'
                    : '已登入，但缺少聊天室發言權限。請重新授權後再發言。',
              ),
              findsOneWidget,
            );
          } else {
            expect(
              find.text(
                english
                    ? 'Guests can read chat. Sign in to send messages and use channel points.'
                    : '訪客模式可讀取聊天室；登入後才能發言與使用點數。',
              ),
              findsOneWidget,
            );
          }
          await tester.tap(find.text(label));
          await tester.pump();
          expect(logins, 1);
          expect(sends, 0);
        } else {
          expect(find.byType(TwitchChatInputBar), findsOneWidget);
          expect(find.text(english ? 'Authorize again' : '重新授權'), findsNothing);
          expect(
            tester
                .widget<TwitchChatInputBar>(find.byType(TwitchChatInputBar))
                .enabled,
            status == 'authenticated',
          );
          expect(logins, 0);
        }
        expect(draft.text, 'fixture draft');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
