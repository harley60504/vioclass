import 'package:flutter/material.dart';

import '../design/twitch_breakpoints.dart';
import '../design/twitch_typography.dart';
import '../settings/twitch_app_font_controller.dart';
import '../settings/twitch_chat_appearance_controller.dart';
import '../settings/twitch_player_settings_controller.dart';
import '../widgets/chat/appearance/twitch_chat_appearance_sheet_widgets.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

enum _TwitchSettingsTab { account, chat, player, appearance }

Future<void> showTwitchAppSettingsSheet({
  required BuildContext context,
  required TwitchChatAppearanceController chatAppearanceController,
  required TwitchPlayerSettingsController playerSettingsController,
  required String Function() viewerLabel,
  required String Function() loginStatus,
  required bool Function() loadingLoginState,
  required Future<void> Function() onLogin,
  required Future<void> Function() onRefreshLogin,
  required Future<void> Function() onLogout,
}) {
  return showTwitchUnifiedSheet<void>(
    context: context,
    title: '設定',
    subtitle: '聊天室與播放器偏好',
    icon: Icons.settings_rounded,
    size: TwitchUnifiedSheetSize.wide,
    showRefresh: false,
    builder: (_) => TwitchAppSettingsSheet(
      chatAppearanceController: chatAppearanceController,
      playerSettingsController: playerSettingsController,
      viewerLabel: viewerLabel,
      loginStatus: loginStatus,
      loadingLoginState: loadingLoginState,
      onLogin: onLogin,
      onRefreshLogin: onRefreshLogin,
      onLogout: onLogout,
    ),
  );
}

class TwitchAppSettingsSheet extends StatefulWidget {
  final TwitchChatAppearanceController chatAppearanceController;
  final TwitchPlayerSettingsController playerSettingsController;
  final String Function() viewerLabel;
  final String Function() loginStatus;
  final bool Function() loadingLoginState;
  final Future<void> Function() onLogin;
  final Future<void> Function() onRefreshLogin;
  final Future<void> Function() onLogout;

  const TwitchAppSettingsSheet({
    super.key,
    required this.chatAppearanceController,
    required this.playerSettingsController,
    required this.viewerLabel,
    required this.loginStatus,
    required this.loadingLoginState,
    required this.onLogin,
    required this.onRefreshLogin,
    required this.onLogout,
  });

  @override
  State<TwitchAppSettingsSheet> createState() => _TwitchAppSettingsSheetState();
}

class _TwitchAppSettingsSheetState extends State<TwitchAppSettingsSheet> {
  _TwitchSettingsTab _tab = _TwitchSettingsTab.account;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final tabs = _SettingsTabSelector(
          selected: _tab,
          compact: compact,
          onChanged: (tab) => setState(() => _tab = tab),
        );
        final content = switch (_tab) {
          _TwitchSettingsTab.account => _AccountSettingsPane(
            viewerLabel: widget.viewerLabel,
            loginStatus: widget.loginStatus,
            loadingLoginState: widget.loadingLoginState,
            onLogin: widget.onLogin,
            onRefreshLogin: widget.onRefreshLogin,
            onLogout: widget.onLogout,
          ),
          _TwitchSettingsTab.chat => _ChatSettingsPane(
            controller: widget.chatAppearanceController,
          ),
          _TwitchSettingsTab.player => _PlayerSettingsPane(
            controller: widget.playerSettingsController,
          ),
          _TwitchSettingsTab.appearance => const _AppearanceSettingsPane(),
        };

        if (compact) {
          return Column(
            children: [
              tabs,
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              Expanded(child: content),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: 184, child: tabs),
            VerticalDivider(
              width: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

class _SettingsTabSelector extends StatelessWidget {
  final _TwitchSettingsTab selected;
  final bool compact;
  final ValueChanged<_TwitchSettingsTab> onChanged;

  const _SettingsTabSelector({
    required this.selected,
    required this.compact,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_SettingsTabMeta>[
      const _SettingsTabMeta(
        tab: _TwitchSettingsTab.account,
        icon: Icons.person_rounded,
        label: 'Account',
        description: '登入與帳號',
      ),
      const _SettingsTabMeta(
        tab: _TwitchSettingsTab.chat,
        icon: Icons.chat_bubble_rounded,
        label: 'Chat',
        description: '聊天室顯示',
      ),
      const _SettingsTabMeta(
        tab: _TwitchSettingsTab.player,
        icon: Icons.play_circle_rounded,
        label: 'Player',
        description: '播放預設',
      ),
      const _SettingsTabMeta(
        tab: _TwitchSettingsTab.appearance,
        icon: Icons.palette_rounded,
        label: 'Appearance',
        description: '字體與外觀',
      ),
    ];

    if (compact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
        child: Row(
          children: [
            for (final item in items) ...[
              _SettingsTabChip(
                item: item,
                selected: selected == item.tab,
                compact: true,
                onTap: () => onChanged(item.tab),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        children: [
          for (final item in items) ...[
            _SettingsTabChip(
              item: item,
              selected: selected == item.tab,
              compact: false,
              onTap: () => onChanged(item.tab),
            ),
            const SizedBox(height: 8),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}

class _SettingsTabMeta {
  final _TwitchSettingsTab tab;
  final IconData icon;
  final String label;
  final String description;

  const _SettingsTabMeta({
    required this.tab,
    required this.icon,
    required this.label,
    required this.description,
  });
}

class _SettingsTabChip extends StatelessWidget {
  final _SettingsTabMeta item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _SettingsTabChip({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : Colors.white70;

    return Material(
      color: selected
          ? const Color(0xFF9146FF).withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: compact ? 118 : double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 9 : 11,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFFBF94FF).withValues(alpha: 0.34)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(item.icon, color: foreground, size: compact ? 18 : 20),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!compact)
                      Text(
                        item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSettingsPane extends StatefulWidget {
  final String Function() viewerLabel;
  final String Function() loginStatus;
  final bool Function() loadingLoginState;
  final Future<void> Function() onLogin;
  final Future<void> Function() onRefreshLogin;
  final Future<void> Function() onLogout;

  const _AccountSettingsPane({
    required this.viewerLabel,
    required this.loginStatus,
    required this.loadingLoginState,
    required this.onLogin,
    required this.onRefreshLogin,
    required this.onLogout,
  });

  @override
  State<_AccountSettingsPane> createState() => _AccountSettingsPaneState();
}

class _AccountSettingsPaneState extends State<_AccountSettingsPane> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.loadingLoginState() || _busy;
    final label = widget.viewerLabel();
    final status = widget.loginStatus();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        _SettingsSection(
          title: 'Twitch 帳號',
          subtitle: '登入狀態與權限檢查',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9146FF).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(
                            0xFFBF94FF,
                          ).withValues(alpha: 0.28),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              color: Color(0xFFBF94FF),
                              size: 20,
                            ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            status,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: loading ? null : () => _run(widget.onLogin),
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('完整登入 / 修復登入'),
                  ),
                  OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () => _run(widget.onRefreshLogin),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('重新檢查'),
                  ),
                  OutlinedButton.icon(
                    onPressed: loading ? null : () => _run(widget.onLogout),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('登出'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatSettingsPane extends StatelessWidget {
  final TwitchChatAppearanceController controller;

  const _ChatSettingsPane({required this.controller});

  @override
  Widget build(BuildContext context) {
    final compact = TwitchBreakpoints.isCompactVertical(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final scale = controller.fontScale;
        final fontSize = TwitchTypography.chatFontSize(scale, compact: compact);
        final emoteSize = TwitchTypography.chatEmoteSize(
          scale,
          compact: compact,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
          children: [
            _SettingsSection(
              title: '聊天室字體',
              subtitle: '直播聊天室與 VOD 聊天回放共用',
              trailing: TextButton.icon(
                onPressed: controller.reset,
                icon: const Icon(Icons.restart_alt_rounded, size: 17),
                label: const Text('重設'),
              ),
              child: Column(
                children: [
                  TwitchChatAppearanceSizeControl(
                    scale: scale,
                    onChanged: controller.setFontScale,
                  ),
                  const SizedBox(height: 10),
                  TwitchChatAppearancePreviewCard(
                    fontSize: fontSize,
                    emoteSize: emoteSize,
                    compact: compact,
                  ),
                  const SizedBox(height: 12),
                  _TrustedDomainsControl(controller: controller),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrustedDomainsControl extends StatefulWidget {
  final TwitchChatAppearanceController controller;

  const _TrustedDomainsControl({required this.controller});

  @override
  State<_TrustedDomainsControl> createState() => _TrustedDomainsControlState();
}

class _TrustedDomainsControlState extends State<_TrustedDomainsControl> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _addDomain() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    await widget.controller.addTrustedPreviewDomain(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final domains = widget.controller.trustedPreviewDomains;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsSwitchRow(
          title: '自動載入連結預覽',
          subtitle: '只會自動載入內建可信網域和你加入的網域',
          value: widget.controller.linkPreviewsEnabled,
          onChanged: widget.controller.setLinkPreviewsEnabled,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addDomain(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '新增可信網域，例如 example.com',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.36),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.09),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.09),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: const BorderSide(color: Color(0xFFBF94FF)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _addDomain,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('加入'),
            ),
          ],
        ),
        if (domains.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final domain in domains)
                InputChip(
                  label: Text(domain),
                  onDeleted: () {
                    widget.controller.removeTrustedPreviewDomain(domain);
                  },
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: const Color(0xFFBF94FF).withValues(alpha: 0.24),
                  ),
                  backgroundColor: const Color(
                    0xFF9146FF,
                  ).withValues(alpha: 0.13),
                  labelStyle: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PlayerSettingsPane extends StatelessWidget {
  final TwitchPlayerSettingsController controller;

  const _PlayerSettingsPane({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
          children: [
            _SettingsSection(
              title: '播放預設',
              subtitle: '下一次進入直播或 VOD 頁面時套用',
              trailing: TextButton.icon(
                onPressed: controller.resetPlayback,
                icon: const Icon(Icons.restart_alt_rounded, size: 17),
                label: const Text('重設'),
              ),
              child: Column(
                children: [
                  _SettingsSliderRow(
                    title: '預設音量',
                    valueLabel: '${controller.volume.round()}%',
                    value: controller.volume,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: controller.setVolume,
                  ),
                  _SettingsSwitchRow(
                    title: '開始時靜音',
                    subtitle: '播放器會保留音量值，但進頁面時先以靜音套用',
                    value: controller.muted,
                    onChanged: controller.setMuted,
                  ),
                  _SettingsSwitchRow(
                    title: '預設顯示聊天室',
                    subtitle: '新開 watch page 時先顯示右側聊天欄',
                    value: controller.chatVisible,
                    onChanged: controller.setChatVisible,
                  ),
                  _SettingsSwitchRow(
                    title: '允許 Android 子母畫面',
                    subtitle: '小窗送到背景或手動按 PiP 時才會進入系統子母畫面',
                    value: controller.androidPipEnabled,
                    onChanged: controller.setAndroidPipEnabled,
                  ),
                  _SettingsSwitchRow(
                    title: '離開 WatchPage 保留小窗',
                    subtitle: '從直播、VOD 或 Clip 回主畫面時保留 app 內小窗',
                    value: controller.homeKeepsMiniPlayer,
                    onChanged: controller.setHomeKeepsMiniPlayer,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AppearanceSettingsPane extends StatelessWidget {
  const _AppearanceSettingsPane();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: twitchAppFontController,
      builder: (context, _) {
        final controller = twitchAppFontController;
        final choices = controller.choices;

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
          children: [
            _SettingsSection(
              title: 'App 字體',
              subtitle: 'Windows 和 Android 會套用同一個選擇',
              trailing: TextButton.icon(
                onPressed: controller.picking
                    ? null
                    : controller.pickAndSelectFont,
                icon: controller.picking
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded, size: 17),
                label: Text(controller.picking ? '匯入中' : '匯入字體'),
              ),
              child: Column(
                children: [
                  for (final choice in choices) ...[
                    _SettingsFontChoiceRow(
                      choice: choice,
                      selected: choice.id == controller.selectedId,
                      onTap: () => controller.select(choice),
                      onDelete: choice.kind == TwitchAppFontKind.custom
                          ? () => controller.removeCustomFont(choice.family!)
                          : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      '預覽：聊天室中文字體、標題和按鈕會一起套用。',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsFontChoiceRow extends StatelessWidget {
  final TwitchAppFontChoice choice;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _SettingsFontChoiceRow({
    required this.choice,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selected ? const Color(0xFFBF94FF) : Colors.white38;
    final subtitle = switch (choice.kind) {
      TwitchAppFontKind.vioClass => '內建 Noto Sans TC，跨平台一致',
      TwitchAppFontKind.system => '使用裝置預設字體',
      TwitchAppFontKind.custom => '自訂匯入字體',
    };

    return Material(
      color: selected
          ? const Color(0xFF9146FF).withValues(alpha: 0.16)
          : Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      choice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: choice.kind == TwitchAppFontKind.system
                            ? null
                            : choice.family,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: '移除字體',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  const _SettingsSection({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle case final subtitleText?) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitleText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SettingsSliderRow extends StatelessWidget {
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SettingsSliderRow({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
