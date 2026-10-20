// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_recent_messages_api_service.dart';
import '../lib/features/twitch/services/auth/twitch_auth_service.dart';
import '../lib/features/twitch/services/auth/twitch_viewer_session.dart';
import '../lib/features/twitch/services/auth/twitch_drops_auth_service.dart';
import '../lib/features/twitch/services/special_actions/twitch_viewer_special_message_runtime.dart';
import '../lib/features/twitch/presentation/watch/twitch_watch_feature_ports.dart';
import '../lib/features/twitch/presentation/watch/controllers/twitch_watch_chat_controller.dart';
import '../lib/features/twitch/services/chat/twitch_chat_runtime.dart';
import '../lib/features/twitch/models/chat/twitch_chat_startup.dart';
import '../lib/features/twitch/models/chat/twitch_chat_badge.dart';
import '../lib/features/twitch/models/special_actions/twitch_pending_special_message.dart';
import '../lib/features/twitch/models/special_actions/twitch_viewer_special_message_models.dart';

class _GuestAuth extends TwitchAuthService {
  _GuestAuth(TwitchApiClient client) : super(apiClient: client);
  @override
  String? get accessToken => null;
  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async =>
      null;
}

class _StartupPort implements TwitchWatchChatPort {
  int requests = 0;
  @override
  Future<List<Map<String, dynamic>>> fetchOfficialHistory({
    required String channelLogin,
    required String channelId,
  }) async => [];
  @override
  Future<TwitchChatStartupSnapshot> fetchStartupSnapshot({
    required String channelLogin,
  }) async {
    requests++;
    return TwitchChatStartupSnapshot(
      channelLogin: channelLogin,
      channelId: '7',
      badgeCatalog: const TwitchBadgeCatalog(),
      operations: const [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GuestRuntime implements TwitchChatRuntime {
  int connects = 0;
  int supplements = 0;
  int disposals = 0;
  bool failConnect = false;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #sendRejections) {
      return const Stream<TwitchChatSendRejection>.empty();
    }
    if (invocation.memberName == #connect) {
      connects++;
      expect(invocation.namedArguments[#accessToken], isNull);
      expect(invocation.namedArguments[#viewerUserId], isNull);
      expect(invocation.namedArguments[#preloadRecentMessages], isTrue);
      return failConnect
          ? Future<void>.error(StateError('fixture-connect-error'))
          : Future<void>.value();
    }
    if (invocation.memberName == #applyStartupSupplement) {
      supplements++;
      return null;
    }
    if (invocation.memberName == #applyRecentHistory) {
      supplements++;
      return null;
    }
    if (invocation.memberName == #disposeRuntime) {
      disposals++;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _Auth extends TwitchAuthService {
  _Auth(TwitchApiClient client) : super(apiClient: client);
  @override
  String? get accessToken => 'fixture-token';
  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async =>
      'fixture-token';
}

class _ReadyValidation extends TwitchAuthApiService {
  final List<String> scopes;
  _ReadyValidation(TwitchApiClient client, this.scopes) : super(client: client);
  @override
  Future<TwitchTokenValidation> validateToken(String accessToken) async =>
      TwitchTokenValidation(
        clientId: 'fixture',
        login: 'fixture-viewer',
        userId: '42',
        scopes: scopes,
        expiresIn: 3600,
      );
}

class _ReadyDrops implements TwitchDropsAuthService {
  @override
  Future<void> loadStoredSession() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SwitchingAuth extends _Auth {
  String? currentToken = 'fixture-token';
  _SwitchingAuth(super.client);
  @override
  String? get accessToken => currentToken;
  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async =>
      currentToken;
  void change(String? value) {
    currentToken = value;
    notifyListeners();
  }
}

class _StartupGatePort extends _StartupPort {
  final started = Completer<void>();
  final release = Completer<TwitchChatStartupSnapshot>();
  @override
  Future<TwitchChatStartupSnapshot> fetchStartupSnapshot({
    required String channelLogin,
  }) {
    requests++;
    started.complete();
    return release.future;
  }
}

class _OfficialHistoryGatePort extends _StartupGatePort {
  final history = Completer<List<Map<String, dynamic>>>();
  @override
  Future<List<Map<String, dynamic>>> fetchOfficialHistory({
    required String channelLogin,
    required String channelId,
  }) => history.future;
}

class _GatedDrops extends _ReadyDrops {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> loadStoredSession() {
    started.complete();
    return release.future;
  }
}

class _ReadyRuntime extends _GuestRuntime {
  int sends = 0;
  @override
  bool get connected => true;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #connect) {
      connects++;
      return Future<void>.value();
    }
    if (invocation.memberName == #sendMessage) {
      sends++;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _Validation extends TwitchAuthApiService {
  final gate = Completer<TwitchTokenValidation>();
  final started = Completer<void>();
  _Validation(TwitchApiClient client) : super(client: client);
  @override
  Future<TwitchTokenValidation> validateToken(String accessToken) {
    started.complete();
    return gate.future;
  }
}

class _SendGateRuntime extends _ReadyRuntime {
  final started = Completer<void>();
  final gate = Completer<void>();
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #sendMessage) {
      sends++;
      started.complete();
      return gate.future;
    }
    return super.noSuchMethod(invocation);
  }
}

class _ReadTransportRuntime extends _ReadyRuntime {
  String? receivedToken;
  String? receivedNick;
  String? receivedViewerId;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #connect) {
      receivedToken = invocation.namedArguments[#accessToken] as String?;
      receivedNick = invocation.namedArguments[#ircNick] as String?;
      receivedViewerId = invocation.namedArguments[#viewerUserId] as String?;
    }
    return super.noSuchMethod(invocation);
  }
}

class _GatedRuntime extends _ReadyRuntime {
  final started = Completer<void>();
  final gate = Completer<void>();
  bool ready = false;
  @override
  bool get connected => ready;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #connect) {
      connects++;
      started.complete();
      return gate.future.then<void>((_) => ready = true);
    }
    return super.noSuchMethod(invocation);
  }
}

class _ReconnectRuntime extends _ReadyRuntime {
  final started = Completer<void>();
  final gate = Completer<void>();
  bool ready = true;
  @override
  bool get connected => ready;
  @override
  bool get connecting => false;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #reconnect) {
      started.complete();
      return gate.future.then<void>((_) => ready = true);
    }
    return super.noSuchMethod(invocation);
  }
}

class _ForegroundRuntime extends _ReadyRuntime {
  bool ready = true;
  bool failNext = false;
  int reconnects = 0;
  Completer<void>? pending;
  @override
  bool get connected => ready;
  @override
  bool get connecting => false;
  @override
  Object? get error => ready ? null : StateError('fixture disconnected');
  @override
  Future<void> reconnect() async {
    reconnects++;
    await pending?.future;
    ready = !failNext;
    failNext = false;
  }

  @override
  Future<void> disconnect() async => ready = false;
}

// Unused dependencies intentionally throw if connection proceeds past validation.
class _Drops implements TwitchDropsAuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recent implements TwitchRecentMessagesApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChatPort implements TwitchWatchChatPort {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Engagement implements TwitchWatchEngagementPort {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Special implements TwitchViewerSpecialMessageRuntimeStage251 {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RewardGate extends _Engagement {
  final started = Completer<void>();
  final gate = Completer<TwitchWatchRewardRedeemResult>();
  int calls = 0;

  @override
  Future<TwitchWatchRewardRedeemResult> redeemReward({
    required String channelId,
    required Map<String, dynamic> reward,
    required String textInput,
  }) {
    calls++;
    expect(channelId, '7');
    expect(reward, {'id': 'fixture-reward'});
    expect(textInput, 'fixture text');
    if (!started.isCompleted) started.complete();
    return gate.future;
  }
}

class _SpecialGate extends _Special {
  final Symbol operation;
  final Object payload;
  final started = Completer<void>();
  final gate = Completer<TwitchViewerSpecialMessageSendResultStage251>();
  int calls = 0;
  _SpecialGate(this.operation, this.payload);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == operation) {
      calls++;
      expect(invocation.namedArguments[#channelLogin], 'fixture');
      expect(invocation.namedArguments[#channelId], '7');
      expect(invocation.namedArguments[#viewerId], '42');
      expect(invocation.namedArguments[#message], 'fixture text');
      expect(
        invocation.namedArguments[operation == #shareWatchStreak
            ? #status
            : #resub],
        same(payload),
      );
      started.complete();
      return gate.future;
    }
    return super.noSuchMethod(invocation);
  }
}

class _QueuedRewards extends _Engagement {
  final List<_RewardGate> requests;
  int calls = 0;
  _QueuedRewards(this.requests);

  @override
  Future<TwitchWatchRewardRedeemResult> redeemReward({
    required String channelId,
    required Map<String, dynamic> reward,
    required String textInput,
  }) => requests[calls++].redeemReward(
    channelId: channelId,
    reward: reward,
    textInput: textInput,
  );
}

void main() {
  for (final guest in [true, false]) {
    testWidgets('Foreground refresh and disconnected-only retry guest=$guest', (
      tester,
    ) async {
      final client = TwitchApiClient();
      final runtime = _ForegroundRuntime();
      final startup = _StartupPort();
      final notices = <String>[];
      final controller = TwitchWatchChatController(
        runtimeFactory: ({required authenticated}) => runtime,
        authService: guest ? _GuestAuth(client) : _Auth(client),
        dropsAuthService: _ReadyDrops(),
        authApi: _ReadyValidation(client, ['chat:read', 'chat:edit']),
        recentMessagesApi: _Recent(),
        chatPort: startup,
        engagementPort: _Engagement(),
        specialMessagesRuntime: _Special(),
        channelLogin: () => 'fixture',
        channelId: () => '7',
        viewerId: () => guest ? null : '42',
        channelPointsSnapshot: () => null,
        refreshEngagement: ({bool showSnackOnError = false}) async {},
        refreshSpecialMessages: ({bool autoSelectPending = false}) async {},
        onChannelIdResolved: (_) {},
        onViewerResolved: (_, _) {},
        showMessage: notices.add,
      );
      await controller.connectChat('fixture');
      await controller.setAppForeground(false);
      await tester.pump(const Duration(seconds: 30));
      expect(runtime.reconnects, 0);
      // The old connected flag stays true despite a suspended/dead socket.
      await controller.setAppForeground(true);
      expect(runtime.reconnects, 1);
      await controller.setAppForeground(true);
      await tester.pump(const Duration(seconds: 30));
      expect(runtime.reconnects, 1);
      runtime.ready = false;
      runtime.failNext = true;
      await tester.pump(const Duration(seconds: 15));
      expect(runtime.reconnects, 2);
      expect(runtime.ready, isFalse);
      await tester.pump(const Duration(seconds: 15));
      expect(runtime.reconnects, 3);
      expect(runtime.ready, isTrue);
      runtime.ready = false;
      runtime.pending = Completer<void>();
      await tester.pump(const Duration(seconds: 15));
      await tester.pump(const Duration(seconds: 30));
      expect(runtime.reconnects, 4, reason: 'Do not overlap recovery attempts');
      runtime.pending!.complete();
      await tester.pump();
      expect(
        runtime.connects,
        1,
        reason: 'Reuse the existing runtime and history',
      );
      expect(startup.requests, 1);
      expect(
        notices,
        isEmpty,
        reason: 'Background retries must not spam notices',
      );
      await controller.disconnect();
      await tester.pump(const Duration(seconds: 30));
      expect(runtime.reconnects, 4, reason: 'Respect intentional disconnect');
      controller.dispose();
      await tester.pump(const Duration(seconds: 30));
      expect(runtime.reconnects, 4);
      client.close(force: true);
    });
  }
  for (final stage in ['drops', 'irc', 'supplement', 'official']) {
    test('Same-account validation preserves chat during $stage', () async {
      final client = TwitchApiClient();
      addTearDown(() => client.close(force: true));
      final auth = _Auth(client);
      final validation = _ReadyValidation(client, ['chat:read', 'chat:edit']);
      final drops = _GatedDrops();
      final runtime = _GatedRuntime();
      final port = stage == 'official'
          ? _OfficialHistoryGatePort()
          : _StartupGatePort();
      final controller = TwitchWatchChatController(
        runtimeFactory: ({required authenticated}) => runtime,
        authService: auth,
        dropsAuthService: drops,
        authApi: validation,
        recentMessagesApi: _Recent(),
        chatPort: port,
        engagementPort: _Engagement(),
        specialMessagesRuntime: _Special(),
        channelLogin: () => 'fixture',
        channelId: () => '7',
        viewerId: () => '42',
        channelPointsSnapshot: () => null,
        refreshEngagement: ({bool showSnackOnError = false}) async {},
        refreshSpecialMessages: ({bool autoSelectPending = false}) async {},
        onChannelIdResolved: (_) {},
        onViewerResolved: (_, _) {},
        showMessage: (_) {},
      );
      addTearDown(controller.dispose);
      final connection = controller.connectChat('fixture');
      await drops.started.future;
      final viewer = TwitchViewerSession.forAuth(auth);
      final before = viewer.snapshot;
      if (stage == 'drops') {
        await viewer.resolve(validation, forceValidate: true);
      }
      drops.release.complete();
      await runtime.started.future;
      if (stage == 'irc') await viewer.resolve(validation, forceValidate: true);
      runtime.gate.complete();
      await connection;
      if (stage == 'supplement') {
        await viewer.resolve(validation, forceValidate: true);
      }
      if (stage != 'official') expect(viewer.snapshot, isNot(same(before)));
      port.release.complete(
        TwitchChatStartupSnapshot(
          channelLogin: 'fixture',
          channelId: '7',
          badgeCatalog: const TwitchBadgeCatalog(),
          operations: const [],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.runtime, same(runtime));
      expect(runtime.disposals, 0);
      expect(runtime.supplements, 1);
      if (port is _OfficialHistoryGatePort) {
        // Badge supplement is already applied while official history waits.
        await viewer.resolve(validation, forceValidate: true);
        port.history.complete([
          {'id': 'official', 'text': 'history', 'login': 'viewer'},
        ]);
        await Future<void>.delayed(Duration.zero);
        expect(runtime.supplements, 2);
        expect(controller.runtime, same(runtime));
      }
      expect(controller.canSendForCurrentViewer, isTrue);
    });
  }
  for (final oldFails in [false, true]) {
    test(
      'Obsolete special send cannot release newer send oldFails=$oldFails',
      () async {
        final client = TwitchApiClient();
        addTearDown(() => client.close(force: true));
        final oldRequest = _RewardGate();
        final newRequest = _RewardGate();
        final port = _QueuedRewards([oldRequest, newRequest]);
        final notices = <String>[];
        var refreshes = 0;
        var notifications = 0;
        final controller = TwitchWatchChatController(
          runtimeFactory: ({required authenticated}) => _ReadyRuntime(),
          authService: _Auth(client),
          dropsAuthService: _ReadyDrops(),
          authApi: _ReadyValidation(client, ['chat:read', 'chat:edit']),
          recentMessagesApi: _Recent(),
          chatPort: _StartupPort(),
          engagementPort: port,
          specialMessagesRuntime: _Special(),
          channelLogin: () => 'fixture',
          channelId: () => '7',
          viewerId: () => '42',
          channelPointsSnapshot: () => null,
          refreshEngagement: ({bool showSnackOnError = false}) async {
            refreshes++;
          },
          refreshSpecialMessages: ({bool autoSelectPending = false}) async {},
          onChannelIdResolved: (_) {},
          onViewerResolved: (_, _) {},
          showMessage: notices.add,
        );
        addTearDown(controller.dispose);
        controller.addListener(() => notifications++);
        await controller.connectChat('fixture');
        const pending = TwitchPendingSpecialMessage(
          kind: TwitchPendingSpecialMessageKind.channelPointRewardMessage,
          channelLogin: 'fixture',
          channelId: '7',
          title: 'fixture',
          subtitle: '',
          payload: {
            'reward': <String, dynamic>{'id': 'fixture-reward'},
          },
        );
        controller.setPendingSpecialMessage(pending);
        final error = StateError('fixture old failure');
        final oldObserved = expectLater(
          controller.sendMessage('fixture text'),
          oldFails ? throwsA(same(error)) : completes,
        );
        await oldRequest.started.future;
        await controller.disposeRuntime();
        await controller.connectChat('fixture');
        final replacement = pending.copyWith(title: 'replacement');
        controller.setPendingSpecialMessage(replacement);
        final newSend = controller.sendMessage('fixture text');
        await newRequest.started.future;
        final beforeOldCompletion = notifications;
        if (oldFails) {
          oldRequest.gate.completeError(error);
        } else {
          oldRequest.gate.complete(
            const TwitchWatchRewardRedeemResult(title: 'old'),
          );
        }
        await oldObserved;
        expect(controller.sending, isTrue);
        expect(controller.pendingSpecialMessage, same(replacement));
        expect(notices, isEmpty);
        expect(refreshes, 0);
        expect(notifications, beforeOldCompletion);
        newRequest.gate.complete(
          const TwitchWatchRewardRedeemResult(title: 'new'),
        );
        await newSend;
        expect(controller.sending, isFalse);
        expect(controller.pendingSpecialMessage, isNull);
        expect(notices, ['已兌換 new']);
        expect(refreshes, 1);
        expect(port.calls, 2);
      },
    );
  }
  for (final streak in [false, true]) {
    for (final close in [false, true]) {
      for (final rejected in [false, true]) {
        test(
          'Special branch streak=$streak close=$close rejected=$rejected',
          () async {
            final client = TwitchApiClient();
            addTearDown(() => client.close(force: true));
            final Object payload = streak
                ? const TwitchWatchStreakStatusStage251(
                    channelLogin: 'fixture',
                    streakCount: 3,
                    canShare: true,
                  )
                : const TwitchResubNotificationStage251(
                    channelLogin: 'fixture',
                    cumulativeMonths: 12,
                    canShare: true,
                    token: 'fixture-only',
                  );
            final port = _SpecialGate(
              streak ? #shareWatchStreak : #useResubToken,
              payload,
            );
            final notices = <String>[];
            var refreshes = 0;
            var notifications = 0;
            final controller = TwitchWatchChatController(
              runtimeFactory: ({required authenticated}) => _ReadyRuntime(),
              authService: _Auth(client),
              dropsAuthService: _ReadyDrops(),
              authApi: _ReadyValidation(client, ['chat:read', 'chat:edit']),
              recentMessagesApi: _Recent(),
              chatPort: _StartupPort(),
              engagementPort: _Engagement(),
              specialMessagesRuntime: port,
              channelLogin: () => 'fixture',
              channelId: () => '7',
              viewerId: () => '42',
              channelPointsSnapshot: () => null,
              refreshEngagement: ({bool showSnackOnError = false}) async {
                fail('Special branch must not refresh channel points');
              },
              refreshSpecialMessages: ({bool autoSelectPending = false}) async {
                expect(autoSelectPending, isFalse);
                refreshes++;
              },
              onChannelIdResolved: (_) {},
              onViewerResolved: (_, _) {},
              showMessage: notices.add,
            );
            if (!close) addTearDown(controller.dispose);
            controller.addListener(() => notifications++);
            await controller.connectChat('fixture');
            final pending = TwitchPendingSpecialMessage(
              kind: streak
                  ? TwitchPendingSpecialMessageKind.watchStreak
                  : TwitchPendingSpecialMessageKind.resub,
              channelLogin: 'fixture',
              title: 'fixture',
              subtitle: '',
              payload: {streak ? 'watchStreak' : 'resub': payload},
            );
            controller.setPendingSpecialMessage(pending);
            final observed = expectLater(
              controller.sendMessage('fixture text'),
              rejected ? throwsStateError : completes,
            );
            await port.started.future;
            if (close) controller.dispose();
            final beforeCompletion = notifications;
            port.gate.complete(
              TwitchViewerSpecialMessageSendResultStage251(
                ok: !rejected,
                operation: streak ? 'shareWatchStreak' : 'useResubToken',
                error: rejected ? 'fixture-rejection' : null,
              ),
            );
            await observed;
            expect(port.calls, 1);
            expect(controller.sending, isFalse);
            expect(
              notices,
              close
                  ? isEmpty
                  : [
                      rejected
                          ? '特殊訊息送出失敗，請稍後再試。'
                          : streak
                          ? '已分享連續觀看 3場'
                          : '已分享訂閱 12 個月',
                    ],
            );
            expect(refreshes, !close && !rejected ? 1 : 0);
            expect(
              controller.pendingSpecialMessage,
              !close && !rejected ? isNull : same(pending),
            );
            if (close) expect(notifications, beforeCompletion);
          },
        );
      }
    }
  }
  for (final change in ['identity', 'pending', 'runtime', 'duplicate']) {
    test('Special send preflight and duplicate guard change=$change', () async {
      final client = TwitchApiClient();
      addTearDown(() => client.close(force: true));
      final auth = _SwitchingAuth(client);
      final port = _RewardGate();
      final notices = <String>[];
      var refreshes = 0;
      final controller = TwitchWatchChatController(
        runtimeFactory: ({required authenticated}) => _ReadyRuntime(),
        authService: auth,
        dropsAuthService: _ReadyDrops(),
        authApi: _ReadyValidation(client, ['chat:read', 'chat:edit']),
        recentMessagesApi: _Recent(),
        chatPort: _StartupPort(),
        engagementPort: port,
        specialMessagesRuntime: _Special(),
        channelLogin: () => 'fixture',
        channelId: () => '7',
        viewerId: () => '42',
        channelPointsSnapshot: () => null,
        refreshEngagement: ({bool showSnackOnError = false}) async {
          refreshes++;
        },
        refreshSpecialMessages: ({bool autoSelectPending = false}) async {},
        onChannelIdResolved: (_) {},
        onViewerResolved: (_, _) {},
        showMessage: notices.add,
      );
      addTearDown(controller.dispose);
      await controller.connectChat('fixture');
      const pending = TwitchPendingSpecialMessage(
        kind: TwitchPendingSpecialMessageKind.channelPointRewardMessage,
        channelLogin: 'fixture',
        channelId: '7',
        title: 'fixture',
        subtitle: '',
        payload: {
          'reward': <String, dynamic>{'id': 'fixture-reward'},
        },
      );
      final replacement = pending.copyWith(title: 'replacement');
      controller.setPendingSpecialMessage(pending);
      var changed = false;
      Future<void>? disposing;
      if (change != 'duplicate') {
        controller.addListener(() {
          if (changed || !controller.sending) return;
          changed = true;
          switch (change) {
            case 'identity':
              auth.change('replacement-fixture-token');
              break;
            case 'pending':
              controller.setPendingSpecialMessage(replacement);
              break;
            case 'runtime':
              disposing = controller.disposeRuntime();
              break;
          }
        });
      }
      final first = controller.sendMessage('fixture text');
      if (change == 'duplicate') {
        await port.started.future;
        await controller.sendMessage('fixture text');
        await controller.sendPendingSpecialMessage(pending, 'fixture text');
        expect(port.calls, 1);
        expect(controller.sending, isTrue);
        port.gate.complete(
          const TwitchWatchRewardRedeemResult(title: 'fixture'),
        );
      }
      await first;
      await disposing;
      expect(port.calls, change == 'duplicate' ? 1 : 0);
      expect(controller.sending, isFalse);
      expect(notices.length, change == 'duplicate' ? 1 : 0);
      expect(refreshes, change == 'duplicate' ? 1 : 0);
      expect(
        controller.pendingSpecialMessage,
        change == 'duplicate'
            ? isNull
            : same(change == 'pending' ? replacement : pending),
      );
      if (change != 'duplicate') expect(changed, isTrue);
    });
  }
  for (final change in ['dispose', 'runtime', 'identity', 'pending', 'none']) {
    for (final fails in [false, true]) {
      test('Special send late result change=$change fails=$fails', () async {
        final client = TwitchApiClient();
        addTearDown(() => client.close(force: true));
        final auth = _SwitchingAuth(client);
        final port = _RewardGate();
        final notices = <String>[];
        var refreshes = 0;
        var notifications = 0;
        final controller = TwitchWatchChatController(
          runtimeFactory: ({required authenticated}) => _ReadyRuntime(),
          authService: auth,
          dropsAuthService: _ReadyDrops(),
          authApi: _ReadyValidation(client, ['chat:read', 'chat:edit']),
          recentMessagesApi: _Recent(),
          chatPort: _StartupPort(),
          engagementPort: port,
          specialMessagesRuntime: _Special(),
          channelLogin: () => 'fixture',
          channelId: () => '7',
          viewerId: () => '42',
          channelPointsSnapshot: () => null,
          refreshEngagement: ({bool showSnackOnError = false}) async {
            refreshes++;
          },
          refreshSpecialMessages: ({bool autoSelectPending = false}) async {},
          onChannelIdResolved: (_) {},
          onViewerResolved: (_, _) {},
          showMessage: notices.add,
        );
        if (change != 'dispose') addTearDown(controller.dispose);
        controller.addListener(() => notifications++);
        await controller.connectChat('fixture');
        const pending = TwitchPendingSpecialMessage(
          kind: TwitchPendingSpecialMessageKind.channelPointRewardMessage,
          channelLogin: 'fixture',
          channelId: '7',
          title: 'fixture',
          subtitle: '',
          payload: {
            'reward': <String, dynamic>{'id': 'fixture-reward'},
          },
        );
        controller.setPendingSpecialMessage(pending);
        final error = StateError('fixture special failure');
        final observed = expectLater(
          controller.sendMessage('fixture text'),
          fails ? throwsA(same(error)) : completes,
        );
        await port.started.future;
        final replacement = pending.copyWith(title: 'replacement');
        switch (change) {
          case 'dispose':
            controller.dispose();
            break;
          case 'runtime':
            await controller.disposeRuntime();
            await controller.connectChat('fixture');
            break;
          case 'identity':
            auth.change('replacement-fixture-token');
            break;
          case 'pending':
            controller.setPendingSpecialMessage(replacement);
            break;
        }
        final beforeCompletion = notifications;
        if (fails) {
          port.gate.completeError(error);
        } else {
          port.gate.complete(
            const TwitchWatchRewardRedeemResult(title: 'fixture'),
          );
        }
        await observed;
        expect(notices.length, change == 'none' ? 1 : 0);
        if (change == 'none' && fails) {
          expect(notices.single, '特殊訊息送出失敗，請稍後再試。');
        }
        expect(refreshes, change == 'none' && !fails ? 1 : 0);
        expect(controller.sending, isFalse);
        expect(
          controller.pendingSpecialMessage,
          change == 'none' && !fails
              ? isNull
              : same(change == 'pending' ? replacement : pending),
        );
        if (change == 'dispose' || change == 'runtime') {
          expect(notifications, beforeCompletion);
        }
        expect(port.calls, 1);
      });
    }
  }
  for (final scopes in <List<String>>[
    [],
    ['chat:edit'],
    ['chat:read'],
    ['chat:read', 'chat:edit'],
  ]) {
    test(
      'Missing IRC read scope uses anonymous transport without logging out scopes=${scopes.join(',')}',
      () async {
        final client = TwitchApiClient();
        addTearDown(() => client.close(force: true));
        final auth = _Auth(client);
        final runtime = _ReadTransportRuntime();
        bool? authenticatedTransport;
        final controller = TwitchWatchChatController(
          runtimeFactory: ({required authenticated}) {
            authenticatedTransport = authenticated;
            return runtime;
          },
          authService: auth,
          dropsAuthService: _ReadyDrops(),
          authApi: _ReadyValidation(client, scopes),
          recentMessagesApi: _Recent(),
          chatPort: _StartupPort(),
          engagementPort: _Engagement(),
          specialMessagesRuntime: _Special(),
          channelLogin: () => 'fixture',
          channelId: () => '7',
          viewerId: () => '42',
          channelPointsSnapshot: () => null,
          refreshEngagement: ({bool showSnackOnError = false}) async {},
          refreshSpecialMessages: ({bool autoSelectPending = false}) async {},
          onChannelIdResolved: (_) {},
          onViewerResolved: (_, _) {},
          showMessage: (_) {},
        );
        addTearDown(controller.dispose);
        await controller.connectChat('fixture');
        final canRead = scopes.contains('chat:read');
        expect(authenticatedTransport, canRead);
        expect(runtime.receivedToken, canRead ? 'fixture-token' : null);
        expect(
          runtime.receivedNick,
          canRead ? 'fixture-viewer' : 'justinfan12345',
        );
        expect(runtime.receivedViewerId, '42');
        expect(
          TwitchViewerSession.forAuth(auth).status,
          TwitchViewerStatus.authenticated,
        );
        expect(controller.isReadOnlyGuest, isFalse);
        expect(
          controller.canSendForCurrentViewer,
          canRead && scopes.contains('chat:edit'),
        );
      },
    );
  }
  for (final beforeTransport in [false, true]) {
    for (final logout in [false, true]) {
      for (final fails in beforeTransport ? [false] : [false, true]) {
        test(
          'Send identity guard before=$beforeTransport logout=$logout fails=$fails',
          () async {
            final client = TwitchApiClient();
            addTearDown(() => client.close(force: true));
            final auth = _SwitchingAuth(client);
            final _ReadyRuntime runtime = beforeTransport
                ? _ReadyRuntime()
                : _SendGateRuntime();
            final notices = <String>[];
            final controller = TwitchWatchChatController(
              runtimeFactory: ({required authenticated}) => runtime,
              authService: auth,
              dropsAuthService: _ReadyDrops(),
              authApi: _ReadyValidation(client, ['chat:read', 'chat:edit']),
              recentMessagesApi: _Recent(),
              chatPort: _StartupPort(),
              engagementPort: _Engagement(),
              specialMessagesRuntime: _Special(),
              channelLogin: () => 'fixture',
              channelId: () => '7',
              viewerId: () => '42',
              channelPointsSnapshot: () => null,
              refreshEngagement: ({bool showSnackOnError = false}) async {},
              refreshSpecialMessages:
                  ({bool autoSelectPending = false}) async {},
              onChannelIdResolved: (_) {},
              onViewerResolved: (_, _) {},
              showMessage: notices.add,
            );
            addTearDown(controller.dispose);
            await controller.connectChat('fixture');
            void change() =>
                auth.change(logout ? null : 'replacement-fixture-token');
            var changed = false;
            if (beforeTransport) {
              controller.addListener(() {
                if (!changed && controller.sending) {
                  changed = true;
                  change();
                }
              });
            }
            final originalError = StateError('fixture original send failure');
            final pending = controller.sendMessage('fixture message');
            final observed = expectLater(
              pending,
              fails ? throwsA(same(originalError)) : completes,
            );
            if (runtime is _SendGateRuntime) {
              await runtime.started.future;
              change();
              expect(controller.canSendForCurrentViewer, isFalse);
              if (fails) {
                runtime.gate.completeError(originalError);
              } else {
                runtime.gate.complete();
              }
            }
            await observed;
            expect(notices, isEmpty);
            expect(controller.sending, isFalse);
            expect(controller.canSendForCurrentViewer, isFalse);
            expect(controller.isReadOnlyGuest, logout);
            if (beforeTransport) expect(changed, isTrue);
            expect(runtime.sends, beforeTransport ? 0 : 1);
            await controller.sendMessage('fixture disallowed retry');
            expect(runtime.sends, beforeTransport ? 0 : 1);
          },
        );
      }
    }
  }
  for (final close in [false, true]) {
    for (final fails in [false, true]) {
      test(
        'Late send result cannot affect new lifecycle close=$close fails=$fails',
        () async {
          final client = TwitchApiClient();
          addTearDown(() => client.close(force: true));
          final oldRuntime = _SendGateRuntime();
          final newRuntime = _SendGateRuntime();
          var creations = 0;
          final notices = <String>[];
          final controller = TwitchWatchChatController(
            runtimeFactory: ({required authenticated}) =>
                creations++ == 0 ? oldRuntime : newRuntime,
            authService: _Auth(client),
            dropsAuthService: _ReadyDrops(),
            authApi: _ReadyValidation(client, ['chat:read', 'chat:edit']),
            recentMessagesApi: _Recent(),
            chatPort: _StartupPort(),
            engagementPort: _Engagement(),
            specialMessagesRuntime: _Special(),
            channelLogin: () => 'fixture',
            channelId: () => '7',
            viewerId: () => '42',
            channelPointsSnapshot: () => null,
            refreshEngagement: ({bool showSnackOnError = false}) async {},
            refreshSpecialMessages: ({bool autoSelectPending = false}) async {},
            onChannelIdResolved: (_) {},
            onViewerResolved: (_, _) {},
            showMessage: notices.add,
          );
          if (!close) addTearDown(controller.dispose);
          var notifications = 0;
          controller.addListener(() => notifications++);
          await controller.connectChat('old-fixture');
          final oldSend = controller.sendMessage('fixture old message');
          final observed = expectLater(
            oldSend,
            fails ? throwsStateError : completes,
          );
          await oldRuntime.started.future;
          Future<void>? newSend;
          if (close) {
            controller.dispose();
          } else {
            await controller.connectChat('new-fixture');
          }
          final afterChange = notifications;
          try {
            if (!close) {
              expect(controller.sending, isFalse);
              newSend = controller.sendMessage('fixture new message');
              await newRuntime.started.future;
            }
          } finally {
            if (fails) {
              oldRuntime.gate.completeError(
                StateError('fixture old send failed'),
              );
            } else {
              oldRuntime.gate.complete();
            }
            await observed;
          }
          try {
            expect(notices, isEmpty);
            if (close) {
              expect(notifications, afterChange);
            } else {
              expect(controller.sending, isTrue);
              expect(newRuntime.gate.isCompleted, isFalse);
            }
          } finally {
            if (newSend != null) {
              newRuntime.gate.complete();
              await newSend;
            }
          }
          if (!close) expect(controller.sending, isFalse);
        },
      );
    }
  }
  for (final phase in ['connect', 'startup', 'listener']) {
    for (final logout in [false, true]) {
      test(
        'Identity change rejects late chat work phase=$phase logout=$logout',
        () async {
          final client = TwitchApiClient();
          addTearDown(() => client.close(force: true));
          final auth = _SwitchingAuth(client);
          final _ReadyRuntime runtime = phase == 'connect'
              ? _GatedRuntime()
              : _ReadyRuntime();
          final startup = phase == 'startup'
              ? _StartupGatePort()
              : _StartupPort();
          var channelCallbacks = 0;
          final controller = TwitchWatchChatController(
            runtimeFactory: ({required authenticated}) => runtime,
            authService: auth,
            dropsAuthService: _ReadyDrops(),
            authApi: _ReadyValidation(client, ['chat:read', 'chat:edit']),
            recentMessagesApi: _Recent(),
            chatPort: startup,
            engagementPort: _Engagement(),
            specialMessagesRuntime: _Special(),
            channelLogin: () => 'fixture',
            channelId: () => '7',
            viewerId: () => '42',
            channelPointsSnapshot: () => null,
            refreshEngagement: ({bool showSnackOnError = false}) async {},
            refreshSpecialMessages: ({bool autoSelectPending = false}) async {},
            onChannelIdResolved: (_) => channelCallbacks++,
            onViewerResolved: (_, _) {},
            showMessage: (_) {},
          );
          addTearDown(controller.dispose);
          void change() =>
              auth.change(logout ? null : 'replacement-fixture-token');
          var listenerChanged = false;
          if (phase == 'listener') {
            controller.addListener(() {
              if (!listenerChanged && controller.runtime != null) {
                listenerChanged = true;
                change();
              }
            });
          }
          final connection = controller.connectChat('fixture');
          if (runtime is _GatedRuntime) {
            await runtime.started.future;
            change();
            runtime.gate.complete();
          }
          await connection;
          if (startup is _StartupGatePort) {
            await startup.started.future;
            change();
            startup.release.complete(
              const TwitchChatStartupSnapshot(
                channelLogin: 'fixture',
                channelId: '7',
                badgeCatalog: TwitchBadgeCatalog(),
                operations: [],
              ),
            );
          }
          await Future<void>.delayed(Duration.zero);
          expect(runtime.supplements, 0);
          expect(channelCallbacks, 0);
          expect(controller.canSendForCurrentViewer, isFalse);
          expect(controller.isReadOnlyGuest, logout);
          await controller.sendMessage('fixture after identity change');
          expect(runtime.sends, 0);
          if (phase == 'listener') {
            expect(listenerChanged, isTrue);
            expect(runtime.connects, 0);
          } else {
            expect(runtime.connects, 1);
          }
          if (phase != 'startup') {
            expect(controller.runtime, isNull);
            expect(controller.viewerLogin, isNull);
            expect(runtime.disposals, 1);
          }
        },
      );
    }
  }
  for (final logout in [false, true]) {
    test(
      'Identity changed during supplemental load cannot connect old token logout=$logout',
      () async {
        final client = TwitchApiClient();
        addTearDown(() => client.close(force: true));
        final auth = _SwitchingAuth(client);
        final drops = _GatedDrops();
        final runtime = _ReadyRuntime();
        final viewers = <String?>[];
        final controller = TwitchWatchChatController(
          runtimeFactory: ({required authenticated}) => runtime,
          authService: auth,
          dropsAuthService: drops,
          authApi: _ReadyValidation(client, ['chat:read', 'chat:edit']),
          recentMessagesApi: _Recent(),
          chatPort: _StartupPort(),
          engagementPort: _Engagement(),
          specialMessagesRuntime: _Special(),
          channelLogin: () => 'fixture',
          channelId: () => '7',
          viewerId: () => '42',
          channelPointsSnapshot: () => null,
          refreshEngagement: ({bool showSnackOnError = false}) async {},
          refreshSpecialMessages: ({bool autoSelectPending = false}) async {},
          onChannelIdResolved: (_) {},
          onViewerResolved: (login, id) => viewers.add(login),
          showMessage: (_) {},
        );
        addTearDown(controller.dispose);
        final connection = controller.connectChat('fixture');
        await drops.started.future;
        auth.change(logout ? null : 'replacement-fixture-token');
        drops.release.complete();
        await connection;
        expect(runtime.connects, 0);
        expect(controller.runtime, isNull);
        expect(controller.viewerLogin, isNull);
        expect(viewers.last, isNull);
        expect(controller.canSendForCurrentViewer, isFalse);
      },
    );
  }
  for (final close in [false, true]) {
    test(
      'Network reconnect completion is obsolete after close=$close',
      () async {
        final client = TwitchApiClient();
        addTearDown(() => client.close(force: true));
        final oldRuntime = _ReconnectRuntime();
        final newRuntime = _GatedRuntime();
        var creations = 0;
        final controller = TwitchWatchChatController(
          runtimeFactory: ({required authenticated}) =>
              creations++ == 0 ? oldRuntime : newRuntime,
          authService: _Auth(client),
          dropsAuthService: _ReadyDrops(),
          authApi: _ReadyValidation(client, ['chat:read', 'chat:edit']),
          recentMessagesApi: _Recent(),
          chatPort: _StartupPort(),
          engagementPort: _Engagement(),
          specialMessagesRuntime: _Special(),
          channelLogin: () => 'fixture',
          channelId: () => '7',
          viewerId: () => '42',
          channelPointsSnapshot: () => null,
          refreshEngagement: ({bool showSnackOnError = false}) async {},
          refreshSpecialMessages: ({bool autoSelectPending = false}) async {},
          onChannelIdResolved: (_) {},
          onViewerResolved: (_, _) {},
          showMessage: (_) {},
        );
        if (!close) addTearDown(controller.dispose);
        var notifications = 0;
        controller.addListener(() => notifications++);
        await controller.connectChat('fixture');
        oldRuntime.ready = false;
        final reconnect = controller.reconnectAfterNetworkRestored();
        await oldRuntime.started.future;
        if (close) {
          controller.dispose();
          final afterDispose = notifications;
          oldRuntime.gate.complete();
          await reconnect;
          expect(notifications, afterDispose);
          expect(controller.runtime, isNull);
          expect(controller.canSendForCurrentViewer, isFalse);
        } else {
          final next = controller.connectChat('next-fixture');
          await newRuntime.started.future;
          oldRuntime.gate.complete();
          await reconnect;
          try {
            expect(controller.runtime, same(newRuntime));
            expect(controller.connectingChat, isTrue);
            expect(controller.canSendForCurrentViewer, isFalse);
          } finally {
            newRuntime.gate.complete();
            await next;
          }
          expect(controller.canSendForCurrentViewer, isTrue);
        }
      },
    );
  }
  for (final oldFails in [false, true]) {
    test(
      'Old chat completion cannot release newer connection oldFails=$oldFails',
      () async {
        final client = TwitchApiClient();
        addTearDown(() => client.close(force: true));
        final oldRuntime = _GatedRuntime();
        final newRuntime = _GatedRuntime();
        var creations = 0;
        final controller = TwitchWatchChatController(
          runtimeFactory: ({required authenticated}) =>
              creations++ == 0 ? oldRuntime : newRuntime,
          authService: _Auth(client),
          dropsAuthService: _ReadyDrops(),
          authApi: _ReadyValidation(client, ['chat:read', 'chat:edit']),
          recentMessagesApi: _Recent(),
          chatPort: _StartupPort(),
          engagementPort: _Engagement(),
          specialMessagesRuntime: _Special(),
          channelLogin: () => 'fixture',
          channelId: () => '7',
          viewerId: () => '42',
          channelPointsSnapshot: () => null,
          refreshEngagement: ({bool showSnackOnError = false}) async {},
          refreshSpecialMessages: ({bool autoSelectPending = false}) async {},
          onChannelIdResolved: (_) {},
          onViewerResolved: (_, _) {},
          showMessage: (_) {},
        );
        addTearDown(controller.dispose);
        final oldConnection = controller.connectChat('old-fixture');
        final oldObserved = expectLater(
          oldConnection,
          oldFails ? throwsStateError : completes,
        );
        await oldRuntime.started.future;
        final newConnection = controller.connectChat('new-fixture');
        await newRuntime.started.future;
        expect(controller.runtime, same(newRuntime));
        if (oldFails) {
          oldRuntime.gate.completeError(
            StateError('fixture old connection failed'),
          );
        } else {
          oldRuntime.gate.complete();
        }
        await oldObserved;
        try {
          expect(newRuntime.gate.isCompleted, isFalse);
          expect(controller.connectingChat, isTrue);
          expect(controller.canSendForCurrentViewer, isFalse);
          await controller.sendMessage('fixture waiting');
          expect(newRuntime.sends, 0);
        } finally {
          newRuntime.gate.complete();
          await newConnection;
        }
        expect(controller.connectingChat, isFalse);
        expect(controller.canSendForCurrentViewer, isTrue);
        await controller.sendMessage('fixture ready');
        expect(newRuntime.sends, 1);
        expect(oldRuntime.sends, 0);
      },
    );
  }
  for (final scopes in <List<String>>[
    [],
    ['chat:read'],
    ['chat:edit'],
    ['user:write:chat'],
    ['chat:read', 'chat:edit'],
  ]) {
    test('IRC composer permission guard scopes=${scopes.join(',')}', () async {
      final client = TwitchApiClient();
      addTearDown(() => client.close(force: true));
      final runtime = _ReadyRuntime();
      final notices = <String>[];
      final controller = TwitchWatchChatController(
        runtimeFactory: ({required authenticated}) => runtime,
        authService: _Auth(client),
        dropsAuthService: _ReadyDrops(),
        authApi: _ReadyValidation(client, scopes),
        recentMessagesApi: _Recent(),
        chatPort: _StartupPort(),
        engagementPort: _Engagement(),
        specialMessagesRuntime: _Special(),
        channelLogin: () => 'fixture',
        channelId: () => '7',
        viewerId: () => '42',
        channelPointsSnapshot: () => null,
        refreshEngagement: ({bool showSnackOnError = false}) async {},
        refreshSpecialMessages: ({bool autoSelectPending = false}) async {},
        onChannelIdResolved: (_) {},
        onViewerResolved: (_, _) {},
        showMessage: notices.add,
      );
      addTearDown(controller.dispose);
      expect(controller.hasCurrentViewer, isFalse);
      expect(controller.canSendForCurrentViewer, isFalse);
      await controller.sendMessage('fixture before validation');
      expect(runtime.sends, 0);
      notices.clear();
      await controller.connectChat('fixture');
      final allowed =
          scopes.contains('chat:read') && scopes.contains('chat:edit');
      expect(controller.isReadOnlyGuest, isFalse);
      expect(controller.hasCurrentViewer, isTrue);
      expect(controller.canSendForCurrentViewer, allowed);
      await controller.sendMessage('fixture message');
      expect(runtime.sends, allowed ? 1 : 0);
      expect(notices, allowed ? isEmpty : contains('目前帳號缺少聊天室發言權限，請重新授權。'));
      if (!allowed) {
        controller.pendingSpecialMessage = const TwitchPendingSpecialMessage(
          kind: TwitchPendingSpecialMessageKind.preview,
          channelLogin: 'fixture',
          title: 'fixture preview',
          subtitle: '',
          previewOnly: true,
        );
        expect(controller.canSendForCurrentViewer, isTrue);
        await controller.sendMessage('fixture preview');
        expect(runtime.sends, 0);
        expect(controller.pendingSpecialMessage, isNull);
        expect(controller.canSendForCurrentViewer, isFalse);
      }
      await controller.disposeRuntime();
      expect(controller.hasCurrentViewer, isFalse);
    });
  }
  for (final failConnect in [false, true]) {
    test(
      'Guest chat injected runtime connect/read-only and retry failure=$failConnect',
      () async {
        final client = TwitchApiClient();
        addTearDown(() => client.close(force: true));
        final validation = _Validation(client);
        final port = _StartupPort();
        final runtime = _GuestRuntime()..failConnect = failConnect;
        var factories = 0;
        var resolved = 0;
        final controller = TwitchWatchChatController(
          runtimeFactory: ({required authenticated}) {
            expect(authenticated, isFalse);
            factories++;
            return runtime;
          },
          authService: _GuestAuth(client),
          dropsAuthService: _Drops(),
          authApi: validation,
          recentMessagesApi: _Recent(),
          chatPort: port,
          engagementPort: _Engagement(),
          specialMessagesRuntime: _Special(),
          channelLogin: () => 'fixture',
          channelId: () => null,
          viewerId: () => null,
          channelPointsSnapshot: () => null,
          refreshEngagement: ({bool showSnackOnError = false}) async {},
          refreshSpecialMessages: ({bool autoSelectPending = false}) async {},
          onChannelIdResolved: (id) {
            expect(id, '7');
            resolved++;
          },
          onViewerResolved: (login, id) {
            expect(login, isNull);
            expect(id, isNull);
          },
          showMessage: (_) => fail('Unexpected guest message'),
        );
        addTearDown(controller.dispose);
        final connection = controller.connectChat('fixture');
        if (failConnect) {
          await expectLater(connection, throwsStateError);
          expect(controller.connectingChat, isFalse);
          runtime.failConnect = false;
          await controller.connectChat('fixture');
        } else {
          await connection;
        }
        await Future<void>.value();
        expect(factories, failConnect ? 2 : 1);
        expect(runtime.connects, factories);
        expect(port.requests, factories);
        expect(runtime.supplements, 1);
        expect(resolved, 1);
        expect(validation.started.isCompleted, isFalse);
        expect(controller.isReadOnlyGuest, isTrue);
        expect(controller.canSendForCurrentViewer, isFalse);
        expect(controller.connectingChat, isFalse);
        await controller.disposeRuntime();
        expect(runtime.disposals, factories);
        expect(controller.runtime, isNull);
      },
    );
  }
  for (final fails in [false, true]) {
    test(
      'Disposed chat ignores late validation without connection or notification: fails=$fails',
      () async {
        final client = TwitchApiClient();
        addTearDown(() => client.close(force: true));
        final auth = _Auth(client);
        final validation = _Validation(client);
        var viewerCallbacks = 0;
        var notifications = 0;
        final controller = TwitchWatchChatController(
          authService: auth,
          dropsAuthService: _Drops(),
          authApi: validation,
          recentMessagesApi: _Recent(),
          chatPort: _ChatPort(),
          engagementPort: _Engagement(),
          specialMessagesRuntime: _Special(),
          channelLogin: () => 'fixture',
          channelId: () => null,
          viewerId: () => null,
          channelPointsSnapshot: () => null,
          refreshEngagement: ({bool showSnackOnError = false}) async {},
          refreshSpecialMessages: ({bool autoSelectPending = false}) async {},
          onChannelIdResolved: (_) {},
          onViewerResolved: (_, _) {
            viewerCallbacks++;
          },
          showMessage: (_) {},
        );
        controller.addListener(() => notifications++);
        final pending = controller.connectChat('fixture');
        await validation.started.future;
        controller.dispose();
        final countAfterDispose = notifications;
        final expected = expectLater(
          pending,
          fails ? throwsA(isA<StateError>()) : completes,
        );
        if (fails) {
          validation.gate.completeError(
            StateError('fixture validation unavailable'),
          );
        } else {
          validation.gate.complete(
            const TwitchTokenValidation(
              clientId: 'fixture-client',
              login: 'fixture-viewer',
              userId: '1',
              scopes: ['chat:read', 'chat:edit'],
              expiresIn: 3600,
            ),
          );
        }
        await expected;
        expect(viewerCallbacks, 0);
        expect(controller.runtime, isNull);
        expect(notifications, countAfterDispose);
        expect(controller.canSendForCurrentViewer, isFalse);
        await controller.connectChat('fixture');
        expect(viewerCallbacks, 0);
        expect(notifications, countAfterDispose);
      },
    );
  }
}
