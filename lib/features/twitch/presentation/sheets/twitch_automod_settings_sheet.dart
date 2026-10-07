import 'package:flutter/material.dart';

import '../../api/moderation/twitch_moderation_api_service.dart';
import '../../models/chat/twitch_automod_settings.dart';
import '../localization/vioclass_localizations.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

Future<void> showTwitchAutomodSettingsSheet({
  required BuildContext context,
  required TwitchModerationApiService api,
  required String channelName,
}) => showTwitchResponsiveSheet<void>(
  context: context,
  builder: (_) =>
      TwitchAutomodSettingsPanel(api: api, channelName: channelName),
);

class TwitchAutomodSettingsPanel extends StatefulWidget {
  final TwitchModerationApiService api;
  final String channelName;
  const TwitchAutomodSettingsPanel({
    super.key,
    required this.api,
    required this.channelName,
  });
  @override
  State<TwitchAutomodSettingsPanel> createState() => _AutomodSettingsState();
}

class _AutomodSettingsState extends State<TwitchAutomodSettingsPanel> {
  TwitchAutomodSettings? _snapshot;
  Map<String, int> _levels = {};
  int _overall = 0;
  bool _custom = false;
  bool _busy = false;
  bool _loading = false;
  bool _locked = false;
  String? _error;
  String? _result;
  bool get _current => widget.api.canModerate?.call() != false;
  Map<String, int> get _changes =>
      _custom ? Map.of(_levels) : {'overall_level': _overall};
  bool get _dirty =>
      _snapshot != null &&
      (_custom
          ? _snapshot!.overallLevel != null ||
                TwitchAutomodSettings.categories.keys.any(
                  (key) => _levels[key] != _snapshot!.levels[key],
                )
          : _snapshot!.overallLevel != _overall);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _install(TwitchAutomodSettings settings) {
    _snapshot = settings;
    _levels = Map.of(settings.levels);
    _overall = settings.overallLevel ?? 0;
    _custom = settings.overallLevel == null;
    _locked = false;
  }

  Future<void> _load() async {
    if (_busy || _loading) return;
    final api = widget.api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_current) throw const TwitchModerationException('管理身分或頻道已變更，未送出操作。');
      final settings = await api.automodSettings();
      if (!mounted || !_current || widget.api != api) return;
      _install(settings);
    } on TwitchModerationException catch (error) {
      if (mounted) {
        _error = error.message;
        _locked = true;
      }
    } catch (_) {
      if (mounted) {
        _error = 'AutoMod 設定暫時無法讀取。';
        _locked = true;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _loading || _locked || !_current || !_dirty) return;
    final api = widget.api;
    final before = _snapshot!;
    final changes = Map<String, int>.unmodifiable(_changes);
    final channelName = widget.channelName;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    var writing = false;
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.vio.t('確認 AutoMod 設定')),
          content: SingleChildScrollView(
            child: Text(
              '@$channelName\n${changes.containsKey('overall_level') ? '${context.vio.t('整體等級')}：${changes['overall_level']}\n${context.vio.t('Twitch 會套用官方建議的分類等級，不是全部分類設成相同數字。')}' : changes.entries.map((e) => '${context.vio.t(TwitchAutomodSettings.categories[e.key]!)}：${e.value}').join('\n')}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.vio.t('取消')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.vio.t('確認')),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      if (!_current || widget.api != api) {
        throw const TwitchModerationException('管理身分或頻道已變更，未送出操作。');
      }
      final latest = await api.automodSettings();
      if (!mounted) return;
      if (!_current || widget.api != api) {
        throw const TwitchModerationException('管理身分或頻道已變更，未送出操作。');
      }
      if (!before.sameAs(latest)) {
        _locked = true;
        throw const TwitchModerationException(
          'AutoMod 設定已被變更，請重新載入後再編輯；草稿尚未送出。',
        );
      }
      writing = true;
      final result = await api.automodSettings(changes: changes);
      if (!mounted || !_current || widget.api != api) return;
      _install(result);
      _result = 'AutoMod 設定已更新，以下是官方回傳的等級。';
    } on TwitchModerationException catch (error) {
      if (mounted) {
        _error = error.message;
        if (writing) _locked = true;
      }
    } catch (_) {
      if (mounted) {
        _error = writing
            ? 'AutoMod 寫入結果未確認，請重新整理；不要直接重送。'
            : 'AutoMod 設定暫時無法讀取。';
        _locked = true;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _level(String key, String title, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: DropdownButtonFormField<int>(
      key: ValueKey('$key:$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.vio.t(title),
        border: const OutlineInputBorder(),
      ),
      items: [
        for (var level = 0; level <= 4; level++)
          DropdownMenuItem(
            value: level,
            child: Text(level == 0 ? '0 · ${context.vio.t('不過濾')}' : '$level'),
          ),
      ],
      onChanged: _busy || _loading || _locked || !_current
          ? null
          : (next) {
              if (next == null) return;
              setState(() {
                if (key == 'overall_level') {
                  _overall = next;
                } else {
                  _levels[key] = next;
                }
              });
            },
    ),
  );

  @override
  Widget build(BuildContext context) => TwitchUnifiedSheetScaffold(
    title: context.vio.t('AutoMod 設定'),
    subtitle: '@${widget.channelName}',
    icon: Icons.shield_outlined,
    loading: _loading,
    onRefresh: _busy || _loading ? null : _load,
    child: ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text(context.vio.t('0 為不過濾，4 為最嚴格。重新載入會以官方設定取代未儲存草稿。')),
        if (_error != null)
          Text(
            context.vio.t(_error!),
            style: const TextStyle(color: Colors.redAccent),
          ),
        if (_result != null) Text(context.vio.t(_result!)),
        if (_snapshot != null) ...[
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              title: Text(context.vio.t('自訂各分類')),
              subtitle: Text(context.vio.t('自訂會送出全部八類，不會把未修改的分類歸零。')),
              value: _custom,
              onChanged: _busy || _loading || _locked || !_current
                  ? null
                  : (value) => setState(() => _custom = value),
            ),
          ),
          if (_custom)
            for (final entry in TwitchAutomodSettings.categories.entries)
              _level(entry.key, entry.value, _levels[entry.key]!)
          else
            _level('overall_level', '整體等級', _overall),
          if (!_custom)
            Text(context.vio.t('Twitch 會套用官方建議的分類等級，不是全部分類設成相同數字。')),
          FilledButton.icon(
            onPressed: _busy || _loading || _locked || !_current || !_dirty
                ? null
                : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(context.vio.t('儲存 AutoMod 設定')),
          ),
        ],
        TextButton.icon(
          onPressed: _busy || _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          label: Text(context.vio.t('重新載入官方設定')),
        ),
      ],
    ),
  );
}
