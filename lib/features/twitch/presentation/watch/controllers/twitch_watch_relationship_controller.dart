import 'package:flutter/foundation.dart';

class TwitchWatchRelationshipController extends ChangeNotifier {
  final dynamic relationshipPort;
  final String Function() channelLogin;
  final String? Function() channelId;
  final String? Function() viewerId;
  final void Function(String channelId) onChannelIdResolved;
  final void Function(String message) showMessage;

  bool checkingRelationship = false;
  bool followBusy = false;
  bool isFollowing = false;
  String? relationshipError;

  TwitchWatchRelationshipController({
    required this.relationshipPort,
    required this.channelLogin,
    required this.channelId,
    required this.viewerId,
    required this.onChannelIdResolved,
    required this.showMessage,
  });

  bool get busy => checkingRelationship || followBusy;

  Future<void> refreshRelationshipStatus({String? targetChannelLogin}) async {
    final login = (targetChannelLogin ?? channelLogin()).trim().toLowerCase();
    if (login.isEmpty || checkingRelationship) return;

    checkingRelationship = true;
    relationshipError = null;
    notifyListeners();

    try {
      final snapshot = await relationshipPort.fetchRelationship(
        channelLogin: login,
        targetUserId: channelId(),
        viewerUserId: viewerId(),
      );
      isFollowing = snapshot.isFollowing == true;
      final resolvedUserId = (snapshot.userId as String?)?.trim() ?? '';
      final currentChannelId = channelId();
      if ((currentChannelId == null || currentChannelId.trim().isEmpty) &&
          resolvedUserId.isNotEmpty) {
        onChannelIdResolved(resolvedUserId);
      }
      relationshipError = null;
    } catch (error) {
      relationshipError = error.toString();
    } finally {
      checkingRelationship = false;
      notifyListeners();
    }
  }

  Future<void> toggleFollowChannel() async {
    if (followBusy) return;
    final login = channelLogin().trim().toLowerCase();
    if (login.isEmpty) return;

    followBusy = true;
    relationshipError = null;
    notifyListeners();

    try {
      final snapshot = isFollowing
          ? await relationshipPort.unfollowChannel(
              channelLogin: login,
              targetUserId: channelId(),
              viewerUserId: viewerId(),
            )
          : await relationshipPort.followChannel(
              channelLogin: login,
              targetUserId: channelId(),
              viewerUserId: viewerId(),
            );
      isFollowing = snapshot.isFollowing == true;
      final resolvedUserId = (snapshot.userId as String?)?.trim() ?? '';
      final currentChannelId = channelId();
      if ((currentChannelId == null || currentChannelId.trim().isEmpty) &&
          resolvedUserId.isNotEmpty) {
        onChannelIdResolved(resolvedUserId);
      }
      relationshipError = null;
      showMessage(isFollowing ? '已追隨 $login' : '已取消追隨 $login');
    } catch (error) {
      relationshipError = error.toString();
      showMessage('追隨狀態更新失敗：$error');
    } finally {
      followBusy = false;
      notifyListeners();
    }
  }

  Uri buildSubscribeUri() {
    return relationshipPort.buildSubscribeUri(channelLogin());
  }

  void reset() {
    checkingRelationship = false;
    followBusy = false;
    isFollowing = false;
    relationshipError = null;
    notifyListeners();
  }
}
