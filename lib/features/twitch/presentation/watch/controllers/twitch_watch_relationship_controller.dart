import 'package:flutter/foundation.dart';

import '../../../services/discovery/twitch_channel_snapshot_cache.dart';

class _CachedRelationshipStatus {
  final bool isFollowing;
  final String? userId;
  final DateTime storedAt;

  const _CachedRelationshipStatus({
    required this.isFollowing,
    required this.userId,
    required this.storedAt,
  });

  bool get fresh =>
      DateTime.now().difference(storedAt) < const Duration(minutes: 2);
}

class TwitchWatchRelationshipController extends ChangeNotifier {
  static final Map<String, _CachedRelationshipStatus> _relationshipCache =
      <String, _CachedRelationshipStatus>{};

  final dynamic relationshipPort;
  final String Function() channelLogin;
  final String? Function() channelId;
  final String? Function() viewerId;
  final void Function(String channelId) onChannelIdResolved;
  final void Function(String message) showMessage;

  bool checkingRelationship = false;
  bool followBusy = false;
  bool isFollowing = false;
  bool hasResolvedRelationshipStatus = false;
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

  void seedKnownFollowStatus(bool following, {String? resolvedUserId}) {
    final login = channelLogin().trim().toLowerCase();
    if (login.isEmpty) return;

    _applySnapshot(following: following, resolvedUserId: resolvedUserId);
    hasResolvedRelationshipStatus = false;
    relationshipError = null;
  }

  Future<void> refreshRelationshipStatus({String? targetChannelLogin}) async {
    final login = (targetChannelLogin ?? channelLogin()).trim().toLowerCase();
    if (login.isEmpty || checkingRelationship) return;
    final cacheKey = _cacheKey(login);
    final cached = _relationshipCache[cacheKey];
    if (cached != null && cached.fresh) {
      _applySnapshot(
        following: cached.isFollowing,
        resolvedUserId: cached.userId,
      );
      hasResolvedRelationshipStatus = true;
      relationshipError = null;
      notifyListeners();
      return;
    }

    checkingRelationship = true;
    relationshipError = null;
    notifyListeners();

    try {
      final snapshot = await relationshipPort.fetchRelationship(
        channelLogin: login,
        targetUserId: channelId(),
        viewerUserId: viewerId(),
      );
      final following = snapshot.isFollowing == true;
      final resolvedUserId = (snapshot.userId as String?)?.trim() ?? '';
      _applySnapshot(following: following, resolvedUserId: resolvedUserId);
      hasResolvedRelationshipStatus = true;
      _relationshipCache[cacheKey] = _CachedRelationshipStatus(
        isFollowing: following,
        userId: resolvedUserId.isEmpty ? null : resolvedUserId,
        storedAt: DateTime.now(),
      );
      TwitchChannelSnapshotCache.instance.remember(
        TwitchChannelSnapshot(
          broadcasterId: resolvedUserId,
          broadcasterLogin: login,
          isFollowed: following,
        ),
      );
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
      final following = snapshot.isFollowing == true;
      final resolvedUserId = (snapshot.userId as String?)?.trim() ?? '';
      _applySnapshot(following: following, resolvedUserId: resolvedUserId);
      hasResolvedRelationshipStatus = true;
      _relationshipCache[_cacheKey(login)] = _CachedRelationshipStatus(
        isFollowing: following,
        userId: resolvedUserId.isEmpty ? null : resolvedUserId,
        storedAt: DateTime.now(),
      );
      TwitchChannelSnapshotCache.instance.remember(
        TwitchChannelSnapshot(
          broadcasterId: resolvedUserId,
          broadcasterLogin: login,
          isFollowed: following,
        ),
      );
      relationshipError = null;
      showMessage(isFollowing ? '已追隨 $login' : '已取消追隨 $login');
    } catch (error) {
      relationshipError = error.toString();
      showMessage('追隨狀態更新失敗，請稍後再試。');
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
    hasResolvedRelationshipStatus = false;
    relationshipError = null;
    notifyListeners();
  }

  String _cacheKey(String login) {
    final viewer = viewerId()?.trim();
    return '${viewer == null || viewer.isEmpty ? 'anonymous' : viewer}|$login';
  }

  void _applySnapshot({required bool following, String? resolvedUserId}) {
    isFollowing = following;
    final cleanUserId = resolvedUserId?.trim() ?? '';
    final currentChannelId = channelId();
    if ((currentChannelId == null || currentChannelId.trim().isEmpty) &&
        cleanUserId.isNotEmpty) {
      onChannelIdResolved(cleanUserId);
    }
  }
}
