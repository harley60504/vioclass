import 'package:flutter/material.dart';

import '../../models/chat/twitch_moderation_log_entry.dart';
import '../../services/chat/twitch_moderation_log_controller.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

Future<void> showTwitchModerationLogSheet({
  required BuildContext context,
  required TwitchModerationLogController controller,
  required VoidCallback onReconnect,
}) => showTwitchResponsiveSheet<void>(
  context: context,
  size: TwitchUnifiedSheetSize.large,
  builder: (_) => TwitchModerationLogPanel(
    controller: controller,
    onReconnect: onReconnect,
  ),
);

class TwitchModerationLogPanel extends StatefulWidget {
  final TwitchModerationLogController controller;
  final VoidCallback onReconnect;
  const TwitchModerationLogPanel({
    super.key,
    required this.controller,
    required this.onReconnect,
  });
  @override
  State<TwitchModerationLogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<TwitchModerationLogPanel> {
  TwitchModerationLogCategory? _category;
  String _query = '';
  static const _categories = ['使用者', '聊天室', '身分', '揪團', 'AutoMod', '未識別'];
  static const _fields = {
    'reason': '原因',
    'message_body': '被刪訊息',
    'message_id': '訊息 ID',
    'moderator_message': '管理員說明',
    'expires_at': '禁言到期',
    'follow_duration_minutes': '追隨門檻（分鐘）',
    'wait_time_seconds': '發言間隔（秒）',
    'viewer_count': '揪團人數',
    'terms': '詞彙',
    'chat_rules_cited': '引用規則',
    'is_approved': '是否核准',
    'from_automod': '來自 AutoMod',
    'action': '詞彙操作',
    'list': '詞彙清單',
  };
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final entries = controller.entries.reversed.where((entry) {
        if (_category != null && entry.category != _category) return false;
        final haystack =
            '${entry.label} ${entry.action} ${entry.moderatorId} '
            '${entry.broadcasterId} ${entry.sourceBroadcasterId} '
            '${entry.moderatorLogin} ${entry.moderatorName} ${entry.details.values.join(' ')}';
        return haystack.toLowerCase().contains(_query);
      }).toList();
      return Padding(
        padding: const EdgeInsets.all(12),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('管理紀錄')),
                      IconButton(
                        tooltip: '關閉管理紀錄',
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(controller.status),
                  const Text(
                    '僅限本機收到的事件；斷線期間與更早歷史不會自動補回。',
                    style: TextStyle(fontSize: 12),
                  ),
                  if (controller.storageError != null)
                    Text(
                      controller.storageError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<TwitchModerationLogCategory>(
                        hint: const Text('全部分類'),
                        value: _category,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('全部分類'),
                          ),
                          for (final category
                              in TwitchModerationLogCategory.values)
                            DropdownMenuItem(
                              value: category,
                              child: Text(_categories[category.index]),
                            ),
                        ],
                        onChanged: (value) => setState(() => _category = value),
                      ),
                      TextButton(
                        onPressed: controller.loading
                            ? null
                            : widget.onReconnect,
                        child: const Text('重新連線'),
                      ),
                      if (controller.unsavedCount > 0)
                        TextButton(
                          onPressed: controller.saving
                              ? null
                              : controller.retrySaving,
                          child: Text(controller.saving ? '正在保存…' : '重試保存'),
                        ),
                    ],
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '搜尋管理員、使用者或內容',
                    ),
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                  ),
                ],
              ),
            ),
            if (controller.loading || entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: controller.loading
                    ? const Center(child: CircularProgressIndicator())
                    : const Center(child: Text('沒有符合條件的本機管理紀錄。')),
              )
            else
              SliverList.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final actor = entry.moderatorName.isNotEmpty
                      ? entry.moderatorName
                      : entry.moderatorLogin.isNotEmpty
                      ? entry.moderatorLogin
                      : entry.moderatorId;
                  final target =
                      [
                            entry.details['user_name'],
                            entry.details['user_login'],
                            entry.targetUserId,
                          ]
                          .whereType<String>()
                          .map((value) => value.trim())
                          .where((value) => value.isNotEmpty)
                          .firstOrNull;
                  return ListTile(
                    isThreeLine: false,
                    title: Text(
                      '${entry.label}${target == null ? '' : ' · $target'}',
                    ),
                    subtitle: Text(
                      [
                        '${entry.time.toLocal()} · $actor（${entry.moderatorId}）',
                        if (entry.targetUserId?.isNotEmpty == true)
                          '使用者 ID：${entry.targetUserId}',
                        if (entry.isSharedChat)
                          '共享來源頻道：${entry.sourceBroadcasterId}',
                        if (entry.category ==
                            TwitchModerationLogCategory.unknown)
                          '官方動作：${entry.action}',
                        if (!entry.detailsAvailable) '事件詳細資料未提供。',
                        for (final field in _fields.entries)
                          if (entry.details.containsKey(field.key))
                            '${field.value}：${entry.details[field.key]}',
                      ].join('\n'),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}
