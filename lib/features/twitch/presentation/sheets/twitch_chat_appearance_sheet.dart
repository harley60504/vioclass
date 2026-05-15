import 'package:flutter/material.dart';

import '../design/twitch_breakpoints.dart';
import '../design/twitch_typography.dart';
import '../settings/twitch_chat_appearance_controller.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

Future<void> showTwitchChatAppearanceSheet({
  required BuildContext context,
  required TwitchChatAppearanceController controller,
}) {
  return showTwitchUnifiedSheet<void>(
    context: context,
    title: '聊天室字體',
    subtitle: '調整訊息文字與貼圖大小',
    icon: Icons.format_size_rounded,
    size: TwitchUnifiedSheetSize.compact,
    showRefresh: false,
    trailing: [
      IconButton(
        tooltip: '重設',
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

  const TwitchChatAppearanceSheet({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final compact = TwitchBreakpoints.isCompactVertical(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final scale = controller.fontScale;
        final fontSize = TwitchTypography.chatFontSize(scale, compact: compact);
        final emoteSize = TwitchTypography.chatEmoteSize(scale, compact: compact);

        return Padding(
          padding: EdgeInsets.fromLTRB(14, compact ? 10 : 14, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    '大小',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(scale * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Slider(
                min: 0.82,
                max: 1.45,
                divisions: 21,
                value: scale,
                onChanged: controller.setFontScale,
              ),
              const Row(
                children: [
                  Text('小', style: TextStyle(color: Colors.white54, fontSize: 10)),
                  Spacer(),
                  Text('大', style: TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(compact ? 9 : 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF242429),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '預覽',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 3,
                      children: [
                        Text(
                          'viewer123',
                          style: TextStyle(
                            color: const Color(0xFFBF94FF),
                            fontSize: fontSize,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '這是聊天室訊息預覽',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          width: emoteSize,
                          height: emoteSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF9146FF).withOpacity(0.28),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '😄',
                            style: TextStyle(fontSize: emoteSize * 0.72),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
