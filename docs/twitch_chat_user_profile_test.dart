// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/chat/twitch_chat_user_profile_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/models/channel/twitch_user.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message.dart';
import '../lib/features/twitch/models/chat/twitch_chat_badge.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message_metadata.dart';
import '../lib/features/twitch/models/chat/twitch_chat_runtime_message.dart';
import '../lib/features/twitch/presentation/sheets/twitch_chat_user_profile_sheet.dart';
import '../lib/features/twitch/presentation/sheets/twitch_chat_message_context_sheet.dart';
import '../lib/features/twitch/presentation/widgets/chat/twitch_chat_message_list.dart';
import '../lib/features/twitch/presentation/widgets/chat/twitch_runtime_message_tile.dart';
import '../lib/features/twitch/presentation/sheets/chat_message_context/twitch_reply_thread_card.dart';

TwitchChatRuntimeMessage message(
  String id, {
  String userId = '30',
  String login = 'peer',
  String channel = 'test',
  String room = '20',
  String? parentId,
  List<TwitchChatBadge> badges = const [],
}) {
  final raw = TwitchChatMessage(
    raw: '',
    command: 'PRIVMSG',
    channel: channel,
    userLogin: login,
    displayName: login,
    message: 'body $id',
    tags: {
      'id': id,
      'user-id': userId,
      'room-id': room,
      'reply-parent-msg-id': ?parentId,
    },
  );
  return TwitchChatRuntimeMessage(
    source: raw,
    resolvedBadges: badges,
    receivedAt: DateTime.utc(2026),
    fragments: const [],
    segments: const [],
    metadata: TwitchChatMessageMetadata.fromMessage(raw),
  );
}

const profile = TwitchUser(
  id: '30',
  login: 'peer',
  displayName: 'Peer official',
  description: 'Official bio',
);

class Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String owner = '10';
  String targetId = '30';
  void Function()? onValidate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final validate = options.uri.path.endsWith('/validate');
    if (validate) onValidate?.call();
    return ResponseBody.fromString(
      jsonEncode(
        validate
            ? {
                'client_id': 'matched-client',
                'user_id': owner,
                'login': 'viewer',
                'scopes': [],
                'expires_in': 100,
              }
            : {
                'data': [
                  {
                    'id': targetId,
                    'login': 'peer',
                    'display_name': 'Peer official',
                    'description': 'Official bio',
                  },
                ],
              },
      ),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('Icon badges beside whisper show names only on tap at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchChatUserProfileCard(
              message: message(
                'badges',
                badges: [
                  for (final title in ['Moderator', 'Chat Bot', 'Subscriber'])
                    TwitchChatBadge(
                      id: title,
                      setId: title,
                      version: '1',
                      title: title,
                      image1x: '',
                      image2x: '',
                      image4x: '',
                      clickAction: '',
                      clickUrl: '',
                    ),
                ],
              ),
              messages: const [],
              canWhisper: true,
              loadUser: () async => profile,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('這則訊息的 Twitch 徽章'), findsNothing);
      final row = find.byKey(const ValueKey('profile-actions-and-badges'));
      expect(find.descendant(of: row, matching: find.text('私訊')), findsNothing);
      expect(
        find.descendant(of: row, matching: find.byType(IconButton)),
        findsNWidgets(3),
      );
      final button = tester.getRect(find.text('私訊'));
      expect(find.text('Moderator'), findsNothing);
      expect(find.text('Chat Bot'), findsNothing);
      expect(find.text('Subscriber'), findsNothing);
      final badge = find.byKey(const ValueKey('profile-badge-Moderator-1'));
      final first = tester.getRect(badge);
      expect(
        first.top,
        greaterThan(tester.getRect(find.text('Official bio')).bottom),
      );
      final last = tester.getRect(
        find.byKey(const ValueKey('profile-badge-Subscriber-1')),
      );
      final identity = tester.getRect(find.text('@peer'));
      expect(last.center.dy, closeTo(first.center.dy, 2));
      expect(button.left, greaterThan(identity.right));
      expect(button.center.dy, lessThan(identity.bottom));
      await tester.tap(badge);
      await tester.pumpAndSettle();
      expect(find.text('Moderator'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Peer official'), findsOneWidget);
      expect(find.text('Official bio'), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('profile-badge-preview'))),
        const Size(96, 96),
      );
      await tester.tap(find.byTooltip('下一個徽章'));
      await tester.pumpAndSettle();
      expect(find.text('Chat Bot'), findsOneWidget);
      await tester.tap(find.byTooltip('上一個徽章'));
      await tester.pumpAndSettle();
      expect(find.text('Moderator'), findsOneWidget);
      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();
      expect(find.text('Moderator'), findsNothing);
      expect(find.text('Official bio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final history in [false, true]) {
    testWidgets(
      'Compact ${history ? "history" : "thread"} copies original message',
      (tester) async {
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
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TwitchChatUserProfileCard(
                message: message('copy'),
                messages: [message('copy')],
                canWhisper: false,
                loadUser: () async => profile,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (history) {
          await tester.tap(find.text('個人聊天紀錄'));
          await tester.pumpAndSettle();
        }
        expect(find.byType(TwitchReplyThreadMessageCard), findsNothing);
        final tile = find.byType(TwitchRuntimeMessageTile);
        expect(tile, findsOneWidget);
        expect(
          tester.widget<TwitchRuntimeMessageTile>(tile).showTimestamp,
          true,
        );
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(copied, 'peer: body copy');
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Shared profile defaults to thread and switches history in place',
    (tester) async {
      var loads = 0;
      final root = message('root', userId: '40', login: 'other');
      final selected = message('reply', parentId: 'root');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchChatUserProfileCard(
              message: selected,
              messages: [root, selected, message('unrelated')],
              canWhisper: true,
              loadUser: () async {
                loads++;
                return profile;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('聊天串'), findsOneWidget);
      expect(find.textContaining('聊天串 ·'), findsNothing);
      expect(find.text('Peer official'), findsOneWidget);
      expect(find.textContaining('本機聊天紀錄'), findsNothing);
      await tester.tap(find.text('個人聊天紀錄'));
      await tester.pumpAndSettle();
      expect(find.text('本機聊天紀錄 · 2'), findsOneWidget);
      expect(find.text('Peer official'), findsOneWidget);
      expect(loads, 1);
      await tester.tap(find.text('聊天串'));
      await tester.pumpAndSettle();
      expect(find.textContaining('本機聊天紀錄'), findsNothing);
      expect(loads, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('name opens user directly without also opening message context', (
    tester,
  ) async {
    var profiles = 0;
    var contexts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchChatMessageFeed(
            messages: [message('a')],
            onOpenUser: (_) => profiles++,
            onOpenMessageContext: (_) => contexts++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final text = find
        .byType(RichText)
        .evaluate()
        .where(
          (e) => (e.widget as RichText).text.toPlainText().startsWith('peer:'),
        )
        .single;
    final paragraph = text.renderObject! as RenderParagraph;
    final nameBox = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 4),
        )
        .first;
    await tester.tapAt(paragraph.localToGlobal(nameBox.toRect().center));
    await tester.pumpAndSettle();
    expect(profiles, 1);
    expect(contexts, 0);
    final bodyBox = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 6, extentOffset: 9),
        )
        .first;
    await tester.tapAt(paragraph.localToGlobal(bodyBox.toRect().center));
    await tester.pumpAndSettle();
    expect(contexts, 1);
    expect(profiles, 1);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(tester.takeException(), isNull);
  });
  test(
    'local history is ID-bound, room-bound, deduplicated and includes selection',
    () {
      final selected = message('a');
      final history = twitchChatUserLocalHistory(selected, [
        selected,
        message('b'),
        message('c', userId: '99'),
        message('d', channel: 'other'),
        message('e', room: '77'),
        message('f', userId: '30', login: 'old_name'),
      ]);
      expect(history.map((m) => m.id), ['a', 'b', 'f']);
    },
  );
  test(
    'profile uses official ID and validated client, not a fixed OAuth client',
    () async {
      final adapter = Adapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = TwitchApiClient(dio: dio);
      addTearDown(client.close);
      final api = TwitchChatUserProfileApiService(
        client: client,
        tokenProviders: [() async => 'fake-token'],
        ownerId: '10',
        isCurrent: () => true,
      );
      final user = await api.getUser(login: 'old_name', userId: '30');
      expect(user?.displayName, 'Peer official');
      final request = adapter.requests.last;
      expect(request.method, 'GET');
      expect(request.queryParameters, {'id': '30'});
      expect(request.headers['Client-ID'], 'matched-client');
      expect(request.headers['Authorization'], 'Bearer fake-token');
    },
  );
  test(
    'different account and changed viewing context never request profiles',
    () async {
      final adapter = Adapter()..owner = '99';
      final client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
      addTearDown(client.close);
      var current = true;
      final api = TwitchChatUserProfileApiService(
        client: client,
        tokenProviders: [() async => 'fake-token'],
        ownerId: '10',
        isCurrent: () => current,
      );
      await expectLater(
        api.getUser(login: 'peer'),
        throwsA(isA<TwitchChatUserProfileException>()),
      );
      expect(
        adapter.requests.where((r) => r.uri.path.endsWith('/users')),
        isEmpty,
      );
      adapter.owner = '10';
      adapter.onValidate = () => current = false;
      await expectLater(
        api.getUser(login: 'peer'),
        throwsA(isA<TwitchChatUserProfileException>()),
      );
      expect(
        adapter.requests.where((r) => r.uri.path.endsWith('/users')),
        isEmpty,
      );
    },
  );
  test('mismatched official response is rejected', () async {
    final adapter = Adapter()..targetId = '99';
    final client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
    addTearDown(client.close);
    final api = TwitchChatUserProfileApiService(
      client: client,
      tokenProviders: [() async => 'fake-token'],
      ownerId: '10',
      isCurrent: () => true,
    );
    await expectLater(
      api.getUser(login: 'peer', userId: '30'),
      throwsA(isA<TwitchChatUserProfileException>()),
    );
  });
  testWidgets('context retains reply thread and opens the selected identity', (
    tester,
  ) async {
    TwitchChatRuntimeMessage? opened;
    final selected = message('a');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showTwitchChatMessageContextSheet(
                context: context,
                selectedMessage: selected,
                messages: [selected],
                onOpenUser: (m) async => opened = m,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('回覆串'), findsOneWidget);
    await tester.tap(find.text('使用者資料'));
    await tester.pumpAndSettle();
    expect(opened, same(selected));
    expect(find.textContaining('回覆串'), findsOneWidget);
  });
  testWidgets(
    'official failure leaves local history available and retry recovers',
    (tester) async {
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchChatUserProfileCard(
              message: message('a'),
              messages: [message('b')],
              canWhisper: false,
              loadUser: () async {
                if (fail) throw StateError('fake');
                return profile;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('官方使用者資料暫時'), findsOneWidget);
      expect(find.text('聊天串'), findsOneWidget);
      expect(find.text('本機聊天紀錄 · 2'), findsNothing);
      await tester.tap(find.text('個人聊天紀錄'));
      await tester.pumpAndSettle();
      expect(find.text('本機聊天紀錄 · 2'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      fail = false;
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      expect(find.text('Peer official'), findsOneWidget);
      expect(find.text('Official bio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1200, 800),
  ]) {
    testWidgets(
      'profile is scrollable at $size and whisper closes only after explicit choice',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showTwitchChatUserProfileSheet(
                      context: context,
                      message: message('a'),
                      messages: List.generate(20, (i) => message('$i')),
                      canWhisper: true,
                      loadUser: () async => profile,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        await tester.ensureVisible(find.text('私訊'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('私訊'));
        await tester.pumpAndSettle();
        expect(result, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'closing while official data is pending does not update a disposed card',
    (tester) async {
      final pending = Completer<TwitchUser?>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchChatUserProfileCard(
              message: message('a'),
              messages: const [],
              canWhisper: false,
              loadUser: () => pending.future,
            ),
          ),
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      pending.complete(profile);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
