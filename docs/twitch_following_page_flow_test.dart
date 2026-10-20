// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/features/twitch/models/discovery/twitch_live_stream.dart';
import '../lib/features/twitch/presentation/pages/twitch_following_page.dart';
import '../lib/features/twitch/presentation/widgets/shared/twitch_login_required_view.dart';
import '../lib/features/twitch/presentation/widgets/discovery/twitch_discovery_stream_template.dart';
import '../lib/features/twitch/services/discovery/twitch_discovery_service.dart';
import '../lib/features/twitch/services/auth/twitch_viewer_session.dart';

class _ViewerSession extends ChangeNotifier implements TwitchViewerSession {
  bool get listening => hasListeners;
  @override
  int get identityRevision => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Discovery implements TwitchDiscoveryService {
  @override
  final _ViewerSession viewerSession = _ViewerSession();
  @override
  TwitchViewerAuthSnapshot get cachedAuth => _identity;
  static const _identity = TwitchViewerAuthSnapshot(
    accessToken: 'fixture-only',
    clientId: 'fixture-client',
    viewerId: 'fixture-viewer',
    viewerLogin: 'fixture-viewer',
    scopes: ['user:read:follows'],
  );

  Future<TwitchStreamPageResult> Function(String? after) fetch;
  Future<TwitchFollowedChannelPageResult> Function()? offline;
  Future<TwitchFollowedChannelPageResult> Function(String? after)? offlinePages;
  final offlineCalls = <String?>[];
  Future<Map<String, String>> Function()? profiles;
  final calls = <String?>[];
  _Discovery(this.fetch);

  @override
  Future<TwitchStreamPageResult> fetchFollowedStreams({
    String? after,
    int first = 100,
  }) {
    calls.add(after);
    expect(first, 100);
    return fetch(after);
  }

  @override
  Future<TwitchFollowedChannelPageResult> fetchFollowedChannels({
    String? after,
    int first = 100,
    bool attachProfiles = true,
  }) async {
    offlineCalls.add(after);
    if (offlinePages != null) return offlinePages!(after);
    return offline != null
        ? await offline!()
        : const TwitchFollowedChannelPageResult(channels: [], cursor: null);
  }

  @override
  Future<Map<String, String>> fetchProfileImagesForLogins(
    Iterable<String> logins,
  ) async => profiles != null ? await profiles!() : {};

  @override
  Future<List<TwitchGameCategory>> fetchGamesByIds(
    Iterable<String> ids,
  ) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TwitchLiveStream _stream(
  String id, {
  String language = 'en',
  String game = 'g1',
}) => TwitchLiveStream(
  id: id,
  userId: id,
  userLogin: id,
  userName: id,
  gameId: game,
  gameName: 'Game $game',
  title: 'fixture $id',
  viewerCount: 10,
  startedAt: null,
  language: language,
  thumbnailUrl: '',
  tags: const [],
  isMature: false,
);

List<TwitchLiveStream> _window(String prefix) =>
    List.generate(100, (i) => _stream('$prefix$i'));

Future<TwitchFollowingPageState> _mount(
  WidgetTester tester,
  _Discovery service, {
  String search = '',
  Future<void> Function()? onLogin,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TwitchFollowingPage(
          discoveryService: service,
          searchText: search,
          searchedLiveStreams: const [],
          searchedOfflineChannels: const [],
          loadingChannelSearch: false,
          channelSearchError: null,
          reloadTick: 0,
          onLoginPressed: onLogin ?? () async {},
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return tester.state<TwitchFollowingPageState>(
    find.byType(TwitchFollowingPage),
  );
}

void main() {
  setUp(() {
    // This docs fixture runs exclusively through flutter test.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Following session listener moves with service and detaches', (
    tester,
  ) async {
    final first = _Discovery(
      (_) async => const TwitchStreamPageResult(streams: [], cursor: null),
    );
    final second = _Discovery(
      (_) async => const TwitchStreamPageResult(streams: [], cursor: null),
    );
    expect(first.viewerSession.listening, isFalse);
    expect(second.viewerSession.listening, isFalse);
    final state = await _mount(tester, first);
    expect(first.viewerSession.listening, isTrue);
    expect(await _mount(tester, second), same(state));
    expect(first.viewerSession.listening, isFalse);
    expect(second.viewerSession.listening, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(second.viewerSession.listening, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Following language and game selections filter existing streams',
    (tester) async {
      final service = _Discovery(
        (_) async => TwitchStreamPageResult(
          streams: [
            _stream('one'),
            _stream('two', language: 'zh'),
            _stream('three', game: 'g2'),
          ],
          cursor: null,
        ),
      );
      final state = await _mount(tester, service);
      unawaited(
        state.showLanguageMenu(
          tester.element(find.byType(TwitchFollowingPage)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(state.currentLanguage, 'en');
      List<String> visible() => tester
          .widget<TwitchDiscoveryStreamGrid>(
            find.byType(TwitchDiscoveryStreamGrid),
          )
          .streams
          .map((s) => s.id)
          .toList();
      expect(visible(), ['one', 'three']);
      unawaited(
        state.showGameMenu(tester.element(find.byType(TwitchFollowingPage))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Game g2').last);
      await tester.pumpAndSettle();
      expect(state.selectedGameId, 'g2');
      expect(visible(), ['three']);
      await _mount(tester, service, search: 'missing-fixture');
      expect(find.text('找不到符合條件的頻道'), findsOneWidget);
      expect(service.calls, [null]);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Following initial failure retries through actual page button', (
    tester,
  ) async {
    var attempts = 0;
    final service = _Discovery((_) async {
      if (++attempts == 1) throw StateError('fixture unavailable');
      return TwitchStreamPageResult(
        streams: [_stream('recovered')],
        cursor: null,
      );
    });
    final state = await _mount(tester, service);
    expect(find.text('追隨直播讀取失敗'), findsOneWidget);
    await tester.tap(find.text('重新整理'));
    await tester.pumpAndSettle();
    expect(state.loadedStreams.single.id, 'recovered');
    expect(state.errorText, isNull);
    expect(attempts, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Following pagination preserves prefix and removes duplicate IDs',
    (tester) async {
      final initial = _window('old');
      final service = _Discovery(
        (after) async => after == null
            ? TwitchStreamPageResult(streams: initial, cursor: 'next')
            : TwitchStreamPageResult(
                streams: [initial.first, _stream('new')],
                cursor: null,
              ),
      );
      final state = await _mount(tester, service);
      await state.loadMore();
      await tester.pumpAndSettle();
      expect(state.loadedStreams.map((s) => s.id), [
        ...initial.map((s) => s.id),
        'new',
      ]);
      expect(state.hasMore, isFalse);
      await state.loadMore();
      expect(service.calls, [null, 'next']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final emptyLive in [false, true]) {
    testWidgets(
      'Offline failure preserves live or reports empty state: empty=$emptyLive',
      (tester) async {
        final service = _Discovery(
          (_) async => TwitchStreamPageResult(
            streams: emptyLive ? [] : [_stream('live')],
            cursor: null,
          ),
        );
        service.offline = () async =>
            throw StateError('fixture offline unavailable');
        final state = await _mount(tester, service);
        expect(state.errorText, isNull);
        expect(state.offlineError, isNotNull);
        expect(state.loadingOfflineChannels, isFalse);
        expect(state.loadedStreams.length, emptyLive ? 0 : 1);
        if (emptyLive) {
          expect(find.text('直播清單為空，離線追隨頻道也暫時讀取失敗。'), findsOneWidget);
        } else {
          expect(find.byType(TwitchDiscoveryStreamGrid), findsOneWidget);
        }
        service.offline = () async =>
            const TwitchFollowedChannelPageResult(channels: [], cursor: null);
        await state.refreshStreams();
        await tester.pumpAndSettle();
        expect(state.offlineError, isNull);
        expect(state.errorText, isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Refresh failure retains loaded cards and next refresh recovers',
    (tester) async {
      var count = 0;
      final service = _Discovery((_) async {
        if (++count == 2) throw StateError('fixture refresh unavailable');
        return TwitchStreamPageResult(
          streams: [_stream(count == 1 ? 'old' : 'fresh')],
          cursor: null,
        );
      });
      final state = await _mount(tester, service);
      await state.refreshStreams();
      await tester.pumpAndSettle();
      expect(state.loadedStreams.single.id, 'old');
      expect(state.errorText, isNull);
      expect(state.paginationError, isNotNull);
      await state.refreshStreams();
      await tester.pumpAndSettle();
      expect(state.loadedStreams.single.id, 'fresh');
      expect(state.paginationError, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Pagination failure preserves cursor and retry appends once', (
    tester,
  ) async {
    var attempts = 0;
    final service = _Discovery((after) async {
      if (after == null) {
        return TwitchStreamPageResult(streams: _window('old'), cursor: 'next');
      }
      if (++attempts == 1) throw StateError('fixture page unavailable');
      return TwitchStreamPageResult(streams: [_stream('new')], cursor: null);
    });
    final state = await _mount(tester, service);
    await state.loadMore();
    expect(state.loadedStreams.length, 100);
    expect(state.nextCursor, 'next');
    expect(state.hasMore, isTrue);
    expect(state.loadingMore, isFalse);
    expect(state.paginationError, isNotNull);
    await state.loadMore();
    await tester.pumpAndSettle();
    expect(state.loadedStreams.length, 101);
    expect(state.loadedStreams.last.id, 'new');
    expect(state.paginationError, isNull);
    expect(service.calls, [null, 'next', 'next']);
    await tester.pumpWidget(const SizedBox());
  });

  for (final paginate in [false, true]) {
    for (final fail in [false, true]) {
      testWidgets(
        'Disposed following ignores pending request: page=$paginate error=$fail',
        (tester) async {
          final gate = Completer<TwitchStreamPageResult>();
          final service = _Discovery(
            (_) async =>
                TwitchStreamPageResult(streams: _window('old'), cursor: 'next'),
          );
          final state = await _mount(tester, service);
          service.fetch = (_) => gate.future;
          final pending = paginate ? state.loadMore() : state.refreshStreams();
          await tester.pumpWidget(const SizedBox());
          expect(state.mounted, isFalse);
          if (fail) {
            gate.completeError(StateError('fixture late failure'));
          } else {
            gate.complete(
              TwitchStreamPageResult(streams: [_stream('late')], cursor: null),
            );
          }
          await pending;
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(state.loadedStreams.length, 100);
          expect(state.loadedStreams.first.id, 'old0');
        },
      );
    }
  }

  testWidgets(
    'Profile attachment finishing after refresh cannot append old page',
    (tester) async {
      final service = _Discovery(
        (after) async => TwitchStreamPageResult(
          streams: after == null ? _window('old') : [_stream('stale')],
          cursor: after == null ? 'next' : null,
        ),
      );
      final state = await _mount(tester, service);
      final profiles = Completer<Map<String, String>>();
      service.profiles = () => profiles.future;
      final pending = state.loadMore();
      await tester.pump();
      service.profiles = null;
      service.fetch = (_) async =>
          TwitchStreamPageResult(streams: _window('fresh'), cursor: null);
      await state.refreshStreams(clearExisting: true);
      profiles.complete({});
      await pending;
      await tester.pumpAndSettle();
      expect(
        state.loadedStreams.map((s) => s.id),
        _window('fresh').map((s) => s.id),
      );
      expect(state.nextCursor, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final reason in [
    'OAuth fixture unavailable',
    'OAuth fixture missing scope',
    'fixture 授權失效',
  ]) {
    testWidgets(
      'Following authorization error shows login and retry: $reason',
      (tester) async {
        var loginCalls = 0;
        final service = _Discovery((_) async => throw StateError(reason));
        final state = await _mount(
          tester,
          service,
          onLogin: () async {
            loginCalls++;
          },
        );
        expect(find.byType(TwitchLoginRequiredView), findsOneWidget);
        expect(find.byType(TwitchDiscoveryStreamGrid), findsNothing);
        await tester.tap(find.text('用 WebView 登入'));
        await tester.pumpAndSettle();
        expect(loginCalls, 1);
        expect(service.calls.length, 1);
        service.fetch = (_) async => TwitchStreamPageResult(
          streams: [_stream('authorized')],
          cursor: null,
        );
        await tester.tap(find.text('重新檢查'));
        await tester.pumpAndSettle();
        expect(find.byType(TwitchLoginRequiredView), findsNothing);
        expect(state.loadedStreams.single.id, 'authorized');
        expect(state.errorText, isNull);
        expect(service.calls.length, 2);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Offline excludes live IDs and logins, supports description search and game reset',
    (tester) async {
      final service = _Discovery(
        (_) async =>
            TwitchStreamPageResult(streams: [_stream('live')], cursor: null),
      );
      service.offline = () async => const TwitchFollowedChannelPageResult(
        channels: [
          TwitchFollowedChannel(
            broadcasterId: 'live',
            broadcasterLogin: 'other-login',
            broadcasterName: 'duplicate-id',
            followedAt: null,
          ),
          TwitchFollowedChannel(
            broadcasterId: 'other-id',
            broadcasterLogin: 'live',
            broadcasterName: 'duplicate-login',
            followedAt: null,
          ),
          TwitchFollowedChannel(
            broadcasterId: 'offline',
            broadcasterLogin: 'offline',
            broadcasterName: 'fixture-offline',
            followedAt: null,
            description: 'description-only',
          ),
        ],
        cursor: null,
      );
      final state = await _mount(tester, service);
      expect(state.offlineFollowedChannels.map((c) => c.broadcasterId), [
        'offline',
      ]);
      expect(find.text('fixture-offline'), findsOneWidget);
      await _mount(tester, service, search: 'description-only');
      expect(find.text('fixture-offline'), findsOneWidget);
      expect(
        tester
            .widget<TwitchDiscoveryStreamGrid>(
              find.byType(TwitchDiscoveryStreamGrid),
            )
            .streams,
        isEmpty,
      );
      await _mount(tester, service);
      unawaited(
        state.showGameMenu(tester.element(find.byType(TwitchFollowingPage))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Game g1').last);
      await tester.pumpAndSettle();
      expect(state.selectedGameId, 'g1');
      expect(find.text('fixture-offline'), findsNothing);
      unawaited(
        state.showGameMenu(tester.element(find.byType(TwitchFollowingPage))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '全部分類'));
      await tester.pumpAndSettle();
      expect(state.selectedGameId, isNull);
      expect(find.text('fixture-offline'), findsOneWidget);
      expect(service.calls, [null]);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Offline follows reads later pages, preserves order and deduplicates',
    (tester) async {
      TwitchFollowedChannel channel(String id) => TwitchFollowedChannel(
        broadcasterId: id,
        broadcasterLogin: id,
        broadcasterName: id,
        followedAt: null,
      );
      final service = _Discovery(
        (_) async =>
            TwitchStreamPageResult(streams: [_stream('live')], cursor: null),
      );
      service.offlinePages = (after) async => after == null
          ? TwitchFollowedChannelPageResult(
              channels: [channel('live'), channel('first')],
              cursor: 'next-offline',
            )
          : TwitchFollowedChannelPageResult(
              channels: [channel('first'), channel('last')],
              cursor: null,
            );
      final state = await _mount(tester, service);
      expect(state.offlineFollowedChannels.map((c) => c.broadcasterId), [
        'first',
        'last',
      ]);
      expect(service.offlineCalls, [null, 'next-offline']);
      expect(state.offlineError, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final repeatCursor in [false, true]) {
    testWidgets(
      'Offline later page failure or cursor cycle is visible and retryable: cycle=$repeatCursor',
      (tester) async {
        final service = _Discovery(
          (_) async =>
              TwitchStreamPageResult(streams: [_stream('live')], cursor: null),
        );
        service.offlinePages = (after) async {
          if (after == null || repeatCursor) {
            return const TwitchFollowedChannelPageResult(
              channels: [],
              cursor: 'next-offline',
            );
          }
          throw StateError('fixture offline second page unavailable');
        };
        final state = await _mount(tester, service);
        expect(service.offlineCalls, [null, 'next-offline']);
        expect(state.offlineError, isNotNull);
        expect(state.loadedStreams.single.id, 'live');
        expect(find.text('載入更多失敗，重試'), findsOneWidget);
        service.offlinePages = (_) async =>
            const TwitchFollowedChannelPageResult(channels: [], cursor: null);
        await tester.tap(find.text('載入更多失敗，重試'));
        await tester.pumpAndSettle();
        expect(state.offlineError, isNull);
        expect(service.offlineCalls, [null, 'next-offline', null]);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final disposePage in [false, true]) {
    testWidgets(
      'Obsolete offline page does not request another cursor: disposed=$disposePage',
      (tester) async {
        final service = _Discovery(
          (_) async =>
              TwitchStreamPageResult(streams: [_stream('live')], cursor: null),
        );
        final state = await _mount(tester, service);
        final pending = Completer<TwitchFollowedChannelPageResult>();
        service.offlinePages = (after) async => after == null
            ? const TwitchFollowedChannelPageResult(
                channels: [],
                cursor: 'pending-offline',
              )
            : pending.future;
        final oldRefresh = state.refreshStreams();
        await tester.pump();
        expect(service.offlineCalls, [null, null, 'pending-offline']);
        if (disposePage) {
          await tester.pumpWidget(const SizedBox());
        } else {
          service.offlinePages = (_) async =>
              const TwitchFollowedChannelPageResult(channels: [], cursor: null);
          await state.refreshStreams();
        }
        pending.complete(
          const TwitchFollowedChannelPageResult(
            channels: [],
            cursor: 'must-not-fetch',
          ),
        );
        await oldRefresh;
        await tester.pump();
        expect(
          service.offlineCalls,
          disposePage
              ? [null, null, 'pending-offline']
              : [null, null, 'pending-offline', null],
        );
        expect(state.offlineError, isNull);
        expect(tester.takeException(), isNull);
        if (!disposePage) {
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  }

  for (final failLate in [false, true]) {
    testWidgets(
      'Service replacement cannot keep old offline pagination: error=$failLate',
      (tester) async {
        final old = _Discovery(
          (_) async => TwitchStreamPageResult(
            streams: [_stream('old-live')],
            cursor: null,
          ),
        );
        final state = await _mount(tester, old);
        final pending = Completer<TwitchFollowedChannelPageResult>();
        old.offlinePages = (after) async => after == null
            ? const TwitchFollowedChannelPageResult(
                channels: [],
                cursor: 'old-offline',
              )
            : pending.future;
        final oldRefresh = state.refreshStreams();
        await tester.pump();
        final replacement = _Discovery(
          (_) async => TwitchStreamPageResult(
            streams: [_stream('new-live')],
            cursor: null,
          ),
        );
        await _mount(tester, replacement, settle: false);
        if (failLate) {
          pending.completeError(StateError('old source failure'));
        } else {
          pending.complete(
            const TwitchFollowedChannelPageResult(
              channels: [
                TwitchFollowedChannel(
                  broadcasterId: 'old-offline',
                  broadcasterLogin: 'old-offline',
                  broadcasterName: 'old-offline',
                  followedAt: null,
                ),
              ],
              cursor: 'old-third',
            ),
          );
        }
        await oldRefresh;
        await tester.pumpAndSettle();
        expect(replacement.calls, [null]);
        expect(replacement.offlineCalls, [null]);
        expect(state.loadedStreams.single.id, 'new-live');
        expect(state.offlineFollowedChannels, isEmpty);
        expect(state.offlineError, isNull);
        expect(old.offlineCalls, [null, null, 'old-offline']);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Replacing source with unauthorized service does not show old private follows',
    (tester) async {
      final old = _Discovery(
        (_) async => TwitchStreamPageResult(
          streams: [_stream('old-live')],
          cursor: null,
        ),
      );
      final state = await _mount(tester, old);
      final replacement = _Discovery(
        (_) async => throw StateError('OAuth fixture unavailable'),
      );
      await _mount(tester, replacement);
      expect(state.loadedStreams, isEmpty);
      expect(find.byType(TwitchLoginRequiredView), findsOneWidget);
      expect(replacement.calls, [null]);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Offline 25 page fixture collects all 2500 without artificial cap',
    (tester) async {
      final service = _Discovery(
        (_) async => const TwitchStreamPageResult(streams: [], cursor: null),
      );
      service.offlinePages = (after) async {
        final page = after == null ? 0 : int.parse(after);
        return TwitchFollowedChannelPageResult(
          channels: List.generate(100, (index) {
            final id = 'offline-${page * 100 + index}';
            return TwitchFollowedChannel(
              broadcasterId: id,
              broadcasterLogin: id,
              broadcasterName: id,
              followedAt: null,
            );
          }),
          cursor: page == 24 ? null : '${page + 1}',
        );
      };
      final state = await _mount(tester, service);
      expect(service.offlineCalls, [
        null,
        ...List.generate(24, (i) => '${i + 1}'),
      ]);
      expect(state.offlineFollowedChannels.length, 2500);
      expect(state.offlineFollowedChannels.first.broadcasterId, 'offline-0');
      expect(state.offlineFollowedChannels.last.broadcasterId, 'offline-2499');
      expect(
        state.offlineFollowedChannels
            .map((c) => c.broadcasterId)
            .toSet()
            .length,
        2500,
      );
      expect(state.offlineError, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final clearExisting in [false, true]) {
    for (final failLate in [false, true]) {
      testWidgets(
        'Following ignores old pagination after refresh: clear=$clearExisting error=$failLate',
        (tester) async {
          final pending = Completer<TwitchStreamPageResult>();
          final fresh = Completer<TwitchStreamPageResult>();
          var refreshes = 0;
          final service = _Discovery((after) async {
            if (after != null) return pending.future;
            if (++refreshes > 1) return fresh.future;
            return TwitchStreamPageResult(
              streams: _window('old'),
              cursor: 'old-next',
            );
          });
          final state = await _mount(tester, service);
          final oldRequest = state.loadMore();
          expect(state.loadingMore, isTrue);
          final refresh = state.refreshStreams(clearExisting: clearExisting);
          final duringRefresh = state.loadMore();
          await tester.pump();
          final callsDuringRefresh = List<String?>.of(service.calls);
          fresh.complete(
            TwitchStreamPageResult(streams: _window('fresh'), cursor: null),
          );
          await refresh;
          expect(state.loadingMore, isFalse);
          if (failLate) {
            pending.completeError(StateError('obsolete fixture failure'));
          } else {
            pending.complete(
              TwitchStreamPageResult(
                streams: [_stream('stale')],
                cursor: 'stale-next',
              ),
            );
          }
          await oldRequest;
          await duringRefresh;
          await tester.pumpAndSettle();
          expect(
            state.loadedStreams.map((s) => s.id),
            _window('fresh').map((s) => s.id),
          );
          expect(state.nextCursor, isNull);
          expect(state.hasMore, isFalse);
          expect(state.paginationError, isNull);
          expect(state.loadingMore, isFalse);
          expect(callsDuringRefresh, [null, 'old-next', null]);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
