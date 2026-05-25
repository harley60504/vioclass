part of '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _TwitchWatchPageEngagementMethods on _TwitchWatchPageState {
  Future<void> _runDeferredEngagementStartup(
    int generation,
    String channel,
  ) async {
    try {
      await _refreshEngagement(
        showSnackOnError: false,
        notifyBalanceDelta: false,
      );
    } finally {
      if (_isCurrentWatchTask(generation, channel)) {
        setState(() => _engagementBootstrapping = false);
        _ensureChannelPointPolling(generation: generation, channel: channel);
      }
    }
  }

  void _ensureChannelPointPolling({
    required int generation,
    required String channel,
  }) {
    _engagementController.ensureChannelPointPolling(
      generation: generation,
      channel: channel,
      engagementBootstrapping: () => _engagementBootstrapping,
    );
  }

  Future<void> _runDeferredEmoteStartup(int generation, String channel) async {
    try {
      await _loadThirdPartyEmotes();
    } finally {
      if (_isCurrentWatchTask(generation, channel)) {
        setState(() => _emoteBootstrapping = false);
      }
    }
  }

  Future<void> _loadThirdPartyEmotes({bool forceRefresh = false}) {
    return _engagementController.loadThirdPartyEmotes(
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _refreshEngagement({
    bool showSnackOnError = true,
    bool notifyBalanceDelta = true,
  }) {
    return _engagementController.refreshEngagement(
      showSnackOnError: showSnackOnError,
      notifyBalanceDelta: notifyBalanceDelta,
    );
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
}
