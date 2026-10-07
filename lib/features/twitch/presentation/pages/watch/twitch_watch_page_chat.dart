import 'dart:async';
import 'package:flutter/material.dart';

import '../../../api/chat/twitch_chat_identity_api_service.dart';
import '../../../api/chat/twitch_chat_user_profile_api_service.dart';
import '../../../api/moderation/twitch_moderation_api_service.dart';
import '../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../models/chat/twitch_moderation_target_policy.dart';
import '../../../models/special_actions/twitch_pending_special_message.dart';
import '../../../models/special_actions/twitch_viewer_special_message_models.dart';
import '../../localization/vioclass_localizations.dart';
import '../../sheets/twitch_special_message_sheet.dart';
import '../../sheets/twitch_moderation_sheet.dart';
import '../../sheets/twitch_moderation_batch_sheet.dart';
import '../../sheets/twitch_chat_user_profile_sheet.dart';
import '../../settings/twitch_app_settings_launcher.dart';
import '../../widgets/chat/twitch_chat_input_emote_state.dart';
import '../../widgets/chat/message/twitch_moderation_message_actions.dart';
import '../../widgets/chat/message/twitch_user_moderation_controls.dart';
import '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

final _chatUserProfileOpen = Expando<bool>('chatUserProfileOpen');

extension TwitchWatchPageChatMethods on TwitchWatchPageState {
  Future<void> openChatUserProfile(TwitchChatRuntimeMessage message) async {
    final runtime = chatRuntime;
    final selectedChannel = channelLogin;
    final selectedViewer = viewerId;
    bool isCurrent() =>
        mounted &&
        chatRuntime == runtime &&
        channelLogin == selectedChannel &&
        viewerId == selectedViewer;
    if (!isCurrent() || runtime == null || _chatUserProfileOpen[this] == true) {
      return;
    }
    _chatUserProfileOpen[this] = true;
    try {
      final api = TwitchChatUserProfileApiService(
        client: watchServices.apiClient,
        tokenProviders: [
          authService.getValidAccessToken,
          watchServices.webGqlAuthService.getToken,
          watchServices.dropsAuthService.getToken,
        ],
        ownerId: selectedViewer,
        isCurrent: isCurrent,
      );
      final whisper = await showTwitchChatUserProfileSheet(
        context: context,
        message: message,
        messages: List.of(runtime.messages),
        viewerLogin: viewerLogin,
        messageActionBuilder: canManageChat
            ? (context, item) =>
                  buildUserRoleActions(item) ??
                  buildMessageModerationActions(context, item)
            : null,
        thirdPartyEmotes: watchServices.thirdPartyEmotes,
        officialEmotes: watchServices.officialEmotes,
        loadUser: () => api.getUser(
          login: message.userLogin,
          userId: message.source.tags['user-id'],
        ),
        canWhisper:
            selectedViewer != null &&
            selectedViewer.isNotEmpty &&
            message.source.tags['user-id'] != selectedViewer &&
            message.userLogin.toLowerCase() != viewerLogin?.toLowerCase(),
        moderationActions: canManageChat
            ? buildUserRoleActions(message) ??
                  buildMessageModerationActions(context, message)
            : null,
      );
      if (whisper != true || !isCurrent() || selectedViewer == null) return;
      try {
        await twitchAppSettingsLauncher.openWhisperTo(
          message.userLogin,
          ownerId: selectedViewer,
          peerId: message.source.tags['user-id'],
        );
      } catch (error) {
        if (isCurrent()) {
          showSnack(
            error is StateError ? error.message.toString() : '私訊暫時無法開啟。',
          );
        }
      }
    } finally {
      _chatUserProfileOpen[this] = false;
    }
  }

  Future<void> openChatTools() async {
    await openSpecialMessagesSheet();
  }

  Widget? buildUserRoleActions(TwitchChatRuntimeMessage message) {
    final api = createChatModerationApi();
    final userId = message.source.tags['user-id'] ?? '';
    if (api == null ||
        api.moderatorId != api.broadcasterId ||
        !RegExp(r'^\d+$').hasMatch(userId) ||
        userId == api.broadcasterId ||
        message.channel.replaceFirst('#', '').toLowerCase() !=
            channelLogin.toLowerCase() ||
        !TwitchModerationTargetPolicy.sameChannel(message, api.broadcasterId)) {
      return null;
    }
    return TwitchUserModerationControls(
      api: api,
      message: message,
      channelName: channelLogin,
    );
  }

  bool get canManageChat =>
      chatRuntime != null &&
      (chatRuntime!.viewerIsModerator ||
          (viewerId != null && channelId != null && viewerId == channelId));

  TwitchModerationApiService? createChatModerationApi() {
    final runtime = chatRuntime;
    if (!mounted || runtime == null || !canManageChat) return null;
    final targetChannel = channelLogin;
    final targetId = channelId ?? '';
    final targetModeratorId = viewerId ?? '';
    bool isCurrentModerationContext() =>
        mounted &&
        channelLogin == targetChannel &&
        channelId == targetId &&
        viewerId == targetModeratorId &&
        chatRuntime == runtime &&
        canManageChat;
    return TwitchModerationApiService(
      client: watchServices.apiClient,
      broadcasterId: targetId,
      moderatorId: targetModeratorId,
      canModerate: isCurrentModerationContext,
      onPinsLoaded: (pins) {
        if (isCurrentModerationContext()) {
          engagementController.applyModerationPins(targetId, pins);
        }
      },
      tokenProviders: [
        authService.getValidAccessToken,
        watchServices.webGqlAuthService.getToken,
        watchServices.dropsAuthService.getToken,
      ],
    );
  }

  Widget buildMessageModerationActions(
    BuildContext context,
    TwitchChatRuntimeMessage message,
  ) {
    final api = createChatModerationApi();
    if (api == null ||
        message.channel.replaceFirst('#', '').toLowerCase() !=
            channelLogin.toLowerCase()) {
      return const SizedBox.shrink();
    }
    final runtime = chatRuntime;
    return TwitchModerationMessageActions(
      api: api,
      message: message,
      channelName: channelLogin,
      canModerate: api.canModerate!,
      onOpenBatch: () async {
        if (runtime == null || !api.canModerate!()) return;
        await showTwitchModerationBatchSheet(
          context: context,
          api: api,
          messages: List.of(runtime.messages).reversed.toList(),
          channelName: channelLogin,
          canModerate: api.canModerate!,
          initialMessageId: message.source.tags['id'],
          canManageTarget: (id) =>
              api.canModerate!() &&
              TwitchModerationTargetPolicy.canManageVisibleUser(
                runtime.messages,
                id,
                broadcasterId: api.broadcasterId,
                moderatorId: api.moderatorId,
              ),
        );
      },
    );
  }

  Future<void> openChatModeration() async {
    final runtime = chatRuntime;
    final api = createChatModerationApi();
    if (api == null || runtime == null) return;
    syncModerationLogContext();
    await showTwitchModerationSheet(
      context: context,
      runtime: runtime,
      channelName: channelLogin,
      canModerate: api.canModerate!,
      api: api,
      logController: moderationLogController,
      onReconnectLog: () => syncModerationLogContext(force: true),
    );
  }

  void syncModerationLogContext({bool force = false}) {
    final api = createChatModerationApi();
    if (api == null || api.moderatorId.isEmpty || api.broadcasterId.isEmpty) {
      if (moderationLogContextKey != null) {
        moderationLogContextKey = null;
        moderationLogRuntime = null;
        moderationLogController.stop();
      }
      return;
    }
    final key = '${api.moderatorId}:${api.broadcasterId}:$channelLogin';
    if (!force &&
        key == moderationLogContextKey &&
        chatRuntime == moderationLogRuntime) {
      return;
    }
    moderationLogContextKey = key;
    moderationLogRuntime = chatRuntime;
    unawaited(moderationLogController.start(api));
  }

  Future<void> runDeferredChatStartup(String channel, int generation) async {
    try {
      final activeRuntime = chatController.runtime;
      final cleanChannel = channel.trim().toLowerCase();
      final canReuseRuntime =
          activeRuntime != null && activeRuntime.channelLogin == cleanChannel;
      if (canReuseRuntime) {
        // Foreground resume should keep the existing message list and IRC
        // runtime. If the socket survived, this is a no-op; if it dropped while
        // backgrounded, reconnect() preserves messages and skips recent-history
        // bootstrap instead of rebuilding the whole chat session.
        await chatController.reconnectAfterNetworkRestored();
      } else {
        await connectChat(channel);
      }
    } catch (error) {
      if (isCurrentWatchTask(generation, channel)) {
        showSnack('聊天室暫時連線失敗，稍後再試。');
      }
    } finally {
      if (isCurrentWatchTask(generation, channel)) {
        setState(() => chatBootstrapping = false);
      }
    }
  }

  Future<void> connectChat(String channel) {
    return chatController.connectChat(channel);
  }

  Future<void> sendMessage() async {
    final message = TwitchChatInputEmoteState.serialize(
      messageController,
    ).trim();
    if (message.isEmpty) return;

    try {
      await chatController.sendMessage(message);
      messageController.clear();
    } catch (error) {
      debugPrint('watch chat send failed: $error');
    }
  }

  Future<void> runDeferredSpecialMessagesStartup(
    int generation,
    String channel,
  ) async {
    await refreshSpecialMessages(
      generation: generation,
      channel: channel,
      autoSelectPending: true,
      showSnackOnError: false,
    );
  }

  Future<TwitchViewerSpecialMessagesSnapshotStage251?> refreshSpecialMessages({
    int? generation,
    String? channel,
    bool autoSelectPending = true,
    bool showSnackOnError = true,
  }) async {
    final targetChannel = channel ?? channelLogin;
    if (generation != null && !isCurrentWatchTask(generation, targetChannel)) {
      return null;
    }

    try {
      final snapshot = await chatController.loadSpecialMessages(
        targetChannel: targetChannel,
        autoSelectPending: autoSelectPending,
      );
      if (generation != null &&
          !isCurrentWatchTask(generation, targetChannel)) {
        return null;
      }
      return snapshot;
    } catch (error) {
      if (showSnackOnError) showSnack('特殊訊息暫時載入失敗，稍後再試。');
      return null;
    }
  }

  TwitchPendingSpecialMessage pendingFromWatchStreak(
    TwitchWatchStreakStatusStage251 status,
  ) {
    return chatController.pendingFromWatchStreak(status);
  }

  TwitchPendingSpecialMessage pendingFromResub(
    TwitchResubNotificationStage251 resub,
  ) {
    return chatController.pendingFromResub(resub);
  }

  Future<void> openSpecialMessagesSheet() async {
    final snapshot =
        specialMessagesSnapshot ??
        await refreshSpecialMessages(
          autoSelectPending: false,
          showSnackOnError: false,
        );
    if (!mounted) return;

    await showTwitchSpecialMessageSheetStage251(
      context: context,
      initialSnapshot: snapshot,
      loading: loadingSpecialMessages,
      viewerName: viewerLogin ?? 'You',
      initialColor: chatRuntime?.ircApi.currentUserColor ?? '',
      onOpenModeration: canManageChat ? openChatModeration : null,
      onSetColor: (color) async {
        final id = viewerId;
        if (id == null || id.isEmpty) {
          throw const TwitchChatColorException('請先登入 Twitch 再修改 ID 顏色。');
        }
        await TwitchChatIdentityApiService(
          client: watchServices.apiClient,
          tokenProviders: [
            authService.getValidAccessToken,
            watchServices.webGqlAuthService.getToken,
            watchServices.dropsAuthService.getToken,
          ],
        ).updateColor(userId: id, color: color);
      },
      onRefresh: () => refreshSpecialMessages(
        autoSelectPending: false,
        showSnackOnError: true,
      ),
      onShareWatchStreak: (status) {
        chatController.setPendingSpecialMessage(pendingFromWatchStreak(status));
      },
      onShareResub: (resub) {
        chatController.setPendingSpecialMessage(pendingFromResub(resub));
        final defaultMessage = resub.defaultMessage?.trim();
        if (messageController.text.trim().isEmpty &&
            defaultMessage != null &&
            defaultMessage.isNotEmpty) {
          messageController.text = defaultMessage;
        }
      },
      onSelectBadge: (badge) async {
        final badgeSubmittedLabel = context.vio.t('徽章套用已提交');
        final result = await watchServices.specialMessagesStage251.runtime
            .updateChatIdentity(
              channelLogin: channelLogin,
              channelId: channelId,
              viewerId: viewerId,
              badge: badge,
            );
        if (!result.ok) {
          showSnack('聊天身分暫時無法更新，請稍後再試。');
          return false;
        }
        showSnack('$badgeSubmittedLabel ${badge.title}');
        return true;
      },
    );
  }

  void setPendingSpecialMessage(TwitchPendingSpecialMessage pending) {
    chatController.setPendingSpecialMessage(pending);
  }

  void clearPendingSpecialMessage() {
    chatController.clearPendingSpecialMessage();
  }

  void toggleChatVisibility() {
    preferencesController.toggleChatVisibility();
  }

  void insertMessageText(String text) {
    final emote = TwitchChatInputEmotePayload.tryDecode(text);
    if (emote != null) {
      TwitchChatInputEmoteState.insert(
        messageController,
        emote,
        appendSpace: true,
      );
      return;
    }

    final current = messageController.text;
    final selection = messageController.selection;
    final start = selection.start < 0 ? current.length : selection.start;
    final end = selection.end < 0 ? current.length : selection.end;
    final next = current.replaceRange(start, end, text);
    messageController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }
}
