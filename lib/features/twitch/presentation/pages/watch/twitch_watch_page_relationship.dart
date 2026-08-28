import '../../dialogs/twitch_subscribe_webview_dialog_v1.dart';
import '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension TwitchWatchPageRelationshipMethods on TwitchWatchPageState {
  Future<void> runDeferredRelationshipStartup(
    int generation,
    String channel,
  ) async {
    try {
      await refreshRelationshipStatus(channelLogin: channel);
    } finally {
      if (isCurrentWatchTask(generation, channel)) {
        setState(() => relationshipBootstrapping = false);
      }
    }
  }

  Future<void> refreshRelationshipStatus({String? channelLogin}) {
    return relationshipController.refreshRelationshipStatus(
      targetChannelLogin: channelLogin,
    );
  }

  Future<void> toggleFollowChannel() {
    return relationshipController.toggleFollowChannel();
  }

  Future<void> openSubscribePage() async {
    try {
      await showTwitchSubscribeWebViewDialogV1(
        context: context,
        initialUri: relationshipController.buildSubscribeUri(),
        channelLogin: channelLogin,
      );
    } catch (error) {
      showSnack('訂閱頁暫時無法開啟，請稍後再試。');
    }
  }
}
