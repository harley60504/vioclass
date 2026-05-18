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
        if (snapshot.userId.trim().isNotEmpty) _channelId = snapshot.userId.trim();
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
        if (snapshot.userId.trim().isNotEmpty) _channelId = snapshot.userId.trim();
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
