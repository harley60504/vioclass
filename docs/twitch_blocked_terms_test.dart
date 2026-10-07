// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_blocked_term.dart';
import '../lib/features/twitch/presentation/sheets/twitch_blocked_terms_sheet.dart';

class Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  List<String> scopes = ['moderator:manage:blocked_terms'];
  String owner = '10';
  bool malformed = false;
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
      options.method == 'DELETE'
          ? ''
          : jsonEncode({
              'data': [
                {
                  'id': 'term1',
                  'text': 'fake phrase',
                  'broadcaster_id': malformed ? '99' : '20',
                },
              ],
              'pagination': {'cursor': 'next-page'},
            }),
      options.method == 'DELETE' ? 204 : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeApi extends TwitchModerationApiService {
  final requests = <String?>[];
  final writes = <String>[];
  bool fail = false;
  bool failWrite = false;
  bool repeatCursor = false;
  FakeApi(bool Function() permission)
    : super(
        client: TwitchApiClient(),
        tokenProviders: const [],
        broadcasterId: '20',
        moderatorId: '10',
        canModerate: permission,
      );
  @override
  Future<TwitchBlockedTermsPage> blockedTerms({String? after}) async {
    requests.add(after);
    if (fail) throw const TwitchModerationException('fake missing scope');
    return TwitchBlockedTermsPage(
      after == null
          ? const [TwitchBlockedTerm(id: 'one', text: 'first phrase')]
          : const [
              TwitchBlockedTerm(id: 'one', text: 'first phrase'),
              TwitchBlockedTerm(id: 'two', text: 'second phrase'),
            ],
      after == null || repeatCursor ? 'next' : null,
    );
  }

  @override
  Future<TwitchBlockedTerm> addBlockedTerm(String text) async {
    if (failWrite) throw const TwitchModerationException('fake write rejected');
    writes.add('add:$text');
    return TwitchBlockedTerm(id: 'new', text: text);
  }

  @override
  Future<void> removeBlockedTerm(String id) async => writes.add('remove:$id');
}

void main() {
  test(
    'blocked terms use exact official query/body, matching client and read/manage scopes',
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
      final page = await api.blockedTerms(after: 'previous');
      expect(page.terms.single.id, 'term1');
      expect(page.cursor, 'next-page');
      final added = await api.addBlockedTerm('  fake phrase  ');
      expect(added.id, 'term1');
      await api.removeBlockedTerm('term1');
      expect(adapter.requests.first.queryParameters, {
        'broadcaster_id': '20',
        'moderator_id': '10',
        'first': 100,
        'after': 'previous',
      });
      expect(adapter.requests[1].data, {'text': 'fake phrase'});
      expect(adapter.requests.last.queryParameters, {
        'broadcaster_id': '20',
        'moderator_id': '10',
        'id': 'term1',
      });
      expect(
        adapter.requests.every(
          (r) => r.headers['Client-ID'] == 'matched-client',
        ),
        true,
      );
      adapter.scopes = ['moderator:read:blocked_terms'];
      await api.blockedTerms();
      await expectLater(
        api.addBlockedTerm('phrase'),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests.length, 4);
    },
  );
  test(
    'invalid terms, mismatched account, lost role and foreign response are not accepted',
    () async {
      final adapter = Adapter();
      final client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
      addTearDown(client.close);
      var allowed = true;
      final api = TwitchModerationApiService(
        client: client,
        tokenProviders: [() async => 'fake'],
        broadcasterId: '20',
        moderatorId: '10',
        canModerate: () => allowed,
      );
      for (final text in ['', 'a', 'x' * 501]) {
        await expectLater(
          api.addBlockedTerm(text),
          throwsA(isA<TwitchModerationException>()),
        );
      }
      await expectLater(
        api.removeBlockedTerm(' '),
        throwsA(isA<TwitchModerationException>()),
      );
      adapter.owner = '99';
      await expectLater(
        api.blockedTerms(),
        throwsA(isA<TwitchModerationException>()),
      );
      adapter.owner = '10';
      allowed = false;
      await expectLater(
        api.addBlockedTerm('phrase'),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests, isEmpty);
      allowed = true;
      adapter.malformed = true;
      await expectLater(
        api.blockedTerms(),
        throwsA(isA<TwitchModerationException>()),
      );
    },
  );
  testWidgets('pages merge by term ID and filter is explicitly local', (
    tester,
  ) async {
    final api = FakeApi(() => true);
    addTearDown(api.client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchBlockedTermsPanel(api: api, channelName: 'channel'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('載入更多'));
    await tester.tap(find.text('載入更多'));
    await tester.pumpAndSettle();
    expect(api.requests, [null, 'next']);
    expect(find.text('first phrase'), findsOneWidget);
    expect(find.text('second phrase'), findsOneWidget);
    expect(find.text('已載入 2'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'second');
    await tester.pumpAndSettle();
    expect(find.text('first phrase'), findsNothing);
    expect(find.text('second phrase'), findsOneWidget);
  });
  testWidgets(
    'add/remove freeze targets, require confirmation and preserve failed draft',
    (tester) async {
      final api = FakeApi(() => true);
      addTearDown(api.client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchBlockedTermsPanel(api: api, channelName: 'channel'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'a');
      await tester.tap(find.widgetWithText(FilledButton, '新增封鎖詞'));
      await tester.pumpAndSettle();
      expect(find.text('封鎖詞需為 2–500 字。'), findsOneWidget);
      expect(api.writes, isEmpty);
      await tester.enterText(find.byType(TextField).first, 'new phrase');
      await tester.tap(find.widgetWithText(FilledButton, '新增封鎖詞'));
      await tester.pumpAndSettle();
      expect(find.textContaining('@channel\nnew phrase'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(api.writes, isEmpty);
      api.failWrite = true;
      await tester.tap(find.widgetWithText(FilledButton, '新增封鎖詞'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'new phrase',
      );
      api.failWrite = false;
      await tester.tap(find.widgetWithText(FilledButton, '新增封鎖詞'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.writes, ['add:new phrase']);
      await tester.ensureVisible(find.text('first phrase'));
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'first phrase'),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.writes, ['add:new phrase', 'remove:one']);
      expect(find.text('first phrase'), findsNothing);
    },
  );
  testWidgets(
    'cancelled permission and repeated cursor stop unsafe work without erasing loaded list',
    (tester) async {
      var allowed = true;
      final api = FakeApi(() => allowed)..repeatCursor = true;
      addTearDown(api.client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchBlockedTermsPanel(api: api, channelName: 'channel'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('載入更多'));
      await tester.tap(find.text('載入更多'));
      await tester.pumpAndSettle();
      expect(find.text('分頁游標重複，請重新整理以確認完整清單。'), findsOneWidget);
      expect(find.text('載入更多'), findsNothing);
      api.fail = true;
      await tester.ensureVisible(find.text('重新整理'));
      await tester.tap(find.text('重新整理'));
      await tester.pumpAndSettle();
      expect(find.text('second phrase'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'phrase');
      await tester.ensureVisible(find.widgetWithText(FilledButton, '新增封鎖詞'));
      await tester.tap(find.widgetWithText(FilledButton, '新增封鎖詞'));
      await tester.pumpAndSettle();
      allowed = false;
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.writes, isEmpty);
    },
  );
  testWidgets('phone keyboard and large type do not overflow', (tester) async {
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
            viewInsets: EdgeInsets.only(bottom: 280),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Scaffold(
            body: TwitchBlockedTermsPanel(api: api, channelName: 'channel'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
