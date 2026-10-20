import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/api/core/twitch_api_client.dart';
import 'package:vioclass/features/twitch/api/auth/twitch_auth_api_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_auth_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_drops_auth_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_web_gql_auth_service.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_viewer_session.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/watch/twitch_watch_page_startup.dart';

class _Auth extends TwitchAuthService {
  String? fixtureToken;
  _Auth(TwitchApiClient client, this.fixtureToken) : super(apiClient: client);
  @override
  String? get accessToken => fixtureToken;
  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async =>
      fixtureToken;
  @override
  Future<void> loadStoredSession({bool refreshIfNeeded = true}) async {}
  void changeIdentity(String? token) {
    fixtureToken = token;
    notifyListeners();
  }
}

class _Drops extends TwitchDropsAuthService {
  _Drops(TwitchApiClient client) : super(apiClient: client);
  @override
  Future<void> loadStoredSession() async {}
}

class _Web extends TwitchWebGqlAuthService {
  _Web(TwitchApiClient client) : super(apiClient: client);
  @override
  Future<void> loadStoredSession({
    bool migrateLegacyDropsWebToken = true,
  }) async {}
}

class _Validation extends TwitchAuthApiService {
  final old = Completer<TwitchTokenValidation>();
  bool failCurrent = false;
  int calls = 0;
  _Validation(TwitchApiClient client) : super(client: client);
  @override
  Future<TwitchTokenValidation> validateToken(String token) async {
    calls++;
    if (token == 'old-fixture') return old.future;
    if (failCurrent) throw StateError('fixture-current-validation-error');
    return const TwitchTokenValidation(
      clientId: 'fixture-client',
      login: 'new_viewer',
      userId: '99',
      scopes: ['chat:read'],
      expiresIn: 3600,
    );
  }
}

// Executes the official startup extension with isolated dependency getters.
// Does not mount a widget, create a Player, connect IRC, or access storage.
class _Page extends TwitchWatchPageState {
  @override
  final TwitchAuthService authService;
  @override
  final TwitchDropsAuthService dropsAuthService;
  @override
  final TwitchWebGqlAuthService webGqlAuthService;
  @override
  final TwitchAuthApiService authApi;
  final snacks = <String>[];
  bool attached = true;
  int stateChanges = 0;
  _Page(
    this.authService,
    this.dropsAuthService,
    this.webGqlAuthService,
    this.authApi,
  );
  @override
  bool get mounted => attached;
  @override
  void setState(VoidCallback fn) {
    stateChanges++;
    fn();
  }

  @override
  void showSnack(String message) => snacks.add(message);
}

void main() {
  for (final failOld in [false, true]) {
    test(
      'Watch shared new identity without new load finishes old loading failure=$failOld',
      () async {
        final client = TwitchApiClient();
        addTearDown(() => client.close(force: true));
        final auth = _Auth(client, 'old-fixture');
        final validation = _Validation(client);
        final page = _Page(auth, _Drops(client), _Web(client), validation);
        final session = TwitchViewerSession.forAuth(auth);
        session.addListener(page.syncViewerIdentity);
        addTearDown(() => session.removeListener(page.syncViewerIdentity));
        final pending = page.loadAuth();
        for (var i = 0; i < 8; i++) {
          await Future<void>.value();
        }
        expect(validation.calls, 1);
        auth.changeIdentity('new-fixture');
        await session.resolve(validation);
        expect(page.viewerId, '99');
        expect(page.loadingAuth, isFalse);
        if (failOld) {
          validation.old.completeError(StateError('fixture-old-error'));
        } else {
          validation.old.complete(
            const TwitchTokenValidation(
              clientId: 'fixture-client',
              login: 'old_viewer',
              userId: '42',
              scopes: ['chat:read'],
              expiresIn: 3600,
            ),
          );
        }
        await pending;
        expect(page.viewerId, '99');
        expect(page.loadingAuth, isFalse);
        expect(page.snacks, isEmpty);
      },
    );
  }
  test(
    'Watch current validation failure finishes loading and reports once',
    () async {
      final client = TwitchApiClient();
      addTearDown(() => client.close(force: true));
      final auth = _Auth(client, 'new-fixture');
      final validation = _Validation(client)..failCurrent = true;
      final page = _Page(auth, _Drops(client), _Web(client), validation);
      await page.loadAuth();
      expect(validation.calls, 1);
      expect(page.loadingAuth, isFalse);
      expect(page.viewerId, isNull);
      expect(page.snacks, ['OAuth 暫時載入失敗，請稍後再試。']);
      validation.failCurrent = false;
      await page.loadAuth();
      expect(validation.calls, 2);
      expect(page.viewerId, '99');
      expect(page.loadingAuth, isFalse);
      expect(page.snacks, hasLength(1));
    },
  );
  test(
    'Watch guest startup does not validate or retain an old viewer',
    () async {
      final client = TwitchApiClient();
      addTearDown(() => client.close(force: true));
      final auth = _Auth(client, null);
      final validation = _Validation(client);
      final page = _Page(auth, _Drops(client), _Web(client), validation)
        ..viewerId = '42'
        ..viewerLogin = 'old_viewer';
      await page.loadAuth();
      expect(validation.calls, 0);
      expect(page.viewerId, isNull);
      expect(page.viewerLogin, isNull);
      expect(page.loadingAuth, isFalse);
      expect(page.snacks, isEmpty);
      expect(
        TwitchViewerSession.forAuth(auth).status,
        TwitchViewerStatus.guest,
      );
    },
  );
  for (final detach in [false, true]) {
    for (final failOld in [false, true]) {
      test(
        'Watch pending completion logout/dispose detach=$detach failure=$failOld',
        () async {
          final client = TwitchApiClient();
          addTearDown(() => client.close(force: true));
          final auth = _Auth(client, 'old-fixture');
          final validation = _Validation(client);
          final page = _Page(auth, _Drops(client), _Web(client), validation);
          final pending = page.loadAuth();
          for (var i = 0; i < 8; i++) {
            await Future<void>.value();
          }
          expect(validation.calls, 1);
          if (detach) {
            page.attached = false;
          } else {
            auth.changeIdentity(null);
            await page.loadAuth();
            expect(page.loadingAuth, isFalse);
          }
          final stateChanges = page.stateChanges;
          if (failOld) {
            validation.old.completeError(StateError('fixture-old-error'));
          } else {
            validation.old.complete(
              const TwitchTokenValidation(
                clientId: 'fixture-client',
                login: 'old_viewer',
                userId: '42',
                scopes: ['chat:read'],
                expiresIn: 3600,
              ),
            );
          }
          await pending;
          expect(page.stateChanges, stateChanges);
          expect(page.viewerId, isNull);
          expect(page.snacks, isEmpty);
          if (!detach) {
            expect(TwitchViewerSession.forAuth(auth).snapshot, isNull);
            expect(
              TwitchViewerSession.forAuth(auth).status,
              TwitchViewerStatus.guest,
            );
          }
        },
      );
    }
  }
  for (final failOld in [false, true]) {
    test(
      'Watch auth old completion cannot disturb new viewer failure=$failOld',
      () async {
        final client = TwitchApiClient();
        addTearDown(() => client.close(force: true));
        final auth = _Auth(client, 'old-fixture');
        final validation = _Validation(client);
        final page = _Page(auth, _Drops(client), _Web(client), validation);
        final oldLoad = page.loadAuth();
        for (var i = 0; i < 8; i++) {
          await Future<void>.value();
        }
        expect(validation.calls, 1);
        auth.changeIdentity('new-fixture');
        await page.loadAuth();
        expect(page.viewerId, '99');
        expect(page.loadingAuth, isFalse);
        if (failOld) {
          validation.old.completeError(
            StateError('fixture-old-validation-error'),
          );
        } else {
          validation.old.complete(
            const TwitchTokenValidation(
              clientId: 'fixture-client',
              login: 'old_viewer',
              userId: '42',
              scopes: ['chat:read'],
              expiresIn: 3600,
            ),
          );
        }
        await oldLoad;
        expect(page.viewerId, '99');
        expect(page.viewerLogin, 'new_viewer');
        expect(page.loadingAuth, isFalse);
        expect(page.snacks, isEmpty);
        expect(TwitchViewerSession.forAuth(auth).snapshot?.viewerId, '99');
      },
    );
  }
}
