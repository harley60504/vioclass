import 'package:flutter/material.dart';
import '../../api/moderation/twitch_moderation_api_service.dart';
import '../../models/chat/twitch_chat_runtime_message.dart';
import '../../services/chat/twitch_moderation_batch_controller.dart';
import '../localization/vioclass_localizations.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

Future<void> showTwitchModerationUserBatchSheet({
  required BuildContext context,
  required TwitchModerationApiService api,
  required List<TwitchChatRuntimeMessage> messages,
  required String channelName,
  required bool Function() canModerate,
  required bool Function(String) canManageTarget,
}) => showTwitchResponsiveSheet<void>(
  context: context,
  size: TwitchUnifiedSheetSize.large,
  builder: (_) => _UserBatchSheet(
    api: api,
    messages: messages,
    channelName: channelName,
    canModerate: canModerate,
    canManageTarget: canManageTarget,
  ),
);

class _UserBatchSheet extends StatefulWidget {
  final TwitchModerationApiService api;
  final List<TwitchChatRuntimeMessage> messages;
  final String channelName;
  final bool Function() canModerate;
  final bool Function(String) canManageTarget;
  const _UserBatchSheet({
    required this.api,
    required this.messages,
    required this.channelName,
    required this.canModerate,
    required this.canManageTarget,
  });
  @override
  State<_UserBatchSheet> createState() => _UserBatchState();
}

class _UserBatchState extends State<_UserBatchSheet> {
  late final TwitchModerationBatchController _controller;
  late final List<TwitchChatRuntimeMessage> _messages;
  final _reason = TextEditingController();
  final _seconds = TextEditingController(text: '600');
  TwitchModerationUserBatchAction _action =
      TwitchModerationUserBatchAction.warn;
  TwitchModerationUserPlan? _plan;
  bool _confirming = false;
  bool _started = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _messages = List.unmodifiable(
      widget.messages.map(
        (message) => TwitchChatRuntimeMessage(
          source: message.source.copyWith(
            tags: Map.unmodifiable(message.source.tags),
          ),
          resolvedBadges: message.resolvedBadges,
          receivedAt: message.receivedAt,
          fragments: message.fragments,
          segments: message.segments,
          metadata: message.metadata,
        ),
      ),
    );
    _controller = TwitchModerationBatchController(
      api: widget.api,
      canModerate: widget.canModerate,
    )..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    _reason.dispose();
    _seconds.dispose();
    super.dispose();
  }

  void _preview() {
    if (_plan != null || _started || _confirming) return;
    try {
      final plan = _controller.prepareUsers(
        _messages,
        action: _action,
        reason: _reason.text,
        seconds: _action == TwitchModerationUserBatchAction.timeout
            ? int.tryParse(_seconds.text.trim())
            : null,
      );
      FocusScope.of(context).unfocus();
      setState(() {
        _plan = plan;
        _error = null;
      });
    } on TwitchModerationException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Future<void> _confirm() async {
    final plan = _plan;
    if (plan == null || plan.users.isEmpty || _started || _confirming) return;
    setState(() => _confirming = true);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.vio.t('確認批次使用者操作')),
        content: SingleChildScrollView(
          child: Text(
            '@${widget.channelName}\n${_actionName(plan.action)} · ${plan.users.length} ${context.vio.t('位使用者')}\n${plan.seconds == null ? '' : '${plan.seconds} ${context.vio.t('秒')}\n'}${plan.reason}\n${context.vio.t('已送出操作不能取消；只會停止尚未送出的項目。')}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.vio.t('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.vio.t('確認送出')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (accepted != true) return;
    if (!widget.canModerate()) {
      setState(() => _error = '管理身分或頻道已變更，未送出操作。');
      return;
    }
    setState(() => _started = true);
    await _controller.executeUsers(
      plan,
      canManageTarget: widget.canManageTarget,
    );
  }

  String _actionName(TwitchModerationUserBatchAction action) => context.vio.t(
    action == TwitchModerationUserBatchAction.warn ? '警告' : '禁言',
  );
  String _status(TwitchModerationBatchResult? result) => switch (result) {
    TwitchModerationBatchResult.submitted => '已提交；以 Twitch 狀態為準',
    TwitchModerationBatchResult.submitting => '正在提交',
    TwitchModerationBatchResult.rejected => '未接受',
    TwitchModerationBatchResult.unknown => '結果不明；請先核對，勿直接重送',
    _ => '未送出',
  };
  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final l10n = context.vio;
    return TwitchUnifiedSheetScaffold(
      title: l10n.t('批次禁言／警告'),
      subtitle: '@${widget.channelName}',
      icon: Icons.shield_outlined,
      showRefresh: false,
      child: Material(
        color: Colors.transparent,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text(
              '${l10n.t('來源選取')} ${_messages.length} · ${l10n.t('同一使用者只處理一次；受保護角色會排除。')}',
            ),
            if (_error != null)
              Text(
                l10n.t(_error!),
                style: const TextStyle(color: Colors.redAccent),
              ),
            if (_controller.problem != null)
              Text(
                l10n.t(_controller.problem!),
                style: const TextStyle(color: Colors.redAccent),
              ),
            if (plan == null) ...[
              DropdownButton<TwitchModerationUserBatchAction>(
                value: _action,
                isExpanded: true,
                items: [
                  for (final action in TwitchModerationUserBatchAction.values)
                    DropdownMenuItem(
                      value: action,
                      child: Text(_actionName(action)),
                    ),
                ],
                onChanged: !widget.canModerate()
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _action = value;
                            _error = null;
                          });
                        }
                      },
              ),
              TextField(
                controller: _reason,
                maxLength: 500,
                decoration: InputDecoration(labelText: l10n.t('原因（警告必填）')),
              ),
              if (_action == TwitchModerationUserBatchAction.timeout)
                TextField(
                  controller: _seconds,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${l10n.t('禁言秒數')} (1–1209600)',
                  ),
                ),
              FilledButton(
                onPressed: !widget.canModerate() ? null : _preview,
                child: Text(l10n.t('預覽使用者')),
              ),
            ] else ...[
              Text(
                '${_actionName(plan.action)} · ${l10n.t('預覽')} ${plan.users.length} · ${l10n.t('排除或重複')} ${plan.excluded}',
              ),
              Text(
                '${plan.reason}${plan.seconds == null ? '' : '\n${plan.seconds} ${l10n.t('秒')}'}',
              ),
              if (plan.users.isEmpty) Text(l10n.t('沒有符合操作條件的使用者，未送出任何操作。')),
              if (!_started) ...[
                FilledButton(
                  onPressed:
                      _confirming || plan.users.isEmpty || !widget.canModerate()
                      ? null
                      : _confirm,
                  child: Text(l10n.t('繼續確認')),
                ),
                TextButton(
                  onPressed: _confirming
                      ? null
                      : () => setState(() {
                          _plan = null;
                          _error = null;
                        }),
                  child: Text(l10n.t('返回設定')),
                ),
              ] else ...[
                Text(
                  l10n.t(
                    _controller.running
                        ? '正在逐筆提交'
                        : _controller.cancelled
                        ? '已停止後續操作'
                        : _controller.problem != null
                        ? '批次已停止'
                        : '批次處理結束',
                  ),
                ),
                if (_controller.running)
                  OutlinedButton(
                    onPressed: _controller.cancelled
                        ? null
                        : _controller.cancelRemaining,
                    child: Text(l10n.t('停止後續操作')),
                  ),
              ],
              for (final target in plan.users)
                ListTile(
                  title: Text(target.displayName),
                  subtitle: Text(
                    '${target.exampleText}\nUser ID: ${target.userId}\n${l10n.t(_status(_controller.results[target.userId]))}',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
