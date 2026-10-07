// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_moderation_log_entry.dart';
import '../lib/features/twitch/services/chat/twitch_moderation_log_archive_store.dart';
import '../lib/features/twitch/services/chat/twitch_moderation_log_controller.dart';
import '../lib/features/twitch/services/chat/twitch_moderation_log_eventsub_service.dart';

class _Api extends TwitchModerationApiService {
  Completer<void>? gate;
  String? validatedOwner;
  _Api(String owner, String channel, {bool Function()? allowed})
    : super(
        client: TwitchApiClient(),
        tokenProviders: const [],
        moderatorId: owner,
        broadcasterId: channel,
        canModerate: allowed,
      );
  @override
  Future<TwitchModerationSession> moderationLogSession() async {
    await gate?.future;
    return TwitchModerationSession(
      'fake',
      TwitchTokenValidation(
        clientId: 'fake',
        userId: validatedOwner ?? moderatorId,
        login: 'mod',
        expiresIn: 1000,
        scopes: const [],
      ),
    );
  }
}

class _Receiver extends TwitchModerationLogEventSubService {
  bool stopped = false;
  _Receiver({
    required super.api,
    required super.onEntry,
    required super.onStatus,
  }) : super(onEvent: (_, _, _) {});
  @override
  void start() {
    connected = true;
    onStatus('fake connected');
  }

  @override
  void stop() {
    stopped = true;
    connected = false;
  }

  void emit(String id) => onEntry!(
    TwitchModerationLogEntry.parse(
      id: id,
      time: DateTime.utc(2026),
      expectedBroadcasterId: api.broadcasterId,
      event: {
        'action': 'clear',
        'moderator_user_id': '40',
        'broadcaster_user_id': api.broadcasterId,
      },
    )!,
  );
}

void main() {
  late Map<String, String> disk;
  late TwitchModerationLogArchiveStore archive;
  late TwitchModerationLogController controller;
  late List<_Receiver> receivers;
  late List<_Api> apis;
  var failWrite = false;
  var writeAttempts = 0;
  Completer<void>? writeGate;
  _Api api(String owner, String channel, {bool Function()? allowed}) {
    final value = _Api(owner, channel, allowed: allowed);
    apis.add(value);
    return value;
  }

  setUp(() {
    disk = {};
    receivers = [];
    apis = [];
    failWrite = false;
    writeAttempts = 0;
    writeGate = null;
    archive = TwitchModerationLogArchiveStore(
      read: (key) async => disk[key],
      write: (key, value) async {
        writeAttempts++;
        await writeGate?.future;
        if (failWrite) throw StateError('fake write failed');
        disk[key] = value;
      },
    );
    controller = TwitchModerationLogController(
      archive: archive,
      receiverFactory: ({required api, required onEntry, required onStatus}) {
        final receiver = _Receiver(
          api: api,
          onEntry: onEntry,
          onStatus: onStatus,
        );
        receivers.add(receiver);
        return receiver;
      },
    );
  });
  tearDown(() {
    controller.dispose();
    for (final api in apis) {
      api.client.close();
    }
  });
  test(
    'Lost moderation permission rejects new events but preserves accepted local records',
    () async {
      var allowed = true;
      final context = api('10', '20', allowed: () => allowed);
      await controller.start(context);
      failWrite = true;
      receivers.last.emit('accepted-before-loss');
      await controller.flush();
      expect(controller.unsavedCount, 1);
      allowed = false;
      receivers.last.emit('rejected-after-loss');
      await controller.flush();
      expect(controller.entries.single.id, 'accepted-before-loss');
      expect(controller.unsavedCount, 1);
      failWrite = false;
      await controller.retrySaving();
      expect(controller.unsavedCount, 0);
      expect(controller.saving, false);
      expect(
        (await archive.load('10', '20')).single.id,
        'accepted-before-loss',
      );
      await controller.start(context);
      expect(receivers, hasLength(1));
      expect(controller.ownerId, isNull);
      expect(controller.entries, isEmpty);
      expect(controller.status, contains('變更'));
      allowed = true;
      await controller.start(context);
      expect(receivers, hasLength(2));
      expect(controller.entries.single.id, 'accepted-before-loss');
    },
  );
  for (final retryFails in [false, true]) {
    test(
      'Saving retry rejects repeated activation and releases busy after failure=$retryFails',
      () async {
        await controller.start(api('10', '20'));
        failWrite = true;
        receivers.last.emit('pending');
        await controller.flush();
        expect(controller.unsavedCount, 1);
        writeAttempts = 0;
        writeGate = Completer<void>();
        failWrite = retryFails;
        final saving = controller.retrySaving();
        expect(controller.saving, true);
        await controller.retrySaving();
        writeGate!.complete();
        await saving;
        expect(writeAttempts, 1);
        expect(controller.saving, false);
        expect(controller.unsavedCount, retryFails ? 1 : 0);
        if (retryFails) {
          expect(controller.storageError, isNotNull);
          failWrite = false;
          await controller.retrySaving();
          expect(controller.unsavedCount, 0);
          expect(controller.saving, false);
        }
        expect((await archive.load('10', '20')).single.id, 'pending');
      },
    );
  }
  test(
    'Old saving completion after switching cannot change new owner state',
    () async {
      await controller.start(api('10', '20'));
      failWrite = true;
      receivers.last.emit('old-pending');
      await controller.flush();
      failWrite = false;
      writeGate = Completer<void>();
      final retry = controller.retrySaving();
      expect(controller.saving, true);
      final switching = controller.start(api('11', '21'));
      expect(controller.saving, false);
      writeGate!.complete();
      await Future.wait([retry, switching]);
      expect(controller.ownerId, '11');
      expect(controller.broadcasterId, '21');
      expect(controller.entries, isEmpty);
      expect(controller.saving, false);
      expect(controller.storageError, isNull);
      expect((await archive.load('10', '20')).single.id, 'old-pending');
    },
  );
  test(
    'Received events persist and reconnect loads them without duplicates',
    () async {
      final context = api('10', '20');
      await controller.start(context);
      receivers.last.emit('a');
      receivers.last.emit('a');
      await controller.flush();
      expect(controller.entries, hasLength(1));
      expect(controller.unsavedCount, 0);
      await controller.start(context);
      expect(controller.entries.single.id, 'a');
      receivers.last.emit('a');
      await controller.flush();
      expect(await archive.load('10', '20'), hasLength(1));
    },
  );
  test(
    'Switch hides old data immediately and rejects stale callbacks',
    () async {
      await controller.start(api('10', '20'));
      final old = receivers.last;
      old.emit('old');
      await controller.flush();
      final next = api('11', '21')..gate = Completer<void>();
      final loading = controller.start(next);
      expect(controller.entries, isEmpty);
      old.emit('late');
      old.onStatus('stale status');
      next.gate!.complete();
      await loading;
      expect(old.stopped, true);
      expect(controller.ownerId, '11');
      expect(controller.entries, isEmpty);
      expect(controller.status, 'fake connected');
      expect((await archive.load('10', '20')).single.id, 'old');
    },
  );
  test(
    'Late validation cannot install a receiver after stop or dispose',
    () async {
      final context = api('10', '20')..gate = Completer<void>();
      final loading = controller.start(context);
      controller.stop();
      context.gate!.complete();
      await loading;
      expect(receivers, isEmpty);
      expect(controller.ownerId, isNull);
      final other = api('11', '20')..gate = Completer<void>();
      final pending = controller.start(other);
      controller.dispose();
      other.gate!.complete();
      await pending;
      expect(receivers, isEmpty);
    },
  );
  test('Invalid owner and corrupt archive never open receiver', () async {
    final wrong = api('10', '20')..validatedOwner = '11';
    await controller.start(wrong);
    expect(receivers, isEmpty);
    expect(controller.status, contains('身分不符'));
    disk['vioclass_twitch_mod_log_v1_10_20'] = 'corrupt';
    await controller.start(api('10', '20'));
    expect(receivers, isEmpty);
    expect(controller.storageError, isNotNull);
    expect(disk.values.single, 'corrupt');
  });
  test('Write failure stays visible and explicit retry saves once', () async {
    await controller.start(api('10', '20'));
    failWrite = true;
    receivers.last.emit('unsaved');
    await controller.flush();
    expect(controller.entries.single.id, 'unsaved');
    expect(controller.unsavedCount, 1);
    expect(controller.storageError, isNotNull);
    failWrite = false;
    await controller.retrySaving();
    expect(controller.unsavedCount, 0);
    expect(controller.storageError, isNull);
    expect((await archive.load('10', '20')).single.id, 'unsaved');
  });
  test(
    'Failed records survive switch but only original partition can retry',
    () async {
      await controller.start(api('10', '20'));
      failWrite = true;
      receivers.last.emit('old');
      await controller.flush();
      await controller.start(api('11', '21'));
      expect(controller.entries, isEmpty);
      expect(controller.unsavedCount, 0);
      failWrite = false;
      await controller.retrySaving();
      expect(await archive.load('10', '20'), isEmpty);
      await controller.start(api('10', '20'));
      expect(controller.entries.single.id, 'old');
      expect(controller.unsavedCount, 1);
      expect(controller.storageError, isNotNull);
      await controller.retrySaving();
      expect((await archive.load('10', '20')).single.id, 'old');
      expect(await archive.load('11', '21'), isEmpty);
    },
  );
  test(
    'Failure completing after switch remains recoverable in old partition',
    () async {
      await controller.start(api('10', '20'));
      failWrite = true;
      writeGate = Completer<void>();
      receivers.last.emit('late-failure');
      await Future<void>.delayed(Duration.zero);
      final next = controller.start(api('11', '21'));
      writeGate!.complete();
      await controller.flush();
      await next;
      expect(controller.entries, isEmpty);
      expect(controller.storageError, isNull);
      await controller.start(api('10', '20'));
      expect(controller.entries.single.id, 'late-failure');
      failWrite = false;
      await controller.retrySaving();
      expect(controller.unsavedCount, 0);
    },
  );
  test(
    'Global pending bound stops receipt without replacing old pending data',
    () async {
      final factory = controller.createReceiver;
      controller.dispose();
      archive = TwitchModerationLogArchiveStore(
        maxEntries: 2,
        read: (key) async => disk[key],
        write: (key, value) async {
          if (failWrite) throw StateError('fake failure');
          disk[key] = value;
        },
      );
      controller = TwitchModerationLogController(
        archive: archive,
        receiverFactory: factory,
      );
      failWrite = true;
      await controller.start(api('10', '20'));
      receivers.last.emit('one');
      receivers.last.emit('two');
      await controller.flush();
      await controller.start(api('11', '21'));
      receivers.last.emit('excess');
      expect(receivers.last.stopped, true);
      expect(controller.status, contains('上限'));
      expect(controller.entries, isEmpty);
      await controller.start(api('10', '20'));
      expect(controller.entries.map((entry) => entry.id), ['one', 'two']);
      failWrite = false;
      await controller.retrySaving();
      expect(await archive.load('10', '20'), hasLength(2));
      expect(await archive.load('11', '21'), isEmpty);
    },
  );
  test(
    'Accepted write finishes only in original partition after switch',
    () async {
      await controller.start(api('10', '20'));
      writeGate = Completer<void>();
      receivers.last.emit('old');
      await Future<void>.delayed(Duration.zero);
      final next = controller.start(api('11', '21'));
      expect(controller.entries, isEmpty);
      writeGate!.complete();
      await controller.flush();
      await next;
      expect(controller.ownerId, '11');
      expect(controller.entries, isEmpty);
      expect((await archive.load('10', '20')).single.id, 'old');
      expect(await archive.load('11', '21'), isEmpty);
    },
  );
}
