// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/models/discovery/twitch_live_stream.dart';
import '../lib/features/twitch/presentation/pages/twitch_channel_page.dart';
import '../lib/features/twitch/presentation/pages/twitch_watch_page.dart';
import '../lib/features/twitch/services/discovery/twitch_discovery_service.dart';

const channel = TwitchFollowedChannel(
  broadcasterId: 'fixture-owner',
  broadcasterLogin: 'fixture',
  broadcasterName: 'Fixture channel',
  followedAt: null,
);

class _Discovery implements TwitchDiscoveryService {
  final calls = <String?>[];
  bool fail = false;
  bool overlap = false;
  String label = 'Media item';
  Completer<void>? gate;
  bool growing = false;

  Future<List<int>> _page(String? after) async {
    calls.add(after);
    await gate?.future;
    if (fail) throw StateError('fixture media failure');
    return after == null
        ? [1, 2]
        : overlap
        ? [2, 3]
        : [3];
  }

  @override
  Future<TwitchChannelVideoPageResult> fetchChannelVideos({
    required String userId,
    String? after,
    int first = 20,
    String type = 'archive',
  }) async => TwitchChannelVideoPageResult(
    videos: (await _page(after))
        .map(
          (id) => TwitchChannelVideo.fromHelixJson({
            'id': '$id',
            'user_id': channel.broadcasterId,
            'user_name': channel.displayName,
            'title': '$label $id',
            'duration': '1h',
            'type': 'archive',
            if (growing)
              'created_at': DateTime.now()
                  .toUtc()
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
          }),
        )
        .toList(),
    cursor: after == null ? 'next' : null,
  );

  @override
  Future<TwitchChannelClipPageResult> fetchChannelClips({
    required String broadcasterId,
    String? after,
    int first = 30,
  }) async => TwitchChannelClipPageResult(
    clips: (await _page(after))
        .map(
          (id) => TwitchChannelClip.fromHelixJson({
            'id': '$id',
            'broadcaster_id': channel.broadcasterId,
            'broadcaster_name': channel.displayName,
            'title': '$label $id',
            'duration': 12,
          }),
        )
        .toList(),
    cursor: after == null ? 'next' : null,
  );

  @override
  Future<TwitchChannelAboutResult> fetchChannelAbout({
    required String login,
  }) async => const TwitchChannelAboutResult(panels: [], socialLinks: []);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected fixture API: ${invocation.memberName}');
}

class _MediaRouteProbe extends NavigatorObserver {
  MaterialPageRoute<void>? target;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) return;
    target = route as MaterialPageRoute<void>;
    // Inspect the actual card destination without initializing native playback.
    scheduleMicrotask(() => navigator!.removeRoute(route));
  }
}

Future<void> open(
  WidgetTester tester,
  TwitchDiscoveryService api,
  bool clip, {
  double width = 1000,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: TwitchChannelPage(
        discoveryService: api,
        channel: channel,
        initialTabIndex: clip ? 1 : 2,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> clickMore(WidgetTester tester) async {
  final scrollable = find
      .descendant(
        of: find.byType(CustomScrollView).first,
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    find.text('載入更多'),
    250,
    scrollable: scrollable,
  );
  await tester.tap(find.text('載入更多'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  for (final kind in ['clip', 'vod', 'growing-vod']) {
    for (final width in [1000.0, 390.0]) {
      testWidgets('Media card destination kind=$kind width=$width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = _Discovery()..growing = kind == 'growing-vod';
        final probe = _MediaRouteProbe();
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [probe],
            home: TwitchChannelPage(
              discoveryService: api,
              channel: channel,
              initialTabIndex: kind == 'clip' ? 1 : 2,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final pageState = tester.state(find.byType(TwitchChannelPage));
        final before = api.calls.length;
        await tester.ensureVisible(find.text('Media item 1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Media item 1').hitTestable());
        await tester.pumpAndSettle();
        expect(probe.target, isNotNull);
        final target =
            probe.target!.builder(
                  tester.element(find.byType(TwitchChannelPage)),
                )
                as TwitchWatchPage;
        expect(target.initialDiscoveryService, same(api));
        expect(target.initialOfflineChannel, same(channel));
        expect(target.initialMetadata.channelLogin, channel.channelLogin);
        expect(target.initialMetadata.streamTitle, 'Media item 1');
        expect(target.initialClip?.id, kind == 'clip' ? '1' : null);
        expect(target.initialVodVideo?.id, kind == 'vod' ? '1' : null);
        expect(
          target.initialActiveDvrVideo?.id,
          kind == 'growing-vod' ? '1' : null,
        );
        expect(target.initialVodPlaybackOnly, kind == 'vod');
        expect(find.byType(TwitchWatchPage), findsNothing);
        expect(tester.state(find.byType(TwitchChannelPage)), same(pageState));
        expect(api.calls.length, before);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  for (final clip in [false, true]) {
    final kind = clip ? 'clip' : 'VOD';
    for (final fails in [false, true]) {
      testWidgets(
        '$kind old pending source cannot overwrite replacement fails=$fails',
        (tester) async {
          final gate = Completer<void>();
          final old = _Discovery()
            ..gate = gate
            ..fail = fails
            ..label = 'Old media';
          await open(tester, old, clip);
          expect(old.calls, [null]);
          final fresh = _Discovery()..label = 'Fresh media';
          await open(tester, fresh, clip);
          expect(find.text('Fresh media 1'), findsOneWidget);
          gate.complete();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Fresh media 1'), findsOneWidget);
          expect(find.text('Old media 1'), findsNothing);
          expect(find.text(clip ? '片段讀取失敗' : 'VOD 讀取失敗'), findsNothing);
          expect(fresh.calls, [null]);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
    testWidgets('$kind replaces retained media when discovery source changes', (
      tester,
    ) async {
      final old = _Discovery();
      await open(tester, old, clip);
      final fresh = _Discovery()..label = 'Fresh media';
      await open(tester, fresh, clip);
      expect(fresh.calls, [null]);
      expect(find.text('Fresh media 1'), findsOneWidget);
      expect(find.text('Media item 1'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
    for (final width in [1000.0, 390.0]) {
      testWidgets(
        '$kind page search and clear retain loaded media width=$width',
        (tester) async {
          final api = _Discovery();
          await open(tester, api, clip, width: width);
          expect(find.text('Media item 1'), findsOneWidget);
          await tester.enterText(find.byType(TextField).first, 'item 2');
          await tester.pump();
          expect(find.text('Media item 1'), findsNothing);
          expect(find.text('Media item 2'), findsOneWidget);
          await tester.enterText(find.byType(TextField).first, 'not-found');
          await tester.pump();
          expect(find.text(clip ? '找不到符合的片段' : '找不到符合的 VOD'), findsOneWidget);
          await tester.tap(find.text('清空搜尋'));
          await tester.pump();
          expect(find.text('Media item 1'), findsOneWidget);
          expect(api.calls, [null]);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets('$kind first-page error retries through the visible action', (
      tester,
    ) async {
      final api = _Discovery()..fail = true;
      await open(tester, api, clip);
      expect(find.text(clip ? '片段讀取失敗' : 'VOD 讀取失敗'), findsOneWidget);
      expect(find.textContaining('fixture media failure'), findsNothing);
      api.fail = false;
      await tester.tap(find.text('重試'));
      await tester.pump();
      expect(find.text('Media item 1'), findsOneWidget);
      expect(api.calls, [null, null]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$kind pagination retry preserves prefix and exhausts cursor', (
      tester,
    ) async {
      final api = _Discovery();
      await open(tester, api, clip);
      api.fail = true;
      await clickMore(tester);
      expect(find.text('Media item 1'), findsOneWidget);
      api.fail = false;
      await clickMore(tester);
      expect(api.calls, [null, 'next', 'next']);
      expect(find.text('Media item 1'), findsOneWidget);
      expect(find.text('Media item 3'), findsOneWidget);
      expect(find.text('載入更多'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$kind overlapping page never renders duplicate media IDs', (
      tester,
    ) async {
      final api = _Discovery()..overlap = true;
      await open(tester, api, clip);
      await clickMore(tester);
      expect(find.text('Media item 2'), findsOneWidget);
      expect(find.text('Media item 3'), findsOneWidget);
      expect(api.calls, [null, 'next']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$kind pending load-more disables duplicate submissions', (
      tester,
    ) async {
      final api = _Discovery();
      await open(tester, api, clip);
      api.gate = Completer<void>();
      await clickMore(tester);
      final button = find.widgetWithText(FilledButton, '載入中');
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(button);
      await tester.pump();
      expect(api.calls, [null, 'next']);
      api.gate!.complete();
      await tester.pump();
      expect(find.text('Media item 3'), findsOneWidget);
      expect(find.text('載入中'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    for (final fail in [false, true]) {
      testWidgets('$kind ignores completion after leaving page: error=$fail', (
        tester,
      ) async {
        final api = _Discovery()
          ..gate = Completer<void>()
          ..fail = fail;
        await open(tester, api, clip);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        api.gate!.complete();
        await tester.pump();
        expect(api.calls, [null]);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Switching media tabs preserves each search without reloading', (
    tester,
  ) async {
    final api = _Discovery();
    await open(tester, api, false);
    await tester.enterText(find.byType(TextField).first, 'item 2');
    await tester.pump();
    await tester.tap(find.text('片段'));
    await tester.pumpAndSettle();
    expect(api.calls, [null, null]);
    expect(find.text('Media item 1'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'item 1');
    await tester.pump();
    await tester.tap(find.text('VOD'));
    await tester.pumpAndSettle();
    expect(find.text('Media item 1'), findsNothing);
    expect(find.text('Media item 2'), findsOneWidget);
    await tester.tap(find.text('片段'));
    await tester.pumpAndSettle();
    expect(find.text('Media item 1'), findsOneWidget);
    expect(find.text('Media item 2'), findsNothing);
    expect(api.calls, [null, null]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [
    const Size(1000, 900),
    const Size(390, 844),
    const Size(844, 260),
  ]) {
    testWidgets('Media sheet opens and closes within viewport $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _Discovery();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTwitchChannelSheet(
                  context: context,
                  discoveryService: api,
                  channel: channel,
                  initialTabIndex: 2,
                ),
                child: const Text('Open media'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open media'));
      await tester.pumpAndSettle();
      expect(find.byType(TwitchChannelPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byType(TwitchChannelPage));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      await tester.tap(find.byTooltip('關閉'));
      await tester.pumpAndSettle();
      expect(find.byType(TwitchChannelPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
