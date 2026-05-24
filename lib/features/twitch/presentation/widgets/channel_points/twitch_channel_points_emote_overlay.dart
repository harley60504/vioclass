import 'package:flutter/material.dart';

import '../../../api/engagement/twitch_channel_points_api_service.dart';
import '../../theme/twitch_ui_tokens.dart';

const int _channelPointEmoteGridCacheSize = 112;
const int _channelPointModifierCacheSize = 84;

enum ChannelPointEmoteOverlayMode { choose, modify }

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
    final choosingModifier =
        mode == ChannelPointEmoteOverlayMode.modify && base != null;

    return Material(
      color: TwitchUiColors.sheet.scrim,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: TwitchUiColors.sheet.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TwitchUiColors.sheet.cardBorder),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final searchField = SizedBox(
                  height: 38,
                  child: TextField(
                    onChanged: choosingModifier ? null : onQueryChanged,
                    enabled: !choosingModifier,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: choosingModifier ? '選擇修改效果' : '搜尋貼圖名稱',
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
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      filled: true,
                      fillColor: TwitchUiColors.surfaceAlt,
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
                );

                final actionButtons = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                );

                return Container(
                  padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                  decoration: BoxDecoration(
                    color: TwitchUiColors.sheet.background,
                    border: Border(
                      bottom: BorderSide(
                        color: TwitchUiColors.sheet.cardBorder,
                      ),
                    ),
                  ),
                  child: compact
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
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
                                  child: Text(
                                    rewardTitle.isEmpty ? '選擇貼圖' : rewardTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                actionButtons,
                              ],
                            ),
                            const SizedBox(height: 6),
                            searchField,
                          ],
                        )
                      : Row(
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
                            Expanded(child: searchField),
                            const SizedBox(width: 6),
                            actionButtons,
                          ],
                        ),
                );
              },
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? _OverlayMessage(
                      icon: Icons.error_outline_rounded,
                      message: '載入貼圖清單失敗：$error',
                    )
                  : choosingModifier
                  ? _ModifierGrid(emote: base, onSelected: onChooseModifier)
                  : emotes.isEmpty
                  ? const _OverlayMessage(
                      icon: Icons.search_off_rounded,
                      message: '沒有可顯示的 Channel Points 貼圖。',
                    )
                  : _EmoteGrid(emotes: emotes, onSelected: onChooseEmote),
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

  const _EmoteGrid({required this.emotes, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 760
            ? 6
            : constraints.maxWidth >= 560
            ? 5
            : constraints.maxWidth >= 420
            ? 4
            : 3;
        final itemExtent = constraints.maxWidth < 420 ? 96.0 : 108.0;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: itemExtent,
          ),
          itemCount: emotes.length,
          itemBuilder: (context, index) {
            final emote = emotes[index];
            return RepaintBoundary(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(emote),
                child: Container(
                  padding: EdgeInsets.all(constraints.maxWidth < 420 ? 6 : 8),
                  decoration: BoxDecoration(
                    color: TwitchUiColors.sheet.cardFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: TwitchUiColors.sheet.backplate.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: _OptimizedChannelPointEmoteImage(
                            imageUrl: emote.imageUrl,
                            cacheSize: _channelPointEmoteGridCacheSize,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        emote.token,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: constraints.maxWidth < 420 ? 10 : 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ModifierGrid extends StatelessWidget {
  final TwitchChannelPointEmoteOption emote;
  final ValueChanged<TwitchChannelPointEmoteModification> onSelected;

  const _ModifierGrid({required this.emote, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final modifications = emote.modifications;

    if (modifications.isEmpty) {
      return const _OverlayMessage(
        icon: Icons.auto_fix_off_rounded,
        message: '這個貼圖沒有可用的修改效果。',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 760
            ? 5
            : constraints.maxWidth >= 560
            ? 4
            : constraints.maxWidth >= 420
            ? 3
            : 2;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: constraints.maxWidth < 420 ? 104.0 : 114.0,
          ),
          itemCount: modifications.length,
          itemBuilder: (context, index) {
            final modifier = modifications[index];
            return RepaintBoundary(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(modifier),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TwitchUiColors.sheet.cardFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TwitchUiColors.sheet.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: _OptimizedChannelPointEmoteImage(
                            imageUrl: modifier.imageUrl.isNotEmpty
                                ? modifier.imageUrl
                                : emote.imageUrl,
                            cacheSize: _channelPointModifierCacheSize,
                            fallbackIcon: Icons.auto_fix_high_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        modifier.token,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OverlayMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _OverlayMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white30, size: 32),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptimizedChannelPointEmoteImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final int cacheSize;
  final IconData fallbackIcon;

  const _OptimizedChannelPointEmoteImage({
    required this.imageUrl,
    this.width,
    this.height,
    required this.cacheSize,
    this.fallbackIcon = Icons.emoji_emotions,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      return Icon(fallbackIcon, color: Colors.white54);
    }

    return RepaintBoundary(
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.contain,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: Colors.white54),
      ),
    );
  }
}
