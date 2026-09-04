import 'package:flutter/material.dart';

import '../design/twitch_breakpoints.dart';
import '../design/twitch_typography.dart';
import '../localization/vioclass_localizations.dart';
import '../settings/twitch_chat_appearance_controller.dart';
import '../widgets/chat/appearance/twitch_chat_appearance_sheet_widgets.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

Future<void> showTwitchChatAppearanceSheet({
  required BuildContext context,
  required TwitchChatAppearanceController controller,
}) {
  final l10n = context.vio;
  return showTwitchUnifiedSheet<void>(
    context: context,
    title: l10n.t('聊天室字體'),
    subtitle: l10n.t('調整訊息文字與貼圖大小'),
    icon: Icons.format_size_rounded,
    size: TwitchUnifiedSheetSize.compact,
    showRefresh: false,
    trailing: [
      IconButton(
        tooltip: l10n.t('重設'),
        visualDensity: VisualDensity.compact,
        onPressed: controller.reset,
        icon: const Icon(Icons.restart_alt_rounded, size: 20),
      ),
    ],
    builder: (_) => TwitchChatAppearanceSheet(controller: controller),
  );
}

class TwitchChatAppearanceSheet extends StatelessWidget {
  final TwitchChatAppearanceController controller;

  const TwitchChatAppearanceSheet({super.key, required this.controller});

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

        return Padding(
          padding: EdgeInsets.fromLTRB(14, compact ? 10 : 14, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
            ],
          ),
        );
      },
    );
  }
}
