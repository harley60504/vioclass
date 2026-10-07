import 'package:flutter/material.dart';

import '../../../../api/moderation/twitch_moderation_api_service.dart';
import '../../../localization/vioclass_localizations.dart';

/// Official role/ban reads are broadcaster-only. Unknown is not false, and
/// historical message badges are never treated as the current role state.
class TwitchUserRoleActions extends StatefulWidget {
  final TwitchModerationApiService api;
  final String userId;
  final String userName;
  final String channelName;
  final ValueChanged<bool?>? onModeratorStatus;
  final ValueChanged<bool>? onBusyChanged;
  final VoidCallback? onRoleWriteAccepted;
  const TwitchUserRoleActions({
    super.key,
    required this.api,
    required this.userId,
    required this.userName,
    required this.channelName,
    this.onModeratorStatus,
    this.onBusyChanged,
    this.onRoleWriteAccepted,
  });
  @override
  State<TwitchUserRoleActions> createState() => _RoleState();
}

class _RoleState extends State<TwitchUserRoleActions> {
  bool? _mod;
  bool? _vip;
  Map<String, dynamic>? _ban;
  bool _banKnown = false;
  bool _loading = true;
  bool _busy = false;
  final _readErrors = <String>[];
  String? _result;
  bool _failed = false;
  int _generation = 0;

  bool get _current =>
      widget.api.canModerate?.call() != false &&
      widget.api.broadcasterId == widget.api.moderatorId;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    widget.onModeratorStatus?.call(null);
    final generation = ++_generation;
    final api = widget.api;
    final userId = widget.userId;
    setState(() {
      _loading = true;
      _mod = null;
      _vip = null;
      _ban = null;
      _banKnown = false;
      _readErrors.clear();
    });
    bool active() => mounted && generation == _generation && _current;
    for (final kind in ['MOD', 'VIP', '封鎖／禁言']) {
      try {
        if (!active()) break;
        if (kind == '封鎖／禁言') {
          final ban = await api.userBanStatus(userId);
          if (active()) {
            setState(() {
              _ban = ban;
              _banKnown = true;
            });
          }
        } else {
          final value = await api.userHasRole(userId, vip: kind == 'VIP');
          if (active()) {
            if (kind == 'MOD') widget.onModeratorStatus?.call(value);
            setState(() {
              if (kind == 'VIP') {
                _vip = value;
              } else {
                _mod = value;
              }
            });
          }
        }
      } catch (error) {
        if (active()) {
          setState(
            () => _readErrors.add(
              '$kind：${error is TwitchModerationException ? error.message : '狀態暫時無法讀取。'}',
            ),
          );
        }
      }
    }
    if (mounted && generation == _generation) setState(() => _loading = false);
  }

  Future<void> _change(bool vip, bool enabled) async {
    if (_busy || !_current) return;
    final api = widget.api;
    final userId = widget.userId;
    final label = enabled
        ? (vip ? '授予 VIP' : '授予 MOD')
        : (vip ? '撤銷 VIP' : '撤銷 MOD');
    widget.onBusyChanged?.call(true);
    setState(() {
      _busy = true;
      _result = null;
      _failed = false;
    });
    var finishing = false;
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.vio.t('確認角色變更')),
          content: SingleChildScrollView(
            child: Text(
              '@${widget.channelName}\n${widget.userName}\n${context.vio.t(label)}\n${context.vio.t('這會變更此人的頻道權限；不會自動撤銷另一角色或解除封鎖。')}',
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
      if (!_current || widget.userId != userId) {
        throw const TwitchModerationException('管理身分或頻道已變更，未送出操作。');
      }
      await api.setUserRole(userId, vip: vip, enabled: enabled);
      if (!mounted) return;
      widget.onRoleWriteAccepted?.call();
      setState(() => _result = '角色操作已提交；目前狀態請以重新整理的 Twitch 回應為準。');
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _result = error is TwitchModerationException
              ? error.message
              : '角色操作暫時失敗，請重新確認。';
        });
      }
    } finally {
      if (mounted) {
        widget.onBusyChanged?.call(false);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vio.t;
    String state(bool? value) => t(
      value == null
          ? '未確認'
          : value
          ? '是'
          : '否',
    );
    final expires = _ban?['expires_at']?.toString() ?? '';
    final banText = !_banKnown
        ? t('未確認')
        : _ban == null
        ? t('未封鎖／禁言')
        : expires.isEmpty
        ? t('已封鎖')
        : '${t('禁言至')} $expires';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text(t('台主角色管理')),
        Text('MOD：${state(_mod)} · VIP：${state(_vip)}'),
        Text('${t('封鎖／禁言')}：$banText'),
        if (_ban?['reason'] case final String reason)
          if (reason.isNotEmpty) Text('${t('原因')}：$reason'),
        if (_loading) const LinearProgressIndicator(),
        for (final error in _readErrors)
          Text(error, style: Theme.of(context).textTheme.bodySmall),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final vip in [false, true]) ...[
              OutlinedButton(
                onPressed:
                    _busy ||
                        _loading ||
                        !_current ||
                        (vip ? _vip : _mod) == true ||
                        (vip ? _mod : _vip) == true ||
                        (_banKnown && _ban != null)
                    ? null
                    : () => _change(vip, true),
                child: Text(t(vip ? '授予 VIP' : '授予 MOD')),
              ),
              OutlinedButton(
                onPressed:
                    _busy ||
                        _loading ||
                        !_current ||
                        (vip ? _vip : _mod) == false
                    ? null
                    : () => _change(vip, false),
                child: Text(t(vip ? '撤銷 VIP' : '撤銷 MOD')),
              ),
            ],
            TextButton.icon(
              onPressed: _busy || _loading || !_current ? null : _refresh,
              icon: const Icon(Icons.refresh),
              label: Text(t('重新整理')),
            ),
          ],
        ),
        if (_result != null)
          Text(
            t(_result!),
            style: TextStyle(
              color: _failed ? Colors.redAccent : Colors.greenAccent,
            ),
          ),
      ],
    );
  }
}
