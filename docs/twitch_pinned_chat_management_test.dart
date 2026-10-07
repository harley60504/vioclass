// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message.dart';
import '../lib/features/twitch/models/chat/twitch_chat_runtime_message.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message_metadata.dart';
import '../lib/features/twitch/models/engagement/twitch_pinned_chat.dart';
import '../lib/features/twitch/presentation/sheets/twitch_pinned_chat_management_sheet.dart';
import '../lib/features/twitch/presentation/watch/controllers/twitch_watch_engagement_controller.dart';

const pin = TwitchPinnedChatMessage(
  pinId: 'old',
  type: 'MOD',
  messageId: 'old',
  text: 'old pin',
);
TwitchChatRuntimeMessage message({
  String room = '20',
  TwitchChatMessageSource source = TwitchChatMessageSource.liveIrc,
}) {
  final raw = TwitchChatMessage(
    raw: '',
    command: 'PRIVMSG',
    channel: 'channel',
    userLogin: 'peer',
    displayName: 'Peer',
    message: 'new pin',
    source: source,
    tags: {'id': 'selected', 'room-id': room, 'user-id': '30'},
  );
  return TwitchChatRuntimeMessage(
    source: raw,
    resolvedBadges: const [],
    receivedAt: DateTime.utc(2026),
    fragments: const [],
    segments: const [],
    metadata: TwitchChatMessageMetadata.fromMessage(raw),
  );
}

class Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  List<String> scopes = ['moderator:manage:chat_messages'];
  String owner = '10';
  int status = 204;
  bool foreign = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path.endsWith('/validate')) {
      return ResponseBody.fromString(
        jsonEncode({
          'client_id': 'matched-client',
          'user_id': owner,
          'login': 'viewer',
          'scopes': scopes,
          'expires_in': 1000,
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    requests.add(options);
    return ResponseBody.fromString(
      options.method == 'GET'
          ? jsonEncode({
              'data': [
                {
                  'message_id': 'old',
                  'broadcaster_id': foreign ? '99' : '20',
                  'sender_user_id': '30',
                  'sender_user_login': 'peer',
                  'sender_user_name': 'Peer',
                  'pinned_by_user_id': '10',
                  'pinned_by_user_login': 'viewer',
                  'pinned_by_user_name': 'Viewer',
                  'message': {'text': 'old pin', 'fragments': []},
                  'starts_at': '2026-10-03T00:00:00Z',
                  'ends_at': null,
                },
              ],
            })
          : '',
      options.method == 'GET' ? 200 : status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeApi extends TwitchModerationApiService {
  List<TwitchPinnedChatMessage> pins = [pin];
  int reads = 0;
  bool replaceOnPreflight = false;
  bool failRead = false;
  final writes = <String>[];
  FakeApi(bool Function() permission)
    : super(
        client: TwitchApiClient(),
        tokenProviders: const [],
        broadcasterId: '20',
        moderatorId: '10',
        canModerate: permission,
      );
  @override
  Future<List<TwitchPinnedChatMessage>> pinnedMessages() async {
    reads++;
    if (failRead) throw const TwitchModerationException('fake read failure');
    if (replaceOnPreflight && reads > 1) {
      return const [
        TwitchPinnedChatMessage(
          pinId: 'changed',
          type: 'MOD',
          messageId: 'changed',
          text: 'someone else',
        ),
      ];
    }
    return List.of(pins);
  }

  @override
  Future<void> pinMessage(
    String id, {
    int? seconds,
    bool update = false,
  }) async {
    writes.add('$id:$seconds:$update');
    pins = [
      TwitchPinnedChatMessage(pinId: id, type: 'MOD', messageId: id, text: id),
    ];
  }

  @override
  Future<void> unpinMessage(String id) async {
    writes.add('unpin:$id');
    pins = [];
  }
}

class Port {
  dynamic get services => null;
}

void main() {
  test(
    'official pins use GET/PUT/PATCH/DELETE query parameters and matched Client-ID',
    () async {
      final adapter = Adapter();
      final client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
      addTearDown(client.close);
      List<TwitchPinnedChatMessage>? published;
      final api = TwitchModerationApiService(
        client: client,
        tokenProviders: [() async => 'fake'],
        broadcasterId: '20',
        moderatorId: '10',
        onPinsLoaded: (pins) => published = pins,
      );
      final result = await api.pinnedMessages();
      expect(result.single.sender?.displayName, 'Peer');
      expect(published?.single.messageId, 'old');
      await api.pinMessage('selected', seconds: 30);
      await api.pinMessage('selected', seconds: 1800, update: true);
      await api.pinMessage('selected');
      await api.unpinMessage('selected');
      expect(adapter.requests.map((r) => r.method), [
        'GET',
        'PUT',
        'PATCH',
        'PUT',
        'DELETE',
      ]);
      expect(adapter.requests[1].queryParameters, {
        'broadcaster_id': '20',
        'moderator_id': '10',
        'message_id': 'selected',
        'duration_seconds': 30,
      });
      expect(
        adapter.requests[3].queryParameters.containsKey('duration_seconds'),
        false,
      );
      expect(
        adapter.requests.every(
          (r) => r.data == null && r.headers['Client-ID'] == 'matched-client',
        ),
        true,
      );
    },
  );
  test(
    'read-only scope, invalid duration/ID, wrong account and foreign reads never grant write access',
    () async {
      final adapter = Adapter();
      final client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
      addTearDown(client.close);
      final api = TwitchModerationApiService(
        client: client,
        tokenProviders: [() async => 'fake'],
        broadcasterId: '20',
        moderatorId: '10',
      );
      for (final seconds in [0, 29, 1801]) {
        await expectLater(
          api.pinMessage('selected', seconds: seconds),
          throwsA(isA<TwitchModerationException>()),
        );
      }
      await expectLater(
        api.pinMessage(' '),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests, isEmpty);
      adapter.scopes = ['moderator:read:chat_messages'];
      await api.pinnedMessages();
      await expectLater(
        api.pinMessage('selected'),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests.length, 1);
      adapter.owner = '99';
      await expectLater(
        api.pinnedMessages(),
        throwsA(isA<TwitchModerationException>()),
      );
      adapter.owner = '10';
      adapter.foreign = true;
      await expectLater(
        api.pinnedMessages(),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(twitchCanPinMessage(message(room: '99'), '20'), false);
      expect(
        twitchCanPinMessage(
          message(source: TwitchChatMessageSource.localEcho),
          '20',
        ),
        false,
      );
    },
  );
  test(
    'banner accepts only current channel official snapshots and releases on reset',
    () {
      final controller = TwitchWatchEngagementController(
        emotesPort: null,
        engagementPort: Port(),
        channelLogin: () => 'channel',
        channelId: () => '20',
        viewerId: () => '10',
        isCurrentWatchTask: (_, _) => true,
      );
      addTearDown(controller.dispose);
      controller.applyModerationPins('99', [pin]);
      expect(controller.pinnedMessages, isEmpty);
      controller.applyModerationPins('20', [pin]);
      expect(controller.pinnedMessages.single, same(pin));
      controller.reset();
      expect(controller.pinnedMessages, isEmpty);
    },
  );
  testWidgets(
    'pin validates duration, confirms replacement, cancellation does not send',
    (tester) async {
      final api = FakeApi(() => true);
      addTearDown(api.client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchPinnedChatManagementPanel(
              api: api,
              channelName: 'channel',
              selectedMessage: message(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '29');
      await tester.tap(find.text('釘選這則訊息'));
      await tester.pumpAndSettle();
      expect(api.writes, isEmpty);
      expect(find.text('請輸入範圍內的整數。'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '60');
      await tester.tap(find.text('釘選這則訊息'));
      await tester.pumpAndSettle();
      expect(find.textContaining('新增會取代'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(api.writes, isEmpty);
      await tester.tap(find.text('釘選這則訊息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.writes, ['selected:60:false']);
    },
  );
  testWidgets(
    'update until stream ends and unpin target exact loaded message',
    (tester) async {
      final api = FakeApi(() => true);
      addTearDown(api.client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchPinnedChatManagementPanel(
              api: api,
              channelName: 'channel',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('調整釘選時間'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.writes, ['old:null:true']);
      await tester.tap(find.text('解除釘選'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.writes, ['old:null:true', 'unpin:old']);
      expect(find.text('目前沒有管理員釘選訊息。'), findsOneWidget);
    },
  );
  testWidgets(
    'another moderator replacing pin during confirmation prevents stale write',
    (tester) async {
      final api = FakeApi(() => true)..replaceOnPreflight = true;
      addTearDown(api.client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchPinnedChatManagementPanel(
              api: api,
              channelName: 'channel',
              selectedMessage: message(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('釘選這則訊息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.writes, isEmpty);
      expect(find.text('釘選訊息已變更，請重新確認後再操作。'), findsOneWidget);
    },
  );
  testWidgets('lost role and unavailable current state do not silently unpin', (
    tester,
  ) async {
    var allowed = true;
    final api = FakeApi(() => allowed);
    addTearDown(api.client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchPinnedChatManagementPanel(
            api: api,
            channelName: 'channel',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('解除釘選'));
    await tester.pumpAndSettle();
    allowed = false;
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();
    expect(api.writes, isEmpty);
    allowed = true;
    api.failRead = true;
    await tester.tap(find.text('重新整理'));
    await tester.pumpAndSettle();
    expect(find.text('釘選狀態未確認，請重新整理。'), findsOneWidget);
    expect(find.text('目前沒有管理員釘選訊息。'), findsNothing);
  });
  testWidgets('phone keyboard and enlarged text keep pin controls scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeApi(() => true);
    addTearDown(api.client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            viewInsets: EdgeInsets.only(bottom: 260),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Scaffold(
            body: TwitchPinnedChatManagementPanel(
              api: api,
              channelName: 'channel',
              selectedMessage: message(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
