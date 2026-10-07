import 'package:flutter/material.dart';
import '../../settings/twitch_chat_keyboard_controller.dart';
import '../../localization/vioclass_localizations.dart';

class TwitchChatKeyboardSettingsCard extends StatefulWidget {
  final TwitchChatKeyboardController? controller;
  const TwitchChatKeyboardSettingsCard({super.key, this.controller});
  @override
  State<TwitchChatKeyboardSettingsCard> createState() =>
      _KeyboardSettingsState();
}

class _KeyboardSettingsState extends State<TwitchChatKeyboardSettingsCard> {
  TwitchChatKeyboardController get _controller =>
      widget.controller ?? twitchChatKeyboardController;
  bool _busy = false;
  String? _error;
  String? _status;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _run(_controller.load);
  }

  @override
  void didUpdateWidget(covariant TwitchChatKeyboardSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? twitchChatKeyboardController).removeListener(
        _changed,
      );
      _controller.addListener(_changed);
      _generation++;
      _busy = false;
      _error = null;
      _status = null;
      _run(_controller.load);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool saved = false,
  }) async {
    if (_busy) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      await action();
      if (mounted && generation == _generation && saved) _status = '已保存聊天室鍵位。';
    } catch (error) {
      if (mounted && generation == _generation) {
        _error = error is ArgumentError
            ? error.message.toString()
            : error is StateError
            ? error.message
            : '鍵位讀取或保存失敗，請再試一次。';
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_busy) return;
    final controller = _controller;
    final generation = _generation;
    setState(() => _busy = true);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.vio.t('重設聊天室鍵位？')),
        content: SingleChildScrollView(
          child: Text(
            context.vio.t('將恢復五項預設鍵位，並取代本機已保存的鍵位資料。其他 App 設定與聊天歷史不會變更。'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.vio.t('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.vio.t('確認重設')),
          ),
        ],
      ),
    );
    if (!mounted || generation != _generation || controller != _controller) {
      return;
    }
    setState(() => _busy = false);
    if (accepted == true) await _run(controller.reset, saved: true);
  }

  String _label(TwitchChatKeyboardCommand command) => switch (command) {
    TwitchChatKeyboardCommand.older => '較舊訊息',
    TwitchChatKeyboardCommand.newer => '較新訊息',
    TwitchChatKeyboardCommand.user => '開啟使用者卡',
    TwitchChatKeyboardCommand.context => '開啟訊息操作選單',
    TwitchChatKeyboardCommand.clear => '解除訊息焦點',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.t('只在聊天室取得焦點時作用，不會搶走輸入框按鍵；管理操作仍需原權限與確認。')),
        const SizedBox(height: 8),
        Text(
          l10n.t(
            '管理快捷鍵（固定）：Ctrl+D 刪除、Ctrl+T 禁言、Ctrl+W 警告、Ctrl+B 封鎖、Ctrl+Shift+B 解除。先選取訊息，按鍵只開啟確認，不會立即送出。',
          ),
        ),
        if (_busy) Text(l10n.t('正在讀取或保存鍵位…')),
        if (_error != null)
          Text(
            l10n.t(_error!),
            style: const TextStyle(color: Colors.redAccent),
          ),
        if (_controller.problem != null && _controller.problem != _error)
          Text(
            l10n.t(_controller.problem!),
            style: const TextStyle(color: Colors.orangeAccent),
          ),
        if (_status != null) Text(l10n.t(_status!)),
        for (final command in TwitchChatKeyboardCommand.values) ...[
          const SizedBox(height: 10),
          Text(l10n.t(_label(command))),
          DropdownButton<String>(
            key: ValueKey('chat-key-${command.name}'),
            isExpanded: true,
            value: _controller.bindings[command] ?? 'disabled',
            items: [
              DropdownMenuItem(value: 'disabled', child: Text(l10n.t('停用'))),
              for (final key in TwitchChatKeyboardController.keys.keys)
                DropdownMenuItem(value: key, child: Text(key)),
            ],
            onChanged: _busy || !_controller.loaded || _controller.corrupt
                ? null
                : (value) => _run(
                    () => _controller.setBinding(
                      command,
                      value == 'disabled' ? null : value,
                    ),
                    saved: true,
                  ),
          ),
        ],
        if (!_controller.loaded && !_busy)
          TextButton(
            onPressed: () => _run(_controller.load),
            child: Text(l10n.t('重新讀取鍵位')),
          ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _reset,
          icon: const Icon(Icons.restart_alt),
          label: Text(l10n.t('重設聊天室鍵位')),
        ),
      ],
    );
  }
}
