import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/io.dart';
import 'package:vioclass/features/twitch/services/engagement/twitch_prediction_hermes_runtime_service.dart';

// Mirrors the Hermes connection's two asynchronous error surfaces using a
// local failed handshake. No Twitch access, credentials or DNS are required.
void main() {
  test('Disconnect during Hermes cleanup prevents a late connection', () async {
    var dials = 0;
    final service = TwitchPredictionHermesRuntimeService(
      connector: (_) {
        dials++;
        throw StateError('A cancelled connect must not dial');
      },
    );
    final pending = service.connect(channelId: 'fixture', viewerUserId: null);
    await service.disconnect();
    await pending;
    expect(dials, 0);
    expect(service.connected, isFalse);
    expect(service.connecting, isFalse);
  });

  test(
    'Concurrent Hermes connects leave no orphan socket after disposal',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final active = <WebSocket>{};
      final requests = server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        active.add(socket);
        socket.listen((_) {}, onDone: () => active.remove(socket));
      });
      final service = TwitchPredictionHermesRuntimeService(
        connector: (_) =>
            IOWebSocketChannel.connect('ws://127.0.0.1:${server.port}'),
      );
      addTearDown(() async {
        await service.dispose();
        for (final socket in active.toList()) {
          await socket.close();
        }
        await requests.cancel();
        await server.close(force: true);
      });
      await Future.wait([
        service.connect(channelId: 'first', viewerUserId: null),
        service.connect(channelId: 'second', viewerUserId: null),
      ]);
      await service.dispose();
      final deadline = DateTime.now().add(const Duration(seconds: 1));
      while (active.isNotEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(active, isEmpty);
    },
  );

  Future<({int streamErrors, int readyErrors, int uncaughtErrors})> probe(
    bool handleReady,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = server.listen((request) async {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
    });
    var streamErrors = 0;
    var readyErrors = 0;
    var uncaughtErrors = 0;
    final done = Completer<void>();
    runZonedGuarded(
      () async {
        final channel = IOWebSocketChannel.connect(
          'ws://127.0.0.1:${server.port}',
        );
        channel.stream.listen(
          (_) {},
          onError: (Object _) => streamErrors++,
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );
        if (handleReady) {
          try {
            await channel.ready;
          } catch (_) {
            readyErrors++;
          }
        }
      },
      (Object _, StackTrace _) {
        uncaughtErrors++;
      },
    );
    await done.future.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(Duration.zero);
    await requests.cancel();
    await server.close(force: true);
    return (
      streamErrors: streamErrors,
      readyErrors: readyErrors,
      uncaughtErrors: uncaughtErrors,
    );
  }

  test('Hermes stream-only handling leaves ready failure uncaught', () async {
    final result = await probe(false);
    expect(result.streamErrors, 1);
    expect(result.uncaughtErrors, 1);
  });
  test('Awaiting ready handles the second failure surface', () async {
    final result = await probe(true);
    expect(result.streamErrors, 1);
    expect(result.readyErrors, 1);
    expect(result.uncaughtErrors, 0);
  });
  test(
    'Real Hermes service catches a failed handshake and can reconnect',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var accept = false;
      final topics = <String>[];
      final sockets = <WebSocket>[];
      final requests = server.listen((request) async {
        if (!accept) {
          request.response.statusCode = HttpStatus.serviceUnavailable;
          await request.response.close();
          return;
        }
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((data) => topics.add(data as String));
      });
      final service = TwitchPredictionHermesRuntimeService(
        connector: (_) =>
            IOWebSocketChannel.connect('ws://127.0.0.1:${server.port}'),
      );
      addTearDown(() async {
        await service.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await requests.cancel();
        await server.close(force: true);
      });
      await service.connect(channelId: 'fixture', viewerUserId: null);
      expect(service.connected, isFalse);
      expect(topics, isEmpty);
      accept = true;
      await service.connect(channelId: 'fixture', viewerUserId: null);
      expect(service.connected, isTrue);
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (topics.length < 2 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(topics.length, 2);
    },
  );
}
