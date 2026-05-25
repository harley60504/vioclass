import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../api/engagement/twitch_hype_train_api_service.dart';
import '../../../models/engagement/twitch_prediction.dart';
import '../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../../services/engagement/twitch_hype_train_controller.dart';
import '../../../services/notifications/twitch_app_notification_service.dart';

class TwitchWatchEngagementController extends ChangeNotifier {
  final dynamic emotesPort;
  final dynamic engagementPort;
  final String Function() channelLogin;
  final String? Function() channelId;
  final String? Function() viewerId;
  final bool Function(int generation, String channel) isCurrentWatchTask;
  final TwitchHypeTrainController hypeTrainController;

  final Map<int, String> _lastNotifiedChannelPointClaimByState =
      <int, String>{};
  final Map<int, int> _lastChannelPointBalanceByState = <int, int>{};
  final Map<int, Timer> _channelPointPollingTimerByState = <int, Timer>{};
  final Map<int, Set<String>> _processingChannelPointBonusByState =
      <int, Set<String>>{};
  final Map<int, Set<String>> _doneChannelPointBonusByState =
      <int, Set<String>>{};

  bool loadingEmotes = false;
  bool loadingEngagement = false;
  String? engagementError;
  TwitchChannelPointsRuntimeSnapshot? channelPointsSnapshot;
  TwitchPredictionSnapshot? prediction;
  List<dynamic> pinnedMessages = const <dynamic>[];

  TwitchWatchEngagementController({
    required this.emotesPort,
    required this.engagementPort,
    required this.channelLogin,
    required this.channelId,
    required this.viewerId,
    required this.isCurrentWatchTask,
    TwitchHypeTrainController? hypeTrainController,
  }) : hypeTrainController =
           hypeTrainController ??
           TwitchHypeTrainController(api: const TwitchHypeTrainApiService());

  void ensureChannelPointPolling({
    required int generation,
    required String channel,
    required bool Function() engagementBootstrapping,
  }) {
    final key = hashCode;
    final existing = _channelPointPollingTimerByState[key];
    if (existing != null && existing.isActive) return;

    _channelPointPollingTimerByState[key] = Timer.periodic(
      const Duration(seconds: 30),
      (timer) {
        if (!isCurrentWatchTask(generation, channel)) {
          timer.cancel();
          if (_channelPointPollingTimerByState[key] == timer) {
            _channelPointPollingTimerByState.remove(key);
          }
          _processingChannelPointBonusByState.remove(key);
          _doneChannelPointBonusByState.remove(key);
          _lastNotifiedChannelPointClaimByState.remove(key);
          _lastChannelPointBalanceByState.remove(key);
          return;
        }

        if (loadingEngagement || engagementBootstrapping()) return;
        unawaited(refreshEngagement(showSnackOnError: false));
      },
    );
  }

  Future<void> loadThirdPartyEmotes({bool forceRefresh = false}) async {
    final currentChannelId = channelId();
    if (currentChannelId == null || currentChannelId.isEmpty) return;

    loadingEmotes = true;
    notifyListeners();
    try {
      await emotesPort.loadForChannel(
        channelId: currentChannelId,
        channelLogin: channelLogin(),
        viewerId: viewerId() ?? '',
        forceRefresh: forceRefresh,
      );
    } finally {
      loadingEmotes = false;
      notifyListeners();
    }
  }

  Future<void> refreshEngagement({
    bool showSnackOnError = true,
    bool notifyBalanceDelta = true,
  }) async {
    final login = channelLogin();
    final currentChannelId = channelId();

    loadingEngagement = true;
    engagementError = null;
    notifyListeners();

    final snapshot = await engagementPort.refresh(
      channelLogin: login,
      channelId: currentChannelId,
    );
    if (login != channelLogin()) return;
    unawaited(
      hypeTrainController.refresh(
        channelLogin: login,
        channelId: currentChannelId,
      ),
    );
    final lastError = snapshot.error;
    if (snapshot.channelPoints != null) {
      channelPointsSnapshot = snapshot.channelPoints;
    }
    if (snapshot.prediction != null) prediction = snapshot.prediction;
    pinnedMessages = snapshot.pinnedMessages;
    engagementError = lastError?.toString();
    loadingEngagement = false;
    notifyListeners();

    _handleAvailableChannelPointBonus(snapshot.channelPoints);
    _notifyChannelPointBalanceIncrease(
      snapshot.channelPoints,
      notifyBalanceDelta: notifyBalanceDelta,
    );

    if (lastError != null && showSnackOnError) {
      debugPrint('refresh engagement failed: $lastError');
    }
  }

  void _handleAvailableChannelPointBonus(
    TwitchChannelPointsRuntimeSnapshot? channelPoints,
  ) {
    final key = hashCode;

    if (channelPoints == null || !channelPoints.hasAvailableClaim) {
      _lastNotifiedChannelPointClaimByState.remove(key);
      _processingChannelPointBonusByState[key]?.clear();
      _doneChannelPointBonusByState[key]?.clear();
      return;
    }

    final claimId = channelPoints.availableClaimId?.trim();
    if (claimId == null || claimId.isEmpty) return;

    final resolvedChannelId = channelPoints.channelId?.trim().isNotEmpty == true
        ? channelPoints.channelId!.trim()
        : channelId()?.trim();
    if (resolvedChannelId == null || resolvedChannelId.isEmpty) {
      _notifyAvailableChannelPointBonus(channelPoints);
      return;
    }

    final bonusKey = '${channelLogin()}:$claimId';
    final processing = _processingChannelPointBonusByState.putIfAbsent(
      key,
      () => <String>{},
    );
    final done = _doneChannelPointBonusByState.putIfAbsent(
      key,
      () => <String>{},
    );

    if (processing.contains(bonusKey) || done.contains(bonusKey)) return;

    processing.add(bonusKey);
    unawaited(
      _collectAvailableChannelPointBonus(
        stateKey: key,
        bonusKey: bonusKey,
        channelId: resolvedChannelId,
        claimId: claimId,
        channelPoints: channelPoints,
      ),
    );
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
    final pointName = name == null || name.isEmpty ? 'Channel Points' : name;

    try {
      final result = await engagementPort.claimCommunityPoints(
        channelId: channelId,
        claimId: claimId,
      );

      _doneChannelPointBonusByState
          .putIfAbsent(stateKey, () => <String>{})
          .add(bonusKey);

      final earned = result.pointsEarned > 0
          ? result.pointsEarned
          : fallbackPoints;
      twitchAppNotificationCenter.showSuccess(
        title: '已領取 $pointName',
        message: '${channelLogin()} +$earned',
        duration: const Duration(seconds: 5),
      );

      await refreshEngagement(showSnackOnError: false);
    } catch (error) {
      twitchAppNotificationCenter.showWarning(
        title: '$pointName 領取失敗',
        message: '${channelLogin()}：$error',
        duration: const Duration(seconds: 8),
      );
    } finally {
      _processingChannelPointBonusByState[stateKey]?.remove(bonusKey);
    }
  }

  void _notifyAvailableChannelPointBonus(
    TwitchChannelPointsRuntimeSnapshot? channelPoints,
  ) {
    if (channelPoints == null || !channelPoints.hasAvailableClaim) {
      _lastNotifiedChannelPointClaimByState.remove(hashCode);
      return;
    }

    final claimId = channelPoints.availableClaimId?.trim();
    if (claimId == null || claimId.isEmpty) return;

    final memoryKey = '${channelLogin()}:$claimId';
    if (_lastNotifiedChannelPointClaimByState[hashCode] == memoryKey) {
      return;
    }

    _lastNotifiedChannelPointClaimByState[hashCode] = memoryKey;

    final points = channelPoints.availableClaimPoints;
    final pointsText = points > 0 ? '$points' : 'Channel Points';
    final name = channelPoints.pointsName?.trim();
    final pointName = name == null || name.isEmpty ? 'Channel Points' : name;

    twitchAppNotificationCenter.showInfo(
      title: '可領取 $pointName',
      message: '${channelLogin()} 可領取 $pointsText',
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
    final previousBalance = _lastChannelPointBalanceByState[key];
    _lastChannelPointBalanceByState[key] = balance;

    if (!notifyBalanceDelta || previousBalance == null) return;
    final delta = balance - previousBalance;
    if (delta <= 0) return;

    final name = channelPoints.pointsName?.trim();
    final pointName = name == null || name.isEmpty ? 'Channel Points' : name;

    twitchAppNotificationCenter.showInfo(
      title: '$pointName 增加',
      message: '${channelLogin()} +$delta，目前 $balance',
      duration: const Duration(seconds: 5),
    );
  }

  void reset() {
    channelPointsSnapshot = null;
    prediction = null;
    pinnedMessages = const <dynamic>[];
    hypeTrainController.clear();
    engagementError = null;
    loadingEngagement = false;
    loadingEmotes = false;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final timer in _channelPointPollingTimerByState.values) {
      timer.cancel();
    }
    hypeTrainController.dispose();
    super.dispose();
  }
}
