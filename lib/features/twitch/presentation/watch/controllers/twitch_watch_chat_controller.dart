import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../api/auth/twitch_auth_api_service.dart';
import '../../../api/chat/twitch_irc_api_service.dart';
import '../../../api/chat/twitch_recent_messages_api_service.dart';
import '../../../models/chat/twitch_chat_startup.dart';
import '../../../models/special_actions/twitch_pending_special_message.dart';
import '../../../models/special_actions/twitch_viewer_special_message_models.dart';
import '../../../parsers/chat/twitch_recent_message_parser.dart';
import '../../../services/auth/twitch_auth_service.dart';
import '../../../services/auth/twitch_viewer_session.dart';
import '../../../services/auth/twitch_drops_auth_service.dart';
import '../../../services/chat/twitch_badge_cache_service.dart';
import '../../../services/chat/twitch_chat_runtime.dart';
import '../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../../services/engagement/twitch_prediction_hermes_runtime_service.dart';
import '../../../services/special_actions/twitch_viewer_special_message_runtime.dart';
import '../twitch_watch_feature_ports.dart';

typedef TwitchWatchChatRuntimeFactory =
    TwitchChatRuntime Function({required bool authenticated});

class TwitchWatchChatController extends ChangeNotifier {
  final TwitchWatchChatRuntimeFactory? runtimeFactory;
  bool _disposed = false;
  int _connectionGeneration = 0;
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
  String? _connectedToken;
  bool sending = false;
  String? viewerLogin;
  String? resolvedViewerId;
  TwitchPendingSpecialMessage? pendingSpecialMessage;
  TwitchViewerSpecialMessagesSnapshotStage251? specialMessagesSnapshot;
  bool loadingSpecialMessages = false;
  StreamSubscription<TwitchCommunityRedemptionEvent>? _redemptionSubscription;
  StreamSubscription<TwitchChatSendRejection>? _sendRejectionSubscription;

  bool get isReadOnlyGuest =>
      TwitchViewerSession.forAuth(authService).status ==
      TwitchViewerStatus.guest;

  bool get _hasConnectedViewer {
    final identity = TwitchViewerSession.forAuth(authService).snapshot;
    return !connectingChat &&
        !_disposed &&
        identity != null &&
        identity.accessToken == _connectedToken;
  }

  bool get hasIrcSendPermission {
    final identity = TwitchViewerSession.forAuth(authService).snapshot;
    return identity != null &&
        identity.scopes.contains('chat:read') &&
        identity.scopes.contains('chat:edit');
  }

  bool get canSendForCurrentViewer =>
      _hasConnectedViewer &&
      (pendingSpecialMessage != null || hasIrcSendPermission);

  bool get hasCurrentViewer => _hasConnectedViewer;

  TwitchWatchChatController({
    this.runtimeFactory,
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
    if (_disposed) return;
    final generation = ++_connectionGeneration;
    bool isCurrent() => !_disposed && generation == _connectionGeneration;
    sending = false;
    connectingChat = true;
    notifyListeners();
    try {
      await _sendRejectionSubscription?.cancel();
      if (!isCurrent()) return;
      _sendRejectionSubscription = null;
      await runtime?.disposeRuntime();
      if (!isCurrent()) return;
      runtime = null;

      final identity = await TwitchViewerSession.forAuth(
        authService,
      ).resolve(authApi);
      if (!isCurrent()) return;
      if (identity == null &&
          TwitchViewerSession.forAuth(authService).status !=
              TwitchViewerStatus.guest) {
        return;
      }
      final token = identity?.accessToken;
      // Account identity is independent from the public IRC read transport.
      // A token lacking chat:read cannot authenticate that connection.
      final ircToken = identity?.scopes.contains('chat:read') == true
          ? token
          : null;
      final authenticatedLogin = identity?.viewerLogin;
      final authenticatedViewerId = identity?.viewerId;

      _connectedToken = token;
      viewerLogin = authenticatedLogin;
      resolvedViewerId = authenticatedViewerId;
      onViewerResolved(viewerLogin, resolvedViewerId);

      final startupFuture = _fetchStartupSupplement(channel);
      final nextRuntime =
          runtimeFactory?.call(authenticated: ircToken != null) ??
          TwitchChatRuntime(
            ircApi: TwitchIrcApiService(),
            writeIrcApi: ircToken == null ? null : TwitchIrcApiService(),
            badgeCache: TwitchBadgeCacheService(),
            recentMessagesApi: recentMessagesApi,
            maxMessages: 900,
          );

      runtime = nextRuntime;
      Future<bool> discardChangedIdentity() async {
        final viewer = TwitchViewerSession.forAuth(authService);
        final sameIdentity = identity == null
            ? viewer.status == TwitchViewerStatus.guest
            : identical(viewer.snapshot, identity);
        if (sameIdentity) return false;
        if (!isCurrent() || !identical(runtime, nextRuntime)) return true;
        viewerLogin = null;
        resolvedViewerId = null;
        final cleanup = disposeRuntime();
        // disposeRuntime invalidates this generation synchronously. A newer
        // connect may already have started from its notification callback.
        if (!_disposed && _connectionGeneration == generation + 1) {
          onViewerResolved(null, null);
        }
        await cleanup;
        return true;
      }

      _sendRejectionSubscription = nextRuntime.sendRejections.listen((
        rejection,
      ) {
        showMessage('訊息未送出：${_sendRejectionReason(rejection)}');
      });
      if (token != null) {
        await dropsAuthService.loadStoredSession();
        if (!isCurrent()) return;
        if (await discardChangedIdentity()) return;
        if (!isCurrent()) return;
        _ensureRedemptionSubscription();
      }
      notifyListeners();
      if (!isCurrent()) return;
      // A listener can synchronously change the account during notification.
      final currentViewer = TwitchViewerSession.forAuth(authService);
      if (identity == null
          ? currentViewer.status != TwitchViewerStatus.guest
          : !identical(currentViewer.snapshot, identity)) {
        await discardChangedIdentity();
        return;
      }

      await nextRuntime.connect(
        channelLogin: channel,
        accessToken: ircToken,
        ircNick: ircToken == null ? 'justinfan12345' : authenticatedLogin,
        viewerLogin: authenticatedLogin,
        viewerDisplayName: authenticatedLogin,
        viewerUserId: authenticatedViewerId,
        preloadRecentMessages: true,
        recentMessageLimit: 700,
      );
      if (!isCurrent()) return;
      if (await discardChangedIdentity()) return;
      if (!isCurrent()) return;
      unawaited(
        _applyStartupSupplement(
          runtime: nextRuntime,
          channel: channel,
          startupFuture: startupFuture,
          expectedIdentity: identity,
        ),
      );
    } finally {
      if (isCurrent()) {
        connectingChat = false;
        notifyListeners();
      }
    }
  }

  Future<TwitchChatStartupSnapshot?> _fetchStartupSupplement(
    String channel,
  ) async {
    TwitchChatStartupSnapshot? partialSnapshot;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final snapshot = await chatPort
            .fetchStartupSnapshot(channelLogin: channel)
            .timeout(const Duration(seconds: 7));
        partialSnapshot = snapshot;
        if (snapshot.channelId.trim().isNotEmpty) return snapshot;
      } catch (error) {
        debugPrint(
          'watch chat GQL supplement attempt ${attempt + 1} failed: $error',
        );
      }

      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
    }

    return partialSnapshot;
  }

  Future<void> _applyStartupSupplement({
    required TwitchChatRuntime runtime,
    required String channel,
    required Future<TwitchChatStartupSnapshot?> startupFuture,
    required TwitchViewerAuthSnapshot? expectedIdentity,
  }) async {
    final startup = await startupFuture;
    if (startup == null || this.runtime != runtime) return;
    final viewer = TwitchViewerSession.forAuth(authService);
    if (expectedIdentity == null
        ? viewer.status != TwitchViewerStatus.guest
        : !identical(viewer.snapshot, expectedIdentity)) {
      return;
    }

    final startupRecentMessages = const TwitchRecentMessageParser()
        .parseMessagesField(
          messagesField: startup.recentMessages,
          channelLogin: channel,
        );
    runtime.applyStartupSupplement(
      badgeCatalog: startup.badgeCatalog,
      fallbackRecentMessages: startupRecentMessages.messages,
    );

    final resolvedChannelId = startup.channelId.trim();
    if (resolvedChannelId.isNotEmpty) {
      onChannelIdResolved(resolvedChannelId);
    }
  }

  void _ensureRedemptionSubscription() {
    _redemptionSubscription ??= TwitchPredictionHermesRealtimeBus
        .redemptionStream
        .listen(_handleCommunityRedemption);
  }

  String _sendRejectionReason(TwitchChatSendRejection rejection) {
    return switch (rejection.messageId.trim().toLowerCase()) {
      'msg_slowmode' => '目前是慢速模式，請稍後再發言。',
      'msg_ratelimit' => '發言速度太快，請稍後再試。',
      'msg_duplicate' => '訊息與上一則太相似，請修改後再送出。',
      'msg_banned' => '你已被此聊天室封鎖。',
      'msg_timedout' => '你目前被暫時禁言。',
      'msg_emoteonly' => '目前僅能傳送表情。',
      'msg_subsonly' => '目前僅限訂閱者發言。',
      'msg_followersonly' ||
      'msg_followersonly_followed' ||
      'msg_followersonly_zero' => '尚未符合此聊天室的追隨條件。',
      'msg_r9k' => '目前是唯一訊息模式，請勿重複相同內容。',
      'msg_verified_email' => '需要先完成 Twitch 電子郵件驗證。',
      'msg_requires_verified_phone_number' => '需要先完成 Twitch 手機號碼驗證。',
      'msg_channel_blocked' || 'msg_suspended' => '目前沒有在此聊天室發言的權限。',
      'msg_rejected' || 'msg_rejected_mandatory' => '訊息不符合聊天室規則。',
      _ =>
        rejection.reason.trim().isEmpty
            ? 'Twitch 拒絕了這則訊息。'
            : rejection.reason.trim(),
    };
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

  Future<bool> sendMessage(String message) async {
    if (_disposed || sending) return false;
    if (isReadOnlyGuest) {
      showMessage('目前是訪客唯讀聊天室，登入 Twitch 後才能發言。');
      return false;
    }
    if (!_hasConnectedViewer) {
      showMessage('登入狀態或聊天室連線尚未準備完成，請稍後再試。');
      return false;
    }
    final activeRuntime = runtime;
    if (activeRuntime == null || !activeRuntime.connected) {
      showMessage('聊天室尚未連線');
      return false;
    }

    if (message.trim().isEmpty) return false;
    final pending = pendingSpecialMessage;
    if (pending != null) {
      return sendPendingSpecialMessage(pending, message);
    }
    if (!hasIrcSendPermission) {
      showMessage('目前帳號缺少聊天室發言權限，請重新授權。');
      return false;
    }

    final generation = _connectionGeneration;
    final identity = TwitchViewerSession.forAuth(authService).snapshot;
    bool ownsSend() =>
        !_disposed &&
        generation == _connectionGeneration &&
        identical(runtime, activeRuntime);
    bool sameIdentity() =>
        identical(TwitchViewerSession.forAuth(authService).snapshot, identity);
    sending = true;
    try {
      notifyListeners();
      if (!ownsSend() || !sameIdentity()) return false;
      await activeRuntime.sendMessage(message);
      return ownsSend() && sameIdentity();
    } catch (error) {
      if (ownsSend() && sameIdentity()) {
        showMessage('聊天室訊息送出失敗，請稍後再試。');
      }
      rethrow;
    } finally {
      if (ownsSend()) {
        sending = false;
        notifyListeners();
      }
    }
  }

  Future<bool> sendPendingSpecialMessage(
    TwitchPendingSpecialMessage pending,
    String message,
  ) async {
    if (_disposed || sending) return false;
    if (!_hasConnectedViewer) {
      showMessage('登入狀態或聊天室連線尚未準備完成，請稍後再試。');
      return false;
    }
    final generation = _connectionGeneration;
    final activeRuntime = runtime;
    final identity = TwitchViewerSession.forAuth(authService).snapshot;
    bool ownsSend() =>
        !_disposed &&
        generation == _connectionGeneration &&
        identical(runtime, activeRuntime);
    bool isCurrent() =>
        ownsSend() &&
        identical(
          TwitchViewerSession.forAuth(authService).snapshot,
          identity,
        ) &&
        identical(pendingSpecialMessage, pending);
    sending = true;
    try {
      notifyListeners();
      if (!isCurrent()) return false;
      switch (pending.kind) {
        case TwitchPendingSpecialMessageKind.highlightedMessage:
        case TwitchPendingSpecialMessageKind.channelPointRewardMessage:
          await _sendPendingChannelPointTextReward(pending, message, isCurrent);
          break;
        case TwitchPendingSpecialMessageKind.watchStreak:
          await _sendPendingWatchStreak(pending, message, isCurrent);
          break;
        case TwitchPendingSpecialMessageKind.resub:
          await _sendPendingResub(pending, message, isCurrent);
          break;
        case TwitchPendingSpecialMessageKind.preview:
        case TwitchPendingSpecialMessageKind.officialSpecialMessage:
          showMessage('預覽訊息：${pending.describeForLog(message: message)}');
          break;
      }
      if (!isCurrent()) return false;
      clearPendingSpecialMessage();
      return true;
    } catch (error) {
      if (isCurrent()) {
        showMessage('特殊訊息送出失敗，請稍後再試。');
      }
      rethrow;
    } finally {
      if (ownsSend()) {
        sending = false;
        notifyListeners();
      }
    }
  }

  Future<void> _sendPendingChannelPointTextReward(
    TwitchPendingSpecialMessage pending,
    String message,
    bool Function() isCurrent,
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

    if (!isCurrent()) return;
    showMessage('已兌換 ${result.title}');
    if (isCurrent()) await refreshEngagement(showSnackOnError: false);
  }

  Future<void> _sendPendingWatchStreak(
    TwitchPendingSpecialMessage pending,
    String message,
    bool Function() isCurrent,
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
      throw StateError(result.error?.toString() ?? '連續觀看分享失敗。');
    }
    if (!isCurrent()) return;
    showMessage('已分享連續觀看 ${status.streakCount ?? ''}${status.unitLabel}');
    if (isCurrent()) await refreshSpecialMessages(autoSelectPending: false);
  }

  Future<void> _sendPendingResub(
    TwitchPendingSpecialMessage pending,
    String message,
    bool Function() isCurrent,
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
      throw StateError(result.error?.toString() ?? '續訂訊息分享失敗。');
    }
    if (!isCurrent()) return;
    showMessage('已分享訂閱 ${resub.cumulativeMonths ?? ''} 個月');
    if (isCurrent()) await refreshSpecialMessages(autoSelectPending: false);
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
      subtitle: '送出訊息並分享連續觀看。',
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
      subtitle: '送出訊息並分享續訂訊息。',
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

  Future<void> reconnectAfterNetworkRestored() async {
    if (_disposed) return;
    final activeRuntime = runtime;
    if (activeRuntime == null ||
        activeRuntime.connected ||
        activeRuntime.connecting ||
        connectingChat) {
      return;
    }

    // A runtime retains the identity used for its previous connection. Rebind
    // through the normal session-aware startup after logout/account changes;
    // reconnecting it directly would reuse the old account's IRC transport.
    final viewer = TwitchViewerSession.forAuth(authService);
    if (viewer.status == TwitchViewerStatus.checking) {
      return;
    }
    final sameViewer = viewer.status == TwitchViewerStatus.guest
        ? _connectedToken == null
        : viewer.snapshot != null &&
            viewer.snapshot!.accessToken == _connectedToken;
    if (!sameViewer) {
      await connectChat(channelLogin());
      return;
    }

    final generation = ++_connectionGeneration;
    final recoveryIdentity = viewer.snapshot;
    final recoveryStatus = viewer.status;
    final recoveryChannel = channelLogin();
    bool isCurrentRecovery() =>
        !_disposed &&
        generation == _connectionGeneration &&
        identical(runtime, activeRuntime) &&
        channelLogin() == recoveryChannel &&
        viewer.status == recoveryStatus &&
        identical(viewer.snapshot, recoveryIdentity);
    connectingChat = true;
    notifyListeners();
    try {
      await activeRuntime.reconnect();
      if (isCurrentRecovery() && activeRuntime.error != null) {
        showMessage('聊天室暫時連線失敗，稍後再試。');
      }
    } catch (_) {
      if (isCurrentRecovery()) {
        showMessage('聊天室暫時連線失敗，稍後再試。');
      }
    } finally {
      if (!_disposed &&
          generation == _connectionGeneration &&
          identical(runtime, activeRuntime)) {
        connectingChat = false;
        notifyListeners();
      }
    }
  }

  Future<void> disposeRuntime() async {
    _connectionGeneration++;
    sending = false;
    connectingChat = false;
    _connectedToken = null;
    final rejectionSubscription = _sendRejectionSubscription;
    _sendRejectionSubscription = null;
    final activeRuntime = runtime;
    runtime = null;
    if (!_disposed) notifyListeners();
    await rejectionSubscription?.cancel();
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
    _disposed = true;
    unawaited(disposeRuntime());
    unawaited(_redemptionSubscription?.cancel());
    super.dispose();
  }
}
