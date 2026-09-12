import 'package:flutter/material.dart';

import '../../../models/special_actions/twitch_pending_special_message.dart';
import '../../../models/special_actions/twitch_viewer_special_message_models.dart';
import '../../localization/vioclass_localizations.dart';
import '../../sheets/twitch_special_message_sheet.dart';
import '../../widgets/chat/twitch_chat_input_emote_state.dart';
import '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension TwitchWatchPageChatMethods on TwitchWatchPageState {
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
        final badgeAppliedLabel = context.vio.t('已套用徽章');
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
        showSnack('$badgeAppliedLabel ${badge.title}');
        await refreshSpecialMessages(
          autoSelectPending: false,
          showSnackOnError: false,
        );
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
