part of twitch_watch_page;

extension _TwitchWatchPageEngagementMethods on _TwitchWatchPageState {
  Future<void> _runDeferredEngagementStartup(int generation, String channel) async {
    try {
      await _refreshEngagement(showSnackOnError: false);
    } finally {
      if (_isCurrentWatchTask(generation, channel)) {
        setState(() => _engagementBootstrapping = false);
      }
    }
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
