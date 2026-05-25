import 'package:flutter/material.dart';

import '../../models/special_actions/twitch_viewer_special_message_models.dart';
import '../theme/twitch_ui_tokens.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

Future<void> showTwitchSpecialMessageSheetStage251({
  required BuildContext context,
  required TwitchViewerSpecialMessagesSnapshotStage251? initialSnapshot,
  required bool loading,
  required Future<TwitchViewerSpecialMessagesSnapshotStage251?> Function()
  onRefresh,
  required void Function(TwitchWatchStreakStatusStage251 status)
  onShareWatchStreak,
  required void Function(TwitchResubNotificationStage251 resub) onShareResub,
  required Future<bool> Function(TwitchChatIdentityBadgeStage251 badge)
  onSelectBadge,
  required VoidCallback onOpenDebugProbe,
}) {
  return showTwitchResponsiveSheet<void>(
    context: context,
    size: TwitchUnifiedSheetSize.large,
    builder: (_) => _TwitchSpecialMessageSheetStage251(
      initialSnapshot: initialSnapshot,
      loading: loading,
      onRefresh: onRefresh,
      onShareWatchStreak: onShareWatchStreak,
      onShareResub: onShareResub,
      onSelectBadge: onSelectBadge,
      onOpenDebugProbe: onOpenDebugProbe,
    ),
  );
}

class _TwitchSpecialMessageSheetStage251 extends StatefulWidget {
  final TwitchViewerSpecialMessagesSnapshotStage251? initialSnapshot;
  final bool loading;
  final Future<TwitchViewerSpecialMessagesSnapshotStage251?> Function()
  onRefresh;
  final void Function(TwitchWatchStreakStatusStage251 status)
  onShareWatchStreak;
  final void Function(TwitchResubNotificationStage251 resub) onShareResub;
  final Future<bool> Function(TwitchChatIdentityBadgeStage251 badge)
  onSelectBadge;
  final VoidCallback onOpenDebugProbe;

  const _TwitchSpecialMessageSheetStage251({
    required this.initialSnapshot,
    required this.loading,
    required this.onRefresh,
    required this.onShareWatchStreak,
    required this.onShareResub,
    required this.onSelectBadge,
    required this.onOpenDebugProbe,
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

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot;
    _loading = widget.loading;
    if (_snapshot == null && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return TwitchUnifiedSheetScaffold(
      title: 'Special Messages',
      subtitle: 'Watch Streak / Resub / Chat Identity',
      icon: Icons.auto_awesome_rounded,
      loading: _loading,
      onRefresh: _loading ? null : _refresh,
      trailing: <Widget>[
        _TwitchSpecialMessageDebugButton(onPressed: widget.onOpenDebugProbe),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_errorText != null) _ErrorBox(text: _errorText!),
            Expanded(
              child: snapshot == null && _loading
                  ? const Center(child: CircularProgressIndicator())
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
                        _BadgeSection(
                          snapshot: snapshot,
                          selectingBadgeId: _selectingBadgeId,
                          onSelectBadge: _selectBadge,
                        ),
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
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final snapshot = await widget.onRefresh();
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectBadge(TwitchChatIdentityBadgeStage251 badge) async {
    setState(() {
      _selectingBadgeId = badge.id;
      _errorText = null;
    });
    try {
      final ok = await widget.onSelectBadge(badge);
      if (!mounted) return;
      if (ok) {
        final snapshot = await widget.onRefresh();
        if (!mounted) return;
        setState(() => _snapshot = snapshot);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.toString());
    } finally {
      if (mounted) setState(() => _selectingBadgeId = null);
    }
  }
}

class _TwitchSpecialMessageDebugButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _TwitchSpecialMessageDebugButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Debug',
      child: InkWell(
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        onTap: onPressed,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TwitchUiColors.sheet.cardFill,
            shape: BoxShape.circle,
            border: Border.all(color: TwitchUiColors.sheet.cardBorder),
          ),
          child: const Icon(
            Icons.science_rounded,
            color: TwitchUiColors.primarySoft,
            size: 19,
          ),
        ),
      ),
    );
  }
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
    final watchStreak = snapshot?.watchStreak;
    final resub = snapshot?.resub;

    return _Section(
      title: 'Shareable Messages',
      children: <Widget>[
        _ActionTile(
          icon: Icons.local_fire_department_rounded,
          title: _watchStreakTitle(watchStreak),
          subtitle: watchStreak?.canShare == true
              ? 'Ready to share your watch streak message'
              : 'No shareable watch streak message right now',
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
          title: _resubTitle(resub),
          subtitle: _resubSubtitle(resub),
          value: resub?.cumulativeMonths == null
              ? null
              : '${resub!.cumulativeMonths} mo',
          enabled: resub?.canShare ?? false,
          onTap: resub == null ? null : () => onShareResub(resub),
        ),
      ],
    );
  }

  String _watchStreakTitle(TwitchWatchStreakStatusStage251? status) {
    final count = status?.streakCount;
    if (count != null && count > 0) {
      return 'Watch Streak $count${status!.unitLabel}';
    }
    return 'Watch Streak';
  }

  String _resubTitle(TwitchResubNotificationStage251? resub) {
    final months = resub?.cumulativeMonths;
    if (months != null && months > 0) return 'Resub $months mo';
    return 'Resub Message';
  }

  String _resubSubtitle(TwitchResubNotificationStage251? resub) {
    if (resub == null) return 'No shareable Resub message right now';
    final parts = <String>[];
    final streak = resub.streakMonths;
    final duration = resub.durationMonths;
    if (streak != null && streak > 0) parts.add('streak $streak mo');
    if (duration != null && duration > 0) parts.add('duration $duration mo');
    final plan = resub.subPlan?.trim();
    if (plan != null && plan.isNotEmpty) parts.add(plan);
    if (parts.isNotEmpty) return parts.join(' / ');
    return resub.canShare
        ? 'Ready to share your Resub message'
        : 'No shareable Resub message right now';
  }
}

class _BadgeSection extends StatelessWidget {
  final TwitchViewerSpecialMessagesSnapshotStage251? snapshot;
  final String? selectingBadgeId;
  final void Function(TwitchChatIdentityBadgeStage251 badge) onSelectBadge;

  const _BadgeSection({
    required this.snapshot,
    required this.selectingBadgeId,
    required this.onSelectBadge,
  });

  @override
  Widget build(BuildContext context) {
    final badges =
        snapshot?.chatIdentity?.badges ??
        const <TwitchChatIdentityBadgeStage251>[];

    return _Section(
      title: 'Chat Identity Badges',
      children: <Widget>[
        if (badges.isEmpty)
          Text(
            'No switchable badges loaded yet.',
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
      title: 'Backend Notes',
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
  final VoidCallback onTap;

  const _BadgeChoice({
    required this.badge,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = badge.imageUrl?.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: busy ? null : onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: badge.selected
              ? TwitchUiColors.sheet.cardFillActive
              : TwitchUiColors.sheet.cardFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: badge.selected
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
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : imageUrl == null || imageUrl.isEmpty
                  ? const Icon(
                      Icons.workspace_premium_rounded,
                      color: TwitchUiColors.textSecondary,
                      size: 22,
                    )
                  : Image.network(imageUrl, fit: BoxFit.contain),
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
