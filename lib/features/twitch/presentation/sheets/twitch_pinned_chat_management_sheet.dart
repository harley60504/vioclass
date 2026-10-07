import 'package:flutter/material.dart';
import '../../api/moderation/twitch_moderation_api_service.dart';
import '../../models/chat/twitch_chat_message.dart';
import '../../models/chat/twitch_chat_runtime_message.dart';
import '../../models/chat/twitch_moderation_target_policy.dart';
import '../../models/engagement/twitch_pinned_chat.dart';
import '../localization/vioclass_localizations.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

bool twitchCanPinMessage(TwitchChatRuntimeMessage message, String channelId) =>
    message.source.isPrivMsg &&
    message.source.source != TwitchChatMessageSource.localEcho &&
    message.source.source != TwitchChatMessageSource.synthetic &&
    (message.source.tags['id']?.trim().isNotEmpty ?? false) &&
    TwitchModerationTargetPolicy.sameChannel(message, channelId);

Future<void> showTwitchPinnedChatManagementSheet({
  required BuildContext context,
  required TwitchModerationApiService api,
  required String channelName,
  TwitchChatRuntimeMessage? selectedMessage,
}) => showTwitchResponsiveSheet<void>(
  context: context,
  builder: (_) => TwitchPinnedChatManagementPanel(
    api: api,
    channelName: channelName,
    selectedMessage: selectedMessage,
  ),
);

class TwitchPinnedChatManagementPanel extends StatefulWidget {
  final TwitchModerationApiService api;
  final String channelName;
  final TwitchChatRuntimeMessage? selectedMessage;
  const TwitchPinnedChatManagementPanel({
    super.key,
    required this.api,
    required this.channelName,
    this.selectedMessage,
  });
  @override
  State<TwitchPinnedChatManagementPanel> createState() => _PinsState();
}

class _PinsState extends State<TwitchPinnedChatManagementPanel> {
  final _duration = TextEditingController(text: '300');
  final _form = GlobalKey<FormState>();
  List<TwitchPinnedChatMessage>? _pins;
  bool _loading = false;
  bool _busy = false;
  bool _untilEnd = false;
  String? _error;
  String? _result;
  bool get _current => widget.api.canModerate?.call() != false;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _duration.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_loading || !_current) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pins = await widget.api.pinnedMessages();
      if (mounted && _current) setState(() => _pins = pins);
    } catch (error) {
      if (mounted) {
        setState(() {
          _pins = null;
          _error = error is TwitchModerationException
              ? error.message
              : '釘選狀態未確認，請重新整理。';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _change(String action, {TwitchPinnedChatMessage? pin}) async {
    if (_busy || _loading || !_current || _pins == null) return;
    if (action != '解除釘選' && !_form.currentState!.validate()) return;
    final api = widget.api;
    final selected = widget.selectedMessage;
    final id = action == '釘選這則訊息'
        ? selected?.source.tags['id'] ?? ''
        : pin?.messageId ?? '';
    final text = action == '釘選這則訊息' ? selected?.message ?? '' : pin?.text ?? '';
    final seconds = _untilEnd ? null : int.tryParse(_duration.text.trim());
    final before = _pins!
        .map((p) => '${p.messageId}:${p.updatedAt}:${p.endsAt}')
        .join('|');
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    var finishing = false;
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.vio.t(action)),
          content: SingleChildScrollView(
            child: Text(
              '@${widget.channelName}\n$text\n${action == '解除釘選'
                  ? ''
                  : seconds == null
                  ? context.vio.t('直到直播結束')
                  : '$seconds ${context.vio.t('秒')}'}\n${context.vio.t('每個頻道只能有一則管理員釘選；新增會取代當時的釘選。')}',
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
                if (finishing) return;
                finishing = true;
                Navigator.pop(ctx, true);
              },
              child: Text(context.vio.t('確認')),
            ),
          ],
        ),
      );
      if (!mounted || accepted != true) return;
      if (!_current) throw const TwitchModerationException('管理身分或頻道已變更，未送出操作。');
      final current = await api.pinnedMessages();
      if (!mounted || !_current) return;
      if (current
              .map((p) => '${p.messageId}:${p.updatedAt}:${p.endsAt}')
              .join('|') !=
          before) {
        setState(() => _pins = current);
        throw const TwitchModerationException('釘選訊息已變更，請重新確認後再操作。');
      }
      if (action == '解除釘選') {
        await api.unpinMessage(id);
      } else {
        if (action == '釘選這則訊息' &&
            (selected == null ||
                !twitchCanPinMessage(selected, api.broadcasterId))) {
          throw const TwitchModerationException('這則訊息沒有可用的官方 ID 或來自其他頻道。');
        }
        await api.pinMessage(id, seconds: seconds, update: action == '調整釘選時間');
      }
      if (!mounted || !_current) return;
      setState(() => _result = '釘選操作已提交；目前狀態以 Twitch 回應為準。');
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is TwitchModerationException
              ? error.message
              : '釘選操作未確認，請先重新整理；不要直接重送。',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vio.t;
    final selected = widget.selectedMessage;
    final enabled = !_busy && !_loading && _current && _pins != null;
    return Material(
      color: Colors.transparent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: Text('${t('釘選管理')} · @${widget.channelName}')),
              IconButton(
                tooltip: t('關閉'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Text(t(_error!), style: const TextStyle(color: Colors.redAccent)),
          if (_result != null) Text(t(_result!)),
          if (_pins == null) Text(t('釘選狀態未確認，請重新整理。')),
          if (_pins?.isEmpty == true) Text(t('目前沒有管理員釘選訊息。')),
          Form(
            key: _form,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('直到直播結束')),
                  value: _untilEnd,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _untilEnd = value),
                ),
                TextFormField(
                  controller: _duration,
                  enabled: !_busy && !_untilEnd,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${t('釘選時間')} (30–1800 ${t('秒')})',
                  ),
                  validator: (value) {
                    if (_untilEnd) return null;
                    final seconds = int.tryParse(value?.trim() ?? '');
                    return seconds == null || seconds < 30 || seconds > 1800
                        ? t('請輸入範圍內的整數。')
                        : null;
                  },
                ),
              ],
            ),
          ),
          if (selected != null &&
              twitchCanPinMessage(selected, widget.api.broadcasterId)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('${selected.displayName}：${selected.message}'),
            ),
            OutlinedButton(
              onPressed: enabled ? () => _change('釘選這則訊息') : null,
              child: Text(t('釘選這則訊息')),
            ),
          ],
          for (final pin in _pins ?? <TwitchPinnedChatMessage>[]) ...[
            const Divider(),
            Text('${pin.sender?.displayName ?? ''}：${pin.text}'),
            Text('${t('釘選者')}：${pin.pinnedBy?.displayName ?? ''}'),
            Text(
              pin.endsAt == null
                  ? t('直到直播結束')
                  : '${t('到期時間')} ${pin.endsAt!.toLocal()}',
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: enabled ? () => _change('調整釘選時間', pin: pin) : null,
                  child: Text(t('調整釘選時間')),
                ),
                OutlinedButton(
                  onPressed: enabled ? () => _change('解除釘選', pin: pin) : null,
                  child: Text(t('解除釘選')),
                ),
              ],
            ),
          ],
          TextButton.icon(
            onPressed: _busy || _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            label: Text(t('重新整理')),
          ),
        ],
      ),
    );
  }
}
