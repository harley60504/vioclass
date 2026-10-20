// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/twitch/services/notifications/twitch_app_notification_service.dart';
import '../lib/features/twitch/presentation/widgets/notifications/twitch_app_notification_overlay.dart';
import '../lib/features/twitch/presentation/widgets/notifications/twitch_notification_card.dart';

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({});
    twitchAppNotificationCenter.clear();
  });
  tearDown(() {
    twitchAppNotificationCenter.clear();
    debugDefaultTargetPlatformOverride = null;
  });
  Widget page() => const MaterialApp(
    home: TwitchAppNotificationOverlay(
      child: Scaffold(body: Text('fixture page')),
    ),
  );

  for (final size in [const Size(900, 700), const Size(320, 640)]) {
    for (final pending in [false, true]) {
      testWidgets(
        'Account notification rejects obsolete open before repaint or late error size=$size pending=$pending',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final gate = Completer<void>();
          var opens = 0;
          twitchAppNotificationCenter.retainAccountOwner('fixture-owner-old');
          twitchAppNotificationCenter.show(
            title: 'fixture old private action',
            message: 'fixture',
            category: TwitchAppNotificationCategory.giftSubscription,
            accountOwnerId: 'fixture-owner-old',
            onOpen: () {
              opens++;
              return gate.future;
            },
          );
          await tester.pumpWidget(page());
          await tester.pump(const Duration(milliseconds: 250));
          if (pending) {
            await tester.tap(find.text('開啟'));
            await tester.pump();
            expect(opens, 1);
          }
          twitchAppNotificationCenter.retainAccountOwner('fixture-owner-new');
          if (!pending) {
            // Deliberately tap the still-mounted old card before the next frame.
            await tester.tap(find.text('開啟'));
            expect(opens, 0);
            gate.complete();
          } else {
            gate.completeError(StateError('fixture obsolete private error'));
          }
          await tester.pump(const Duration(milliseconds: 250));
          expect(
            twitchAppNotificationCenter.items.where(
              (item) => item.title == '無法開啟通知',
            ),
            isEmpty,
          );
          expect(find.text('fixture obsolete private error'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          twitchAppNotificationCenter.clear();
          twitchAppNotificationCenter.retainAccountOwner(null);
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }
    testWidgets('Open notification panel prunes previous account at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var oldOpens = 0;
      var newOpens = 0;
      twitchAppNotificationCenter.retainAccountOwner('fixture-owner-old');
      twitchAppNotificationCenter.show(
        title: 'fixture old account reward',
        message: 'fixture',
        category: TwitchAppNotificationCategory.giftSubscription,
        accountOwnerId: 'fixture-owner-old',
        onOpen: () async {
          oldOpens++;
        },
      );
      twitchAppNotificationCenter.show(
        title: 'fixture public notice',
        message: 'fixture',
      );
      await tester.pumpWidget(page());
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.pumpAndSettle();
      expect(find.text('fixture old account reward'), findsOneWidget);
      twitchAppNotificationCenter.retainAccountOwner('fixture-owner-new');
      twitchAppNotificationCenter.show(
        title: 'fixture new account reward',
        message: 'fixture',
        category: TwitchAppNotificationCategory.giftSubscription,
        accountOwnerId: 'fixture-owner-new',
        onOpen: () async {
          newOpens++;
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('fixture old account reward'), findsNothing);
      expect(find.text('fixture public notice'), findsOneWidget);
      expect(find.text('fixture new account reward'), findsOneWidget);
      final card = find.ancestor(
        of: find.text('fixture new account reward'),
        matching: find.byType(TwitchNotificationCard),
      );
      final open = find.descendant(of: card, matching: find.text('開啟'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(oldOpens, 0);
      expect(newOpens, 1);
      expect(find.text('fixture page'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      twitchAppNotificationCenter.clear();
      twitchAppNotificationCenter.retainAccountOwner(null);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  for (final scenario in ['success', 'failure', 'unmount-failure']) {
    testWidgets('Notification open completion is lifecycle safe $scenario', (
      tester,
    ) async {
      final gate = Completer<void>();
      var opens = 0;
      twitchAppNotificationCenter.show(
        title: 'fixture notice',
        message: 'fixture',
        onOpen: () {
          opens++;
          return gate.future;
        },
      );
      await tester.pumpWidget(page());
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('開啟'));
      await tester.pump();
      expect(opens, 1);
      if (scenario == 'unmount-failure') {
        await tester.pumpWidget(const SizedBox());
      }
      if (scenario == 'success') {
        gate.complete();
      } else {
        gate.completeError(StateError('fixture private failure'));
      }
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        twitchAppNotificationCenter.items
            .where((item) => item.title == '無法開啟通知')
            .length,
        scenario == 'failure' ? 1 : 0,
      );
      expect(find.text('fixture private failure'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      twitchAppNotificationCenter.clear();
      debugDefaultTargetPlatformOverride = null;
    });
  }
  for (final size in [const Size(900, 700), const Size(320, 640)]) {
    testWidgets(
      'Notification panel marks read and clears fake history at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        twitchAppNotificationCenter.show(
          title: 'fixture first',
          message: 'one',
        );
        twitchAppNotificationCenter.show(
          title: 'fixture second',
          message: 'two',
        );
        expect(twitchAppNotificationCenter.unreadCount, 2);
        await tester.pumpWidget(page());
        await tester.pump(const Duration(milliseconds: 250));
        await tester.tap(find.byIcon(Icons.notifications_none_rounded));
        await tester.pumpAndSettle();
        expect(find.text('通知中心'), findsOneWidget);
        expect(find.text('fixture first'), findsOneWidget);
        expect(find.text('fixture second'), findsOneWidget);
        expect(twitchAppNotificationCenter.unreadCount, 0);
        await tester.tap(find.text('全部清除'));
        await tester.pumpAndSettle();
        expect(twitchAppNotificationCenter.items, isEmpty);
        expect(find.text('目前沒有通知'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        twitchAppNotificationCenter.clear();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}
