import 'package:flutter/material.dart';

import '../../api/chat/twitch_chat_identity_api_service.dart';
import '../../models/special_actions/twitch_viewer_special_message_models.dart';
import '../localization/vioclass_localizations.dart';
import '../theme/twitch_ui_tokens.dart';
import '../widgets/chat/twitch_chat_text_style.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

Future<void> showTwitchSpecialMessageSheetStage251({
  required BuildContext context,
  required TwitchViewerSpecialMessagesSnapshotStage251? initialSnapshot,
  required bool loading,
  String viewerName = 'You',
  String initialColor = '',
  Future<void> Function(String color)? onSetColor,
  Future<void> Function()? onOpenModeration,
  required Future<TwitchViewerSpecialMessagesSnapshotStage251?> Function()
  onRefresh,
  required void Function(TwitchWatchStreakStatusStage251 status)
  onShareWatchStreak,
  required void Function(TwitchResubNotificationStage251 resub) onShareResub,
  required Future<bool> Function(TwitchChatIdentityBadgeStage251 badge)
  onSelectBadge,
}) {
  return showTwitchResponsiveSheet<void>(
    context: context,
    size: TwitchUnifiedSheetSize.large,
    builder: (_) => _TwitchSpecialMessageSheetStage251(
      initialSnapshot: initialSnapshot,
      loading: loading,
      viewerName: viewerName,
      initialColor: initialColor,
      onSetColor: onSetColor,
      onOpenModeration: onOpenModeration,
      onRefresh: onRefresh,
      onShareWatchStreak: onShareWatchStreak,
      onShareResub: onShareResub,
      onSelectBadge: onSelectBadge,
    ),
  );
}

class _TwitchSpecialMessageSheetStage251 extends StatefulWidget {
  final TwitchViewerSpecialMessagesSnapshotStage251? initialSnapshot;
  final bool loading;
  final String viewerName;
  final String initialColor;
  final Future<void> Function(String color)? onSetColor;
  final Future<void> Function()? onOpenModeration;
  final Future<TwitchViewerSpecialMessagesSnapshotStage251?> Function()
  onRefresh;
  final void Function(TwitchWatchStreakStatusStage251 status)
  onShareWatchStreak;
  final void Function(TwitchResubNotificationStage251 resub) onShareResub;
  final Future<bool> Function(TwitchChatIdentityBadgeStage251 badge)
  onSelectBadge;

  const _TwitchSpecialMessageSheetStage251({
    required this.initialSnapshot,
    required this.loading,
    required this.viewerName,
    required this.initialColor,
    required this.onSetColor,
    required this.onOpenModeration,
    required this.onRefresh,
    required this.onShareWatchStreak,
    required this.onShareResub,
    required this.onSelectBadge,
  });

  @override
  State<_TwitchSpecialMessageSheetStage251> createState() =>
      _TwitchSpecialMessageSheetStage251State();
}

class _TwitchSpecialMessageSheetStage251State
    extends State<_TwitchSpecialMessageSheetStage251> {
  TwitchViewerSpecialMessagesSnapshotStage251? _snapshot;
  bool _loading = false;
  String? _errorText;
  String? _selectingBadgeId;
  String? _pendingBadgeId;
  String? _pendingBadgeChannel;
  TwitchChatIdentityBadgeStage251? _draftBadge;
  late final TextEditingController _hexController;
  String? _namedColor;
  bool _applyingColor = false;
  String? _identityStatus;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot;
    _loading = widget.loading;
    _hexController = TextEditingController(text: widget.initialColor);
    if (_snapshot == null && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final l10n = context.vio;

    return TwitchUnifiedSheetScaffold(
      title: l10n.t('聊天身分與互動'),
      subtitle: l10n.t('ID 顏色、徽章、續訂與連續觀看'),
      icon: Icons.auto_awesome_rounded,
      loading: _loading,
      onRefresh: _loading || _selectingBadgeId != null || _applyingColor
          ? null
          : _refresh,
      child: TwitchChatTextScope(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_errorText != null) _ErrorBox(text: _errorText!),
              Expanded(
                child: snapshot == null && _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: TwitchUiColors.primarySoft,
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 8),
                        children: <Widget>[
                          _ShareSection(
                            snapshot: snapshot,
                            onShareWatchStreak: (status) {
                              widget.onShareWatchStreak(status);
                              Navigator.of(context).maybePop();
                            },
                            onShareResub: (resub) {
                              widget.onShareResub(resub);
                              Navigator.of(context).maybePop();
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildIdentityPreview(),
                          const SizedBox(height: 12),
                          _BadgeSection(
                            snapshot: snapshot,
                            selectingBadgeId: _selectingBadgeId,
                            draftBadgeId: _draftBadge?.id,
                            onSelectBadge: (badge) {
                              if (_selectingBadgeId != null ||
                                  _loading ||
                                  _applyingColor) {
                                return;
                              }
                              setState(() {
                                _draftBadge = badge;
                                _identityStatus = null;
                              });
                            },
                          ),
                          if (_draftBadge != null) ...[
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed:
                                  _selectingBadgeId != null ||
                                      _loading ||
                                      _applyingColor
                                  ? null
                                  : () => _selectBadge(_draftBadge!),
                              icon: const Icon(Icons.check_rounded),
                              label: Text(l10n.t('套用徽章')),
                            ),
                          ],
                          if (widget.onOpenModeration != null) ...[
                            const SizedBox(height: 12),
                            _Section(
                              title: l10n.t('聊天室管理'),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.shield_outlined),
                                  title: Text(l10n.t('管理員與台主工具')),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap:
                                      _loading ||
                                          _selectingBadgeId != null ||
                                          _applyingColor
                                      ? null
                                      : widget.onOpenModeration,
                                ),
                              ],
                            ),
                          ],
                          if (snapshot?.hasIssues ?? false) ...<Widget>[
                            const SizedBox(height: 12),
                            _IssuesSection(snapshot: snapshot!),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    if (_loading || _selectingBadgeId != null || _applyingColor) return;
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final snapshot = await widget.onRefresh();
      if (!mounted) return;
      setState(() {
        if (_pendingBadgeId == null) {
          _snapshot = snapshot;
        } else {
          _confirmPendingBadge(snapshot);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorText = context.vio.t(
          _pendingBadgeId == null
              ? '特殊訊息暫時載入失敗，稍後再試。'
              : '徽章套用已提交，但身分重新載入失敗；請重新整理確認，勿直接重複套用。',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectBadge(TwitchChatIdentityBadgeStage251 badge) async {
    if (_selectingBadgeId != null || _loading || _applyingColor) return;
    var accepted = false;
    final channel = _snapshot?.channelLogin;
    setState(() {
      _selectingBadgeId = badge.id;
      _errorText = null;
    });
    try {
      final ok = await widget.onSelectBadge(badge);
      if (!mounted) return;
      if (ok) {
        accepted = true;
        setState(() {
          _draftBadge = null;
          _pendingBadgeId = badge.id;
          _pendingBadgeChannel = channel;
          _identityStatus = context.vio.t('徽章套用已提交；請重新整理確認目前配戴。');
        });
        final snapshot = await widget.onRefresh();
        if (!mounted) return;
        setState(() {
          _draftBadge = null;
          _confirmPendingBadge(snapshot);
        });
      } else {
        setState(() => _errorText = context.vio.t('聊天室身分更新失敗，稍後再試。'));
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorText = context.vio.t(
          accepted ? '徽章套用已提交，但身分重新載入失敗；請重新整理確認，勿直接重複套用。' : '聊天室身分更新失敗，稍後再試。',
        ),
      );
    } finally {
      if (mounted) setState(() => _selectingBadgeId = null);
    }
  }

  void _confirmPendingBadge(
    TwitchViewerSpecialMessagesSnapshotStage251? snapshot,
  ) {
    if (_pendingBadgeId == null) return;
    final sameChannel =
        snapshot != null && snapshot.channelLogin == _pendingBadgeChannel;
    if (sameChannel) _snapshot = snapshot;
    final confirmed =
        sameChannel &&
        snapshot.chatIdentity?.selectedBadge?.id == _pendingBadgeId;
    if (_draftBadge == null) {
      _identityStatus = context.vio.t(
        confirmed ? '已套用徽章' : '徽章套用已提交；請重新整理確認目前配戴。',
      );
    }
    if (confirmed) {
      _pendingBadgeId = null;
      _pendingBadgeChannel = null;
    }
  }

  Widget _buildIdentityPreview() {
    final badge = _draftBadge ?? _snapshot?.chatIdentity?.selectedBadge;
    final hex = _hexController.text.trim();
    final value = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)
        ? int.parse(hex.substring(1), radix: 16)
        : 0xB99AFF;
    final color = Color(0xFF000000 | value);
    final l10n = context.vio;
    return _Section(
      title: l10n.t('聊天室身分預覽'),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: TwitchUiColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (badge != null) ...[
                _badgeImage(badge, 22),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  widget.viewerName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(l10n.t('這是訊息預覽'), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(l10n.t('ID 顏色（套用到 Twitch）')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _chatColors.entries.map((entry) {
            final selected = hex.toUpperCase() == entry.value.toUpperCase();
            return Tooltip(
              message: entry.key,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _applyingColor || _loading || _selectingBadgeId != null
                    ? null
                    : () => setState(() {
                        _namedColor = entry.key;
                        _hexController.text = entry.value;
                        _identityStatus = null;
                      }),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(
                      0xFF000000 |
                          int.parse(entry.value.substring(1), radix: 16),
                    ),
                    border: Border.all(
                      color: selected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _hexController,
          enabled: !_applyingColor && !_loading && _selectingBadgeId == null,
          maxLength: 7,
          decoration: InputDecoration(
            labelText: l10n.t('自訂色碼（Prime／Turbo）'),
            hintText: '#9146FF',
            errorText:
                hex.isNotEmpty && !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)
                ? l10n.t('請輸入 # 加上六位色碼')
                : null,
          ),
          onChanged: (_) => setState(() {
            _namedColor = null;
            _identityStatus = null;
          }),
        ),
        FilledButton.icon(
          onPressed:
              _applyingColor ||
                  _loading ||
                  _selectingBadgeId != null ||
                  widget.onSetColor == null ||
                  !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)
              ? null
              : _applyColor,
          icon: _applyingColor
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.palette_outlined),
          label: Text(l10n.t('套用 ID 顏色')),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.t('預覽不會立即修改身分；按套用後才更新。此處僅列出 Twitch 可用徽章。'),
          style: const TextStyle(
            fontSize: 12,
            color: TwitchUiColors.textSecondary,
          ),
        ),
        if (_identityStatus != null)
          Text(
            _identityStatus!,
            style: const TextStyle(color: TwitchUiColors.primarySoft),
          ),
      ],
    );
  }

  Future<void> _applyColor() async {
    if (_applyingColor ||
        _loading ||
        _selectingBadgeId != null ||
        widget.onSetColor == null) {
      return;
    }
    setState(() {
      _applyingColor = true;
      _errorText = null;
      _identityStatus = null;
    });
    try {
      await widget.onSetColor!(_namedColor ?? _hexController.text.trim());
      if (mounted) {
        setState(() => _identityStatus = context.vio.t('ID 顏色已更新；新訊息會使用新顏色。'));
      }
    } on TwitchChatColorException catch (error) {
      if (mounted) setState(() => _errorText = context.vio.t(error.message));
    } catch (_) {
      if (mounted) {
        setState(() => _errorText = context.vio.t('ID 顏色更新失敗，請稍後再試。'));
      }
    } finally {
      if (mounted) setState(() => _applyingColor = false);
    }
  }
}

const _chatColors = <String, String>{
  'blue': '#0000FF',
  'blue_violet': '#8A2BE2',
  'cadet_blue': '#5F9EA0',
  'chocolate': '#D2691E',
  'coral': '#FF7F50',
  'dodger_blue': '#1E90FF',
  'firebrick': '#B22222',
  'golden_rod': '#DAA520',
  'green': '#008000',
  'hot_pink': '#FF69B4',
  'orange_red': '#FF4500',
  'red': '#FF0000',
  'sea_green': '#2E8B57',
  'spring_green': '#00FF7F',
  'yellow_green': '#9ACD32',
};

Widget _badgeImage(TwitchChatIdentityBadgeStage251 badge, double size) {
  final url = badge.imageUrl;
  return SizedBox(
    width: size,
    height: size,
    child: url == null || url.isEmpty
        ? Icon(Icons.workspace_premium_rounded, size: size)
        : Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                Icon(Icons.workspace_premium_rounded, size: size),
          ),
  );
}

class _ShareSection extends StatelessWidget {
  final TwitchViewerSpecialMessagesSnapshotStage251? snapshot;
  final void Function(TwitchWatchStreakStatusStage251 status)
  onShareWatchStreak;
  final void Function(TwitchResubNotificationStage251 resub) onShareResub;

  const _ShareSection({
    required this.snapshot,
    required this.onShareWatchStreak,
    required this.onShareResub,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    final watchStreak = snapshot?.watchStreak;
    final resub = snapshot?.resub;

    return _Section(
      title: l10n.t('可分享訊息'),
      children: <Widget>[
        _ActionTile(
          icon: Icons.local_fire_department_rounded,
          title: _watchStreakTitle(watchStreak, l10n),
          subtitle: watchStreak?.canShare == true
              ? l10n.t('可以分享你的連續觀看訊息')
              : l10n.t('目前沒有可分享的連續觀看訊息'),
          value: watchStreak?.streakCount == null
              ? null
              : '${watchStreak!.streakCount}${watchStreak.unitLabel}',
          enabled: watchStreak?.canShare ?? false,
          onTap: watchStreak == null
              ? null
              : () => onShareWatchStreak(watchStreak),
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.workspace_premium_rounded,
          title: _resubTitle(resub, l10n),
          subtitle: _resubSubtitle(resub, l10n),
          value: resub?.cumulativeMonths == null
              ? null
              : '${resub!.cumulativeMonths} ${l10n.t('個月')}',
          enabled: resub?.canShare ?? false,
          onTap: resub == null ? null : () => onShareResub(resub),
        ),
      ],
    );
  }

  String _watchStreakTitle(
    TwitchWatchStreakStatusStage251? status,
    VioClassLocalizations l10n,
  ) {
    final count = status?.streakCount;
    if (count != null && count > 0) {
      return '${l10n.t('連續觀看')} $count${status!.unitLabel}';
    }
    return l10n.t('連續觀看');
  }

  String _resubTitle(
    TwitchResubNotificationStage251? resub,
    VioClassLocalizations l10n,
  ) {
    final months = resub?.cumulativeMonths;
    if (months != null && months > 0) {
      return '${l10n.t('續訂')} $months ${l10n.t('個月')}';
    }
    return l10n.t('續訂訊息');
  }

  String _resubSubtitle(
    TwitchResubNotificationStage251? resub,
    VioClassLocalizations l10n,
  ) {
    if (resub == null) return l10n.t('目前沒有可分享的續訂訊息');
    final parts = <String>[];
    final streak = resub.streakMonths;
    final duration = resub.durationMonths;
    if (streak != null && streak > 0) {
      parts.add('${l10n.t('連續')} $streak ${l10n.t('個月')}');
    }
    if (duration != null && duration > 0) {
      parts.add('${l10n.t('本次')} $duration ${l10n.t('個月')}');
    }
    final plan = resub.subPlan?.trim();
    if (plan != null && plan.isNotEmpty) parts.add(plan);
    if (parts.isNotEmpty) return parts.join(' / ');
    return resub.canShare ? l10n.t('可以分享你的續訂訊息') : l10n.t('目前沒有可分享的續訂訊息');
  }
}

class _BadgeSection extends StatelessWidget {
  final TwitchViewerSpecialMessagesSnapshotStage251? snapshot;
  final String? selectingBadgeId;
  final String? draftBadgeId;
  final void Function(TwitchChatIdentityBadgeStage251 badge) onSelectBadge;

  const _BadgeSection({
    required this.snapshot,
    required this.selectingBadgeId,
    required this.draftBadgeId,
    required this.onSelectBadge,
  });

  @override
  Widget build(BuildContext context) {
    final badges =
        snapshot?.chatIdentity?.badges ??
        const <TwitchChatIdentityBadgeStage251>[];

    return _Section(
      title: context.vio.t('聊天室身分徽章'),
      children: <Widget>[
        if (badges.isNotEmpty) ...[
          Text(
            context.vio.t('點選徽章可預覽，再按「套用徽章」。眼睛代表預覽，勾勾代表目前配戴。'),
            style: const TextStyle(
              color: TwitchUiColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (badges.isEmpty)
          Text(
            context.vio.t('目前沒有可切換的徽章'),
            style: TextStyle(
              color: TwitchUiColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges
                .map(
                  (badge) => _BadgeChoice(
                    badge: badge,
                    busy: selectingBadgeId == badge.id,
                    previewSelected: draftBadgeId == badge.id,
                    enabled: selectingBadgeId == null,
                    onTap: () => onSelectBadge(badge),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _IssuesSection extends StatelessWidget {
  final TwitchViewerSpecialMessagesSnapshotStage251 snapshot;

  const _IssuesSection({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: context.vio.t('系統提示'),
      children: snapshot.issues
          .map(
            (issue) => Text(
              '${issue.area}: ${issue.message}',
              style: const TextStyle(
                color: Color(0xFFFFB4AB),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TwitchUiColors.sheet.cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TwitchUiColors.sheet.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: TwitchUiColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? value;
  final bool enabled;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.value,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: enabled
              ? TwitchUiColors.sheet.backplate.fill
              : TwitchUiColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? TwitchUiColors.sheet.backplate.border
                : TwitchUiColors.sheet.cardBorder,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              color: enabled
                  ? TwitchUiColors.sheet.backplate.foreground
                  : TwitchUiColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled
                          ? TwitchUiColors.textPrimary
                          : TwitchUiColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled
                          ? TwitchUiColors.textSecondary
                          : TwitchUiColors.textFaint,
                      fontSize: 11.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (value != null) ...<Widget>[
              const SizedBox(width: 8),
              Text(
                value!,
                style: TextStyle(
                  color: enabled
                      ? TwitchUiColors.sheet.backplate.foreground
                      : TwitchUiColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeChoice extends StatelessWidget {
  final TwitchChatIdentityBadgeStage251 badge;
  final bool busy;
  final bool previewSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _BadgeChoice({
    required this.badge,
    required this.busy,
    required this.previewSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = badge.imageUrl?.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: busy || !enabled ? null : onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: previewSelected || badge.selected
              ? TwitchUiColors.sheet.cardFillActive
              : TwitchUiColors.sheet.cardFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: previewSelected || badge.selected
                ? TwitchUiColors.sheet.cardBorderActive
                : TwitchUiColors.sheet.cardBorder,
          ),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              height: 28,
              child: busy
                  ? const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TwitchUiColors.primarySoft,
                    )
                  : imageUrl == null || imageUrl.isEmpty
                  ? const Icon(
                      Icons.workspace_premium_rounded,
                      color: TwitchUiColors.textSecondary,
                      size: 22,
                    )
                  : _badgeImage(badge, 28),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                badge.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: badge.selected
                      ? TwitchUiColors.textPrimary
                      : TwitchUiColors.textSecondary,
                  fontSize: 11.5,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (previewSelected || badge.selected)
              Icon(
                previewSelected
                    ? Icons.visibility_outlined
                    : Icons.check_circle,
                size: 15,
                color: TwitchUiColors.primarySoft,
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;

  const _ErrorBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFB4AB),
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
