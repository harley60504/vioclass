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
  final TwitchChannelPointEmoteModification? selectedModifier;
  final bool loading;
  final String? error;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onBack;
  final VoidCallback onClose;
  final Future<void> Function() onReload;
  final ValueChanged<TwitchChannelPointEmoteOption> onChooseEmote;
  final ValueChanged<TwitchChannelPointEmoteModification> onChooseModifier;
  final ValueChanged<TwitchChannelPointEmoteModification> onConfirmModifier;

  const ChannelPointEmoteMenuOverlay({
    super.key,
    required this.mode,
    required this.rewardTitle,
    required this.emotes,
    required this.selectedBaseEmote,
    required this.selectedModifier,
    required this.loading,
    required this.error,
    required this.query,
    required this.onQueryChanged,
    required this.onBack,
    required this.onClose,
    required this.onReload,
    required this.onChooseEmote,
    required this.onChooseModifier,
    required this.onConfirmModifier,
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
                  ? _ModifierGrid(
                      emote: base,
                      selectedModifier: selectedModifier,
                      onSelected: onChooseModifier,
                      onConfirm: onConfirmModifier,
                    )
                  : emotes.isEmpty
                  ? _EmoteEmptyMessage(mode: mode, query: query)
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

class _EmoteEmptyMessage extends StatelessWidget {
  final ChannelPointEmoteOverlayMode? mode;
  final String query;

  const _EmoteEmptyMessage({required this.mode, required this.query});

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;
    if (mode == ChannelPointEmoteOverlayMode.modify && !hasQuery) {
      return const _OverlayMessage(
        icon: Icons.auto_fix_off_rounded,
        message: '這個頻道目前沒有可修改的訂閱貼圖。',
      );
    }
    return _OverlayMessage(
      icon: Icons.search_off_rounded,
      message: hasQuery ? '沒有符合搜尋條件的貼圖' : '沒有符合的 Channel Points 貼圖',
    );
  }
}

class _ModifierGrid extends StatelessWidget {
  final TwitchChannelPointEmoteOption emote;
  final TwitchChannelPointEmoteModification? selectedModifier;
  final ValueChanged<TwitchChannelPointEmoteModification> onSelected;
  final ValueChanged<TwitchChannelPointEmoteModification> onConfirm;

  const _ModifierGrid({
    required this.emote,
    required this.selectedModifier,
    required this.onSelected,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final modifications = emote.modifications;
    final preview = selectedModifier;

    if (modifications.isEmpty) {
      return const _OverlayMessage(
        icon: Icons.auto_fix_off_rounded,
        message: '這個貼圖沒有可用的修改效果。',
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: const Color(0xFFFFF232), width: 2),
                ),
                child: ClipOval(
                  child: _OptimizedChannelPointEmoteImage(
                    imageUrl: preview?.imageUrl ?? emote.imageUrl,
                    cacheSize: _channelPointModifierCacheSize,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                preview?.token ?? emote.token,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final modifier in modifications)
                    _ModifierActionButton(
                      modifier: modifier,
                      selected: modifier.id == preview?.id,
                      onSelected: onSelected,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: preview == null ? null : () => onConfirm(preview),
                  child: const Text('確定'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModifierActionButton extends StatelessWidget {
  final TwitchChannelPointEmoteModification modifier;
  final bool selected;
  final ValueChanged<TwitchChannelPointEmoteModification> onSelected;

  const _ModifierActionButton({
    required this.modifier,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: modifier.token,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onSelected(modifier),
        child: Container(
          width: 56,
          height: 50,
          decoration: BoxDecoration(
            color: selected
                ? TwitchUiColors.primary.withValues(alpha: 0.24)
                : TwitchUiColors.sheet.cardFill,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? TwitchUiColors.primary
                  : TwitchUiColors.sheet.cardBorder,
            ),
          ),
          child: Icon(
            _modifierIcon(modifier.modifierId),
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

IconData _modifierIcon(String modifierId) {
  switch (modifierId.trim().toUpperCase()) {
    case 'BW':
      return Icons.contrast_rounded;
    case 'HF':
      return Icons.flip_rounded;
    case 'SQ':
      return Icons.unfold_less_rounded;
    case 'SG':
      return Icons.thumb_up_alt_rounded;
    case 'TK':
      return Icons.auto_fix_high_rounded;
    default:
      return Icons.auto_fix_high_rounded;
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
  final int cacheSize;

  const _OptimizedChannelPointEmoteImage({
    required this.imageUrl,
    required this.cacheSize,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      return const Icon(Icons.emoji_emotions, color: Colors.white54);
    }

    return RepaintBoundary(
      child: Image.network(
        url,
        fit: BoxFit.contain,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.emoji_emotions, color: Colors.white54),
      ),
    );
  }
}
