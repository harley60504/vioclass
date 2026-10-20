// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/api/core/twitch_api_exception.dart';
import '../lib/features/twitch/models/discovery/twitch_live_stream.dart';
import '../lib/features/twitch/presentation/pages/twitch_browse_page.dart';
import '../lib/features/twitch/presentation/widgets/shared/twitch_login_required_view.dart';
import '../lib/features/twitch/services/discovery/twitch_discovery_service.dart';

TwitchLiveStream _stream(String id) => TwitchLiveStream.fromHelixJson({
  'id': id,
  'user_id': id,
  'user_login': id,
  'user_name': 'Fixture $id',
  'title': 'Fixture title $id',
  'language': 'zh',
});

TwitchStreamPageResult _page(String prefix, {int count = 2, String? cursor}) =>
    TwitchStreamPageResult(
      streams: List.generate(count, (i) => _stream('$prefix$i')),
      cursor: cursor,
    );

class _Discovery implements TwitchDiscoveryService {
  final requests = <Map<String, String?>>[];
  Future<TwitchStreamPageResult> Function(String? after) fetch;
  _Discovery(this.fetch);
  final gameRequests = <String?>[];
  Future<TwitchGamePageResult> Function(String? after)? games;

  @override
  Future<TwitchStreamPageResult> fetchBrowseStreams({
    String? after,
    String? gameId,
    String? language,
    int first = 100,
  }) {
    requests.add({'after': after, 'game': gameId, 'language': language});
    expect(first, 100);
    return fetch(after);
  }

  @override
  Future<TwitchGamePageResult> fetchTopGames({
    String? after,
    int first = 20,
  }) async {
    gameRequests.add(after);
    return games == null
        ? const TwitchGamePageResult(games: [], cursor: null)
        : await games!(after);
  }

  @override
  Future<Map<String, String>> fetchProfileImagesForLogins(
    Iterable<String> logins,
  ) async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected fixture API: ${invocation.memberName}');
}

Future<TwitchBrowsePageState> _mount(
  WidgetTester tester,
  _Discovery api, {
  double width = 1000,
  String search = '',
  String? searchError,
  Future<void> Function()? login,
  GlobalKey<TwitchBrowsePageState>? pageKey,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        appBar: pageKey == null
            ? null
            : AppBar(
                actions: [
                  TextButton(
                    onPressed: () => pageKey.currentState!.showLanguageMenu(
                      pageKey.currentContext!,
                    ),
                    child: const Text('Test language'),
                  ),
                  TextButton(
                    onPressed: () => pageKey.currentState!.showGameMenu(
                      pageKey.currentContext!,
                    ),
                    child: const Text('Test game'),
                  ),
                ],
              ),
        body: TwitchBrowsePage(
          key: pageKey ?? const ValueKey('browse-fixture'),
          discoveryService: api,
          searchText: search,
          searchedLiveStreams: const [],
          searchedOfflineChannels: const [],
          loadingChannelSearch: false,
          channelSearchError: searchError,
          reloadTick: 0,
          onLoginPressed: login ?? () async {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return tester.state<TwitchBrowsePageState>(find.byType(TwitchBrowsePage));
}

void main() {
  testWidgets('Filter game initial failure retry reloads the first page', (
    tester,
  ) async {
    var fail = true;
    final api = _Discovery((_) async => _page('public'))
      ..games = (_) async {
        if (fail) {
          throw const TwitchApiException(
            'fixture initial games',
            statusCode: 503,
          );
        }
        return const TwitchGamePageResult(
          games: [
            TwitchGameCategory(
              id: 'recovered',
              name: 'Recovered game',
              boxArtUrl: '',
            ),
          ],
          cursor: null,
        );
      };
    final key = GlobalKey<TwitchBrowsePageState>();
    final state = await _mount(tester, api, pageKey: key);
    await tester.tap(find.text('Test game'));
    await tester.pumpAndSettle();
    expect(find.text('載入分類失敗，重試'), findsOneWidget);
    final beforeRetry = api.gameRequests.length;
    fail = false;
    await tester.tap(find.text('載入分類失敗，重試'));
    await tester.pumpAndSettle();
    expect(api.gameRequests.length, beforeRetry + 1);
    expect(state.games.map((g) => g.id), ['recovered']);
    expect(find.text('Recovered game'), findsOneWidget);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Filter game scroll pagination retries and deduplicates IDs', (
    tester,
  ) async {
    var fail = true;
    final initial = List.generate(
      30,
      (i) => TwitchGameCategory(
        id: 'game-$i',
        name: 'Fixture game $i',
        boxArtUrl: '',
      ),
    );
    final api = _Discovery((_) async => _page('public'))
      ..games = (after) async {
        if (after == null) {
          return TwitchGamePageResult(games: initial, cursor: 'next-games');
        }
        if (fail) {
          throw const TwitchApiException('fixture next games', statusCode: 503);
        }
        return TwitchGamePageResult(
          games: [
            initial.first,
            const TwitchGameCategory(
              id: 'tail-game',
              name: 'Tail game',
              boxArtUrl: '',
            ),
          ],
          cursor: null,
        );
      };
    final key = GlobalKey<TwitchBrowsePageState>();
    final state = await _mount(tester, api, pageKey: key);
    await tester.tap(find.text('Test game'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(GridView), const Offset(0, -30000));
    await tester.pumpAndSettle();
    expect(find.text('載入分類失敗，重試'), findsOneWidget);
    expect(state.games, hasLength(30));
    fail = false;
    await tester.tap(find.text('載入分類失敗，重試'));
    await tester.pumpAndSettle();
    expect(state.games, hasLength(31));
    expect(state.games.map((g) => g.id).toSet(), hasLength(31));
    expect(state.hasMoreGames, false);
    expect(state.gamePaginationError, isNull);
    expect(api.gameRequests, [null, 'next-games', 'next-games']);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [1000.0, 390.0]) {
    testWidgets(
      'Filter language sheet selects, closes, and clears width=$width',
      (tester) async {
        final api = _Discovery((_) async => _page('public'));
        final key = GlobalKey<TwitchBrowsePageState>();
        final state = await _mount(tester, api, width: width, pageKey: key);
        await tester.tap(find.text('Test language'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'zh');
        await tester.pump();
        expect(find.text('中文 Chinese'), findsOneWidget);
        expect(find.text('English'), findsNothing);
        await tester.tap(find.text('中文 Chinese'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        expect(state.currentLanguage, 'zh');
        expect(api.requests.last['language'], 'zh');
        final beforeCancel = api.requests.length;
        await tester.tap(find.text('Test language'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('關閉'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        expect(state.currentLanguage, 'zh');
        expect(api.requests.length, beforeCancel);
        await tester.tap(find.text('Test language'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, '全部語言'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        expect(state.currentLanguage, '');
        expect(api.requests.last['language'], '');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 300));
      },
    );

    testWidgets(
      'Filter game sheet searches, selects, and clears width=$width',
      (tester) async {
        final api = _Discovery((_) async => _page('public'))
          ..games = (_) async => const TwitchGamePageResult(
            games: [
              TwitchGameCategory(
                id: 'g-a',
                name: 'Fixture Game A',
                boxArtUrl: '',
              ),
              TwitchGameCategory(
                id: 'g-b',
                name: 'Fixture Game B',
                boxArtUrl: '',
              ),
            ],
            cursor: null,
          );
        final key = GlobalKey<TwitchBrowsePageState>();
        final state = await _mount(tester, api, width: width, pageKey: key);
        await tester.tap(find.text('Test game'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Game A');
        await tester.pump();
        expect(find.text('Fixture Game A'), findsOneWidget);
        expect(find.text('Fixture Game B'), findsNothing);
        await tester.tap(find.text('Fixture Game A'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        expect(state.selectedGameId, 'g-a');
        expect(api.requests.last['game'], 'g-a');
        await tester.tap(find.text('Test game'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, '全部分類'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        expect(state.selectedGameId, isNull);
        expect(api.requests.last['game'], isNull);
        expect(api.gameRequests, [null]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  }

  testWidgets(
    'Scroll near the tail requests next page and visible retry works',
    (tester) async {
      var fail = true;
      final api = _Discovery((after) async {
        if (after == null) return _page('initial', count: 100, cursor: 'next');
        if (fail) {
          throw const TwitchApiException('fixture pagination', statusCode: 503);
        }
        return _page('tail', count: 1);
      });
      final state = await _mount(tester, api);
      final scroll = find.byType(CustomScrollView).first;
      await tester.drag(scroll, const Offset(0, -50000));
      await tester.pumpAndSettle();
      expect(state.paginationError, isNotNull);
      expect(state.loadedStreams, hasLength(100));
      expect(find.text('載入更多失敗，重試'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('載入更多失敗，重試'));
      await tester.pumpAndSettle();
      expect(state.loadedStreams, hasLength(101));
      expect(state.paginationError, isNull);
      expect(state.hasMore, false);
      expect(api.requests.map((r) => r['after']), [null, 'next', 'next']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final width in [1000.0, 390.0]) {
    testWidgets('Public browse renders without authentication width=$width', (
      tester,
    ) async {
      var logins = 0;
      final api = _Discovery((_) async => _page('public'));
      await _mount(tester, api, width: width, login: () async => logins++);
      expect(find.text('Fixture title public0'), findsOneWidget);
      expect(find.byType(TwitchLoginRequiredView), findsNothing);
      expect(logins, 0);
      expect(api.requests, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final status in [401, 503]) {
    testWidgets('Public failure $status retries without an account login', (
      tester,
    ) async {
      var fail = true;
      var logins = 0;
      final api = _Discovery((_) async {
        if (fail) {
          throw TwitchApiException(
            'fixture public failure',
            statusCode: status,
          );
        }
        return _page('recovered');
      });
      await _mount(tester, api, login: () async => logins++);
      expect(find.text('探索直播讀取失敗'), findsOneWidget);
      expect(find.byType(TwitchLoginRequiredView), findsNothing);
      fail = false;
      await tester.tap(find.text('重新整理'));
      await tester.pump();
      expect(find.text('Fixture title recovered0'), findsOneWidget);
      expect(api.requests, hasLength(2));
      expect(logins, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final searchError in [null, 'fixture search failed']) {
    testWidgets(
      'Loaded browse distinguishes empty search from error=$searchError',
      (tester) async {
        final api = _Discovery((_) async => _page('public'));
        await _mount(tester, api, search: 'no-match', searchError: searchError);
        expect(find.text('找不到符合條件的頻道'), findsOneWidget);
        expect(find.text('Fixture title public0'), findsNothing);
        expect(
          find.text('已載入的直播沒有結果，Twitch 頻道搜尋暫時失敗。'),
          searchError == null ? findsNothing : findsOneWidget,
        );
        expect(find.byType(TwitchLoginRequiredView), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final fail in [false, true]) {
    testWidgets(
      'Browse ignores an initial response after leaving: error=$fail',
      (tester) async {
        final pending = Completer<TwitchStreamPageResult>();
        final api = _Discovery((_) => pending.future);
        await _mount(tester, api);
        await tester.pumpWidget(const SizedBox());
        if (fail) {
          pending.completeError(StateError('fixture late failure'));
        } else {
          pending.complete(_page('late'));
        }
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final fail in [false, true]) {
    testWidgets('New refresh ignores old initial completion: error=$fail', (
      tester,
    ) async {
      final old = Completer<TwitchStreamPageResult>();
      var first = true;
      final api = _Discovery((_) {
        if (first) {
          first = false;
          return old.future;
        }
        return Future.value(_page('fresh'));
      });
      final state = await _mount(tester, api);
      await state.refreshStreams(clearExisting: true);
      if (fail) {
        old.completeError(StateError('fixture old failure'));
      } else {
        old.complete(_page('old'));
      }
      await tester.pump();
      expect(state.loadedStreams.map((s) => s.id), ['fresh0', 'fresh1']);
      expect(state.errorText, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Replacing discovery source reloads the retained browse page', (
    tester,
  ) async {
    final old = _Discovery((_) async => _page('old'));
    await _mount(tester, old);
    final fresh = _Discovery((_) async => _page('fresh'));
    final state = await _mount(tester, fresh);
    expect(fresh.requests, hasLength(1));
    expect(state.loadedStreams.map((s) => s.id), ['fresh0', 'fresh1']);
    expect(find.text('Fixture title old0'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Browse pagination deduplicates IDs and reaches exhaustion', (
    tester,
  ) async {
    final api = _Discovery(
      (after) async => after == null
          ? _page('initial', count: 100, cursor: 'next')
          : TwitchStreamPageResult(
              streams: [_stream('initial0'), _stream('tail')],
              cursor: null,
            ),
    );
    final state = await _mount(tester, api);
    await state.loadMore();
    await tester.pump();
    expect(state.loadedStreams, hasLength(101));
    expect(state.loadedStreams.map((s) => s.id).toSet(), hasLength(101));
    expect(state.hasMore, false);
    expect(state.nextCursor, isNull);
    expect(api.requests.map((r) => r['after']), [null, 'next']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final fail in [false, true]) {
    testWidgets('Refresh rejects a late old pagination response: error=$fail', (
      tester,
    ) async {
      final oldPage = Completer<TwitchStreamPageResult>();
      final api = _Discovery(
        (after) => after == null
            ? Future.value(_page('initial', count: 100, cursor: 'next'))
            : oldPage.future,
      );
      final state = await _mount(tester, api);
      final pagination = state.loadMore();
      api.fetch = (_) async => _page('fresh');
      await state.refreshStreams(clearExisting: true);
      if (fail) {
        oldPage.completeError(
          const TwitchApiException(
            'fixture old pagination failure',
            statusCode: 503,
          ),
        );
      } else {
        oldPage.complete(_page('stale'));
      }
      await pagination;
      await tester.pump();
      expect(state.loadedStreams.map((s) => s.id), ['fresh0', 'fresh1']);
      expect(state.paginationError, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
