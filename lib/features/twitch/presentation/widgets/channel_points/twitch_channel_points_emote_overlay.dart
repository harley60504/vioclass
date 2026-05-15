import 'package:flutter/material.dart';

import '../../../api/engagement/twitch_channel_points_api_service.dart';

enum ChannelPointEmoteOverlayMode {
  choose,
  modify,
}

class ChannelPointEmoteMenuOverlay extends StatelessWidget {
  final ChannelPointEmoteOverlayMode mode;
  final String rewardTitle;
  final List<TwitchChannelPointEmoteOption> emotes;
  final TwitchChannelPointEmoteOption? selectedBaseEmote;
  final bool loading;
  final String? error;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onBack;
  final VoidCallback onClose;
  final Future<void> Function() onReload;
  final ValueChanged<TwitchChannelPointEmoteOption> onChooseEmote;
  final ValueChanged<TwitchChannelPointEmoteModification> onChooseModifier;

  const ChannelPointEmoteMenuOverlay({
    required this.mode,
    required this.rewardTitle,
    required this.emotes,
    required this.selectedBaseEmote,
    required this.loading,
    required this.error,
    required this.query,
    required this.onQueryChanged,
    required this.onBack,
    required this.onClose,
    required this.onReload,
    required this.onChooseEmote,
    required this.onChooseModifier,
  });

  @override
  Widget build(BuildContext context) {
    final base = selectedBaseEmote;
    final choosingModifier = mode == ChannelPointEmoteOverlayMode.modify && base != null;
    return Material(
      color: Colors.black.withOpacity(0.36),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 54, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              blurRadius: 22,
              offset: Offset(0, 10),
              color: Color(0x99000000),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
              decoration: const BoxDecoration(
                color: Color(0xFF18181B),
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2D))),
              ),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      tooltip: '返回',
                      visualDensity: VisualDensity.compact,
                      onPressed: onBack,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        onChanged: choosingModifier ? null : onQueryChanged,
                        enabled: !choosingModifier,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: choosingModifier
                              ? '選擇修改效果'
                              : '搜尋名稱或 emote ID',
                          hintStyle: const TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.white54,
                            size: 18,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 34,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0E0E10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: '重新載入',
                    visualDensity: VisualDensity.compact,
                    onPressed: loading ? null : onReload,
                    icon: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                  ),
                  IconButton(
                    tooltip: '關閉',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? _OverlayMessage(
                          icon: Icons.error_outline_rounded,
                          message: '載入 emote 清單失敗：$error',
                        )
                      : choosingModifier
                          ? _ModifierGrid(
                              emote: base,
                              onSelected: onChooseModifier,
                            )
                          : emotes.isEmpty
                              ? const _OverlayMessage(
                                  icon: Icons.search_off_rounded,
                                  message: '沒有可顯示的 Channel Points emote。',
                                )
                              : _EmoteGrid(
                                  emotes: emotes,
                                  onSelected: onChooseEmote,
                                ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmoteGrid extends StatelessWidget {
  final List<TwitchChannelPointEmoteOption> emotes;
  final ValueChanged<TwitchChannelPointEmoteOption> onSelected;

  const _EmoteGrid({
    required this.emotes,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemCount: emotes.length,
      itemBuilder: (context, index) {
        final emote = emotes[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelected(emote),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF242429),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF9146FF).withOpacity(0.22)),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Image.network(
                    emote.imageUrl,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.emoji_emotions,
                      color: Colors.white54,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  emote.token,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  emote.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModifierGrid extends StatelessWidget {
  final TwitchChannelPointEmoteOption emote;
  final ValueChanged<TwitchChannelPointEmoteModification> onSelected;

  const _ModifierGrid({
    required this.emote,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final modifications = emote.modifications;

    if (modifications.isEmpty) {
      return const _OverlayMessage(
        icon: Icons.auto_fix_off_rounded,
        message: '這個 emote 沒有可用的修改效果。',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      itemCount: modifications.length,
      itemBuilder: (context, index) {
        final modifier = modifications[index];
        return Card(
          color: const Color(0xFF242429),
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            onTap: () => onSelected(modifier),
            leading: Image.network(
              modifier.imageUrl.isNotEmpty ? modifier.imageUrl : emote.imageUrl,
              width: 38,
              height: 38,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.auto_fix_high_rounded,
                color: Colors.white54,
              ),
            ),
            title: Text(
              modifier.token,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: Text(
              modifier.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ),
        );
      },
    );
  }
}

class _OverlayMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _OverlayMessage({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white38, size: 44),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
