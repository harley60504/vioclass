import 'package:flutter/material.dart';
import '../../api/moderation/twitch_moderation_api_service.dart';
import '../../models/chat/twitch_blocked_term.dart';
import '../localization/vioclass_localizations.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

Future<void> showTwitchBlockedTermsSheet({
  required BuildContext context,
  required TwitchModerationApiService api,
  required String channelName,
}) => showTwitchResponsiveSheet<void>(
  context: context,
  builder: (_) => TwitchBlockedTermsPanel(api: api, channelName: channelName),
);

class TwitchBlockedTermsPanel extends StatefulWidget {
  final TwitchModerationApiService api;
  final String channelName;
  const TwitchBlockedTermsPanel({
    super.key,
    required this.api,
    required this.channelName,
  });
  @override
  State<TwitchBlockedTermsPanel> createState() => _TermsState();
}

class _TermsState extends State<TwitchBlockedTermsPanel> {
  final _input = TextEditingController();
  final _filter = TextEditingController();
  final _terms = <String, TwitchBlockedTerm>{};
  final _seenCursors = <String>{};
  String? _cursor;
  String? _error;
  String? _result;
  bool _loading = false;
  bool _busy = false;
  bool _writing = false;
  bool _loaded = false;
  bool get _current => widget.api.canModerate?.call() != false;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _input.dispose();
    _filter.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (_loading || !_current) return;
    final requested = reset ? null : _cursor;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.api.blockedTerms(after: requested);
      if (!mounted || !_current) return;
      setState(() {
        if (reset) {
          _terms.clear();
          _seenCursors.clear();
        }
        for (final term in page.terms) {
          _terms[term.id] = term;
        }
        if (requested != null) _seenCursors.add(requested);
        _cursor = page.cursor;
        if (_cursor != null && _seenCursors.contains(_cursor)) {
          _cursor = null;
          _error = '分頁游標重複，請重新整理以確認完整清單。';
        }
        _loaded = true;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is TwitchModerationException
              ? error.message
              : '封鎖詞暫時載入失敗；已載入清單仍保留。',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _change({TwitchBlockedTerm? remove}) async {
    if (_busy || _loading || !_current) return;
    final text = remove?.text ?? _input.text.trim();
    if (remove == null && (text.runes.length < 2 || text.runes.length > 500)) {
      setState(() => _error = '封鎖詞需為 2–500 字。');
      return;
    }
    final api = widget.api;
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
          title: Text(context.vio.t(remove == null ? '新增封鎖詞' : '移除封鎖詞')),
          content: SingleChildScrollView(
            child: Text(
              '@${widget.channelName}\n$text\n${context.vio.t(remove == null ? '這會影響此頻道之後的聊天訊息。' : '移除後，此詞不再由這項封鎖詞規則攔截。')}',
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
      setState(() => _writing = true);
      if (remove == null) {
        final added = await api.addBlockedTerm(text);
        if (!mounted || !_current) return;
        setState(() {
          _terms[added.id] = added;
          if (_input.text.trim() == text) _input.clear();
        });
      } else {
        await api.removeBlockedTerm(remove.id);
        if (!mounted || !_current) return;
        setState(() => _terms.remove(remove.id));
      }
      setState(() => _result = '封鎖詞操作已由 Twitch 接受。');
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is TwitchModerationException
              ? error.message
              : '封鎖詞操作未確認，請先重新整理；不要直接重送。',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _writing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vio.t;
    final filter = _filter.text.trim().toLowerCase();
    final visible = _terms.values
        .where((term) => term.text.toLowerCase().contains(filter))
        .toList();
    return Material(
      color: Colors.transparent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: Text('${t('封鎖詞管理')} · @${widget.channelName}')),
              IconButton(
                tooltip: t('關閉'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(t('僅顯示 Twitch 提供的非私人封鎖詞；不是完整的 AutoMod 規則。')),
          TextField(
            controller: _input,
            enabled: !_busy,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: t('新增封鎖詞'),
              helperText: t('2–500 字；萬用字元 * 可放在詞首或詞尾。'),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _busy || _loading || !_current
                  ? null
                  : () => _change(),
              icon: const Icon(Icons.add),
              label: Text(t('新增封鎖詞')),
            ),
          ),
          TextField(
            controller: _filter,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: t('搜尋已載入的封鎖詞')),
          ),
          if (_loading || _writing) const LinearProgressIndicator(),
          if (_error != null)
            Text(t(_error!), style: const TextStyle(color: Colors.redAccent)),
          if (_result != null) Text(t(_result!)),
          Text('${t('已載入')} ${_terms.length}'),
          if (_loaded && visible.isEmpty) Text(t('已載入清單沒有符合的封鎖詞。')),
          for (final term in visible)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(term.text),
              subtitle: term.expiresAt == null
                  ? null
                  : Text('${t('到期時間')} ${term.expiresAt!.toLocal()}'),
              trailing: IconButton(
                tooltip: t('移除封鎖詞'),
                onPressed: _busy || _loading || !_current
                    ? null
                    : () => _change(remove: term),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          if (_cursor != null)
            TextButton(
              onPressed: _busy || _loading || !_current
                  ? null
                  : () => _load(reset: false),
              child: Text(t('載入更多')),
            ),
          TextButton.icon(
            onPressed: _busy || _loading || !_current
                ? null
                : () => _load(reset: true),
            icon: const Icon(Icons.refresh),
            label: Text(t('重新整理')),
          ),
        ],
      ),
    );
  }
}
