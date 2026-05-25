import '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension TwitchWatchPageEngagementMethods on TwitchWatchPageState {
  Future<void> runDeferredEngagementStartup(
    int generation,
    String channel,
  ) async {
    try {
      await refreshEngagement(
        showSnackOnError: false,
        notifyBalanceDelta: false,
      );
    } finally {
      if (isCurrentWatchTask(generation, channel)) {
        setState(() => engagementBootstrapping = false);
        ensureChannelPointPolling(generation: generation, channel: channel);
      }
    }
  }

  void ensureChannelPointPolling({
    required int generation,
    required String channel,
  }) {
    engagementController.ensureChannelPointPolling(
      generation: generation,
      channel: channel,
      engagementBootstrapping: () => engagementBootstrapping,
    );
  }

  Future<void> runDeferredEmoteStartup(int generation, String channel) async {
    try {
      await loadThirdPartyEmotes();
    } finally {
      if (isCurrentWatchTask(generation, channel)) {
        setState(() => emoteBootstrapping = false);
      }
    }
  }

  Future<void> loadThirdPartyEmotes({bool forceRefresh = false}) {
    return engagementController.loadThirdPartyEmotes(
      forceRefresh: forceRefresh,
    );
  }

  Future<void> refreshEngagement({
    bool showSnackOnError = true,
    bool notifyBalanceDelta = true,
  }) {
    return engagementController.refreshEngagement(
      showSnackOnError: showSnackOnError,
      notifyBalanceDelta: notifyBalanceDelta,
    );
  }

  Future<void> openEmotePicker() {
    return sheetLauncher.openEmotePicker(context);
  }

  Future<void> openChannelPointsSheet() {
    return sheetLauncher.openChannelPointsSheet(context);
  }

  Future<void> openPredictionBetSheet() {
    return sheetLauncher.openPredictionBetSheet(context);
  }
}
