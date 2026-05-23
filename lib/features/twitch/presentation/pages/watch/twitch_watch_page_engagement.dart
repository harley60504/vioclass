part of twitch_watch_page;

final Map<int, String> _stage249LastNotifiedChannelPointClaimByState =
    <int, String>{};
final Map<int, int> _stage249LastChannelPointBalanceByState = <int, int>{};
final Map<int, Timer> _stage249ChannelPointPollingTimerByState = <int, Timer>{};
final Map<int, Set<String>> _stage249ProcessingChannelPointBonusByState =
    <int, Set<String>>{};
final Map<int, Set<String>> _stage249DoneChannelPointBonusByState =
    <int, Set<String>>{};

extension _TwitchWatchPageEngagementMethods on _TwitchWatchPageState {
  Future<void> _runDeferredEngagementStartup(int generation, String channel) async {
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
    final key = hashCode;
    final existing = _stage249ChannelPointPollingTimerByState[key];
    if (existing != null && existing.isActive) return;

    _stage249ChannelPointPollingTimerByState[key] = Timer.periodic(
      const Duration(seconds: 30),
      (timer) {
        if (!_isCurrentWatchTask(generation, channel)) {
          timer.cancel();
          if (_stage249ChannelPointPollingTimerByState[key] == timer) {
            _stage249ChannelPointPollingTimerByState.remove(key);
          }
          _stage249ProcessingChannelPointBonusByState.remove(key);
          _stage249DoneChannelPointBonusByState.remove(key);
          _stage249LastNotifiedChannelPointClaimByState.remove(key);
          _stage249LastChannelPointBalanceByState.remove(key);
          return;
        }

        if (_loadingEngagement || _engagementBootstrapping) return;
        unawaited(_refreshEngagement(
          showSnackOnError: false,
          notifyBalanceDelta: true,
        ));
      },
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

  Future<void> _refreshEngagement({
    bool showSnackOnError = true,
    bool notifyBalanceDelta = true,
  }) async {
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

    _handleAvailableChannelPointBonus(snapshot.channelPoints);
    _notifyChannelPointBalanceIncrease(
      snapshot.channelPoints,
      notifyBalanceDelta: notifyBalanceDelta,
    );

    if (lastError != null && showSnackOnError) {
      _showSnack('互動資料更新失敗：$lastError');
    }
  }

  void _handleAvailableChannelPointBonus(
    TwitchChannelPointsRuntimeSnapshot? channelPoints,
  ) {
    final key = hashCode;

    if (channelPoints == null || !channelPoints.hasAvailableClaim) {
      _stage249LastNotifiedChannelPointClaimByState.remove(key);
      _stage249ProcessingChannelPointBonusByState[key]?.clear();
      _stage249DoneChannelPointBonusByState[key]?.clear();
      return;
    }

    final claimId = channelPoints.availableClaimId?.trim();
    if (claimId == null || claimId.isEmpty) return;

    final resolvedChannelId = channelPoints.channelId?.trim().isNotEmpty == true
        ? channelPoints.channelId!.trim()
        : _channelId?.trim();
    if (resolvedChannelId == null || resolvedChannelId.isEmpty) {
      _notifyAvailableChannelPointBonus(channelPoints);
      return;
    }

    final bonusKey = '$_channelLogin:$claimId';
    final processing = _stage249ProcessingChannelPointBonusByState
        .putIfAbsent(key, () => <String>{});
    final done = _stage249DoneChannelPointBonusByState
        .putIfAbsent(key, () => <String>{});

    if (processing.contains(bonusKey) || done.contains(bonusKey)) return;

    processing.add(bonusKey);
    unawaited(_collectAvailableChannelPointBonus(
      stateKey: key,
      bonusKey: bonusKey,
      channelId: resolvedChannelId,
      claimId: claimId,
      channelPoints: channelPoints,
    ));
  }

  Future<void> _collectAvailableChannelPointBonus({
    required int stateKey,
    required String bonusKey,
    required String channelId,
    required String claimId,
    required TwitchChannelPointsRuntimeSnapshot channelPoints,
  }) async {
    final fallbackPoints = channelPoints.availableClaimPoints;
    final name = channelPoints.pointsName?.trim();
    final pointName = name == null || name.isEmpty ? '忠誠點數' : name;

    try {
      final result = await _watchPorts.engagement.claimCommunityPoints(
        channelId: channelId,
        claimId: claimId,
      );

      _stage249DoneChannelPointBonusByState
          .putIfAbsent(stateKey, () => <String>{})
          .add(bonusKey);

      if (!mounted) return;
      final earned = result.pointsEarned > 0 ? result.pointsEarned : fallbackPoints;
      twitchAppNotificationCenter.showSuccess(
        title: '已領取 $pointName',
        message: '$_channelLogin +$earned 點。',
        duration: const Duration(seconds: 5),
      );

      await _refreshEngagement(
        showSnackOnError: false,
        notifyBalanceDelta: true,
      );
    } catch (error) {
      if (!mounted) return;
      twitchAppNotificationCenter.showWarning(
        title: '$pointName 領取失敗',
        message: '$_channelLogin：$error',
        duration: const Duration(seconds: 8),
      );
    } finally {
      _stage249ProcessingChannelPointBonusByState[stateKey]?.remove(bonusKey);
    }
  }

  void _notifyAvailableChannelPointBonus(
    TwitchChannelPointsRuntimeSnapshot? channelPoints,
  ) {
    if (channelPoints == null || !channelPoints.hasAvailableClaim) {
      _stage249LastNotifiedChannelPointClaimByState.remove(hashCode);
      return;
    }

    final claimId = channelPoints.availableClaimId?.trim();
    if (claimId == null || claimId.isEmpty) return;

    final memoryKey = '$_channelLogin:$claimId';
    if (_stage249LastNotifiedChannelPointClaimByState[hashCode] == memoryKey) {
      return;
    }

    _stage249LastNotifiedChannelPointClaimByState[hashCode] = memoryKey;

    final points = channelPoints.availableClaimPoints;
    final pointsText = points > 0 ? '$points 點' : '忠誠點數';
    final name = channelPoints.pointsName?.trim();
    final pointName = name == null || name.isEmpty ? '忠誠點數' : name;

    twitchAppNotificationCenter.showInfo(
      title: '可以領取 $pointName',
      message: '$_channelLogin 有可領取的 $pointsText，但目前沒有 channelId，先只通知。',
      duration: const Duration(seconds: 7),
    );
  }

  void _notifyChannelPointBalanceIncrease(
    TwitchChannelPointsRuntimeSnapshot? channelPoints, {
    required bool notifyBalanceDelta,
  }) {
    final balance = channelPoints?.balance;
    if (channelPoints == null || balance == null) return;

    final key = hashCode;
    final previousBalance = _stage249LastChannelPointBalanceByState[key];
    _stage249LastChannelPointBalanceByState[key] = balance;

    if (!notifyBalanceDelta || previousBalance == null) return;
    final delta = balance - previousBalance;
    if (delta <= 0) return;

    final name = channelPoints.pointsName?.trim();
    final pointName = name == null || name.isEmpty ? '忠誠點數' : name;

    twitchAppNotificationCenter.showInfo(
      title: '$pointName 增加',
      message: '$_channelLogin +$delta 點，目前 $balance 點。',
      duration: const Duration(seconds: 5),
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
