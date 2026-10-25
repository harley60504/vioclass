import 'package:flutter/material.dart';
import 'package:vioclass/features/twitch/models/chat/twitch_chat_message.dart';
import 'package:vioclass/features/twitch/models/chat/twitch_chat_message_metadata.dart';
import 'package:vioclass/features/twitch/models/chat/twitch_chat_runtime_message.dart';
import 'package:vioclass/features/twitch/presentation/theme/twitch_ui_tokens.dart';
import 'package:vioclass/features/twitch/presentation/widgets/chat/message/twitch_chat_message_cards.dart';
import 'package:vioclass/features/twitch/presentation/widgets/chat/message/twitch_chat_message_visual_metrics.dart';
import 'package:vioclass/features/twitch/presentation/widgets/chat/twitch_runtime_message_tile.dart';

void main() => runApp(const _ChatNamePreview());

class _ChatNamePreview extends StatelessWidget {
  const _ChatNamePreview();

  static const _colors = {
    '藍 Blue': '#0000FF',
    '藍紫 BlueViolet': '#8A2BE2',
    '灰藍 CadetBlue': '#5F9EA0',
    '巧克力 Chocolate': '#D2691E',
    '珊瑚 Coral': '#FF7F50',
    '道奇藍 DodgerBlue': '#1E90FF',
    '磚紅 Firebrick': '#B22222',
    '金黃 GoldenRod': '#DAA520',
    '綠 Green': '#008000',
    '亮粉紅 HotPink': '#FF69B4',
    '橘紅 OrangeRed': '#FF4500',
    '紅 Red': '#FF0000',
    '海綠 SeaGreen': '#2E8B57',
    '春綠 SpringGreen': '#00FF7F',
    '黃綠 YellowGreen': '#9ACD32',
    '自訂色：純黑': '#000000',
    '自訂色：深藍': '#000080',
    '自訂色：暗紅': '#800000',
  };

  TwitchChatRuntimeMessage _message(String color) {
    final source = TwitchChatMessage.synthetic(
      channelLogin: 'preview',
      userLogin: 'color_test',
      displayName: '名字顏色測試',
      message: '這是聊天室訊息，測試名字在深色背景上的閱讀效果。',
      tags: {'color': color},
    );
    return TwitchChatRuntimeMessage(
      source: source,
      resolvedBadges: const [],
      receivedAt: DateTime(2026),
      fragments: const [],
      segments: const [],
      metadata: TwitchChatMessageMetadata.fromMessage(source),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      backgroundColor: TwitchUiColors.appBackground,
      appBar: AppBar(title: const Text('聊天室名字配色測試')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('原始顏色與目前 App 顯示效果', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 8),
              const Text('15 種 Twitch 預設色＋3 種自訂色，皆為本機測試。'),
              for (final entry in _colors.entries) ...[
                const SizedBox(height: 24),
                Text(
                  '${entry.key}  ${entry.value}',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: TwitchUiColors.surfacePanel,
                    border: Border.all(color: TwitchUiColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '調整前',
                            style: TextStyle(
                              color: TwitchUiColors.textSecondary,
                            ),
                          ),
                        ),
                        TwitchChatNormalMessageCard(
                          message: _message(entry.value),
                          thirdPartyEmotes: null,
                          officialEmotes: null,
                          displayColor: Color(
                            int.parse(entry.value.substring(1), radix: 16) |
                                0xFF000000,
                          ),
                          displayNameText: '名字顏色測試 (color_test)',
                          showTimestamp: false,
                          metrics: TwitchChatMessageVisualMetrics(1),
                          onOpenContext: null,
                        ),
                        const Divider(height: 24),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '調整後',
                            style: TextStyle(
                              color: TwitchUiColors.textSecondary,
                            ),
                          ),
                        ),
                        TwitchRuntimeMessageTile(
                          message: _message(entry.value),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
