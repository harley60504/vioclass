import 'package:flutter/material.dart';

import '../../../models/special_actions/twitch_pending_special_message.dart';
import '../../../models/special_actions/twitch_viewer_special_message_models.dart';
import '../../sheets/twitch_special_message_sheet.dart';
import '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension TwitchWatchPageChatMethods on TwitchWatchPageState {
  Future<void> runDeferredChatStartup(String channel, int generation) async {
    try {
      await connectChat(channel);
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
    final message = messageController.text.trim();
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
        showSnack('已套用徽章 ${badge.title}');
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
