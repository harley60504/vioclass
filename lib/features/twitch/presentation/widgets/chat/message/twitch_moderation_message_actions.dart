import 'package:flutter/material.dart';

import '../../../../api/moderation/twitch_moderation_api_service.dart';
import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../../models/chat/twitch_chat_moderation_shortcut.dart';
import '../../../../models/chat/twitch_moderation_target_policy.dart';
import '../../../localization/vioclass_localizations.dart';
import '../../../sheets/twitch_pinned_chat_management_sheet.dart';

Future<void> showTwitchModerationShortcut({
  required BuildContext context,
  required TwitchModerationApiService api,
  required TwitchChatRuntimeMessage message,
  required String channelName,
  required bool Function() canModerate,
  required TwitchChatModerationShortcut action,
}) {
  if (!canModerate()) return Future<void>.value();
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        '${context.vio.t(action.actionLabel)} · ${message.displayName}',
      ),
      scrollable: true,
      content: TwitchModerationMessageActions(
        api: api,
        message: message,
        channelName: channelName,
        canModerate: canModerate,
        initialAction: action,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.vio.t('關閉')),
        ),
      ],
    ),
  );
}

/// Same controls for message context and user-history cards on both platforms.
class TwitchModerationMessageActions extends StatefulWidget {
  final TwitchModerationApiService api;
  final TwitchChatRuntimeMessage message;
  final String channelName;
  final bool Function() canModerate;
  final bool? currentModeratorStatus;
  final Future<void> Function()? onOpenBatch;
  final TwitchChatModerationShortcut? initialAction;
  const TwitchModerationMessageActions({
    super.key,
    required this.api,
    required this.message,
    required this.channelName,
    required this.canModerate,
    this.currentModeratorStatus,
    this.onOpenBatch,
    this.initialAction,
  });
  @override
  State<TwitchModerationMessageActions> createState() => _ActionsState();
}

class _ActionsState extends State<TwitchModerationMessageActions> {
  bool _busy = false;
  bool _confirming = false;
  bool _initialScheduled = false;
  String? _result;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialScheduled && widget.initialAction != null) {
      _initialScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _action(widget.initialAction!.actionLabel);
      });
    }
  }

  Future<void> _action(String action) async {
    if (_busy || _confirming || !widget.canModerate()) return;
    if (action == '批次選取訊息') {
      await widget.onOpenBatch?.call();
      return;
    }
    if (action == '釘選管理') {
      await showTwitchPinnedChatManagementSheet(
        context: context,
        api: widget.api,
        channelName: widget.channelName,
        selectedMessage: widget.message,
      );
      return;
    }
    final reason = TextEditingController();
    final duration = TextEditingController(text: '600');
    final form = GlobalKey<FormState>();
    final message = widget.message;
    final api = widget.api;
    final canModerate = widget.canModerate;
    final channelName = widget.channelName;
    if (action == '刪除訊息'
        ? !TwitchModerationTargetPolicy.canDelete(message, api.broadcasterId)
        : !TwitchModerationTargetPolicy.canManageUser(
            message,
            broadcasterId: api.broadcasterId,
            moderatorId: api.moderatorId,
            currentModeratorStatus: widget.currentModeratorStatus,
          )) {
      reason.dispose();
      duration.dispose();
      return;
    }
    final target = message.source.tags['user-id'] ?? '';
    var finishing = false;
    _confirming = true;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.vio.t('確認管理操作')),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$channelName\n${message.displayName} · ${context.vio.t(action)}',
                ),
                const SizedBox(height: 8),
                Text(
                  message.message,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                if (action == '刪除訊息') ...[
                  const SizedBox(height: 8),
                  Text(context.vio.t('此操作無法復原，請確認目標。')),
                ],
                if (action == '封鎖') ...[
                  const SizedBox(height: 8),
                  Text(context.vio.t('封鎖會阻止此人在這個頻道發言；可使用解除封鎖恢復。')),
                ],
                if (action == '自訂禁言時間')
                  TextFormField(
                    controller: duration,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${context.vio.t('秒')} (1–1209600)',
                    ),
                    validator: (value) {
                      final number = int.tryParse(value?.trim() ?? '');
                      return number == null || number < 1 || number > 1209600
                          ? context.vio.t('請輸入範圍內的整數。')
                          : null;
                    },
                  ),
                if (const {'自訂禁言時間', '封鎖', '警告'}.contains(action))
                  TextFormField(
                    controller: reason,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: context.vio.t('管理操作原因（警告必填）'),
                    ),
                    validator: (value) =>
                        action == '警告' && (value?.trim().isEmpty ?? true)
                        ? context.vio.t('警告需要有效對象與 1–500 字的原因。')
                        : null,
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (finishing) return;
              finishing = true;
              Navigator.pop(ctx, false);
            },
            child: Text(context.vio.t('取消')),
          ),
          FilledButton(
            onPressed: () {
              if (!finishing && form.currentState!.validate()) {
                finishing = true;
                Navigator.pop(ctx, true);
              }
            },
            child: Text(context.vio.t('確認')),
          ),
        ],
      ),
    );
    _confirming = false;
    final reasonText = reason.text.trim();
    final seconds = int.tryParse(duration.text.trim());
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      reason.dispose();
      duration.dispose();
    });
    if (!mounted || accepted != true) return;
    setState(() {
      _busy = true;
      _result = null;
      _failed = false;
    });
    try {
      if (!canModerate() || widget.message.id != message.id) {
        throw const TwitchModerationException('管理身分或頻道已變更，未送出操作。');
      }
      if (action == '刪除訊息' &&
          !TwitchModerationTargetPolicy.canDelete(message, api.broadcasterId)) {
        throw const TwitchModerationException('訊息目前不符合刪除資格，未送出操作。');
      }
      if (action != '刪除訊息' &&
          !TwitchModerationTargetPolicy.canManageUser(
            message,
            broadcasterId: api.broadcasterId,
            moderatorId: api.moderatorId,
            currentModeratorStatus: widget.currentModeratorStatus,
          )) {
        throw const TwitchModerationException('對象目前是受保護角色，未送出操作。');
      }
      switch (action) {
        case '刪除訊息':
          await api.deleteMessages(messageId: message.source.tags['id']);
        case '自訂禁言時間':
          await api.ban(target, seconds: seconds, reason: reasonText);
        case '封鎖':
          await api.ban(target, reason: reasonText);
        case '解除封鎖／禁言':
          await api.unban(target);
        case '警告':
          await api.warn(target, reason: reasonText);
      }
      if (mounted) _result = '管理操作已提交；聊天室狀態以 Twitch 回應為準。';
    } on TwitchModerationException catch (error) {
      if (mounted) {
        _result = error.message;
        _failed = true;
      }
    } catch (_) {
      if (mounted) {
        _result = '管理操作失敗，請稍後再試。';
        _failed = true;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manageUser = TwitchModerationTargetPolicy.canManageUser(
      widget.message,
      broadcasterId: widget.api.broadcasterId,
      moderatorId: widget.api.moderatorId,
      currentModeratorStatus: widget.currentModeratorStatus,
    );
    final delete = TwitchModerationTargetPolicy.canDelete(
      widget.message,
      widget.api.broadcasterId,
    );
    final pin = twitchCanPinMessage(widget.message, widget.api.broadcasterId);
    if (!manageUser && !delete && !pin) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PopupMenuButton<String>(
          enabled: !_busy && widget.canModerate(),
          tooltip: context.vio.t('管理這則訊息'),
          onSelected: _action,
          itemBuilder: (_) => [
            if (delete && widget.onOpenBatch != null)
              PopupMenuItem(
                value: '批次選取訊息',
                child: Text(context.vio.t('批次選取訊息')),
              ),
            if (pin)
              PopupMenuItem(value: '釘選管理', child: Text(context.vio.t('釘選管理'))),
            if (delete)
              PopupMenuItem(value: '刪除訊息', child: Text(context.vio.t('刪除訊息'))),
            if (manageUser)
              for (final action in const ['自訂禁言時間', '警告', '封鎖', '解除封鎖／禁言'])
                PopupMenuItem(
                  value: action,
                  child: Text(context.vio.t(action)),
                ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 18),
                const SizedBox(width: 6),
                Text(context.vio.t(_busy ? '處理中' : '管理這則訊息')),
              ],
            ),
          ),
        ),
        if (_result != null)
          Text(
            context.vio.t(_result!),
            style: TextStyle(
              fontSize: 12,
              color: _failed ? Colors.redAccent : Colors.greenAccent,
            ),
          ),
      ],
    );
  }
}
