part of '../twitch_watch_page.dart';

extension _TwitchWatchPageEngagementPart on _TwitchWatchPageState {
  Future<void> _loadThirdPartyEmotes({bool forceRefresh = false}) async {
    final channelId = _channelId;
    if (channelId == null || channelId.isEmpty) return;

    setState(() => _loadingEmotes = true);
    try {
      await _watchPorts.emotes.loadForChannel(
        channelId: channelId,
        channelLogin: _channelLogin,
        viewerId: _viewerId ?? '',
        forceRefresh: forceRefresh,
      );
    } finally {
      if (mounted) setState(() => _loadingEmotes = false);
    }
  }

  Future<void> _refreshEngagement({bool showSnackOnError = true}) async {
    final channelLogin = _channelLogin;
    final channelId = _channelId;
    if (!mounted) return;

    setState(() {
      _loadingEngagement = true;
      _engagementError = null;
    });

    final snapshot = await _watchPorts.engagement.refresh(
      channelLogin: channelLogin,
      channelId: channelId,
    );

    if (!mounted || channelLogin != _channelLogin) return;
    final lastError = snapshot.error;
    setState(() {
      if (snapshot.channelPoints != null) {
        _channelPointsSnapshot = snapshot.channelPoints;
      }
      if (snapshot.prediction != null) _prediction = snapshot.prediction;
      _pinnedMessages = snapshot.pinnedMessages;
      _engagementError = lastError?.toString();
      _loadingEngagement = false;
    });

    if (lastError != null && showSnackOnError) {
      _showSnack('互動資料更新失敗：$lastError');
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

  Future<void> _openEmotePicker() {
    return _sheetLauncher.openEmotePicker(context);
  }

  Future<void> _openChannelPointsSheet() {
    return _sheetLauncher.openChannelPointsSheet(context);
  }

  Future<void> _openPredictionBetSheet() {
    return _sheetLauncher.openPredictionBetSheet(context);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
