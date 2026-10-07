// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import '../lib/features/twitch/models/emotes/twitch_cheermote_catalog.dart';
import '../lib/features/twitch/models/chat/twitch_automod_queue.dart';
import '../lib/features/twitch/presentation/widgets/chat/twitch_automod_message_text.dart';

const _light =
    'https://d3aqoihi2n8ty8.cloudfront.net/actions/cheer/light/animated/100/2.gif';
const _dark =
    'https://d3aqoihi2n8ty8.cloudfront.net/actions/cheer/dark/static/100/2.png';
List<dynamic> _rows() => [
  {
    'prefix': 'Cheer',
    'tiers': [
      {
        'id': '100',
        'min_bits': 100,
        'images': {
          'light': {
            'animated': {'2': _light},
          },
          'dark': {
            'static': {'2': _dark},
          },
        },
      },
    ],
  },
];

class _Adapter implements HttpClientAdapter {
  String owner = '10';
  int status = 200;
  bool malformed = false;
  void Function()? afterRead;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final validation = options.uri.path.endsWith('/validate');
    if (!validation) {
      requests.add(options);
      afterRead?.call();
    }
    return ResponseBody.fromString(
      jsonEncode(
        validation
            ? {
                'user_id': owner,
                'client_id': 'validated-client',
                'login': 'mod',
                'expires_in': 1000,
                'scopes': [],
              }
            : {'data': malformed ? 'invalid' : _rows()},
      ),
      validation ? 200 : status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'fallback list uses only the current theme and removes duplicate URLs',
    () {
      final rows = _rows();
      final images =
          ((rows.single as Map)['tiers'] as List).single['images'] as Map;
      images['light']['static'] = {'2': _dark};
      final catalog = TwitchCheermoteCatalog.parse(rows);
      expect(catalog.imageUrls('cheer', 100, 100, dark: false), [
        _light,
        _dark,
      ]);
      expect(catalog.imageUrls('cheer', 100, 100, dark: true), [_dark]);
      images['light']['static'] = {'2': _light};
      expect(
        TwitchCheermoteCatalog.parse(
          rows,
        ).imageUrls('cheer', 100, 100, dark: false),
        [_light],
      );
    },
  );

  for (final staticFails in [false, true]) {
    testWidgets(
      staticFails
          ? 'failed animated and static Bits images preserve text and copy'
          : 'animated image failure falls back to loaded static while selection stays correct',
      (tester) async {
        final rows = _rows();
        final images =
            ((rows.single as Map)['tiers'] as List).single['images'] as Map;
        images['light']['static'] = {'2': _dark};
        final animated = Completer<ImageInfo>();
        final still = Completer<ImageInfo>();
        const animatedProvider = NetworkImage(_light);
        const staticProvider = NetworkImage(_dark);
        PaintingBinding.instance.imageCache.putIfAbsent(
          animatedProvider,
          () => OneFrameImageStreamCompleter(animated.future),
        );
        PaintingBinding.instance.imageCache.putIfAbsent(
          staticProvider,
          () => OneFrameImageStreamCompleter(still.future),
        );
        addTearDown(() {
          PaintingBinding.instance.imageCache.evict(animatedProvider);
          PaintingBinding.instance.imageCache.evict(staticProvider);
        });
        String? copied;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        final message = TwitchHeldAutomodMessage(
          id: 'held',
          userId: '30',
          userName: 'Chatter',
          text: 'before Cheer100 after',
          reason: 'AutoMod',
          heldAt: DateTime.utc(2026),
          boundaries: const [(7, 14)],
          fragments: const [
            TwitchAutomodFragment('before '),
            TwitchAutomodFragment(
              'Cheer100',
              bits: 100,
              cheerPrefix: 'cheer',
              cheerTier: 100,
            ),
            TwitchAutomodFragment(' after'),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: TwitchAutomodMessageText(
                    message: message,
                    cheermotes: TwitchCheermoteCatalog.parse(rows),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final region = tester.state<SelectableRegionState>(
          find.byType(SelectableRegion),
        );
        region.selectAll();
        await tester.pump();
        expect(
          region.contextMenuButtonItems.any(
            (item) => item.type == ContextMenuButtonType.copy,
          ),
          true,
          reason: 'Selection must exist before either image completes',
        );
        animated.completeError(StateError('fixture animation failure'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<Image>(find.byType(Image))
              .any((image) => image.image == staticProvider),
          true,
        );
        if (staticFails) {
          still.completeError(StateError('fixture static failure'));
        } else {
          final recorder = ui.PictureRecorder();
          ui.Canvas(recorder).drawRect(
            const ui.Rect.fromLTWH(0, 0, 28, 28),
            ui.Paint()..color = const ui.Color(0xff663399),
          );
          final picture = recorder.endRecording();
          final bitmap = (await tester.runAsync(
            () => picture.toImage(28, 28),
          ))!;
          picture.dispose();
          still.complete(ImageInfo(image: bitmap));
        }
        await tester.pumpAndSettle();
        if (staticFails) {
          expect(find.text('Cheer100'), findsOneWidget);
        } else {
          expect(
            tester
                .widgetList<RawImage>(find.byType(RawImage))
                .where((image) => image.image != null),
            isNotEmpty,
          );
        }
        expect(
          tester
              .widgetList<DecoratedBox>(find.byType(DecoratedBox))
              .any(
                (box) =>
                    box.decoration is BoxDecoration &&
                    (box.decoration as BoxDecoration).border != null,
              ),
          true,
          reason: 'The held Bits token remains highlighted after fallback',
        );
        region.contextMenuButtonItems
            .singleWhere((item) => item.type == ContextMenuButtonType.copy)
            .onPressed!();
        await tester.pump();
        expect(copied, message.text);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.android,
      }),
    );
  }
  test('prefix exact tier minimum and theme determine official image', () {
    final catalog = TwitchCheermoteCatalog.parse(_rows());
    expect(catalog.image('cheer', 100, 150, dark: false), _light);
    expect(catalog.image('CHEER', 100, 150, dark: true), _dark);
    expect(catalog.image('cheer', 100, 99, dark: true), isNull);
    expect(catalog.image('unknown', 100, 150, dark: true), isNull);
    expect(catalog.image('cheer', 1, 150, dark: true), isNull);
  });
  test('unsafe image URL has no invented fallback', () {
    for (final url in [
      'http://static-cdn.jtvnw.net/a',
      'https://evil.test/a',
      'https://user@static-cdn.jtvnw.net/a',
    ]) {
      final catalog = TwitchCheermoteCatalog.parse([
        {
          'prefix': 'Cheer',
          'tiers': [
            {
              'id': '100',
              'min_bits': 100,
              'images': {
                'dark': {
                  'static': {'2': url},
                },
              },
            },
          ],
        },
      ]);
      expect(catalog.image('cheer', 100, 100, dark: true), isNull);
    }
  });
  test('duplicate prefix tier and malformed tiers are not guessed', () {
    final catalog = TwitchCheermoteCatalog.parse([
      ..._rows(),
      ..._rows(),
      {'prefix': 'future', 'tiers': 'invalid'},
    ]);
    expect(catalog.image('cheer', 100, 100, dark: false), isNull);
    expect(
      const TwitchCheermoteCatalog.empty().image(
        'cheer',
        100,
        100,
        dark: false,
      ),
      isNull,
    );
  });
  test(
    'API uses validated selected owner client and exact broadcaster query without extra scope',
    () async {
      final adapter = _Adapter();
      final client = TwitchApiClient();
      client.dio.httpClientAdapter = adapter;
      addTearDown(client.close);
      final api = TwitchModerationApiService(
        client: client,
        tokenProviders: [() async => 'selected-token'],
        broadcasterId: '20',
        moderatorId: '10',
      );
      final catalog = await api.automodCheermotes();
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.path, '/helix/bits/cheermotes');
      expect(request.queryParameters, {'broadcaster_id': '20'});
      expect(request.headers['Client-ID'], 'validated-client');
      expect(request.headers['Authorization'], 'Bearer selected-token');
      expect(catalog.image('cheer', 100, 100, dark: false), _light);
    },
  );
  test(
    'wrong owner and permission lost after read never return a catalog',
    () async {
      final adapter = _Adapter()..owner = '99';
      final client = TwitchApiClient();
      client.dio.httpClientAdapter = adapter;
      addTearDown(client.close);
      var permitted = true;
      final api = TwitchModerationApiService(
        client: client,
        tokenProviders: [() async => 'token'],
        broadcasterId: '20',
        moderatorId: '10',
        canModerate: () => permitted,
      );
      await expectLater(
        api.automodCheermotes(),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests, isEmpty);
      adapter.owner = '10';
      adapter.afterRead = () => permitted = false;
      await expectLater(
        api.automodCheermotes(),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests.length, 1);
    },
  );
  test(
    'unexpected successful status or malformed data is not an empty successful catalog',
    () async {
      final adapter = _Adapter()..status = 204;
      final client = TwitchApiClient();
      client.dio.httpClientAdapter = adapter;
      addTearDown(client.close);
      final api = TwitchModerationApiService(
        client: client,
        tokenProviders: [() async => 'token'],
        broadcasterId: '20',
        moderatorId: '10',
      );
      await expectLater(
        api.automodCheermotes(),
        throwsA(isA<TwitchModerationException>()),
      );
      adapter.status = 200;
      adapter.malformed = true;
      await expectLater(
        api.automodCheermotes(),
        throwsA(isA<TwitchModerationException>()),
      );
    },
  );
  testWidgets(
    'loaded Bits image copies the original token rather than metadata or placeholder',
    (tester) async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 28, 28),
        ui.Paint()..color = const ui.Color(0xff663399),
      );
      final picture = recorder.endRecording();
      final bitmap = (await tester.runAsync(() => picture.toImage(28, 28)))!;
      picture.dispose();
      const provider = NetworkImage(_light);
      PaintingBinding.instance.imageCache.putIfAbsent(
        provider,
        () => OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: bitmap)),
        ),
      );
      addTearDown(() => PaintingBinding.instance.imageCache.evict(provider));
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
      final message = TwitchHeldAutomodMessage(
        id: 'held',
        userId: '30',
        userName: 'Chatter',
        text: 'Cheer100',
        reason: 'AutoMod',
        heldAt: DateTime.utc(2026),
        fragments: const [
          TwitchAutomodFragment(
            'Cheer100',
            bits: 100,
            cheerPrefix: 'cheer',
            cheerTier: 100,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchAutomodMessageText(
              message: message,
              cheermotes: TwitchCheermoteCatalog.parse(_rows()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll();
      await tester.pump();
      region.contextMenuButtonItems
          .singleWhere((item) => item.type == ContextMenuButtonType.copy)
          .onPressed!();
      await tester.pump();
      expect(copied, 'Cheer100');
      expect(find.text('Cheer100 · 100 Bits'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
