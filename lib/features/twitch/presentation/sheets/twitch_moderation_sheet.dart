import 'package:flutter/material.dart';

import '../../api/moderation/twitch_moderation_api_service.dart';
import '../../models/chat/twitch_chat_runtime_message.dart';
import '../../models/chat/twitch_moderation_target_policy.dart';
import '../../services/chat/twitch_chat_runtime.dart';
import '../../services/chat/twitch_moderation_log_controller.dart';
import '../localization/vioclass_localizations.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import 'twitch_blocked_terms_sheet.dart';
import 'twitch_pinned_chat_management_sheet.dart';
import 'twitch_automod_settings_sheet.dart';
import 'twitch_moderation_log_sheet.dart';
import 'twitch_moderation_batch_sheet.dart';

Future<void> showTwitchModerationSheet({
  required BuildContext context,
  required TwitchModerationApiService api,
  required TwitchChatRuntime runtime,
  required bool Function() canModerate,
  String? channelName,
  TwitchModerationLogController? logController,
  VoidCallback? onReconnectLog,
}) => showTwitchResponsiveSheet<void>(
  context: context,
  size: TwitchUnifiedSheetSize.large,
  builder: (_) => _ModerationSheet(
    api: api,
    runtime: runtime,
    canModerate: canModerate,
    channelName: channelName ?? api.broadcasterId,
    logController: logController,
    onReconnectLog: onReconnectLog,
  ),
);

class _ModerationSheet extends StatefulWidget {
  final TwitchModerationApiService api;
  final TwitchChatRuntime runtime;
  final bool Function() canModerate;
  final String channelName;
  final TwitchModerationLogController? logController;
  final VoidCallback? onReconnectLog;
  const _ModerationSheet({
    required this.api,
    required this.runtime,
    required this.canModerate,
    required this.channelName,
    this.logController,
    this.onReconnectLog,
  });
  @override
  State<_ModerationSheet> createState() => _ModerationSheetState();
}

class _ModerationSheetState extends State<_ModerationSheet> {
  Map<String, dynamic>? _settings;
  bool _busy = false;
  String? _error;
  final _reason = TextEditingController();
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _run(() async {
      _settings = await widget.api.settings();
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? label}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!widget.canModerate()) {
        throw const TwitchModerationException('你沒有這個頻道的管理權限。');
      }
      await action();
      if (!mounted) return;
      if (label != null) {
        final now = TimeOfDay.now().format(context);
        _log.insert(0, '$now · $label');
        if (_log.length > 30) _log.removeLast();
      }
    } on TwitchModerationException catch (error) {
      if (mounted) _error = context.vio.t(error.message);
    } catch (_) {
      if (mounted) _error = context.vio.t('管理操作失敗，請稍後再試。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(String label, Future<void> Function() action) async {
    if (_busy) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.vio.t('確認管理操作')),
        content: SingleChildScrollView(
          child: Text('@${widget.channelName}\n$label'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.vio.t('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.vio.t('確認')),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) await _run(action, label: label);
  }

  Future<int?> _askInteger(
    String title, {
    required int minimum,
    required int maximum,
    required int initial,
    required String unit,
  }) async {
    final input = TextEditingController(text: initial.toString());
    final form = GlobalKey<FormState>();
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.vio.t(title)),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: TextFormField(
              controller: input,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '${context.vio.t(unit)} ($minimum–$maximum)',
              ),
              validator: (text) {
                final parsed = int.tryParse(text?.trim() ?? '');
                return parsed == null || parsed < minimum || parsed > maximum
                    ? context.vio.t('請輸入範圍內的整數。')
                    : null;
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.vio.t('取消')),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(ctx, int.parse(input.text.trim()));
              }
            },
            child: Text(context.vio.t('繼續')),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), input.dispose);
    return value;
  }

  Future<void> _changeDuration(String key, String label) async {
    final spec = _modeParameters[key]!;
    final duration = await _askInteger(
      label,
      minimum: spec.$2,
      maximum: spec.$3,
      initial: (_settings?[spec.$1] as int?) ?? spec.$4,
      unit: spec.$5,
    );
    if (!mounted || duration == null) return;
    await _confirm(
      '${context.vio.t(label)}：$duration ${context.vio.t(spec.$5)}',
      () async {
        _settings = await widget.api.settings(
          changes: {key: true, spec.$1: duration},
        );
      },
    );
  }

  Widget _durationControl(String key, String label) {
    final spec = _modeParameters[key]!;
    return TextButton.icon(
      onPressed: _busy || _settings == null
          ? null
          : () => _changeDuration(key, label),
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: Text(
        '${context.vio.t(label)}：${_settings?[spec.$1] ?? spec.$4} ${context.vio.t(spec.$5)}',
      ),
    );
  }

  Widget _mode(String key, String label) => SwitchListTile(
    title: Text(context.vio.t(label)),
    value: _settings?[key] == true,
    onChanged: _busy || _settings == null
        ? null
        : (value) => value && _modeParameters.containsKey(key)
              ? _changeDuration(key, label)
              : _confirm(
                  '${context.vio.t(label)}：${context.vio.t(value ? '開啟' : '關閉')}',
                  () async {
                    _settings = await widget.api.settings(
                      changes: {key: value},
                    );
                  },
                ),
  );

  @override
  Widget build(BuildContext context) => TwitchUnifiedSheetScaffold(
    title: context.vio.t('聊天室管理'),
    subtitle: '@${widget.channelName} · ${context.vio.t('管理員與台主工具')}',
    icon: Icons.shield_outlined,
    loading: _busy,
    onRefresh: _busy
        ? null
        : () => _run(() async {
            _settings = await widget.api.settings();
          }),
    child: Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: widget.runtime,
        builder: (context, _) {
          final messages = widget.runtime.messages
              .where((m) => m.source.isPrivMsg)
              .toList()
              .reversed
              .take(60)
              .toList();
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              _mode('emote_mode', '僅限貼圖'),
              _mode('subscriber_mode', '僅限訂閱者'),
              _mode('follower_mode', '僅限追隨者'),
              _durationControl('follower_mode', '追隨時間門檻'),
              _mode('slow_mode', '慢速模式'),
              _durationControl('slow_mode', '發言間隔'),
              _mode('unique_chat_mode', '不重複訊息模式'),
              OutlinedButton.icon(
                onPressed: _busy || !widget.canModerate()
                    ? null
                    : () => showTwitchModerationBatchSheet(
                        context: context,
                        api: widget.api,
                        messages: List.of(
                          widget.runtime.messages,
                        ).reversed.toList(),
                        channelName: widget.channelName,
                        canModerate: widget.canModerate,
                        canManageTarget: (id) =>
                            widget.canModerate() &&
                            TwitchModerationTargetPolicy.canManageVisibleUser(
                              widget.runtime.messages,
                              id,
                              broadcasterId: widget.api.broadcasterId,
                              moderatorId: widget.api.moderatorId,
                            ),
                      ),
                icon: const Icon(Icons.checklist),
                label: Text(context.vio.t('批次刪除訊息')),
              ),
              if (widget.logController != null && widget.onReconnectLog != null)
                OutlinedButton.icon(
                  onPressed: !widget.canModerate()
                      ? null
                      : () => showTwitchModerationLogSheet(
                          context: context,
                          controller: widget.logController!,
                          onReconnect: widget.onReconnectLog!,
                        ),
                  icon: const Icon(Icons.history),
                  label: Text(context.vio.t('管理紀錄')),
                ),
              OutlinedButton.icon(
                onPressed: _busy || !widget.canModerate()
                    ? null
                    : () => showTwitchAutomodSettingsSheet(
                        context: context,
                        api: widget.api,
                        channelName: widget.channelName,
                      ),
                icon: const Icon(Icons.shield_outlined),
                label: Text(context.vio.t('AutoMod 設定')),
              ),
              OutlinedButton.icon(
                onPressed: _busy || !widget.canModerate()
                    ? null
                    : () => showTwitchPinnedChatManagementSheet(
                        context: context,
                        api: widget.api,
                        channelName: widget.channelName,
                      ),
                icon: const Icon(Icons.push_pin_outlined),
                label: Text(context.vio.t('釘選管理')),
              ),
              OutlinedButton.icon(
                onPressed: _busy || !widget.canModerate()
                    ? null
                    : () => showTwitchBlockedTermsSheet(
                        context: context,
                        api: widget.api,
                        channelName: widget.channelName,
                      ),
                icon: const Icon(Icons.filter_alt_outlined),
                label: Text(context.vio.t('封鎖詞管理')),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _confirm(
                        context.vio.t('清除整個聊天室（無法復原）'),
                        () => widget.api.deleteMessages(),
                      ),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(context.vio.t('清除聊天室')),
              ),
              TextField(
                controller: _reason,
                enabled: !_busy,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: context.vio.t('管理操作原因（警告必填）'),
                ),
              ),
              const Divider(),
              Text(context.vio.t('最近訊息（最多 60 則）')),
              if (messages.isEmpty) Text(context.vio.t('等待聊天室訊息')),
              for (final message in messages) _messageTile(message),
              const Divider(),
              Text(context.vio.t('本次面板的操作紀錄（非完整管理紀錄）')),
              for (final entry in _log)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(entry),
                ),
            ],
          );
        },
      ),
    ),
  );

  void _requireManageUser(String userId) {
    if (!TwitchModerationTargetPolicy.canManageVisibleUser(
      widget.runtime.messages,
      userId,
      broadcasterId: widget.api.broadcasterId,
      moderatorId: widget.api.moderatorId,
    )) {
      throw const TwitchModerationException('對象身分已變更或無法確認，未送出操作。');
    }
  }

  Widget _messageTile(TwitchChatRuntimeMessage message) {
    final id = message.source.tags['id'] ?? '';
    final userId = message.source.tags['user-id'] ?? '';
    final manageUser = TwitchModerationTargetPolicy.canManageUser(
      message,
      broadcasterId: widget.api.broadcasterId,
      moderatorId: widget.api.moderatorId,
    );
    final canDelete = TwitchModerationTargetPolicy.canDelete(
      message,
      widget.api.broadcasterId,
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(message.displayName),
      subtitle: Text(
        message.message,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        enabled: !_busy && (manageUser || canDelete),
        onSelected: (action) {
          final reason = _reason.text;
          final label =
              '${message.displayName} · ${context.vio.t(action)}'
              '${reason.trim().isEmpty ? '' : '\n${reason.trim()}'}';
          if (action == '自訂禁言時間') {
            _customTimeout(userId, message.displayName, reason);
            return;
          }
          _confirm(label, () async {
            if (action != '刪除訊息') _requireManageUser(userId);
            switch (action) {
              case '刪除訊息':
                await widget.api.deleteMessages(messageId: id);
              case '解除封鎖／禁言':
                await widget.api.unban(userId);
              case '封鎖':
                await widget.api.ban(userId, reason: reason);
              case '警告':
                await widget.api.warn(userId, reason: reason);
              default:
                await widget.api.ban(
                  userId,
                  seconds: _durations[action],
                  reason: reason,
                );
            }
          });
        },
        itemBuilder: (_) => [
          if (canDelete)
            PopupMenuItem(value: '刪除訊息', child: Text(context.vio.t('刪除訊息'))),
          if (manageUser) ...[
            for (final action in _durations.keys)
              PopupMenuItem(value: action, child: Text(context.vio.t(action))),
            PopupMenuItem(
              value: '自訂禁言時間',
              child: Text(context.vio.t('自訂禁言時間')),
            ),
            PopupMenuItem(value: '警告', child: Text(context.vio.t('警告'))),
            PopupMenuItem(value: '封鎖', child: Text(context.vio.t('封鎖'))),
            PopupMenuItem(
              value: '解除封鎖／禁言',
              child: Text(context.vio.t('解除封鎖／禁言')),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _customTimeout(String userId, String name, String reason) async {
    final seconds = await _askInteger(
      '自訂禁言時間',
      minimum: 1,
      maximum: 1209600,
      initial: 600,
      unit: '秒',
    );
    if (!mounted || seconds == null) return;
    await _confirm(
      '$name · ${context.vio.t('禁言')} $seconds ${context.vio.t('秒')}'
      '${reason.trim().isEmpty ? '' : '\n${reason.trim()}'}',
      () async {
        _requireManageUser(userId);
        await widget.api.ban(userId, seconds: seconds, reason: reason);
      },
    );
  }
}

const _modeParameters = {
  'slow_mode': ('slow_mode_wait_time', 3, 120, 10, '秒'),
  'follower_mode': ('follower_mode_duration', 0, 129600, 0, '分鐘'),
};

const _durations = {
  '禁言 1 秒': 1,
  '禁言 10 分鐘': 600,
  '禁言 1 小時': 3600,
  '禁言 24 小時': 86400,
};
