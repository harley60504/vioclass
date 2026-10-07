// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/emotes/twitch_official_emote_api_service.dart';
import '../lib/features/twitch/api/emotes/twitch_third_party_emote_api_service.dart';
import '../lib/features/twitch/api/engagement/twitch_hype_train_api_service.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message_metadata.dart';
import '../lib/features/twitch/models/chat/twitch_chat_runtime_message.dart';
import '../lib/features/twitch/services/chat/twitch_chat_runtime.dart';
import '../lib/features/twitch/services/chat/twitch_official_emote_cache_service.dart';
import '../lib/features/twitch/services/chat/twitch_third_party_emote_cache_service.dart';
import '../lib/features/twitch/services/engagement/twitch_hype_train_controller.dart';
import '../lib/features/twitch/presentation/widgets/watch/twitch_watch_chat_panel.dart';
import '../lib/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_message_area.dart';
import '../lib/features/twitch/presentation/widgets/chat/twitch_chat_message_list.dart';
import '../lib/features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart';
import '../lib/features/twitch/presentation/widgets/shared/twitch_emote_picker_panel.dart';

class _Runtime extends ChangeNotifier implements TwitchChatRuntime {
  final List<TwitchChatRuntimeMessage> rows;
  _Runtime(this.rows);
  @override
  List<TwitchChatRuntimeMessage> get messages => rows;
  @override
  bool get connected => true;
  @override
  bool get viewerIsModerator => true;
  @override
  bool get viewerIsVip => false;
  @override
  bool get viewerIsSubscriber => false;
  @override
  TwitchChatRoomState get roomState => TwitchChatRoomState.fromTags({});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final configured in [true, false]) {
    testWidgets(
      'Watch panel forwards live callable gate: configured=$configured',
      (tester) async {
        // This docs fixture is executed by flutter test, not production code.
        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferences.setMockInitialValues({});
        var permitted = true;
        var gateReads = 0;
        final raw = TwitchChatMessage(
          raw: '',
          command: 'PRIVMSG',
          channel: 'fixture',
          userLogin: 'peer',
          displayName: 'Peer',
          message: 'fixture',
          tags: const {'id': 'official', 'user-id': '30'},
        );
        final message = TwitchChatRuntimeMessage(
          source: raw,
          resolvedBadges: const [],
          receivedAt: DateTime.utc(2026),
          fragments: const [],
          segments: const [],
          metadata: TwitchChatMessageMetadata.fromMessage(raw),
        );
        final runtime = _Runtime([message]);
        final client = TwitchApiClient();
        final official = TwitchOfficialEmoteCacheService(
          api: TwitchOfficialEmoteApiService(client: client),
          accessTokenProvider: () async => null,
          clientIdProvider: () async => null,
        );
        final thirdParty = TwitchThirdPartyEmoteCacheService(
          api: TwitchThirdPartyEmoteApiService(client: client),
        );
        final hype = TwitchHypeTrainController(
          api: const TwitchHypeTrainApiService(),
        );
        final composer = TextEditingController();
        final users = <TwitchChatRuntimeMessage>[];
        final api = TwitchModerationApiService(
          client: client,
          tokenProviders: const [],
          broadcasterId: '20',
          moderatorId: '10',
          canModerate: configured
              ? () {
                  gateReads++;
                  return permitted;
                }
              : null,
        );
        addTearDown(() {
          runtime.dispose();
          official.dispose();
          thirdParty.dispose();
          hype.dispose();
          composer.dispose();
          client.close();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TwitchWatchChatPanel(
                runtime: runtime,
                viewerLogin: 'fixture',
                viewerId: '10',
                viewerIsFollowing: false,
                viewerFollowedAt: null,
                thirdPartyEmoteCache: thirdParty,
                officialEmoteCache: official,
                emoteCount: 0,
                loadingEmotes: false,
                channelPoints: null,
                pinnedMessages: const [],
                prediction: null,
                hypeTrainController: hype,
                loadingEngagement: false,
                engagementError: null,
                messageController: composer,
                sending: false,
                onSend: () {},
                onOpenEmotes: () {},
                onRefreshEmotes: () {},
                onRefreshEngagement: () {},
                onOpenChannelPoints: () {},
                onOpenPrediction: () {},
                moderationApi: api,
                onOpenUser: (selected) async => users.add(selected),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final beforePicker = tester
            .getTopLeft(find.byType(TwitchChatInputBar))
            .dy;
        await tester.tap(find.byTooltip('貼圖'));
        await tester.pumpAndSettle();
        final picker = find.byKey(const ValueKey('chat-emote-panel'));
        expect(picker, findsOneWidget);
        expect(find.byType(TwitchEmotePickerPanel), findsOneWidget);
        final emojiCategory = find.byKey(
          const ValueKey('emote-category-emoji'),
        );
        final rail = find.byKey(const ValueKey('emote-category-sidebar'));
        await tester.scrollUntilVisible(
          emojiCategory,
          80,
          scrollable: find.descendant(
            of: rail,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(emojiCategory);
        await tester.pumpAndSettle();
        await tester.tap(find.text('😀'));
        await tester.pumpAndSettle();
        expect(composer.text, contains('😀'));
        expect(find.byType(GridView), findsNothing);
        expect(
          tester.getRect(picker).bottom,
          closeTo(tester.getRect(find.byType(TwitchWatchChatPanel)).bottom, 1),
        );
        expect(find.byType(Dialog), findsNothing);
        expect(
          tester.getTopLeft(find.byType(TwitchChatInputBar)).dy,
          lessThan(beforePicker),
        );
        expect(
          tester.getRect(find.byType(TwitchChatInputBar)).bottom,
          lessThanOrEqualTo(tester.getRect(picker).top),
        );
        await tester.tap(find.byTooltip('關閉貼圖'));
        await tester.pumpAndSettle();
        expect(picker, findsNothing);
        expect(tester.takeException(), isNull);
        tester.view.physicalSize = const Size(390, 260);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('貼圖'));
        await tester.pumpAndSettle();
        expect(picker, findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(picker).bottom,
          closeTo(tester.getRect(find.byType(TwitchWatchChatPanel)).bottom, 1),
        );
        await tester.tap(find.byTooltip('關閉貼圖'));
        await tester.pumpAndSettle();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.pumpAndSettle();
        final area = tester.widget<TwitchWatchChatMessageArea>(
          find.byType(TwitchWatchChatMessageArea),
        );
        final feed = tester.widget<TwitchChatMessageFeed>(
          find.byType(TwitchChatMessageFeed),
        );
        expect(area.canStartKeyboardModeration!(), configured);
        expect(feed.canStartKeyboardModeration!(), configured);
        final pane = tester
            .widget<Focus>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is Focus &&
                    widget.focusNode?.debugLabel == 'chat keyboard entry',
              ),
            )
            .focusNode!;
        expect(pane.canRequestFocus, configured);
        if (configured) {
          pane.requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
          await tester.pumpAndSettle();
          expect(users.single, same(message));
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pumpAndSettle();
          expect(find.text('確認管理操作'), findsOneWidget);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('關閉'));
          await tester.pumpAndSettle();
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pumpAndSettle();
          expect(find.text('確認管理操作'), findsOneWidget);
          // Original selected message disappears while its confirmation is open.
          runtime.rows.clear();
          await tester.tap(find.text('確認'));
          await tester.pumpAndSettle();
          expect(find.text('管理身分或頻道已變更，未送出操作。'), findsOneWidget);
          await tester.tap(find.text('關閉'));
          await tester.pumpAndSettle();
          runtime.rows.add(message);
          expect(gateReads, greaterThan(3));
          permitted = false;
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pumpAndSettle();
          expect(find.text('確認管理操作'), findsNothing);
          expect(area.canStartKeyboardModeration!(), isFalse);
          expect(feed.canStartKeyboardModeration!(), isFalse);
        } else {
          expect(gateReads, 0);
          expect(users, isEmpty);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
