import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../api/auth/twitch_auth_api_service.dart';
import '../../../api/chat/twitch_irc_api_service.dart';
import '../../../api/chat/twitch_recent_messages_api_service.dart';
import '../../../models/special_actions/twitch_pending_special_message.dart';
import '../../../models/special_actions/twitch_viewer_special_message_models.dart';
import '../../../services/auth/twitch_auth_service.dart';
import '../../../services/auth/twitch_drops_auth_service.dart';
import '../../../services/chat/twitch_badge_cache_service.dart';
import '../../../services/chat/twitch_chat_runtime.dart';
import '../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../../services/engagement/twitch_prediction_hermes_runtime_service.dart';
import '../../../services/special_actions/twitch_viewer_special_message_runtime.dart';
import '../twitch_watch_feature_ports.dart';

class TwitchWatchChatController extends ChangeNotifier {
  final TwitchAuthService authService;
  final TwitchDropsAuthService dropsAuthService;
  final TwitchAuthApiService authApi;
  final TwitchRecentMessagesApiService recentMessagesApi;
  final TwitchWatchChatPort chatPort;
  final TwitchWatchEngagementPort engagementPort;
  final TwitchViewerSpecialMessageRuntimeStage251 specialMessagesRuntime;
  final String Function() channelLogin;
  final String? Function() channelId;
  final String? Function() viewerId;
  final TwitchChannelPointsRuntimeSnapshot? Function() channelPointsSnapshot;
  final Future<void> Function({bool showSnackOnError}) refreshEngagement;
  final Future<void> Function({bool autoSelectPending}) refreshSpecialMessages;
  final void Function(String channelId) onChannelIdResolved;
  final void Function(String? viewerLogin, String? viewerId) onViewerResolved;
  final void Function(String message) showMessage;

  TwitchChatRuntime? runtime;
  bool connectingChat = false;
  bool sending = false;
  String? viewerLogin;
  String? resolvedViewerId;
  TwitchPendingSpecialMessage? pendingSpecialMessage;
  TwitchViewerSpecialMessagesSnapshotStage251? specialMessagesSnapshot;
  bool loadingSpecialMessages = false;
  StreamSubscription<TwitchCommunityRedemptionEvent>? _redemptionSubscription;

  TwitchWatchChatController({
    required this.authService,
    required this.dropsAuthService,
    required this.authApi,
    required this.recentMessagesApi,
    required this.chatPort,
    required this.engagementPort,
    required this.specialMessagesRuntime,
    required this.channelLogin,
    required this.channelId,
    required this.viewerId,
    required this.channelPointsSnapshot,
    required this.refreshEngagement,
    required this.refreshSpecialMessages,
    required this.onChannelIdResolved,
    required this.onViewerResolved,
    required this.showMessage,
  });

  Future<void> connectChat(String channel) async {
    connectingChat = true;
    notifyListeners();
    try {
      await runtime?.disposeRuntime();

      final token = await authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw StateError('Missing OAuth token for chat connection.');
      }

      await dropsAuthService.loadStoredSession();
      final validation = await authApi.validateToken(token);
      final startup = await chatPort.fetchStartupSnapshot(
        channelLogin: channel,
      );
      final nextRuntime = TwitchChatRuntime(
        ircApi: TwitchIrcApiService(),
        writeIrcApi: TwitchIrcApiService(),
        badgeCache: TwitchBadgeCacheService(),
        recentMessagesApi: recentMessagesApi,
      );

      runtime = nextRuntime;
      _ensureRedemptionSubscription();
      viewerLogin = validation.login;
      resolvedViewerId = validation.userId;
      onViewerResolved(viewerLogin, resolvedViewerId);
      onChannelIdResolved(startup.channelId);
      notifyListeners();

      await nextRuntime.connect(
        channelLogin: channel,
        accessToken: token,
        ircNick: validation.login,
        viewerLogin: validation.login,
        viewerDisplayName: validation.login,
        viewerUserId: validation.userId,
        badgeCatalog: startup.badgeCatalog,
        preloadRecentMessages: true,
        recentMessageLimit: 100,
      );
    } finally {
      connectingChat = false;
      notifyListeners();
    }
  }

  void _ensureRedemptionSubscription() {
    _redemptionSubscription ??= TwitchPredictionHermesRealtimeBus
        .redemptionStream
        .listen(_handleCommunityRedemption);
  }

  void _handleCommunityRedemption(TwitchCommunityRedemptionEvent redemption) {
    final activeRuntime = runtime;
    if (activeRuntime == null) return;

    final activeChannelId = channelId()?.trim();
    final eventChannelId = redemption.channelId?.trim();
    if (activeChannelId != null &&
        activeChannelId.isNotEmpty &&
        eventChannelId != null &&
        eventChannelId.isNotEmpty &&
        activeChannelId != eventChannelId) {
      return;
    }

    if (redemption.isInputRequired && redemption.userInput.trim().isNotEmpty) {
      return;
    }

    activeRuntime.injectRedemptionMessage(redemption);
  }

  Future<void> sendMessage(String message) async {
    if (sending) return;
    final activeRuntime = runtime;
    if (activeRuntime == null || !activeRuntime.connected) {
      showMessage('聊天室尚未連線');
      return;
    }

    if (message.trim().isEmpty) return;
    final pending = pendingSpecialMessage;
    if (pending != null) {
      await sendPendingSpecialMessage(pending, message);
      return;
    }

    sending = true;
    notifyListeners();
    try {
      await activeRuntime.sendMessage(message);
    } catch (error) {
      showMessage('送出失敗：$error');
      rethrow;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> sendPendingSpecialMessage(
    TwitchPendingSpecialMessage pending,
    String message,
  ) async {
    sending = true;
    notifyListeners();
    try {
      switch (pending.kind) {
        case TwitchPendingSpecialMessageKind.highlightedMessage:
        case TwitchPendingSpecialMessageKind.channelPointRewardMessage:
          await _sendPendingChannelPointTextReward(pending, message);
          break;
        case TwitchPendingSpecialMessageKind.watchStreak:
          await _sendPendingWatchStreak(pending, message);
          break;
        case TwitchPendingSpecialMessageKind.resub:
          await _sendPendingResub(pending, message);
          break;
        case TwitchPendingSpecialMessageKind.preview:
        case TwitchPendingSpecialMessageKind.officialSpecialMessage:
          showMessage('預覽訊息：${pending.describeForLog(message: message)}');
          break;
      }
      clearPendingSpecialMessage();
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> _sendPendingChannelPointTextReward(
    TwitchPendingSpecialMessage pending,
    String message,
  ) async {
    final reward = pending.payload['reward'];
    if (reward is! Map<String, dynamic>) {
      throw StateError('Missing reward payload.');
    }

    final snapshot = channelPointsSnapshot();
    final resolvedChannelId = pending.channelId?.trim().isNotEmpty == true
        ? pending.channelId!.trim()
        : snapshot?.channelId ?? channelId();
    if (resolvedChannelId == null || resolvedChannelId.isEmpty) {
      throw StateError('Missing channelId for channel point reward.');
    }

    final result = await engagementPort.redeemReward(
      channelId: resolvedChannelId,
      reward: reward,
      textInput: message,
    );

    showMessage('已兌換 ${result.title}');
    await refreshEngagement(showSnackOnError: false);
  }

  Future<void> _sendPendingWatchStreak(
    TwitchPendingSpecialMessage pending,
    String message,
  ) async {
    final status = pending.payload['watchStreak'];
    if (status is! TwitchWatchStreakStatusStage251) {
      throw StateError('Missing watch streak payload.');
    }

    final result = await specialMessagesRuntime.shareWatchStreak(
      channelLogin: pending.channelLogin,
      channelId: pending.channelId ?? channelId(),
      viewerId: viewerId(),
      status: status,
      message: message,
    );
    if (!result.ok) {
      throw StateError(
        result.error?.toString() ?? 'Watch streak share failed.',
      );
    }
    showMessage(
      '已分享 Watch Streak ${status.streakCount ?? ''}${status.unitLabel}',
    );
    await refreshSpecialMessages(autoSelectPending: false);
  }

  Future<void> _sendPendingResub(
    TwitchPendingSpecialMessage pending,
    String message,
  ) async {
    final resub = pending.payload['resub'];
    if (resub is! TwitchResubNotificationStage251) {
      throw StateError('Missing resub payload.');
    }

    final result = await specialMessagesRuntime.useResubToken(
      channelLogin: pending.channelLogin,
      channelId: pending.channelId ?? channelId(),
      viewerId: viewerId(),
      resub: resub,
      message: message,
    );
    if (!result.ok) {
      throw StateError(result.error?.toString() ?? 'Resub share failed.');
    }
    showMessage('已分享訂閱 ${resub.cumulativeMonths ?? ''} 個月');
    await refreshSpecialMessages(autoSelectPending: false);
  }

  Future<TwitchViewerSpecialMessagesSnapshotStage251?> loadSpecialMessages({
    required String targetChannel,
    bool autoSelectPending = true,
  }) async {
    loadingSpecialMessages = true;
    notifyListeners();
    try {
      final snapshot = await specialMessagesRuntime.load(
        channelLogin: targetChannel,
        channelId: channelId(),
        viewerId: viewerId(),
      );
      specialMessagesSnapshot = snapshot;
      if (autoSelectPending &&
          (pendingSpecialMessage == null ||
              pendingSpecialMessage!.kind ==
                  TwitchPendingSpecialMessageKind.watchStreak ||
              pendingSpecialMessage!.kind ==
                  TwitchPendingSpecialMessageKind.resub)) {
        pendingSpecialMessage = pendingFromSpecialMessages(snapshot);
      }
      notifyListeners();
      return snapshot;
    } finally {
      loadingSpecialMessages = false;
      notifyListeners();
    }
  }

  TwitchPendingSpecialMessage? pendingFromSpecialMessages(
    TwitchViewerSpecialMessagesSnapshotStage251 snapshot,
  ) {
    final resub = snapshot.resub;
    if (resub != null && resub.canShare) return pendingFromResub(resub);

    final watchStreak = snapshot.watchStreak;
    if (watchStreak != null && watchStreak.canShare) {
      return pendingFromWatchStreak(watchStreak);
    }

    return null;
  }

  TwitchPendingSpecialMessage pendingFromWatchStreak(
    TwitchWatchStreakStatusStage251 status,
  ) {
    final count = status.streakCount;
    return TwitchPendingSpecialMessage(
      kind: TwitchPendingSpecialMessageKind.watchStreak,
      channelLogin: channelLogin(),
      channelId: channelId() ?? status.channelId,
      title: count == null ? '分享連續觀看' : '連續觀看 $count${status.unitLabel}',
      subtitle: '送出訊息並分享 Watch Streak。',
      sendLabel: '分享',
      costLabel: count == null ? null : '$count${status.unitLabel}',
      payload: <String, dynamic>{'watchStreak': status},
    );
  }

  TwitchPendingSpecialMessage pendingFromResub(
    TwitchResubNotificationStage251 resub,
  ) {
    final months = resub.cumulativeMonths;
    return TwitchPendingSpecialMessage(
      kind: TwitchPendingSpecialMessageKind.resub,
      channelLogin: channelLogin(),
      channelId: channelId() ?? resub.channelId,
      title: months == null ? '分享訂閱訊息' : '訂閱 $months 個月',
      subtitle: '送出訊息並分享 Resub 訊息。',
      sendLabel: '分享',
      costLabel: months == null ? null : '$months 個月',
      payload: <String, dynamic>{'resub': resub},
    );
  }

  void setPreviewPendingSpecialMessage() {
    pendingSpecialMessage = TwitchPendingSpecialMessage(
      kind: TwitchPendingSpecialMessageKind.preview,
      channelLogin: channelLogin(),
      channelId: channelId(),
      title: '特殊訊息預覽',
      subtitle: '預覽模式不會送出 Twitch 特殊訊息。',
      costLabel: '預覽',
      previewOnly: true,
    );
    notifyListeners();
  }

  void setPendingSpecialMessage(TwitchPendingSpecialMessage pending) {
    pendingSpecialMessage = pending;
    notifyListeners();
  }

  void clearPendingSpecialMessage() {
    if (pendingSpecialMessage == null) return;
    pendingSpecialMessage = null;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await runtime?.disconnect();
  }

  Future<void> disposeRuntime() async {
    final activeRuntime = runtime;
    runtime = null;
    notifyListeners();
    if (activeRuntime != null) {
      await activeRuntime.disposeRuntime();
    }
  }

  void resetSpecialMessages() {
    specialMessagesSnapshot = null;
    pendingSpecialMessage = null;
    loadingSpecialMessages = false;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(disposeRuntime());
    unawaited(_redemptionSubscription?.cancel());
    super.dispose();
  }
}
