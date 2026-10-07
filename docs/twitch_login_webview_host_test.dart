// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/presentation/widgets/shared/twitch_login_webview_host.dart';
import '../lib/features/twitch/services/auth/twitch_webview_environment_disposal.dart';

class _Environment extends Fake implements WebViewEnvironment {
  int disposals = 0;
  Object? failure;
  @override
  String get id => 'fixture-env';
  @override
  Future<void> dispose() async {
    disposals++;
    if (failure != null) throw failure!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('Login host does not suppress input focus: $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final environment = _Environment();
      final focus = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: TwitchLoginWebViewHost(
            createEnvironment: () async => environment,
            builder: (_) => Focus(focusNode: focus, child: const Text('login')),
          ),
        ),
      );
      await tester.pump();
      expect(focus.canRequestFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  }
  test(
    'Missing disposal channel retries only the actual environment ID',
    () async {
      final environment = _Environment()..failure = MissingPluginException();
      const channel = MethodChannel(
        'com.pichillilorenzo/flutter_webview_environment_fixture-env',
      );
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'dispose');
            calls++;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await disposeTwitchWebViewEnvironment(environment);
      expect(calls, 1);
      expect(environment.disposals, 1);
    },
  );
  test(
    'Unrelated native errors are not treated as channel-ID mismatch',
    () async {
      final failure = PlatformException(code: 'fixture-native');
      final environment = _Environment()..failure = failure;
      await expectLater(
        disposeTwitchWebViewEnvironment(environment),
        throwsA(same(failure)),
      );
    },
  );
  testWidgets(
    'Waits for the shared profile without building a default profile',
    (tester) async {
      final pending = Completer<WebViewEnvironment>();
      final environment = _Environment();
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: TwitchLoginWebViewHost(
            createEnvironment: () => pending.future,
            builder: (value) {
              expect(identical(value, environment), isTrue);
              builds++;
              return const Text('login');
            },
          ),
        ),
      );
      expect(builds, 0);
      pending.complete(environment);
      await tester.pump();
      expect(find.text('login'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(environment.disposals, 1);
    },
  );

  testWidgets('Leaving during creation disposes the late environment', (
    tester,
  ) async {
    final pending = Completer<WebViewEnvironment>();
    final environment = _Environment();
    await tester.pumpWidget(
      MaterialApp(
        home: TwitchLoginWebViewHost(
          createEnvironment: () => pending.future,
          builder: (_) => const Text('login'),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    pending.complete(environment);
    await tester.pump();
    expect(environment.disposals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Creation failure can retry without using another cookie profile',
    (tester) async {
      final environment = _Environment();
      var attempts = 0;
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: TwitchLoginWebViewHost(
            createEnvironment: () async {
              if (++attempts == 1) throw StateError('fixture');
              return environment;
            },
            builder: (value) {
              expect(identical(value, environment), isTrue);
              builds++;
              return const Text('login');
            },
          ),
        ),
      );
      await tester.pump();
      expect(builds, 0);
      await tester.tap(find.textContaining('無法建立登入 WebView，點此重試'));
      await tester.pump();
      await tester.pump();
      expect(attempts, 2);
      expect(find.text('login'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(environment.disposals, 1);
    },
  );
}
