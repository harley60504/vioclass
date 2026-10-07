// Regression harness kept in the permitted docs scope.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:io';
import '../lib/features/twitch/api/chat/twitch_whisper_threads_api_service.dart';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../lib/features/twitch/services/chat/twitch_emote_image_cache_manager.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_history_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_whisper_remote_history.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/models/chat/twitch_whisper_conversation.dart';
import '../lib/features/twitch/models/chat/twitch_whisper_emote_catalog.dart';
import '../lib/features/twitch/models/emotes/twitch_official_emote.dart';
import '../lib/features/twitch/presentation/sheets/twitch_whisper_sheet.dart';
import '../lib/features/twitch/presentation/widgets/chat/twitch_selectable_emote.dart';
import '../lib/features/twitch/presentation/widgets/shared/twitch_emote_picker_panel.dart';
import '../lib/features/twitch/presentation/settings/twitch_app_settings_launcher.dart';
import '../lib/features/twitch/presentation/settings/vioclass_update_controller.dart';
import '../lib/features/twitch/services/chat/twitch_whisper_archive_store.dart';
import '../lib/features/twitch/services/chat/twitch_whisper_inbox_controller.dart';
import '../lib/features/twitch/services/notifications/twitch_app_notification_service.dart';
import '../lib/features/twitch/services/notifications/twitch_system_notification_service.dart';
import '../lib/features/twitch/presentation/widgets/notifications/twitch_app_notification_overlay.dart';

class _FakeApi extends TwitchWhisperApiService {
  Completer<void>? sessionGate;
  String owner = '1';
  bool failSend = false;
  bool unknownSend = false;
  Completer<void>? sendGate;
  Completer<void>? profileGate;
  Completer<void>? emoteGate;
  @override
  Future<TwitchWhisperEmoteCatalog> fetchWhisperEmotes({
    required String ownerId,
    required bool Function() canRead,
  }) async {
    await emoteGate?.future;
    return TwitchWhisperEmoteCatalog(const [
      TwitchOfficialEmote(
        id: '25',
        name: 'Kappa',
        imageUrl: 'https://example.test/kappa.png',
        emoteType: '',
        tier: '',
        emoteSetId: '',
        ownerId: '',
        source: TwitchOfficialEmoteSource.global,
        unlocked: true,
      ),
    ]);
  }

  bool failProfile = false;
  String? lastProfileId;

  @override
  Future<TwitchWhisperConversation> getUserById({
    required String ownerId,
    required String peerId,
    bool Function()? canRead,
  }) async {
    lastProfileId = peerId;
    await profileGate?.future;
    if (failProfile) throw const TwitchWhisperException('fake profile failure');
    return TwitchWhisperConversation(
      userId: peerId,
      login: 'refreshed',
      displayName: 'Refreshed',
      avatarUrl: 'https://example.test/updated.png',
    );
  }

  int sent = 0;
  int lookups = 0;
  bool? lastReceivedFlag;
  int lastSentLength = 0;
  _FakeApi() : super(client: TwitchApiClient(), tokenProviders: const []);

  @override
  Future<TwitchWhisperSession> session({String? ownerId, String? scope}) async {
    await sessionGate?.future;
    return TwitchWhisperSession(
      'fake-test-token',
      TwitchTokenValidation(
        clientId: 'fake-client',
        login: 'owner$owner',
        userId: owner,
        scopes: const ['user:manage:whispers'],
        expiresIn: 1000,
      ),
    );
  }

  @override
  Future<TwitchWhisperConversation> findUser(
    String login,
    String ownerId,
  ) async {
    lookups++;
    return TwitchWhisperConversation(
      userId: '2',
      login: login,
      displayName: 'Peer',
    );
  }

  @override
  Future<void> send({
    required String ownerId,
    required String peerId,
    required String text,
    bool Function()? canSend,
    bool hasReceivedWhisper = false,
  }) async {
    await sendGate?.future;
    if (canSend != null && !canSend()) {
      throw const TwitchWhisperException('登入帳號已變更，未發送私訊。');
    }
    if (failSend) throw const TwitchWhisperException('fake send failure');
    if (unknownSend) {
      throw const TwitchWhisperException(
        'fake unknown result',
        outcomeUnknown: true,
      );
    }
    lastReceivedFlag = hasReceivedWhisper;
    lastSentLength = text.length;
    sent++;
  }
}

class _FakeThreads extends TwitchWhisperThreadsApiService {
  Completer<void>? gate;
  bool fail = false;
  int calls = 0;
  final requestedCursors = <String?>[];
  _FakeThreads(TwitchApiClient client) : super(history: _FakeHistory(client));
  @override
  Future<TwitchWhisperThreadsPage> page({
    required String ownerId,
    String? cursor,
  }) async {
    calls++;
    requestedCursors.add(cursor);
    await gate?.future;
    if (fail) throw const TwitchWhisperException('fake inbox unavailable');
    return TwitchWhisperThreadsPage(
      ownerId: ownerId,
      requestedCursor: cursor,
      nextCursor: cursor == null ? 'next' : null,
      conversations: [
        TwitchWhisperConversation(
          userId: '3',
          login: 'remotepeer',
          displayName: 'Remote peer',
          remoteUnreadCount: 4,
        ),
      ],
    );
  }
}

class _FakeHistory extends TwitchWhisperHistoryApiService {
  Completer<void>? gate;
  final cursors = <String?>[];
  bool fail = false;
  bool extraPage = false;
  bool variableHeights = false;
  _FakeHistory(TwitchApiClient client)
    : super(client: client, webTokenProviders: const []);
  @override
  Future<TwitchWhisperRemotePage> page({
    required String ownerId,
    required String peerId,
    String? cursor,
  }) async {
    cursors.add(cursor);
    await gate?.future;
    if (fail) throw const TwitchWhisperException('fake history unavailable');
    return TwitchWhisperRemotePage(
      ownerId: ownerId,
      peerId: peerId,
      requestedCursor: cursor,
      nextCursor: cursor == null
          ? 'older'
          : extraPage && cursor == 'older'
          ? 'oldest'
          : null,
      messages: List.generate(
        5,
        (index) => TwitchWhisperMessage(
          id: 'remote-${cursor ?? "recent"}-$index',
          fromUserId: peerId,
          toUserId: ownerId,
          text:
              'remote history $index${variableHeights ? '\n長短不一的歷史內容' * (index * 2 + 1) : ''}',
          timestamp: DateTime.utc(
            cursor == 'oldest'
                ? 2023
                : cursor == 'older'
                ? 2024
                : 2025,
            1,
            1,
            0,
            index,
          ),
          state: TwitchWhisperMessageState.received,
        ),
      ),
    );
  }
}

Future<void> _advancePrivateWidget(WidgetTester tester) async {
  for (var step = 0; step < 8; step++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _seedSharedFixtureImage(WidgetTester tester) async {
  // The shared static renderer now uses CachedNetworkImageProvider. Seed the
  // fixture image in memory instead of requiring path-provider/native storage.
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 1, 1),
    ui.Paint()..color = const ui.Color(0xff663399),
  );
  final picture = recorder.endRecording();
  final bitmap = (await tester.runAsync(() => picture.toImage(1, 1)))!;
  picture.dispose();
  final provider = CachedNetworkImageProvider(
    'https://example.test/kappa.png',
    cacheKey: TwitchEmoteImageCacheManager.buildCacheKey(
      providerLabel: 'Twitch',
      id: '25',
      name: 'Kappa',
      staticVariant: false,
      url: 'https://example.test/kappa.png',
    ),
    cacheManager: TwitchEmoteImageCacheManager.instance,
  );
  for (final key in [provider, ResizeImage.resizeIfNeeded(64, 64, provider)]) {
    PaintingBinding.instance.imageCache.putIfAbsent(
      key,
      () => OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: bitmap.clone())),
      ),
    );
  }
  bitmap.dispose();
  // Start the cache's housekeeping in real async time, not the widget fake
  // clock; rendering assertions should not inherit its cleanup timer.
  await tester.runAsync(
    () => TwitchEmoteImageCacheManager.instance.getFileFromCache(
      'fixture-bootstrap',
    ),
  );
}

Future<void> _openPrivateWidget(
  WidgetTester tester,
  TwitchWhisperInboxController inbox, {
  Size size = const Size(390, 844),
  double scale = 1,
  double keyboardInset = 0,
  bool Function(ScrollNotification)? onScroll,
  Future<void> Function()? onAuthorize,
  bool automaticSync = false,
}) async {
  await _seedSharedFixtureImage(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: NotificationListener<ScrollNotification>(
          onNotification: onScroll,
          child: child!,
        ),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTwitchWhisperSheet(
              context: context,
              controller: inbox,
              onAuthorize: onAuthorize,
              automaticSync: automaticSync,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _advancePrivateWidget(tester);
  if (keyboardInset > 0) {
    addTearDown(tester.view.resetViewInsets);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
    await _advancePrivateWidget(tester);
  }
}

// An active recovery intentionally keeps a loading animation alive. Do not use
// pumpAndSettle here: it advances fake time until the 45-second read expires.
Future<void> _advanceRunningRecoveryWidget(WidgetTester tester) async {
  for (var step = 0; step < 12; step++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const cachePaths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory fixtureCacheDirectory;
  setUpAll(() async {
    fixtureCacheDirectory = await Directory.systemTemp.createTemp(
      'vioclass-emote-test-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          cachePaths,
          (_) async => fixtureCacheDirectory.path,
        );
    await TwitchEmoteImageCacheManager.instance.getFileFromCache(
      'fixture-bootstrap',
    );
  });
  tearDownAll(() async {
    await TwitchEmoteImageCacheManager.instance.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cachePaths, null);
    // Only the test-owned temporary directory is removed.
    await fixtureCacheDirectory.delete(recursive: true);
  });
  late _FakeApi api;
  late TwitchWhisperInboxController inbox;
  late Map<String, String> disk;
  var notifications = 0;
  String? notificationName;
  setUp(() async {
    disk = {};
    notifications = 0;
    notificationName = null;
    api = _FakeApi();
    inbox = TwitchWhisperInboxController(
      api: api,
      receiveInBackground: false,
      onIncomingNotification: (peer) {
        notifications++;
        notificationName = peer.displayName;
      },
      store: TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async {
          disk[key] = value;
        },
      ),
    );
    await inbox.refreshSession();
    await inbox.startConversation('peer');
  });
  tearDown(() {
    inbox.dispose();
    api.client.close();
  });

  testWidgets(
    'Private opens at latest then keeps manual scrolling on receive',
    (tester) async {
      await tester.runAsync(() async {
        for (var index = 0; index < 40; index++) {
          await inbox.receiveEvent({
            'from_user_id': '2',
            'to_user_id': '1',
            'whisper_id': 'manual-$index',
            'whisper': {'text': 'message $index\nsecond line\nthird line'},
          }, DateTime.utc(2026, 1, 1).add(Duration(seconds: index)));
        }
      });
      await _openPrivateWidget(tester, inbox);
      final list = find.byKey(const ValueKey('whisper-message-list'));
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)).first,
          )
          .position;
      expect(position.extentBefore, lessThanOrEqualTo(.5));
      expect(find.textContaining('返回最新訊息'), findsNothing);
      ScrollStartNotification(
        metrics: position,
        context: tester.element(list),
        dragDetails: DragStartDetails(),
      ).dispatch(tester.element(list));
      await tester.pump();
      expect(inbox.readingLatest, true);
      expect(find.textContaining('返回最新訊息'), findsNothing);
      position.jumpTo(30);
      await tester.pumpAndSettle();
      expect(inbox.readingLatest, true);
      expect(find.textContaining('返回最新訊息'), findsNothing);
      position.jumpTo(60);
      await tester.pumpAndSettle();
      expect(inbox.readingLatest, false);
      expect(find.textContaining('返回最新訊息'), findsOneWidget);
      position.jumpTo(20);
      await tester.pumpAndSettle();
      expect(inbox.readingLatest, true);
      expect(find.textContaining('返回最新訊息'), findsNothing);
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(position.extentBefore, greaterThan(90));
      final before = position.pixels;
      await tester.runAsync(
        () => inbox.receiveEvent({
          'from_user_id': '2',
          'to_user_id': '1',
          'whisper_id': 'manual-new',
          'whisper': {'text': 'new incoming message'},
        }, DateTime.utc(2026, 1, 2)),
      );
      await _advancePrivateWidget(tester);
      expect(position.pixels, closeTo(before, .5));
      final latest = find.textContaining('返回最新訊息');
      await tester.tap(latest.first);
      await _advancePrivateWidget(tester);
      expect(position.extentBefore, lessThanOrEqualTo(.5));
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: tester.getCenter(list),
          scrollDelta: const Offset(0, -30),
          kind: ui.PointerDeviceKind.mouse,
        ),
      );
      await _advancePrivateWidget(tester);
      expect(position.extentBefore, greaterThan(.5));
      expect(inbox.readingLatest, true);
      expect(find.textContaining('返回最新訊息'), findsNothing);
      final stopped = position.pixels;
      await tester.pump(const Duration(milliseconds: 500));
      expect(position.pixels, closeTo(stopped, .5));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Production inbox starts at tail without seeking and history sync preserves pixels',
    (tester) async {
      final store = inbox.archive;
      inbox.dispose();
      final history = _FakeHistory(api.client);
      final threads = _FakeThreads(api.client);
      inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        historyApi: history,
        threadsApi: threads,
        receiveInBackground: false,
      );
      await tester.runAsync(() async {
        await inbox.refreshSession();
        await inbox.startConversation('peer');
        for (var i = 0; i < 60; i++) {
          await inbox.receiveEvent({
            'from_user_id': '2',
            'to_user_id': '1',
            'whisper_id': 'tail-$i',
            'whisper': {'text': 'tail row $i\n${'variable line\n' * (i % 5)}'},
          }, DateTime.utc(2026).add(Duration(seconds: i)));
        }
      });
      var programmaticUpdates = 0;
      await _openPrivateWidget(
        tester,
        inbox,
        automaticSync: true,
        onScroll: (event) {
          if (event.depth == 0 &&
              event is ScrollUpdateNotification &&
              event.dragDetails == null) {
            programmaticUpdates++;
          }
          return false;
        },
      );
      final list = find.byKey(const ValueKey('whisper-message-list'));
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)).first,
          )
          .position;
      expect(position.pixels, 0);
      expect(position.extentBefore, lessThanOrEqualTo(.5));
      expect(programmaticUpdates, 0);
      expect(find.textContaining('tail row 59'), findsOneWidget);
      expect(find.text('已提交不代表送達或對方已讀。'), findsNothing);
      expect(find.text('部分表情符號會佔兩格；未確認收過對方私訊時額度為 500。'), findsNothing);
      final updatesBefore = programmaticUpdates;
      unawaited(inbox.syncActiveHistory());
      await _advancePrivateWidget(tester);
      expect(inbox.syncingHistory, false);
      expect(history.cursors, [null, null]);
      expect(position.pixels, 0);
      expect(programmaticUpdates, updatesBefore);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'Logout while deletion waits for draft persistence cancels the old deletion',
    () async {
      inbox.dispose();
      final entered = Completer<void>();
      final release = Completer<void>();
      var armed = false;
      final archive = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, raw) async {
          if (armed && key.endsWith('_1')) {
            armed = false;
            entered.complete();
            await release.future;
          }
          disk[key] = raw;
        },
      );
      inbox = TwitchWhisperInboxController(
        api: api,
        store: archive,
        receiveInBackground: false,
      );
      await inbox.refreshSession();
      await inbox.startConversation('peer');
      inbox.updateDraft('2', 'old draft');
      armed = true;
      final removal = inbox.removeConversation('2');
      await entered.future;
      inbox.clearSession();
      release.complete();
      await removal;
      final old = await archive.load('1');
      expect(old, hasLength(1));
      expect(old.single.userId, '2');
      expect(old.single.draft, 'old draft');
      expect(inbox.ownerId, isNull);
      expect(inbox.conversations, isEmpty);
      api.owner = '9';
      await inbox.refreshSession();
      await inbox.startConversation('peer');
      expect(inbox.ownerId, '9');
      expect(inbox.conversations.single.userId, '2');
      expect((await archive.load('1')).single.draft, 'old draft');
      expect(api.sent, 0);
    },
  );

  for (final failLate in [false, true]) {
    test(
      'Committed deletion finishes only old owner after login changes: $failLate',
      () async {
        inbox.dispose();
        var armed = false;
        final entered = Completer<void>();
        final release = Completer<void>();
        final archive = TwitchWhisperArchiveStore(
          read: (key) async => disk[key],
          write: (key, raw) async {
            if (armed && key.endsWith('_1')) {
              armed = false;
              entered.complete();
              await release.future;
              if (failLate) throw StateError('fake old owner write failure');
            }
            disk[key] = raw;
          },
        );
        inbox = TwitchWhisperInboxController(
          api: api,
          store: archive,
          receiveInBackground: false,
        );
        await inbox.refreshSession();
        await inbox.startConversation('peer');
        await archive.saveDraft(
          '9',
          TwitchWhisperConversation(
            userId: '2',
            login: 'otherpeer',
            displayName: 'OtherPeer',
          ),
          'new owner draft',
        );
        armed = true;
        final removal = inbox.removeConversation('2');
        await entered.future;
        inbox.clearSession();
        api.owner = '9';
        final refresh = inbox.refreshSession();
        for (var step = 0; step < 10 && inbox.ownerId != '9'; step++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(inbox.ownerId, '9');
        final arriving = inbox.receiveEvent({
          'from_user_id': '2',
          'to_user_id': '9',
          'whisper_id': 'new-owner-receipt',
          'whisper': {'text': 'new owner received'},
        }, DateTime.utc(2026, 10, 4));
        release.complete();
        await Future.wait([removal, refresh, arriving]);
        expect(inbox.ownerId, '9');
        expect(inbox.loading, false);
        expect(inbox.managingHistory, false);
        expect(inbox.errorText, isNull);
        expect(inbox.conversations.single.draft, 'new owner draft');
        expect(
          inbox.conversations.single.messages.single.id,
          'new-owner-receipt',
        );
        expect(inbox.pendingIncomingCount, 0);
        final old = await archive.load('1');
        expect(old, failLate ? hasLength(1) : isEmpty);
        if (failLate) expect(old.single.userId, '2');
        expect(
          (await archive.load('9')).single.messages.single.id,
          'new-owner-receipt',
        );
        expect(api.sent, 0);
      },
    );
  }

  for (final failDelete in [false, true]) {
    test(
      'Deleting clears only pre-existing pending receipts after commit: $failDelete',
      () async {
        inbox.dispose();
        var failWrites = false;
        var armed = false;
        final deleting = Completer<void>();
        final release = Completer<void>();
        final notifications = <String>[];
        final archive = TwitchWhisperArchiveStore(
          read: (key) async => disk[key],
          write: (key, raw) async {
            if (failWrites) throw StateError('fake pending write failure');
            final peers = (jsonDecode(raw) as Map)['conversations'] as List;
            if (armed && !peers.any((p) => (p as Map)['userId'] == '2')) {
              armed = false;
              deleting.complete();
              await release.future;
              if (failDelete) throw StateError('fake deletion failure');
            }
            disk[key] = raw;
          },
        );
        inbox = TwitchWhisperInboxController(
          api: api,
          store: archive,
          receiveInBackground: false,
          onIncomingNotification: (peer) => notifications.add(peer.userId),
        );
        await inbox.refreshSession();
        await inbox.startConversation('peer');
        Future<void> receipt(String peer, String id) => inbox.receiveEvent({
          'from_user_id': peer,
          'to_user_id': '1',
          'whisper_id': id,
          'whisper': {'text': id},
        }, DateTime.utc(2026, 10, 4));
        failWrites = true;
        await receipt('2', 'pending-old');
        await receipt('3', 'pending-other');
        expect(inbox.pendingIncomingCount, 2);
        failWrites = false;
        armed = true;
        final removal = inbox.removeConversation('2');
        await deleting.future;
        final arriving = receipt('2', 'arrived-during-delete');
        release.complete();
        await Future.wait([removal, arriving]);
        await inbox.refreshSession();
        final saved = await archive.load('1');
        final target = saved.singleWhere((p) => p.userId == '2');
        expect(target.messages.map((m) => m.id).toSet(), {
          if (failDelete) 'pending-old',
          'arrived-during-delete',
        });
        expect(
          saved.singleWhere((p) => p.userId == '3').messages.single.id,
          'pending-other',
        );
        expect(
          notifications.where((id) => id == '2').length,
          failDelete ? 2 : 1,
        );
        expect(inbox.pendingIncomingCount, 0);
        expect(api.sent, 0);
      },
    );
  }

  for (final failAfterCommit in [false, true]) {
    test(
      'Local removal distinguishes write failure from committed read failure: $failAfterCommit',
      () async {
        inbox.dispose();
        var failWrite = false;
        var failRead = false;
        var armReadFailure = false;
        final archive = TwitchWhisperArchiveStore(
          read: (key) async {
            if (failRead) throw StateError('fake read failure');
            return disk[key];
          },
          write: (key, raw) async {
            if (failWrite) throw StateError('fake delete write failure');
            disk[key] = raw;
            if (armReadFailure && key.endsWith('_1')) {
              final peers = (jsonDecode(raw) as Map)['conversations'] as List;
              if (!peers.any((peer) => (peer as Map)['userId'] == '2')) {
                failRead = true;
              }
            }
          },
        );
        inbox = TwitchWhisperInboxController(
          api: api,
          store: archive,
          receiveInBackground: false,
        );
        await inbox.refreshSession();
        await inbox.startConversation('peer');
        inbox.updateDraft('2', 'delete target draft');
        await inbox.flushDrafts();
        await archive.saveDraft(
          '1',
          TwitchWhisperConversation(
            userId: '3',
            login: 'untouched',
            displayName: 'Untouched',
          ),
          'other peer draft',
        );
        await inbox.refreshSession();
        final before = disk['vioclass_twitch_whispers_v1_1'];
        failWrite = !failAfterCommit;
        armReadFailure = failAfterCommit;
        await inbox.removeConversation('2');
        expect(inbox.managingHistory, false);
        if (failAfterCommit) {
          expect(inbox.errorText, contains('本機對話已刪除'));
          expect(inbox.activePeerId, isNull);
          expect(inbox.conversations.single.userId, '3');
          expect(disk['vioclass_twitch_whispers_v1_1'], isNot(before));
        } else {
          expect(inbox.errorText, contains('刪除未完成'));
          expect(inbox.conversations, hasLength(2));
          expect(disk['vioclass_twitch_whispers_v1_1'], before);
        }
        failWrite = false;
        failRead = false;
        armReadFailure = false;
        if (!failAfterCommit) await inbox.removeConversation('2');
        await inbox.refreshSession();
        expect(inbox.errorText, isNull);
        expect(inbox.conversations.single.userId, '3');
        expect(inbox.conversations.single.draft, 'other peer draft');
        expect((await archive.load('1')).single.userId, '3');
        expect(api.sent, 0);
      },
    );
  }

  test(
    'Receipts queued during deletion preserve new messages and other peers',
    () async {
      inbox.dispose();
      final deleting = Completer<void>();
      final release = Completer<void>();
      var armDelete = false;
      final archive = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, raw) async {
          final peers = (jsonDecode(raw) as Map)['conversations'] as List;
          if (armDelete &&
              !peers.any((peer) => (peer as Map)['userId'] == '2')) {
            armDelete = false;
            deleting.complete();
            await release.future;
          }
          disk[key] = raw;
        },
      );
      inbox = TwitchWhisperInboxController(
        api: api,
        store: archive,
        receiveInBackground: false,
      );
      await inbox.refreshSession();
      await inbox.startConversation('peer');
      inbox.updateDraft('2', 'old removed draft');
      await inbox.flushDrafts();
      await archive.saveDraft(
        '1',
        TwitchWhisperConversation(
          userId: '3',
          login: 'other',
          displayName: 'Other',
        ),
        'keep other draft',
      );
      await inbox.receiveEvent({
        'from_user_id': '2',
        'to_user_id': '1',
        'whisper_id': 'old-removed',
        'whisper': {'text': 'old removed history'},
      }, DateTime.utc(2026, 10, 4));
      armDelete = true;
      final removal = inbox.removeConversation('2');
      await deleting.future;
      final receipts = [
        for (final peer in ['2', '3'])
          inbox.receiveEvent({
            'from_user_id': peer,
            'to_user_id': '1',
            'whisper_id': 'new-$peer',
            'whisper': {'text': 'new receipt $peer'},
          }, DateTime.utc(2026, 10, 4, 1)),
      ];
      release.complete();
      await Future.wait([removal, ...receipts]);
      final peers = await archive.load('1');
      final recreated = peers.singleWhere((peer) => peer.userId == '2');
      expect(recreated.messages.single.id, 'new-2');
      expect(recreated.draft, '');
      expect(recreated.unreadCount, 1);
      final other = peers.singleWhere((peer) => peer.userId == '3');
      expect(other.messages.single.id, 'new-3');
      expect(other.draft, 'keep other draft');
      expect(other.unreadCount, 1);
      expect(inbox.conversations, hasLength(2));
      expect(inbox.pendingIncomingCount, 0);
      expect(inbox.errorText, isNull);
      expect(api.sent, 0);
    },
  );

  for (final size in [
    const Size(1100, 800),
    const Size(390, 844),
    const Size(390, 260),
  ]) {
    testWidgets(
      'Private removes refresh and local deletion controls at $size',
      (tester) async {
        inbox.updateDraft('2', 'keep original draft');
        await tester.runAsync(inbox.flushDrafts);
        final original = Map<String, String>.of(disk);
        await _openPrivateWidget(tester, inbox, size: size);
        expect(find.byTooltip('對話操作'), findsNothing);
        expect(find.byTooltip('刪除本機對話'), findsNothing);
        expect(find.text('刪除本機對話'), findsNothing);
        expect(find.text('更新對象資料'), findsNothing);
        expect(inbox.activeConversation!.draft, 'keep original draft');
        expect(disk, original);
        expect(api.sent, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final scenario in [
    (size: const Size(390, 260), scale: 1.4, keyboard: 0.0),
    (size: const Size(320, 640), scale: 1.3, keyboard: 250.0),
  ]) {
    testWidgets(
      'Compact private errors remain accessible at ${scenario.size}',
      (tester) async {
        await tester.runAsync(() async {
          api.failSend = true;
          inbox.updateDraft('2', 'keep failed draft');
          await inbox.sendActiveMessage();
        });
        final error = inbox.errorText!;
        final sends = api.sent;
        await _openPrivateWidget(
          tester,
          inbox,
          size: scenario.size,
          scale: scenario.scale,
          keyboardInset: scenario.keyboard,
        );
        expect(find.byTooltip('私訊錯誤詳情'), findsOneWidget);
        await tester.tap(find.byTooltip('私訊錯誤詳情'));
        await _advancePrivateWidget(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text(error), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('關閉'),
          ),
        );
        await _advancePrivateWidget(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(inbox.activeConversation!.draft, 'keep failed draft');
        expect(inbox.errorText, error);
        expect(api.sent, sends);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Compact private archive failure exposes its full reason without overwriting data',
    (tester) async {
      await tester.runAsync(() async {
        disk['vioclass_twitch_whispers_v1_1'] = '{damaged archive';
        await inbox.refreshSession();
      });
      final error = inbox.errorText!;
      await _openPrivateWidget(
        tester,
        inbox,
        size: const Size(390, 260),
        scale: 1.4,
      );
      await tester.tap(find.byTooltip('私訊錯誤詳情'));
      await _advancePrivateWidget(tester);
      expect(find.text(error), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(disk['vioclass_twitch_whispers_v1_1'], '{damaged archive');
      expect(api.sent, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [const Size(1000, 760), const Size(390, 844)]) {
    testWidgets(
      'Private list search and sorting retain background receipts at $size',
      (tester) async {
        await tester.runAsync(() async {
          await inbox.selectConversation(null);
          for (final contact in [
            ('2', 'Zulu'),
            ('3', 'Alpha'),
            ('4', 'Bravo'),
          ]) {
            await inbox.receiveEvent({
              'from_user_id': contact.$1,
              'from_user_login': contact.$2.toLowerCase(),
              'from_user_name': contact.$2,
              'to_user_id': '1',
              'whisper_id': 'list-${contact.$1}',
              'whisper': {'text': 'preview ${contact.$1}'},
            }, DateTime.utc(2026, 10, 4, int.parse(contact.$1)));
          }
          await inbox.receiveEvent({
            'from_user_id': '4',
            'to_user_id': '1',
            'whisper_id': 'list-4-second',
            'whisper': {'text': 'second preview'},
          }, DateTime.utc(2026, 10, 4, 5));
        });
        await _openPrivateWidget(tester, inbox, size: size);
        Finder row(String name) =>
            find.ancestor(of: find.text(name), matching: find.byType(ListTile));
        void order(List<String> names) {
          for (var i = 1; i < names.length; i++) {
            expect(
              tester.getTopLeft(row(names[i - 1])).dy,
              lessThan(tester.getTopLeft(row(names[i])).dy),
            );
          }
        }

        order(['Bravo', 'Alpha', 'Zulu']);
        await tester.tap(find.byTooltip('對話排序'));
        await _advancePrivateWidget(tester);
        await tester.tap(find.text('依名字'));
        await _advancePrivateWidget(tester);
        order(['Alpha', 'Bravo', 'Zulu']);
        await tester.tap(find.byTooltip('對話排序'));
        await _advancePrivateWidget(tester);
        await tester.tap(find.text('未讀優先'));
        await _advancePrivateWidget(tester);
        order(['Bravo', 'Alpha', 'Zulu']);
        final search = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.hintText == '搜尋對話',
        );
        await tester.enterText(search, ' ALPHA ');
        await _advancePrivateWidget(tester);
        expect(row('Alpha'), findsOneWidget);
        expect(row('Bravo'), findsNothing);
        await tester.enterText(search, 'no-match');
        await _advancePrivateWidget(tester);
        expect(find.text('沒有符合搜尋的對話。'), findsOneWidget);
        expect(find.textContaining('尚無本機對話'), findsNothing);
        var received = false;
        unawaited(
          inbox
              .receiveEvent({
                'from_user_id': '3',
                'to_user_id': '1',
                'whisper_id': 'list-filtered-receipt',
                'whisper': {'text': 'while filtered'},
              }, DateTime.utc(2026, 10, 4, 6))
              .then((_) => received = true),
        );
        await _advancePrivateWidget(tester);
        expect(received, true);
        expect(inbox.activePeerId, isNull);
        expect(inbox.unreadCount, 5);
        expect(find.text('沒有符合搜尋的對話。'), findsOneWidget);
        await tester.enterText(search, '');
        await _advancePrivateWidget(tester);
        order(['Alpha', 'Bravo', 'Zulu']);
        expect(find.text('while filtered'), findsOneWidget);
        expect(inbox.conversations, hasLength(3));
        expect(api.sent, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final failingPhase in ['receipt', 'draft']) {
    test(
      'Accepted send followed by $failingPhase write failure is not labelled failed or resent',
      () async {
        inbox.dispose();
        var failed = false;
        final store = TwitchWhisperArchiveStore(
          read: (key) async => disk[key],
          write: (key, value) async {
            final peers = (jsonDecode(value) as Map)['conversations'] as List;
            final target = peers.cast<Map>().singleWhere(
              (peer) => peer['userId'] == '2',
            );
            final messages = target['messages'] as List;
            final submitted = messages.any(
              (message) => (message as Map)['state'] == 'submitted',
            );
            if (!failed &&
                submitted &&
                (failingPhase == 'receipt' || target['draft'] == '')) {
              failed = true;
              throw StateError('fake accepted-send persistence failure');
            }
            disk[key] = value;
          },
        );
        inbox = TwitchWhisperInboxController(
          api: api,
          store: store,
          receiveInBackground: false,
        );
        await inbox.refreshSession();
        await inbox.startConversation('peer');
        inbox.updateDraft('2', 'submit exactly once');
        await inbox.sendActiveMessage();
        expect(failed, true);
        expect(api.sent, 1);
        expect(inbox.activeConversation!.messages, hasLength(1));
        expect(
          inbox.activeConversation!.messages.single.state,
          TwitchWhisperMessageState.submitted,
        );
        expect(inbox.activeConversation!.draft, 'submit exactly once');
        expect(inbox.errorText, contains('請勿直接重送'));
        expect(
          (await store.load('1')).single.messages.single.state,
          TwitchWhisperMessageState.submitted,
        );
      },
    );
  }

  for (final failure in ['read', 'write']) {
    test(
      'Persistent $failure failure after accepted send preserves warning and restart uncertainty',
      () async {
        inbox.dispose();
        var storageUnavailable = true;
        final store = TwitchWhisperArchiveStore(
          read: (key) async {
            if (failure == 'read' && storageUnavailable && api.sent > 0) {
              throw StateError('fake persistent read failure');
            }
            return disk[key];
          },
          write: (key, value) async {
            if (failure == 'write' && storageUnavailable && api.sent > 0) {
              throw StateError('fake persistent write failure');
            }
            disk[key] = value;
          },
        );
        inbox = TwitchWhisperInboxController(
          api: api,
          store: store,
          receiveInBackground: false,
        );
        await inbox.refreshSession();
        await inbox.startConversation('peer');
        inbox.updateDraft('2', 'preserve uncertain receipt');
        await inbox.sendActiveMessage();
        expect(api.sent, 1);
        expect(inbox.sending, false);
        expect(inbox.errorText, contains('Twitch 已接受本次提交'));
        expect(inbox.errorText, contains('請勿直接重送'));
        expect(inbox.activeConversation!.draft, 'preserve uncertain receipt');
        expect(
          inbox.activeConversation!.messages.single.state,
          TwitchWhisperMessageState.submitted,
        );
        expect(
          inbox.hasUnsavedSubmission(inbox.activeConversation!.messages.single),
          true,
        );
        final persisted = jsonDecode(disk['vioclass_twitch_whispers_v1_1']!);
        expect(
          persisted['conversations'][0]['messages'][0]['state'],
          'sending',
        );

        storageUnavailable = false;
        final restartedStore = TwitchWhisperArchiveStore(
          read: (key) async => disk[key],
          write: (key, value) async => disk[key] = value,
        );
        final recovered = (await restartedStore.load('1')).single;
        expect(recovered.draft, 'preserve uncertain receipt');
        expect(
          recovered.messages.single.state,
          TwitchWhisperMessageState.unconfirmed,
        );
        expect(api.sent, 1);
        // A different owner never flushes the old owner's volatile receipt.
        final uncertainDisk = disk['vioclass_twitch_whispers_v1_1'];
        api.owner = '9';
        await inbox.refreshSession();
        expect(inbox.ownerId, '9');
        expect(inbox.conversations, isEmpty);
        expect(inbox.hasUnsavedSubmission(recovered.messages.single), false);
        expect(disk['vioclass_twitch_whispers_v1_1'], uncertainDisk);
        api.owner = '1';
        await inbox.refreshSession();
        expect(
          inbox.conversations.single.messages.single.state,
          TwitchWhisperMessageState.submitted,
        );
        expect(
          (await restartedStore.load('1')).single.messages.single.state,
          TwitchWhisperMessageState.submitted,
        );
        expect(inbox.conversations.single.draft, 'preserve uncertain receipt');
        expect(api.sent, 1);
        expect(
          inbox.hasUnsavedSubmission(
            inbox.conversations.single.messages.single,
          ),
          false,
        );
      },
    );
  }

  for (final size in [const Size(1000, 760), const Size(390, 844)]) {
    testWidgets('Unsaved accepted receipt status stays distinct at $size', (
      tester,
    ) async {
      inbox.dispose();
      var writeUnavailable = true;
      await tester.runAsync(() async {
        inbox = TwitchWhisperInboxController(
          api: api,
          receiveInBackground: false,
          store: TwitchWhisperArchiveStore(
            read: (key) async => disk[key],
            write: (key, value) async {
              if (writeUnavailable && api.sent > 0) {
                throw StateError('fake persistent receipt write failure');
              }
              disk[key] = value;
            },
          ),
        );
        await inbox.refreshSession();
        await inbox.startConversation('peer');
        inbox.updateDraft('2', 'unsaved status test');
        await inbox.sendActiveMessage();
      });
      await _openPrivateWidget(tester, inbox, size: size);
      expect(find.textContaining('已提交 · 尚未儲存'), findsOneWidget);
      expect(api.sent, 1);
      writeUnavailable = false;
      unawaited(inbox.selectConversation('2'));
      await _advancePrivateWidget(tester);
      expect(find.textContaining('已提交 · 尚未儲存'), findsNothing);
      expect(
        inbox.activeConversation!.messages.single.state,
        TwitchWhisperMessageState.submitted,
      );
      expect(api.sent, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _advancePrivateWidget(tester);
    });
  }

  for (final target in [
    'missing message',
    'removed peer',
    'conflicting message',
  ]) {
    test(
      'Unsaved submitted receipt never resurrects or overwrites $target',
      () async {
        final receipt = TwitchWhisperMessage(
          id: 'local-receipt',
          fromUserId: '1',
          toUserId: '2',
          text: 'original',
          timestamp: DateTime.utc(2026, 10, 3),
          state: TwitchWhisperMessageState.submitted,
        );
        if (target == 'removed peer') {
          await inbox.archive.removeConversation('1', '2');
        } else if (target == 'conflicting message') {
          await inbox.archive.append(
            '1',
            inbox.activeConversation!,
            TwitchWhisperMessage(
              id: receipt.id,
              fromUserId: '2',
              toUserId: '1',
              text: 'different identity',
              timestamp: receipt.timestamp,
              state: TwitchWhisperMessageState.received,
            ),
          );
        }
        final before = disk['vioclass_twitch_whispers_v1_1'];
        if (target == 'conflicting message') {
          await expectLater(
            inbox.archive.saveSubmittedReceipt('1', receipt),
            throwsFormatException,
          );
        } else {
          expect(await inbox.archive.saveSubmittedReceipt('1', receipt), false);
        }
        expect(disk['vioclass_twitch_whispers_v1_1'], before);
        expect(api.sent, 0);
      },
    );
  }

  test(
    'Interrupted-send recovery retries its failed checkpoint before exposing data',
    () async {
      inbox.updateDraft('2', 'restart draft');
      await inbox.flushDrafts();
      await inbox.archive.append(
        '1',
        inbox.activeConversation!,
        TwitchWhisperMessage(
          id: 'interrupted-local-id',
          fromUserId: '1',
          toUserId: '2',
          text: 'interrupted send',
          timestamp: DateTime.utc(2026, 10, 3),
          state: TwitchWhisperMessageState.sending,
        ),
      );
      final original = disk['vioclass_twitch_whispers_v1_1'];
      var recoveryWrites = 0;
      final restartedStore = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async {
          recoveryWrites++;
          if (recoveryWrites == 1) {
            throw StateError('fake recovery write failure');
          }
          disk[key] = value;
        },
      );
      await expectLater(
        restartedStore.load('1'),
        throwsA(isA<TwitchWhisperArchiveException>()),
      );
      expect(disk['vioclass_twitch_whispers_v1_1'], original);
      final recovered = (await restartedStore.load('1')).single;
      expect(recoveryWrites, 2);
      expect(
        recovered.messages.single.state,
        TwitchWhisperMessageState.unconfirmed,
      );
      expect(recovered.draft, 'restart draft');
      expect(
        (await restartedStore.load('1')).single.messages.single.state,
        TwitchWhisperMessageState.unconfirmed,
      );
      expect(recoveryWrites, 2);
      expect(api.sent, 0);
    },
  );

  Map<String, dynamic> incoming(
    String id, {
    String text = 'pending incoming',
  }) => {
    'from_user_id': '2',
    'from_user_login': 'peer',
    'from_user_name': 'Peer',
    'to_user_id': '1',
    'whisper_id': id,
    'whisper': {'text': text},
  };

  for (final failure in ['read', 'write']) {
    test(
      'Incoming $failure failure retains events, isolates owners, and recovers exactly once',
      () async {
        inbox.dispose();
        var unavailable = false;
        inbox = TwitchWhisperInboxController(
          api: api,
          receiveInBackground: false,
          onIncomingNotification: (_) => notifications++,
          store: TwitchWhisperArchiveStore(
            read: (key) async {
              if (unavailable && failure == 'read') {
                throw StateError('fake read failure');
              }
              return disk[key];
            },
            write: (key, value) async {
              if (unavailable && failure == 'write') {
                throw StateError('fake write failure');
              }
              disk[key] = value;
            },
          ),
        );
        await inbox.refreshSession();
        await inbox.startConversation('peer');
        final before = disk['vioclass_twitch_whispers_v1_1'];
        unavailable = true;
        await inbox.receiveEvent(
          incoming('pending-a'),
          DateTime.utc(2026, 10, 3),
        );
        await inbox.receiveEvent(
          incoming('pending-a'),
          DateTime.utc(2026, 10, 3),
        );
        await inbox.receiveEvent(
          incoming('pending-b'),
          DateTime.utc(2026, 10, 3),
        );
        expect(inbox.pendingIncomingCount, 2);
        expect(inbox.errorText, contains('暫存於記憶體'));
        expect(disk['vioclass_twitch_whispers_v1_1'], before);
        expect(notifications, 0);
        unavailable = false;
        api.owner = '9';
        await inbox.refreshSession();
        expect(inbox.pendingIncomingCount, 0);
        expect(inbox.conversations, isEmpty);
        expect(disk['vioclass_twitch_whispers_v1_1'], before);
        api.owner = '1';
        await inbox.refreshSession();
        expect(inbox.pendingIncomingCount, 0);
        expect(inbox.conversations.single.messages.map((m) => m.id), [
          'pending-a',
          'pending-b',
        ]);
        expect(inbox.unreadCount, 2);
        expect(notifications, 2);
        await inbox.receiveEvent(
          incoming('pending-a'),
          DateTime.utc(2026, 10, 3),
        );
        expect(notifications, 2);
        expect(inbox.unreadCount, 2);
        expect(api.sent, 0);
      },
    );
  }

  test(
    'Notification callback failure does not lose saved incoming or block the next message',
    () async {
      final store = inbox.archive;
      inbox.dispose();
      var attempts = 0;
      inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        receiveInBackground: false,
        onIncomingNotification: (_) {
          attempts++;
          throw StateError('fake notification failure');
        },
      );
      await inbox.refreshSession();
      await inbox.receiveEvent(incoming('notify-a'), DateTime.utc(2026, 10, 3));
      await inbox.receiveEvent(incoming('notify-b'), DateTime.utc(2026, 10, 3));
      expect(attempts, 2);
      expect(inbox.pendingIncomingCount, 0);
      expect(inbox.conversations.single.messages, hasLength(2));
      expect((await store.load('1')).single.messages, hasLength(2));
      expect(inbox.errorText, contains('通知顯示失敗'));
      expect(inbox.unreadCount, 2);
    },
  );

  test(
    'Incoming volatile queue cap and identity conflicts are explicit, clearSession discards only volatile data',
    () async {
      inbox.dispose();
      var unavailable = false;
      inbox = TwitchWhisperInboxController(
        api: api,
        receiveInBackground: false,
        store: TwitchWhisperArchiveStore(
          read: (key) async => disk[key],
          write: (key, value) async {
            if (unavailable) throw StateError('fake full disk');
            disk[key] = value;
          },
        ),
      );
      await inbox.refreshSession();
      final before = disk['vioclass_twitch_whispers_v1_1'];
      unavailable = true;
      for (var i = 0; i < 500; i++) {
        await inbox.receiveEvent(
          incoming('queued-$i'),
          DateTime.utc(2026, 10, 3),
        );
      }
      await inbox.receiveEvent(
        incoming('queued-0', text: 'conflicting'),
        DateTime.utc(2026, 10, 3),
      );
      expect(inbox.errorText, contains('衝突'));
      expect(inbox.pendingIncomingCount, 500);
      await inbox.receiveEvent(incoming('overflow'), DateTime.utc(2026, 10, 3));
      expect(inbox.errorText, contains('暫存已滿'));
      expect(inbox.pendingIncomingCount, 500);
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      inbox.clearSession();
      unavailable = false;
      await inbox.refreshSession();
      expect(inbox.pendingIncomingCount, 0);
      expect(inbox.conversations.single.messages, isEmpty);
      expect(api.sent, 0);
    },
  );

  test(
    'Receive gap survives reconnect, refresh and clearSession without mixing owners',
    () async {
      inbox.recordReceiveGap('9');
      expect(inbox.historyRecoveryNeeded, false);
      inbox.recordReceiveGap('1');
      inbox.receiveStatus = '私訊收件已連線';
      await inbox.refreshSession();
      expect(inbox.historyRecoveryNeeded, true);
      api.owner = '9';
      await inbox.refreshSession();
      expect(inbox.historyRecoveryNeeded, false);
      inbox.recordReceiveGap('1');
      expect(inbox.historyRecoveryNeeded, false);
      api.owner = '1';
      await inbox.refreshSession();
      expect(inbox.historyRecoveryNeeded, true);
      inbox.clearSession();
      await inbox.refreshSession();
      expect(inbox.historyRecoveryNeeded, true);
    },
  );

  test(
    'Receive gap checkpoint retains earliest time across store restart and unrelated writes',
    () async {
      final since = DateTime.utc(2026, 10, 1);
      await inbox.archive.recordReceiveGap('1', since);
      await inbox.archive.mergeThreadsPage(
        '1',
        TwitchWhisperThreadsPage(
          ownerId: '1',
          requestedCursor: null,
          nextCursor: 'gap-page',
          conversations: const [],
        ),
      );
      await inbox.archive.recordReceiveGap(
        '1',
        since.add(const Duration(days: 1)),
      );
      inbox.updateDraft('2', 'gap checkpoint draft');
      await inbox.flushDrafts();
      await inbox.receiveEvent(
        incoming('gap-checkpoint-message'),
        DateTime.utc(2026, 10, 3),
      );
      final restartedStore = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async => disk[key] = value,
      );
      expect(await restartedStore.receiveGapSince('1'), since);
      expect((await restartedStore.threadsCheckpoint('1')).cursor, 'gap-page');
      expect(await restartedStore.receiveGapSince('9'), isNull);
      final saved = (await restartedStore.load('1')).single;
      expect(saved.draft, 'gap checkpoint draft');
      expect(saved.unreadCount, 1);
      expect(saved.messages.single.id, 'gap-checkpoint-message');
      await restartedStore.recordReceiveGap(
        '1',
        since.subtract(const Duration(days: 1)),
      );
      expect(
        await restartedStore.receiveGapSince('1'),
        since.subtract(const Duration(days: 1)),
      );
      inbox.dispose();
      inbox = TwitchWhisperInboxController(
        api: api,
        store: restartedStore,
        receiveInBackground: false,
      );
      await inbox.refreshSession();
      expect(inbox.historyRecoveryNeeded, true);
      expect(api.sent, 0);
    },
  );

  test(
    'Receive gap checkpoint failure preserves archive and retries on reload',
    () async {
      inbox.dispose();
      // Start with an archive without a prior receiving lifetime, so the first
      // socket gap must be persisted rather than already covered by restart.
      final initial = jsonDecode(disk['vioclass_twitch_whispers_v1_1']!) as Map;
      initial.remove('receiveSessionStartedAt');
      disk['vioclass_twitch_whispers_v1_1'] = jsonEncode(initial);
      var unavailable = false;
      final store = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async {
          if (unavailable) {
            throw StateError('fake checkpoint write failure');
          }
          disk[key] = value;
        },
      );
      inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        receiveInBackground: false,
      );
      await inbox.refreshSession();
      final before = disk['vioclass_twitch_whispers_v1_1'];
      unavailable = true;
      inbox.recordReceiveGap('1');
      expect(await store.receiveGapSince('1'), isNull);
      expect(inbox.historyRecoveryNeeded, true);
      expect(inbox.errorText, contains('缺口紀錄尚未保存'));
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      unavailable = false;
      await inbox.refreshSession();
      expect(await store.receiveGapSince('1'), isNotNull);
      inbox.clearSession();
      await inbox.refreshSession();
      expect(inbox.historyRecoveryNeeded, true);
    },
  );

  test(
    'Invalid receive gap checkpoint is rejected without overwriting data',
    () async {
      final raw = jsonDecode(disk['vioclass_twitch_whispers_v1_1']!) as Map;
      for (final invalid in [true, 123, 'bad', '2026-02-30T00:00:00.000Z']) {
        raw['receiveGapSince'] = invalid;
        final corrupt = jsonEncode(raw);
        disk['vioclass_twitch_whispers_v1_1'] = corrupt;
        await expectLater(
          inbox.archive.receiveGapSince('1'),
          throwsA(isA<TwitchWhisperArchiveException>()),
        );
        await expectLater(
          inbox.archive.recordReceiveGap('1', DateTime.utc(2026, 10, 3)),
          throwsA(isA<TwitchWhisperArchiveException>()),
        );
        expect(disk['vioclass_twitch_whispers_v1_1'], corrupt);
      }
    },
  );

  test(
    'Changing owner during App recovery releases old wait without displaying late pages',
    () async {
      final store = inbox.archive;
      inbox.dispose();
      final history = _FakeHistory(api.client);
      final threads = _FakeThreads(api.client)..gate = Completer<void>();
      inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        historyApi: history,
        threadsApi: threads,
        receiveInBackground: false,
      );
      await inbox.refreshSession();
      final running = inbox.recoverHistory();
      while (threads.calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      var newOwnerNotified = false;
      inbox.addListener(() {
        if (inbox.ownerId == '9' && !inbox.recoveringHistory) {
          newOwnerNotified = true;
        }
      });
      inbox.clearSession();
      api.owner = '9';
      await inbox.refreshSession();
      await running;
      threads.gate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(inbox.ownerId, '9');
      expect(newOwnerNotified, true);
      expect(inbox.conversations, isEmpty);
      expect(inbox.recoveryError, isNull);
      expect(inbox.recoveryProgress, isNull);
      expect((await store.recoveryCheckpoint('1'))!.phase, 'threads');
    },
  );

  test(
    'App recovery exposes committing and ignores cancellation until the page is saved',
    () async {
      inbox.dispose();
      final gate = Completer<void>();
      var committing = false;
      final store = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async {
          final checkpoint = (jsonDecode(value) as Map)['receiveRecovery'];
          if (checkpoint is Map && checkpoint['phase'] == 'history') {
            committing = true;
            await gate.future;
          }
          disk[key] = value;
        },
      );
      final history = _FakeHistory(api.client);
      final threads = _FakeThreads(api.client);
      inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        historyApi: history,
        threadsApi: threads,
        receiveInBackground: false,
      );
      await inbox.refreshSession();
      final running = inbox.recoverHistory();
      while (!committing) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(inbox.savingRecovery, true);
      expect(inbox.canCancelRecovery, false);
      inbox.cancelRecovery();
      gate.complete();
      await running;
      expect(inbox.recoveryProgress!.complete, true);
      expect(inbox.recoveryError, isNull);
      expect(inbox.savingRecovery, false);
    },
  );

  for (final size in [
    const Size(1000, 760),
    const Size(390, 844),
    const Size(390, 260),
  ]) {
    testWidgets(
      'Receive gap recovery entry points remain honest and usable at $size',
      (tester) async {
        late _FakeHistory history;
        late _FakeThreads threads;
        await tester.runAsync(() async {
          final store = inbox.archive;
          inbox.dispose();
          history = _FakeHistory(api.client);
          threads = _FakeThreads(api.client);
          inbox = TwitchWhisperInboxController(
            api: api,
            store: store,
            historyApi: history,
            threadsApi: threads,
            receiveInBackground: false,
          );
          await inbox.refreshSession();
          await inbox.startConversation('peer');
          inbox.recordReceiveGap('1');
          inbox.receiveStatus = '私訊收件已連線';
        });
        await _openPrivateWidget(tester, inbox, size: size);
        final compact = size.height < 310;
        if (compact) {
          expect(find.byTooltip('可能有未恢復的收件區間；連線不代表歷史已補齊。'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('whisper-gap-menu')));
          await tester.pumpAndSettle();
        } else {
          expect(find.text('可能有未恢復的收件區間；連線不代表歷史已補齊。'), findsOneWidget);
        }
        await tester.tap(find.byKey(const ValueKey('whisper-gap-threads')));
        await _advancePrivateWidget(tester);
        expect(threads.calls, 1);
        expect(inbox.historyRecoveryNeeded, true);
        if (compact) {
          await tester.tap(find.byKey(const ValueKey('whisper-gap-menu')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const ValueKey('whisper-gap-history')));
        await _advancePrivateWidget(tester);
        expect(history.cursors, [null]);
        expect(inbox.historyRecoveryNeeded, true);
        expect(api.sent, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await _advancePrivateWidget(tester);
      },
    );
  }

  test(
    'App recovery cancellation blocks conflicts and retries without mixing new owner',
    () async {
      final store = inbox.archive;
      inbox.dispose();
      final history = _FakeHistory(api.client);
      final threads = _FakeThreads(api.client)..gate = Completer<void>();
      inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        historyApi: history,
        threadsApi: threads,
        receiveInBackground: false,
      );
      await inbox.refreshSession();
      final running = inbox.recoverHistory();
      while (threads.calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(inbox.recoveringHistory, true);
      expect(inbox.managingHistory, true);
      expect(inbox.canCancelRecovery, true);
      await inbox.syncThreads();
      await inbox.sendActiveMessage();
      expect(threads.calls, 1);
      expect(api.sent, 0);
      inbox.cancelRecovery();
      await running;
      expect(inbox.recoveryError, contains('取消'));
      expect(inbox.recoveryProgress!.phase, 'threads');
      expect(inbox.recoveringHistory, false);
      threads.gate!.complete();
      threads.gate = null;
      await inbox.recoverHistory();
      expect(inbox.recoveryProgress!.complete, true);
      expect(inbox.conversations.map((p) => p.userId), containsAll(['2', '3']));
      expect(inbox.recoveryStatus, contains('不保證'));
      expect(inbox.managingHistory, false);
      api.owner = '9';
      await inbox.refreshSession();
      expect(inbox.recoveryProgress, isNull);
      expect(inbox.conversations, isEmpty);
    },
  );

  for (final size in [
    const Size(1000, 760),
    const Size(390, 844),
    const Size(390, 260),
  ]) {
    testWidgets(
      'App full history recovery menu starts, cancels and resumes at $size',
      (tester) async {
        late _FakeThreads threads;
        await tester.runAsync(() async {
          final store = inbox.archive;
          inbox.dispose();
          final history = _FakeHistory(api.client);
          threads = _FakeThreads(api.client)..gate = Completer<void>();
          inbox = TwitchWhisperInboxController(
            api: api,
            store: store,
            historyApi: history,
            threadsApi: threads,
            receiveInBackground: false,
          );
          await inbox.refreshSession();
          await inbox.startConversation('peer');
        });
        await _openPrivateWidget(tester, inbox, size: size);
        await tester.tap(find.byKey(const ValueKey('whisper-recovery-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('恢復全部對話歷史／續接'));
        await _advanceRunningRecoveryWidget(tester);
        expect(
          inbox.recoveringHistory,
          true,
          reason:
              'calls=${threads.calls}, error=${inbox.recoveryError}, status=${inbox.recoveryStatus}',
        );
        await tester.tap(find.byKey(const ValueKey('whisper-recovery-menu')));
        await _advanceRunningRecoveryWidget(tester);
        await tester.tap(find.text('取消恢復，保留進度'));
        await _advancePrivateWidget(tester);
        expect(inbox.recoveringHistory, false);
        expect(inbox.recoveryError, contains('取消'));
        threads.gate!.complete();
        threads.gate = null;
        await tester.tap(find.byKey(const ValueKey('whisper-recovery-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('恢復全部對話歷史／續接'));
        for (var i = 0; i < 4; i++) {
          await _advanceRunningRecoveryWidget(tester);
        }
        expect(inbox.recoveryProgress!.complete, true);
        expect(inbox.recoveringHistory, false);
        expect(inbox.recoveryError, isNull);
        expect(api.sent, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await _advancePrivateWidget(tester);
      },
    );
  }

  test(
    'App recovery timeout keeps original discovery cursor and ignores late page',
    () async {
      final store = inbox.archive;
      inbox.dispose();
      final history = _FakeHistory(api.client);
      final threads = _FakeThreads(api.client)..gate = Completer<void>();
      inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        historyApi: history,
        threadsApi: threads,
        receiveInBackground: false,
        recoverySyncTimeout: const Duration(milliseconds: 20),
      );
      await inbox.refreshSession();
      await inbox.recoverHistory();
      expect(inbox.recoveryError, contains('逾時'));
      expect(inbox.recoveryProgress!.phase, 'threads');
      expect(inbox.recoveryProgress!.cursor, isNull);
      final before = disk['vioclass_twitch_whispers_v1_1'];
      threads.gate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      threads.gate = null;
      await inbox.recoverHistory();
      expect(inbox.recoveryProgress!.complete, true);
      expect(inbox.recoveryError, isNull);
      expect(api.sent, 0);
    },
  );

  test(
    'App recovery exposes capacity error without clearing progress or retrying automatically',
    () async {
      inbox.dispose();
      final history = _FakeHistory(api.client);
      final threads = _FakeThreads(api.client);
      final metadata =
          jsonDecode(disk['vioclass_twitch_whispers_v1_1']!) as Map;
      metadata['conversations'] = List.generate(
        500,
        (i) => TwitchWhisperConversation(
          userId: '${i + 10}',
          login: 'peer',
          displayName: 'Peer',
          draft: 'keep draft',
        ).toJson(),
      );
      disk['vioclass_twitch_whispers_v1_1'] = jsonEncode(metadata);
      final store = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async => disk[key] = value,
      );
      inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        historyApi: history,
        threadsApi: threads,
        receiveInBackground: false,
      );
      await inbox.refreshSession();
      await inbox.recoverHistory();
      expect(inbox.recoveryError, contains('五百個'));
      expect(inbox.recoveryProgress!.phase, 'threads');
      expect(inbox.recoveryProgress!.cursor, isNull);
      expect(inbox.conversations, hasLength(500));
      expect(inbox.conversations.every((p) => p.draft == 'keep draft'), true);
      expect(threads.calls, 1);
      expect(api.sent, 0);
    },
  );

  test(
    'App new gap interrupts recovery honestly and retry starts fresh',
    () async {
      final store = inbox.archive;
      inbox.dispose();
      final history = _FakeHistory(api.client);
      final threads = _FakeThreads(api.client)..gate = Completer<void>();
      inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        historyApi: history,
        threadsApi: threads,
        receiveInBackground: false,
      );
      await inbox.refreshSession();
      final pending = inbox.recoverHistory();
      while (threads.calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      inbox.recordReceiveGap('1');
      await store.load('1');
      threads.gate!.complete();
      await pending;
      expect(inbox.recoveryError, contains('新收件缺口'));
      expect(inbox.recoveryStatus, isNull);
      expect(inbox.historyRecoveryNeeded, true);
      threads.gate = null;
      await inbox.recoverHistory();
      expect(threads.requestedCursors, [null, null, 'next']);
      expect(inbox.recoveryError, isNull);
      expect(inbox.recoveryProgress!.complete, true);
      expect(api.sent, 0);
    },
  );

  test(
    'App gap identity survives retries but changes for each distinct signal',
    () async {
      final store = inbox.archive;
      String? observationId() =>
          (jsonDecode(disk['vioclass_twitch_whispers_v1_1']!)
                  as Map)['receiveGapObservationId']
              as String?;
      inbox.recordReceiveGap('1');
      await store.load('1');
      final firstId = observationId();
      expect(firstId, matches(RegExp(r'^[0-9a-f]{32}$')));
      await inbox.refreshSession();
      expect(observationId(), firstId);
      inbox.recordReceiveGap('9');
      await store.load('1');
      expect(observationId(), firstId);
      inbox.recordReceiveGap('1');
      await store.load('1');
      final secondId = observationId();
      expect(secondId, isNot(firstId));
      await inbox.refreshSession();
      expect(observationId(), secondId);
      expect(api.sent, 0);
    },
  );

  test(
    'App cannot recover against an unsaved new gap and retries persistence first',
    () async {
      inbox.dispose();
      var unavailable = false;
      final store = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async {
          if (unavailable) throw StateError('fake gap save failure');
          disk[key] = value;
        },
      );
      final history = _FakeHistory(api.client);
      final threads = _FakeThreads(api.client);
      inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        historyApi: history,
        threadsApi: threads,
        receiveInBackground: false,
      );
      await inbox.refreshSession();
      final before = disk['vioclass_twitch_whispers_v1_1'];
      unavailable = true;
      inbox.recordReceiveGap('1');
      await store.load('1');
      await inbox.recoverHistory();
      expect(threads.calls, 0);
      expect(inbox.recoveryError, isNotNull);
      expect(inbox.errorText, contains('缺口紀錄尚未保存'));
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      unavailable = false;
      await inbox.recoverHistory();
      expect(inbox.recoveryError, isNull);
      expect(inbox.recoveryProgress!.complete, true);
      expect(inbox.recoveryProgress!.gapObservedAt, isNotNull);
      expect(api.sent, 0);
    },
  );

  test(
    'Acknowledged old gap cannot overwrite a new account receiving lifetime',
    () async {
      final store = inbox.archive;
      await store.saveDraft('1', inbox.activeConversation!, 'retained draft');
      inbox.recordReceiveGap('1');
      await store.load('1');
      final oldWork = await store.beginRecovery('1');
      final oldId = oldWork.gapObservationId;
      expect(oldId, isNotNull);
      api.owner = '9';
      await inbox.refreshSession();
      api.owner = '1';
      await inbox.refreshSession();
      final returned =
          jsonDecode(disk['vioclass_twitch_whispers_v1_1']!) as Map;
      expect(returned['receiveGapObservationId'], isNot(oldId));
      expect(await store.recoveryNeedsRestart('1', oldWork), true);
      final newId = returned['receiveGapObservationId'];
      await inbox.refreshSession();
      expect(
        (jsonDecode(disk['vioclass_twitch_whispers_v1_1']!)
            as Map)['receiveGapObservationId'],
        newId,
      );
      expect(inbox.conversations.single.draft, 'retained draft');
      expect(api.sent, 0);
    },
  );

  test(
    'App backup capacity failure keeps archive and reports the actual reason without sending',
    () async {
      inbox.dispose();
      final store = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async => disk[key] = value,
        maxBackupBytes: 256,
      );
      inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        receiveInBackground: false,
      );
      await inbox.refreshSession();
      final before = disk['vioclass_twitch_whispers_v1_1'];
      await expectLater(
        inbox.exportBackup(),
        throwsA(isA<TwitchWhisperArchiveException>()),
      );
      expect(await inbox.importBackup('x' * 257), isNull);
      expect(inbox.errorText, contains('UTF-8'));
      expect(inbox.errorText, contains('256'));
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      expect(api.sent, 0);
    },
  );

  test(
    'An older successful commit cannot acknowledge a newer pending gap',
    () async {
      inbox.dispose();
      final gate = Completer<void>();
      var delayFirst = false;
      final writtenIds = <String>[];
      final store = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async {
          final id = (jsonDecode(value) as Map)['receiveGapObservationId'];
          if (delayFirst && key.endsWith('_1') && id is String) {
            writtenIds.add(id);
            if (writtenIds.length == 1) await gate.future;
          }
          disk[key] = value;
        },
      );
      inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        receiveInBackground: false,
      );
      await inbox.refreshSession();
      delayFirst = true;
      inbox.recordReceiveGap('1');
      while (writtenIds.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      inbox.recordReceiveGap('1');
      gate.complete();
      await store.load('1');
      expect(writtenIds, hasLength(2));
      expect(writtenIds[1], isNot(writtenIds[0]));
      await inbox.refreshSession();
      expect(writtenIds, hasLength(2));
      expect(
        (jsonDecode(disk['vioclass_twitch_whispers_v1_1']!)
            as Map)['receiveGapObservationId'],
        writtenIds.last,
      );
      expect(api.sent, 0);
    },
  );

  test(
    'A commit finishing after owner change is acknowledged without replaying into the next lifetime',
    () async {
      inbox.dispose();
      final gate = Completer<void>();
      String? delayedId;
      var delay = false;
      final store = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async {
          final id = (jsonDecode(value) as Map)['receiveGapObservationId'];
          if (delay && key.endsWith('_1') && id is String) {
            delayedId = id;
            await gate.future;
          }
          disk[key] = value;
        },
      );
      inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        receiveInBackground: false,
      );
      await inbox.refreshSession();
      delay = true;
      inbox.recordReceiveGap('1');
      while (delayedId == null) {
        await Future<void>.delayed(Duration.zero);
      }
      api.owner = '9';
      final refresh = inbox.refreshSession();
      await Future<void>.delayed(Duration.zero);
      delay = false;
      gate.complete();
      await refresh;
      expect(inbox.ownerId, '9');
      expect(inbox.conversations, isEmpty);
      expect(
        (jsonDecode(disk['vioclass_twitch_whispers_v1_1']!)
            as Map)['receiveGapObservationId'],
        delayedId,
      );
      api.owner = '1';
      await inbox.refreshSession();
      expect(
        (jsonDecode(disk['vioclass_twitch_whispers_v1_1']!)
            as Map)['receiveGapObservationId'],
        isNot(delayedId),
      );
      expect(api.sent, 0);
    },
  );

  test(
    'New App receiving lifetime restores conservative offline uncertainty without rotating on refresh',
    () async {
      final first = DateTime.parse(
        (jsonDecode(disk['vioclass_twitch_whispers_v1_1']!)
                as Map)['receiveSessionStartedAt']
            as String,
      );
      expect(await inbox.archive.receiveGapSince('1'), isNull);
      await inbox.refreshSession();
      expect(
        (jsonDecode(disk['vioclass_twitch_whispers_v1_1']!)
            as Map)['receiveSessionStartedAt'],
        first.toIso8601String(),
      );
      expect(inbox.historyRecoveryNeeded, false);
      final store = inbox.archive;
      inbox.dispose();
      inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        receiveInBackground: false,
      );
      await inbox.refreshSession();
      expect(await store.receiveGapSince('1'), first);
      expect(inbox.historyRecoveryNeeded, true);
      expect(inbox.conversations.single.userId, '2');
      api.owner = '9';
      await inbox.refreshSession();
      expect(inbox.historyRecoveryNeeded, false);
      expect(inbox.conversations, isEmpty);
      expect(await store.receiveGapSince('1'), first);
      api.owner = '1';
      await inbox.refreshSession();
      expect(inbox.historyRecoveryNeeded, true);
      expect(api.sent, 0);
    },
  );

  test(
    'Receive lifetime checkpoint write failure remains retryable on same owner refresh',
    () async {
      inbox.dispose();
      var unavailable = true;
      final before = disk['vioclass_twitch_whispers_v1_1'];
      final store = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async {
          if (unavailable) {
            throw StateError('fake session checkpoint failure');
          }
          disk[key] = value;
        },
      );
      inbox = TwitchWhisperInboxController(
        api: api,
        store: store,
        receiveInBackground: false,
      );
      await inbox.refreshSession();
      expect(inbox.errorText, contains('會話紀錄尚未保存'));
      expect(disk['vioclass_twitch_whispers_v1_1'], before);
      expect(inbox.ownerId, '1');
      unavailable = false;
      await inbox.refreshSession();
      expect(inbox.errorText, isNull);
      expect(inbox.historyRecoveryNeeded, true);
      expect(await store.receiveGapSince('1'), isNotNull);
    },
  );

  Future<_FakeHistory> enableHistory() async {
    final archive = inbox.archive;
    inbox.dispose();
    final history = _FakeHistory(api.client);
    inbox = TwitchWhisperInboxController(
      api: api,
      historyApi: history,
      store: archive,
      receiveInBackground: false,
    );
    await inbox.refreshSession();
    await inbox.startConversation('peer');
    return history;
  }

  for (final fails in [false, true]) {
    testWidgets(
      'Automatic inbox open uses cache and paginates; failure=$fails',
      (tester) async {
        final archive = inbox.archive;
        inbox.dispose();
        final threads = _FakeThreads(api.client)..fail = fails;
        final history = _FakeHistory(api.client);
        inbox = TwitchWhisperInboxController(
          api: api,
          store: archive,
          threadsApi: threads,
          historyApi: history,
          receiveInBackground: false,
        );
        await tester.runAsync(() async {
          await inbox.refreshSession();
          await inbox.startConversation('peer');
        });
        inbox.updateDraft('2', 'keep automatic draft');
        await _openPrivateWidget(
          tester,
          inbox,
          automaticSync: true,
          size: const Size(1000, 760),
        );
        await _advancePrivateWidget(tester);
        expect(threads.requestedCursors, fails ? [null] : [null, 'next']);
        expect(history.cursors, [null]);
        expect(inbox.activeConversation!.draft, 'keep automatic draft');
        expect(find.text('同步對話列表'), findsNothing);
        expect(find.text('同步此對話歷史'), findsNothing);
        expect(
          find.byKey(const ValueKey('whisper-recovery-menu')),
          findsNothing,
        );
        expect(find.text('可能有未恢復的收件區間；連線不代表歷史已補齊。'), findsNothing);
        expect(find.byTooltip('同步 Twitch 私訊歷史'), findsNothing);
        if (fails) {
          expect(find.text('重試對話同步'), findsOneWidget);
          threads.fail = false;
          await tester.tap(find.text('重試對話同步'));
          await _advancePrivateWidget(tester);
          expect(threads.requestedCursors, [null, null, 'next']);
        } else {
          expect(inbox.threadsComplete, true);
          expect(find.text('重試對話同步'), findsNothing);
        }
        final before = threads.calls;
        await tester.pump(const Duration(seconds: 1));
        expect(threads.calls, before);
        expect(api.sent, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await _advancePrivateWidget(tester);
      },
    );
  }

  testWidgets(
    'Automatic history follows scrolling without pulling reader to tail',
    (tester) async {
      final history = (await tester.runAsync(enableHistory))!..extraPage = true;
      await tester.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          await inbox.receiveEvent({
            'from_user_id': '2',
            'to_user_id': '1',
            'whisper_id': 'auto-anchor-$i',
            'whisper': {'text': 'anchor $i'},
          }, DateTime.utc(2026, 1, 1, 0, i));
        }
      });
      await _openPrivateWidget(tester, inbox, automaticSync: true);
      await _advancePrivateWidget(tester);
      expect(history.cursors, [null]);
      final list = find.byKey(const ValueKey('whisper-message-list'));
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)).first,
          )
          .position;
      expect(position.extentBefore, lessThanOrEqualTo(.5));
      position.jumpTo(position.maxScrollExtent);
      await _advancePrivateWidget(tester);
      expect(history.cursors, [null, 'older']);
      expect(inbox.readingLatest, false);
      expect(position.extentBefore, greaterThan(90));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _advancePrivateWidget(tester);
    },
  );

  testWidgets('Closing automatic inbox stops subsequent pages and history', (
    tester,
  ) async {
    final archive = inbox.archive;
    inbox.dispose();
    final gate = Completer<void>();
    final threads = _FakeThreads(api.client)..gate = gate;
    final history = _FakeHistory(api.client);
    inbox = TwitchWhisperInboxController(
      api: api,
      store: archive,
      threadsApi: threads,
      historyApi: history,
      receiveInBackground: false,
    );
    await tester.runAsync(() async {
      await inbox.refreshSession();
      await inbox.startConversation('peer');
    });
    await _openPrivateWidget(tester, inbox, automaticSync: true);
    expect(threads.calls, 1);
    await tester.pumpWidget(const SizedBox());
    await _advancePrivateWidget(tester);
    gate.complete();
    await _advancePrivateWidget(tester);
    expect(threads.calls, 1);
    expect(history.cursors, isEmpty);
    expect(api.sent, 0);
    expect(tester.takeException(), isNull);
  });

  for (final outcome in ['success', 'failure', 'account-change']) {
    testWidgets(
      'Private inbox authorization retry handles $outcome without sending',
      (tester) async {
        final archive = inbox.archive;
        inbox.dispose();
        final threads = _FakeThreads(api.client);
        inbox = TwitchWhisperInboxController(
          api: api,
          store: archive,
          threadsApi: threads,
          receiveInBackground: false,
        );
        await tester.runAsync(inbox.refreshSession);
        inbox.updateDraft('2', 'preserve authorization draft');
        var authorizations = 0;
        await _openPrivateWidget(
          tester,
          inbox,
          onAuthorize: () async {
            authorizations++;
            if (outcome == 'failure') throw StateError('fake consent failure');
            if (outcome == 'account-change') api.owner = '9';
          },
        );
        await tester.tap(find.byTooltip('本機私訊歷史'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('授權並重試對話同步'));
        await _advancePrivateWidget(tester);
        expect(authorizations, 1);
        expect(threads.calls, outcome == 'success' ? 1 : 0);
        expect(api.sent, 0);
        final saved = await tester.runAsync(() => archive.load('1'));
        expect(
          saved!.singleWhere((peer) => peer.userId == '2').draft,
          'preserve authorization draft',
        );
        if (outcome == 'account-change') expect(inbox.ownerId, '9');
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await _advancePrivateWidget(tester);
      },
    );
  }

  for (final size in [
    const Size(1000, 760),
    const Size(390, 844),
    const Size(390, 260),
  ]) {
    testWidgets('Inbox failure retry and cancel remain usable at $size', (
      tester,
    ) async {
      final archive = inbox.archive;
      inbox.dispose();
      final remote = _FakeThreads(api.client)..fail = true;
      inbox = TwitchWhisperInboxController(
        api: api,
        threadsApi: remote,
        store: archive,
        receiveInBackground: false,
      );
      await tester.runAsync(inbox.refreshSession);
      inbox.updateDraft('2', 'keep retry draft');
      await _openPrivateWidget(tester, inbox, size: size);
      await tester.tap(find.byTooltip('本機私訊歷史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('同步 Twitch 對話'));
      await _advancePrivateWidget(tester);
      expect(find.text('fake inbox unavailable'), findsOneWidget);
      remote.fail = false;
      await tester.ensureVisible(find.text('重試對話同步'));
      await tester.tap(find.text('重試對話同步'));
      await _advancePrivateWidget(tester);
      expect(remote.calls, 2);
      expect(
        inbox.conversations.singleWhere((peer) => peer.userId == '2').draft,
        'keep retry draft',
      );
      final scrollView = find.byType(CustomScrollView).first;
      await tester.drag(scrollView, const Offset(0, 500));
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      remote.gate = gate;
      await tester.tap(find.byTooltip('本機私訊歷史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('載入更多對話'));
      await _advancePrivateWidget(tester);
      expect(inbox.canCancelThreadsSync, true);
      await tester.ensureVisible(find.text('取消對話同步'));
      await tester.tap(find.text('取消對話同步'));
      await _advancePrivateWidget(tester);
      expect(inbox.syncingThreads, false);
      expect(inbox.threadsStatus, contains('已取消'));
      expect(
        (await tester.runAsync(() => archive.threadsCheckpoint('1')))!.cursor,
        'next',
      );
      gate.complete();
      await _advancePrivateWidget(tester);
      expect(inbox.threadsComplete, false);
      expect(api.sent, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _advancePrivateWidget(tester);
    });
  }

  testWidgets('Closing private inbox during authorization prevents late sync', (
    tester,
  ) async {
    final archive = inbox.archive;
    inbox.dispose();
    final threads = _FakeThreads(api.client);
    inbox = TwitchWhisperInboxController(
      api: api,
      store: archive,
      threadsApi: threads,
      receiveInBackground: false,
    );
    await tester.runAsync(inbox.refreshSession);
    final consent = Completer<void>();
    await _openPrivateWidget(tester, inbox, onAuthorize: () => consent.future);
    await tester.tap(find.byTooltip('本機私訊歷史'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('授權並重試對話同步'));
    await _advancePrivateWidget(tester);
    await tester.tap(find.byTooltip('關閉'));
    await _advancePrivateWidget(tester);
    consent.complete();
    await _advancePrivateWidget(tester);
    expect(threads.calls, 0);
    expect(api.sent, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await _advancePrivateWidget(tester);
  });

  for (final switchAccount in [false, true]) {
    testWidgets(
      'Authorization joins Home session refresh before retry, account change=$switchAccount',
      (tester) async {
        final archive = inbox.archive;
        inbox.dispose();
        final threads = _FakeThreads(api.client);
        inbox = TwitchWhisperInboxController(
          api: api,
          store: archive,
          threadsApi: threads,
          receiveInBackground: false,
        );
        await tester.runAsync(inbox.refreshSession);
        final gate = Completer<void>();
        await _openPrivateWidget(
          tester,
          inbox,
          onAuthorize: () async {
            if (switchAccount) api.owner = '9';
            api.sessionGate = gate;
            unawaited(inbox.refreshSession());
          },
        );
        await tester.tap(find.byTooltip('本機私訊歷史'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('授權並重試對話同步'));
        for (var step = 0; step < 8; step++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump();
        }
        expect(inbox.loading, true);
        expect(threads.calls, 0);
        gate.complete();
        await _advancePrivateWidget(tester);
        expect(inbox.ownerId, switchAccount ? '9' : '1');
        expect(threads.calls, switchAccount ? 0 : 1);
        expect(api.sent, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await _advancePrivateWidget(tester);
      },
    );
  }

  for (final size in [
    const Size(1000, 760),
    const Size(390, 844),
    const Size(390, 260),
  ]) {
    testWidgets('Remote inbox menu and pagination work at $size', (
      tester,
    ) async {
      final archive = inbox.archive;
      inbox.dispose();
      inbox = TwitchWhisperInboxController(
        api: api,
        store: archive,
        threadsApi: _FakeThreads(api.client),
        receiveInBackground: false,
      );
      await tester.runAsync(inbox.refreshSession);
      await _openPrivateWidget(tester, inbox, size: size);
      await tester.tap(find.byTooltip('本機私訊歷史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('同步 Twitch 對話'));
      await _advancePrivateWidget(tester);
      if (size.height < 300) {
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -180),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('Remote peer'), findsOneWidget);
      expect(find.text('新對話\nTwitch 未讀 4（上次同步）'), findsOneWidget);
      if (size.height < 300) {
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, 300),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('本機私訊歷史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('載入更多對話'));
      await _advancePrivateWidget(tester);
      expect(inbox.threadsComplete, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _advancePrivateWidget(tester);
    });
  }

  for (final size in [
    const Size(1000, 760),
    const Size(390, 844),
    const Size(390, 260),
  ]) {
    testWidgets('History enabled menu works without overflow at $size', (
      tester,
    ) async {
      final history = await tester.runAsync(enableHistory);
      await _openPrivateWidget(tester, inbox, size: size);
      await tester.tap(find.byTooltip('同步 Twitch 私訊歷史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('同步近期歷史'));
      await _advancePrivateWidget(tester);
      expect(history!.cursors, [null]);
      expect(inbox.activeConversation!.messages, hasLength(5));
      await tester.tap(find.byTooltip('同步 Twitch 私訊歷史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('載入更早訊息'));
      await _advancePrivateWidget(tester);
      expect(history.cursors, [null, 'older']);
      expect(inbox.activeConversation!.remoteHistoryComplete, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _advancePrivateWidget(tester);
    });
  }

  for (final size in [
    const Size(1000, 760),
    const Size(390, 844),
    const Size(390, 260),
  ]) {
    testWidgets('History retry and cancellation menu works at $size', (
      tester,
    ) async {
      final history = (await tester.runAsync(enableHistory))!..fail = true;
      inbox.updateDraft('2', 'keep history retry draft');
      await _openPrivateWidget(tester, inbox, size: size);
      await tester.tap(find.byTooltip('同步 Twitch 私訊歷史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('同步近期歷史'));
      await _advancePrivateWidget(tester);
      expect(inbox.historyError, 'fake history unavailable');
      await tester.pump(const Duration(seconds: 3));
      history.fail = false;
      await tester.tap(find.byTooltip('同步 Twitch 私訊歷史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重試歷史同步'));
      await _advancePrivateWidget(tester);
      expect(history.cursors, [null, null]);
      expect(inbox.activeConversation!.draft, 'keep history retry draft');
      final gate = Completer<void>();
      history.gate = gate;
      await tester.tap(find.byTooltip('同步 Twitch 私訊歷史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('載入更早訊息'));
      await _advancePrivateWidget(tester);
      expect(inbox.canCancelHistorySync, true);
      await tester.tap(find.byTooltip('同步 Twitch 私訊歷史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消歷史同步'));
      await _advancePrivateWidget(tester);
      expect(inbox.syncingHistory, false);
      expect(inbox.historyStatus, contains('已取消'));
      gate.complete();
      await _advancePrivateWidget(tester);
      expect(inbox.activeConversation!.remoteHistoryCursor, 'older');
      expect(inbox.activeConversation!.messages, hasLength(5));
      expect(api.sent, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _advancePrivateWidget(tester);
    });
  }

  for (final scenario in [
    (size: const Size(1000, 760), scale: 1.0, inset: 0.0),
    (size: const Size(390, 844), scale: 1.0, inset: 0.0),
    (size: const Size(320, 640), scale: 1.3, inset: 250.0),
    (size: const Size(844, 390), scale: 1.0, inset: 220.0),
    (size: const Size(390, 260), scale: 1.4, inset: 0.0),
  ]) {
    for (final varied in [false, true]) {
      testWidgets(
        'Prepending history retains exact visible anchor at $scenario varied=$varied',
        (tester) async {
          final history = (await tester.runAsync(enableHistory))!
            ..extraPage = true
            ..variableHeights = varied;
          await tester.runAsync(() async {
            for (var i = 0; i < 40; i++) {
              await inbox.receiveEvent({
                'from_user_id': '2',
                'to_user_id': '1',
                'whisper_id': 'anchor-$i',
                'whisper': {'text': 'anchor live $i'},
              }, DateTime.utc(2026, 1, 1, 0, i));
            }
          });
          await _openPrivateWidget(
            tester,
            inbox,
            size: scenario.size,
            scale: scenario.scale,
            keyboardInset: scenario.inset,
          );
          final list = find.byKey(const ValueKey('whisper-message-list'));
          final position = tester
              .state<ScrollableState>(
                find
                    .descendant(of: list, matching: find.byType(Scrollable))
                    .first,
              )
              .position;
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          double anchorOffset(Finder target) =>
              tester.getTopLeft(target).dy - tester.getTopLeft(list).dy;
          final anchor = find.byKey(const ValueKey('anchor-0'));
          final before = anchorOffset(anchor);
          Future<void> older() async {
            await tester.tap(find.byTooltip('同步 Twitch 私訊歷史'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('載入更早訊息'));
            await _advancePrivateWidget(tester);
          }

          await older();
          expect(inbox.historyError, isNull);
          expect(inbox.activeConversation!.messages, hasLength(45));
          expect(anchorOffset(anchor), closeTo(before, 1));
          expect(position.maxScrollExtent, greaterThan(0));
          final pastAnchor = find.byKey(const ValueKey('remote-recent-4'));
          // Select an exact reading anchor independently of the compact
          // return-to-latest overlay; pointer arbitration is tested separately.
          for (var step = 0; step < 15; step++) {
            if (pastAnchor.evaluate().isNotEmpty &&
                tester.getRect(pastAnchor).overlaps(tester.getRect(list))) {
              break;
            }
            position.jumpTo(position.pixels + 40);
            await tester.pump();
          }
          await tester.pumpAndSettle();
          final pastOffset = anchorOffset(pastAnchor);
          await older();
          expect(anchorOffset(pastAnchor), closeTo(pastOffset, 1));
          await older();
          expect(anchorOffset(pastAnchor), closeTo(pastOffset, 1));
          expect(history.cursors, [null, 'older', 'oldest']);
          expect(find.textContaining('新私訊 ·'), findsNothing);
          expect(inbox.readingLatest, false);
          await tester.runAsync(
            () => inbox.receiveEvent({
              'from_user_id': '2',
              'to_user_id': '1',
              'whisper_id': 'anchor-new-tail',
              'whisper': {'text': 'new while reading history'},
            }, DateTime.utc(2026, 1, 2)),
          );
          await _advancePrivateWidget(tester);
          expect(inbox.activeConversation!.unreadCount, 1);
          expect(inbox.readingLatest, false);
          expect(anchorOffset(pastAnchor), closeTo(pastOffset, 1));
          expect(find.textContaining('新私訊 · 1 ·'), findsOneWidget);
          expect(
            tester.getRect(find.byType(TextField).last).bottom,
            lessThanOrEqualTo(scenario.size.height - scenario.inset + 1),
          );
          await tester.tap(find.textContaining('新私訊 · 1 ·'));
          await _advancePrivateWidget(tester);
          expect(inbox.readingLatest, true);
          expect(inbox.activeConversation!.unreadCount, 0);
          expect(find.textContaining('新私訊 ·'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await _advancePrivateWidget(tester);
        },
      );
    }
  }

  testWidgets(
    'History merge while reading older messages does not jump to tail or count as new',
    (tester) async {
      await tester.runAsync(enableHistory);
      await tester.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          await inbox.receiveEvent({
            'from_user_id': '2',
            'to_user_id': '1',
            'whisper_id': 'local-$i',
            'whisper': {'text': 'local message $i'},
          }, DateTime.utc(2026, 1, 1, 0, i));
        }
      });
      await _openPrivateWidget(tester, inbox);
      final list = find.byKey(const ValueKey('whisper-message-list'));
      final scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable.first).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(inbox.readingLatest, false);
      final beforeHistory = position.pixels;
      await tester.tap(find.byTooltip('同步 Twitch 私訊歷史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('載入更早訊息'));
      await _advancePrivateWidget(tester);
      expect(position.pixels, closeTo(beforeHistory, 1));
      expect(position.extentBefore, greaterThan(100));
      expect(inbox.readingLatest, false);
      expect(find.textContaining('新私訊 ·'), findsNothing);
      expect(inbox.activeConversation!.messages, hasLength(45));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _advancePrivateWidget(tester);
    },
  );

  for (final size in [const Size(1000, 760), const Size(390, 260)]) {
    testWidgets(
      'Imported history is quiet and first live receipt promotes exactly once at $size',
      (tester) async {
        await tester.runAsync(enableHistory);
        await tester.runAsync(() async {
          for (var i = 0; i < 40; i++) {
            await inbox.receiveEvent({
              'from_user_id': '2',
              'to_user_id': '1',
              'whisper_id': 'import-anchor-$i',
              'whisper': {'text': 'anchor $i'},
            }, DateTime.utc(2026, 1, 1, 0, i));
          }
        });
        await _openPrivateWidget(tester, inbox, size: size);
        final list = find.byKey(const ValueKey('whisper-message-list'));
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: list, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        final anchor = find.byKey(const ValueKey('import-anchor-0'));
        double offset() =>
            tester.getTopLeft(anchor).dy - tester.getTopLeft(list).dy;
        final before = offset();
        final imported = TwitchWhisperMessage(
          id: 'import-first-live',
          fromUserId: '2',
          toUserId: '1',
          text: 'imported message',
          timestamp: DateTime.utc(2026, 1, 2),
          state: TwitchWhisperMessageState.received,
        );
        final backup = jsonEncode({
          'version': 1,
          'ownerId': '1',
          'conversations': [
            TwitchWhisperConversation(
              userId: '2',
              login: 'peer',
              displayName: 'Peer',
              messages: [imported],
            ).toJson(),
          ],
        });
        int? added;
        var importFinished = false;
        unawaited(
          inbox.importBackup(backup).then((value) {
            added = value;
            importFinished = true;
          }),
        );
        await _advancePrivateWidget(tester);
        expect(importFinished, true);
        expect(added, 1);
        expect(find.textContaining('新私訊 ·'), findsNothing);
        expect(inbox.unreadCount, 0);
        expect(inbox.isHistoricalMessage(imported.id), true);
        expect(offset(), closeTo(before, 1));
        final event = {
          'from_user_id': '2',
          'to_user_id': '1',
          'whisper_id': imported.id,
          'whisper': {'text': imported.text},
        };
        Future<void> receive() async {
          var received = false;
          unawaited(
            inbox
                .receiveEvent(event, imported.timestamp)
                .then((_) => received = true),
          );
          await _advancePrivateWidget(tester);
          expect(received, true);
        }

        await receive();
        expect(inbox.unreadCount, 1);
        expect(inbox.isHistoricalMessage(imported.id), false);
        expect(find.textContaining('新私訊 · 1 ·'), findsOneWidget);
        await receive();
        expect(inbox.unreadCount, 1);
        expect(find.textContaining('新私訊 · 1 ·'), findsOneWidget);
        expect(offset(), closeTo(before, 1));
        expect(api.sent, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await _advancePrivateWidget(tester);
      },
    );
  }

  testWidgets(
    'History failure keeps draft and retry without profile or deletion actions',
    (tester) async {
      final history = await tester.runAsync(enableHistory);
      inbox.updateDraft('2', 'keep draft');
      history!.fail = true;
      await _openPrivateWidget(tester, inbox, size: const Size(390, 260));
      await tester.tap(find.byTooltip('同步 Twitch 私訊歷史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('同步近期歷史'));
      await _advancePrivateWidget(tester);
      expect(find.text('fake history unavailable'), findsOneWidget);
      expect(inbox.activeConversation!.draft, 'keep draft');
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byTooltip('同步 Twitch 私訊歷史'));
      await tester.pumpAndSettle();
      expect(find.text('更新對象資料'), findsNothing);
      expect(find.text('刪除本機對話'), findsNothing);
      expect(find.text('同步近期歷史'), findsOneWidget);
      expect(api.sent, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _advancePrivateWidget(tester);
    },
  );

  for (final size in [const Size(1100, 800), const Size(390, 260)]) {
    testWidgets('Connected inbox hides normal status at $size', (tester) async {
      inbox.receiveStatus = '私訊收件已連線';
      await _openPrivateWidget(tester, inbox, size: size);
      expect(find.text('私訊收件已連線'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _advancePrivateWidget(tester);
    });
    testWidgets('Authorized inbox hides top authorization at $size', (
      tester,
    ) async {
      expect(inbox.sessionReady, isTrue);
      await _openPrivateWidget(
        tester,
        inbox,
        size: size,
        onAuthorize: () async {},
      );
      expect(find.text('重新授權私訊'), findsNothing);
      expect(find.byTooltip('重新授權私訊'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _advancePrivateWidget(tester);
    });
  }

  testWidgets(
    'Private reauthorization saves drafts and prevents duplicate login',
    (tester) async {
      inbox.sessionReady = false;
      inbox.updateDraft('2', 'keep this draft');
      final consent = Completer<void>();
      var attempts = 0;
      await _openPrivateWidget(
        tester,
        inbox,
        onAuthorize: () {
          attempts++;
          return consent.future;
        },
      );
      await tester.tap(find.text('重新授權私訊'));
      await _advancePrivateWidget(tester);
      expect(attempts, 1);
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '重新授權私訊'),
      );
      expect(button.onPressed, isNull);
      expect((await inbox.archive.load('1')).single.draft, 'keep this draft');
      consent.complete();
      await _advancePrivateWidget(tester);
      expect(inbox.ownerId, '1');
      expect(inbox.conversations.single.draft, 'keep this draft');
      expect(api.sent, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Account changed during consent cannot retain the old private conversation',
    (tester) async {
      inbox.sessionReady = false;
      inbox.updateDraft('2', 'account one only');
      await _openPrivateWidget(
        tester,
        inbox,
        onAuthorize: () async {
          api.owner = '3';
        },
      );
      await tester.tap(find.text('重新授權私訊'));
      await _advancePrivateWidget(tester);
      expect(inbox.ownerId, '3');
      expect(inbox.conversations, isEmpty);
      expect(inbox.activePeerId, isNull);
      expect((await inbox.archive.load('1')).single.draft, 'account one only');
      expect(api.sent, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Consent failure keeps the private draft and permits retry', (
    tester,
  ) async {
    inbox.sessionReady = false;
    inbox.updateDraft('2', 'retry draft');
    await _openPrivateWidget(
      tester,
      inbox,
      onAuthorize: () async {
        throw StateError('fake failure');
      },
    );
    await tester.tap(find.text('重新授權私訊'));
    await _advancePrivateWidget(tester);
    expect(inbox.activeConversation!.draft, 'retry draft');
    expect(find.text('私訊重新授權未完成，原本對話與草稿仍保留。'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '重新授權私訊'))
          .onPressed,
      isNotNull,
    );
    expect(api.sent, 0);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Compact private sheet offers authorization and ignores completion after close',
    (tester) async {
      inbox.sessionReady = false;
      final consent = Completer<void>();
      var attempts = 0;
      await _openPrivateWidget(
        tester,
        inbox,
        size: const Size(390, 260),
        onAuthorize: () {
          attempts++;
          return consent.future;
        },
      );
      await tester.tap(find.byTooltip('重新授權私訊'));
      await _advancePrivateWidget(tester);
      expect(attempts, 1);
      await tester.tap(find.byTooltip('關閉').first);
      await _advancePrivateWidget(tester);
      consent.complete();
      await _advancePrivateWidget(tester);
      expect(inbox.panelVisible, isFalse);
      expect(api.sent, 0);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'profile private entry selects exact peer without sending or losing drafts',
    () async {
      final launcher = TwitchAppSettingsLauncher();
      final update = VioClassUpdateController();
      addTearDown(() {
        launcher.detach();
        launcher.dispose();
        update.dispose();
      });
      var opened = 0;
      launcher.attach(
        () async {},
        updateController: update,
        updateOpener: () async {},
        whisperInbox: inbox,
        whisperOpener: () async {
          opened++;
        },
      );
      inbox.updateDraft('2', 'retained draft');
      await launcher.openWhisperTo('peer', ownerId: '1', peerId: '2');
      expect(opened, 1);
      expect(inbox.activePeerId, '2');
      expect(inbox.activeConversation!.draft, 'retained draft');
      expect(api.sent, 0);
      await expectLater(
        launcher.openWhisperTo('peer', ownerId: '3', peerId: '2'),
        throwsStateError,
      );
      await expectLater(
        launcher.openWhisperTo('peer', ownerId: '1', peerId: '99'),
        throwsStateError,
      );
      expect(opened, 1);
      expect(api.sent, 0);
    },
  );

  test(
    'Windows whisper notification stores account target without message content',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        twitchAppNotificationCenter.clear();
      });
      twitchAppNotificationCenter.clear();
      await twitchSystemNotificationService.showWhisper(
        sender: 'Peer',
        userId: '2',
        ownerId: '1',
      );
      final item = twitchAppNotificationCenter.items.single;
      expect(item.whisperTarget!.payload, 'whisper:1:2');
      expect(item.message, '開啟私訊查看對話');
      await twitchSystemNotificationService.showWhisper(
        sender: 'Peer',
        userId: '2',
        ownerId: '',
      );
      expect(twitchAppNotificationCenter.items.length, 1);
    },
  );

  test('notification payload requires exact owner and peer IDs', () {
    const target = TwitchWhisperNotificationTarget(ownerId: '1', peerId: '2');
    expect(
      TwitchWhisperNotificationTarget.fromPayload(target.payload)!.peerId,
      '2',
    );
    for (final payload in [
      null,
      'whisper:2',
      'whisper:1:1',
      'whisper:1:name',
      'whisper:1:2:3',
      'live:1:2',
    ]) {
      expect(TwitchWhisperNotificationTarget.fromPayload(payload), isNull);
    }
  });

  test(
    'notification opens local ID without login lookup and rejects stale context',
    () async {
      final launcher = TwitchAppSettingsLauncher();
      final update = VioClassUpdateController();
      addTearDown(() {
        launcher.detach();
        launcher.dispose();
        update.dispose();
      });
      var opened = 0;
      launcher.attach(
        () async {},
        updateController: update,
        updateOpener: () async {},
        whisperInbox: inbox,
        whisperOpener: () async {
          opened++;
        },
      );
      inbox.updateDraft('2', 'notification must preserve draft');
      await inbox.selectConversation(null);
      final lookups = api.lookups;
      await launcher.openWhisperConversation(ownerId: '1', peerId: '2');
      expect(opened, 1);
      expect(api.lookups, lookups);
      expect(
        inbox.activeConversation!.draft,
        'notification must preserve draft',
      );
      await expectLater(
        launcher.openWhisperConversation(ownerId: '3', peerId: '2'),
        throwsStateError,
      );
      await expectLater(
        launcher.openWhisperConversation(ownerId: '1', peerId: '99'),
        throwsStateError,
      );
      final pending = launcher.openWhisperConversation(
        ownerId: '1',
        peerId: '2',
      );
      launcher.detach();
      await expectLater(pending, throwsStateError);
      expect(opened, 1);
      expect(api.sent, 0);
    },
  );

  for (final fromPanel in [false, true]) {
    testWidgets(
      'private notification opens exact conversation from ${fromPanel ? "panel" : "toast"}',
      (tester) async {
        final update = VioClassUpdateController();
        twitchAppNotificationCenter.clear();
        var opened = 0;
        twitchAppSettingsLauncher.attach(
          () async {},
          updateController: update,
          updateOpener: () async {},
          whisperInbox: inbox,
          whisperOpener: () async {
            opened++;
          },
        );
        addTearDown(() {
          twitchAppSettingsLauncher.detach();
          twitchAppNotificationCenter.clear();
          update.dispose();
        });
        await tester.pumpWidget(
          const MaterialApp(
            home: TwitchAppNotificationOverlay(
              child: Scaffold(body: Text('app')),
            ),
          ),
        );
        twitchAppNotificationCenter.show(
          title: 'Peer private notification',
          message: 'open private chat',
          whisperTarget: const TwitchWhisperNotificationTarget(
            ownerId: '1',
            peerId: '2',
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        if (fromPanel) {
          await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
          await tester.pump();
        }
        await tester.tap(find.text('Peer private notification'));
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(Duration.zero);
          });
          await tester.pump();
        }
        expect(opened, 1);
        expect(inbox.activePeerId, '2');
        expect(api.sent, 0);
        expect(find.text('Peer private notification'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  test(
    'notification waits for attachment, navigation and session before opening once',
    () async {
      final launcher = TwitchAppSettingsLauncher();
      final update = VioClassUpdateController();
      final loadingInbox = TwitchWhisperInboxController(
        api: api,
        store: inbox.archive,
        receiveInBackground: false,
      );
      var opened = 0;
      addTearDown(() {
        launcher.dispose();
        loadingInbox.dispose();
        update.dispose();
        twitchAppNotificationCenter.clear();
      });
      launcher.queueWhisperNotification(
        const TwitchWhisperNotificationTarget(ownerId: '1', peerId: '2'),
      );
      await Future<void>.delayed(Duration.zero);
      launcher.attach(
        () async {},
        updateController: update,
        updateOpener: () async {},
        whisperInbox: loadingInbox,
        navigationReady: false,
        whisperOpener: () async {
          opened++;
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(opened, 0);
      // This persisted history represents the archive available after cold start.
      await inbox.flushDrafts();
      await loadingInbox.refreshSession();
      await Future<void>.delayed(Duration.zero);
      expect(opened, 0);
      launcher.setNavigationReady(true);
      await Future<void>.delayed(Duration.zero);
      expect(opened, 1);
      expect(loadingInbox.activePeerId, '2');
      launcher.setNavigationReady(true);
      await Future<void>.delayed(Duration.zero);
      expect(opened, 1);
      expect(api.sent, 0);
    },
  );

  test(
    'notification waits for foreground, coalesces duplicates and queues latest click',
    () async {
      final launcher = TwitchAppSettingsLauncher();
      final update = VioClassUpdateController();
      final gate = Completer<void>();
      var opened = 0;
      addTearDown(() {
        launcher.dispose();
        update.dispose();
        twitchAppNotificationCenter.clear();
      });
      launcher.attach(
        () async {},
        updateController: update,
        updateOpener: () async {},
        whisperInbox: inbox,
        whisperOpener: () async {
          opened++;
          await gate.future;
        },
      );
      const target = TwitchWhisperNotificationTarget(ownerId: '1', peerId: '2');
      inbox.setAppForeground(false);
      launcher.queueWhisperNotification(target);
      launcher.queueWhisperNotification(target);
      await Future<void>.delayed(Duration.zero);
      expect(opened, 0);
      inbox.setAppForeground(true);
      await Future<void>.delayed(Duration.zero);
      expect(opened, 1);
      launcher.queueWhisperNotification(target);
      await Future<void>.delayed(Duration.zero);
      expect(opened, 1);
      launcher.queueWhisperNotification(
        const TwitchWhisperNotificationTarget(ownerId: '1', peerId: '99'),
      );
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(opened, 1);
      expect(twitchAppNotificationCenter.items.single.title, '無法開啟私訊');
      expect(api.sent, 0);
    },
  );

  test(
    'notification after logout rejects once rather than borrowing later account',
    () async {
      final launcher = TwitchAppSettingsLauncher();
      final update = VioClassUpdateController();
      var opened = 0;
      addTearDown(() {
        launcher.dispose();
        update.dispose();
        twitchAppNotificationCenter.clear();
      });
      inbox.clearSession();
      launcher.attach(
        () async {},
        updateController: update,
        updateOpener: () async {},
        whisperInbox: inbox,
        whisperOpener: () async {
          opened++;
        },
      );
      launcher.queueWhisperNotification(
        const TwitchWhisperNotificationTarget(ownerId: '1', peerId: '2'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(opened, 0);
      expect(twitchAppNotificationCenter.items.single.title, '無法開啟私訊');
      await inbox.refreshSession();
      await Future<void>.delayed(Duration.zero);
      expect(opened, 0);
    },
  );

  test(
    'Android plugin cold launch and live response wait for navigation without replaying launch',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final update = VioClassUpdateController();
      var launchReads = 0;
      var opened = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getNotificationAppLaunchDetails') {
          launchReads++;
          return {
            'notificationLaunchedApp': true,
            'notificationResponse': {
              'notificationId': 12,
              'notificationResponseType': 0,
              'payload': 'whisper:1:2',
            },
          };
        }
        return true;
      });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
        twitchAppSettingsLauncher.detach();
        twitchAppNotificationCenter.clear();
        update.dispose();
      });
      twitchAppSettingsLauncher.attach(
        () async {},
        updateController: update,
        updateOpener: () async {},
        whisperInbox: inbox,
        navigationReady: false,
        whisperOpener: () async {
          opened++;
        },
      );
      await twitchSystemNotificationService.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(launchReads, 1);
      expect(opened, 0);
      twitchAppSettingsLauncher.setNavigationReady(true);
      await Future<void>.delayed(Duration.zero);
      expect(opened, 1);
      await twitchSystemNotificationService.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(launchReads, 1);
      expect(opened, 1);
      inbox.setAppForeground(false);
      final completed = Completer<void>();
      messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('didReceiveNotificationResponse', {
            'notificationId': 13,
            'notificationResponseType': 0,
            'payload': 'whisper:1:2',
          }),
        ),
        (_) {
          completed.complete();
        },
      );
      await completed.future;
      await Future<void>.delayed(Duration.zero);
      expect(opened, 1);
      inbox.setAppForeground(true);
      await Future<void>.delayed(Duration.zero);
      expect(opened, 2);
      expect(api.sent, 0);
    },
  );

  test(
    'incoming profile changes persist by ID without resetting history, draft or avatar',
    () async {
      final raw =
          jsonDecode(await inbox.archive.exportBackup('1'))
              as Map<String, dynamic>;
      (raw['conversations'] as List).first['avatarUrl'] =
          'https://example.test/avatar.png';
      disk['vioclass_twitch_whispers_v1_1'] = jsonEncode(raw);
      await inbox.refreshSession();
      inbox.updateDraft('2', 'retained profile draft');
      await inbox.receiveEvent({
        'from_user_id': '2',
        'to_user_id': '1',
        'from_user_login': 'Renamed_Peer',
        'from_user_name': '新名稱',
        'whisper_id': 'profile-new',
        'whisper': {'text': 'first'},
      }, DateTime.utc(2026, 10, 3, 12));
      expect(inbox.conversations.single.login, 'renamed_peer');
      expect(inbox.conversations.single.displayName, '新名稱');
      expect(notificationName, '新名稱');
      await inbox.receiveEvent({
        'from_user_id': '2',
        'to_user_id': '1',
        'from_user_login': 'old_peer',
        'from_user_name': '舊名稱',
        'whisper_id': 'profile-late',
        'whisper': {'text': 'older event'},
      }, DateTime.utc(2026, 10, 3, 11));
      expect(notificationName, '新名稱');
      expect(inbox.conversations.single.login, 'renamed_peer');
      expect(inbox.conversations.single.messages.length, 2);
      expect(inbox.conversations.single.unreadCount, 2);
      expect(inbox.conversations.single.draft, 'retained profile draft');
      expect(
        inbox.conversations.single.avatarUrl,
        'https://example.test/avatar.png',
      );
      await inbox.flushDrafts();
      await inbox.refreshSession();
      expect(inbox.conversations.single.displayName, '新名稱');
      expect(
        inbox.conversations.single.profileObservedAt,
        DateTime.utc(2026, 10, 3, 12),
      );
      expect(inbox.conversations.single.hasReceivedWhisper, true);
      expect(api.sent, 0);
    },
  );

  test(
    'partial and malformed profile fields preserve existing data and duplicates do not rename',
    () async {
      await inbox.receiveEvent({
        'from_user_id': '2',
        'to_user_id': '1',
        'from_user_name': '新顯示名',
        'whisper_id': 'partial',
        'whisper': {'text': 'partial fields'},
      }, DateTime.utc(2026, 10, 3, 12));
      expect(inbox.conversations.single.login, 'peer');
      expect(inbox.conversations.single.displayName, '新顯示名');
      await inbox.receiveEvent({
        'from_user_id': '2',
        'to_user_id': '1',
        'from_user_login': 123,
        'from_user_name': ' ',
        'whisper_id': 'malformed',
        'whisper': {'text': 'no profile'},
      }, DateTime.utc(2026, 10, 3, 13));
      await inbox.receiveEvent({
        'from_user_id': '2',
        'to_user_id': '1',
        'from_user_login': 'not allowed!',
        'from_user_name': false,
        'whisper_id': 'invalid-login',
        'whisper': {'text': 'bad fields'},
      }, DateTime.utc(2026, 10, 3, 14));
      await inbox.receiveEvent({
        'from_user_id': '2',
        'to_user_id': '1',
        'from_user_name': 'duplicate rename',
        'whisper_id': 'partial',
        'whisper': {'text': 'partial fields'},
      }, DateTime.utc(2026, 10, 3, 15));
      expect(inbox.conversations.single.login, 'peer');
      expect(inbox.conversations.single.displayName, '新顯示名');
      expect(inbox.conversations.single.unreadCount, 3);
      expect(notifications, 3);
      expect(
        inbox.conversations.single.profileObservedAt,
        DateTime.utc(2026, 10, 3, 12),
      );
    },
  );

  test(
    'import cannot freeze future official profile updates or overwrite current peer metadata',
    () async {
      final imported = TwitchWhisperConversation(
        userId: '3',
        login: 'imported',
        displayName: 'backup',
        profileObservedAt: DateTime.utc(2099),
      );
      final currentBackup = TwitchWhisperConversation(
        userId: '2',
        login: 'fake',
        displayName: 'fake',
        profileObservedAt: DateTime.utc(2099),
      );
      await inbox.importBackup(
        jsonEncode({
          'version': 1,
          'ownerId': '1',
          'conversations': [imported.toJson(), currentBackup.toJson()],
        }),
      );
      expect(
        inbox.conversations.firstWhere((peer) => peer.userId == '2').login,
        'peer',
      );
      expect(
        inbox.conversations
            .firstWhere((peer) => peer.userId == '3')
            .profileObservedAt,
        isNull,
      );
      await inbox.receiveEvent({
        'from_user_id': '3',
        'to_user_id': '1',
        'from_user_login': 'official',
        'from_user_name': 'Official',
        'whisper_id': 'import-peer-update',
        'whisper': {'text': 'new'},
      }, DateTime.utc(2026, 10, 3));
      expect(
        inbox.conversations.firstWhere((peer) => peer.userId == '3').login,
        'official',
      );
      expect(api.sent, 0);
    },
  );

  testWidgets(
    'open private conversation displays incoming renamed peer without replacing draft',
    (tester) async {
      inbox.updateDraft('2', 'draft stays visible');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showTwitchWhisperSheet(context: context, controller: inbox),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      var received = false;
      unawaited(
        inbox
            .receiveEvent({
              'from_user_id': '2',
              'to_user_id': '1',
              'from_user_login': 'new_login',
              'from_user_name': '最新名稱',
              'whisper_id': 'visible-profile',
              'whisper': {'text': 'new profile'},
            }, DateTime.utc(2026, 10, 3))
            .then((_) => received = true),
      );
      for (var step = 0; step < 8; step++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(received, true);
      expect(find.text('最新名稱'), findsWidgets);
      expect(find.text('@new_login'), findsWidgets);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'draft stays visible',
      );
      expect(inbox.activePeerId, '2');
      expect(api.sent, 0);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(TextField).last)).pop();
      await tester.pumpAndSettle();
    },
  );

  test(
    'ID profile refresh preserves draft and rejects failure or changed selection',
    () async {
      inbox.updateDraft('2', 'profile refresh draft');
      await inbox.refreshActiveProfile();
      expect(api.lastProfileId, '2');
      expect(
        inbox.activeConversation!.avatarUrl,
        'https://example.test/updated.png',
      );
      expect(inbox.activeConversation!.login, 'refreshed');
      expect(inbox.activeConversation!.draft, 'profile refresh draft');
      expect(inbox.activeConversation!.hasReceivedWhisper, false);
      api.failProfile = true;
      await inbox.refreshActiveProfile();
      expect(inbox.errorText, 'fake profile failure');
      expect(
        inbox.activeConversation!.avatarUrl,
        'https://example.test/updated.png',
      );
      api.failProfile = false;
      api.profileGate = Completer<void>();
      final observed = inbox.activeConversation!.profileObservedAt;
      final pending = inbox.refreshActiveProfile();
      await inbox.selectConversation(null);
      await inbox.selectConversation('2');
      api.profileGate!.complete();
      await pending;
      expect(inbox.refreshingProfile, false);
      expect(inbox.activeConversation!.profileObservedAt, observed);
      expect(inbox.activeConversation!.draft, 'profile refresh draft');
      expect(api.sent, 0);
    },
  );

  test(
    'profile archive preserves newer names and clears obsolete avatar without changing unread',
    () async {
      await inbox.receiveEvent({
        'from_user_id': '2',
        'to_user_id': '1',
        'from_user_login': 'newest',
        'from_user_name': 'Newest',
        'whisper_id': 'refresh-order',
        'whisper': {'text': 'message'},
      }, DateTime.utc(2026, 10, 3, 12));
      await inbox.archive.updateProfile(
        '1',
        TwitchWhisperConversation(
          userId: '2',
          login: 'stale',
          displayName: 'Stale',
          avatarUrl: 'https://example.test/old.png',
        ),
        DateTime.utc(2026, 10, 3, 11),
        canApply: () => true,
      );
      var peer = (await inbox.archive.load('1')).single;
      expect(peer.login, 'newest');
      expect(peer.unreadCount, 1);
      expect(peer.avatarUrl, 'https://example.test/old.png');
      await inbox.archive.updateProfile(
        '1',
        TwitchWhisperConversation(
          userId: '2',
          login: 'latest',
          displayName: 'Latest',
        ),
        DateTime.utc(2026, 10, 3, 13),
        canApply: () => true,
      );
      peer = (await inbox.archive.load('1')).single;
      expect(peer.avatarUrl, isNull);
      expect(peer.messages.single.text, 'message');
      expect(peer.unreadCount, 1);
      expect(peer.hasReceivedWhisper, true);
    },
  );

  testWidgets(
    'Phone profile updates preserve composer without manual refresh controls',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      inbox.updateDraft('2', 'visible refresh draft');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showTwitchWhisperSheet(context: context, controller: inbox),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('更新對象資料'), findsNothing);
      expect(find.byTooltip('對話操作'), findsNothing);
      unawaited(inbox.refreshActiveProfile());
      for (var step = 0; step < 8; step++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      expect(api.lastProfileId, '2');
      expect(find.text('Refreshed'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'visible refresh draft',
      );
      expect(api.sent, 0);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(TextField).last)).pop();
      await tester.pumpAndSettle();
    },
  );

  test(
    'official emote catalog clears on logout and ignores late account response',
    () async {
      await inbox.loadOfficialEmotes();
      expect(inbox.emoteCatalog.emotes.single.name, 'Kappa');
      api.emoteGate = Completer<void>();
      final pending = inbox.loadOfficialEmotes();
      inbox.clearSession();
      api.emoteGate!.complete();
      await pending;
      expect(inbox.emoteCatalog.emotes, isEmpty);
      expect(inbox.loadingEmotes, false);
      expect(api.sent, 0);
    },
  );
  for (final keyboard in [false, true]) {
    testWidgets(
      'official emote picker inserts draft and renders inline with keyboard=$keyboard',
      (tester) async {
        await _seedSharedFixtureImage(tester);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        inbox.updateDraft('2', 'hello');
        await tester.runAsync(
          () => inbox.receiveEvent({
            'from_user_id': '2',
            'to_user_id': '1',
            'whisper_id': 'emote-body',
            'whisper': {'text': 'Kappa unknown'},
          }, DateTime.utc(2026, 10, 3)),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTwitchWhisperSheet(
                    context: context,
                    controller: inbox,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        if (keyboard) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          await tester.pumpAndSettle();
        }
        final composer = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.hintText == '私訊內容',
        );
        final beforePicker = tester.getTopLeft(composer).dy;
        await tester.tap(find.byTooltip('聊天表情'));
        for (var step = 0; step < 8; step++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        final panel = find.byKey(const ValueKey('whisper-emote-panel'));
        expect(find.byType(TwitchEmotePickerPanel), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.getTopLeft(composer).dy, lessThan(beforePicker));
        expect(
          tester.getRect(composer).bottom,
          lessThanOrEqualTo(tester.getRect(panel).top),
        );
        expect(find.text('Kappa'), findsWidgets);
        await tester.tap(find.text('Kappa').last);
        await tester.pumpAndSettle();
        expect(inbox.activeConversation!.draft, 'hello Kappa');
        expect(find.byType(SelectionArea), findsOneWidget);
        expect(find.byTooltip('複製原始訊息'), findsOneWidget);
        expect(inbox.activeConversation!.messages.single.text, 'Kappa unknown');
        expect(api.sent, 0);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byType(TextField).last)).pop();
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'official picker search and cancel preserve draft and selection replacement uses token boundaries',
    (tester) async {
      await _openPrivateWidget(tester, inbox);
      await tester.enterText(find.byType(TextField), 'hello world');
      final composer = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      composer.selection = const TextSelection(baseOffset: 11, extentOffset: 6);
      await tester.tap(find.byTooltip('聊天表情'));
      await _advancePrivateWidget(tester);
      final search = find.descendant(
        of: find.byKey(const ValueKey('whisper-emote-panel')),
        matching: find.byType(TextField),
      );
      await tester.enterText(search, 'missing');
      await tester.pump();
      expect(find.text('目前沒有可用的官方貼圖'), findsOneWidget);
      await tester.tap(find.byTooltip('關閉貼圖'));
      await tester.pumpAndSettle();
      expect(inbox.activeConversation!.draft, 'hello world');
      composer.selection = const TextSelection(baseOffset: 11, extentOffset: 6);
      await tester.tap(find.byTooltip('聊天表情'));
      await _advancePrivateWidget(tester);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('whisper-emote-panel')),
          matching: find.byType(TextField),
        ),
        'kAp',
      );
      await tester.pump();
      expect(find.text('Kappa'), findsOneWidget);
      await tester.tap(find.text('Kappa'));
      await _advancePrivateWidget(tester);
      expect(inbox.activeConversation!.draft, 'hello Kappa');
      expect(composer.selection.baseOffset, 11);
      expect(api.sent, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [
    const Size(1000, 760),
    const Size(390, 844),
    const Size(390, 260),
  ]) {
    testWidgets(
      'Private composer aligns controls and shares vertical categories at $size',
      (tester) async {
        await _openPrivateWidget(tester, inbox, size: size);
        final composer = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.hintText == '私訊內容',
        );
        final center = tester.getCenter(composer).dy;
        expect(find.byTooltip('Twitch 官方貼圖'), findsNothing);
        for (final label in ['聊天表情', '傳送私訊']) {
          expect(
            tester.getCenter(find.byTooltip(label)).dy,
            closeTo(center, 1),
          );
        }
        await tester.tap(find.byTooltip('聊天表情'));
        await _advancePrivateWidget(tester);
        final panel = find.byType(TwitchEmotePickerPanel);
        expect(panel, findsOneWidget);
        final sidebar = find.byKey(const ValueKey('emote-category-sidebar'));
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('emote-category-emoji')),
          40,
          scrollable: find.descendant(
            of: sidebar,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tapAt(
          tester
              .getRect(find.byKey(const ValueKey('emote-category-emoji')))
              .intersect(tester.getRect(sidebar))
              .center,
        );
        await _advancePrivateWidget(tester);
        expect(
          find.byKey(const ValueKey('emote-category-content-emoji')),
          findsOneWidget,
        );
        final official = find.byKey(const ValueKey('emote-category-official'));
        await tester.scrollUntilVisible(
          official,
          -40,
          scrollable: find.descendant(
            of: sidebar,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tapAt(
          tester.getRect(official).intersect(tester.getRect(sidebar)).center,
        );
        await _advancePrivateWidget(tester);
        expect(
          find.byKey(const ValueKey('emote-category-content-official')),
          findsOneWidget,
        );
        expect(find.text('Kappa'), findsOneWidget);
        // Compact responsive sheets retain a small outer margin, not an
        // additional empty engagement region below the picker.
        expect(tester.getRect(panel).bottom, closeTo(size.height, 8));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final receivesWhileOpen in [false, true]) {
    testWidgets(
      'official insertion uses current length allowance; receive while open=$receivesWhileOpen',
      (tester) async {
        inbox.updateDraft('2', 'x' * 499);
        await _openPrivateWidget(tester, inbox);
        await tester.tap(find.byTooltip('聊天表情'));
        await _advancePrivateWidget(tester);
        if (receivesWhileOpen) {
          var received = false;
          unawaited(
            inbox
                .receiveEvent({
                  'from_user_id': '2',
                  'to_user_id': '1',
                  'whisper_id': 'while-picker',
                  'whisper': {'text': 'relationship confirmed'},
                }, DateTime.utc(2026, 10, 3))
                .then((_) => received = true),
          );
          await _advancePrivateWidget(tester);
          expect(received, true);
        }
        await tester.tap(find.text('Kappa').last);
        await _advancePrivateWidget(tester);
        expect(
          inbox.activeConversation!.draft,
          receivesWhileOpen ? '${'x' * 499} Kappa' : 'x' * 499,
        );
        expect(api.sent, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'inline official choice cannot overwrite an externally changed draft',
    (tester) async {
      inbox.updateDraft('2', 'original');
      await _openPrivateWidget(tester, inbox);
      await tester.tap(find.byTooltip('聊天表情'));
      await _advancePrivateWidget(tester);
      inbox.updateDraft('2', 'newer draft');
      await tester.pump();
      await tester.tap(find.text('Kappa').last);
      await _advancePrivateWidget(tester);
      expect(inbox.activeConversation!.draft, 'newer draft');
      expect(api.sent, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('old official picker choice is rejected after account change', (
    tester,
  ) async {
    inbox.updateDraft('2', 'account one draft');
    await _openPrivateWidget(tester, inbox);
    await tester.tap(find.byTooltip('聊天表情'));
    await _advancePrivateWidget(tester);
    final oldChoice = tester
        .widget<InkWell>(
          find
              .ancestor(
                of: find.text('Kappa').last,
                matching: find.byType(InkWell),
              )
              .first,
        )
        .onTap!;
    api.owner = '3';
    var refreshed = false;
    unawaited(inbox.refreshSession().then((_) => refreshed = true));
    await _advancePrivateWidget(tester);
    expect(refreshed, true);
    expect(find.byKey(const ValueKey('whisper-emote-panel')), findsNothing);
    oldChoice();
    await _advancePrivateWidget(tester);
    expect(inbox.ownerId, '3');
    expect(inbox.conversations, isEmpty);
    expect(inbox.emoteCatalog.emotes, isEmpty);
    expect(api.sent, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'whole original copy preserves emote token and whitespace instead of object placeholder',
    (tester) async {
      const original = 'Kappa\n😀 unknown\tKappa';
      await tester.runAsync(
        () => inbox.receiveEvent({
          'from_user_id': '2',
          'to_user_id': '1',
          'whisper_id': 'copy-original',
          'whisper': {'text': original},
        }, DateTime.utc(2026, 10, 3)),
      );
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _openPrivateWidget(tester, inbox);
      await tester.tap(find.byTooltip('複製原始訊息'));
      await tester.pump();
      expect(copied, original);
      expect(copied, isNot(contains('\uFFFC')));
      expect(api.sent, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'loaded private emote selection copies original tokens through native copy action',
    (tester) async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 28, 28),
        ui.Paint()..color = const ui.Color(0xff663399),
      );
      final picture = recorder.endRecording();
      final bitmap = (await tester.runAsync(() => picture.toImage(28, 28)))!;
      picture.dispose();
      final provider = CachedNetworkImageProvider(
        'https://example.test/kappa.png',
        cacheKey: TwitchEmoteImageCacheManager.buildCacheKey(
          providerLabel: 'Twitch',
          id: '25',
          name: 'Kappa',
          staticVariant: false,
          url: 'https://example.test/kappa.png',
        ),
        cacheManager: TwitchEmoteImageCacheManager.instance,
      );
      PaintingBinding.instance.imageCache.evict(provider);
      PaintingBinding.instance.imageCache.putIfAbsent(
        provider,
        () => OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: bitmap)),
        ),
      );
      addTearDown(() => PaintingBinding.instance.imageCache.evict(provider));
      const original = 'before Kappa after';
      await tester.runAsync(
        () => inbox.receiveEvent({
          'from_user_id': '2',
          'to_user_id': '1',
          'whisper_id': 'loaded-copy',
          'whisper': {'text': original},
        }, DateTime.utc(2026, 10, 3)),
      );
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _openPrivateWidget(tester, inbox);
      final loaded = find.descendant(
        of: find.byType(SelectionArea),
        matching: find.byType(RawImage),
      );
      expect(tester.widget<RawImage>(loaded).image, isNotNull);
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll();
      await tester.pump();
      region.contextMenuButtonItems
          .singleWhere((item) => item.type == ContextMenuButtonType.copy)
          .onPressed!();
      await tester.pump();
      expect(copied, original);
      region.clearSelection();
      final emoteCenter = tester.getCenter(find.byType(TwitchSelectableEmote));
      await tester.tapAt(emoteCenter, kind: ui.PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(emoteCenter, kind: ui.PointerDeviceKind.mouse);
      await tester.pump();
      region.contextMenuButtonItems
          .singleWhere((item) => item.type == ContextMenuButtonType.copy)
          .onPressed!();
      await tester.pump();
      expect(copied, 'Kappa');
      copied = null;
      Focus.of(
        tester.element(find.byType(TwitchSelectableEmote)),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(copied, 'Kappa');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      copied = null;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(copied, 'Kappa ');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      copied = null;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(copied, 'Kappa');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      copied = null;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(copied, anyOf(isNull, isEmpty));
      expect(api.sent, 0);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );

  for (final scenario in [
    (
      name: 'short landscape',
      size: const Size(844, 390),
      inset: 160.0,
      scale: 1.0,
    ),
    (
      name: 'large text phone',
      size: const Size(390, 844),
      inset: 280.0,
      scale: 2.0,
    ),
  ]) {
    testWidgets(
      '${scenario.name} official picker remains usable with keyboard',
      (tester) async {
        await _openPrivateWidget(
          tester,
          inbox,
          size: scenario.size,
          scale: scenario.scale,
        );
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('聊天表情'));
        await _advancePrivateWidget(tester);
        final picker = find.byKey(const ValueKey('whisper-emote-panel'));
        tester.view.viewInsets = FakeViewPadding(bottom: scenario.inset);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final search = find.descendant(
          of: picker,
          matching: find.byType(TextField),
        );
        await tester.ensureVisible(search);
        await tester.enterText(search, 'kap');
        await tester.pumpAndSettle();
        final emote = find.descendant(of: picker, matching: find.text('Kappa'));
        await tester.ensureVisible(emote);
        await tester.pumpAndSettle();
        await tester.tap(emote);
        await _advancePrivateWidget(tester);
        expect(inbox.activeConversation!.draft, 'Kappa');
        expect(api.sent, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Compact profile updates preserve draft without manual refresh controls',
    (tester) async {
      inbox.updateDraft('2', 'compact draft');
      await _openPrivateWidget(tester, inbox);
      tester.view.physicalSize = const Size(844, 260);
      await tester.pumpAndSettle();
      expect(find.byTooltip('對話操作'), findsNothing);
      unawaited(inbox.refreshActiveProfile());
      await _advancePrivateWidget(tester);
      expect(api.lastProfileId, '2');
      expect(inbox.activeConversation!.displayName, 'Refreshed');
      expect(inbox.activeConversation!.draft, 'compact draft');
      expect(api.sent, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('draft survives closing and account histories are isolated', () async {
    inbox.updateDraft('2', 'draft on account one');
    await inbox.flushDrafts();
    inbox.setPanelVisible(false);
    await inbox.refreshSession();
    expect(inbox.activeConversation!.draft, 'draft on account one');
    api.owner = '3';
    await inbox.refreshSession();
    expect(inbox.conversations, isEmpty);
    api.owner = '1';
    await inbox.refreshSession();
    expect(inbox.conversations.single.draft, 'draft on account one');
  });
  test(
    'interrupted sending restores as unconfirmed and persists without sending again',
    () async {
      final message = TwitchWhisperMessage(
        id: 'local-interrupted',
        fromUserId: '1',
        toUserId: '2',
        text: 'potentially sent',
        timestamp: DateTime.utc(2026),
        state: TwitchWhisperMessageState.sending,
      );
      disk['vioclass_twitch_whispers_v1_1'] = jsonEncode({
        'version': 1,
        'ownerId': '1',
        'conversations': [
          TwitchWhisperConversation(
            userId: '2',
            login: 'peer',
            displayName: 'Peer',
            draft: 'potentially sent',
            messages: [message],
          ).toJson(),
        ],
      });
      final store = TwitchWhisperArchiveStore(
        read: (key) async => disk[key],
        write: (key, value) async {
          disk[key] = value;
        },
      );
      final peers = await store.load('1');
      expect(
        peers.single.messages.single.state,
        TwitchWhisperMessageState.unconfirmed,
      );
      expect(disk.values.join(), contains('unconfirmed'));
      expect(api.sent, 0);
      expect(
        (await store.load('1')).single.messages.single.state,
        TwitchWhisperMessageState.unconfirmed,
      );
    },
  );

  test(
    'successful submission clears unchanged draft and does not fabricate delivery',
    () async {
      inbox.updateDraft('2', 'hello');
      await inbox.sendActiveMessage();
      expect(api.sent, 1);
      expect(inbox.activeConversation!.draft, isEmpty);
      expect(
        inbox.activeConversation!.messages.single.state,
        TwitchWhisperMessageState.submitted,
      );
    },
  );

  test('failure preserves draft and failed message', () async {
    api.failSend = true;
    inbox.updateDraft('2', 'keep this draft');
    await inbox.sendActiveMessage();
    expect(api.sent, 0);
    expect(inbox.activeConversation!.draft, 'keep this draft');
    expect(
      inbox.activeConversation!.messages.single.state,
      TwitchWhisperMessageState.failed,
    );
  });
  test(
    'reading older messages keeps incoming unread; latest clears locally without duplicate notification',
    () async {
      inbox.setPanelVisible(true);
      inbox.setReadingLatest(false);
      await inbox.receiveEvent({
        'from_user_id': '2',
        'to_user_id': '1',
        'whisper_id': 'paused-incoming',
        'whisper': {'text': 'new while reading history'},
      }, DateTime.utc(2026));
      expect(inbox.unreadCount, 1);
      expect(notifications, 0);
      inbox.setAppForeground(false);
      inbox.setAppForeground(true);
      await Future<void>.delayed(Duration.zero);
      expect(inbox.unreadCount, 1);
      inbox.setReadingLatest(true);
      await Future<void>.delayed(Duration.zero);
      expect(inbox.unreadCount, 0);
      expect(api.sent, 0);
    },
  );
  test(
    'only valid incoming unlocks long content; own sends and foreign events do not',
    () async {
      inbox.updateDraft('2', 'x' * 501);
      await inbox.sendActiveMessage();
      expect(api.sent, 0);
      expect(inbox.activeConversation!.draft.length, 501);
      inbox.updateDraft('2', 'short outgoing');
      await inbox.sendActiveMessage();
      expect(inbox.activeConversation!.hasReceivedWhisper, false);
      await inbox.receiveEvent({
        'from_user_id': '2',
        'to_user_id': '9',
        'whisper_id': 'foreign',
        'whisper': {'text': 'foreign'},
      }, DateTime.utc(2026));
      expect(inbox.activeConversation!.messageLimit, 500);
      await inbox.receiveEvent({
        'from_user_id': '2',
        'to_user_id': '1',
        'from_user_login': 'peer',
        'whisper_id': 'real-incoming',
        'whisper': {'text': 'reply'},
      }, DateTime.utc(2026));
      expect(inbox.activeConversation!.messageLimit, 10000);
      inbox.updateDraft('2', 'x' * 10000);
      await inbox.sendActiveMessage();
      expect(api.sent, 2);
      expect(api.lastSentLength, 10000);
      expect(api.lastReceivedFlag, true);
      inbox.updateDraft('2', 'x' * 10001);
      await inbox.sendActiveMessage();
      expect(api.sent, 2);
      expect(inbox.activeConversation!.draft.length, 10001);
    },
  );
  test(
    'long relationship persists for same account but not other account',
    () async {
      await inbox.receiveEvent({
        'from_user_id': '2',
        'to_user_id': '1',
        'whisper_id': 'incoming',
        'whisper': {'text': 'reply'},
      }, DateTime.utc(2026));
      await inbox.refreshSession();
      expect(inbox.activeConversation!.hasReceivedWhisper, true);
      api.owner = '3';
      await inbox.refreshSession();
      await inbox.startConversation('peer');
      expect(inbox.activeConversation!.hasReceivedWhisper, false);
      api.owner = '1';
      await inbox.refreshSession();
      await inbox.selectConversation('2');
      expect(inbox.activeConversation!.messageLimit, 10000);
    },
  );
  test(
    'imported incoming metadata cannot unlock new peer; interrupted imported send is unconfirmed',
    () async {
      final incoming = TwitchWhisperMessage(
        id: 'import-incoming',
        fromUserId: '4',
        toUserId: '1',
        text: 'not live proof',
        timestamp: DateTime.utc(2026),
        state: TwitchWhisperMessageState.received,
      );
      final sending = TwitchWhisperMessage(
        id: 'import-sending',
        fromUserId: '1',
        toUserId: '4',
        text: 'maybe sent',
        timestamp: DateTime.utc(2026),
        state: TwitchWhisperMessageState.sending,
      );
      final raw = jsonEncode({
        'version': 1,
        'ownerId': '1',
        'conversations': [
          TwitchWhisperConversation(
            userId: '4',
            login: 'other',
            displayName: 'Other',
            hasReceivedWhisper: true,
            messages: [incoming, sending],
          ).toJson(),
        ],
      });
      expect(await inbox.importBackup(raw), 2);
      await inbox.selectConversation('4');
      expect(inbox.activeConversation!.messageLimit, 500);
      expect(
        inbox.activeConversation!.messages.last.state,
        TwitchWhisperMessageState.unconfirmed,
      );
      expect(api.sent, 0);
    },
  );

  test('new draft typed during send is not erased', () async {
    api.sendGate = Completer<void>();
    inbox.updateDraft('2', 'first message');
    final sending = inbox.sendActiveMessage();
    await Future<void>.delayed(Duration.zero);
    inbox.updateDraft('2', 'second draft');
    api.sendGate!.complete();
    await sending;
    expect(inbox.activeConversation!.draft, 'second draft');
  });
  test(
    'unknown send preserves draft and persists unconfirmed state without retry',
    () async {
      api.unknownSend = true;
      inbox.updateDraft('2', 'do not duplicate');
      await inbox.sendActiveMessage();
      expect(api.sent, 0);
      expect(inbox.activeConversation!.draft, 'do not duplicate');
      expect(
        inbox.activeConversation!.messages.single.state,
        TwitchWhisperMessageState.unconfirmed,
      );
      await inbox.refreshSession();
      expect(
        inbox.activeConversation!.messages.single.state,
        TwitchWhisperMessageState.unconfirmed,
      );
      expect(api.sent, 0);
    },
  );

  test(
    'logout cancels a request waiting for auth and clears visible account data',
    () async {
      api.sendGate = Completer<void>();
      inbox.updateDraft('2', 'do not send');
      final sending = inbox.sendActiveMessage();
      await Future<void>.delayed(Duration.zero);
      inbox.clearSession();
      api.sendGate!.complete();
      await sending;
      expect(api.sent, 0);
      expect(inbox.ownerId, isNull);
      expect(inbox.conversations, isEmpty);
    },
  );

  testWidgets('desktop presents list and conversation without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showTwitchWhisperSheet(context: context, controller: inbox),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Peer'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(TextField).first)).pop();
    await tester.pumpAndSettle();
  });

  test(
    'closed panel receives once and unread clears on local reading',
    () async {
      final event = <String, dynamic>{
        'from_user_id': '2',
        'from_user_login': 'peer',
        'from_user_name': 'Peer',
        'to_user_id': '1',
        'whisper_id': 'incoming-1',
        'whisper': {'text': 'fake incoming'},
      };
      await inbox.receiveEvent(event, DateTime.utc(2026));
      await inbox.receiveEvent(event, DateTime.utc(2026));
      expect(inbox.unreadCount, 1);
      expect(notifications, 1);
      expect(inbox.conversations.single.messages.length, 1);
      inbox.setPanelVisible(true);
      await inbox.selectConversation('2');
      expect(inbox.unreadCount, 0);
      await inbox.receiveEvent({
        ...event,
        'whisper_id': 'incoming-2',
      }, DateTime.utc(2026));
      expect(inbox.unreadCount, 0);
      inbox.setAppForeground(false);
      await inbox.receiveEvent({
        ...event,
        'whisper_id': 'incoming-3',
      }, DateTime.utc(2026));
      expect(inbox.unreadCount, 1);
      await inbox.receiveEvent({
        ...event,
        'to_user_id': '3',
      }, DateTime.utc(2026));
      expect(inbox.conversations.single.messages.length, 3);
      expect(notifications, 2);
    },
  );

  test(
    'backup merges once, preserves current draft, rejects another account atomically',
    () async {
      inbox.updateDraft('2', 'saved draft');
      await inbox.sendActiveMessage();
      final raw = (await inbox.exportBackup())!;
      inbox.updateDraft('2', 'new draft');
      expect(await inbox.importBackup(raw), 0);
      expect(inbox.conversations.single.draft, 'new draft');
      final before = (await inbox.exportBackup())!;
      expect(
        await inbox.importBackup(
          raw.replaceFirst('"ownerId":"1"', '"ownerId":"3"'),
        ),
        isNull,
      );
      expect(await inbox.exportBackup(), before);
      await inbox.removeConversation('2');
      expect(inbox.conversations, isEmpty);
      expect(inbox.activePeerId, isNull);
      expect(await inbox.importBackup(before), 1);
      expect(inbox.conversations.single.draft, 'new draft');
      expect(inbox.unreadCount, 0);
    },
  );

  testWidgets('phone conversation has back navigation and preserves draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showTwitchWhisperSheet(context: context, controller: inbox),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'phone draft');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(inbox.activePeerId, isNull);
    expect(inbox.conversations.single.draft, 'phone draft');
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(TextField))).pop();
    await tester.pumpAndSettle();
  });
  for (final variableHeight in [false, true]) {
    testWidgets(
      'private history ${variableHeight ? "variable heights and keyboard resize" : "uniform heights"} preserves position and reaches actual latest tail',
      (tester) async {
        await tester.runAsync(() async {
          for (var i = 0; i < 35; i++) {
            await inbox.receiveEvent({
              'from_user_id': '2',
              'to_user_id': '1',
              'whisper_id': 'history-$i',
              'whisper': {
                'text':
                    'history line $i — message body${variableHeight && i % 4 == 0 ? "\nlong line" * 35 : ""}',
              },
            }, DateTime.utc(2026, 1, 1).add(Duration(seconds: i)));
          }
        });
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTwitchWhisperSheet(
                    context: context,
                    controller: inbox,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final list = find.byKey(const ValueKey('whisper-message-list'));
        final scrollable = find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        );
        final position = tester
            .state<ScrollableState>(scrollable.first)
            .position;
        expect(position.extentBefore, lessThanOrEqualTo(0.5));
        if (variableHeight) {
          final beforeResize = position.pixels;
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          expect(position.pixels, closeTo(beforeResize, 1));
          if (position.extentBefore > 0.5) {
            await tester.tap(find.text('返回最新訊息'));
            await _advancePrivateWidget(tester);
          }
          expect(position.extentBefore, lessThanOrEqualTo(0.5));
          expect(inbox.readingLatest, true);
        }
        // Stay away from the oldest boundary, which legitimately clamps when
        // the keyboard closes and the viewport grows.
        position.jumpTo(position.maxScrollExtent * .5);
        await tester.pumpAndSettle();
        expect(inbox.readingLatest, false);
        final offset = position.pixels;
        if (variableHeight) {
          tester.view.viewInsets = FakeViewPadding.zero;
          await tester.pumpAndSettle();
          expect(position.pixels, closeTo(offset, 1));
          expect(inbox.readingLatest, false);
        }
        // Advance both real persistence and widget-zone callbacks.
        var received = false;
        unawaited(
          inbox
              .receiveEvent({
                'from_user_id': '2',
                'to_user_id': '1',
                'whisper_id': 'new-at-bottom',
                'whisper': {
                  'text':
                      'latest received marker${variableHeight ? "\nvariable latest line" * 50 : ""}',
                },
              }, DateTime.utc(2026, 1, 2))
              .then((_) => received = true),
        );
        for (var step = 0; step < 8; step++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump();
        }
        expect(received, true);
        expect(position.pixels, closeTo(offset, 1));
        expect(inbox.unreadCount, 1);
        expect(find.text('新私訊 · 1 · 返回最新訊息'), findsOneWidget);
        await tester.tap(find.text('新私訊 · 1 · 返回最新訊息'));
        await tester.pumpAndSettle();
        for (var step = 0; step < 6; step++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump();
        }
        expect(inbox.readingLatest, true);
        expect(inbox.unreadCount, 0);
        expect(find.text('新私訊 · 1 · 返回最新訊息'), findsNothing);
        expect(find.textContaining('latest received marker'), findsOneWidget);
        expect(position.extentBefore, lessThanOrEqualTo(0.5));
        if (variableHeight) {
          final beforeResize = position.pixels;
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          await tester.pumpAndSettle();
          expect(position.pixels, closeTo(beforeResize, 1));
          if (position.extentBefore > 0.5) {
            await tester.tap(find.text('返回最新訊息'));
            await _advancePrivateWidget(tester);
          }
          expect(position.extentBefore, lessThanOrEqualTo(0.5));
          expect(inbox.readingLatest, true);
        }
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(list)).pop();
        await tester.pumpAndSettle();
      },
    );
  }
  for (final scenario in [
    (useGesture: false, platform: TargetPlatform.windows),
    (useGesture: true, platform: TargetPlatform.windows),
    (useGesture: true, platform: TargetPlatform.android),
  ]) {
    final useGesture = scenario.useGesture;
    testWidgets(
      '${useGesture ? "pointer gesture" : "drag-start notification"} ${scenario.platform.name} cancels pending private latest correction without clearing unread',
      (tester) async {
        await tester.runAsync(() async {
          for (var index = 0; index < 45; index++) {
            await inbox.receiveEvent({
              'from_user_id': '2',
              'to_user_id': '1',
              'whisper_id': 'cancel-history-$index',
              'whisper': {
                'text':
                    'history $index${"\nlong body" * (index % 3 == 0 ? 30 : 2)}',
              },
            }, DateTime.utc(2026, 10, 3).add(Duration(seconds: index)));
          }
        });
        var dragStarts = 0;
        final scrollTrace = <String>[];
        await _openPrivateWidget(
          tester,
          inbox,
          onScroll: (notification) {
            scrollTrace.add(
              '${notification.runtimeType}: ${notification.metrics.pixels}/${notification.metrics.maxScrollExtent}',
            );
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              dragStarts++;
            }
            return false;
          },
        );
        final list = find.byKey(const ValueKey('whisper-message-list'));
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: list, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => inbox.receiveEvent({
            'from_user_id': '2',
            'to_user_id': '1',
            'whisper_id': 'cancel-latest',
            'whisper': {'text': 'latest${"\nlatest line" * 40}'},
          }, DateTime.utc(2026, 10, 4)),
        );
        await _advancePrivateWidget(tester);
        expect(inbox.unreadCount, 1);
        // Invoke the real button callback before the next frame can finish seeking.
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, '新私訊 · 1 · 返回最新訊息'),
        );
        button.onPressed!();
        if (useGesture) {
          final gesture = await tester.startGesture(tester.getCenter(list));
          await gesture.moveBy(const Offset(0, 180));
          await tester.pump();
          await gesture.moveBy(const Offset(0, 180));
          await gesture.up();
        } else {
          // Isolate the notification/callback race from platform gesture arbitration.
          ScrollStartNotification(
            metrics: position,
            context: tester.element(list),
            dragDetails: DragStartDetails(),
          ).dispatch(tester.element(list));
          position.jumpTo(position.maxScrollExtent);
        }
        await _advancePrivateWidget(tester);
        if (useGesture) expect(dragStarts, greaterThan(0));
        expect(
          position.extentBefore,
          greaterThan(90),
          reason: scrollTrace.join('\n'),
        );
        expect(inbox.readingLatest, false);
        expect(inbox.unreadCount, 1);
        final stopped = position.pixels;
        await tester.pump(const Duration(milliseconds: 500));
        expect(position.pixels, closeTo(stopped, .5));
        await tester.tap(find.text('新私訊 · 1 · 返回最新訊息'));
        await _advancePrivateWidget(tester);
        expect(position.extentBefore, lessThanOrEqualTo(.5));
        expect(inbox.readingLatest, true);
        expect(inbox.unreadCount, 0);
        expect(api.sent, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({scenario.platform}),
    );
  }

  testWidgets(
    'private drag extent adjustment preserves gap only for shrinking estimated range',
    (tester) async {
      await _openPrivateWidget(tester, inbox);
      final list = find.byKey(const ValueKey('whisper-message-list'));
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)).first,
          )
          .position;
      ScrollStartNotification(
        metrics: position,
        context: tester.element(list),
        dragDetails: DragStartDetails(),
      ).dispatch(tester.element(list));
      const base = RangeMaintainingScrollPhysics(
        parent: ClampingScrollPhysics(),
      );
      final physics = tester
          .widget<CustomScrollView>(list)
          .physics!
          .applyTo(base);
      final old = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1000,
        pixels: 800,
        viewportDimension: 400,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );
      final smaller = old.copyWith(maxScrollExtent: 500);
      expect(
        physics.adjustPositionForNewDimensions(
          oldPosition: old,
          newPosition: smaller,
          isScrolling: true,
          velocity: 0,
        ),
        300,
      );
      // Viewport changes, in-range movement, genuine overscroll, range growth and
      // idle layout must keep the inherited platform behavior.
      for (final values in [
        (
          old: old,
          next: smaller.copyWith(viewportDimension: 250),
          scrolling: true,
        ),
        (
          old: old.copyWith(pixels: 400),
          next: smaller.copyWith(pixels: 400),
          scrolling: true,
        ),
        (
          old: old.copyWith(pixels: 1100),
          next: smaller.copyWith(pixels: 1100),
          scrolling: true,
        ),
        (old: old, next: old.copyWith(maxScrollExtent: 1500), scrolling: true),
        (old: old, next: smaller, scrolling: false),
      ]) {
        expect(
          physics.adjustPositionForNewDimensions(
            oldPosition: values.old,
            newPosition: values.next,
            isScrolling: values.scrolling,
            velocity: 0,
          ),
          base.adjustPositionForNewDimensions(
            oldPosition: values.old,
            newPosition: values.next,
            isScrolling: values.scrolling,
            velocity: 0,
          ),
        );
      }
      ScrollEndNotification(
        metrics: position,
        context: tester.element(list),
      ).dispatch(tester.element(list));
      expect(
        physics.adjustPositionForNewDimensions(
          oldPosition: old,
          newPosition: smaller,
          isScrolling: true,
          velocity: 0,
        ),
        base.adjustPositionForNewDimensions(
          oldPosition: old,
          newPosition: smaller,
          isScrolling: true,
          velocity: 0,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final switchOwner in [false, true]) {
    testWidgets(
      'pending private metrics rejects old ${switchOwner ? "owner" : "peer"} callbacks',
      (tester) async {
        await tester.runAsync(() async {
          for (var index = 0; index < 35; index++) {
            await inbox.receiveEvent({
              'from_user_id': '2',
              'to_user_id': '1',
              'whisper_id': 'switch-history-$index',
              'whisper': {'text': 'old history $index${"\nlong body" * 20}'},
            }, DateTime.utc(2026, 10, 3).add(Duration(seconds: index)));
          }
          if (!switchOwner) {
            await inbox.receiveEvent({
              'from_user_id': '4',
              'from_user_login': 'other',
              'from_user_name': 'Other',
              'to_user_id': '1',
              'whisper_id': 'other-history',
              'whisper': {'text': 'other conversation marker'},
            }, DateTime.utc(2026, 10, 4));
          }
        });
        await _openPrivateWidget(tester, inbox);
        final oldList = find.byKey(const ValueKey('whisper-message-list'));
        final oldPosition = tester
            .state<ScrollableState>(
              find
                  .descendant(of: oldList, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        oldPosition.jumpTo(oldPosition.maxScrollExtent);
        await tester.pumpAndSettle();
        // Dispatch real metrics while following; do not drain its post-frame work.
        inbox.setReadingLatest(true);
        ScrollMetricsNotification(
          metrics: oldPosition,
          context: tester.element(oldList),
        ).dispatch(tester.element(oldList));
        if (switchOwner) {
          api.owner = '3';
          unawaited(inbox.refreshSession());
        } else {
          unawaited(inbox.selectConversation('4'));
        }
        await _advancePrivateWidget(tester);
        if (switchOwner) {
          expect(inbox.ownerId, '3');
          expect(inbox.activePeerId, isNull);
          expect(inbox.conversations, isEmpty);
          expect(find.textContaining('old history'), findsNothing);
        } else {
          expect(inbox.activePeerId, '4');
          expect(find.text('other conversation marker'), findsOneWidget);
          expect(find.textContaining('old history'), findsNothing);
          final position = tester
              .state<ScrollableState>(
                find
                    .descendant(of: oldList, matching: find.byType(Scrollable))
                    .first,
              )
              .position;
          expect(position.extentBefore, lessThanOrEqualTo(.5));
        }
        expect(api.sent, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'over-limit phone draft is preserved visibly and cannot be submitted or silently truncated',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showTwitchWhisperSheet(context: context, controller: inbox),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'x' * 501);
      await tester.pumpAndSettle();
      expect(find.text('501/500'), findsOneWidget);
      expect(find.text('內容超過目前私訊額度，草稿已保留；不會截短送出。'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '傳送私訊',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(inbox.activeConversation!.draft.length, 501);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(TextField))).pop();
      await tester.pumpAndSettle();
      expect(inbox.conversations.single.draft.length, 501);
      expect(api.sent, 0);
    },
  );
  for (final scenario in [
    (name: 'phone system back', size: const Size(390, 844), closeFirst: false),
    (
      name: 'short landscape system back',
      size: const Size(844, 290),
      closeFirst: false,
    ),
    (
      name: 'desktop system back',
      size: const Size(1200, 900),
      closeFirst: true,
    ),
  ]) {
    testWidgets(
      '${scenario.name} respects list/conversation navigation and persists draft',
      (tester) async {
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTwitchWhisperSheet(
                    context: context,
                    controller: inbox,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final messageInput = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.hintText == '私訊內容',
        );
        await tester.enterText(messageInput, 'system back draft');
        // This harness lives in docs/ by repository policy, but is a widget test.
        // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        if (scenario.closeFirst) {
          expect(inbox.panelVisible, false);
          expect(find.byTooltip('傳送私訊'), findsNothing);
        } else {
          expect(inbox.activePeerId, isNull);
          expect(inbox.panelVisible, true);
          expect(find.byTooltip('傳送私訊'), findsNothing);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is TextField && widget.decoration?.hintText == '搜尋對話',
            ),
            findsOneWidget,
          );
          // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(inbox.panelVisible, false);
        }
        // The store queue was created in setUp's real async zone. Let that
        // queue and widget microtasks both finish; don't await a cross-zone
        // storage future while preventing the other zone from advancing.
        for (var step = 0; step < 6; step++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump();
        }
        expect(inbox.conversations.single.draft, 'system back draft');
        expect(disk.values.join(), contains('system back draft'));
        expect(api.sent, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'explicit close exits phone conversation directly without treating it as system back',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showTwitchWhisperSheet(context: context, controller: inbox),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'close draft');
      await tester.tap(find.byTooltip('關閉'));
      await tester.pumpAndSettle();
      expect(inbox.panelVisible, false);
      expect(inbox.conversations.single.draft, 'close draft');
      expect(api.sent, 0);
      expect(tester.takeException(), isNull);
    },
  );
  for (final scenario in [
    (
      name: 'small phone with keyboard',
      size: const Size(320, 640),
      inset: 250.0,
      scale: 1.3,
    ),
    (
      name: 'landscape phone with keyboard',
      size: const Size(844, 390),
      inset: 220.0,
      scale: 1.0,
    ),
    (
      name: 'desktop large text',
      size: const Size(1200, 900),
      inset: 0.0,
      scale: 1.6,
    ),
  ]) {
    testWidgets('${scenario.name} keeps composer visible without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showTwitchWhisperSheet(context: context, controller: inbox),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding(bottom: scenario.inset);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(TextField).last).bottom,
        lessThanOrEqualTo(scenario.size.height - scenario.inset + 1),
      );
      Navigator.of(tester.element(find.byType(TextField).last)).pop();
      await tester.pumpAndSettle();
    });
  }
  testWidgets(
    'emoji inserts at selection and survives closing without sending',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showTwitchWhisperSheet(context: context, controller: inbox),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'hello world');
      final field = tester.widget<TextField>(find.byType(TextField));
      field.controller!.selection = const TextSelection.collapsed(offset: 5);
      await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('emote-category-emoji')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('😀'));
      await tester.pumpAndSettle();
      expect(inbox.activeConversation!.draft, 'hello😀 world');
      expect(api.sent, 0);
      Navigator.of(tester.element(find.byType(TextField).first)).pop();
      await tester.pumpAndSettle();
      expect(inbox.conversations.single.draft, 'hello😀 world');
      expect(tester.takeException(), isNull);
    },
  );
}
