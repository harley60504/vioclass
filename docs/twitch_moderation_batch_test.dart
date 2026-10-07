// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message_metadata.dart';
import '../lib/features/twitch/models/chat/twitch_chat_runtime_message.dart';
import '../lib/features/twitch/services/chat/twitch_moderation_batch_controller.dart';

TwitchChatRuntimeMessage _message(
  String id, {
  String room = '20',
  String owner = '30',
  String text = 'fixture',
  TwitchChatMessageSource source = TwitchChatMessageSource.liveIrc,
}) {
  final raw = TwitchChatMessage(
    raw: '',
    command: 'PRIVMSG',
    channel: 'fixture',
    userLogin: 'fixture',
    displayName: 'Fixture',
    message: text,
    source: source,
    tags: {'id': id, 'room-id': room, 'user-id': owner},
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

class _Api extends TwitchModerationApiService {
  final sent = <String>[];
  final userActions = <String>[];
  Future<void> Function()? response;
  _Api()
    : super(
        client: TwitchApiClient(),
        tokenProviders: const [],
        broadcasterId: '20',
        moderatorId: '10',
      );
  @override
  Future<void> deleteMessages({String? messageId}) async {
    expect(messageId, isNotNull);
    expect(messageId, isNotEmpty);
    sent.add(messageId!);
    await response?.call();
  }

  @override
  Future<void> warn(String userId, {required String reason}) async {
    userActions.add('warn:$userId:$reason');
    await response?.call();
  }

  @override
  Future<void> ban(String userId, {int? seconds, String reason = ''}) async {
    userActions.add('timeout:$userId:$seconds:$reason');
    await response?.call();
  }
}

void main() {
  late _Api api;
  late TwitchModerationBatchController controller;
  var permitted = true;
  final delays = <Duration>[];
  setUp(() {
    permitted = true;
    delays.clear();
    api = _Api();
    controller = TwitchModerationBatchController(
      api: api,
      canModerate: () => permitted,
      wait: (duration) async {
        delays.add(duration);
      },
    );
  });
  tearDown(() {
    controller.dispose();
    api.client.close();
  });
  test(
    'Warnings deduplicate users, freeze preview identity and send a fixed reason once',
    () async {
      final first = _message('a');
      final plan = controller.prepareUsers(
        [first, _message('b'), _message('c', owner: '40')],
        action: TwitchModerationUserBatchAction.warn,
        reason: ' fixture reason ',
      );
      expect(plan.users.map((user) => user.userId), ['30', '40']);
      expect(plan.excluded, 1);
      expect(api.userActions, isEmpty);
      first.source.tags['user-id'] = '99';
      await controller.executeUsers(plan, canManageTarget: (_) => true);
      await controller.executeUsers(plan, canManageTarget: (_) => true);
      expect(api.userActions, [
        'warn:30:fixture reason',
        'warn:40:fixture reason',
      ]);
      expect(api.sent, isEmpty);
      expect(delays, [const Duration(milliseconds: 350)]);
    },
  );
  test('Any protected hint for a user excludes all selected occurrences', () {
    final mod = _message('mod');
    mod.source.tags['badges'] = 'moderator/1';
    final plan = controller.prepareUsers(
      [
        _message('ordinary'),
        mod,
        _message('self', owner: '10'),
        _message('broadcaster', owner: '20'),
        _message('shared', room: '99', owner: '50'),
        _message(
          'echo',
          owner: '60',
          source: TwitchChatMessageSource.localEcho,
        ),
        _message('valid', owner: '40'),
      ],
      action: TwitchModerationUserBatchAction.warn,
      reason: 'fixture',
    );
    expect(plan.users.map((user) => user.userId), ['40']);
    expect(plan.excluded, 6);
    expect(api.userActions, isEmpty);
  });
  test(
    'Invalid user action reason/duration never replaces an existing delete preview',
    () async {
      final original = controller.prepareDelete([_message('original')]);
      for (final reason in ['', ' ']) {
        expect(
          () => controller.prepareUsers(
            [_message('a')],
            action: TwitchModerationUserBatchAction.warn,
            reason: reason,
          ),
          throwsA(isA<TwitchModerationException>()),
        );
      }
      expect(
        () => controller.prepareUsers(
          [_message('a')],
          action: TwitchModerationUserBatchAction.warn,
          reason: 'x' * 501,
        ),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(
        () => controller.prepareUsers(
          [_message('a')],
          action: TwitchModerationUserBatchAction.warn,
          reason: 'valid',
          seconds: 1,
        ),
        throwsA(isA<TwitchModerationException>()),
      );
      for (final seconds in [null, 0, 1209601]) {
        expect(
          () => controller.prepareUsers(
            [_message('a')],
            action: TwitchModerationUserBatchAction.timeout,
            reason: '',
            seconds: seconds,
          ),
          throwsA(isA<TwitchModerationException>()),
        );
      }
      await controller.executeDelete(original);
      expect(api.sent, ['original']);
      expect(api.userActions, isEmpty);
    },
  );
  for (final seconds in [1, 1209600]) {
    test(
      'Timeout duration $seconds is fixed and cannot become a permanent ban',
      () async {
        final plan = controller.prepareUsers(
          [_message('a')],
          action: TwitchModerationUserBatchAction.timeout,
          reason: ' fixture ',
          seconds: seconds,
        );
        await controller.executeUsers(plan, canManageTarget: (_) => true);
        expect(api.userActions, ['timeout:30:$seconds:fixture']);
        expect(controller.results['30'], TwitchModerationBatchResult.submitted);
      },
    );
  }
  test(
    'Live target role gate stops after the accepted first user without replay',
    () async {
      var allowed = true;
      api.response = () async {
        allowed = false;
      };
      final plan = controller.prepareUsers(
        [_message('a'), _message('b', owner: '40')],
        action: TwitchModerationUserBatchAction.warn,
        reason: 'fixture',
      );
      await controller.executeUsers(plan, canManageTarget: (_) => allowed);
      await controller.executeUsers(plan, canManageTarget: (_) => true);
      expect(api.userActions, ['warn:30:fixture']);
      expect(controller.results['30'], TwitchModerationBatchResult.submitted);
      expect(controller.results['40'], TwitchModerationBatchResult.rejected);
      expect(controller.problem, contains('身分已變更'));
    },
  );
  test(
    'Preview filters invalid/shared/protected/echo IDs and freezes exact targets',
    () async {
      final message = _message('a');
      final plan = controller.prepareDelete([
        message,
        message,
        _message(''),
        _message('shared', room: '99'),
        _message('owner', owner: '20'),
        _message('echo', source: TwitchChatMessageSource.localEcho),
        _message('b'),
      ]);
      expect(plan.excluded, 5);
      expect(plan.messages.map((target) => target.messageId), ['a', 'b']);
      expect(api.sent, isEmpty);
      message.source.tags['id'] = 'changed';
      await controller.executeDelete(plan);
      expect(api.sent, ['a', 'b']);
      expect(delays, [const Duration(milliseconds: 350)]);
      expect(
        controller.results.values,
        everyElement(TwitchModerationBatchResult.submitted),
      );
      await controller.executeDelete(plan);
      expect(api.sent, ['a', 'b']);
    },
  );
  test(
    'Oversized or conflicting preview fails without changing existing plan',
    () {
      final original = controller.prepareDelete([_message('original')]);
      expect(
        () =>
            controller.prepareDelete(List.generate(51, (i) => _message('$i'))),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(
        () => controller.prepareDelete([
          _message('same'),
          _message('same', text: 'conflict'),
        ]),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(original.messages.single.messageId, 'original');
      expect(controller.results.keys, ['original']);
      expect(api.sent, isEmpty);
    },
  );
  test('Cancelled preview and revoked authorization do not send', () async {
    final plan = controller.prepareDelete([_message('a')]);
    controller.cancelRemaining();
    await controller.executeDelete(plan);
    expect(api.sent, isEmpty);
    final next = controller.prepareDelete([_message('b')]);
    permitted = false;
    await controller.executeDelete(next);
    expect(api.sent, isEmpty);
    expect(controller.problem, contains('已變更'));
  });
  test(
    'Cancellation during request keeps submitted result and stops next message',
    () async {
      final gate = Completer<void>();
      api.response = () => gate.future;
      final plan = controller.prepareDelete([_message('a'), _message('b')]);
      final running = controller.executeDelete(plan);
      expect(controller.running, isTrue);
      await controller.executeDelete(plan);
      expect(api.sent, ['a']);
      controller.cancelRemaining();
      gate.complete();
      await running;
      expect(api.sent, ['a']);
      expect(controller.results['a'], TwitchModerationBatchResult.submitted);
      expect(controller.results['b'], TwitchModerationBatchResult.pending);
      expect(controller.running, isFalse);
    },
  );
  test('Replaced plan never dispatches stale preview', () async {
    final old = controller.prepareDelete([_message('a')]);
    final current = controller.prepareDelete([_message('b')]);
    await controller.executeDelete(old);
    expect(api.sent, isEmpty);
    await controller.executeDelete(current);
    expect(api.sent, ['b']);
  });
  test(
    'Disposed owner stops later writes while retaining the in-flight outcome',
    () async {
      final gate = Completer<void>();
      api.response = () => gate.future;
      final isolated = TwitchModerationBatchController(
        api: api,
        canModerate: () => true,
        wait: (_) async {},
      );
      var notifications = 0;
      isolated.addListener(() => notifications++);
      final plan = isolated.prepareDelete([_message('a'), _message('b')]);
      final running = isolated.executeDelete(plan);
      isolated.dispose();
      final beforeCompletion = notifications;
      gate.complete();
      await running;
      expect(api.sent, ['a']);
      expect(notifications, beforeCompletion);
      expect(isolated.results['a'], TwitchModerationBatchResult.submitted);
      expect(isolated.results['b'], TwitchModerationBatchResult.pending);
    },
  );
  for (final known in [true, false]) {
    test(
      'Failure stops remaining targets without retry: known=$known',
      () async {
        api.response = () async {
          if (known) throw const TwitchModerationException('fixture limit');
          throw StateError('unknown transport');
        };
        final plan = controller.prepareDelete([_message('a'), _message('b')]);
        await controller.executeDelete(plan);
        await controller.executeDelete(plan);
        expect(api.sent, ['a']);
        expect(
          controller.results['a'],
          known
              ? TwitchModerationBatchResult.rejected
              : TwitchModerationBatchResult.unknown,
        );
        expect(controller.results['b'], TwitchModerationBatchResult.pending);
        expect(controller.problem, isNotNull);
      },
    );
  }
  test(
    'Permission revoked between serial writes stops subsequent dispatch',
    () async {
      api.response = () async {
        permitted = false;
      };
      final plan = controller.prepareDelete([_message('a'), _message('b')]);
      await controller.executeDelete(plan);
      expect(api.sent, ['a']);
      expect(controller.results['a'], TwitchModerationBatchResult.submitted);
      expect(controller.results['b'], TwitchModerationBatchResult.pending);
    },
  );
}
