part of '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _TwitchWatchPageRelationshipMethods on _TwitchWatchPageState {
  Future<void> _runDeferredRelationshipStartup(
    int generation,
    String channel,
  ) async {
    try {
      await _refreshRelationshipStatus(channelLogin: channel);
    } finally {
      if (_isCurrentWatchTask(generation, channel)) {
        setState(() => _relationshipBootstrapping = false);
      }
    }
  }

  Future<void> _refreshRelationshipStatus({String? channelLogin}) {
    return _relationshipController.refreshRelationshipStatus(
      targetChannelLogin: channelLogin,
    );
  }

  Future<void> _toggleFollowChannel() {
    return _relationshipController.toggleFollowChannel();
  }

  Future<void> _openSubscribePage() async {
    try {
      await showTwitchSubscribeWebViewDialogV1(
        context: context,
        initialUri: _relationshipController.buildSubscribeUri(),
        channelLogin: _channelLogin,
      );
    } catch (error) {
      _showSnack('開啟訂閱頁失敗：$error');
    }
  }
}
