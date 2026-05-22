part of twitch_watch_page;

extension _TwitchWatchPageRelationshipMethods on _TwitchWatchPageState {
  Future<void> _runDeferredRelationshipStartup(int generation, String channel) async {
    try {
      await _refreshRelationshipStatus(channelLogin: channel);
    } finally {
      if (_isCurrentWatchTask(generation, channel)) {
        setState(() => _relationshipBootstrapping = false);
      }
    }
  }

  Future<void> _refreshRelationshipStatus({String? channelLogin}) async {
    final login = (channelLogin ?? _channelLogin).trim().toLowerCase();
    if (login.isEmpty || _checkingRelationship) return;

    setState(() {
      _checkingRelationship = true;
      _relationshipError = null;
    });

    try {
      final snapshot = await _watchPorts.relationship.fetchRelationship(
        channelLogin: login,
        targetUserId: _channelId,
        viewerUserId: _viewerId,
      );
      if (!mounted) return;
      setState(() {
        _isFollowing = snapshot.isFollowing;
        // Stage 245C:
        // The chat startup snapshot is the authoritative channel id source for
        // chat/emotes/pinned/prediction. Relationship runs in parallel now, so
        // do not let it overwrite an existing channel id and race emote loading
        // into a wrong/sub-related id. Use relationship's resolved id only as a
        // fallback when startup has not produced an id yet.
        final resolvedUserId = snapshot.userId.trim();
        if ((_channelId == null || _channelId!.trim().isEmpty) &&
            resolvedUserId.isNotEmpty) {
          _channelId = resolvedUserId;
        }
        _relationshipError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _relationshipError = error.toString());
    } finally {
      if (mounted) setState(() => _checkingRelationship = false);
    }
  }

  Future<void> _toggleFollowChannel() async {
    if (_followBusy) return;
    final login = _channelLogin.trim().toLowerCase();
    if (login.isEmpty) return;

    setState(() {
      _followBusy = true;
      _relationshipError = null;
    });

    try {
      final snapshot = _isFollowing
          ? await _watchPorts.relationship.unfollowChannel(
              channelLogin: login,
              targetUserId: _channelId,
              viewerUserId: _viewerId,
            )
          : await _watchPorts.relationship.followChannel(
              channelLogin: login,
              targetUserId: _channelId,
              viewerUserId: _viewerId,
            );
      if (!mounted) return;
      setState(() {
        _isFollowing = snapshot.isFollowing;
        final resolvedUserId = snapshot.userId.trim();
        if ((_channelId == null || _channelId!.trim().isEmpty) &&
            resolvedUserId.isNotEmpty) {
          _channelId = resolvedUserId;
        }
        _relationshipError = null;
      });
      _showSnack(_isFollowing ? '已追隨 $login' : '已取消追隨 $login');
    } catch (error) {
      if (mounted) {
        setState(() => _relationshipError = error.toString());
        _showSnack('追隨狀態更新失敗：$error');
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _openSubscribePage() async {
    try {
      final uri = _watchPorts.relationship.buildSubscribeUri(_channelLogin);
      await showTwitchSubscribeWebViewDialogV1(
        context: context,
        initialUri: uri,
        channelLogin: _channelLogin,
      );
    } catch (error) {
      _showSnack('開啟訂閱彈窗失敗：$error');
    }
  }
}
