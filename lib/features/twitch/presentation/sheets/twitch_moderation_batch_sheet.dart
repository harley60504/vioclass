import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/moderation/twitch_moderation_api_service.dart';
import '../../models/chat/twitch_chat_runtime_message.dart';
import '../../models/chat/twitch_chat_message.dart';
import '../../models/chat/twitch_moderation_target_policy.dart';
import '../../services/chat/twitch_moderation_batch_controller.dart';
import '../localization/vioclass_localizations.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import 'twitch_moderation_user_batch_sheet.dart';

Future<void> showTwitchModerationBatchSheet({
  required BuildContext context,
  required TwitchModerationApiService api,
  required List<TwitchChatRuntimeMessage> messages,
  required String channelName,
  required bool Function() canModerate,
  String? initialMessageId,
  bool Function(String userId)? canManageTarget,
}) => showTwitchResponsiveSheet<void>(
  context: context,
  size: TwitchUnifiedSheetSize.large,
  builder: (_) => TwitchModerationBatchSheet(
    api: api,
    messages: messages,
    channelName: channelName,
    canModerate: canModerate,
    initialMessageId: initialMessageId,
    canManageTarget: canManageTarget,
  ),
);

class TwitchModerationBatchSheet extends StatefulWidget {
  final TwitchModerationApiService api;
  final List<TwitchChatRuntimeMessage> messages;
  final String channelName;
  final bool Function() canModerate;
  final String? initialMessageId;
  final bool Function(String userId)? canManageTarget;
  const TwitchModerationBatchSheet({
    super.key,
    required this.api,
    required this.messages,
    required this.channelName,
    required this.canModerate,
    this.initialMessageId,
    this.canManageTarget,
  });
  @override
  State<TwitchModerationBatchSheet> createState() => _BatchSheetState();
}

class _BatchSheetState extends State<TwitchModerationBatchSheet> {
  late final TwitchModerationBatchController _controller;
  late final List<TwitchChatRuntimeMessage> _messages;
  final _selected = <int>{};
  TwitchModerationDeletePlan? _plan;
  String? _error;
  bool _started = false;
  bool _confirming = false;
  bool _userMode = false;
  bool _userSheetOpen = false;
  final _userEligibility = <String, bool>{};
  bool _rangeMode = false;
  int? _selectionAnchor;
  bool _dragMode = false;
  final _scroll = ScrollController();
  final _viewportKey = GlobalKey();
  final _rowKeys = <int, GlobalKey>{};
  int? _dragAnchor;
  Set<int>? _dragBaseline;
  bool _dragSelect = true;
  Offset? _dragPosition;
  Offset? _panOrigin;
  Timer? _dragTimer;

  @override
  void initState() {
    super.initState();
    // The preview must not change when live chat or the source tag map changes.
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
    );
    _controller.addListener(_changed);
    final index = _messages.indexWhere(
      (message) =>
          widget.initialMessageId != null &&
          message.source.tags['id']?.trim() ==
              widget.initialMessageId?.trim() &&
          TwitchModerationTargetPolicy.canDelete(
            message,
            widget.api.broadcasterId,
          ),
    );
    if (index >= 0) {
      _selected.add(index);
      _selectionAnchor = index;
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _endDrag();
    _scroll.dispose();
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  void _preview() {
    if (_started ||
        _confirming ||
        _plan != null ||
        _selected.isEmpty ||
        _dragAnchor != null) {
      return;
    }
    if (_userMode) {
      _openUsers();
      return;
    }
    try {
      final plan = _controller.prepareDelete([
        for (final index in _selected) _messages[index],
      ]);
      setState(() {
        _plan = plan;
        _dragMode = false;
        _error = null;
      });
    } on TwitchModerationException catch (error) {
      setState(() => _error = error.message);
    }
  }

  bool _eligible(TwitchChatRuntimeMessage message) {
    if (!_userMode) {
      return TwitchModerationTargetPolicy.canDelete(
        message,
        widget.api.broadcasterId,
      );
    }
    return message.source.isPrivMsg &&
        message.source.source != TwitchChatMessageSource.synthetic &&
        message.source.source != TwitchChatMessageSource.localEcho &&
        TwitchModerationTargetPolicy.sameChannel(
          message,
          widget.api.broadcasterId,
        ) &&
        _userEligibility.putIfAbsent(
          message.source.tags['user-id'] ?? '',
          () => TwitchModerationTargetPolicy.canManageVisibleUser(
            _messages,
            message.source.tags['user-id'] ?? '',
            broadcasterId: widget.api.broadcasterId,
            moderatorId: widget.api.moderatorId,
          ),
        );
  }

  Future<void> _openUsers() async {
    if (_userSheetOpen ||
        _started ||
        _confirming ||
        _plan != null ||
        _selected.isEmpty ||
        _dragAnchor != null ||
        !widget.canModerate() ||
        widget.canManageTarget == null) {
      return;
    }
    setState(() => _dragMode = false);
    _userSheetOpen = true;
    try {
      await showTwitchModerationUserBatchSheet(
        context: context,
        api: widget.api,
        messages: [for (final index in _selected) _messages[index]],
        channelName: widget.channelName,
        canModerate: widget.canModerate,
        canManageTarget: widget.canManageTarget!,
      );
    } finally {
      _userSheetOpen = false;
    }
  }

  void _switchMode() {
    if (_started ||
        _confirming ||
        _plan != null ||
        _userSheetOpen ||
        !widget.canModerate() ||
        widget.canManageTarget == null) {
      return;
    }
    _endDrag();
    setState(() {
      _userMode = !_userMode;
      _selected.clear();
      _selectionAnchor = null;
      _dragMode = false;
      _rangeMode = false;
      _panOrigin = null;
      _error = null;
    });
  }

  void _select(int index, bool selected) {
    if (_started || _confirming || _plan != null || !widget.canModerate()) {
      return;
    }
    final anchor = _selectionAnchor;
    final range =
        (_rangeMode || HardwareKeyboard.instance.isShiftPressed) &&
        anchor != null;
    final first = range && anchor < index ? anchor : index;
    final last = range && anchor > index ? anchor : index;
    _applyRange(first, last, selected, _selected, index);
  }

  void _applyRange(
    int first,
    int last,
    bool selected,
    Set<int> baseline,
    int anchor,
  ) {
    final next = Set<int>.of(baseline);
    for (var position = first; position <= last; position++) {
      if (!_eligible(_messages[position])) {
        continue;
      }
      if (selected) {
        next.add(position);
      } else {
        next.remove(position);
      }
    }
    if (next.length > 50) {
      setState(() => _error = '範圍超過 50 則，未變更原選取；請縮小範圍。');
      return;
    }
    setState(() {
      _selected.clear();
      _selected.addAll(next);
      _selectionAnchor = anchor;
      _error = null;
    });
  }

  void _startDrag(int index, Offset position) {
    if (!widget.canModerate() ||
        _plan != null ||
        !_eligible(_messages[index])) {
      return;
    }
    _dragAnchor = index;
    _dragBaseline = Set.of(_selected);
    _dragSelect = !_selected.contains(index);
    _moveDrag(position);
    _dragTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!widget.canModerate()) {
        _endDrag();
        if (mounted) setState(() => _error = '管理身分或頻道已變更，已停止拖曳選取。');
        return;
      }
      final position = _dragPosition;
      final render = _viewportKey.currentContext?.findRenderObject();
      if (!mounted ||
          position == null ||
          render is! RenderBox ||
          !_scroll.hasClients) {
        return;
      }
      final local = render.globalToLocal(position);
      final delta = local.dy < 36
          ? -22.0
          : local.dy > render.size.height - 36
          ? 22.0
          : 0.0;
      if (delta == 0) return;
      final next = (_scroll.offset + delta).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      _scroll.jumpTo(next);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moveDrag(position);
      });
    });
  }

  void _startDragAt(Offset position) {
    for (final entry in _rowKeys.entries) {
      final row = entry.value.currentContext?.findRenderObject();
      if (row is RenderBox &&
          row.attached &&
          (row.localToGlobal(Offset.zero) & row.size).contains(position)) {
        _startDrag(entry.key, position);
        break;
      }
    }
  }

  void _moveDrag(Offset position) {
    final anchor = _dragAnchor;
    final baseline = _dragBaseline;
    if (anchor == null || baseline == null) return;
    if (!widget.canModerate()) {
      _endDrag();
      return;
    }
    _dragPosition = position;
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox) return;
    final local = viewport.globalToLocal(position);
    final point = viewport.localToGlobal(
      Offset(
        local.dx.clamp(1.0, viewport.size.width - 1),
        local.dy.clamp(1.0, viewport.size.height - 1),
      ),
    );
    for (final entry in _rowKeys.entries) {
      final row = entry.value.currentContext?.findRenderObject();
      if (row is! RenderBox || !row.attached) continue;
      if (!(row.localToGlobal(Offset.zero) & row.size).contains(point)) {
        continue;
      }
      final index = entry.key;
      _applyRange(
        anchor < index ? anchor : index,
        anchor > index ? anchor : index,
        _dragSelect,
        baseline,
        anchor,
      );
      break;
    }
  }

  void _endDrag() {
    _dragTimer?.cancel();
    _dragTimer = null;
    _dragAnchor = null;
    _dragBaseline = null;
    _dragPosition = null;
    _panOrigin = null;
  }

  Future<void> _confirm() async {
    final plan = _plan;
    if (_started || _confirming || plan == null || plan.messages.isEmpty) {
      return;
    }
    setState(() => _confirming = true);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.vio.t('確認批次刪除')),
        content: SingleChildScrollView(
          child: Text(
            '@${widget.channelName}\n${plan.messages.length} ${context.vio.t('則訊息')}\n${context.vio.t('此操作無法復原；已送出的刪除不能取消。')}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.vio.t('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.vio.t('確認刪除')),
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
    await _controller.executeDelete(plan);
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final results = _controller.results;
    final l10n = context.vio;
    return TwitchUnifiedSheetScaffold(
      title: l10n.t(_userMode ? '批次使用者操作' : '批次刪除訊息'),
      subtitle: '@${widget.channelName}',
      icon: Icons.delete_outline,
      showRefresh: false,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              _preview,
        },
        child: Focus(
          autofocus: true,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onPanDown: !_dragMode
                  ? null
                  : (details) => _panOrigin = details.globalPosition,
              onPanStart: !_dragMode
                  ? null
                  : (details) {
                      _startDragAt(_panOrigin ?? details.globalPosition);
                      _moveDrag(details.globalPosition);
                    },
              onPanUpdate: !_dragMode
                  ? null
                  : (details) {
                      if (_dragAnchor != null) {
                        _moveDrag(details.globalPosition);
                      } else if (_scroll.hasClients) {
                        _scroll.jumpTo(
                          (_scroll.offset - details.delta.dy).clamp(
                            0.0,
                            _scroll.position.maxScrollExtent,
                          ),
                        );
                      }
                    },
              onPanEnd: !_dragMode ? null : (_) => _endDrag(),
              onPanCancel: !_dragMode ? null : _endDrag,
              child: CustomScrollView(
                key: _viewportKey,
                controller: _scroll,
                physics: _dragMode
                    ? const NeverScrollableScrollPhysics()
                    : null,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.t(
                              _userMode
                                  ? '依本次快照選取使用者來源訊息，最多 50 則；預覽按使用者去重，不需訊息 ID。'
                                  : '只處理本次快照中的已選訊息，不會清除整個聊天室。最多選取 50 則。',
                            ),
                          ),
                          Text(l10n.t('關閉或停止只取消尚未送出的項目；已送出操作無法復原。')),
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
                            Text('${l10n.t('已選取')} ${_selected.length} / 50'),
                            if (widget.canManageTarget != null)
                              OutlinedButton(
                                onPressed: !widget.canModerate()
                                    ? null
                                    : _switchMode,
                                child: Text(
                                  l10n.t(_userMode ? '選取模式：使用者' : '選取模式：訊息'),
                                ),
                              ),
                            if (widget.canManageTarget != null)
                              OutlinedButton(
                                onPressed:
                                    _selected.isEmpty ||
                                        _dragAnchor != null ||
                                        !widget.canModerate()
                                    ? null
                                    : _openUsers,
                                child: Text(l10n.t('批次禁言／警告')),
                              ),
                            OutlinedButton(
                              onPressed: !widget.canModerate()
                                  ? null
                                  : () => setState(() {
                                      _endDrag();
                                      _dragMode = !_dragMode;
                                    }),
                              child: Text(
                                l10n.t(_dragMode ? '拖曳選取：開' : '拖曳選取：關'),
                              ),
                            ),
                            Text(
                              l10n.t(
                                'Ctrl+Enter：預覽；Shift+點選：範圍選取。手機可開啟範圍選取後點兩端。',
                              ),
                            ),
                            OutlinedButton(
                              onPressed: !widget.canModerate()
                                  ? null
                                  : () => setState(() {
                                      _rangeMode = !_rangeMode;
                                      _selectionAnchor = null;
                                    }),
                              child: Text(
                                l10n.t(_rangeMode ? '範圍選取：開' : '範圍選取：關'),
                              ),
                            ),
                            FilledButton(
                              onPressed:
                                  _selected.isEmpty || !widget.canModerate()
                                  ? null
                                  : _preview,
                              child: Text(
                                l10n.t(_userMode ? '預覽使用者操作' : '預覽刪除'),
                              ),
                            ),
                          ] else ...[
                            Text(
                              '${l10n.t('預覽')} ${plan.messages.length} · ${l10n.t('排除或重複')} ${plan.excluded}',
                            ),
                            if (!_started) ...[
                              FilledButton(
                                onPressed:
                                    _confirming ||
                                        plan.messages.isEmpty ||
                                        !widget.canModerate()
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
                                child: Text(l10n.t('返回選取')),
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
                          ],
                          if (_messages.isEmpty) Text(l10n.t('目前沒有可選訊息。')),
                        ],
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: plan == null
                        ? _messages.length
                        : plan.messages.length,
                    itemBuilder: (context, index) {
                      if (plan != null) {
                        final target = plan.messages[index];
                        return ListTile(
                          title: Text(target.displayName),
                          subtitle: Text(
                            '${target.text}\nID: ${target.messageId}\n${l10n.t(_status(results[target.messageId]))}',
                          ),
                        );
                      }
                      final message = _messages[index];
                      final eligible = _eligible(message);
                      return KeyedSubtree(
                        key: _rowKeys.putIfAbsent(index, GlobalKey.new),
                        child: CheckboxListTile(
                          key: ValueKey('batch-select-$index'),
                          value: _selected.contains(index),
                          title: Text(message.displayName),
                          subtitle: Text(
                            '${message.message}\n${_userMode ? 'User ID: ${message.source.tags['user-id'] ?? ''}' : 'ID: ${message.source.tags['id'] ?? ''}'}${eligible ? '' : '\n${l10n.t(_userMode ? '此使用者不符合操作條件' : '此訊息不符合刪除條件')}'}',
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onChanged:
                              !eligible ||
                                  !widget.canModerate() ||
                                  (_selected.length >= 50 &&
                                      !_selected.contains(index))
                              ? null
                              : (value) => _select(index, value == true),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _status(TwitchModerationBatchResult? result) => switch (result) {
    TwitchModerationBatchResult.submitting => '正在提交',
    TwitchModerationBatchResult.submitted => '已提交；以 Twitch 狀態為準',
    TwitchModerationBatchResult.rejected => '未接受',
    TwitchModerationBatchResult.unknown => '結果不明；請先核對，勿直接重送',
    _ => '未送出',
  };
}
