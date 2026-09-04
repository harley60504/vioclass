import 'package:flutter/material.dart';

import '../../../api/engagement/twitch_channel_points_api_service.dart';
import '../../localization/vioclass_localizations.dart';
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
    final l10n = context.vio;
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
                      hintText: l10n.t(
                        choosingModifier ? '選擇修改效果' : '搜尋貼圖名稱',
                      ),
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
                      tooltip: l10n.t('重新載入'),
                      visualDensity: VisualDensity.compact,
                      onPressed: loading ? null : onReload,
                      icon: loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: TwitchUiColors.primarySoft,
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                    ),
                    IconButton(
                      tooltip: l10n.t('關閉'),
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
                                    tooltip: l10n.t('返回'),
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
                                    rewardTitle.isEmpty
                                        ? l10n.t('選擇貼圖')
                                        : rewardTitle,
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
                                tooltip: l10n.t('返回'),
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
                  ? _OverlayLoadingMessage(message: l10n.t('正在讀取貼圖清單...'))
                  : error != null
                  ? _OverlayMessage(
                      icon: Icons.error_outline_rounded,
                      message: l10n.t('貼圖清單暫時載入失敗，稍後再試。'),
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
      return _OverlayMessage(
        icon: Icons.auto_fix_off_rounded,
        message: context.vio.t('這個頻道目前沒有可修改的訂閱貼圖。'),
      );
    }
    return _OverlayMessage(
      icon: Icons.search_off_rounded,
      message: context.vio.t(
        hasQuery ? '沒有符合搜尋條件的貼圖' : '沒有符合的 Channel Points 貼圖',
      ),
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
      return _OverlayMessage(
        icon: Icons.auto_fix_off_rounded,
        message: context.vio.t('這個貼圖沒有可用的修改效果。'),
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
                  child: Text(context.vio.t('選擇')),
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
      message: context.vio.t(_modifierLabel(_modifierKey(modifier))),
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
          child: Center(child: _modifierIconWidget(modifier)),
        ),
      ),
    );
  }
}

Widget _modifierIconWidget(TwitchChannelPointEmoteModification modifier) {
  switch (_modifierKey(modifier)) {
    case 'BW':
      return const SizedBox(
        width: 24,
        height: 24,
        child: CustomPaint(painter: _BlackWhiteModifierPainter()),
      );
    case 'HF':
      return const SizedBox(
        width: 24,
        height: 24,
        child: CustomPaint(painter: _HorizontalFlipModifierPainter()),
      );
    case 'SQ':
      return const SizedBox(
        width: 25,
        height: 20,
        child: CustomPaint(painter: _SquishModifierPainter()),
      );
    case 'SG':
      return const SizedBox(
        width: 27,
        height: 18,
        child: CustomPaint(painter: _SunglassesModifierPainter()),
      );
    case 'TK':
      return const SizedBox(
        width: 27,
        height: 22,
        child: CustomPaint(painter: _ThinkingHandModifierPainter()),
      );
    default:
      return Icon(
        _modifierIcon(modifier.modifierId),
        color: Colors.white,
        size: 24,
      );
  }
}

String _modifierKey(TwitchChannelPointEmoteModification modifier) {
  final candidates = <String>[
    modifier.modifierId,
    modifier.id,
    modifier.token,
  ].map((value) => value.trim().toUpperCase());

  for (final value in candidates) {
    final compact = value.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (value == 'BW' ||
        value.endsWith('_BW') ||
        compact.endsWith('BW') ||
        compact.contains('BLACKWHITE') ||
        compact.contains('GRAYSCALE') ||
        compact.contains('GREYSCALE')) {
      return 'BW';
    }
    if (value == 'HF' ||
        value.endsWith('_HF') ||
        compact.endsWith('HF') ||
        compact.contains('HORIZONTALFLIP') ||
        compact.contains('FLIPHORIZONTAL')) {
      return 'HF';
    }
    if (value == 'SQ' ||
        value.endsWith('_SQ') ||
        compact.endsWith('SQ') ||
        compact.contains('SQUISH') ||
        compact.contains('SQUEEZE') ||
        compact.contains('COMPRESS')) {
      return 'SQ';
    }
    if (value == 'SG' ||
        value.endsWith('_SG') ||
        compact.endsWith('SG') ||
        compact.contains('SUNGLASSES')) {
      return 'SG';
    }
    if (value == 'TK' ||
        value.endsWith('_TK') ||
        compact.endsWith('TK') ||
        compact.contains('THINK')) {
      return 'TK';
    }
  }
  return modifier.modifierId.trim().toUpperCase();
}

IconData _modifierIcon(String modifierId) {
  switch (modifierId.trim().toUpperCase()) {
    case 'BW':
      return Icons.filter_b_and_w;
    case 'HF':
      return Icons.flip_rounded;
    case 'SQ':
      return Icons.compress_rounded;
    case 'SG':
      return Icons.dark_mode_rounded;
    case 'TK':
      return Icons.back_hand_rounded;
    default:
      return Icons.auto_fix_high_rounded;
  }
}

class _BlackWhiteModifierPainter extends CustomPainter {
  const _BlackWhiteModifierPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final circle = Offset(size.width * 0.5, size.height * 0.5);
    canvas.drawCircle(circle, size.shortestSide * 0.39, paint);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.18, size.height * 0.82)
        ..lineTo(size.width * 0.82, size.height * 0.18)
        ..lineTo(size.width * 0.82, size.height * 0.42)
        ..lineTo(size.width * 0.42, size.height * 0.82)
        ..close(),
      Paint()
        ..color = const Color(0xFF18181B)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HorizontalFlipModifierPainter extends CustomPainter {
  const _HorizontalFlipModifierPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          0,
          size.height * 0.20,
          size.width * 0.22,
          size.height * 0.60,
        ),
        Radius.circular(size.width * 0.04),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.78,
          size.height * 0.20,
          size.width * 0.22,
          size.height * 0.60,
        ),
        Radius.circular(size.width * 0.04),
      ),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.14),
      Offset(size.width * 0.50, size.height * 0.86),
      line,
    );
    for (final y in <double>[0.25, 0.40, 0.60, 0.75]) {
      canvas.drawCircle(
        Offset(size.width * 0.64, size.height * y),
        size.width * 0.035,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SquishModifierPainter extends CustomPainter {
  const _SquishModifierPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final radius = Radius.circular(size.height * 0.18);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.18,
          size.height * 0.35,
          size.width * 0.64,
          size.height * 0.24,
        ),
        radius,
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          0,
          size.height * 0.18,
          size.width * 0.26,
          size.height * 0.52,
        ),
        radius,
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.74,
          size.height * 0.18,
          size.width * 0.26,
          size.height * 0.52,
        ),
        radius,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SunglassesModifierPainter extends CustomPainter {
  const _SunglassesModifierPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final lensWidth = size.width * 0.36;
    final lensHeight = size.height * 0.62;
    final top = size.height * 0.24;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, lensWidth, lensHeight),
        Radius.circular(size.height * 0.18),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - lensWidth, top, lensWidth, lensHeight),
        Radius.circular(size.height * 0.18),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          lensWidth * 0.86,
          top + lensHeight * 0.20,
          size.width - lensWidth * 1.72,
          lensHeight * 0.18,
        ),
        Radius.circular(size.height * 0.08),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.02,
          0,
          size.width * 0.24,
          size.height * 0.16,
        ),
        Radius.circular(size.height * 0.08),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.74,
          0,
          size.width * 0.24,
          size.height * 0.16,
        ),
        Radius.circular(size.height * 0.08),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ThinkingHandModifierPainter extends CustomPainter {
  const _ThinkingHandModifierPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final radius = Radius.circular(size.height * 0.12);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.28,
          size.height * 0.38,
          size.width * 0.42,
          size.height * 0.32,
        ),
        radius,
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.52,
          size.height * 0.28,
          size.width * 0.42,
          size.height * 0.20,
        ),
        radius,
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.43,
          size.height * 0.04,
          size.width * 0.18,
          size.height * 0.44,
        ),
        radius,
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.20,
          size.height * 0.62,
          size.width * 0.44,
          size.height * 0.22,
        ),
        radius,
      ),
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.40),
      size.height * 0.13,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _modifierLabel(String modifierId) {
  switch (modifierId.trim().toUpperCase()) {
    case 'BW':
      return '黑白';
    case 'HF':
      return '水平翻轉';
    case 'SQ':
      return '壓縮';
    case 'SG':
      return '太陽眼鏡';
    case 'TK':
      return '思考中';
    default:
      return modifierId;
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
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
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

class _OverlayLoadingMessage extends StatelessWidget {
  final String message;

  const _OverlayLoadingMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: TwitchUiColors.primarySoft,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12.5,
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
