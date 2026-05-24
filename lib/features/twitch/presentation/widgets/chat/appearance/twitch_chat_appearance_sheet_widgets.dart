// PATCH VERSION: twitch_chat_appearance_sheet_widgets_stage163
//
// UI pieces used by the chat appearance sheet. Keep slider and preview styling
// here so the sheet entry file only wires the controller into the unified sheet.

import 'package:flutter/material.dart';

import '../../../theme/twitch_ui_tokens.dart';

class TwitchChatAppearanceSizeControl extends StatelessWidget {
  final double scale;
  final ValueChanged<double> onChanged;

  const TwitchChatAppearanceSizeControl({
    super.key,
    required this.scale,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
          onChanged: onChanged,
        ),
        const Row(
          children: [
            Text('小', style: TextStyle(color: Colors.white54, fontSize: 10)),
            Spacer(),
            Text('大', style: TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

class TwitchChatAppearancePreviewCard extends StatelessWidget {
  final double fontSize;
  final double emoteSize;
  final bool compact;

  const TwitchChatAppearancePreviewCard({
    super.key,
    required this.fontSize,
    required this.emoteSize,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 9 : 12),
      decoration: BoxDecoration(
        color: TwitchUiColors.sheet.cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TwitchUiColors.sheet.cardBorder),
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
                  color: TwitchUiColors.sheet.backplate.foreground,
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
                  color: TwitchUiColors.sheet.backplate.fillActive,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text('😄', style: TextStyle(fontSize: emoteSize * 0.72)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
