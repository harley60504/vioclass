// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/presentation/watch/controllers/twitch_watch_relationship_controller.dart';

class _Snapshot {
  final bool isFollowing;
  final String userId = 'fixture-channel';
  final DateTime? followedAt = null;

  _Snapshot({this.isFollowing = true});
}

class _Port {
  final pending = Completer<_Snapshot>();
  final unfollowCalls = <List<String?>>[];
  Future<_Snapshot> fetchRelationship({
    String? channelLogin,
    String? targetUserId,
    String? viewerUserId,
  }) => pending.future;
  Future<_Snapshot> followChannel({
    String? channelLogin,
    String? targetUserId,
    String? viewerUserId,
  }) => pending.future;

  Future<_Snapshot> unfollowChannel({
    String? channelLogin,
    String? targetUserId,
    String? viewerUserId,
  }) {
    unfollowCalls.add([channelLogin, targetUserId, viewerUserId]);
    return pending.future;
  }
}

void main() {
  for (final outcome in ['success', 'failure', 'viewer', 'channel']) {
    test('Unfollow applies only current success outcome=$outcome', () async {
      final port = _Port();
      final notices = <String>[];
      var login = 'unfollow-fixture-$outcome';
      var viewer = 'fixture-unfollow-owner';
      final followedAt = DateTime.utc(2020, 1, 1);
      final controller = TwitchWatchRelationshipController(
        relationshipPort: port,
        channelLogin: () => login,
        channelId: () => 'fixture-channel',
        viewerId: () => viewer,
        onChannelIdResolved: (_) => fail('Known channel must not be resolved'),
        showMessage: notices.add,
      );
      addTearDown(controller.dispose);
      controller.seedKnownFollowStatus(true, followedAt: followedAt);
      final request = controller.toggleFollowChannel();
      expect(controller.followBusy, true);
      await controller.toggleFollowChannel();
      expect(port.unfollowCalls, [
        ['unfollow-fixture-$outcome', 'fixture-channel', 'fixture-unfollow-owner'],
      ]);
      if (outcome == 'viewer') viewer = 'replacement-owner';
      if (outcome == 'channel') login = 'replacement-channel';
      if (outcome == 'failure') {
        port.pending.completeError(StateError('fixture rejected unfollow'));
      } else {
        port.pending.complete(_Snapshot(isFollowing: false));
      }
      await request;
      expect(controller.followBusy, false);
      expect(controller.isFollowing, outcome != 'success');
      expect(controller.followedAt, outcome == 'success' ? isNull : followedAt);
      expect(controller.hasResolvedRelationshipStatus, outcome == 'success');
      expect(notices, switch (outcome) {
        'success' => ['已取消追隨 unfollow-fixture-success'],
        'failure' => ['追隨狀態更新失敗，請稍後再試。'],
        _ => isEmpty,
      });
      expect(
        controller.relationshipError,
        outcome == 'failure' ? contains('fixture rejected unfollow') : isNull,
      );
    });
  }
  for (final toggle in [false, true]) {
    test('Current relationship result still applies toggle=$toggle', () async {
      final port = _Port();
      final notices = <String>[];
      final controller = TwitchWatchRelationshipController(
        relationshipPort: port,
        channelLogin: () => 'current-fixture-$toggle',
        channelId: () => null,
        viewerId: () => 'fixture-current-owner',
        onChannelIdResolved: (id) => expect(id, 'fixture-channel'),
        showMessage: notices.add,
      );
      addTearDown(controller.dispose);
      final request = toggle
          ? controller.toggleFollowChannel()
          : controller.refreshRelationshipStatus();
      port.pending.complete(_Snapshot());
      await request;
      expect(controller.isFollowing, isTrue);
      expect(controller.hasResolvedRelationshipStatus, isTrue);
      expect(controller.busy, isFalse);
      expect(controller.relationshipError, isNull);
      expect(notices, toggle ? ['已追隨 current-fixture-true'] : isEmpty);
    });
  }
  for (final toggle in [false, true]) {
    for (final changeViewer in [false, true]) {
      for (final fails in [false, true]) {
        test(
          'Relationship result rejects changed context toggle=$toggle viewer=$changeViewer fails=$fails',
          () async {
            final port = _Port();
            var login = 'context-$toggle-$changeViewer-$fails';
            var viewer = 'fixture-owner';
            var callbacks = 0;
            final controller = TwitchWatchRelationshipController(
              relationshipPort: port,
              channelLogin: () => login,
              channelId: () => null,
              viewerId: () => viewer,
              onChannelIdResolved: (_) => callbacks++,
              showMessage: (_) => callbacks++,
            );
            addTearDown(controller.dispose);
            final request = toggle
                ? controller.toggleFollowChannel()
                : controller.refreshRelationshipStatus();
            if (changeViewer) {
              viewer = 'replacement-owner';
            } else {
              login = 'replacement-channel';
            }
            if (fails) {
              port.pending.completeError(
                StateError('fixture obsolete failure'),
              );
            } else {
              port.pending.complete(_Snapshot());
            }
            await request;
            expect(callbacks, 0);
            expect(controller.isFollowing, isFalse);
            expect(controller.hasResolvedRelationshipStatus, isFalse);
            expect(controller.relationshipError, isNull);
            expect(controller.busy, isFalse);
          },
        );
      }
    }
  }
  for (final toggle in [false, true]) {
    for (final disposed in [false, true]) {
      for (final error in [false, true]) {
        test(
          'Late relationship toggle=$toggle disposed=$disposed error=$error is ignored',
          () async {
            final port = _Port();
            var callbacks = 0;
            var notifications = 0;
            final controller = TwitchWatchRelationshipController(
              relationshipPort: port,
              channelLogin: () => 'fixture-$toggle-$disposed-$error',
              channelId: () => null,
              viewerId: () => 'fixture-viewer',
              onChannelIdResolved: (_) => callbacks++,
              showMessage: (_) => callbacks++,
            );
            controller.addListener(() => notifications++);
            final pending = toggle
                ? controller.toggleFollowChannel()
                : controller.refreshRelationshipStatus();
            if (disposed) {
              controller.dispose();
            } else {
              controller.reset();
            }
            final before = notifications;
            if (error) {
              port.pending.completeError(StateError('fixture late failure'));
            } else {
              port.pending.complete(_Snapshot());
            }
            await pending;
            expect(callbacks, 0);
            expect(notifications, before);
            expect(controller.isFollowing, isFalse);
            expect(controller.relationshipError, isNull);
            if (!disposed) controller.dispose();
          },
        );
      }
    }
  }
}
