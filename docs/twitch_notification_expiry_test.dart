// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/services/notifications/twitch_app_notification_service.dart';

void main() {
  testWidgets('Default toast expires after five seconds, keeping history', (
    tester,
  ) async {
    final center = TwitchAppNotificationCenter();
    addTearDown(center.dispose);
    var changes = 0;
    center.addListener(() => changes++);
    center.showInfo(title: '開台', message: '直播已開始');
    await tester.pump(const Duration(seconds: 4));
    expect(center.visibleItems, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    expect(center.visibleItems, isEmpty);
    expect(center.items, hasLength(1));
    expect(center.unreadCount, 1);
    expect(changes, 2);
  });

  testWidgets('Inactive/native focus does not extend toast lifetime', (
    tester,
  ) async {
    final center = TwitchAppNotificationCenter();
    addTearDown(center.dispose);
    center.showSuccess(title: '點數', message: '更新完成');
    await tester.pump(const Duration(seconds: 3));
    center.pauseAutoDismiss();
    center.pauseAutoDismiss();
    await tester.pump(const Duration(seconds: 5));
    expect(center.visibleItems, isEmpty);
    center.resumeAutoDismiss();
    expect(center.visibleItems, isEmpty);
    expect(center.items, hasLength(1));
  });

  testWidgets('Notifications created while inactive still expire', (
    tester,
  ) async {
    final center = TwitchAppNotificationCenter();
    addTearDown(center.dispose);
    center.pauseAutoDismiss();
    center.showWarning(title: '通知', message: '測試');
    await tester.pump(TwitchAppNotificationCenter.defaultDuration);
    expect(center.visibleItems, isEmpty);
    expect(center.items, hasLength(1));
  });

  testWidgets('Resuming does not restart the remaining countdown', (
    tester,
  ) async {
    final center = TwitchAppNotificationCenter();
    addTearDown(center.dispose);
    center.showInfo(title: '通知', message: '測試');
    await tester.pump(const Duration(seconds: 2));
    center.pauseAutoDismiss();
    await tester.pump(const Duration(seconds: 2));
    center.resumeAutoDismiss();
    await tester.pump(const Duration(seconds: 1));
    expect(center.visibleItems, isEmpty);
  });

  testWidgets('Replaced toast cannot expire the newer notification', (
    tester,
  ) async {
    final center = TwitchAppNotificationCenter();
    addTearDown(center.dispose);
    center.showInfo(title: '舊通知', message: '舊');
    await tester.pump(const Duration(seconds: 1));
    final newest = center.showInfo(title: '新通知', message: '新');
    await tester.pump(const Duration(seconds: 4));
    expect(center.visibleItems.single.id, newest);
    await tester.pump(const Duration(seconds: 4));
    expect(center.visibleItems, isEmpty);
    expect(center.items, hasLength(2));
  });
}
